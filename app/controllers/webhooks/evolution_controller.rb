class Webhooks::EvolutionController < ActionController::API
  ALLOWED_PAYLOAD_KEYS = %w[event instance date_time data].freeze
  SENSITIVE_PAYLOAD_KEYS = %w[
    apikey
    jwt_key
    token
    secret
    base64
    code
    pairingcode
    pairing_code
    qrcode
  ].freeze

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
    payload = params.to_unsafe_h.slice(*ALLOWED_PAYLOAD_KEYS)
    payload['data'] =
      if normalized_event_name(payload['event']) == 'qrcode_updated'
        {}
      else
        deep_sanitize(payload['data'])
      end
    payload.compact
  end

  def deep_sanitize(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, nested_value), sanitized|
        next if key.to_s.downcase.in?(SENSITIVE_PAYLOAD_KEYS)

        sanitized[key] = deep_sanitize(nested_value)
      end
    when Array
      value.map { |item| deep_sanitize(item) }
    else
      value
    end
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
