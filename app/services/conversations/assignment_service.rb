class Conversations::AssignmentService
  def initialize(conversation:, assignee_id:, assignee_type: nil)
    @conversation = conversation
    @assignee_id = assignee_id
    @assignee_type = assignee_type
  end

  def perform
    agent_bot_assignment? ? assign_agent_bot : assign_agent
  end

  private

  attr_reader :conversation, :assignee_id, :assignee_type

  def assign_agent
    conversation.assignee = assignee
    conversation.assignee_agent_bot = nil
    conversation.save!
    assignee
  end

  def assign_agent_bot
    return unless agent_bot

    conversation.assignee = nil
    conversation.assignee_agent_bot = agent_bot
    conversation.save!
    agent_bot
  end

  def assignee
    @assignee ||= if strict_assignment?
                    strict_assignee
                  else
                    conversation.account.users.find_by(id: assignee_id)
                  end
  end

  def strict_assignee
    administrator = conversation.account.administrators.find_by(id: assignee_id)
    return administrator if administrator.present?

    eligible_assignees.find(assignee_id)
  end

  def agent_bot
    @agent_bot ||= AgentBot.accessible_to(conversation.account).find_by(id: assignee_id)
  end

  def agent_bot_assignment?
    assignee_type.to_s == 'AgentBot'
  end

  def eligible_assignees
    inbox_members = conversation.inbox.members
    return inbox_members if conversation.team_id.blank?

    conversation.team.members.merge(inbox_members)
  end

  def strict_assignment?
    assignee_id.present? && conversation.account.feature_enabled?('strict_team_conversation_visibility')
  end
end
