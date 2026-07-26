require 'rails_helper'

RSpec.describe Captain::Knowledge::RepositorySyncService, type: :service do
  let(:account) { create(:account) }
  let(:first_assistant) { create(:captain_assistant, account: account) }
  let(:second_assistant) { create(:captain_assistant, account: account) }
  let(:source_path) { Rails.root.join('config/captain/knowledge/aifood_manager_faqs.yml') }
  let(:service) do
    described_class.new(
      account: account,
      assistants: [first_assistant, second_assistant],
      source_path: source_path
    )
  end

  it 'checks without changing repository-managed content' do
    expect { service.check }.not_to change(Captain::AssistantResponse, :count)
  end

  it 'creates approved and independently linked FAQs for each assistant' do
    result = service.sync

    expected_count = YAML.safe_load_file(source_path, permitted_classes: [], aliases: false)
                         .fetch('definitions')
                         .length
    expect(first_assistant.responses.approved.count).to eq(expected_count)
    expect(second_assistant.responses.approved.count).to eq(expected_count)
    expect(first_assistant.responses.pluck(:assistant_id).uniq).to eq([first_assistant.id])
    expect(second_assistant.responses.pluck(:assistant_id).uniq).to eq([second_assistant.id])
    expect(result[:assistants].pluck(:approved_count)).to eq([expected_count, expected_count])
  end

  it 'is idempotent' do
    service.sync

    expect { service.sync }.not_to change(Captain::AssistantResponse, :count)
    expect(first_assistant.documents.where(external_link: described_class::PUBLIC_SOURCE_URL).count).to eq(1)
    expect(second_assistant.documents.where(external_link: described_class::PUBLIC_SOURCE_URL).count).to eq(1)
  end

  it 'retires approved content outside the controlled repository source' do
    unmanaged = create(
      :captain_assistant_response,
      assistant: first_assistant,
      account: account,
      question: 'Conteúdo antigo',
      answer: 'Não controlado',
      status: :approved
    )

    service.sync

    expect(unmanaged.reload).to be_pending
    expect(first_assistant.responses.approved.count).to eq(
      YAML.safe_load_file(source_path, permitted_classes: [], aliases: false).fetch('definitions').length
    )
  end

  it 'rolls back every assistant when one sync fails' do
    allow(second_assistant.documents).to receive(:find_or_initialize_by).and_raise(ActiveRecord::RecordInvalid)

    expect { service.sync }.to raise_error(ActiveRecord::RecordInvalid)
    expect(first_assistant.responses.count).to eq(0)
    expect(first_assistant.documents.count).to eq(0)
  end
end
