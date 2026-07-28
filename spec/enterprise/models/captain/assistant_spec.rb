require 'rails_helper'

RSpec.describe Captain::Assistant do
  describe '#agent_tools' do
    let(:account) { create(:account) }
    let(:assistant) { create(:captain_assistant, account: account) }

    it 'includes enabled custom tools from the assistant account' do
      custom_tool = create(:captain_custom_tool, account: account)

      tools = assistant.send(:agent_tools)

      expect(tools.map(&:name)).to include(custom_tool.slug)
      expect(tools.find { |tool| tool.name == custom_tool.slug }).to be_a(Captain::Tools::HttpTool)
    end

    it 'excludes disabled custom tools' do
      custom_tool = create(:captain_custom_tool, :disabled, account: account)

      tools = assistant.send(:agent_tools)

      expect(tools.map(&:name)).not_to include(custom_tool.slug)
    end

    it 'excludes custom tools from other accounts' do
      custom_tool = create(:captain_custom_tool)

      tools = assistant.send(:agent_tools)

      expect(tools.map(&:name)).not_to include(custom_tool.slug)
    end

    it 'keeps the built-in FAQ lookup and handoff tools' do
      tools = assistant.send(:agent_tools)

      expect(tools).to include(
        an_instance_of(Captain::Tools::FaqLookupTool),
        an_instance_of(Captain::Tools::HandoffTool)
      )
    end

    it 'enables operational tools only through explicit assistant features' do
      specialist = create(:user, account: account)
      finance_team = create(:team, account: account)
      assistant.update!(
        config: assistant.config.merge(
          'feature_contact_attributes' => true,
          'feature_demo_scheduling' => true,
          'demo_assignee_id' => specialist.id,
          'feature_payment_notices' => true,
          'finance_team_id' => finance_team.id
        )
      )

      tools = assistant.send(:agent_tools)

      expect(tools).to include(
        an_instance_of(Captain::Tools::CaptureContactProfileTool),
        an_instance_of(Captain::Tools::ScheduleDemoTool),
        an_instance_of(Captain::Tools::RecordPaymentNoticeTool),
        an_instance_of(Captain::Tools::LookupPaymentStatusTool)
      )
    end

    it 'does not expose operational tools to an assistant without the feature flags' do
      tools = assistant.send(:agent_tools)

      expect(tools).not_to include(
        an_instance_of(Captain::Tools::CaptureContactProfileTool),
        an_instance_of(Captain::Tools::ScheduleDemoTool),
        an_instance_of(Captain::Tools::RecordPaymentNoticeTool),
        an_instance_of(Captain::Tools::LookupPaymentStatusTool)
      )
    end
  end

  describe 'operational tool configuration' do
    let(:account) { create(:account) }
    let(:assistant) { create(:captain_assistant, account: account) }
    let(:specialist) { create(:user, account: account) }
    let(:finance_team) { create(:team, account: account) }

    it 'resolves configured resources only inside the assistant account' do
      assistant.update!(
        config: {
          'feature_contact_attributes' => true,
          'feature_demo_scheduling' => true,
          'demo_assignee_id' => specialist.id,
          'feature_payment_notices' => true,
          'finance_team_id' => finance_team.id
        }
      )

      expect(assistant.configured_demo_specialist).to eq(specialist)
      expect(assistant.configured_finance_team).to eq(finance_team)
      expect(assistant.operational_tools_configuration).to include(
        contact_profile: include(enabled: true, ready: true),
        demo_scheduling: include(enabled: true, ready: true, assignee_id: specialist.id),
        payment_notices: include(enabled: true, ready: true, finance_team_id: finance_team.id)
      )
    end

    it 'rejects a specialist from another account' do
      external_specialist = create(:user, account: create(:account))
      assistant.config = { 'demo_assignee_id' => external_specialist.id }

      expect(assistant).not_to be_valid
      expect(assistant.errors[:config]).to include('demo specialist must belong to the assistant account')
    end

    it 'requires contact capture and a specialist before enabling demonstration scheduling' do
      assistant.config = {
        'feature_demo_scheduling' => true,
        'demo_assignee_id' => specialist.id
      }

      expect(assistant).not_to be_valid
      expect(assistant.errors[:config]).to include(
        'contact profile capture must be enabled for demonstration scheduling'
      )
    end

    it 'rejects a legacy specialist email from another account' do
      external_specialist = create(:user, account: create(:account))
      assistant.config = { 'demo_assignee_email' => external_specialist.email }

      expect(assistant).not_to be_valid
      expect(assistant.errors[:config]).to include('demo specialist email must belong to the assistant account')
    end

    it 'rejects a finance team from another account' do
      external_team = create(:team)
      assistant.config = { 'finance_team_id' => external_team.id }

      expect(assistant).not_to be_valid
      expect(assistant.errors[:config]).to include('finance team must belong to the assistant account')
    end
  end
end
