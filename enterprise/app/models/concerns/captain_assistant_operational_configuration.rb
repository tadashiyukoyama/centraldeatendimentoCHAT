module Concerns::CaptainAssistantOperationalConfiguration
  extend ActiveSupport::Concern

  included do
    validate :validate_operational_tool_references
    validate :validate_operational_tool_dependencies
  end

  def configured_demo_specialist
    specialist = account.users.find_by(id: config['demo_assignee_id']) if config['demo_assignee_id'].present?
    specialist ||= account.users.find_by('LOWER(email) = ?', config['demo_assignee_email'].to_s.downcase) if
      config['demo_assignee_email'].present?
    specialist
  end

  def configured_finance_team
    account.teams.find_by(id: config['finance_team_id']) if config['finance_team_id'].present?
  end

  def operational_tools_configuration
    demo_specialist = configured_demo_specialist
    finance_team = configured_finance_team

    {
      contact_profile: {
        enabled: feature_enabled?(:feature_contact_attributes),
        ready: true
      },
      demo_scheduling: {
        enabled: feature_enabled?(:feature_demo_scheduling),
        ready: feature_enabled?(:feature_contact_attributes) && demo_specialist.present?,
        assignee_id: demo_specialist&.id
      },
      payment_notices: {
        enabled: feature_enabled?(:feature_payment_notices),
        ready: finance_team.present?,
        finance_team_id: finance_team&.id
      }
    }
  end

  private

  def validate_operational_tool_references
    validate_demo_specialist_reference
    validate_finance_team_reference
  end

  def validate_operational_tool_dependencies
    validate_demo_scheduling_dependencies
    validate_payment_notice_dependencies
  end

  def validate_demo_scheduling_dependencies
    return unless feature_enabled?(:feature_demo_scheduling)

    errors.add(:config, 'contact profile capture must be enabled for demonstration scheduling') unless
      feature_enabled?(:feature_contact_attributes)
    errors.add(:config, 'select a demonstration specialist before enabling scheduling') unless
      configured_demo_specialist
  end

  def validate_payment_notice_dependencies
    return unless feature_enabled?(:feature_payment_notices)
    return if configured_finance_team

    errors.add(:config, 'select a finance team before enabling payment notices')
  end

  def validate_demo_specialist_reference
    return validate_demo_specialist_id if config['demo_assignee_id'].present?
    return if config['demo_assignee_email'].blank?
    return if account&.users&.exists?(['LOWER(email) = ?', config['demo_assignee_email'].to_s.downcase])

    errors.add(:config, 'demo specialist email must belong to the assistant account')
  end

  def validate_demo_specialist_id
    return if account&.users&.exists?(id: config['demo_assignee_id'])

    errors.add(:config, 'demo specialist must belong to the assistant account')
  end

  def validate_finance_team_reference
    return if config['finance_team_id'].blank?
    return if account&.teams&.exists?(id: config['finance_team_id'])

    errors.add(:config, 'finance team must belong to the assistant account')
  end
end
