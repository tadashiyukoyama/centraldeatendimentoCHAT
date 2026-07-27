class Instagram::CommentAutomation::RetentionJob < ApplicationJob
  queue_as :purgable

  def perform
    InstagramCommentEvent.retention_expired.in_batches(of: 500).delete_all
  end
end
