require 'rails_helper'

RSpec.describe 'Webhooks::EvolutionController', type: :request do
  let(:provisioning) do
    create(
      :whatsapp_evolution_provisioning,
      public_id: 'public-webhook-id',
      instance_name: 'cw-a1-test',
      webhook_secret: 'webhook-secret'
    )
  end
  let(:payload) do
    {
      event: 'connection.update',
      instance: provisioning.instance_name,
      apikey: 'must-not-reach-the-job',
      data: { state: 'connecting' }
    }
  end
  let(:claims) do
    {
      app: 'evolution',
      action: 'webhook',
      iat: Time.current.to_i,
      exp: 10.minutes.from_now.to_i
    }
  end
  let(:token) { JWT.encode(claims, provisioning.webhook_secret, 'HS256') }

  before do
    allow(Webhooks::EvolutionEventsJob).to receive(:perform_later)
  end

  it 'authenticates, deduplicates and enqueues a sanitized payload' do
    post "/webhooks/evolution/#{provisioning.public_id}",
         params: payload,
         headers: { 'Authorization' => "Bearer #{token}" },
         as: :json

    expect(response).to have_http_status(:accepted)
    event = Whatsapp::EvolutionEvent.last
    expect(event.event_type).to eq('connection_update')
    expect(Webhooks::EvolutionEventsJob).to have_received(:perform_later).with(
      event.id,
      hash_excluding('apikey')
    )
  end

  it 'does not enqueue a duplicate event' do
    2.times do
      post "/webhooks/evolution/#{provisioning.public_id}",
           params: payload,
           headers: { 'Authorization' => "Bearer #{token}" },
           as: :json
    end

    expect(response).to have_http_status(:accepted)
    expect(provisioning.events.count).to eq(1)
    expect(Webhooks::EvolutionEventsJob).to have_received(:perform_later).once
  end

  it 'allows a failed event to be queued again on provider redelivery' do
    post "/webhooks/evolution/#{provisioning.public_id}",
         params: payload,
         headers: { 'Authorization' => "Bearer #{token}" },
         as: :json
    provisioning.events.last.update!(status: :failed)

    post "/webhooks/evolution/#{provisioning.public_id}",
         params: payload,
         headers: { 'Authorization' => "Bearer #{token}" },
         as: :json

    expect(response).to have_http_status(:accepted)
    expect(Webhooks::EvolutionEventsJob).to have_received(:perform_later).twice
    expect(provisioning.events.last).to be_queued
  end

  it 'rejects an invalid signature without exposing details' do
    post "/webhooks/evolution/#{provisioning.public_id}",
         params: payload,
         headers: { 'Authorization' => 'Bearer invalid' },
         as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(response.body).to be_blank
  end
end
