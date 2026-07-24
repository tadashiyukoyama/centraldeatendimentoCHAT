module Enterprise::CsatSurveyResponsePolicy
  def index?
    return super if account.feature_enabled?('strict_team_conversation_visibility')

    @account_user.custom_role&.permissions&.include?('report_manage') || super
  end

  def metrics?
    return super if account.feature_enabled?('strict_team_conversation_visibility')

    @account_user.custom_role&.permissions&.include?('report_manage') || super
  end

  def download?
    return super if account.feature_enabled?('strict_team_conversation_visibility')

    @account_user.custom_role&.permissions&.include?('report_manage') || super
  end

  def update?
    return @account_user.administrator? if account.feature_enabled?('strict_team_conversation_visibility')

    @account_user.administrator? || @account_user.custom_role&.permissions&.include?('report_manage')
  end
end
