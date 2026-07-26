require 'digest'
require 'uri'

class Acelerachat::PublicContent::Catalog
  ROOT = Rails.root.join('config/acelerachat/public_content').freeze
  REQUIRED_FACTS = %w[
    LEGAL_ENTITY_NAME
    LEGAL_ENTITY_ADDRESS
    LEGAL_DPO_NAME
    PRIVACY_CONTACT_EMAIL
    SUPPORT_CONTACT_EMAIL
    ACELERACHAT_PUBLIC_CONTENT_AUTHOR_EMAIL
  ].freeze
  OPTIONAL_FACTS = %w[LEGAL_ENTITY_CNPJ].freeze
  EMAIL_FACTS = %w[PRIVACY_CONTACT_EMAIL SUPPORT_CONTACT_EMAIL ACELERACHAT_PUBLIC_CONTENT_AUTHOR_EMAIL].freeze
  REQUIRED_METADATA = %i[id kind locale slug title category_slug category_name position managed].freeze
  LEGAL_ROUTES = %w[terms privacy cookies data_request].freeze
  SUPPORTED_LOCALES = %w[pt_BR en].freeze
  CONTENT_PLACEHOLDER = /\{\{([A-Z][A-Z0-9_]+)\}\}/
  LEGACY_EMAIL_DOMAINS = %w[chatwoot.com chatwoot.help chwt.app].freeze

  Document = Struct.new(
    :id, :kind, :locale, :slug, :title, :category_slug, :category_name,
    :position, :route, :source_path, :content, keyword_init: true
  ) do
    def source_sha256
      Digest::SHA256.hexdigest(content)
    end

    def description
      content.lines.map(&:strip).find { |line| line.present? && !line.start_with?('#') }.to_s.truncate(240)
    end
  end

  attr_reader :documents

  def initialize(root: ROOT, env: ENV)
    @root = Pathname(root)
    @env = env
    @documents = load_documents
  end

  def validate!(require_facts: true)
    raise ArgumentError, "No public content found under #{@root}" if documents.empty?

    validate_unique!(:id)
    validate_unique!(:slug)
    validate_routes!
    validate_facts! if require_facts
    validate_placeholders!
    self
  end

  def facts
    @facts ||= begin
      values = (REQUIRED_FACTS + OPTIONAL_FACTS).index_with { |key| @env[key].to_s.strip }
      cnpj = values.fetch('LEGAL_ENTITY_CNPJ')
      values.merge(
        'LEGAL_ENTITY_REGISTRATION_PT' => cnpj.present? ? ", CNPJ `#{cnpj}`" : '',
        'LEGAL_ENTITY_REGISTRATION_EN' => cnpj.present? ? ", Brazilian company registration `#{cnpj}`" : ''
      )
    end
  end

  def missing_facts
    REQUIRED_FACTS.select { |key| facts.fetch(key).blank? }
  end

  def author_email
    facts.fetch('ACELERACHAT_PUBLIC_CONTENT_AUTHOR_EMAIL')
  end

  def find_legal_route!(route, locale)
    documents.find { |document| document.kind == 'legal' && document.route == route && document.locale == locale } ||
      raise(ArgumentError, "Missing legal document for route=#{route.inspect}, locale=#{locale.inspect}")
  end

  private

  def load_documents
    @root.glob('{pt_BR,en}/{help,legal}/*.md').sort.map { |path| load_document(path) }
  end

  def load_document(path)
    match = extract_front_matter(path)
    metadata = parse_metadata(match)
    validate_metadata!(metadata, path)
    build_document(metadata, match[:content], path)
  rescue Psych::Exception => e
    raise ArgumentError, "Invalid YAML in #{path}: #{e.message}"
  end

  def extract_front_matter(path)
    raw = path.read(encoding: 'UTF-8')
    match = raw.match(/\A---\s*\n(?<front_matter>.*?)\n---\s*\n(?<content>.*)\z/m)
    raise ArgumentError, "Invalid front matter in #{path}" unless match

    match
  end

  def parse_metadata(match)
    YAML.safe_load(match[:front_matter], aliases: false).deep_symbolize_keys
  end

  def validate_metadata!(metadata, path)
    missing = REQUIRED_METADATA.select { |key| metadata[key].blank? && metadata[key] != true }
    raise ArgumentError, "Missing #{missing.join(', ')} in #{path}" if missing.any?
    raise ArgumentError, "Document is not repository-managed: #{path}" unless metadata[:managed] == true
    raise ArgumentError, "Document metadata does not match its path: #{path}" unless metadata_matches_path?(metadata, path)
  end

  def metadata_matches_path?(metadata, path)
    locale, kind = path.relative_path_from(@root).each_filename.to_a
    metadata[:locale].to_s == locale && metadata[:kind].to_s == kind
  end

  def build_document(metadata, raw_content, path)
    Document.new(
      **metadata.slice(*Document.members),
      source_path: path,
      content: interpolate(raw_content.strip)
    )
  end

  def interpolate(content)
    content.gsub(CONTENT_PLACEHOLDER) { |placeholder| facts.fetch(Regexp.last_match(1), placeholder) }
  end

  def validate_unique!(attribute)
    duplicates = documents.group_by(&attribute).select { |_value, entries| entries.many? }.keys
    raise ArgumentError, "Duplicate public content #{attribute}: #{duplicates.join(', ')}" if duplicates.any?
  end

  def validate_routes!
    route_documents = documents.select { |document| document.route.present? }
    duplicates = route_documents.group_by { |document| [document.route, document.locale] }
                                .select { |_key, entries| entries.many? }.keys
    raise ArgumentError, "Duplicate legal routes: #{duplicates.inspect}" if duplicates.any?

    LEGAL_ROUTES.each do |route|
      SUPPORTED_LOCALES.each { |locale| find_legal_route!(route, locale) }
    end
  end

  def validate_facts!
    raise ArgumentError, "Missing required public content configuration: #{missing_facts.join(', ')}" if missing_facts.any?

    validate_cnpj!
    EMAIL_FACTS.each { |key| validate_email_fact!(key) }
  end

  def validate_cnpj!
    cnpj = facts.fetch('LEGAL_ENTITY_CNPJ')
    return if cnpj.blank? || cnpj.match?(%r{\A(?:\d{14}|\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2})\z})

    raise ArgumentError, 'LEGAL_ENTITY_CNPJ must contain a valid 14-digit CNPJ format'
  end

  def validate_email_fact!(key)
    address = facts.fetch(key)
    raise ArgumentError, "#{key} is not a valid email address" unless address.match?(URI::MailTo::EMAIL_REGEXP)

    domain = address.split('@', 2).last.to_s.downcase.delete_suffix('.')
    return unless LEGACY_EMAIL_DOMAINS.any? { |legacy| domain == legacy || domain.end_with?(".#{legacy}") }

    raise ArgumentError, "#{key} must not use a legacy first-party domain"
  end

  def validate_placeholders!
    unresolved = documents.flat_map { |document| document.content.scan(CONTENT_PLACEHOLDER).flatten }.uniq
    return if unresolved.empty?

    raise ArgumentError, "Unresolved public content placeholders: #{unresolved.join(', ')}"
  end
end
