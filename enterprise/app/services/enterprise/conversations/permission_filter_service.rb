module Enterprise::Conversations::PermissionFilterService
  def perform
    return strict_manager_conversations if strict_manager?
    return super if account.feature_enabled?('strict_team_conversation_visibility')
    return filter_by_permissions(permissions) if user_has_custom_role?

    super
  end

  private

  def user_has_custom_role?
    user_role == 'agent' && account_user&.custom_role_id.present?
  end

  def strict_manager?
    account.feature_enabled?('strict_team_conversation_visibility') &&
      user_has_custom_role? && permissions.include?('conversation_manage')
  end

  def strict_manager_conversations
    conversations.where(inbox: user.inboxes.where(account_id: account.id))
  end

  def permissions
    account_user&.permissions || []
  end

  def filter_by_permissions(permissions)
    # Permission-based filtering with hierarchy
    # conversation_manage > conversation_unassigned_manage > conversation_participating_manage
    if permissions.include?('conversation_manage')
      accessible_conversations
    elsif permissions.include?('conversation_unassigned_manage')
      filter_unassigned_and_mine
    elsif permissions.include?('conversation_participating_manage')
      filter_participating_and_mine
    else
      Conversation.none
    end
  end

  def filter_participating_and_mine
    conversations = accessible_conversations
    participant_conversation_ids = ConversationParticipant.where(account_id: account.id, user_id: user.id).select(:conversation_id)

    conversations
      .where(assignee_id: user.id)
      .or(conversations.where(id: participant_conversation_ids))
  end

  def filter_unassigned_and_mine
    accessible_conversations.where(assignee_id: [nil, user.id])
  end
end
