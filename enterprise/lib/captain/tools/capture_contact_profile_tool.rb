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
      save_profile(tool_context, conversation, attributes)
    end
  end

  private

  def save_profile(tool_context, conversation, attributes)
    changed_fields = Captain::Conversation::ContactProfileUpdater.new(
      conversation: conversation,
      assistant: @assistant,
      country_code: attributes[:country_code]
    ).perform(
      attributes: attributes.slice(*PROFILE_FIELDS),
      source: 'captain_tool'
    )
    contact = conversation.contact.reload
    profile_status = Captain::Conversation::ContactProfileStatus.new(contact)
    sync_tool_state!(tool_context, profile_status)

    profile_result(changed_fields, profile_status).to_json
  rescue Captain::Conversation::ContactProfileUpdater::ValidationError => e
    reject_execution!(
      e.message,
      code: e.code
    )
  end

  def profile_result(changed_fields, profile_status)
    {
      status: 'saved',
      saved_fields: changed_fields == ['no_changes'] ? [] : changed_fields.map(&:to_s),
      missing_fields: profile_status.missing_fields.map(&:to_s),
      profile_complete: profile_status.complete?
    }
  end

  def sync_tool_state!(tool_context, profile_status)
    return unless tool_context&.state

    tool_context.state[:contact] = profile_status.public_contact_attributes.slice(
      *Captain::Assistant::RunnerStateHelper::CONTACT_STATE_ATTRIBUTES
    )
    tool_context.state[:contact_profile] = {
      complete: profile_status.complete?,
      missing_fields: profile_status.missing_fields.map(&:to_s)
    }
  end
end
