require 'rails_helper'

RSpec.describe Openjarvis::CapabilityResolver do
  it 'declares unsupported WhatsApp provider mutations without hiding text send or delivery status' do
    capabilities = described_class.new(channel_type: 'Channel::Whatsapp').capabilities

    expect(capabilities.dig('messages.send', :supported)).to be(true)
    expect(capabilities.dig('messages.delivery_status', :supported)).to be(true)
    expect(capabilities.dig('messages.reply', :supported)).to be(false)
    expect(capabilities.dig('messages.reaction', :supported)).to be(false)
    expect(capabilities.dig('messages.mark_read_provider', :supported)).to be(false)
    expect(capabilities.dig('messages.media_send', :supported)).to be(false)
  end

  it 'reports Evolution connection from provisioning rather than auto assignment' do
    channel = create(:channel_whatsapp, provider: 'evolution', validate_provider_config: false, sync_templates: false)
    inbox = channel.inbox
    inbox.update!(enable_auto_assignment: false)
    create(:whatsapp_evolution_provisioning, account: channel.account, whatsapp_channel: channel, status: :connected)

    connection = described_class.new(inbox: inbox).connection

    expect(connection).to include(state: 'connected', connected: true, source: 'whatsapp_evolution_provisioning')
  end

  it 'exposes provider-native replies, reactions, read receipts and media only for Evolution inboxes' do
    channel = create(:channel_whatsapp, provider: 'evolution', validate_provider_config: false, sync_templates: false)
    inbox = channel.inbox
    create(:whatsapp_evolution_provisioning, account: channel.account, whatsapp_channel: channel, status: :connected)

    capabilities = described_class.new(inbox: inbox).capabilities

    expect(capabilities.dig('messages.reply', :supported)).to be(true)
    expect(capabilities.dig('messages.reaction', :supported)).to be(true)
    expect(capabilities.dig('messages.mark_read_provider', :supported)).to be(true)
    expect(capabilities.dig('messages.media_send', :supported)).to be(true)
  end

  it 'formally limits email to AceleraChat customer-service operations' do
    capabilities = described_class.new(channel_type: 'Channel::Email').capabilities

    expect(capabilities.dig('email.threads', :supported)).to be(true)
    expect(capabilities.dig('email.recipients', :supported)).to be(true)
    expect(capabilities.dig('email.attachments_read', :supported)).to be(true)
    expect(capabilities.dig('email.attachments_send', :supported)).to be(false)
    expect(capabilities.dig('email.archive', :supported)).to be(false)
    expect(capabilities.dig('email.trash', :supported)).to be(false)
  end
end
