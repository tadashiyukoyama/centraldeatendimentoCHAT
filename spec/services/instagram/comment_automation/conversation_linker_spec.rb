require 'rails_helper'

RSpec.describe Instagram::CommentAutomation::ConversationLinker do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_instagram, account: account) }
  let(:inbox) { channel.inbox }
  let(:automation) do
    create(
      :instagram_comment_automation,
      account: account,
      inbox: inbox,
      conversation_context: 'Lead pediu uma demonstração.',
      conversation_label: 'instagram_demo'
    )
  end
  let(:contact) { create(:contact, account: account) }
  let!(:contact_inbox) do
    create(:contact_inbox, inbox: inbox, contact: contact, source_id: '17840000000000999')
  end
  let!(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox
    )
  end
  let!(:event) do
    create(
      :instagram_comment_event,
      account: account,
      inbox: inbox,
      instagram_comment_automation: automation,
      private_reply_status: :succeeded,
      private_reply_recipient_id: contact_inbox.source_id,
      matched_keyword: 'demo'
    )
  end

  it 'links the Direct conversation and exposes structured campaign context to Nemmo' do
    described_class.new(inbox: inbox, recipient_id: contact_inbox.source_id).call

    context = conversation.reload.additional_attributes['instagram_comment_campaign']
    expect(context).to include(
      'automation_id' => automation.id,
      'matched_keyword' => 'demo',
      'context' => 'Lead pediu uma demonstração.'
    )
    expect(conversation.label_list).to include('instagram_demo')
    expect(event.reload.conversation).to eq(conversation)
  end

  it 'is idempotent once the event is linked' do
    linker = described_class.new(inbox: inbox, recipient_id: contact_inbox.source_id)
    linker.call
    attributes = conversation.reload.additional_attributes.deep_dup

    linker.call

    expect(conversation.reload.additional_attributes).to eq(attributes)
  end
end
