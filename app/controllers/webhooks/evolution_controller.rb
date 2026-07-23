class Webhooks::EvolutionController < ActionController::API
  def process_payload
    provisioning = Whatsapp::EvolutionProvisioning.active.find_by!(public_id: params[:public_id])
    payload = sanitized_payload
    Whatsapp::Evolution::WebhookAuthenticator.new(
      provisioning: provisioning,
      authorization_header: request.authorization,
      payload: payload
    ).verify!

    event = create_event(provisioning, payload)
    enqueue_event(event, payload)
    head :accepted
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue Whatsapp::Evolution::WebhookAuthenticator::AuthenticationError
    head :unauthorized
  end

  private

  def sanitized_payload
    payload = params.to_unsafe_h.except('controller', 'action', 'public_id', 'apikey')
    payload['data'] = sanitize_qr_data(payload['data']) if normalized_event_name(payload['event']) == 'qrcode_updated'
    payload
  end

  def sanitize_qr_data(data)
    data.to_h.except('base64', 'code', 'pairingCode', 'pairing_code', 'qrcode')
  end

  def normalized_event_name(value)
    value.to_s.downcase.tr('.', '_')
  end

  def create_event(provisioning, payload)
    event_key = Whatsapp::Evolution::EventKey.new(provisioning: provisioning, payload: payload).generate
    provisioning.events.create_or_find_by!(event_key: event_key) do |event|
      event.event_type = normalized_event_name(payload['event'])
    end
  end

  def enqueue_event(event, payload)
    should_enqueue = event.with_lock do
      next false unless event.pending? || event.failed?

      event.update!(status: :queued)
      true
    end
    return unless should_enqueue

    Webhooks::EvolutionEventsJob.perform_later(event.id, payload)
  rescue StandardError
    event.update!(status: :pending) if event&.queued?
    raise
  end
end
