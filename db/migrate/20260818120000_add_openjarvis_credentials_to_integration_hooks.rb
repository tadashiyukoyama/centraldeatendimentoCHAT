class AddOpenjarvisCredentialsToIntegrationHooks < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :integrations_hooks, :webhook_secret, :string
    add_column :integrations_hooks, :access_token_rotated_at, :datetime
    add_column :integrations_hooks, :webhook_secret_rotated_at, :datetime
    add_index(
      :integrations_hooks,
      :access_token,
      unique: true,
      where: "app_id = 'openjarvis'",
      name: 'idx_integration_hooks_openjarvis_token',
      algorithm: :concurrently
    )
  end
end
