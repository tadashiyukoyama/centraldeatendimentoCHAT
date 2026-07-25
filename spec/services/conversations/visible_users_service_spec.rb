require 'rails_helper'

RSpec.describe Conversations::VisibleUsersService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
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
