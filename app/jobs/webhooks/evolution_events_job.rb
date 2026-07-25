class Webhooks::EvolutionEventsJob < MutexApplicationJob
  queue_as :low
  self.log_arguments = false

  discard_on ActiveRecord::RecordNotFound
  retry_on LockAcquisitionError, wait: 2.seconds, attempts: 20
  retry_on Whatsapp::Evolution::ApiClient::Error, wait: :polynomially_longer, attempts: 5

  def perform(event_id, payload)
    event = Whatsapp::EvolutionEvent.find(event_id)
    sender_id = contact_sender_id(payload)
    return process_event(event, payload) if sender_id.blank?

    key = format(
      ::Redis::Alfred::WHATSAPP_MESSAGE_MUTEX,
      inbox_id: "evolution-#{event.provisioning_id}",
      sender_id: sender_id
    )
    with_lock(key, 30.seconds) { process_event(event, payload) }
  end

  private

  def process_event(event, payload)
    Whatsapp::Evolution::WebhookProcessor.new(event: event, payload: payload).perform
  end

  # Message webhooks for the same contact can arrive concurrently (especially albums).
  # Status and connection events do not create conversations and bypass this lock.
  def contact_sender_id(payload)
    normalized = payload.deep_stringify_keys
    return unless normalized['event'].to_s.downcase.tr('.', '_').in?(%w[messages_upsert send_message])

    key = normalized.dig('data', 'key') || {}
    [key['remoteJidAlt'], key['remoteJid']].compact_blank.find do |jid|
      jid.end_with?('@s.whatsapp.net', '@lid')
    end
  end
end
