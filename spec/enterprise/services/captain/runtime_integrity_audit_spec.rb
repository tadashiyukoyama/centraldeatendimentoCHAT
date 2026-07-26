require 'rails_helper'

RSpec.describe Captain::RuntimeIntegrityAudit, type: :service do
  let(:account) { create(:account) }

  it 'accepts valid UTF-8 assistant configuration' do
    assistant = create(
      :captain_assistant,
      account: account,
      config: { 'welcome_message' => 'Olá! Como posso ajudar?' }
    )

    result = described_class.new(scope: Captain::Assistant.where(id: assistant.id)).perform

    expect(result[:errors]).to eq(0)
  end

  it 'detects question-mark corruption in assistant messages' do
    assistant = create(:captain_assistant, account: account)
    # Simulate legacy persisted corruption while bypassing the new write-time guard.
    assistant.update_column(:config, { 'welcome_message' => 'Ol? Eu sou o Nemmo.' }) # rubocop:disable Rails/SkipsModelValidations

    result = described_class.new(scope: Captain::Assistant.where(id: assistant.id)).perform

    expect(result[:errors]).to eq(1)
    expect(result[:assistants].first[:errors]).to include('config.welcome_message: possible question-mark corruption')
  end

  it 'detects double-encoded UTF-8 text' do
    assistant = create(:captain_assistant, account: account)
    # Simulate legacy persisted corruption while bypassing the new write-time guard.
    assistant.update_column(:config, { 'handoff_message' => "Respons\u00C3\u00A1vel" }) # rubocop:disable Rails/SkipsModelValidations

    result = described_class.new(scope: Captain::Assistant.where(id: assistant.id)).perform

    expect(result[:errors]).to eq(1)
    expect(result[:assistants].first[:errors]).to include('config.handoff_message: possible mojibake')
  end

  it 'prevents new corrupted assistant configuration from being saved' do
    assistant = build(
      :captain_assistant,
      account: account,
      config: { 'welcome_message' => 'Ol? Eu sou o Nemmo.' }
    )

    expect(assistant).not_to be_valid
    expect(assistant.errors[:base]).to include('config.welcome_message: possible question-mark corruption')
  end
end
