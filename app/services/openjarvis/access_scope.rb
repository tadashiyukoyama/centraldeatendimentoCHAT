class Openjarvis::AccessScope
  attr_reader :hook, :configuration, :account, :user

  def initialize(hook)
    @hook = hook
    @configuration = hook.openjarvis_configuration
    @account = hook.account
    @user = configuration.service_user
  end

  def inboxes
    @inboxes ||= begin
      scope = account.inboxes.where(id: configuration.allowed_inbox_ids)
      configuration.account_user&.administrator? ? scope : scope.where(id: user.inboxes.select(:id))
    end
  end

  def conversations
    @conversations ||= Conversations::PermissionFilterService
                       .new(account.conversations, user, account)
                       .perform
                       .where(inbox_id: inboxes.select(:id))
  end

  def contacts
    @contacts ||= begin
      visible_contact_ids = conversations.where.not(contact_id: nil).select(:contact_id)
      created_contact_ids = hook.openjarvis_api_requests
                                .completed
                                .where(resource_type: 'Contact')
                                .select(:resource_id)
      account.contacts.where(id: visible_contact_ids).or(account.contacts.where(id: created_contact_ids))
    end
  end

  def conversation!(display_id)
    conversations.find_by!(display_id: display_id)
  rescue ActiveRecord::RecordNotFound
    raise Openjarvis::ApiError.new('conversation_not_found', 'Conversation was not found or is outside the authorized scope', status: :not_found)
  end

  def contact!(id)
    contacts.find(id)
  rescue ActiveRecord::RecordNotFound
    raise Openjarvis::ApiError.new('contact_not_found', 'Contact was not found or is outside the authorized scope', status: :not_found)
  end

  def inbox!(id)
    inboxes.find(id)
  rescue ActiveRecord::RecordNotFound
    raise Openjarvis::ApiError.new('inbox_not_found', 'Inbox was not found or is outside the authorized scope', status: :not_found)
  end

  def accessible?(resource)
    case resource
    when Message
      conversations.exists?(id: resource.conversation_id)
    when Conversation
      conversations.exists?(id: resource.id)
    when Contact
      contacts.exists?(id: resource.id)
    when Inbox
      inboxes.exists?(id: resource.id)
    else
      false
    end
  end
end
