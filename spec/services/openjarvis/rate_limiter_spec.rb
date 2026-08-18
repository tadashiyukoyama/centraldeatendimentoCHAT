require 'rails_helper'

RSpec.describe Openjarvis::RateLimiter do
  let(:hook) { create(:integrations_hook, :openjarvis) }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:now) { Time.zone.parse('2026-08-18 12:00:00') }

  it 'separates read and write buckets and reports reset metadata' do
    read = described_class.new(hook: hook, bucket: :read, now: now, cache: cache).check
    write = described_class.new(hook: hook, bucket: :write, now: now, cache: cache).check

    expect(read).to have_attributes(allowed?: true, limit: 120, remaining: 119)
    expect(write).to have_attributes(allowed?: true, limit: 30, remaining: 29)
    expect(read.retry_after).to eq(60)
  end

  it 'rejects requests beyond the documented limit' do
    120.times { described_class.new(hook: hook, bucket: :read, now: now, cache: cache).check }

    expect(described_class.new(hook: hook, bucket: :read, now: now, cache: cache).check).not_to be_allowed
  end
end
