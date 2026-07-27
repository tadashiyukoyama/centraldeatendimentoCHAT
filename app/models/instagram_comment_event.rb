class InstagramCommentEvent < ApplicationRecord
  MAX_PROCESSING_ATTEMPTS = 5
  STALE_PROCESSING_AFTER = 5.minutes

  belongs_to :account
  belongs_to :inbox
  belongs_to :instagram_comment_automation, optional: true
  belongs_to :conversation, optional: true

  encrypts :comment_text, :sender_username if Chatwoot.encryption_configured?

  enum :status, {
    received: 0,
    matched: 1,
    processing: 2,
    retrying: 3,
    completed: 4,
    partially_failed: 5,
    failed: 6,
    ignored: 7
  }
  enum :public_reply_status, {
    not_requested: 0,
    pending: 1,
    succeeded: 2,
    permanent_failure: 3,
    transient_failure: 4
  }, prefix: :public_reply
  enum :private_reply_status, {
    not_requested: 0,
    pending: 1,
    succeeded: 2,
    permanent_failure: 3,
    transient_failure: 4
  }, prefix: :private_reply

  validates :comment_id, :media_id, :comment_text, :webhook_field, :received_at, presence: true
  validates :comment_id, uniqueness: { scope: :inbox_id }
  validates :webhook_field, inclusion: { in: %w[comments live_comments] }

  scope :retention_expired, -> { where(created_at: ...90.days.ago) }

  def terminal?
    completed? || partially_failed? || failed? || ignored?
  end

  def claim_for_processing!
    with_lock do
      next false if terminal?
      next false if processing? && processing_started_at.present? && processing_started_at > STALE_PROCESSING_AFTER.ago
      next false if processing_attempts >= MAX_PROCESSING_ATTEMPTS

      update!(
        status: :processing,
        processing_attempts: processing_attempts + 1,
        processing_started_at: Time.current,
        retry_at: nil
      )
      true
    end
  end

  def finalize_delivery!
    failures = [
      public_reply_permanent_failure? || public_reply_transient_failure?,
      private_reply_permanent_failure? || private_reply_transient_failure?
    ]
    successes = [public_reply_succeeded?, private_reply_succeeded?]

    final_status = if failures.any? && successes.any?
                     :partially_failed
                   elsif failures.any?
                     :failed
                   else
                     :completed
                   end

    update!(status: final_status, processed_at: Time.current, processing_started_at: nil, retry_at: nil)
  end
end
