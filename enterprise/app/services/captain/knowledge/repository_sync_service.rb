require 'yaml'

class Captain::Knowledge::RepositorySyncService
  MANAGED_SOURCE = 'aifood_manager_repository_faqs'.freeze
  PUBLIC_SOURCE_URL = 'https://www.aifoodmanager.pro/funcionalidades'.freeze

  def initialize(account:, assistants:, source_path:)
    @account = account
    @assistants = assistants
    @source_path = source_path
  end

  def check
    source = load_source
    {
      mode: 'check',
      source_version: source.fetch('version'),
      definitions: source.fetch('definitions').length,
      assistants: @assistants.map { |assistant| assistant_plan(assistant, source.fetch('definitions')) }
    }
  end

  def sync
    source = load_source
    results = []
    ActiveRecord::Base.transaction do
      @assistants.each do |assistant|
        results << sync_assistant(assistant, source.fetch('definitions'))
      end
    end
    {
      mode: 'sync',
      source_version: source.fetch('version'),
      assistants: results
    }
  end

  private

  def load_source
    source = YAML.safe_load_file(@source_path, permitted_classes: [], aliases: false)
    definitions = source.fetch('definitions')
    keys = definitions.map { |definition| definition.fetch('key') }
    raise 'Duplicate FAQ keys' unless keys.uniq.length == keys.length

    definitions.each do |definition|
      validate_utf8!(definition.fetch('question'))
      validate_utf8!(definition.fetch('answer'))
    end
    source
  end

  def validate_utf8!(value)
    return if Captain::TextIntegrity.errors(content: value.to_s).empty?

    raise 'Invalid UTF-8 in repository FAQ source'
  end

  def assistant_plan(assistant, definitions)
    existing = assistant.responses
    target_document = assistant.documents.find_by(external_link: PUBLIC_SOURCE_URL)
    matched_ids = definitions.filter_map { |definition| matching_response(existing, definition)&.id }.uniq
    {
      assistant_id: assistant.id,
      assistant_name: assistant.name,
      approved_after_sync: definitions.length,
      creates: definitions.count { |definition| matching_response(existing, definition).nil? },
      updates: definitions.count do |definition|
        response_changed?(matching_response(existing, definition), definition, target_document)
      end,
      retires: assistant.responses.approved.where.not(id: matched_ids).count
    }
  end

  def sync_assistant(assistant, definitions)
    document = managed_document(assistant, definitions)
    existing = assistant.responses.where(documentable: document).to_a
    managed_ids = sync_definitions(assistant, document, definitions)
    retire_unmanaged_responses(assistant, existing, managed_ids)

    {
      assistant_id: assistant.id,
      assistant_name: assistant.name,
      document_id: document.id,
      approved_ids: managed_ids,
      approved_count: managed_ids.length
    }
  end

  def sync_definitions(assistant, document, definitions)
    definitions.map do |definition|
      response = matching_response(assistant.responses, definition) || assistant.responses.build
      response.assign_attributes(
        question: definition.fetch('question'),
        answer: definition.fetch('answer'),
        status: :approved,
        documentable: document
      )
      response.save!
      response.id
    end
  end

  def retire_unmanaged_responses(assistant, existing, managed_ids)
    existing.reject { |response| managed_ids.include?(response.id) }
            .each { |response| response.update!(status: :pending) }
    assistant.responses.where.not(id: managed_ids).approved
             .find_each { |response| response.update!(status: :pending) }
  end

  def managed_document(assistant, _definitions)
    document = assistant.documents.find_or_initialize_by(external_link: PUBLIC_SOURCE_URL)
    document.assign_attributes(
      account: @account,
      name: 'AI Food Manager — base oficial revisada',
      status: :available,
      sync_status: :synced,
      last_synced_at: Time.current,
      metadata: document.metadata.to_h.merge('managed_source' => MANAGED_SOURCE)
    )
    document.save!
    document
  end

  def matching_response(scope, definition)
    legacy_ids = Array(definition['legacy_ids']).map(&:to_i)
    scope.find_by(id: legacy_ids) || scope.find_by(question: definition.fetch('question'))
  end

  def response_changed?(response, definition, target_document)
    return false unless response

    response.question != definition.fetch('question') ||
      response.answer != definition.fetch('answer') ||
      !response.approved? ||
      target_document.nil? ||
      response.documentable != target_document
  end
end
