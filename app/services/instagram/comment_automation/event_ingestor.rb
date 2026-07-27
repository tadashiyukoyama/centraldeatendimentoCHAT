class Instagram::CommentAutomation::EventIngestor
  def initialize(channel:, webhook_field:, payload:, entry_time:)
    @channel = channel
    @inbox = channel.inbox
    @webhook_field = webhook_field.to_s
    @payload = payload.with_indifferent_access
    @entry_time = entry_time
  end

  def call
    return if invalid_payload?

    event, created = find_or_create_event
    return event unless created

    match_and_enqueue(event)
    event
  rescue ActiveRecord::RecordNotUnique
    @inbox.instagram_comment_events.find_by!(comment_id: comment_id)
  end

  private

  def find_or_create_event
    event = @inbox.instagram_comment_events.find_or_initialize_by(comment_id: comment_id)
    return [event, false] if event.persisted?

    event.assign_attributes(event_attributes)
    event.save!
    [event, true]
  end

  def event_attributes
    {
      account: @inbox.account,
      sender_id: @payload.dig(:from, :id)&.to_s,
      sender_username: @payload.dig(:from, :username)&.to_s,
      media_id: @payload.dig(:media, :id)&.to_s,
      media_product_type: @payload.dig(:media, :media_product_type)&.to_s,
      parent_comment_id: (@payload[:parent_id] || @payload[:parent_comment_id])&.to_s,
      comment_text: @payload[:text].to_s,
      webhook_field: @webhook_field,
      received_at: occurred_at
    }
  end

  def match_and_enqueue(event)
    return ignore_event(event, 'self_comment') if self_comment?

    match = find_match(event)
    return ignore_event(event, 'no_matching_rule') unless match

    apply_match(event, match)
    Instagram::CommentAutomation::ProcessEventJob.perform_later(event.id)
  end

  def find_match(event)
    Instagram::CommentAutomation::KeywordMatcher.new(
      inbox: @inbox,
      text: event.comment_text,
      media_id: event.media_id,
      nested_reply: event.parent_comment_id.present?,
      occurred_at: event.received_at
    ).call
  end

  def apply_match(event, match)
    automation = match.automation
    event.update!(
      instagram_comment_automation: automation,
      matched_keyword: match.keyword,
      status: :matched,
      public_reply_status: automation.public_reply_enabled? ? :pending : :not_requested,
      private_reply_status: automation.private_reply_enabled? ? :pending : :not_requested
    )
  end

  def ignore_event(event, reason)
    event.update!(status: :ignored, ignore_reason: reason, processed_at: Time.current)
  end

  def self_comment?
    @payload.dig(:from, :id).to_s == @channel.instagram_id.to_s
  end

  def comment_id
    @payload[:id].to_s
  end

  def occurred_at
    timestamp = Integer(@entry_time)
    timestamp /= 1000.0 if timestamp > 10_000_000_000
    Time.zone.at(timestamp)
  rescue ArgumentError, TypeError
    Time.current
  end

  def invalid_payload?
    missing = {
      comment_id: comment_id,
      media_id: @payload.dig(:media, :id),
      comment_text: @payload[:text]
    }.select { |_key, value| value.blank? }.keys
    return false if missing.empty?

    Rails.logger.warn("[InstagramCommentWebhook] Ignored malformed event missing=#{missing.join(',')}")
    true
  end
end
