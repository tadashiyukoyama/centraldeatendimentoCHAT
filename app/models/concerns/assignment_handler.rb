module AssignmentHandler
  extend ActiveSupport::Concern
  include Events::Types

  included do
    before_save :ensure_assignee_is_from_team
    after_commit :notify_assignment_change, :process_assignment_changes
  end

  private

  def ensure_assignee_is_from_team
    return unless team_id_changed? || strict_team_assignee_changed?

    validate_current_assignee_team
    self.assignee ||= find_assignee_from_team if team_id_changed?
  end

  def strict_team_assignee_changed?
    strict_team_visibility? && assignee_id_changed? && assignee_id.present?
  end

  def validate_current_assignee_team
    return if administrator_assignee?

    self.assignee_id = nil unless team_assignee? && inbox_assignee?
  end

  def administrator_assignee?
    strict_team_visibility? && account.administrators.exists?(id: assignee_id)
  end

  def team_assignee?
    team.blank? || team.members.include?(assignee)
  end

  def inbox_assignee?
    !strict_team_visibility? || inbox.members.include?(assignee)
  end

  def strict_team_visibility?
    account.feature_enabled?('strict_team_conversation_visibility')
  end

  def find_assignee_from_team
    return if team&.allow_auto_assign.blank?

    team_members_with_capacity = inbox.member_ids_with_assignment_capacity & team.members.ids
    ::AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: team_members_with_capacity).find_assignee
  end

  def notify_assignment_change
    {
      ASSIGNEE_CHANGED => -> { saved_change_to_assignee_id? },
      TEAM_CHANGED => -> { saved_change_to_team_id? }
    }.each do |event, condition|
      condition.call && dispatcher_dispatch(event, previous_changes)
    end
  end

  def process_assignment_changes
    process_assignment_activities
  end

  def process_assignment_activities
    user_name = Current.user.name if Current.user.present?
    if saved_change_to_team_id?
      create_team_change_activity(user_name)
    elsif saved_change_to_assignee_id?
      create_assignee_change_activity(user_name)
    end
  end

  def self_assign?(assignee_id)
    assignee_id.present? && Current.user&.id == assignee_id
  end
end
