require 'rails_helper'

RSpec.describe Openjarvis::Idempotency::Executor do
  let(:hook) { create(:integrations_hook, :openjarvis) }
  let(:payload) { { contact: { name: 'Cliente Teste' } } }
  let(:executor) { described_class.new(hook: hook, key: 'contact-0001', operation: 'contacts.create', payload: payload) }

  it 'stores and replays a completed response without running the mutation twice' do
    executions = 0
    first = executor.execute do
      executions += 1
      described_class::Result.new(status: 201, body: { data: { id: 10 } }, resource: nil, replayed: false)
    end
    second = executor.execute do
      executions += 1
      described_class::Result.new(status: 201, body: { data: { id: 11 } }, resource: nil, replayed: false)
    end

    expect(first.replayed).to be(false)
    expect(second.replayed).to be(true)
    expect(second.body).to eq('data' => { 'id' => 10 })
    expect(executions).to eq(1)
  end

  it 'rejects reuse of a key with a different payload' do
    executor.execute do
      described_class::Result.new(status: 201, body: {}, resource: nil, replayed: false)
    end

    conflicting = described_class.new(
      hook: hook,
      key: 'contact-0001',
      operation: 'contacts.create',
      payload: { contact: { name: 'Outro' } }
    )
    expect { conflicting.execute }.to raise_error(Openjarvis::ApiError, /different request/)
  end

  it 'rejects short idempotency keys' do
    invalid = described_class.new(hook: hook, key: 'short', operation: 'contacts.create', payload: payload)

    expect { invalid.execute }.to raise_error(Openjarvis::ApiError, /8 to 128/)
  end
end
