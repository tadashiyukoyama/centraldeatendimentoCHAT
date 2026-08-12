require 'rails_helper'

RSpec.describe Whatsapp::Evolution::IncomingMessageService do
  let(:provisioning) { build(:whatsapp_evolution_provisioning) }
  let(:service) do
    described_class.new(
      inbox: build(:inbox),
      params: {},
      outgoing_echo: false,
      provisioning: provisioning
    )
  end
  let(:client) { instance_double(Whatsapp::Evolution::ApiClient) }

  before do
    allow(Whatsapp::Evolution::ApiClient).to receive(:new)
      .with(provisioning: provisioning)
      .and_return(client)
    allow(GlobalConfigService).to receive(:load)
      .with('MAXIMUM_FILE_UPLOAD_SIZE', 40)
      .and_return(1)
  end

  it 'rejects a media payload larger than the configured upload limit' do
    encoded = Base64.strict_encode64('a' * 1.megabyte)
    allow(client).to receive(:media_base64).and_return('base64' => "#{encoded}AAAA")

    result = service.send(
      :download_attachment_file,
      evolution_message: { key: { id: 'media-id' } }
    )

    expect(result).to be_nil
  end

  it 'scopes message deduplication lookup to the Evolution inbox' do
    inbox = create(:inbox)
    local_message = create(:message, account: inbox.account, inbox: inbox, source_id: 'shared-id')
    create(:message, source_id: 'shared-id')
    scoped_service = described_class.new(
      inbox: inbox,
      params: {},
      outgoing_echo: false,
      provisioning: provisioning
    )

    result = scoped_service.send(:find_message_by_source_id, 'shared-id')

    expect(result).to eq(local_message)
  end

  it 'names the concurrent deduplication lock by provider and inbox' do
    inbox = create(:inbox)
    lock = instance_double(Whatsapp::MessageDedupLock, acquire!: true)
    scoped_service = described_class.new(
      inbox: inbox,
      params: { messages: [{ id: 'message-id' }] },
      outgoing_echo: false,
      provisioning: provisioning
    )
    allow(scoped_service).to receive(:messages_data).and_return([{ id: 'message-id' }])
    allow(Whatsapp::MessageDedupLock).to receive(:new)
      .with("evolution:#{inbox.id}:message-id")
      .and_return(lock)

    expect(scoped_service.send(:lock_message_source_id!)).to be(true)
  end

  it 'records an incoming SAIR message as a marketing opt-out on the contact' do
    inbox = create(:channel_whatsapp, provider: 'evolution', validate_provider_config: false,
                                      sync_templates: false).inbox
    params = {
      messages: [
        {
          id: 'evolution-opt-out-message',
          from: '5511999998888',
          timestamp: Time.current.to_i.to_s,
          type: 'text',
          text: { body: 'SAIR' }
        }
      ],
      contacts: [{ wa_id: '5511999998888', profile: { name: 'Lead Teste' } }]
    }.with_indifferent_access

    described_class.new(inbox: inbox, params: params, outgoing_echo: false, provisioning: provisioning).perform

    contact = inbox.contacts.find_by!(phone_number: '+5511999998888')
    expect(contact.additional_attributes['whatsapp_marketing_unsubscribed']).to be(true)
    expect(contact.additional_attributes['whatsapp_marketing_unsubscribed_at']).to be_present
  end
end
