class Openjarvis::Cursor
  PURPOSE = 'openjarvis.cursor'.freeze
  VERSION = 1

  def self.encode(type:, timestamp:, id:, direction:)
    verifier.generate(
      { version: VERSION, type: type.to_s, timestamp: timestamp.utc.iso8601(6), id: id.to_i, direction: direction.to_s },
      purpose: PURPOSE
    )
  end

  def self.decode(value, type:, direction:)
    payload = verifier.verify(value.to_s, purpose: PURPOSE).with_indifferent_access
    unless payload[:version] == VERSION && payload[:type] == type.to_s && payload[:direction] == direction.to_s
      raise Openjarvis::ApiError.new('cursor_mismatch', 'Cursor does not belong to this collection', status: :bad_request)
    end

    timestamp = Time.iso8601(payload.fetch(:timestamp).to_s)
    id = Integer(payload.fetch(:id), exception: false)
    raise ArgumentError unless id&.positive?

    { timestamp: timestamp, id: id }
  rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError, ArgumentError
    raise Openjarvis::ApiError.new('invalid_cursor', 'Cursor is invalid or has been tampered with', status: :bad_request)
  end

  def self.verifier
    @verifier ||= ActiveSupport::MessageVerifier.new(
      Rails.application.secret_key_base,
      digest: 'SHA256',
      serializer: JSON
    )
  end

  private_class_method :verifier
end
