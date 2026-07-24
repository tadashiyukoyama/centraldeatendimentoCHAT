class Conversations::ActionCableVisibilityService
  attr_reader :account

  def initialize(account)
    @account = account
  end

  def contact_tokens(contact, fallback_token)
    return [fallback_token] unless strict_team_visibility?

    conversations = account.conversations.where(contact_id: contact.id)
    visible_agents = account.agents.select do |agent|
      Conversations::PermissionFilterService.new(conversations, agent, account).perform.exists?
    end
    user_tokens(visible_agents)
  end

  def deleted_contact_tokens(fallback_token)
    strict_team_visibility? ? user_tokens(User.none) : [fallback_token]
  end

  def revoked_tokens(conversation, event, attribute)
    return [] unless strict_team_visibility?

    previous_users = previous_users(conversation, event, attribute)
    return [] if previous_users.blank?

    visible_user_ids = Conversations::VisibleUsersService.new(
      conversation: conversation,
      users: previous_users
    ).perform.map(&:id)
    previous_users.reject { |user| visible_user_ids.include?(user.id) }.map(&:pubsub_token)
  end

  private

  def previous_users(conversation, event, attribute)
    previous_id = event.data[:changed_attributes]&.with_indifferent_access&.dig(attribute)&.first
    return [] if previous_id.blank?
    return account.users.where(id: previous_id).to_a if attribute == :assignee_id

    previous_team = account.teams.find_by(id: previous_id)
    return [] if previous_team.blank?

    previous_team.members.where(id: conversation.inbox.members.select(:id)).to_a
  end

  def user_tokens(agents)
    (agents.pluck(:pubsub_token) + account.administrators.pluck(:pubsub_token)).uniq
  end

  def strict_team_visibility?
    account.feature_enabled?('strict_team_conversation_visibility')
  end
end
