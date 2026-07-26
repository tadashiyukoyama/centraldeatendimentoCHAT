require 'uri'

module PublicBrand
  PROFILES_PATH = Rails.root.join('config/public_brand_profiles').freeze
  BLOCKED_HOSTS = %w[
    chatwoot.com
    chatwoot.help
    chwt.app
  ].freeze
  DEFAULT_LOCALE = 'en'.freeze
  PROFILE_VERSION = 1
  INTERNAL_PATH = %r{\A/(?!/)[A-Za-z0-9._~!$&'()*+,;=:@%/-]*\z}
  RESOURCE_VALUE_KEYS = %w[LOGO LOGO_DARK LOGO_THUMBNAIL].freeze
  ROUTE_SLUG = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  REQUIRED_GLOBAL_CONFIG = %w[
    PUBLIC_BRAND_PROFILE
    INSTALLATION_NAME
    BRAND_NAME
    ASSISTANT_PUBLIC_NAME
    PUBLIC_PLAN_NAME
    LOGO
    LOGO_DARK
    LOGO_THUMBNAIL
    BRAND_URL
    WIDGET_BRAND_URL
    HELP_CENTER_URL
    SUPPORT_URL
    TERMS_URL
    PRIVACY_URL
    COOKIES_URL
    DATA_REQUEST_URL
    MANIFEST_URL
    PWA_ASSET_BASE_URL
    MAILER_SUPPORT_EMAIL
  ].freeze
  LEGACY_PRODUCT_URL = %r{https://(?:[a-z0-9-]+\.)*(?:chatwoot\.com|chatwoot\.help|chwt\.app)[^\s"'<>)]*}i

  class InvalidProfile < StandardError; end

  class << self
    def active?
      profile_name.present?
    end

    def profile_name
      ENV.fetch('PUBLIC_BRAND_PROFILE', '').strip.presence
    end

    def profile
      return {}.with_indifferent_access unless active?

      if @loaded_profile_name != profile_name
        @profile = load_profile
        @loaded_profile_name = profile_name
      end
      @profile
    end

    def apply(config)
      return config.with_indifferent_access unless active?

      config.with_indifferent_access.merge(profile.fetch(:global_config))
    end

    def value(key, fallback = nil)
      return fallback unless active?

      profile.fetch(:global_config).fetch(key.to_s, fallback)
    end

    def help_urls(locale: I18n.locale)
      return {} unless active?

      requested_locale = locale.to_s
      supported_locale = profile.fetch(:help_locales).include?(requested_locale) ? requested_locale : DEFAULT_LOCALE
      profile.fetch(:help_articles).transform_values do |localized_slugs|
        slug = localized_slugs.fetch(supported_locale, localized_slugs.fetch(DEFAULT_LOCALE))
        "/hc/#{profile.fetch(:help_center_slug)}/articles/#{slug}"
      end
    end

    def validate!
      profile if active?
      true
    end

    def reset!
      @profile = nil
      @loaded_profile_name = nil
    end

    def public_text(value)
      return value unless active?
      return value.map { |item| public_text(item) } if value.is_a?(Array)
      return value.transform_values { |item| public_text(item) } if value.is_a?(Hash)
      return value unless value.is_a?(String)

      replace_public_text(value)
    end

    private

    def replace_public_text(text)
      text.gsub(%r{https://(?:www\.)?chatwoot\.com/(?:terms(?:-of-service)?|terms-of-use)[^\s"'<>)]*}i, value('TERMS_URL', '/legal/terms'))
          .gsub(%r{https://(?:www\.)?chatwoot\.com/privacy(?:-policy)?[^\s"'<>)]*}i, value('PRIVACY_URL', '/legal/privacy'))
          .gsub(LEGACY_PRODUCT_URL, value('HELP_CENTER_URL', '/hc/acelerachat'))
          .gsub(/[A-Z0-9._%+-]+@chatwoot\.com/i, value('MAILER_SUPPORT_EMAIL', 'suporte@meugerenciador.pro'))
          .gsub(/Chatwoot/i, value('INSTALLATION_NAME', 'AceleraChat'))
          .gsub(/Captain|Capitão/i, value('ASSISTANT_PUBLIC_NAME', 'Nemmo'))
          .gsub(/\bEnterprise\b/i, value('PUBLIC_PLAN_NAME', 'PRO'))
    end

    def load_profile
      path = PROFILES_PATH.join("#{profile_name}.yml")
      raise InvalidProfile, "Unknown public brand profile: #{profile_name}" unless path.file?

      loaded = YAML.safe_load(path.read, aliases: false).with_indifferent_access
      validate_profile!(loaded)
      loaded.freeze
    rescue Psych::Exception => e
      raise InvalidProfile, "Invalid public brand profile #{profile_name}: #{e.message}"
    end

    def validate_profile!(loaded)
      raise InvalidProfile, "Unsupported public brand profile version: #{loaded[:version]}" unless loaded[:version] == PROFILE_VERSION
      raise InvalidProfile, "Profile name mismatch: #{loaded[:profile_name]}" unless loaded[:profile_name] == profile_name

      global_config = loaded.fetch(:global_config)
      missing = REQUIRED_GLOBAL_CONFIG.select { |key| global_config[key].blank? }
      raise InvalidProfile, "Missing public brand values: #{missing.join(', ')}" if missing.any?
      raise InvalidProfile, 'PUBLIC_BRAND_PROFILE must match the selected profile name' unless global_config[:PUBLIC_BRAND_PROFILE] == profile_name

      validate_urls!(global_config)
      validate_emails!(global_config)
      validate_help_articles!(loaded)
    rescue KeyError => e
      raise InvalidProfile, "Incomplete public brand profile #{profile_name}: #{e.message}"
    end

    def validate_urls!(global_config)
      global_config.each do |key, value|
        next unless key.to_s.end_with?('_URL') || RESOURCE_VALUE_KEYS.include?(key.to_s)
        next if value.blank?

        validate_url!(key, value)
      end
    end

    def validate_url!(key, value)
      uri = URI.parse(value.to_s)
      return if internal_path?(uri, value)

      raise InvalidProfile, "Unsafe URL for #{key}: #{value}" unless safe_https_url?(uri)
    rescue URI::InvalidURIError
      raise InvalidProfile, "Invalid URL for #{key}: #{value}"
    end

    def internal_path?(uri, value)
      uri.scheme.nil? && value.to_s.match?(INTERNAL_PATH)
    end

    def safe_https_url?(uri)
      uri.scheme == 'https' && uri.host.present? && uri.userinfo.blank? && !blocked_host?(uri.host)
    end

    def blocked_host?(host)
      normalized_host = host.to_s.downcase.delete_suffix('.')
      BLOCKED_HOSTS.any? { |blocked| normalized_host == blocked || normalized_host.end_with?(".#{blocked}") }
    end

    def validate_emails!(global_config)
      global_config.each do |key, value|
        next unless key.to_s.end_with?('_EMAIL')
        next if value.blank?

        address = value.to_s.strip
        domain = address.split('@', 2).last.to_s.downcase.delete_suffix('.')
        invalid = !address.match?(URI::MailTo::EMAIL_REGEXP) || blocked_host?(domain)
        raise InvalidProfile, "Unsafe email for #{key}: #{value}" if invalid
      end
    end

    def validate_help_articles!(loaded)
      locales = loaded.fetch(:help_locales)
      raise InvalidProfile, 'Help locales must include en' unless locales.include?(DEFAULT_LOCALE)
      unless loaded.fetch(:help_center_slug).to_s.match?(ROUTE_SLUG)
        raise InvalidProfile, 'Help center slug must contain only lowercase letters, numbers, and hyphens'
      end

      loaded.fetch(:help_articles).each { |key, slugs| validate_help_article!(key, slugs, locales) }
    end

    def validate_help_article!(key, slugs, locales)
      missing_locales = locales - slugs.keys
      raise InvalidProfile, "Missing help locale for #{key}: #{missing_locales.join(', ')}" if missing_locales.any?

      invalid_locales = slugs.filter_map { |locale, slug| locale unless slug.to_s.match?(ROUTE_SLUG) }
      raise InvalidProfile, "Invalid help article slug for #{key}: #{invalid_locales.join(', ')}" if invalid_locales.any?
    end
  end
end
