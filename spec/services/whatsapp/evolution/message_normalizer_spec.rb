require 'rails_helper'

RSpec.describe Whatsapp::Evolution::MessageNormalizer do
  it 'normalizes an incoming text message' do
    data = {
      key: {
        remoteJid: '5511999999999@s.whatsapp.net',
        fromMe: false,
        id: 'message-1'
      },
      pushName: 'Customer',
      messageTimestamp: 1_721_000_000,
      message: { conversation: 'Hello' }
    }

    normalizer = described_class.new(data: data)
    result = normalizer.normalize

    expect(normalizer.outgoing_echo?).to be(false)
    expect(result.dig(:contacts, 0, :wa_id)).to eq('5511999999999')
    expect(result.dig(:messages, 0, :text, :body)).to eq('Hello')
    expect(result.dig(:messages, 0, :from)).to eq('5511999999999')
  end

  it 'normalizes an outgoing echo without creating an inbound contact payload' do
    data = {
      key: {
        remoteJid: '5511999999999@s.whatsapp.net',
        fromMe: true,
        id: 'message-2'
      },
      message: { extendedTextMessage: { text: 'Agent reply' } }
    }

    normalizer = described_class.new(data: data)
    result = normalizer.normalize

    expect(normalizer.outgoing_echo?).to be(true)
    expect(result[:contacts]).to be_nil
    expect(result.dig(:messages, 0, :to)).to eq('5511999999999')
  end

  it 'keeps the exact Evolution message only inside the transient media payload' do
    data = {
      key: {
        remoteJid: '5511999999999@s.whatsapp.net',
        fromMe: false,
        id: 'message-3'
      },
      message: {
        imageMessage: {
          mimetype: 'image/jpeg',
          caption: 'Menu'
        }
      }
    }

    result = described_class.new(data: data).normalize

    expect(result.dig(:messages, 0, :type)).to eq('image')
    expect(result.dig(:messages, 0, :image, :caption)).to eq('Menu')
    expect(result.dig(:messages, 0, :image, :evolution_message, :key, :id)).to eq('message-3')
  end

  it 'rejects group messages' do
    data = {
      key: {
        remoteJid: '120363000000000000@g.us',
        fromMe: false,
        id: 'group-message'
      },
      message: { conversation: 'Hello group' }
    }

    expect { described_class.new(data: data).normalize }.to raise_error(
      Whatsapp::Evolution::MessageNormalizer::UnsupportedMessage
    )
  end

  it 'rejects message types that Chatwoot cannot safely normalize' do
    data = {
      key: {
        remoteJid: '5511999999999@s.whatsapp.net',
        fromMe: false,
        id: 'unsupported-message'
      },
      message: { protocolMessage: { type: 'REVOKE' } }
    }

    expect { described_class.new(data: data).normalize }.to raise_error(
      Whatsapp::Evolution::MessageNormalizer::UnsupportedMessage,
      'WhatsApp message type is not supported'
    )
  end
end
