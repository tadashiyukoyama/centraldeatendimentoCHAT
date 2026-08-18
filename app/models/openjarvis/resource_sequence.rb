class Openjarvis::ResourceSequence < ApplicationRecord
  self.table_name = 'openjarvis_resource_sequences'

  belongs_to :integration_hook, class_name: 'Integrations::Hook', inverse_of: :openjarvis_resource_sequences

  validates :resource_type, presence: true
  validates :resource_id, presence: true
  validates :sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.next_for!(hook:, resource:)
    record = find_or_create_by!(
      integration_hook: hook,
      resource_type: resource.class.base_class.name,
      resource_id: resource.id
    )
    record.with_lock do
      record.update!(sequence: record.sequence + 1)
      record.sequence
    end
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def self.current_for(hook:, resource:)
    find_by(
      integration_hook: hook,
      resource_type: resource.class.base_class.name,
      resource_id: resource.id
    )&.sequence.to_i
  end
end
