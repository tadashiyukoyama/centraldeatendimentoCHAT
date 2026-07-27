class Instagram::CommentAutomation::ProcessEventJob < ApplicationJob
  queue_as :default

  RETRY_DELAYS = [30.seconds, 2.minutes, 10.minutes, 30.minutes, 2.hours].freeze

  def perform(event_id)
    @event = InstagramCommentEvent.find_by(id: event_id)
    return if @event.blank? || !@event.claim_for_processing!

    @automation = @event.instagram_comment_automation
    return ignore_event('automation_unavailable') unless automation_available?
    return ignore_event('automation_outside_schedule') unless @automation.active_at?(@event.received_at)

    @client = Instagram::CommentAutomation::ApiClient.new(@event.inbox.channel)
    deliver_replies
    finish_processing
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @event&.account).capture_exception
    handle_unexpected_failure(e)
  end

  private

  def automation_available?
    @automation.present? && @automation.enabled?
  end

  def deliver_replies
    deliver_public_reply if @event.public_reply_pending? || @event.public_reply_transient_failure?
    deliver_private_reply if @event.private_reply_pending? || @event.private_reply_transient_failure?
  end

  def finish_processing
    if transient_failure? && @event.processing_attempts < InstagramCommentEvent::MAX_PROCESSING_ATTEMPTS
      schedule_retry
    else
      @event.finalize_delivery!
    end
  end

  def deliver_public_reply
    result = @client.reply_publicly(comment_id: @event.comment_id, text: rendered_public_reply)
    update_reply(:public, result, external_id: result.body['id'])
  end

  def deliver_private_reply
    result = @client.reply_privately(comment_id: @event.comment_id, text: rendered_private_reply)
    update_reply(
      :private,
      result,
      external_id: result.body['message_id'],
      recipient_id: result.body['recipient_id']
    )
  end

  def update_reply(kind, result, external_id:, recipient_id: nil)
    status = if result.success?
               :succeeded
             elsif result.transient?
               :transient_failure
             else
               :permanent_failure
             end

    attributes = {
      "#{kind}_reply_status" => status,
      "#{kind}_reply_external_id" => external_id,
      "#{kind}_reply_error_code" => result.success? ? nil : result.error_code
    }
    attributes['private_reply_recipient_id'] = recipient_id if kind == :private && recipient_id.present?
    @event.update!(attributes)
  end

  def rendered_public_reply
    render(@automation.public_reply_template, InstagramCommentAutomation::MAX_PUBLIC_REPLY_LENGTH)
  end

  def rendered_private_reply
    render(@automation.private_reply_template, InstagramCommentAutomation::MAX_PRIVATE_REPLY_LENGTH)
  end

  def render(template, max_length)
    Instagram::CommentAutomation::TemplateRenderer.new(
      template,
      allowed_variables: InstagramCommentAutomation::TEMPLATE_VARIABLES
    ).render(
      {
        campaign: @automation.name,
        comment: @event.comment_text,
        keyword: @event.matched_keyword,
        username: @event.sender_username.presence || 'cliente'
      },
      max_length: max_length
    )
  end

  def transient_failure?
    @event.public_reply_transient_failure? || @event.private_reply_transient_failure?
  end

  def schedule_retry
    delay = RETRY_DELAYS.fetch(@event.processing_attempts - 1, RETRY_DELAYS.last)
    retry_at = Time.current + delay
    @event.update!(status: :retrying, retry_at: retry_at, processing_started_at: nil)
    self.class.set(wait: delay).perform_later(@event.id)
  end

  def ignore_event(reason)
    @event.update!(status: :ignored, ignore_reason: reason, processed_at: Time.current, processing_started_at: nil)
  end

  def handle_unexpected_failure(error)
    return unless @event&.persisted?

    attributes = unfinished_reply_attributes(error)
    @event.update!(attributes) if attributes.any?
    finish_processing
  end

  def unfinished_reply_attributes(error)
    %i[public private].each_with_object({}) do |kind, attributes|
      status = @event.public_send("#{kind}_reply_status")
      next unless status.in?(%w[pending transient_failure])

      attributes["#{kind}_reply_status"] = :transient_failure
      attributes["#{kind}_reply_error_code"] = error.class.name
    end
  end
end
