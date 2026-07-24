module Enterprise::ContactPolicy
  def export?
    return super if account.feature_enabled?('strict_team_conversation_visibility')

    @account_user.custom_role&.permissions&.include?('contact_manage') || super
  end

  def import?
    return super if account.feature_enabled?('strict_team_conversation_visibility')

    @account_user.custom_role&.permissions&.include?('contact_manage') || super
  end
end
