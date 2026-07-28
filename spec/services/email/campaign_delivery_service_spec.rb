require 'rails_helper'

RSpec.describe Email::CampaignDeliveryService do
  subject(:service) { described_class.new(delivery: delivery) }

  let(:account) { create(:account) }
  let(:sender) { create(:user, account: account, role: :administrator) }
  let(:channel) { create(:channel_email, account: account) }
  let(:inbox) { channel.inbox }
  let(:label) { create(:label, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Ada', email: 'ada@example.com') }
  let(:campaign) do
    create(
      :campaign,
      account: account,
      inbox: inbox,
      sender: sender,
      audience: [{ type: 'Label', id: label.id }],
      message: 'Olá {{contact.name}}',
      template_params: {
        subject: 'Boas-vindas {{contact.name}}',
        lawful_basis_confirmed: true
      },
      campaign_status: :processing
    )
  end
  let(:delivery) { create(:campaign_delivery, campaign: campaign, contact: contact) }

  around do |example|
    ClimateControl.modify FRONTEND_URL: 'https://atendimento.example.test' do
      example.run
    end
  end

  it 'creates a traceable conversation and queues an individualized email' do
    expect { service.perform }
      .to change(Conversation, :count).by(1)
      .and change(Message, :count).by(1)

    delivery.reload
    conversation = delivery.conversation
    message = conversation.messages.outgoing.first

    expect(delivery).to be_queued
    expect(conversation.campaign).to eq(campaign)
    expect(conversation.additional_attributes['mail_subject']).to eq('Boas-vindas Ada')
    expect(message.content).to include('Olá Ada')
    expect(message.content_attributes['to_emails']).to eq(['ada@example.com'])
    expect(campaign.reload).to be_completed
  end

  it 'adds a signed unsubscribe link to the individualized content' do
    service.perform

    expect(delivery.reload.conversation.messages.outgoing.first.content).to include(
      'https://atendimento.example.test/email/unsubscribe/'
    )
  end

  it 'is idempotent when the same delivery is performed twice' do
    service.perform

    expect { service.perform }
      .to not_change(Conversation, :count)
      .and not_change(Message, :count)
  end

  it 'skips contacts that already unsubscribed' do
    contact.update!(
      additional_attributes: contact.additional_attributes.merge('email_unsubscribed' => true)
    )

    expect { service.perform }.not_to change(Message, :count)
    expect(delivery.reload).to be_skipped
    expect(campaign.reload).to be_completed
  end
end
