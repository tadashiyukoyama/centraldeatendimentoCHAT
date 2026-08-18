class AddOpenjarvisContractScopes < ActiveRecord::Migration[7.1]
  SCOPES = %w[resources:read sync:read].freeze

  def up
    each_openjarvis_hook do |hook|
      settings = hook.settings.to_h.stringify_keys
      settings['scopes'] = (Array(settings['scopes']) + SCOPES).uniq
      hook.update_columns(settings: settings, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    each_openjarvis_hook do |hook|
      settings = hook.settings.to_h.stringify_keys
      settings['scopes'] = Array(settings['scopes']) - SCOPES
      hook.update_columns(settings: settings, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  private

  def each_openjarvis_hook(&)
    hook_model.where(app_id: 'openjarvis').find_each(&)
  end

  def hook_model
    @hook_model ||= Class.new(ActiveRecord::Base) do
      self.table_name = 'integrations_hooks'
    end
  end
end
