require 'base64'
require 'digest'
require 'stringio'

class Acelerachat::PublicContent::SyncService
  ACCOUNT_ID = 1
  PORTAL_SLUG = 'acelerachat'.freeze
  MANAGED_BY = 'acelerachat_public_content'.freeze
  PORTAL_MARKER = 'acelerachat-public-content-v1'.freeze
  LOGO_PATH = Rails.public_path.join('brand-assets/acelerachat/logo.svg').freeze
  ARTICLE_FIELDS = %w[title content locale description position author_id account_id portal_id].freeze

  Result = Struct.new(:mode, :actions, :document_count, keyword_init: true)

  def initialize(mode:, catalog: nil)
    @mode = mode.to_sym
    @catalog = catalog
    raise ArgumentError, "Unsupported mode: #{@mode}" unless %i[check sync].include?(@mode)
  end

  def call
    if Rails.env.production? && !Chatwoot.encryption_configured?
      raise ArgumentError, 'Active Record encryption must be configured before public content synchronization'
    end

    catalog.validate!
    resolve_dependencies!

    return Result.new(mode: :check, actions: inspect_actions, document_count: catalog.documents.size) if mode == :check

    actions = ApplicationRecord.transaction do
      resolve_dependencies!(lock: true)
      inspect_actions.tap { sync! }
    end
    Result.new(mode: :sync, actions: actions, document_count: catalog.documents.size)
  end

  private

  attr_reader :mode, :account, :author, :portal

  def catalog
    @catalog ||= Acelerachat::PublicContent::Catalog.new
  end

  def resolve_dependencies!(lock: false)
    @account = Account.find(ACCOUNT_ID)
    @author = account.users.where('LOWER(email) = ?', catalog.author_email.downcase).first
    raise ActiveRecord::RecordNotFound, 'Configured public content author must belong to account 1' unless author
    unless account.account_users.exists?(user_id: author.id, role: AccountUser.roles.fetch('administrator'))
      raise ArgumentError, 'Configured public content author must be an administrator of account 1'
    end

    relation = Portal.where(slug: PORTAL_SLUG)
    relation = relation.lock if lock
    @portal = relation.first
    assert_portal_ownership!
    assert_article_ownership!
  end

  def assert_portal_ownership!
    return unless portal
    raise ArgumentError, "Portal #{PORTAL_SLUG} belongs to another account" unless portal.account_id == account.id
    return if portal.config.to_h['website_token'] == PORTAL_MARKER

    raise ArgumentError, "Portal #{PORTAL_SLUG} exists but is not managed by this repository"
  end

  def assert_article_ownership!
    catalog.documents.each do |document|
      article = Article.find_by(slug: document.slug)
      next unless article

      meta = article.meta.to_h
      owned = portal && article.portal_id == portal.id && meta['managed_by'] == MANAGED_BY && meta['content_id'] == document.id
      raise ArgumentError, "Article slug collision with manual content: #{document.slug}" unless owned
    end
  end

  def inspect_actions
    (portal_actions + category_actions + article_actions).freeze
  end

  def portal_actions
    return [{ action: 'create', type: 'portal', key: PORTAL_SLUG }] unless portal
    return [{ action: 'update', type: 'portal', key: PORTAL_SLUG }] if portal_changes?(portal)

    []
  end

  def category_actions
    catalog.documents.group_by { |document| [document.locale, document.category_slug] }.map do |key, entries|
      category_action(key, entries.first)
    end
  end

  def category_action(key, document)
    category = portal&.categories&.find_by(locale: key.first, slug: key.last)
    validate_category_name!(category, document, key)
    { action: category ? 'verify' : 'create', type: 'category', key: key.join('/') }
  end

  def validate_category_name!(category, document, key)
    return unless category && category.name != document.category_name

    raise ArgumentError, "Category collision with manual content: #{key.join('/')}"
  end

  def article_actions
    catalog.documents.map do |document|
      article = Article.find_by(slug: document.slug)
      { action: article_action(article, document), type: 'article', key: document.id, sha256: document.source_sha256 }
    end
  end

  def article_action(article, document)
    return 'create' unless article

    article_changes?(article, document) ? 'update' : 'unchanged'
  end

  def sync!
    @portal ||= account.portals.create!(portal_attributes)
    portal.update!(portal_attributes) if portal_changes?(portal)

    categories = sync_categories!
    catalog.documents.each { |document| sync_article!(document, categories.fetch([document.locale, document.category_slug])) }
    # Attach only after every database-backed content operation succeeds,
    # reducing the chance of an orphaned storage blob on transaction rollback.
    sync_logo!
  end

  def sync_categories!
    catalog.documents.group_by { |document| [document.locale, document.category_slug] }.to_h do |key, entries|
      document = entries.first
      category = portal.categories.find_or_initialize_by(locale: document.locale, slug: document.category_slug)
      if category.persisted? && category.name != document.category_name
        raise ArgumentError, "Category collision with manual content: #{key.join('/')}"
      end

      category.assign_attributes(name: document.category_name, position: entries.map(&:position).min)
      category.save! if category.changed?
      [key, category]
    end
  end

  def sync_article!(document, category)
    article = Article.find_or_initialize_by(slug: document.slug)
    article.assign_attributes(article_attributes(document, category, article))
    article.save! if article.changed?
  end

  def article_attributes(document, category, article)
    {
      account: account,
      portal: portal,
      category: category,
      author: author,
      locale: document.locale,
      title: document.title,
      content: document.content,
      description: document.description,
      position: document.position,
      status: :published,
      meta: article.meta.to_h.merge(
        'managed_by' => MANAGED_BY,
        'content_id' => document.id,
        'source_sha256' => document.source_sha256,
        'title' => document.title,
        'description' => document.description
      )
    }
  end

  def article_changes?(article, document)
    current = article.attributes.values_at(*ARTICLE_FIELDS)
    current.push(article.category&.slug, article.category&.locale, article.meta.to_h['source_sha256'], article.published?)
    expected = [
      document.title, document.content, document.locale, document.description, document.position,
      author.id, account.id, portal.id, document.category_slug, document.locale, document.source_sha256, true
    ]
    current != expected
  end

  def portal_attributes
    Acelerachat::PublicContent::PortalProfile.attributes(portal_marker: PORTAL_MARKER)
  end

  def portal_changes?(record)
    desired = portal_attributes.deep_stringify_keys
    desired.any? do |attribute, value|
      if attribute == 'config'
        current = record.config.to_h.deep_stringify_keys
        value.any? { |key, expected| current[key] != expected }
      else
        record.public_send(attribute) != value
      end
    end
  end

  def sync_logo!
    expected_checksum = Base64.strict_encode64(Digest::MD5.file(LOGO_PATH).digest)
    return if portal.logo.attached? && portal.logo.blob.checksum == expected_checksum

    # Active Storage uploads after the surrounding transaction commits.
    # StringIO keeps the source readable until that callback runs.
    portal.logo.attach(
      io: StringIO.new(LOGO_PATH.binread),
      filename: 'acelerachat-logo.svg',
      content_type: 'image/svg+xml'
    )
  end
end
