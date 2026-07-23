class Whatsapp::Evolution::EventKey
  def initialize(provisioning:, payload:)
    @provisioning = provisioning
    @payload = payload.deep_stringify_keys
  end

  def generate
    identifier = message_identifier || connection_identifier || payload_digest
    Digest::SHA256.hexdigest("#{provisioning.id}:#{event_type}:#{identifier}")
  end

  private

  attr_reader :provisioning, :payload

  def event_type
    payload['event'].to_s.downcase.tr('.', '_')
  end

  def message_identifier
    data = payload['data']
    return unless data.is_a?(Hash)

    identifier = data.dig('key', 'id') || data['keyId'] || data['messageId'] || data['id']
    return unless identifier
    return [identifier, data['status']].compact.join(':') if event_type == 'messages_update'

    identifier
  end

  def connection_identifier
    return unless event_type == 'connection_update'

    data = payload['data'].to_h
    [data['state'], data['wuid'], data['profileName'], payload['date_time']].compact.join(':').presence
  end

  def payload_digest
    Digest::SHA256.hexdigest(JSON.generate(deep_sort(payload)))
  end

  def deep_sort(value)
    case value
    when Hash
      value.keys.sort.index_with { |key| deep_sort(value[key]) }
    when Array
      value.map { |item| deep_sort(item) }
    else
      value
    end
  end
end
