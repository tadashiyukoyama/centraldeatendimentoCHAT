class Whatsapp::Evolution::QrCode
  MAX_BYTES = 1.megabyte
  PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
  DATA_URL_PREFIX = 'data:image/png;base64,'.freeze

  def self.normalize(value)
    return if value.blank?

    encoded = value.to_s.delete_prefix(DATA_URL_PREFIX)
    raise ArgumentError if encoded.bytesize > maximum_encoded_bytes

    decoded = Base64.strict_decode64(encoded)
    raise ArgumentError if decoded.bytesize > MAX_BYTES
    raise ArgumentError unless decoded.start_with?(PNG_SIGNATURE)

    "#{DATA_URL_PREFIX}#{Base64.strict_encode64(decoded)}"
  rescue ArgumentError
    raise Whatsapp::Evolution::ApiClient::Error.new(
      'Evolution QR Code response is invalid',
      code: 'invalid_qr_code'
    )
  end

  def self.maximum_encoded_bytes
    ((MAX_BYTES * 4) / 3) + 4
  end
end
