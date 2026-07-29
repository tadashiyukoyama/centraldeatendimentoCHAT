class Captain::Tools::CaptureContactProfileTool < Captain::Tools::BasePublicTool
  PROFILE_FIELDS = %i[name phone_number company_name email].freeze
  INPUT_FIELDS = (PROFILE_FIELDS + [:country_code]).freeze

  description 'Save contact details explicitly provided by the customer'
  param :name, type: 'string', desc: 'Customer full name', required: false
  param :phone_number, type: 'string', desc: 'Customer phone number', required: false
  param :company_name, type: 'string', desc: 'Customer company or establishment', required: false
  param :email, type: 'string', desc: 'Customer email address', required: false
  param :country_code, type: 'string', desc: 'ISO country code used to normalize a local phone', required: false

  def perform(tool_context, **attributes)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    contact = conversation.contact
    return 'Contact not found' unless contact

    attributes = attributes.symbolize_keys.slice(*INPUT_FIELDS)
    supplied_fields = PROFILE_FIELDS.select { |field| attributes[field].present? }
    return 'At least one contact field is required' if supplied_fields.empty?

    with_tool_audit(
      tool_context,
      request_summary: { fields: supplied_fields.map(&:to_s).sort }
    ) do
      save_profile(conversation, contact, attributes)
    end
  end

  private

  def save_profile(conversation, _contact, attributes)
    changed_fields = Captain::Conversation::ContactProfileUpdater.new(
      conversation: conversation,
      assistant: @assistant,
      country_code: attributes[:country_code]
    ).perform(
      attributes: attributes.slice(*PROFILE_FIELDS),
      source: 'captain_tool'
    )
    "Contact profile saved: #{changed_fields.join(', ')}"
  rescue Captain::Conversation::ContactProfileUpdater::ValidationError => e
    reject_execution!(
      e.message,
      code: e.code
    )
  end
end
