# frozen_string_literal: true

require 'json'
require 'yaml'

account = Account.find(Integer(ENV.fetch('CAPTAIN_ACCOUNT_ID')))
assistant_ids = ENV.fetch('CAPTAIN_ASSISTANT_IDS').split(',').map { |value| Integer(value.strip) }
assistants = account.captain_assistants.where(id: assistant_ids).order(:id)
raise 'One or more Captain assistants were not found in the account' unless assistants.length == assistant_ids.uniq.length

source_path = Rails.root.join('config/captain/assistants/aifood_manager.yml')
source = YAML.safe_load_file(source_path, permitted_classes: [], aliases: false)
mode = ENV.fetch('CAPTAIN_ASSISTANT_MODE', 'check')
raise 'CAPTAIN_ASSISTANT_MODE must be check or sync' unless %w[check sync].include?(mode)

serialized = source.to_json
raise 'Assistant configuration is not valid UTF-8' if Captain::TextIntegrity.errors(source: serialized).any?

demo_assignee_email = ENV['CAPTAIN_DEMO_ASSIGNEE_EMAIL'].to_s.downcase.presence
raise 'CAPTAIN_DEMO_ASSIGNEE_EMAIL is required for sync' if mode == 'sync' && demo_assignee_email.blank?
if demo_assignee_email && !account.users.exists?(['LOWER(email) = ?', demo_assignee_email])
  raise 'CAPTAIN_DEMO_ASSIGNEE_EMAIL does not belong to this account'
end

results = assistants.map do |assistant|
  target_config = assistant.config.to_h.merge(source.fetch('config')).merge('product_name' => source.fetch('product_name'))
  target_config['demo_assignee_email'] = demo_assignee_email if demo_assignee_email
  changes = {
    name: [assistant.name, source.fetch('name')],
    description: [assistant.description, source.fetch('description')],
    config: [assistant.config, target_config],
    response_guidelines: [assistant.response_guidelines, source.fetch('response_guidelines')],
    guardrails: [assistant.guardrails, source.fetch('guardrails')]
  }.reject { |_attribute, values| values.first == values.last }

  if mode == 'sync' && changes.any?
    assistant.update!(
      name: source.fetch('name'),
      description: source.fetch('description'),
      config: target_config,
      response_guidelines: source.fetch('response_guidelines'),
      guardrails: source.fetch('guardrails')
    )
  end

  {
    assistant_id: assistant.id,
    assistant_name: assistant.name,
    changed_fields: changes.keys,
    valid_utf8: true
  }
end

# This is an operator CLI; machine-readable stdout is its public contract.
puts JSON.pretty_generate(mode: mode, source_version: source.fetch('version'), assistants: results) # rubocop:disable Rails/Output
