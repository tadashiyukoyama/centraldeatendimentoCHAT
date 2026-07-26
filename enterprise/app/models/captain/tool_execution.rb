class Captain::ToolExecution < ApplicationRecord
  self.table_name = 'captain_tool_executions'

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  belongs_to :conversation, class_name: '::Conversation', optional: true
  belongs_to :contact, class_name: '::Contact', optional: true

  enum status: { started: 0, succeeded: 1, rejected: 2, failed: 3 }

  validates :tool_name, :started_at, presence: true
  validates :idempotency_key, uniqueness: { scope: [:account_id, :tool_name] }, allow_nil: true
  validate :related_records_share_account

  private

  def related_records_share_account
    errors.add(:assistant, 'must belong to the same account') if assistant&.account_id != account_id
    errors.add(:conversation, 'must belong to the same account') if conversation && conversation.account_id != account_id
    errors.add(:contact, 'must belong to the same account') if contact && contact.account_id != account_id
  end
end
