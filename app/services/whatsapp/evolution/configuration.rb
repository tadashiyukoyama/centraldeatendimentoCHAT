class Whatsapp::Evolution::Configuration
  class ConfigurationError < StandardError; end

  class << self
    def enabled?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch('EVOLUTION_API_ENABLED', false))
    end

    def validate!
      raise ConfigurationError, 'Evolution API integration is disabled' unless enabled?
      raise ConfigurationError, 'Evolution API requires Active Record encryption' unless Chatwoot.encryption_configured?
      raise ConfigurationError, 'EVOLUTION_API_KEY is not configured' if api_key.blank?

      validate_url!(api_url, 'EVOLUTION_API_URL')
      validate_url!(frontend_url, 'FRONTEND_URL')
      validate_basic_auth!
      true
    end

    def api_url
      ENV.fetch('EVOLUTION_API_URL', '').delete_suffix('/')
    end

    def api_key
      ENV.fetch('EVOLUTION_API_KEY', '')
    end

    def frontend_url
      ENV.fetch('FRONTEND_URL', '').delete_suffix('/')
    end

    def basic_auth
      user = ENV.fetch('EVOLUTION_API_BASIC_AUTH_USER', '')
      password = ENV.fetch('EVOLUTION_API_BASIC_AUTH_PASSWORD', '')
      return if user.blank? && password.blank?

      { username: user, password: password }
    end

    def webhook_url(public_id)
      "#{frontend_url}/webhooks/evolution/#{ERB::Util.url_encode(public_id)}"
    end

    private

    def validate_url!(value, variable_name)
      uri = URI.parse(value)
      return if valid_url?(uri)

      scheme_requirement = Rails.env.production? ? 'HTTPS ' : ''
      raise ConfigurationError, "#{variable_name} must be a valid #{scheme_requirement}URL"
    rescue URI::InvalidURIError
      raise ConfigurationError, "#{variable_name} must be a valid URL"
    end

    def valid_url?(uri)
      valid_scheme?(uri) &&
        uri.host.present? &&
        uri.userinfo.blank? &&
        uri.query.blank? &&
        uri.fragment.blank?
    end

    def valid_scheme?(uri)
      return uri.scheme == 'https' if Rails.env.production?

      %w[http https].include?(uri.scheme)
    end

    def validate_basic_auth!
      user = ENV.fetch('EVOLUTION_API_BASIC_AUTH_USER', '')
      password = ENV.fetch('EVOLUTION_API_BASIC_AUTH_PASSWORD', '')
      return if user.blank? && password.blank?
      return if user.present? && password.present?

      raise ConfigurationError, 'Evolution API Basic Authentication requires both user and password'
    end
  end
end
