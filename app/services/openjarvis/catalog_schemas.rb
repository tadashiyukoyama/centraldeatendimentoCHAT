class Openjarvis::CatalogSchemas
  class << self
    def empty
      { type: 'object', additionalProperties: false }
    end

    def object
      { type: 'object' }
    end

    def reference(name)
      { '$ref': "/api/v1/openjarvis/openjarvis-openapi/schemas.yaml#/#{name}" }
    end

    def data
      { type: 'object', required: ['data'], properties: { data: object } }
    end

    def list
      {
        type: 'object', required: ['data'],
        properties: {
          data: { type: 'array', items: object },
          meta: { type: 'object', properties: { has_more: boolean, next_cursor: { type: %w[string null] } } }
        }
      }
    end

    def integer
      { type: 'integer', minimum: 1 }
    end

    def string
      { type: 'string' }
    end

    def boolean
      { type: 'boolean' }
    end

    def identifier(name = 'id')
      filters({ name.to_sym => integer }, required: [name.to_s])
    end

    def filters(properties, required: [])
      schema = { type: 'object', properties: properties, additionalProperties: false }
      schema[:required] = required if required.any?
      schema
    end

    def limit
      filters({ limit: { type: 'integer', minimum: 1, maximum: 100 } })
    end

    def cursor(properties = {}, required: [])
      filters(properties.merge(cursor: string, limit: { type: 'integer', minimum: 1, maximum: 100 }), required: required)
    end

    def with_identifier(schema, name = 'id')
      schema.deep_dup.tap do |result|
        result[:required] = (Array(result[:required]) + [name.to_s]).uniq
        result[:properties] = result.fetch(:properties).merge(name.to_sym => integer)
      end
    end

    def contact_write
      { type: 'object', required: ['contact'], additionalProperties: false, properties: { contact: contact_properties } }
    end

    def conversation_create
      {
        type: 'object', required: ['conversation'], additionalProperties: false,
        properties: { conversation: conversation_create_properties }
      }
    end

    def conversation_update
      {
        type: 'object', required: ['conversation'], additionalProperties: false,
        properties: { conversation: conversation_update_properties }
      }
    end

    def message_write
      { type: 'object', required: ['message'], additionalProperties: false, properties: { message: message_properties } }
    end

    def message_reaction
      filters(
        {
          conversation_id: integer,
          message_id: integer,
          reaction: { type: 'string', maxLength: 64 }
        },
        required: %w[conversation_id message_id reaction]
      )
    end

    def provider_read
      identifier('conversation_id')
    end

    private

    def contact_properties
      {
        type: 'object', properties: {
          name: string, email: { type: 'string', format: 'email' }, phone_number: string,
          identifier: string, contact_type: { type: 'string', enum: Contact.contact_types.keys },
          additional_attributes: object, custom_attributes: object
        }
      }
    end

    def conversation_create_properties
      {
        type: 'object', required: %w[inbox_id contact_id], additionalProperties: false,
        properties: {
          inbox_id: integer, contact_id: integer, status: { type: 'string', enum: Conversation.statuses.keys },
          assignee_id: integer, team_id: integer, additional_attributes: object,
          custom_attributes: object, message: message_properties
        }
      }
    end

    def conversation_update_properties
      {
        type: 'object', additionalProperties: false,
        properties: {
          status: { type: 'string', enum: Conversation.statuses.keys },
          priority: { type: 'string', enum: Conversation.priorities.keys },
          assignee_id: { type: %w[integer null] }, team_id: { type: %w[integer null] },
          snoozed_until: { type: 'string', format: 'date-time' },
          labels: { type: 'array', uniqueItems: true, items: string }
        }
      }
    end

    def message_properties
      {
        type: 'object', additionalProperties: false,
        anyOf: [{ required: ['content'] }, { required: ['remote_attachment'] }],
        properties: {
          content: { type: 'string', minLength: 1, maxLength: 150_000 }, private: boolean,
          content_type: { type: 'string', enum: ['text'] }, reply_to_message_id: integer,
          to_emails: string, cc_emails: string, bcc_emails: string, email_html_content: string,
          content_attributes: object,
          remote_attachment: {
            type: 'object', required: ['url'], additionalProperties: false,
            properties: { url: { type: 'string', format: 'uri', maxLength: 2_048 } }
          }
        }
      }
    end
  end
end
