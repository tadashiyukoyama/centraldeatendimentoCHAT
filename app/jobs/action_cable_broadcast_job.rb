class ActionCableBroadcastJob < ApplicationJob
  queue_as :critical
  include Events::Types

  CONVERSATION_UPDATE_EVENTS = [
    CONVERSATION_READ,
    CONVERSATION_UPDATED,
    TEAM_CHANGED,
    ASSIGNEE_CHANGED,
    CONVERSATION_STATUS_CHANGED
  ].freeze
  CONVERSATION_SCOPED_EVENTS = [
    MESSAGE_CREATED,
    MESSAGE_UPDATED,
    FIRST_REPLY_CREATED,
    CONVERSATION_CREATED,
    CONVERSATION_READ,
    CONVERSATION_STATUS_CHANGED,
    CONVERSATION_UPDATED,
    CONVERSATION_TYPING_ON,
    CONVERSATION_TYPING_OFF,
    ASSIGNEE_CHANGED,
    TEAM_CHANGED,
    CONVERSATION_CONTACT_CHANGED,
    CONVERSATION_MENTIONED
  ].freeze
  CONTACT_SCOPED_EVENTS = [CONTACT_CREATED, CONTACT_UPDATED, CONTACT_MERGED].freeze
  NOTIFICATION_SCOPED_EVENTS = [NOTIFICATION_CREATED, NOTIFICATION_UPDATED].freeze

  def perform(members, event_name, data)
    return if members.blank?

    broadcast_data = prepare_broadcast_data(event_name, data)
    permitted_members = authorized_members(members, event_name, broadcast_data)
    broadcast_to_members(permitted_members, event_name, broadcast_data)
  end

  private

  # Ensures that only the latest available data is sent to prevent UI issues
  # caused by out-of-order events during high-traffic periods. This prevents
  # the conversation job from processing outdated data.
  def prepare_broadcast_data(event_name, data)
    return data unless CONVERSATION_UPDATE_EVENTS.include?(event_name)

    account = Account.find(data[:account_id])
    conversation = account.conversations.find_by!(display_id: data[:id])
    conversation.push_event_data.merge(account_id: data[:account_id])
  end

  def authorized_members(members, event_name, data)
    conversation = conversation_for_event(event_name, data)
    contact = contact_for_event(event_name, data)
    notification = notification_for_event(event_name, data)
    account = conversation&.account || contact&.account || notification&.account
    return members if account.blank?
    return members unless account.feature_enabled?('strict_team_conversation_visibility')

    users_by_token = User.where(pubsub_token: members).index_by(&:pubsub_token)
    visible_user_tokens = if conversation.present?
                            Conversations::VisibleUsersService.new(
                              conversation: conversation,
                              users: users_by_token.values
                            ).perform.map(&:pubsub_token)
                          else
                            resource_visible_user_tokens(contact, notification, users_by_token.values)
                          end

    (members - users_by_token.keys + visible_user_tokens).uniq
  end

  def conversation_for_event(event_name, data)
    return unless CONVERSATION_SCOPED_EVENTS.include?(event_name)

    payload = data.with_indifferent_access
    account = Account.find_by(id: payload[:account_id])
    return if account.blank?

    display_id = if [MESSAGE_CREATED, MESSAGE_UPDATED, FIRST_REPLY_CREATED].include?(event_name)
                   payload[:conversation_id]
                 elsif [CONVERSATION_TYPING_ON, CONVERSATION_TYPING_OFF].include?(event_name)
                   payload.dig(:conversation, :id)
                 else
                   payload[:id]
                 end
    account.conversations.find_by(display_id: display_id)
  end

  def contact_for_event(event_name, data)
    return unless CONTACT_SCOPED_EVENTS.include?(event_name)

    payload = data.with_indifferent_access
    Account.find_by(id: payload[:account_id])&.contacts&.find_by(id: payload[:id])
  end

  def notification_for_event(event_name, data)
    return unless NOTIFICATION_SCOPED_EVENTS.include?(event_name)

    payload = data.with_indifferent_access
    Notification.find_by(id: payload.dig(:notification, :id), account_id: payload[:account_id])
  end

  def resource_visible_user_tokens(contact, notification, users)
    return contact_visible_user_tokens(contact, users) if contact.present?

    notification_visible_user_tokens(notification, users)
  end

  def contact_visible_user_tokens(contact, users)
    users.select { |user| contact_visible_to_user?(contact, user) }.map(&:pubsub_token)
  end

  def contact_visible_to_user?(contact, user)
    Contacts::PermissionFilterService.new(Contact.where(id: contact.id), user, contact.account).perform.exists?
  end

  def notification_visible_user_tokens(notification, users)
    conversation = notification.conversation
    return [] if conversation.blank?

    Conversations::VisibleUsersService.new(conversation: conversation, users: users).perform.map(&:pubsub_token)
  end

  def broadcast_to_members(members, event_name, broadcast_data)
    members.each do |member|
      ActionCable.server.broadcast(
        member,
        {
          event: event_name,
          data: broadcast_data
        }
      )
    end
  end
end
