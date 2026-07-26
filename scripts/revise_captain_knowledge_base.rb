# frozen_string_literal: true

# Check:
#   CAPTAIN_ACCOUNT_ID=1 CAPTAIN_ASSISTANT_IDS=2,3 CAPTAIN_KNOWLEDGE_MODE=check \
#     bundle exec rails runner scripts/revise_captain_knowledge_base.rb
#
# Sync:
#   CAPTAIN_ACCOUNT_ID=1 CAPTAIN_ASSISTANT_IDS=2,3 CAPTAIN_KNOWLEDGE_MODE=sync \
#     bundle exec rails runner scripts/revise_captain_knowledge_base.rb

require 'json'

account = Account.find(Integer(ENV.fetch('CAPTAIN_ACCOUNT_ID')))
assistant_ids = ENV.fetch('CAPTAIN_ASSISTANT_IDS').split(',').map { |value| Integer(value.strip) }
assistants = account.captain_assistants.where(id: assistant_ids).order(:id)
raise 'One or more Captain assistants were not found in the account' unless assistants.length == assistant_ids.uniq.length

source_path = Rails.root.join('config/captain/knowledge/aifood_manager_faqs.yml')
service = Captain::Knowledge::RepositorySyncService.new(
  account: account,
  assistants: assistants,
  source_path: source_path
)
mode = ENV.fetch('CAPTAIN_KNOWLEDGE_MODE', 'check')
result = case mode
         when 'check'
           service.check
         when 'sync'
           service.sync
         else
           raise 'CAPTAIN_KNOWLEDGE_MODE must be check or sync'
         end

# This is an operator CLI; machine-readable stdout is its public contract.
puts JSON.pretty_generate(result) # rubocop:disable Rails/Output
