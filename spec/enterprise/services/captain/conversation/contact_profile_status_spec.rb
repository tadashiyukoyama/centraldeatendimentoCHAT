require 'rails_helper'

RSpec.describe Captain::Conversation::ContactProfileStatus do
  let(:account) { create(:account) }

  it 'treats a generated web-widget name as missing' do
    contact = create(
      :contact,
      account: account,
      name: 'patient-fire-116',
      additional_attributes: { 'captain_name_source' => 'generated' }
    )

    status = described_class.new(contact)

    expect(status.real_name?).to be(false)
    expect(status.missing_fields).to eq(%i[name company_name phone_number email])
    expect(status.public_contact_attributes[:name]).to be_nil
  end

  it 'tracks the required fields without exposing internal evidence metadata' do
    contact = create(
      :contact,
      account: account,
      name: 'Cesar Yukoyama',
      phone_number: '+5511999999999',
      email: 'cesar@example.com',
      additional_attributes: {
        'captain_name_source' => 'customer',
        'company_name' => 'Mar Azul',
        'captain_profile_evidence' => { 'email' => { 'message_id' => 123 } }
      }
    )

    status = described_class.new(contact)

    expect(status).to be_complete
    expect(status.public_contact_attributes[:company_name]).to eq('Mar Azul')
    expect(status.public_contact_attributes).not_to have_key(:additional_attributes)
  end
end
