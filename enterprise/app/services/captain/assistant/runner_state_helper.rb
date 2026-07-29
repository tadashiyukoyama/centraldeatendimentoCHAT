module Captain::Assistant::RunnerStateHelper
  CONVERSATION_STATE_ATTRIBUTES = %i[
    id display_id inbox_id contact_id status priority
    label_list custom_attributes additional_attributes
  ].freeze

  CONTACT_STATE_ATTRIBUTES = %i[
    id name email phone_number identifier contact_type
    custom_attributes additional_attributes
  ].freeze

  CONTACT_INBOX_STATE_ATTRIBUTES = %i[id hmac_verified].freeze

  CAMPAIGN_STATE_ATTRIBUTES = %i[id title message campaign_type description].freeze

  private

  def build_state
    state = {
      account_id: @assistant.account_id,
      assistant_id: @assistant.id,
      assistant_config: @assistant.config,
      timezone: @conversation&.inbox&.timezone.presence || 'UTC'
    }
    state[:source] = @source if @source.present?

    if @conversation
      state[:lead_origin] = Captain::Conversation::OriginResolver.new(@conversation).perform
      state[:greeting_only] = Captain::Conversation::GreetingPolicy.new(@conversation).greeting_only?
      build_conversation_state(state)
    end
    state
  end

  def build_conversation_state(state)
    state[:conversation] = slice_attrs(@conversation, CONVERSATION_STATE_ATTRIBUTES)
    state[:channel_type] = @conversation.inbox&.channel_type
    state[:contact] = contact_state(@conversation.contact) if @conversation.contact
    state[:campaign] = slice_attrs(@conversation.campaign, CAMPAIGN_STATE_ATTRIBUTES) if @conversation.campaign
    state[:contact_inbox] = slice_attrs(@conversation.contact_inbox, CONTACT_INBOX_STATE_ATTRIBUTES) if @conversation.contact_inbox
  end

  def slice_attrs(record, keys)
    record.attributes.symbolize_keys.slice(*keys)
  end

  def contact_state(contact)
    Captain::Conversation::ContactProfileStatus.new(contact)
                                               .public_contact_attributes
                                               .slice(*CONTACT_STATE_ATTRIBUTES)
  end
end
