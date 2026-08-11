module Concerns::Agentable
  extend ActiveSupport::Concern

  DEFAULT_TEMPERATURE = 0.5
  BOOLEAN_TYPE = ActiveModel::Type::Boolean.new.freeze

  def agent(tools: agent_tools)
    Agents::Agent.new(
      name: agent_name,
      instructions: ->(context) { agent_instructions(context) },
      tools: tools,
      model: agent_model,
      temperature: temperature.presence&.to_f || DEFAULT_TEMPERATURE,
      params: agent_provider_params,
      response_schema: agent_response_schema
    )
  end

  def agent_instructions(context = nil)
    enhanced_context = prompt_context
    enhanced_context = enhanced_context.merge(agent_runtime_context(context)) if context

    Captain::PromptRenderer.render(template_name, enhanced_context.with_indifferent_access)
  end

  def agent_model
    route = Llm::FeatureRouter.resolve(feature: 'assistant', account: account)
    return route[:model] if route[:source] == :account_override || account&.feature_enabled?('captain_integration_v2')

    installation_model.presence || route[:model]
  end

  private

  def agent_provider_params
    return {} unless agent_model.to_s.start_with?('gpt-5')

    # Captain uses function tools through the Chat Completions adapter in the
    # current ai-agents/RubyLLM stack. OpenAI rejects reasoning_effort=low for
    # gpt-5.4-mini on that endpoint when tools are present. `none` keeps the
    # configured model and makes the tool-enabled request valid until Captain
    # is migrated to the Responses API.
    { reasoning_effort: 'none' }
  end

  def agent_name
    raise NotImplementedError, "#{self.class} must implement agent_name"
  end

  def template_name
    self.class.name.demodulize.underscore
  end

  def agent_tools
    []  # Default implementation, override if needed
  end

  def installation_model
    InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value
  end

  def agent_contact_context(config, state)
    return { contact: nil, contact_profile: nil } unless BOOLEAN_TYPE.cast(config['feature_contact_attributes'])

    {
      contact: state[:contact],
      contact_profile: state[:contact_profile]
    }
  end

  def agent_runtime_context(context)
    state = context.context.fetch(:state, {})
    config = state.fetch(:assistant_config, {})
    {
      current_time: format_current_time(state[:timezone]),
      conversation_timezone: state[:timezone].presence || 'UTC',
      conversation: state.fetch(:conversation, {}),
      campaign: state.fetch(:campaign, {}),
      lead_origin: state[:lead_origin],
      greeting_only: state[:greeting_only],
      commercial_turn: state.fetch(:commercial_turn, {}),
      commercial_validation_feedback: state.fetch(:commercial_validation_feedback, []),
      commercial_retry: state.fetch(:commercial_retry, {}),
      **agent_contact_context(config, state)
    }
  end

  def agent_response_schema
    return Captain::CommercialResponseSchema if commercial_response_contract_enabled?

    Captain::ResponseSchema
  end

  def commercial_response_contract_enabled?
    owner_config = if respond_to?(:config)
                     config
                   elsif respond_to?(:assistant)
                     assistant.config
                   else
                     {}
                   end
    BOOLEAN_TYPE.cast(owner_config.to_h['feature_commercial_response_contract'])
  end

  def format_current_time(timezone)
    tz = ActiveSupport::TimeZone[timezone] if timezone.present?
    time = tz ? Time.current.in_time_zone(tz) : Time.current
    time.iso8601
  end

  def prompt_context
    raise NotImplementedError, "#{self.class} must implement prompt_context"
  end
end
