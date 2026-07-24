class Contacts::PermissionFilterService
  attr_reader :contacts, :user, :account

  def initialize(contacts, user, account)
    @contacts = contacts
    @user = user
    @account = account
  end

  def perform
    return contacts unless account.feature_enabled?('strict_team_conversation_visibility')
    return Contact.none if user.blank?
    return contacts if account.account_users.find_by(user_id: user.id)&.administrator?

    visible_conversations = Conversations::PermissionFilterService.new(account.conversations, user, account).perform
    contacts.where(id: visible_conversations.select(:contact_id))
  end
end
