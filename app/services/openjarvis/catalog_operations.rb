class Openjarvis::CatalogOperations
  EXECUTABLE_DEFAULTS = { executable: true, idempotency_required: false }.freeze

  class << self
    def all
      @all ||= [system_operations, resource_operations, contact_operations, conversation_operations, message_operations].flatten.map do |item|
        EXECUTABLE_DEFAULTS.merge(item)
      end.freeze
    end

    private

    # These methods are declarative API registries; call count does not represent branching complexity.
    # rubocop:disable Metrics/AbcSize
    def system_operations
      [
        operation('catalog.get', 'GET', '/api/v1/openjarvis/catalog', 'Read executable contract', schemas.empty,
                  schemas.reference('Catalog')),
        operation('openapi.get', 'GET', '/api/v1/openjarvis/openapi', 'Read the OpenAPI 3.1 document', schemas.empty,
                  { type: 'string', content_media_type: 'application/yaml' }),
        operation('health.get', 'GET', '/api/v1/openjarvis/health', 'Read integration health', schemas.empty,
                  schemas.reference('Health')),
        operation('diagnostics.get', 'GET', '/api/v1/openjarvis/diagnostics', 'Read sanitized diagnostics', schemas.empty,
                  schemas.reference('Diagnostics'), scope: 'diagnostics:read'),
        operation('operations.list', 'GET', '/api/v1/openjarvis/operations', 'Read API and webhook ledgers', schemas.limit,
                  schemas.reference('Operations'), scope: 'diagnostics:read'),
        operation('sync.backfill', 'GET', '/api/v1/openjarvis/backfill', 'Backfill resource snapshots for reconciliation',
                  schemas.cursor({ resource: { type: 'string', enum: Openjarvis::Backfill::RESOURCE_TYPES } }, required: ['resource']),
                  schemas.reference('BackfillResponse'), scope: 'sync:read')
      ]
    end

    def resource_operations
      [
        operation('inboxes.list', 'GET', '/api/v1/openjarvis/inboxes', 'List authorized inboxes and capabilities', schemas.empty,
                  schemas.reference('InboxListResponse'), scope: 'inboxes:read'),
        operation('inboxes.health', 'GET', '/api/v1/openjarvis/inboxes/{inbox_id}/health', 'Read inbox connection and capabilities',
                  schemas.identifier('inbox_id'), schemas.reference('InboxHealthResponse'), scope: 'inboxes:read'),
        operation('agents.list', 'GET', '/api/v1/openjarvis/agents', 'Resolve assignable agents',
                  schemas.filters({ inbox_id: schemas.integer }), schemas.reference('AgentListResponse'), scope: 'resources:read'),
        operation('teams.list', 'GET', '/api/v1/openjarvis/teams', 'Resolve assignable teams', schemas.empty,
                  schemas.reference('TeamListResponse'),
                  scope: 'resources:read'),
        operation('labels.list', 'GET', '/api/v1/openjarvis/labels', 'Resolve existing labels', schemas.empty,
                  schemas.reference('LabelListResponse'),
                  scope: 'resources:read')
      ]
    end

    def contact_operations
      [
        operation('contacts.search', 'GET', '/api/v1/openjarvis/contacts', 'Search contacts with stable cursor',
                  schemas.cursor({ q: schemas.string }), schemas.reference('ContactListResponse'), scope: 'contacts:read'),
        operation('contacts.get', 'GET', '/api/v1/openjarvis/contacts/{id}', 'Read a contact', schemas.identifier,
                  schemas.reference('ContactResponse'),
                  scope: 'contacts:read'),
        operation('contacts.create', 'POST', '/api/v1/openjarvis/contacts', 'Create or reuse a contact', schemas.contact_write,
                  schemas.reference('ContactResponse'), scope: 'contacts:write', idempotent: true),
        operation('contacts.update', 'PATCH', '/api/v1/openjarvis/contacts/{id}', 'Update a contact',
                  schemas.with_identifier(schemas.contact_write),
                  schemas.reference('ContactResponse'), scope: 'contacts:write', idempotent: true)
      ]
    end

    def conversation_operations
      search_filters = { contact_id: schemas.integer, inbox_id: schemas.integer, status: schemas.string, updated_after: schemas.string }
      [
        operation('conversations.search', 'GET', '/api/v1/openjarvis/conversations', 'Search by contact, inbox and status',
                  schemas.cursor(search_filters), schemas.reference('ConversationListResponse'), scope: 'conversations:read'),
        operation('conversations.get', 'GET', '/api/v1/openjarvis/conversations/{id}', 'Read a conversation', schemas.identifier,
                  schemas.reference('ConversationResponse'), scope: 'conversations:read'),
        operation('conversations.create', 'POST', '/api/v1/openjarvis/conversations', 'Create with a server-resolved association',
                  schemas.conversation_create, schemas.reference('ConversationResponse'), scope: 'conversations:write', idempotent: true),
        operation('conversations.update', 'PATCH', '/api/v1/openjarvis/conversations/{id}', 'Update conversation routing',
                  schemas.with_identifier(schemas.conversation_update), schemas.reference('ConversationResponse'),
                  scope: 'conversations:write', idempotent: true),
        operation('conversations.mark_read', 'POST', '/api/v1/openjarvis/conversations/{id}/read', 'Mark read inside AceleraChat',
                  schemas.identifier, schemas.reference('ConversationReadResponse'), scope: 'conversations:write', idempotent: true)
      ]
    end

    def message_operations
      [
        operation('messages.search', 'GET', '/api/v1/openjarvis/messages', 'Search authorized messages',
                  schemas.cursor(message_search_filters), schemas.reference('MessageListResponse'), scope: 'messages:read'),
        operation('messages.list', 'GET', '/api/v1/openjarvis/conversations/{conversation_id}/messages', 'List conversation messages',
                  schemas.cursor({ conversation_id: schemas.integer }, required: ['conversation_id']),
                  schemas.reference('MessageListResponse'), scope: 'messages:read'),
        operation('messages.create', 'POST', '/api/v1/openjarvis/conversations/{conversation_id}/messages', 'Create a message or reply',
                  schemas.with_identifier(schemas.message_write, 'conversation_id'), schemas.reference('MessageCreateResponse'),
                  scope: 'messages:write', idempotent: true),
        operation('messages.reaction', 'POST',
                  '/api/v1/openjarvis/conversations/{conversation_id}/messages/{message_id}/reaction',
                  'Set or remove an Evolution WhatsApp reaction', schemas.message_reaction,
                  schemas.reference('MessageReactionResponse'), scope: 'messages:react', idempotent: true),
        operation('messages.provider_read', 'POST', '/api/v1/openjarvis/conversations/{conversation_id}/provider_read',
                  'Send Evolution WhatsApp read receipts and update AceleraChat', schemas.provider_read,
                  schemas.reference('ProviderReadResponse'), scope: 'messages:read_receipts', idempotent: true)
      ]
    end

    def message_search_filters
      {
        q: schemas.string, inbox_id: schemas.integer, contact_id: schemas.integer,
        conversation_id: schemas.integer, unread: schemas.boolean
      }
    end
    # rubocop:enable Metrics/AbcSize

    def operation(*values, **options)
      values => [id, method, path, description, input_schema, output_schema]
      {
        id: id, method: method, path: path, scope: options[:scope], description: description,
        idempotency_required: options.fetch(:idempotent, false), input_schema: input_schema, output_schema: output_schema
      }.compact
    end

    def schemas
      Openjarvis::CatalogSchemas
    end
  end
end
