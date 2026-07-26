require 'uri'

class PrivacyRequestMailer < ApplicationMailer
  layout false

  def verification
    @privacy_request = params[:privacy_request]
    @locale = params[:locale] == 'en' ? 'en' : 'pt_BR'
    @brand_name = brand_config['BRAND_NAME'].presence || 'AceleraChat'
    @logo_url = absolute_brand_asset(brand_config['LOGO'])
    @verification_url = legal_url(
      :legal_data_request_verify_url,
      request_protocol: @privacy_request.protocol,
      token: params[:verification_token],
      lang: @locale
    )
    @status_url = legal_url(
      :legal_data_request_status_url,
      request_protocol: @privacy_request.protocol,
      token: params[:status_token],
      lang: @locale
    )
    subject = @locale == 'en' ? "Confirm privacy request #{@privacy_request.protocol}" : "Confirme a solicitação #{@privacy_request.protocol}"
    mail(to: @privacy_request.email, subject: "#{@brand_name} — #{subject}")
  end

  def status_updated
    @privacy_request = params[:privacy_request]
    @locale = params[:locale] == 'en' ? 'en' : 'pt_BR'
    @brand_name = brand_config['BRAND_NAME'].presence || 'AceleraChat'
    @logo_url = absolute_brand_asset(brand_config['LOGO'])
    subject = @locale == 'en' ? "Privacy request updated: #{@privacy_request.protocol}" : "Solicitação atualizada: #{@privacy_request.protocol}"
    mail(to: @privacy_request.email, subject: "#{@brand_name} — #{subject}")
  end

  private

  def legal_url(route, **parameters)
    frontend = public_base_uri
    options = { host: frontend.host, protocol: frontend.scheme }
    options[:port] = frontend.port unless [80, 443].include?(frontend.port)
    Rails.application.routes.url_helpers.public_send(route, **parameters, **options)
  end

  def absolute_brand_asset(value)
    return if value.blank?

    uri = URI.parse(value.to_s)
    return uri.to_s if safe_external_asset?(uri)
    return unless safe_internal_asset?(uri, value)

    URI.join("#{public_base_uri.to_s.chomp('/')}/", value.to_s.delete_prefix('/')).to_s
  rescue URI::InvalidURIError
    nil
  end

  def safe_external_asset?(uri)
    uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.blank?
  end

  def safe_internal_asset?(uri, value)
    uri.scheme.nil? && value.to_s.start_with?('/') && !value.to_s.start_with?('//')
  end

  def public_base_uri
    value = brand_config['BRAND_URL'].presence ||
            ENV.fetch('FRONTEND_URL', 'https://atendimento.meugerenciador.pro')
    uri = URI.parse(value.to_s)
    safe_scheme = Rails.env.production? ? uri.is_a?(URI::HTTPS) : uri.is_a?(URI::HTTP)
    valid = safe_scheme && uri.host.present? && uri.userinfo.blank?
    raise ArgumentError, 'A safe public brand URL is required for privacy request emails' unless valid

    uri
  end

  def brand_config
    @brand_config ||= GlobalConfig.get('BRAND_NAME', 'BRAND_URL', 'LOGO')
  end
end
