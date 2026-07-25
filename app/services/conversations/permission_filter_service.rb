class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account)
    @conversations = conversations
    @user = user
    @account = account
  end

  def perform
    return conversations if user_role == 'administrator'

    accessible_conversations
  end

  private

  def accessible_conversations
    inbox_conversations = conversations.where(inbox: user.inboxes.where(account_id: account.id))
    return inbox_conversations unless strict_team_visibility?

    strict_team_conversations(inbox_conversations)
  end

  def strict_team_conversations(inbox_conversations)
    inbox_conversations.where(team: user.teams.where(account_id: account.id))
  end

  def strict_team_visibility?
    account.feature_enabled?('strict_team_conversation_visibility')
  end

  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
