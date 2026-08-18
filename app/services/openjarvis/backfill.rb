class Openjarvis::Backfill
  RESOURCE_TYPES = %w[contacts conversations messages].freeze
  Result = Data.define(:data, :meta)

  def initialize(hook:, access_scope:, resource_type:, cursor:, limit:)
    @hook = hook
    @access_scope = access_scope
    @resource_type = resource_type.to_s
    @cursor = cursor
    @limit = limit
  end

  def perform
    unless RESOURCE_TYPES.include?(resource_type)
      raise Openjarvis::ApiError.new(
        'invalid_backfill_resource',
        "resource must be one of: #{RESOURCE_TYPES.join(', ')}",
        status: :bad_request
      )
    end

    page = Openjarvis::CursorPage.new(
      scope: relation,
      cursor: cursor,
      limit: limit,
      type: "backfill:#{resource_type}",
      timestamp_column: :updated_at,
      direction: :asc
    ).perform
    Result.new(data: page.records.map { |record| snapshot(record) }, meta: page.meta.merge(resource: resource_type))
  end

  private

  attr_reader :hook, :access_scope, :resource_type, :cursor, :limit

  def relation
    case resource_type
    when 'contacts' then access_scope.contacts
    when 'conversations' then access_scope.conversations.includes(:inbox, :contact, :assignee, :team)
    when 'messages' then access_scope.messages.includes(:sender, attachments: { file_attachment: :blob })
    end
  end

  def snapshot(record)
    sequence = Openjarvis::ResourceSequence.current_for(hook: hook, resource: record)
    identity = Openjarvis::ResourceIdentity.new(record, sequence: sequence)
    {
      schema_version: Openjarvis::Configuration::SCHEMA_VERSION,
      event_id: "backfill:#{record.class.base_class.name}:#{record.id}:#{Digest::SHA256.hexdigest(identity.version).first(16)}",
      event: 'resource.snapshot',
      occurred_at: record.updated_at.utc.iso8601(6),
      resource: identity.as_json,
      data: present(record)
    }
  end

  def present(record)
    case record
    when Contact then Openjarvis::ContactPresenter.new(record).as_json
    when Conversation then Openjarvis::ConversationPresenter.new(record, include_last_message: false).as_json
    when Message then Openjarvis::MessagePresenter.new(record).as_json
    end
  end
end
