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

    user_list.select do |user|
      account_user = account_users[user.id]
      next false if account_user.blank? || candidate_ids.exclude?(user.id)
      next true if account_user.administrator? || account_user.custom_role_id.blank?

      ConversationPolicy.new(
        { user: user, account: account, account_user: account_user },
        conversation
      ).show?
    end
  end

  private

  def strict_candidate_ids(account_users)
    user_ids = account_users.keys
    ids = account_users.values.select(&:administrator?).map(&:user_id)
    inbox_member_ids = conversation.inbox.members.where(id: user_ids).pluck(:id)
    agent_ids = []
    agent_ids.concat(conversation.team.members.where(id: user_ids).pluck(:id)) if conversation.team_id.present?
    agent_ids << conversation.assignee_id if conversation.assignee_id.present?
    agent_ids.concat(conversation.conversation_participants.where(user_id: user_ids).pluck(:user_id))
    ids.concat(agent_ids & inbox_member_ids)
    ids.compact.uniq
  end
end
