require 'rails_helper'

RSpec.describe ConversationPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator_context) { { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) } }
  let(:agent_context) { { user: agent, account: account, account_user: agent.account_users.find_by(account: account) } }

  let(:conversation) { create(:conversation, account: account) }

  permissions :destroy? do
    context 'when user is an administrator' do
      it 'allows destroy' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end

    context 'when user is an agent' do
      it 'denies destroy' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end
  end

  permissions :index? do
    context 'when user is authenticated' do
      it 'allows index' do
        expect(subject).to permit(agent_context, conversation)
      end
    end
  end

  permissions :show? do
    context 'when user is an administrator' do
      it 'allows access' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end

    context 'when agent has inbox access' do
      let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox) }

      before { create(:inbox_member, user: agent, inbox: inbox) }

      it 'allows access' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when agent has team access' do
      let(:team) { create(:team, account: account) }
      let(:conversation) { create(:conversation, :with_team, account: account, team: team) }

      before { create(:team_member, team: team, user: agent) }

      it 'allows access' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when agent lacks inbox and team access' do
      let(:conversation) { create(:conversation, account: account) }

      it 'denies access' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end

    context 'when strict team visibility is enabled' do
      let(:inbox) { create(:inbox, account: account) }
      let(:team) { create(:team, account: account, allow_auto_assign: false) }
      let(:other_team) { create(:team, account: account, allow_auto_assign: false) }
      let!(:other_team_membership) { create(:team_member, team: other_team, user: agent) }
      let!(:team_conversation) { create(:conversation, account: account, inbox: inbox, team: team) }
      let!(:other_team_conversation) { create(:conversation, account: account, inbox: inbox, team: other_team, assignee: agent) }
      let!(:unassigned_conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

      before do
        other_team_membership.destroy!
        create(:inbox_member, user: agent, inbox: inbox)
        create(:team_member, user: agent, team: team)
        ConversationParticipant.find_or_create_by!(account: account, conversation: other_team_conversation, user: agent)
        ConversationParticipant.find_or_create_by!(account: account, conversation: unassigned_conversation, user: agent)
        account.enable_features!(:strict_team_conversation_visibility)
      end

      it 'allows a conversation in the agent team' do
        expect(subject).to permit(agent_context, team_conversation)
      end

      it 'denies another team even when the agent is assigned and participating' do
        expect(subject).not_to permit(agent_context, other_team_conversation)
      end

      it 'denies a teamless conversation even when the agent is assigned and participating' do
        expect(subject).not_to permit(agent_context, unassigned_conversation)
      end
    end
  end
end
