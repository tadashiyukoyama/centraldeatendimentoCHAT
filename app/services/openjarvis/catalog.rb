class Openjarvis::Catalog
  VERSION = '2026-08-18'.freeze

  def self.as_json
    {
      name: 'AceleraChat OpenJarvis API',
      version: VERSION,
      authentication: { type: 'bearer', header: 'Authorization' },
      idempotency: {
        required_for: %w[POST PATCH],
        header: 'Idempotency-Key',
        minimum_length: 8,
        replay_header: 'Idempotency-Replayed'
      },
      scopes: Openjarvis::Configuration::SCOPES,
      webhook_subscriptions: Openjarvis::Configuration::SUBSCRIPTIONS,
      endpoints: endpoint_catalog
    }
  end

  def self.endpoint_catalog
    [
      endpoint('GET', '/api/v1/openjarvis/catalog', nil, 'Describe the stable integration contract'),
      endpoint('GET', '/api/v1/openjarvis/health', nil, 'Check authenticated integration health'),
      endpoint('GET', '/api/v1/openjarvis/diagnostics', 'diagnostics:read', 'Read sanitized application diagnostics'),
      endpoint('GET', '/api/v1/openjarvis/operations', 'diagnostics:read', 'Read sanitized integration activity'),
      endpoint('GET', '/api/v1/openjarvis/inboxes', 'inboxes:read', 'List authorized inboxes'),
      endpoint('GET', '/api/v1/openjarvis/contacts', 'contacts:read', 'Search authorized contacts'),
      endpoint('GET', '/api/v1/openjarvis/contacts/:id', 'contacts:read', 'Read an authorized contact'),
      endpoint('POST', '/api/v1/openjarvis/contacts', 'contacts:write', 'Create or reuse a contact'),
      endpoint('PATCH', '/api/v1/openjarvis/contacts/:id', 'contacts:write', 'Update an authorized contact'),
      endpoint('GET', '/api/v1/openjarvis/conversations', 'conversations:read', 'List authorized conversations'),
      endpoint('GET', '/api/v1/openjarvis/conversations/:id', 'conversations:read', 'Read a conversation'),
      endpoint('POST', '/api/v1/openjarvis/conversations', 'conversations:write', 'Create a conversation in an authorized inbox'),
      endpoint('PATCH', '/api/v1/openjarvis/conversations/:id', 'conversations:write', 'Update status, priority, assignment or labels'),
      endpoint('GET', '/api/v1/openjarvis/conversations/:conversation_id/messages', 'messages:read', 'List messages'),
      endpoint('POST', '/api/v1/openjarvis/conversations/:conversation_id/messages', 'messages:write', 'Send a message through AceleraChat')
    ]
  end

  def self.endpoint(method, path, scope, description)
    { method: method, path: path, scope: scope, description: description }.compact
  end

  private_class_method :endpoint
end
