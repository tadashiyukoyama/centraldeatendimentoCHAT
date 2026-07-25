require 'rails_helper'

RSpec.describe ConversationPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent_account_user) { agent.account_users.find_by(account: account) }
  let(:context) { { user: agent, account: account, account_user: agent_account_user } }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
  end

  permissions :show? do
    context 'when role grants conversation_unassigned_manage' do
      let(:custom_role) { create(:custom_role, account: account, permissions: ['conversation_unassigned_manage']) }

      before do
        agent_account_user.update!(role: :agent, custom_role: custom_role)
      end

      it 'allows access to conversations assigned to the agent' do
        conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)

        expect(subject).to permit(context, conversation)
      end

      it 'denies access to conversations assigned to someone else' do
        other_agent = create(:user, account: account, role: :agent)
        conversation = create(:conversation, account: account, inbox: inbox, assignee: other_agent)

        expect(subject).not_to permit(context, conversation)
      end
    end

    context 'when role grants conversation_participating_manage' do
      let(:custom_role) { create(:custom_role, account: account, permissions: ['conversation_participating_manage']) }

      before do
        agent_account_user.update!(role: :agent, custom_role: custom_role)
      end

      it 'allows access to conversations assigned to the agent' do
        conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)

        expect(subject).to permit(context, conversation)
      end

      it 'allows access to conversations where the agent is a participant' do
        conversation = create(:conversation, account: account, inbox: inbox, assignee: nil)
        create(:conversation_participant, conversation: conversation, account: account, user: agent)

        expect(subject).to permit(context, conversation)
      end

      it 'denies access to unrelated conversations' do
        conversation = create(:conversation, account: account, inbox: inbox, assignee: nil)

        expect(subject).not_to permit(context, conversation)
      end
    end

    context 'when strict team visibility is enabled' do
      let(:other_team) { create(:team, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, team: other_team) }

      before do
        account.enable_features!(:strict_team_conversation_visibility)
      end

      it 'allows a manager with conversation_manage to view every team in a managed inbox' do
        manager_role = create(:custom_role, account: account, permissions: ['conversation_manage'])
        agent_account_user.update!(role: :agent, custom_role: manager_role)

        expect(subject).to permit(context, conversation)
      end

      it 'denies a manager access to an inbox they do not manage' do
        manager_role = create(:custom_role, account: account, permissions: ['conversation_manage'])
        agent_account_user.update!(role: :agent, custom_role: manager_role)
        unmanaged_conversation = create(:conversation, account: account, inbox: create(:inbox, account: account))

        expect(subject).not_to permit(context, unmanaged_conversation)
      end

      it 'denies cross-team participation for a non-manager custom role' do
        participant_role = create(:custom_role, account: account, permissions: ['conversation_participating_manage'])
        agent_account_user.update!(role: :agent, custom_role: participant_role)
        ConversationParticipant.find_or_create_by!(account: account, conversation: conversation, user: agent)

        expect(subject).not_to permit(context, conversation)
      end

      it 'allows a non-manager custom role to view conversations from its own team' do
        participant_role = create(:custom_role, account: account, permissions: ['conversation_participating_manage'])
        agent_account_user.update!(role: :agent, custom_role: participant_role)
        create(:team_member, team: other_team, user: agent)

        expect(subject).to permit(context, conversation)
      end
    end
  end
end
