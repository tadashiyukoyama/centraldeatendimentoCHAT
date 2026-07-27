class Instagram::CommentAutomation::ConversationLinker
  def initialize(inbox:, recipient_id:, conversation: nil)
    @inbox = inbox
    @recipient_id = recipient_id.to_s
    @conversation = conversation
  end

  def call
    return if @recipient_id.blank?

    event = eligible_event
    return if event.blank?

    conversation = find_conversation
    return if conversation.blank?

    ActiveRecord::Base.transaction do
      conversation.with_lock do
        conversation.update!(
          additional_attributes: merged_attributes(conversation, event),
          **assistant_routing_attributes(conversation)
        )
        conversation.add_labels(event.instagram_comment_automation.conversation_label)
      end
      event.update!(conversation: conversation)
    end

    conversation
  end

  private

  def eligible_event
    @inbox.instagram_comment_events
          .where(private_reply_recipient_id: @recipient_id, conversation_id: nil)
          .where.not(instagram_comment_automation_id: nil)
          .private_reply_succeeded
          .where(created_at: 7.days.ago..)
          .order(created_at: :desc)
          .first
  end

  def find_conversation
    return @conversation if @conversation.present?

    contact_inbox = @inbox.contact_inboxes.find_by(source_id: @recipient_id)
    contact_inbox&.contact&.conversations&.where(inbox: @inbox)&.order(created_at: :desc)&.first
  end

  def merged_attributes(conversation, event)
    automation = event.instagram_comment_automation
    conversation.additional_attributes.to_h.merge(
      'instagram_comment_campaign' => {
        'automation_id' => automation.id,
        'automation_name' => automation.name,
        'comment_id' => event.comment_id,
        'media_id' => event.media_id,
        'matched_keyword' => event.matched_keyword,
        'context' => automation.conversation_context,
        'matched_at' => event.received_at.iso8601
      }.compact
    )
  end

  def assistant_routing_attributes(conversation)
    return {} unless @inbox.respond_to?(:captain_assistant)
    return {} if @inbox.association(:captain_assistant).reload.blank?
    return {} if conversation.pending? && conversation.assignee_id.blank? && conversation.team_id.blank?

    {
      status: :pending,
      assignee_id: nil,
      assignee_agent_bot_id: nil,
      team_id: nil,
      waiting_since: nil
    }
  end
end
