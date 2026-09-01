require 'rails_helper'

RSpec.describe Openjarvis::AccessScope do
  let(:account) { create(:account) }
  let(:service_user) { create(:user, account: account, role: :agent) }
  let(:allowed_inbox) { create(:inbox, account: account) }
  let(:other_inbox) { create(:inbox, account: account) }
  let(:hook) do
    create(
      :integrations_hook,
      :openjarvis,
      account: account,
      service_user: service_user,
      allowed_inboxes: [allowed_inbox]
    )
  end

  before do
    create(:inbox_member, user: service_user, inbox: allowed_inbox)
    create(:inbox_member, user: service_user, inbox: other_inbox)
  end

  it 'limits conversations to configured inboxes even when the user can access more inboxes' do
    allowed_conversation = create(:conversation, account: account, inbox: allowed_inbox)
    create(:conversation, account: account, inbox: other_inbox)

    expect(described_class.new(hook).conversations).to contain_exactly(allowed_conversation)
  end

  it 'does not bypass strict team visibility' do
    account.enable_features!(:strict_team_conversation_visibility)
    visible_team = create(:team, account: account)
    hidden_team = create(:team, account: account)
    create(:team_member, user: service_user, team: visible_team)
    visible = create(:conversation, account: account, inbox: allowed_inbox, team: visible_team)
    create(:conversation, account: account, inbox: allowed_inbox, team: hidden_team)

    expect(described_class.new(hook).conversations).to contain_exactly(visible)
  end

  it 'dynamically includes future inboxes in all-account mode without crossing accounts' do
    administrator = create(:user, account: account, role: :administrator)
    hook.update!(
      settings: hook.settings.merge(
        'service_user_id' => administrator.id,
        'inbox_access_mode' => 'all_account',
        'allowed_inbox_ids' => []
      )
    )
    future_inbox = create(:inbox, account: account)
    create(:inbox)

    expect(described_class.new(hook).inboxes).to contain_exactly(allowed_inbox, other_inbox, future_inbox)
  end
end
