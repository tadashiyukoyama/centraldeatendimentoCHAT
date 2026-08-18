require 'rails_helper'

RSpec.describe Openjarvis::CursorPage do
  let(:account) { create(:account) }

  it 'uses ID as a deterministic tie-breaker and returns has_more metadata' do
    timestamp = Time.zone.parse('2026-08-18 12:00:00')
    contacts = create_list(:contact, 3, account: account)
    contacts.each { |contact| contact.update_columns(updated_at: timestamp) } # rubocop:disable Rails/SkipsModelValidations

    first = described_class.new(
      scope: account.contacts,
      cursor: nil,
      limit: 2,
      type: 'contacts:test',
      timestamp_column: :updated_at,
      direction: :desc
    ).perform
    second = described_class.new(
      scope: account.contacts,
      cursor: first.meta[:next_cursor],
      limit: 2,
      type: 'contacts:test',
      timestamp_column: :updated_at,
      direction: :desc
    ).perform

    expect(first.records.map(&:id)).to eq(contacts.map(&:id).sort.last(2).reverse)
    expect(first.meta).to include(has_more: true, returned: 2)
    expect(second.records.map(&:id)).to eq([contacts.map(&:id).min])
    expect(second.meta).to include(has_more: false, next_cursor: nil)
  end

  it 'rejects cursor reuse in a different collection' do
    contact = create(:contact, account: account)
    cursor = Openjarvis::Cursor.encode(type: 'contacts:first-filter', timestamp: contact.updated_at, id: contact.id, direction: :desc)

    expect do
      described_class.new(
        scope: account.contacts,
        cursor: cursor,
        limit: 25,
        type: 'contacts:other-filter',
        timestamp_column: :updated_at,
        direction: :desc
      ).perform
    end.to raise_error(Openjarvis::ApiError, /does not belong/)
  end
end
