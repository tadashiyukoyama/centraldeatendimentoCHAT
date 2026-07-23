class Webhooks::EvolutionEventsJob < ApplicationJob
  queue_as :low
  self.log_arguments = false

  discard_on ActiveRecord::RecordNotFound
  retry_on Whatsapp::Evolution::ApiClient::Error, wait: :polynomially_longer, attempts: 5

  def perform(event_id, payload)
    event = Whatsapp::EvolutionEvent.find(event_id)
    Whatsapp::Evolution::WebhookProcessor.new(event: event, payload: payload).perform
  end
end
