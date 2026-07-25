require 'rails_helper'

RSpec.describe Conversations::PermissionFilterService do
  let(:account) { create(:account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:another_conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:inbox) { create(:inbox, account: account) }

  # This inbox_member is used to establish the agent's access to the inbox
  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe '#perform' do
    context 'when user is an administrator' do
      it 'returns all conversations' do
        result = described_class.new(
          account.conversations,
          admin,
          account
        ).perform

        expect(result).to include(conversation)
        expect(result).to include(another_conversation)
        expect(result.count).to eq(2)
      end
    end

    context 'when user is an agent' do
      it 'returns all conversations with no further filtering' do
        inbox_ids = agent.inboxes.where(account_id: account.id).pluck(:id)

        # The base implementation returns all conversations
        # expecting the caller to filter by assigned inboxes
        result = described_class.new(
          account.conversations.where(inbox_id: inbox_ids),
          agent,
          account
        ).perform

        expect(result).to include(conversation)
        expect(result).to include(another_conversation)
        expect(result.count).to eq(2)
      end

      context 'when strict team visibility is enabled' do
        let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
        let(:team_a) { create(:team, account: account, allow_auto_assign: false) }
        let(:team_b) { create(:team, account: account, allow_auto_assign: false) }
        let!(:other_team_membership) { create(:team_member, team: team_b, user: agent) }
        let!(:team_conversation) { create(:conversation, account: account, inbox: inbox, team: team_a) }
        let!(:other_team_conversation) { create(:conversation, account: account, inbox: inbox, team: team_b, assignee: agent) }
        let!(:unassigned_conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

        before do
          other_team_membership.destroy!
          create(:team_member, team: team_a, user: agent)
          ConversationParticipant.find_or_create_by!(account: account, conversation: other_team_conversation, user: agent)
          ConversationParticipant.find_or_create_by!(account: account, conversation: unassigned_conversation, user: agent)
          account.enable_features!(:strict_team_conversation_visibility)
        end

        it 'returns only conversations from the agent team' do
          result = described_class.new(account.conversations, agent, account).perform

          expect(result).to contain_exactly(team_conversation)
        end

        it 'does not allow assignee or participant records to bypass the team' do
          result = described_class.new(account.conversations, agent, account).perform

          expect(result).not_to include(other_team_conversation, unassigned_conversation)
        end
      end
    end
  end

  describe Conversations::VisibleUsersService do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
    let(:team) { create(:team, account: account, allow_auto_assign: false) }
    let(:administrator) { create(:user, account: account, role: :administrator) }
    let(:team_agent) { create(:user, account: account, role: :agent) }
    let(:other_agent) { create(:user, account: account, role: :agent) }
    let!(:other_team_membership) { create(:team_member, team: team, user: other_agent) }
    let!(:conversation) { create(:conversation, account: account, inbox: inbox, team: team, assignee: other_agent) }

    before do
      other_team_membership.destroy!
      create(:inbox_member, inbox: inbox, user: team_agent)
      create(:inbox_member, inbox: inbox, user: other_agent)
      create(:team_member, team: team, user: team_agent)
      ConversationParticipant.find_or_create_by!(account: account, conversation: conversation, user: other_agent)
    end

    it 'keeps the legacy candidate list when strict visibility is disabled' do
      result = described_class.new(
        conversation: conversation,
        users: [administrator, team_agent, other_agent]
      ).perform

      expect(result).to contain_exactly(administrator, team_agent, other_agent)
    end

    it 'includes only administrators and inbox members of the conversation team in strict mode' do
      account.enable_features!(:strict_team_conversation_visibility)

      result = described_class.new(
        conversation: conversation,
        users: [administrator, team_agent, other_agent]
      ).perform

      expect(result).to contain_exactly(administrator, team_agent)
    end
  end
end
