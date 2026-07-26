require 'uri'

class Captain::Tools::CaptureContactProfileTool < Captain::Tools::BasePublicTool
  MAX_NAME_LENGTH = 120
  MAX_COMPANY_LENGTH = 160
  PROFILE_FIELDS = %i[name phone_number company_name email].freeze
  INPUT_FIELDS = (PROFILE_FIELDS + [:country_code]).freeze

  description 'Save contact details explicitly provided by the customer'
  param :name, type: 'string', desc: 'Customer full name', required: false
  param :phone_number, type: 'string', desc: 'Customer phone number', required: false
  param :company_name, type: 'string', desc: 'Customer company or establishment', required: false
  param :email, type: 'string', desc: 'Customer email address', required: false
  param :country_code, type: 'string', desc: 'ISO country code used to normalize a local phone', required: false

  def perform(tool_context, **attributes)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    contact = conversation.contact
    return 'Contact not found' unless contact

    attributes = attributes.symbolize_keys.slice(*INPUT_FIELDS)
    supplied_fields = PROFILE_FIELDS.select { |field| attributes[field].present? }
    return 'At least one contact field is required' if supplied_fields.empty?

    with_tool_audit(
      tool_context,
      request_summary: { fields: supplied_fields.map(&:to_s).sort }
    ) do
      save_profile(conversation, contact, attributes)
    end
  end

  private

  def save_profile(conversation, contact, attributes)
    values = normalized_values(
      **attributes.slice(*PROFILE_FIELDS),
      country_code: attributes[:country_code].presence || contact.country_code.presence || default_country_code
    )
    validate_explicit_evidence!(conversation, contact, values)
    changed_fields = safely_update_contact!(conversation, contact, values)
    create_profile_note(conversation, changed_fields)
    "Contact profile saved: #{changed_fields.join(', ')}"
  end

  def normalized_values(name: nil, phone_number: nil, company_name: nil, email: nil, country_code: nil)
    {
      name: normalize_text(name, MAX_NAME_LENGTH, :name),
      phone_number: normalize_phone(phone_number, country_code),
      company_name: normalize_text(company_name, MAX_COMPANY_LENGTH, :company_name),
      email: normalize_email(email)
    }.compact
  end

  def normalize_text(value, max_length, field)
    normalized = value.to_s.squish.presence
    return if normalized.blank?

    reject_execution!("#{field} is too short.", code: "invalid_#{field}") if normalized.length < 2

    normalized.first(max_length)
  end

  def normalize_email(value)
    return if value.blank?

    normalized = value.to_s.strip.downcase
    return normalized if normalized.match?(URI::MailTo::EMAIL_REGEXP)

    reject_execution!('Email address is invalid.', code: 'invalid_email')
  end

  def normalize_phone(value, country_code)
    return if value.blank?

    raw = value.to_s.strip
    return raw if raw.match?(/\A\+[1-9]\d{7,14}\z/)

    digits = raw.gsub(/\D/, '')
    return "+55#{digits}" if country_code.to_s.casecmp('BR').zero? && digits.length.in?([10, 11])

    reject_execution!(
      'Phone number must include the international country code, for example +5511999999999.',
      code: 'invalid_phone'
    )
  end

  def default_country_code
    @assistant.account.locale.to_s.casecmp('pt_BR').zero? ? 'BR' : nil
  end

  def validate_explicit_evidence!(conversation, contact, values)
    evidence = Captain::Conversation::ContactProfileEvidence.new(conversation)
    unsupported = values.reject do |field, value|
      current_value(contact, field).to_s == value.to_s || evidence.explicit?(field, value)
    end.keys
    return if unsupported.empty?

    reject_execution!(
      "Do not save inferred data. Ask the customer to provide: #{unsupported.join(', ')}.",
      code: 'missing_customer_evidence'
    )
  end

  def current_value(contact, field)
    return contact.additional_attributes.to_h['company_name'] if field == :company_name

    contact.public_send(field)
  end

  def update_contact!(conversation, contact, values)
    changed_fields = []
    contact.with_lock do
      values.each do |field, value|
        next if current_value(contact, field).to_s == value.to_s

        if field == :company_name
          contact.additional_attributes = contact.additional_attributes.to_h.merge('company_name' => value)
        else
          contact.public_send("#{field}=", value)
        end
        changed_fields << field
      end
      apply_contact_type(contact, conversation)
      contact.save! if contact.changed?
    end
    changed_fields.presence || ['no_changes']
  end

  def safely_update_contact!(conversation, contact, values)
    update_contact!(conversation, contact, values)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    reject_execution!(
      'Contact data is invalid or conflicts with another contact. A human must review and merge it.',
      code: 'contact_conflict'
    )
  end

  def apply_contact_type(contact, conversation)
    if conversation.label_list.include?('cliente')
      contact.contact_type = :customer
    elsif conversation.label_list.intersect?(%w[lead_morno lead_quente])
      contact.contact_type = :lead
    end
  end

  def create_profile_note(conversation, changed_fields)
    create_private_audit_note(
      conversation,
      "Perfil do contato atualizado pelo agente. Campos: #{changed_fields.join(', ')}."
    )
  end
end
