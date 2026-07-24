class Conversations::VisibleUsersService
  attr_reader :conversation, :users, :account

  def initialize(conversation:, users:)
    @conversation = conversation
    @users = users
    @account = conversation.account
  end

  def perform
    user_list = users.to_a
    return user_list unless account.feature_enabled?('strict_team_conversation_visibility')

    account_users = account.account_users.where(user_id: user_list.map(&:id)).index_by(&:user_id)
    candidate_ids = strict_candidate_ids(account_users)
    user_list.select { |user| visible_user?(user, account_users[user.id], candidate_ids) }
  end

  private

  def visible_user?(user, account_user, candidate_ids)
    return false if account_user.blank? || candidate_ids.exclude?(user.id)
    return true if account_user.administrator? || account_user.custom_role_id.blank?

    ConversationPolicy.new(
      { user: user, account: account, account_user: account_user },
      conversation
    ).show?
  end

  def strict_candidate_ids(account_users)
    user_ids = account_users.keys
    administrator_ids = account_users.values.select(&:administrator?).map(&:user_id)
    (administrator_ids + (agent_candidate_ids(user_ids) & inbox_member_ids(user_ids))).compact.uniq
  end

  def agent_candidate_ids(user_ids)
    team_member_ids(user_ids) + [conversation.assignee_id] + participant_ids(user_ids)
  end

  def team_member_ids(user_ids)
    return [] if conversation.team_id.blank?

    conversation.team.members.where(id: user_ids).pluck(:id)
  end

  def participant_ids(user_ids)
    conversation.conversation_participants.where(user_id: user_ids).pluck(:user_id)
  end

  def inbox_member_ids(user_ids)
    conversation.inbox.members.where(id: user_ids).pluck(:id)
  end
end
