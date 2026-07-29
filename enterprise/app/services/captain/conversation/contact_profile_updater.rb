require 'uri'

class Captain::Conversation::ContactProfileUpdater
  MAX_NAME_LENGTH = 120
  MAX_COMPANY_LENGTH = 160
  PROFILE_FIELDS = %i[name phone_number company_name email].freeze

  class ValidationError < StandardError
    attr_reader :code

    def initialize(message, code)
      @code = code
      super(message)
    end
  end

  def initialize(conversation:, assistant:, country_code: nil)
    @conversation = conversation
    @assistant = assistant
    @contact = conversation.contact
    @country_code = country_code.presence || @contact&.country_code.presence
  end

  def perform(attributes:, source:)
    values = normalized_values(attributes.symbolize_keys.slice(*PROFILE_FIELDS))
    raise_validation!('At least one contact field is required', 'missing_fields') if values.empty?

    evidence_messages = validate_explicit_evidence!(values)
    changed_fields = update_contact!(values, evidence_messages, source)
    create_profile_note(changed_fields, source) if changed_fields.any?
    changed_fields
  end

  private

  def normalized_values(attributes)
    {
      name: normalize_text(attributes[:name], MAX_NAME_LENGTH, :name),
      phone_number: normalize_phone(attributes[:phone_number]),
      company_name: normalize_text(attributes[:company_name], MAX_COMPANY_LENGTH, :company_name),
      email: normalize_email(attributes[:email])
    }.compact
  end

  def normalize_text(value, max_length, field)
    normalized = value.to_s.squish.presence
    return if normalized.blank?

    raise_validation!("#{field} is too short.", "invalid_#{field}") if normalized.length < 2

    normalized.first(max_length)
  end

  def normalize_email(value)
    return if value.blank?

    normalized = value.to_s.strip.downcase
    return normalized if normalized.match?(URI::MailTo::EMAIL_REGEXP)

    raise_validation!('Email address is invalid.', 'invalid_email')
  end

  def normalize_phone(value)
    return if value.blank?

    raw = value.to_s.strip
    digits = raw.gsub(/\D/, '')
    return "+#{digits}" if raw.start_with?('+') && digits.match?(/\A[1-9]\d{7,14}\z/)
    return "+55#{digits}" if default_country_code == 'BR' && digits.length.in?([10, 11])

    raise_validation!(
      'Phone number must include the international country code, for example +5511999999999.',
      'invalid_phone'
    )
  end

  def default_country_code
    @country_code.presence || (@assistant.account.locale.to_s.casecmp('pt_BR').zero? ? 'BR' : nil)
  end

  def validate_explicit_evidence!(values)
    evidence = Captain::Conversation::ContactProfileEvidence.new(@conversation)
    values.to_h do |field, value|
      message = evidence.message_for(field, value)
      next [field, message] if current_value(field).to_s == value.to_s || message

      raise_validation!(
        "Do not save inferred data. Ask the customer to provide: #{field}.",
        'missing_customer_evidence'
      )
    end
  end

  def update_contact!(values, evidence_messages, source)
    changed_fields = []
    @contact.with_lock do
      additional_attributes = @contact.additional_attributes.to_h.deep_dup
      values.each do |field, value|
        next if current_value(field).to_s == value.to_s

        assign_field(field, value, additional_attributes)
        register_evidence!(additional_attributes, field, evidence_messages[field], source)
        changed_fields << field
      end
      apply_contact_type if changed_fields.any?
      @contact.additional_attributes = additional_attributes
      @contact.save! if @contact.changed?
    end
    changed_fields
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    raise_validation!(
      'Contact data is invalid or conflicts with another contact. A human must review and merge it.',
      'contact_conflict'
    )
  end

  def assign_field(field, value, additional_attributes)
    if field == :company_name
      additional_attributes['company_name'] = value
    else
      @contact.public_send("#{field}=", value)
    end
    additional_attributes['captain_name_source'] = 'customer' if field == :name
  end

  def register_evidence!(additional_attributes, field, message, source)
    evidence = additional_attributes.fetch('captain_profile_evidence', {}).deep_dup
    evidence[field.to_s] = {
      'source' => source,
      'conversation_id' => @conversation.id,
      'message_id' => message&.id,
      'captured_at' => Time.current.iso8601
    }
    additional_attributes['captain_profile_evidence'] = evidence
    return unless field == :phone_number

    additional_attributes['whatsapp_contact_permission'] = true
    additional_attributes['whatsapp_contact_permission_details'] = {
      'scope' => 'service_follow_up',
      'basis' => 'number_voluntarily_provided_for_service_follow_up',
      'conversation_id' => @conversation.id,
      'inbox_id' => @conversation.inbox_id,
      'message_id' => message&.id,
      'captured_at' => Time.current.iso8601
    }
  end

  def current_value(field)
    return @contact.additional_attributes.to_h['company_name'] if field == :company_name

    @contact.public_send(field)
  end

  def apply_contact_type
    if @conversation.label_list.include?('cliente')
      @contact.contact_type = :customer
    elsif @conversation.label_list.intersect?(%w[lead_morno lead_quente])
      @contact.contact_type = :lead
    end
  end

  def create_profile_note(changed_fields, source)
    @conversation.messages.create!(
      account: @conversation.account,
      inbox: @conversation.inbox,
      sender: @assistant,
      message_type: :outgoing,
      content: "Perfil do contato atualizado pelo agente. Campos: #{changed_fields.join(', ')}. Origem: #{source}.",
      private: true
    )
  end

  def raise_validation!(message, code)
    raise ValidationError.new(message, code)
  end
end
