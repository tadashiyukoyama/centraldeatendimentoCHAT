# frozen_string_literal: true

# Curate the public AI Food Manager knowledge for Captain.
#
# The YAML file is the reviewable source of truth. Existing response IDs are
# used only as migration anchors; new responses are created when a definition
# does not have a legacy record. Anything not present in the curated file is
# kept for audit but moved to pending so it cannot be retrieved by the agent.
#
# Run with:
#   CAPTAIN_ACCOUNT_ID=1 CAPTAIN_DOCUMENT_ID=2 bundle exec rails runner scripts/revise_captain_knowledge_base.rb

require 'yaml'

account = Account.find(Integer(ENV.fetch('CAPTAIN_ACCOUNT_ID')))
assistant = account.captain_assistants.order(:id).first or raise 'Captain assistant not found'
document = assistant.documents.find(Integer(ENV.fetch('CAPTAIN_DOCUMENT_ID')))
source_path = Rails.root.join('config/captain/knowledge/aifood_manager_faqs.yml')
source = YAML.safe_load_file(source_path, permitted_classes: [], aliases: false)
definitions = source.fetch('definitions')

existing = assistant.responses.where(documentable: document).to_a
managed_ids = []

ActiveRecord::Base.transaction do
  definitions.each do |definition|
    legacy_ids = Array(definition['legacy_ids']).map(&:to_i)
    response = existing.find { |record| legacy_ids.include?(record.id) }
    response ||= existing.find { |record| record.question == definition.fetch('question') }
    response ||= assistant.responses.build(documentable: document)

    response.assign_attributes(
      question: definition.fetch('question'),
      answer: definition.fetch('answer'),
      status: :approved,
      documentable: document
    )
    response.save!
    managed_ids << response.id
  end

  existing.reject { |record| managed_ids.include?(record.id) }.each do |record|
    record.update!(status: :pending)
  end
end

puts({
  account_id: account.id,
  assistant_id: assistant.id,
  document_id: document.id,
  source: source_path.to_s,
  approved_ids: managed_ids,
  approved_count: managed_ids.length,
  pending_count: existing.count { |record| managed_ids.exclude?(record.id) }
}.to_json)
