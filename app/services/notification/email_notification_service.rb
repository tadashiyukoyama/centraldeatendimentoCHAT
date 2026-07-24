class Notification::EmailNotificationService
  pattr_initialize [:notification!]

  def perform
    # don't send emails if user read the push notification already
    return if notification.read_at.present?
    # don't send emails if user is not confirmed
    return if notification.user.confirmed_at.nil?
    return unless conversation_accessible?
    return unless user_subscribed_to_notification?
    return unless notification.account.within_email_rate_limit?

    send_notification_email
    notification.account.increment_email_sent_count
  end

  private

  # TODO : Clean up whatever happening over here
  # Segregate the mailers properly
  def send_notification_email
    AgentNotifications::ConversationNotificationsMailer.with(account: notification.account).public_send(
      notification.notification_type.to_s, notification.primary_actor, notification.user, notification.secondary_actor
    ).deliver_later
  end

  def user_subscribed_to_notification?
    notification_setting = notification.user.notification_settings.find_by(account_id: notification.account.id)
    return true if notification_setting.public_send("email_#{notification.notification_type}?")

    false
  end

  def conversation_accessible?
    return true unless notification.account.feature_enabled?('strict_team_conversation_visibility')

    Conversations::PermissionFilterService.new(
      notification.account.conversations.where(id: notification.primary_actor_id),
      notification.user,
      notification.account
    ).perform.exists?
  end
end
