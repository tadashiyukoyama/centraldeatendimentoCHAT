class Captain::Tools::HandoffTool < Captain::Tools::BasePublicTool
  DESTINATIONS = {
    'owner' => 'owner',
    'financeiro' => 'financeiro',
    'contas_a_pagar' => 'contas a pagar',
    'rh' => 'rh',
    'gerencia' => 'gerencia',
    'representante' => 'representante',
    'suporte' => 'suporte'
  }.freeze

  description 'Hand off the conversation to the owner or a department'
  param :reason, type: 'string', desc: 'The reason why handoff is needed (optional)', required: false
  param :destination,
        type: 'string',
        desc: 'Use owner, financeiro, contas_a_pagar, rh, gerencia, representante, or suporte. Optional.',
        required: false

  def perform(tool_context, reason: nil, destination: nil)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    destination_key = normalize_destination(destination)
    return invalid_destination_message if invalid_destination?(destination, destination_key)

    eligibility = Captain::Conversation::HandoffEligibility.new(conversation)
    return eligibility.denied_message unless eligibility.allowed?

    log_handoff(conversation, reason, destination_key)
    trigger_handoff(conversation, reason, destination_key)

    handoff_response(conversation, destination_key, reason)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    'Failed to handoff conversation'
  end

  def perform_trusted(conversation:, reason:, destination:, assignee: nil, team: nil)
    return 'Conversation not found' unless conversation&.account_id == @assistant.account_id

    destination_key = normalize_destination(destination)
    return invalid_destination_message if invalid_destination?(destination, destination_key)

    routing_error = trusted_routing_error(assignee, team)
    return routing_error if routing_error

    log_handoff(conversation, reason, destination_key)
    trigger_handoff(conversation, reason, destination_key, assignee: assignee, team: team)
    handoff_response(conversation, destination_key, reason)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    'Failed to handoff conversation'
  end

  private

  def trusted_routing_error(assignee, team)
    return 'Invalid assignee for this account' if assignee && !@assistant.account.users.exists?(id: assignee.id)
    return 'Invalid team for this account' if team && !@assistant.account.teams.exists?(id: team.id)
  end

  def normalize_destination(destination)
    destination.to_s.strip.downcase.tr(' ', '_')
  end

  def invalid_destination?(destination, destination_key)
    destination.present? && !DESTINATIONS.key?(destination_key)
  end

  def invalid_destination_message
    "Invalid destination. Use one of: #{DESTINATIONS.keys.join(', ')}"
  end

  def log_handoff(conversation, reason, destination_key)
    log_tool_usage('tool_handoff', {
                     conversation_id: conversation.id,
                     reason: reason || 'Agent requested handoff',
                     destination: destination_key.presence || 'human_support'
                   })
  end

  def handoff_response(conversation, destination_key, reason)
    destination_name = DESTINATIONS[destination_key] || 'human support team'
    response = "Conversation handed off to #{destination_name}"
    response = "#{response} (Reason: #{reason})" if reason
    [response, out_of_office_context(conversation)].compact.join('. ')
  end

  def trigger_handoff(conversation, reason, destination, assignee: nil, team: nil)
    route_conversation!(conversation, destination, assignee: assignee, team: team) if destination.present?

    # post the reason as a private note
    conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      sender: @assistant,
      account: conversation.account,
      inbox: conversation.inbox,
      content: handoff_note(reason, destination)
    )

    # Trigger the bot handoff (sets status to open + dispatches events)
    conversation.bot_handoff!
  end

  def handoff_note(reason, destination)
    return reason if destination.blank?

    [reason, "Destino: #{DESTINATIONS.fetch(destination)}"].compact.join("\n")
  end

  def route_conversation!(conversation, destination, assignee: nil, team: nil)
    if destination == 'owner'
      owner = assignee || conversation.account.administrators.order(:id).first
      raise ActiveRecord::RecordNotFound, 'No account administrator is available for owner handoff' unless owner

      conversation.update!(team_id: nil, assignee_id: owner.id)
      return
    end

    team_name = DESTINATIONS.fetch(destination)
    selected_team = team || conversation.account.teams.find_by('LOWER(name) = ?', team_name.downcase)
    raise ActiveRecord::RecordNotFound, "Team '#{team_name}' is not configured" unless selected_team

    conversation.update!(team_id: selected_team.id, assignee_id: nil)
  end

  def out_of_office_context(conversation)
    return if conversation.campaign.present?

    inbox = conversation.inbox
    return unless inbox.out_of_office? && inbox.out_of_office_message.present?

    'Inbox is currently outside configured business hours.'
  end
end
