class Instagram::CommentAutomation::WebhookSubscriptionService
  REQUIRED_FIELDS = %w[
    messages
    message_reactions
    messaging_seen
    comments
    live_comments
  ].freeze

  Result = Data.define(:success?, :subscribed_fields, :missing_fields, :error_code, :error_type)

  def initialize(channel)
    @client = Instagram::CommentAutomation::ApiClient.new(channel)
  end

  def status
    api_result = @client.subscribed_fields
    return failure(api_result) unless api_result.success?

    fields = Array(api_result.body['subscribed_fields'])
    Result.new(
      success?: true,
      subscribed_fields: fields,
      missing_fields: REQUIRED_FIELDS - fields,
      error_code: nil,
      error_type: nil
    )
  end

  def subscribe
    current = @client.subscribed_fields
    return failure(current) unless current.success?

    fields = (Array(current.body['subscribed_fields']) + REQUIRED_FIELDS).uniq.sort
    api_result = @client.subscribe(fields: fields)
    return failure(api_result) unless api_result.success?

    status
  end

  private

  def failure(api_result)
    Result.new(
      success?: false,
      subscribed_fields: [],
      missing_fields: REQUIRED_FIELDS,
      error_code: api_result.error_code,
      error_type: api_result.error_type
    )
  end
end
