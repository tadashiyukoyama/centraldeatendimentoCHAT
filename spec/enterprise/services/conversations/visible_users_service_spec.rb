require 'rails_helper'

RSpec.describe Conversations::VisibleUsersService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team) }
  let(:manager) { create(:user, account: account, role: :agent) }
  let(:manager_without_inbox) { create(:user, account: account, role: :agent) }
  let(:manager_role) { create(:custom_role, account: account, permissions: ['conversation_manage']) }

  before do
    manager.account_users.find_by(account: account).update!(custom_role: manager_role)
    manager_without_inbox.account_users.find_by(account: account).update!(custom_role: manager_role)
    create(:inbox_member, inbox: inbox, user: manager)
    account.enable_features!(:strict_team_conversation_visibility)
  end

  it 'broadcasts strict conversation events to managers of the inbox' do
    result = described_class.new(
      conversation: conversation,
      users: [manager, manager_without_inbox]
    ).perform

    expect(result).to contain_exactly(manager)
  end
end
