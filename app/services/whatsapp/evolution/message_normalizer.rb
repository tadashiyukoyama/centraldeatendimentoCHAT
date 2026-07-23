class Whatsapp::Evolution::MessageNormalizer
  class UnsupportedMessage < StandardError; end

  MEDIA_TYPES = {
    'imageMessage' => 'image',
    'videoMessage' => 'video',
    'audioMessage' => 'audio',
    'documentMessage' => 'document',
    'stickerMessage' => 'sticker'
  }.freeze

  def initialize(data:)
    @data = data.deep_stringify_keys
  end

  def normalize
    raise UnsupportedMessage, 'Group and broadcast messages are not supported' if unsupported_chat?

    number = contact_number
    raise UnsupportedMessage, 'Message contact number is invalid' unless number&.match?(/\A\d{6,15}\z/)

    message = normalized_message(number)
    payload = { messages: [message] }
    payload[:contacts] = [normalized_contact(number)] unless from_me?
    payload.with_indifferent_access
  end

  def outgoing_echo?
    from_me?
  end

  private

  attr_reader :data

  def key
    data.fetch('key', {})
  end

  def raw_message
    data.fetch('message', {})
  end

  def from_me?
    ActiveModel::Type::Boolean.new.cast(key['fromMe'])
  end

  def remote_jid
    key['remoteJid'].to_s
  end

  def alternate_jid
    key['remoteJidAlt'].to_s
  end

  def unsupported_chat?
    [remote_jid, alternate_jid].any? do |jid|
      jid.end_with?('@g.us', '@broadcast', '@newsletter') || jid == 'status@broadcast'
    end
  end

  def contact_number
    jid = [alternate_jid, remote_jid].find { |candidate| candidate.end_with?('@s.whatsapp.net') }
    jid ||= [alternate_jid, remote_jid].find { |candidate| candidate.match?(/\A\d+@/) }
    jid.to_s.split('@').first.gsub(/\D/, '').presence
  end

  def normalized_contact(number)
    {
      wa_id: number,
      profile: {
        name: data['pushName'].presence || "+#{number}"
      }
    }
  end

  def normalized_message(number)
    type, content = normalized_content
    {
      id: key.fetch('id'),
      from: from_me? ? nil : number,
      to: from_me? ? number : nil,
      timestamp: data['messageTimestamp'].to_s,
      type: type,
      context: reply_context
    }.compact.merge(content)
  end

  def normalized_content
    return ['text', { text: { body: raw_message['conversation'] } }] if raw_message['conversation'].present?
    if raw_message.dig('extendedTextMessage', 'text').present?
      return ['text', { text: { body: raw_message.dig('extendedTextMessage', 'text') } }]
    end

    media_key = MEDIA_TYPES.keys.find { |candidate| raw_message[candidate].present? }
    return normalize_media(media_key) if media_key
    return normalize_location if raw_message['locationMessage'].present?

    raise UnsupportedMessage, 'WhatsApp message type is not supported'
  end

  def normalize_media(media_key)
    type = MEDIA_TYPES.fetch(media_key)
    media = raw_message.fetch(media_key)
    [
      type,
      {
        type.to_sym => {
          id: key.fetch('id'),
          caption: media['caption'],
          filename: media['fileName'],
          mime_type: media['mimetype'],
          evolution_message: data
        }.compact
      }
    ]
  end

  def normalize_location
    location = raw_message.fetch('locationMessage')
    [
      'location',
      {
        location: {
          latitude: location['degreesLatitude'],
          longitude: location['degreesLongitude'],
          name: location['name'],
          address: location['address'],
          url: location['url']
        }.compact
      }
    ]
  end

  def reply_context
    context = raw_message.values.filter_map { |value| value['contextInfo'] if value.is_a?(Hash) }.first
    stanza_id = context&.dig('stanzaId')
    stanza_id.present? ? { id: stanza_id } : nil
  end
end
