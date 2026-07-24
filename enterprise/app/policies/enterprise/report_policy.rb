module Enterprise::ReportPolicy
  def view?
    return super if account.feature_enabled?('strict_team_conversation_visibility')

    @account_user.custom_role&.permissions&.include?('report_manage') || super
  end
end
