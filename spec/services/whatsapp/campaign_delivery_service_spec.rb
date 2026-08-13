require 'rails_helper'

RSpec.describe Whatsapp::CampaignDeliveryService do
  let(:account) { create(:account) }
  let(:sender) { create(:user, account: account) }
  let(:label) { create(:label, account: account) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'evolution',
                              validate_provider_config: false, sync_templates: false)
  end
  let(:campaign) do
    create(
      :campaign,
      account: account,
      inbox: channel.inbox,
      sender: sender,
      message: 'Olá, {{contact.name}}! Conheça nossa solução.',
      audience: [{ type: 'Label', id: label.id }],
      trigger_rules: {
        delivery_interval_min_minutes: 4,
        delivery_interval_max_minutes: 45,
        lawful_basis_confirmed: true,
        message_variants: ['Boa tarde, {{contact.name}}! Posso falar com você?']
      }
    ).tap(&:processing!)
  end
  let(:contact) { create(:contact, account: account, name: 'Marina', phone_number: '+5511999999999') }
  let(:delivery) { create(:campaign_delivery, campaign: campaign, contact: contact, scheduled_for: Time.current) }

  before do
    contact.update_labels([label.title])
  end

  it 'creates one personalized, traceable message without Meta template parameters', :aggregate_failures do
    expect do
      described_class.new(delivery: delivery).perform
    end.to change(Message, :count).by(1)

    message = delivery.reload.conversation.messages.outgoing.first
    expect(delivery).to be_queued
    expect(delivery.processed_at).to be_present
    expect(delivery.conversation.campaign).to eq(campaign)
    expect(delivery.conversation.additional_attributes['campaign_delivery_id']).to eq(delivery.id)
    expect(delivery.conversation.additional_attributes['campaign_variant']).to be_between(1, 2)
    expect(message.content).to include('Marina')
    expect(message.content).to include('responda SAIR')
    expect(message.additional_attributes['campaign_id']).to eq(campaign.id)
    expect(message.additional_attributes['template_params']).to be_blank
    expect(campaign.reload).to be_completed
  end

  it 'is idempotent after the delivery has been queued' do
    described_class.new(delivery: delivery).perform

    expect do
      described_class.new(delivery: delivery.reload).perform
    end.not_to change(Message, :count)
  end

  it 'skips blocked, unnamed, phoneless, and opted-out contacts with an audit reason' do
    contact.update!(additional_attributes: { 'whatsapp_marketing_unsubscribed' => true })

    described_class.new(delivery: delivery).perform

    expect(delivery.reload).to be_skipped
    expect(delivery.error_message).to eq('contact opted out of WhatsApp marketing')
    expect(delivery.conversation).to be_nil
  end
end
