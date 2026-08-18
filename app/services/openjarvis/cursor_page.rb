class Openjarvis::CursorPage
  Result = Data.define(:records, :meta)

  def initialize(scope:, cursor:, limit:, type:, **options)
    @scope = scope
    @cursor = cursor
    @limit = limit
    @type = type
    @timestamp_column = options.fetch(:timestamp_column).to_sym
    @direction = options.fetch(:direction, :desc).to_sym
  end

  def perform
    ordered_scope = apply_cursor(scope)
                    .reorder(timestamp_column => direction, :id => direction)
                    .limit(limit + 1)
    records = ordered_scope.to_a
    has_more = records.size > limit
    records = records.first(limit)
    Result.new(records: records, meta: metadata(records, has_more))
  end

  private

  attr_reader :scope, :cursor, :limit, :type, :timestamp_column, :direction

  def apply_cursor(relation)
    return relation if cursor.blank?

    value = Openjarvis::Cursor.decode(cursor, type: type, direction: direction)
    operator = direction == :desc ? :lt : :gt
    table = relation.klass.arel_table
    timestamp = table[timestamp_column]
    id = table[:id]
    relation.where(timestamp.public_send(operator, value[:timestamp]).or(timestamp.eq(value[:timestamp]).and(id.public_send(operator, value[:id]))))
  end

  def metadata(records, has_more)
    next_cursor = if has_more && records.any?
                    last = records.last
                    Openjarvis::Cursor.encode(
                      type: type,
                      timestamp: last.public_send(timestamp_column),
                      id: last.id,
                      direction: direction
                    )
                  end
    { limit: limit, returned: records.size, has_more: has_more, next_cursor: next_cursor }
  end
end
