require 'rails_helper'

RSpec.describe Openjarvis::WebhookClient do
  it 'signs the exact payload with AceleraChat headers' do
    payload = { event: 'message.created', data: { id: 1 } }
    secrets = %w[current-signing-secret previous-signing-secret]
    allow(Time).to receive(:current).and_return(Time.zone.at(1_700_000_000))

    expect(SafeFetch).to receive(:fetch) do |url, **options, &block|
      body = JSON.generate(payload)
      expected = OpenSSL::HMAC.hexdigest('SHA256', secrets.first, "1700000000.#{body}")
      previous = OpenSSL::HMAC.hexdigest('SHA256', secrets.second, "1700000000.#{body}")
      expect(url).to eq('https://openjarvis.example.com/events')
      expect(options[:body]).to eq(body)
      expect(options[:headers]).to include(
        'X-AceleraChat-Delivery' => 'delivery-1',
        'X-AceleraChat-Timestamp' => '1700000000',
        'X-AceleraChat-Signature' => "sha256=#{expected}",
        'X-AceleraChat-Signature-Previous' => "sha256=#{previous}"
      )
      expect(options[:sensitive_headers]).to contain_exactly(
        'x-acelerachat-delivery', 'x-acelerachat-timestamp', 'x-acelerachat-signature',
        'x-acelerachat-signature-previous'
      )
      block.call(nil)
    end

    described_class.new(endpoint_url: 'https://openjarvis.example.com/events', secrets: secrets)
                   .deliver(payload, delivery_id: 'delivery-1')
  end

  it 'converts upstream failures to a sanitized delivery error' do
    allow(SafeFetch).to receive(:fetch).and_raise(SafeFetch::HttpError, '500 Internal Server Error with private body')

    expect do
      described_class.new(endpoint_url: 'https://openjarvis.example.com/events', secrets: ['secret']).deliver({})
    end.to raise_error(Openjarvis::WebhookClient::DeliveryError, 'OpenJarvis returned HTTP 500')
  end

  it 'classifies retryable and permanent receiver failures' do
    expect(described_class::DeliveryError.new('temporary', status: 429)).to be_retryable
    expect(described_class::DeliveryError.new('temporary', status: 503)).to be_retryable
    expect(described_class::DeliveryError.new('permanent', status: 422)).not_to be_retryable
  end
end
