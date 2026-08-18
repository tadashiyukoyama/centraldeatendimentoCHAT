class Api::V1::Openjarvis::OperationsController < Api::V1::Openjarvis::BaseController
  def index
    require_scope!('diagnostics:read')
    render json: {
      api_requests: api_requests,
      webhook_deliveries: webhook_deliveries
    }
  end

  private

  def api_requests
    openjarvis_hook.openjarvis_api_requests.order(created_at: :desc).limit(limit).map do |item|
      item.slice(:id, :operation, :status, :response_status, :resource_type, :resource_id, :created_at, :completed_at)
    end
  end

  def webhook_deliveries
    openjarvis_hook.openjarvis_webhook_deliveries.order(created_at: :desc).limit(limit).map do |item|
      item.slice(
        :delivery_id, :event_name, :resource_type, :resource_id, :status, :attempts,
        :response_status, :error_code, :error_message, :created_at, :delivered_at
      )
    end
  end
end
