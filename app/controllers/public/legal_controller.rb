# This public surface intentionally avoids authenticated application concerns.
class Public::LegalController < ActionController::Base # rubocop:disable Rails/ApplicationController
  protect_from_forgery with: :exception
  layout 'legal'

  before_action :ensure_publication_ready!
  after_action :set_sensitive_response_headers, only: %i[verify_data_request confirm_data_request data_request_status]

  helper_method :current_legal_locale, :english?, :hcaptcha_site_key, :legal_language_switch_url,
                :privacy_request_status_label, :support_contact_email

  def terms
    render_legal_document('terms')
  end

  def privacy
    render_legal_document('privacy')
  end

  def cookies
    render_legal_document('cookies')
  end

  def data_request
    @document = catalog.find_legal_route!('data_request', current_legal_locale)
    @content_html = render_markdown(@document.content)
    @privacy_request = PrivacyRequest.new
  end

  def create_data_request
    @privacy_request = PrivacyRequest.new(privacy_request_params)
    @privacy_request.locale = current_legal_locale
    captcha_response = params['h-captcha-response'].presence || params[:h_captcha_client_response]
    unless ChatwootCaptcha.new(captcha_response).valid?
      @privacy_request.errors.add(:base, english? ? 'Captcha validation failed.' : 'Não foi possível validar o captcha.')
      return render_data_request_form(:unprocessable_entity)
    end

    @privacy_request.prepare_submission!
    if @privacy_request.save
      @privacy_request.events.create!(event_type: 'created', to_status: @privacy_request.status)
      deliver_verification_email(@privacy_request)
      render :data_request_submitted, status: :accepted
    else
      render_data_request_form(:unprocessable_entity)
    end
  end

  def verify_data_request
    @privacy_request = find_verifiable_request
    render :data_request_verification
  end

  def confirm_data_request
    @privacy_request = find_verifiable_request
    @verified = @privacy_request&.verify_token!(params[:token]) || false
    render :data_request_verified, status: @verified ? :ok : :unprocessable_entity
  end

  def data_request_status
    request_record = PrivacyRequest.find_by(protocol: params[:request_protocol])
    @privacy_request = request_record if request_record&.status_token_valid?(params[:token])
    render :data_request_status, status: @privacy_request ? :ok : :not_found
  end

  private

  def catalog
    @catalog ||= Acelerachat::PublicContent::Catalog.new
  end

  def ensure_publication_ready!
    if Rails.env.production? && !Chatwoot.encryption_configured?
      raise ArgumentError, 'Active Record encryption must be configured before publishing privacy requests'
    end

    catalog.validate!
    validate_hcaptcha_configuration!
  rescue ArgumentError => e
    Rails.logger.warn("AceleraChat public content unavailable: #{e.message}")
    @configuration_error = true
    render :unavailable, status: :service_unavailable
  end

  def render_legal_document(route)
    @document = catalog.find_legal_route!(route, current_legal_locale)
    @content_html = render_markdown(@document.content)
    render :document
  end

  def render_data_request_form(status)
    @document = catalog.find_legal_route!('data_request', current_legal_locale)
    @content_html = render_markdown(@document.content)
    render :data_request, status: status
  end

  def render_markdown(content)
    ChatwootMarkdownRenderer.new(content).render_article
  end

  def privacy_request_params
    permitted = params.require(:privacy_request).permit(:email, :request_type, :details)
    permitted[:request_type] = nil unless PrivacyRequest.request_types.key?(permitted[:request_type])
    permitted
  end

  def find_verifiable_request
    request_record = PrivacyRequest.find_by(protocol: params[:request_protocol])
    return unless request_record&.verification_token_valid?(params[:token])

    request_record
  end

  def deliver_verification_email(request_record)
    PrivacyRequestMailer.with(
      privacy_request: request_record,
      verification_token: request_record.raw_verification_token,
      status_token: request_record.raw_status_token,
      locale: current_legal_locale
    ).verification.deliver_now
    record_delivery_event(request_record, 'verification_email_sent')
  rescue StandardError => e
    Rails.logger.error("Privacy request verification email failed for protocol #{request_record.protocol}: #{e.class}")
    record_delivery_event(request_record, 'verification_email_failed', 'error_class' => e.class.name)
  end

  def record_delivery_event(request_record, event_type, metadata = {})
    request_record.events.create!(
      event_type: event_type,
      from_status: request_record.status,
      to_status: request_record.status,
      metadata: metadata
    )
  rescue StandardError => e
    Rails.logger.error("Privacy request delivery audit failed for protocol #{request_record.protocol}: #{e.class}")
  end

  def current_legal_locale
    @current_legal_locale ||= begin
      requested = params[:lang].to_s
      requested = 'en' if requested.blank? && request.headers['Accept-Language'].to_s.downcase.start_with?('en')
      requested == 'en' ? 'en' : 'pt_BR'
    end
  end

  def english?
    current_legal_locale == 'en'
  end

  def hcaptcha_site_key
    GlobalConfig.get_value('HCAPTCHA_SITE_KEY').to_s
  end

  def validate_hcaptcha_configuration!
    server_key = GlobalConfigService.load('HCAPTCHA_SERVER_KEY', '').to_s
    return if hcaptcha_site_key.present? == server_key.present?

    raise ArgumentError, 'HCAPTCHA_SITE_KEY and HCAPTCHA_SERVER_KEY must be configured together'
  end

  def privacy_request_status_label(request_record)
    request_record.status_label(current_legal_locale)
  end

  def support_contact_email
    catalog.facts.fetch('SUPPORT_CONTACT_EMAIL')
  end

  def set_sensitive_response_headers
    response.headers['Cache-Control'] = 'no-store, max-age=0'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Referrer-Policy'] = 'no-referrer'
    response.headers['X-Robots-Tag'] = 'noindex, nofollow, noarchive'
  end

  def legal_language_switch_url
    language = english? ? 'pt_BR' : 'en'
    case action_name
    when 'terms' then legal_terms_path(lang: language)
    when 'privacy' then legal_privacy_path(lang: language)
    when 'cookies' then legal_cookies_path(lang: language)
    when 'verify_data_request', 'confirm_data_request'
      legal_data_request_verify_path(request_protocol: params[:request_protocol], token: params[:token], lang: language)
    when 'data_request_status'
      legal_data_request_status_path(request_protocol: params[:request_protocol], token: params[:token], lang: language)
    else
      legal_data_request_path(lang: language)
    end
  end
end
