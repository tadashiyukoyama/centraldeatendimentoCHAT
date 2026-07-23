class Whatsapp::EvolutionEvent < ApplicationRecord
  self.table_name = 'whatsapp_evolution_events'

  belongs_to :provisioning,
             class_name: 'Whatsapp::EvolutionProvisioning',
             inverse_of: :events

  enum status: {
    pending: 0,
    queued: 1,
    processing: 2,
    processed: 3,
    ignored: 4,
    failed: 5
  }

  validates :event_key, :event_type, presence: true
  validates :event_key, uniqueness: true

  def record_failure!(error)
    update!(
      status: :failed,
      last_error_class: error.class.name.first(100),
      last_error_message: error.message.to_s.first(500)
    )
  end
end
