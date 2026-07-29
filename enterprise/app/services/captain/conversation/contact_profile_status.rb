class Captain::Conversation::ContactProfileStatus
  REQUIRED_FIELDS = %i[name company_name phone_number email].freeze
  GENERATED_NAME_PATTERN = /\A[a-z]+-[a-z]+-\d+\z/i
  GENERATED_NAME_SOURCE = 'generated'.freeze

  def initialize(contact)
    @contact = contact
  end

  def missing_fields
    REQUIRED_FIELDS.select { |field| missing?(field) }
  end

  def complete?
    missing_fields.empty?
  end

  def real_name?
    return false if @contact.name.blank?

    source = @contact.additional_attributes.to_h['captain_name_source']
    return false if source == GENERATED_NAME_SOURCE

    !@contact.name.match?(GENERATED_NAME_PATTERN)
  end

  def public_contact_attributes
    attributes = @contact.attributes.symbolize_keys.slice(
      :id, :name, :email, :phone_number, :identifier, :contact_type,
      :custom_attributes
    )
    attributes[:name] = nil unless real_name?
    attributes[:company_name] = @contact.additional_attributes.to_h['company_name']
    attributes
  end

  private

  def missing?(field)
    case field
    when :name
      !real_name?
    when :company_name
      @contact.additional_attributes.to_h['company_name'].blank?
    else
      @contact.public_send(field).blank?
    end
  end
end
