class Openjarvis::ContactPresenter
  def initialize(contact)
    @contact = contact
  end

  def as_json
    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone_number: contact.phone_number,
      identifier: contact.identifier,
      contact_type: contact.contact_type,
      blocked: contact.blocked,
      additional_attributes: contact.additional_attributes || {},
      custom_attributes: contact.custom_attributes || {},
      created_at: contact.created_at.iso8601,
      updated_at: contact.updated_at.iso8601
    }
  end

  private

  attr_reader :contact
end
