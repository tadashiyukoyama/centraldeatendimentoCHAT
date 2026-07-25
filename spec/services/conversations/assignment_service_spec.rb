require 'rails_helper'

describe Conversations::AssignmentService do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:conversation) { create(:conversation, account: account) }

  describe '#perform' do
    context 'when assignee_id is blank' do
      before do
        conversation.update!(assignee: agent, assignee_agent_bot: agent_bot)
      end

      it 'clears both human and bot assignees' do
        described_class.new(conversation: conversation, assignee_id: nil).perform

        conversation.reload
        expect(conversation.assignee_id).to be_nil
        expect(conversation.assignee_agent_bot_id).to be_nil
      end
    end

    context 'when assigning a user' do
      before do
        conversation.update!(assignee_agent_bot: agent_bot, assignee: nil)
      end

      it 'sets the agent and clears agent bot' do
        result = described_class.new(conversation: conversation, assignee_id: agent.id).perform

        conversation.reload
        expect(result).to eq(agent)
        expect(conversation.assignee_id).to eq(agent.id)
        expect(conversation.assignee_agent_bot_id).to be_nil
      end
    end

    context 'when assigning an agent bot' do
      let(:service) do
        described_class.new(
          conversation: conversation,
          assignee_id: agent_bot.id,
          assignee_type: 'AgentBot'
        )
      end

      it 'sets the agent bot and clears human assignee' do
        conversation.update!(assignee: agent, assignee_agent_bot: nil)

        result = service.perform

        conversation.reload
        expect(result).to eq(agent_bot)
        expect(conversation.assignee_agent_bot_id).to eq(agent_bot.id)
        expect(conversation.assignee_id).to be_nil
      end
    end

    context 'when strict team visibility is enabled' do
      let(:team) { create(:team, account: account, allow_auto_assign: false) }

      it 'rejects a human assignment while the conversation has no team' do
        create(:inbox_member, inbox: conversation.inbox, user: agent)
        account.enable_features!(:strict_team_conversation_visibility)

        expect do
          described_class.new(conversation: conversation, assignee_id: agent.id).perform
        end.to raise_error(ActiveRecord::RecordNotFound)
        expect(conversation.reload.assignee_id).to be_nil
      end

      it 'allows an inbox member who belongs to the conversation team' do
        create(:inbox_member, inbox: conversation.inbox, user: agent)
        create(:team_member, team: team, user: agent)
        conversation.update!(team: team)
        account.enable_features!(:strict_team_conversation_visibility)

        result = described_class.new(conversation: conversation, assignee_id: agent.id).perform

        expect(result).to eq(agent)
        expect(conversation.reload.assignee_id).to eq(agent.id)
      end

      it 'rejects an inbox member from another team' do
        create(:inbox_member, inbox: conversation.inbox, user: agent)
        conversation.update!(team: team)
        account.enable_features!(:strict_team_conversation_visibility)

        expect do
          described_class.new(conversation: conversation, assignee_id: agent.id).perform
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'allows an administrator even while the conversation has no team' do
        administrator = create(:user, account: account, role: :administrator)
        account.enable_features!(:strict_team_conversation_visibility)

        result = described_class.new(conversation: conversation, assignee_id: administrator.id).perform

        expect(result).to eq(administrator)
        expect(conversation.reload.assignee_id).to eq(administrator.id)
      end
    end
  end
end
