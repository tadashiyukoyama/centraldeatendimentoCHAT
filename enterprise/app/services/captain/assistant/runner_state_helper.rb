module Captain::Assistant::RunnerStateHelper
  CONVERSATION_STATE_ATTRIBUTES = %i[
    id display_id inbox_id contact_id status priority
    label_list custom_attributes additional_attributes
  ].freeze

  CONTACT_STATE_ATTRIBUTES = %i[
    id name email phone_number identifier contact_type
    company_name custom_attributes
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
      build_commercial_turn_state(state) if commercial_response_contract_enabled?
    end
    state
  end

  def build_conversation_state(state)
    state[:conversation] = slice_attrs(@conversation, CONVERSATION_STATE_ATTRIBUTES)
    state[:channel_type] = @conversation.inbox&.channel_type
    if @conversation.contact
      state[:contact] = contact_state(@conversation.contact)
      state[:contact_profile] = contact_profile_state(@conversation.contact)
    end
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

  def contact_profile_state(contact)
    status = Captain::Conversation::ContactProfileStatus.new(contact)
    {
      complete: status.complete?,
      missing_fields: status.missing_fields.map(&:to_s)
    }
  end

  def build_commercial_turn_state(state)
    state[:commercial_turn] = Captain::Conversation::CommercialTurnPolicy.new(conversation: @conversation).perform
  end

  def commercial_response_contract_enabled?
    ActiveModel::Type::Boolean.new.cast(@assistant.config['feature_commercial_response_contract'])
  end

  def repair_runner(tool_names = [])
    @repair_runners ||= {}
    key = Array(tool_names).map(&:to_s).sort.freeze
    @repair_runners[key] ||= begin
      tools = key.map do |tool_name|
        tool_class = @assistant.class.resolve_tool_class(tool_name)
        raise ArgumentError, "Unsupported Captain repair tool: #{tool_name}" unless tool_class

        tool_class.new(@assistant)
      end
      configured_runner = Agents::Runner.with_agents(@assistant.agent(tools: tools))
      configured_runner = add_usage_metadata_callback(configured_runner)
      install_instrumentation(configured_runner)
    end
  end

  def run_payload(message_history)
    message_to_process = extract_last_user_message(message_history)
    context = build_context(message_history_without_last_user_message(message_history))
    enrich_context_with_trace_payload!(context, message_history, message_to_process)
    [message_to_process, context]
  end
end
