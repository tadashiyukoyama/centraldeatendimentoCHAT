require 'digest'
require 'json'

class Acelerachat::BrandAudit
  EXPECTED_VISUAL_ASSETS = 55
  EXPECTED_HELP_ARTICLES = 22
  EXPECTED_LEGAL_DOCUMENTS = 16
  BLOCKED_REFERENCE = %r{
    (?:
      https?://(?:[^/@\s]+@)?(?:[a-z0-9-]+\.)*(?:chatwoot\.com|chatwoot\.help|chwt\.app) |
      https://github\.com/chatwoot/chatwoot/releases |
      [A-Z0-9._%+-]+@chatwoot\.com
    )
  }ix
  SCAN_ROOTS = %w[app config enterprise lib public .env.example app.json].freeze
  HIDDEN_SERVICES = %w[CHANGELOG_URL STATUS_URL BILLING_URL CLOUD_ANALYTICS_TOKEN].freeze
  HELP_ARTICLE_ROUTE = %r{\A/hc/acelerachat/articles/[a-z0-9-]+\z}
  RUNTIME_EXTENSION = /(?:\.rb|\.rake|\.erb|\.liquid|\.js|\.vue|\.json|\.ya?ml|\.example)\z/
  EXCLUDED_RUNTIME_PATTERNS = [
    %r{/(?:spec|specs|fixtures)/},
    %r{\Apublic/(?:vite-dev|vite-test|vite|packs)/}
  ].freeze
  EXCLUDED_RUNTIME_FRAGMENTS = ['/story/', '/i18n/locale/', '/locales/', '.story.'].freeze
  ALLOWED_BLOCKLIST_FILES = %w[
    lib/public_brand.rb
    lib/acelera_control/url_policy.rb
    app/javascript/shared/helpers/publicBrandMessages.js
    app/javascript/dashboard/api/changelog.js
  ].freeze

  def call
    errors = profile_errors + content_errors + asset_errors + egress_errors
    errors << 'ACELERA_CONTROL_ENABLED must remain false' if acelera_control_enabled?
    raise ArgumentError, errors.join("\n") if errors.any?

    saml_user_count = User.where(provider: 'saml').count
    audit_summary(saml_user_count)
  end

  private

  def audit_summary(saml_user_count)
    {
      profile: PublicBrand.profile_name,
      help_links: EXPECTED_HELP_ARTICLES,
      public_documents: (EXPECTED_HELP_ARTICLES + EXPECTED_LEGAL_DOCUMENTS) * 2,
      visual_assets: EXPECTED_VISUAL_ASSETS,
      blocked_runtime_references: 0,
      saml_users: saml_user_count,
      sso_mode: saml_user_count.positive? ? 'preserved_and_rebranded' : 'hidden',
      google_oauth: 'disabled',
      acelera_control_enabled: false
    }
  end

  def acelera_control_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('ACELERA_CONTROL_ENABLED', false))
  end

  def profile_errors
    return ['PUBLIC_BRAND_PROFILE must be acelerachat'] unless PublicBrand.profile_name == 'acelerachat'

    PublicBrand.validate!
    links = PublicBrand.help_urls(locale: 'pt_BR')
    hidden_service_errors + oauth_errors + help_registry_errors(links) + feature_link_errors(links)
  rescue PublicBrand::InvalidProfile => e
    [e.message]
  end

  def hidden_service_errors
    HIDDEN_SERVICES.filter_map do |key|
      "#{key} must remain disabled until a first-party service exists" if PublicBrand.value(key).present?
    end
  end

  def oauth_errors
    return [] unless ActiveModel::Type::Boolean.new.cast(PublicBrand.value('ENABLE_GOOGLE_OAUTH_LOGIN'))

    ['Google OAuth must remain disabled until first-party credentials are approved']
  end

  def help_registry_errors(links)
    errors = []
    errors << "Expected #{EXPECTED_HELP_ARTICLES} canonical help links, found #{links.size}" unless links.size == EXPECTED_HELP_ARTICLES
    errors << 'Canonical help links must use the public article route' unless links.values.all? { |url| url.match?(HELP_ARTICLE_ROUTE) }
    errors
  end

  def feature_link_errors(links)
    feature_links = YAML.safe_load(Rails.root.join('config/features.yml').read).filter_map do |feature|
      [feature.fetch('name'), feature['help_url']] if feature['help_url'].present?
    end.to_h
    feature_links.filter_map do |key, url|
      "Feature help URL differs from canonical registry: #{key}" unless links[key] == url
    end
  end

  def content_errors
    catalog = Acelerachat::PublicContent::Catalog.new.validate!(require_facts: false)
    counts = catalog.documents.group_by { |document| [document.kind, document.locale] }.transform_values(&:size)
    expected = {
      %w[help pt_BR] => EXPECTED_HELP_ARTICLES,
      %w[help en] => EXPECTED_HELP_ARTICLES,
      %w[legal pt_BR] => EXPECTED_LEGAL_DOCUMENTS,
      %w[legal en] => EXPECTED_LEGAL_DOCUMENTS
    }
    expected.filter_map do |key, count|
      "Expected #{count} #{key.join('/')} documents, found #{counts[key].to_i}" unless counts[key] == count
    end
  rescue ArgumentError => e
    [e.message]
  end

  def asset_errors
    manifest_path = Rails.public_path.join('brand-assets/acelerachat/assets.sha256.json')
    return ["Missing asset manifest: #{manifest_path}"] unless manifest_path.file?

    manifest = JSON.parse(manifest_path.read)
    asset_count_errors(manifest) + generated_asset_errors(manifest.fetch('generated_files'))
  rescue JSON::ParserError, KeyError => e
    ["Invalid asset manifest: #{e.message}"]
  end

  def asset_count_errors(manifest)
    return [] if manifest['audited_visual_assets'] == EXPECTED_VISUAL_ASSETS

    ["Expected #{EXPECTED_VISUAL_ASSETS} audited visual assets, found #{manifest['audited_visual_assets']}"]
  end

  def generated_asset_errors(entries)
    entries.filter_map do |entry|
      path = Rails.root.join(entry.fetch('path'))
      if !path.file? || path.empty?
        "Missing or empty AceleraChat asset: #{entry.fetch('path')}"
      elsif Digest::SHA256.file(path).hexdigest != entry.fetch('sha256')
        "Asset digest mismatch: #{entry.fetch('path')}"
      end
    end
  end

  def egress_errors
    runtime_file_errors + environment_egress_errors
  end

  def runtime_file_errors
    runtime_files.filter_map do |path|
      next if allowed_reference_file?(path)

      matches = blocked_locations(path)
      "Blocked legacy runtime reference: #{matches.join(', ')}" if matches.any?
    end
  end

  def environment_egress_errors
    ENV.filter_map do |key, value|
      "Blocked legacy runtime reference in environment key: #{key}" if value.to_s.match?(BLOCKED_REFERENCE)
    end
  end

  def blocked_locations(path)
    path.read(encoding: 'UTF-8', invalid: :replace, undef: :replace).lines.each_with_index.filter_map do |line, index|
      "#{relative(path)}:#{index + 1}" if line.match?(BLOCKED_REFERENCE)
    end
  end

  def runtime_files
    files = SCAN_ROOTS.flat_map do |root|
      path = Rails.root.join(root)
      path.file? ? [path] : path.glob('**/*').select(&:file?)
    end
    files.select { |path| runtime_file?(relative(path)) }
  end

  def runtime_file?(path)
    return false if excluded_runtime_file?(path)
    return false if path.end_with?('LICENSE', '.map')

    path.match?(RUNTIME_EXTENSION)
  end

  def excluded_runtime_file?(path)
    EXCLUDED_RUNTIME_PATTERNS.any? { |pattern| path.match?(pattern) } ||
      EXCLUDED_RUNTIME_FRAGMENTS.any? { |fragment| path.include?(fragment) }
  end

  def allowed_reference_file?(path)
    ALLOWED_BLOCKLIST_FILES.include?(relative(path))
  end

  def relative(path)
    path.relative_path_from(Rails.root).to_s.tr('\\', '/')
  end
end
