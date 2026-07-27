class Webhooks::InstagramCommentEventsJob < ApplicationJob
  queue_as :default

  SUPPORTED_FIELDS = %w[comments live_comments].freeze

  def perform(entries)
    Array(entries).each { |entry| process_entry(entry.with_indifferent_access) }
  end

  private

  def process_entry(entry)
    channel = find_channel(entry[:id])
    return log_missing_channel(entry[:id]) if channel.blank?

    changes(entry).each do |change|
      change = change.with_indifferent_access
      next unless SUPPORTED_FIELDS.include?(change[:field].to_s)

      payloads(change[:value]).each do |payload|
        ingest_payload(channel, change, payload, entry)
      end
    end
  end

  def ingest_payload(channel, change, payload, entry)
    return unless payload.respond_to?(:with_indifferent_access)

    Instagram::CommentAutomation::EventIngestor.new(
      channel: channel,
      webhook_field: change[:field],
      payload: payload,
      entry_time: entry[:time]
    ).call
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[InstagramCommentWebhook] Invalid normalized event errors=#{e.record.errors.attribute_names.join(',')}")
    ChatwootExceptionTracker.new(e, account: channel.account).capture_exception
  end

  def payloads(value)
    value.is_a?(Array) ? value : [value]
  end

  def changes(entry)
    normalized = Array(entry[:changes])
    return normalized unless SUPPORTED_FIELDS.include?(entry[:field].to_s)

    normalized + [{ field: entry[:field], value: entry[:value] }]
  end

  def find_channel(instagram_id)
    Channel::Instagram.find_by(instagram_id: instagram_id) ||
      Channel::FacebookPage.find_by(instagram_id: instagram_id)
  end

  def log_missing_channel(instagram_id)
    Rails.logger.warn("[InstagramCommentWebhook] No channel for Instagram account #{instagram_id}")
  end
end
