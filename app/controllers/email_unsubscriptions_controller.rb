class EmailUnsubscriptionsController < ActionController::Base # rubocop:disable Rails/ApplicationController
  protect_from_forgery with: :exception
  layout 'legal'

  before_action :load_contact
  around_action :switch_public_locale

  helper_method :current_legal_locale, :english?, :legal_language_switch_url, :support_contact_email

  def show
    @token = params[:token]
  end

  def create
    attributes = @contact.additional_attributes.merge(
      'email_unsubscribed' => true,
      'email_unsubscribed_at' => Time.current.iso8601
    )
    @contact.update!(additional_attributes: attributes)
  end

  private

  def load_contact
    @contact = Email::UnsubscribeTokenService.contact_for(params[:token])
    head :not_found if @contact.blank?
  end

  def switch_public_locale(&)
    I18n.with_locale(current_legal_locale, &)
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

  def legal_language_switch_url
    language = english? ? 'pt_BR' : 'en'
    email_unsubscribe_path(token: params[:token], lang: language)
  end

  def support_contact_email
    PublicBrand.value('MAILER_SUPPORT_EMAIL', 'suporte@aifoodmanager.pro')
  end
end
