class PrivacyRequestEvent < ApplicationRecord
  belongs_to :privacy_request
  belongs_to :actor, polymorphic: true, optional: true

  validates :event_type, presence: true
end
