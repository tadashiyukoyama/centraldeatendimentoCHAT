require 'rails_helper'

RSpec.describe Acelerachat::SentryEventScrubber do
  it 'removes contact identifiers, credentials, and URL parameters from backend events', :aggregate_failures do
    exception_entry = Struct.new(:value).new('CPF 123.456.789-00 inválido')
    exception_collection_class = Class.new do
      attr_reader :values

      def initialize(entries)
        @values = entries
      end
    end
    exception_collection = exception_collection_class.new([exception_entry])
    event = Struct.new(:user, :message, :transaction, :request, :tags, :contexts, :extra, :exception, :breadcrumbs).new(
      { id: 7, email: 'cliente@example.com' },
      'Falha para cliente@example.com, telefone +55 (11) 99999-9999',
      '/api/v1/accounts/1/contacts?email=cliente@example.com',
      {
        url: 'https://atendimento.example.com/api/contacts?email=cliente@example.com',
        data: { content: 'mensagem privada' },
        cookies: { session: 'secret' },
        headers: { 'Authorization' => 'Bearer secret-token', 'Accept' => 'application/json' }
      },
      { account_id: 1, api_key: 'secret' },
      { contact: { phone: '5511999999999' } },
      { nested: { authorization: 'Bearer secret-token', safe: 'value' } },
      exception_collection,
      []
    )

    described_class.scrub_event(event)

    expect(event.user).to eq({})
    expect(event.message).to eq('Falha para [Filtered], telefone [Filtered]')
    expect(event.transaction).to eq('/api/v1/accounts/1/contacts')
    expect(event.request).to eq(
      url: 'https://atendimento.example.com/api/contacts',
      headers: { 'Authorization' => '[Filtered]', 'Accept' => 'application/json' }
    )
    expect(event.tags).to eq(account_id: 1, api_key: '[Filtered]')
    expect(event.contexts).to eq(contact: { phone: '[Filtered]' })
    expect(event.extra).to eq(nested: { authorization: '[Filtered]', safe: 'value' })
    expect(event.exception.values.first.value).to eq('CPF [Filtered] inválido')
  end

  it 'removes contact identifiers and parameters from backend breadcrumbs' do
    breadcrumb = Struct.new(:message, :data).new(
      'E-mail cliente@example.com',
      { url: 'https://example.com/path?token=secret' }
    )

    described_class.scrub_breadcrumb(breadcrumb)

    expect(breadcrumb.message).to eq('E-mail [Filtered]')
    expect(breadcrumb.data[:url]).to eq('https://example.com/path')
  end

  it 'limits recursive inspection of untrusted context data' do
    value = {
      one: {
        two: {
          three: {
            four: {
              five: {
                six: { seven: 'private' }
              }
            }
          }
        }
      }
    }

    expect(described_class.sanitize(value).dig(:one, :two, :three, :four, :five, :six)).to eq('[Filtered]')
  end
end
