require 'rails_helper'

RSpec.describe Openjarvis::WebhookDeliveryJob do
  include ActiveJob::TestHelper

  let(:hook) { create(:integrations_hook, :openjarvis) }
  let(:payload) do
    {
      schema_version: '1.0', event_id: SecureRandom.uuid, event: 'contact.updated',
      occurred_at: Time.current.iso8601, resource: {}, data: {}
    }
  end

  it 'does not retry permanent receiver failures' do
    delivery = create(:openjarvis_webhook_delivery, integration_hook: hook)
    client = instance_double(Openjarvis::WebhookClient)
    allow(Openjarvis::WebhookClient).to receive(:new).and_return(client)
    allow(client).to receive(:deliver).and_raise(
      Openjarvis::WebhookClient::DeliveryError.new('invalid payload', status: 422)
    )

    expect do
      described_class.perform_now(delivery.id, payload)
    end.not_to have_enqueued_job(described_class)

    expect(delivery.reload).to have_attributes(status: 'failed', failure_class: 'permanent', response_status: 422)
  end

  it 'schedules bounded retry for temporary receiver failures' do
    delivery = create(:openjarvis_webhook_delivery, integration_hook: hook)
    client = instance_double(Openjarvis::WebhookClient)
    allow(Openjarvis::WebhookClient).to receive(:new).and_return(client)
    allow(client).to receive(:deliver).and_raise(
      Openjarvis::WebhookClient::DeliveryError.new('receiver unavailable', status: 503)
    )

    expect do
      described_class.perform_now(delivery.id, payload)
    end.to have_enqueued_job(described_class)

    expect(delivery.reload).to have_attributes(failure_class: 'temporary', response_status: 503)
    expect(delivery.next_attempt_at).to be_present
  end

  it 'reuses the same delivery and event identity when a job is duplicated' do
    delivery = create(:openjarvis_webhook_delivery, integration_hook: hook)
    client = instance_double(Openjarvis::WebhookClient)
    allow(Openjarvis::WebhookClient).to receive(:new).and_return(client)
    delivered_ids = []
    allow(client).to receive(:deliver) { |_body, delivery_id:| delivered_ids << delivery_id }

    2.times { described_class.new.perform(delivery.id, payload) }

    expect(delivered_ids).to eq([delivery.delivery_id, delivery.delivery_id])
    expect(delivery.reload.attempts).to eq(2)
    expect(Openjarvis::WebhookDelivery.where(event_id: delivery.event_id).count).to eq(1)
  end

  it 'preserves per-resource sequence when jobs execute out of order' do
    first = create(:openjarvis_webhook_delivery, integration_hook: hook, resource_sequence: 1)
    second = create(:openjarvis_webhook_delivery, integration_hook: hook, resource_sequence: 2)
    client = instance_double(Openjarvis::WebhookClient)
    allow(Openjarvis::WebhookClient).to receive(:new).and_return(client)
    observed = []
    allow(client).to receive(:deliver) { |body, **| observed << body.fetch(:resource).fetch(:sequence) }

    described_class.new.perform(second.id, payload.deep_merge(resource: { sequence: 2 }))
    described_class.new.perform(first.id, payload.deep_merge(resource: { sequence: 1 }))

    expect(observed).to eq([2, 1])
  end
end
