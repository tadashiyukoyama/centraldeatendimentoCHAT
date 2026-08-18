require 'rails_helper'
require 'support/openjarvis_contract_reference_validator'
require 'support/openjarvis_contract_schema_validator'

RSpec.describe Openjarvis::Catalog do
  let(:root) { Rails.root.join('docs/integrations/openjarvis-openapi.yaml') }
  let(:component_root) { Rails.root.join('docs/integrations/openjarvis-openapi') }
  let(:endpoint_fixtures) { JSON.parse(Rails.root.join('spec/fixtures/openjarvis/endpoints.json').read) }
  let(:webhook_fixtures) { JSON.parse(Rails.root.join('spec/fixtures/openjarvis/webhooks.json').read) }
  let(:schema_validator) { OpenjarvisContractSchemaValidator.new }

  it 'publishes OpenAPI 3.1 with resolvable local references' do
    document = load_yaml(root)

    expect(document['openapi']).to eq('3.1.0')
    validator = OpenjarvisContractReferenceValidator.new(allowed_root: Rails.root.join('docs/integrations'))
    expect { validator.validate!(document, root.dirname) }.not_to raise_error
  end

  it 'keeps executable catalog operations aligned with OpenAPI and endpoint fixtures' do
    path_document = load_yaml(component_root.join('paths.yaml'))
    operation_ids = path_document.values.flat_map do |path_item|
      path_item.slice('get', 'post', 'patch', 'delete', 'put').values.pluck('operationId')
    end.compact
    catalog_ids = described_class.operations.pluck(:id)

    expect(operation_ids).to match_array(catalog_ids)
    expect(endpoint_fixtures.keys).to match_array(catalog_ids)
    expect(described_class.operations).to all(include(executable: true, input_schema: be_present, output_schema: be_present))
  end

  it 'provides one sanitized fixture and one OpenAPI schema for every webhook' do
    expected_events = Openjarvis::Configuration::SUBSCRIPTIONS + ['integration.test']
    webhook_document = load_yaml(component_root.join('webhooks.yaml'))
    operation_ids = webhook_document.values.filter_map { |path_item| path_item.dig('post', 'operationId') }

    expect(webhook_fixtures.keys).to match_array(expected_events)
    expect(operation_ids).to match_array(expected_events.map { |event| "webhook.#{event}" })
    webhook_fixtures.each_value do |fixture|
      expect(fixture).to include('schema_version' => '1.0', 'event_id' => be_present, 'resource' => include('sequence', 'version'))
    end
  end

  it 'contains no credential values or production personal data' do
    content = [root, *component_root.glob('*.yaml'), Rails.root.join('spec/fixtures/openjarvis/endpoints.json'),
               Rails.root.join('spec/fixtures/openjarvis/webhooks.json')].map(&:read).join("\n")

    expect(content).not_to match(/ACELERACHAT_BEARER_TOKEN\s*=/)
    expect(content).not_to match(/ACELERACHAT_WEBHOOK_SECRET\s*=/)
    expect(content).not_to include('bellartecomercial@gmail.com')
    expect(content).not_to include('9Vterkc!')
  end

  it 'declares every static public API error emitted by the implementation' do
    sources = Rails.root.glob('{app/controllers/api/v1/openjarvis,app/services/openjarvis}/**/*.rb').map(&:read).join("\n")
    emitted = sources.scan(/Openjarvis::ApiError\.new\(\s*['"]([a-z0-9_]+)['"]/m).flatten.uniq
    declared = Openjarvis::CatalogPolicies::ERROR_DEFINITIONS.keys.map(&:to_s)

    expect(emitted - declared).to be_empty
  end

  it 'keeps all published response examples valid against their named schemas' do
    examples = load_yaml(component_root.join('examples.yaml'))
    mappings = {
      'Catalog' => 'Catalog', 'Health' => 'Health', 'Diagnostics' => 'Diagnostics', 'Operations' => 'Operations',
      'Inboxes' => 'InboxListResponse', 'InboxHealth' => 'InboxHealthResponse', 'Agents' => 'AgentListResponse',
      'Teams' => 'TeamListResponse', 'Labels' => 'LabelListResponse', 'Contact' => 'ContactResponse',
      'Contacts' => 'ContactListResponse', 'Conversation' => 'ConversationResponse',
      'Conversations' => 'ConversationListResponse', 'ConversationRead' => 'ConversationReadResponse',
      'Messages' => 'MessageListResponse', 'MessageAccepted' => 'MessageCreateResponse', 'Backfill' => 'BackfillResponse'
    }

    mappings.each do |example_name, schema_name|
      errors = schema_errors(schema_name, examples.dig(example_name, 'value'))
      expect(errors).to be_empty, "#{example_name} does not match #{schema_name}: #{errors.to_json}"
    end
  end

  it 'keeps every webhook example valid as a versioned envelope with typed data' do
    examples = load_yaml(component_root.join('webhook-examples.yaml'))
    type_schemas = { 'Message' => 'Message', 'Conversation' => 'Conversation', 'Contact' => 'Contact' }

    examples.each_value do |example|
      payload = example.fetch('value')
      expect(schema_errors('WebhookEnvelope', payload)).to be_empty
      schema_name = type_schemas[payload.dig('resource', 'type')]
      expect(schema_errors(schema_name, payload['data'])).to be_empty if schema_name
    end
  end

  private

  def load_yaml(path)
    YAML.safe_load(path.read, aliases: true)
  end

  def schema_errors(name, value)
    schema_validator.errors(name, value)
  end
end
