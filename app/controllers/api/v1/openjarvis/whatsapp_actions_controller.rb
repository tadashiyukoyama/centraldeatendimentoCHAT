class Api::V1::Openjarvis::WhatsappActionsController < Api::V1::Openjarvis::BaseController
  MAX_REACTION_BYTES = 64

  def reaction
    require_scope!('messages:react')
    validate_reaction!
    execute_idempotently(
      'messages.reaction',
      { conversation_id: conversation.display_id, message_id: message.id, reaction: reaction_value }
    ) do
      result = action_service.react(message: message, reaction: reaction_value)
      idempotent_result(status: :ok, body: { data: result }, resource: message)
    end
  end

  def mark_read
    require_scope!('messages:read_receipts')
    execute_idempotently('messages.provider_read', { conversation_id: conversation.display_id }) do
      result = action_service.mark_read
      idempotent_result(status: :ok, body: { data: result }, resource: conversation)
    end
  end

  private

  def conversation
    identifier = params[:conversation_id] || params[:id]
    @conversation ||= openjarvis_access_scope.conversation!(identifier)
  end

  def message
    @message ||= conversation.messages.find(params[:id])
  end

  def reaction_value
    @reaction_value ||= params.require(:reaction).to_s
  end

  def validate_reaction!
    return if reaction_value.empty?
    return if reaction_value.bytesize <= MAX_REACTION_BYTES &&
              reaction_value.scan(/\X/).one? && reaction_value.match?(/\p{Emoji}/)

    raise Openjarvis::ApiError.new(
      'invalid_reaction',
      'reaction must be one emoji or an empty string',
      status: :bad_request
    )
  end

  def action_service
    @action_service ||= Openjarvis::WhatsappActionService.new(conversation: conversation)
  end
end
