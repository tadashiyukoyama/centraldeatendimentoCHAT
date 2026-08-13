class Campaigns::DeliveryProgressService
  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 100
  DELIVERY_STATUSES = %w[pending processing queued sent delivered read skipped failed].freeze
  COMPLETED_STATUSES = %w[sent delivered read skipped failed].freeze

  pattr_initialize [:campaign!]

  def payload(page: nil, per_page: nil)
    current_page = [page.to_i, 1].max
    page_size = per_page.to_i.clamp(1, MAX_PER_PAGE)
    page_size = DEFAULT_PER_PAGE if per_page.to_i.zero?
    page_deliveries = deliveries.offset((current_page - 1) * page_size).limit(page_size)

    {
      campaign: campaign_payload,
      progress: progress_payload,
      deliveries: page_deliveries.map { |delivery| delivery_payload(delivery) },
      meta: {
        current_page: current_page,
        per_page: page_size,
        total_count: deliveries.size,
        total_pages: (deliveries.size.to_f / page_size).ceil
      }
    }
  end

  private

  def deliveries
    @deliveries ||= campaign.campaign_deliveries.includes(:contact, :conversation).order(:scheduled_for, :id)
  end

  def campaign_messages
    @campaign_messages ||= begin
      conversation_ids = deliveries.filter_map(&:conversation_id)
      if conversation_ids.empty?
        {}
      else
        Message
          .where(conversation_id: conversation_ids)
          .where("additional_attributes ->> 'campaign_id' = ?", campaign.id.to_s)
          .reorder(:created_at, :id)
          .group_by(&:conversation_id)
          .transform_values(&:last)
      end
    end
  end

  def effective_status(delivery)
    return delivery.status unless delivery.queued?

    campaign_messages[delivery.conversation_id]&.status || delivery.status
  end

  def status_counts
    @status_counts ||= deliveries.each_with_object(Hash.new(0)) do |delivery, counts|
      counts[effective_status(delivery)] += 1
    end
  end

  def progress_payload
    total = deliveries.size
    completed = COMPLETED_STATUSES.sum { |status| status_counts[status] }
    counters = DELIVERY_STATUSES.index_with { |status| status_counts[status] }

    counters.merge(
      total: total,
      completed: completed,
      percentage: total.zero? ? 0 : ((completed.to_f / total) * 100).round,
      next_delivery_at: deliveries.find(&:pending?)&.scheduled_for&.iso8601
    )
  end

  def campaign_payload
    {
      id: campaign.display_id,
      title: campaign.title,
      status: campaign.campaign_status,
      scheduled_at: campaign.scheduled_at&.iso8601,
      updated_at: campaign.updated_at.iso8601
    }
  end

  def delivery_payload(delivery)
    message = campaign_messages[delivery.conversation_id]
    {
      id: delivery.id,
      status: effective_status(delivery),
      queue_status: delivery.status,
      message_status: message&.status,
      contact: {
        id: delivery.contact.id,
        name: delivery.contact.name,
        phone_number: delivery.contact.phone_number
      },
      scheduled_for: delivery.scheduled_for&.iso8601,
      processed_at: delivery.processed_at&.iso8601,
      error_message: delivery.error_message.presence || message&.content_attributes&.dig('external_error'),
      conversation_id: delivery.conversation&.display_id
    }
  end
end
