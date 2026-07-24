class Conversations::UnreadCounts::StrictCounter
  attr_reader :account, :user

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def perform
    {
      all_count: conversations.count,
      inboxes: stringify_positive_counts(conversations.group(:inbox_id).count),
      labels: unread_label_counts,
      teams: stringify_positive_counts(conversations.where.not(team_id: nil).group(:team_id).count)
    }.then { |counts| with_filtered_counts(counts) }
  end

  private

  def conversations
    @conversations ||= Conversation.where(id: strict_unread_conversations.select(:id))
  end

  def unread_label_counts
    label_ids = account.labels.where(show_on_sidebar: true).select(:id)
    counts = conversations.joins(:taggings).where(taggings: { tag_id: label_ids }).group('taggings.tag_id').count
    stringify_positive_counts(counts)
  end

  def strict_unread_conversations
    Conversations::PermissionFilterService.new(unread_conversations, user, account).perform
  end

  def unread_conversations
    account.conversations
           .joins(:messages)
           .merge(Message.incoming.reorder(nil))
           .where(messages: { account_id: account.id })
           .where(unread_since_last_seen_condition)
           .distinct
  end

  def unread_since_last_seen_condition
    conversations = Conversation.arel_table
    messages = Message.arel_table
    conversations[:agent_last_seen_at].eq(nil).or(messages[:created_at].gt(conversations[:agent_last_seen_at]))
  end

  def stringify_positive_counts(counts)
    counts.each_with_object({}) do |(id, count), result|
      result[id.to_s] = count if count.positive?
    end
  end

  def with_filtered_counts(counts)
    return counts unless account.feature_enabled?(Conversations::UnreadCounts::FilteredCounter::FEATURE_FLAG)

    counts.merge(filtered_counter.perform)
  end

  def filtered_counter
    @filtered_counter ||= Conversations::UnreadCounts::FilteredCounter.new(account: account, user: user)
  end
end
