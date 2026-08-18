class Openjarvis::ContactInboxResolver
  DERIVABLE_CHANNEL_TYPES = %w[
    Channel::Api Channel::Email Channel::Sms Channel::TwilioSms Channel::WebWidget Channel::Whatsapp
  ].freeze

  def initialize(contact:, inbox:)
    @contact = contact
    @inbox = inbox
  end

  def resolve!
    existing = ContactInbox.find_by(contact: contact, inbox: inbox)
    return existing if existing

    unless DERIVABLE_CHANNEL_TYPES.include?(inbox.channel_type)
      raise Openjarvis::ApiError.new(
        'contact_inbox_missing',
        'The contact has no provider association for this inbox',
        status: :unprocessable_entity,
        details: { inbox_id: inbox.id, channel_type: inbox.channel_type, source_id_required_from_provider: true }
      )
    end

    ContactInboxBuilder.new(contact: contact, inbox: inbox, source_id: nil).perform
  rescue ActionController::ParameterMissing => e
    raise Openjarvis::ApiError.new(
      'contact_routing_attribute_missing',
      e.message,
      status: :unprocessable_entity,
      details: { inbox_id: inbox.id, channel_type: inbox.channel_type }
    )
  end

  private

  attr_reader :contact, :inbox
end
