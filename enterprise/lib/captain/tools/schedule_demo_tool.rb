require 'digest'
require 'date'
require 'time'

class Captain::Tools::ScheduleDemoTool < Captain::Tools::BasePublicTool
  MIN_DURATION = 10
  MAX_DURATION = 120
  MAX_ADVANCE = 180.days

  description 'Schedule a confirmed product demonstration and transfer it to the responsible specialist'
  param :starts_at,
        type: 'string',
        desc: 'Confirmed start in ISO 8601 format with timezone offset',
        required: true
  param :duration_minutes,
        type: 'integer',
        desc: 'Confirmed duration between 10 and 120 minutes',
        required: false
  param :timezone,
        type: 'string',
        desc: 'IANA timezone; omit to use the conversation inbox timezone',
        required: false

  def perform(tool_context, starts_at:, duration_minutes: 30, timezone: nil)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    contact = conversation.contact
    return 'Contact not found' unless contact

    timezone = timezone.presence || conversation.inbox.timezone.presence || 'UTC'
    with_tool_audit(
      tool_context,
      request_summary: { kind: 'demo', starts_at_supplied: starts_at.present?, duration_minutes: duration_minutes }
    ) do
      schedule_demo!(conversation, contact, starts_at, duration_minutes, timezone)
    end
  end

  private

  def schedule_demo!(conversation, contact, starts_at, duration_minutes, timezone)
    schedule = schedule_details(conversation, contact, starts_at, duration_minutes, timezone)
    validate_demo!(conversation, contact, schedule)
    specialist = resolve_specialist!
    appointment = create_appointment!(conversation, contact, specialist, schedule)
    register_appointment!(conversation, appointment)
    handoff_result = handoff_appointment!(conversation, appointment, specialist)
    "#{handoff_result}. Demo appointment ##{appointment.id} scheduled."
  end

  def parse_schedule!(starts_at, duration_minutes)
    parsed_start = DateTime.iso8601(starts_at.to_s)
    supplied_offset = (parsed_start.offset * 86_400).to_i
    [parsed_start.to_time, supplied_offset, Integer(duration_minutes)]
  rescue ArgumentError, TypeError
    reject_execution!(
      'Invalid appointment date or duration. Use ISO 8601 with timezone offset.',
      code: 'invalid_schedule'
    )
  end

  def schedule_details(conversation, contact, starts_at, duration_minutes, timezone)
    start_time, supplied_offset, duration = parse_schedule!(starts_at, duration_minutes)
    end_time = start_time + duration.minutes
    {
      start_time: start_time,
      supplied_offset: supplied_offset,
      duration: duration,
      end_time: end_time,
      timezone: timezone,
      idempotency_key: appointment_key(conversation, contact, start_time, end_time)
    }
  end

  def validate_demo!(conversation, contact, schedule)
    validate_timezone!(schedule)
    validate_consent!(conversation, schedule)
    validate_timing!(schedule)
    validate_contact!(contact)
  end

  def validate_timezone!(schedule)
    zone = ActiveSupport::TimeZone[schedule[:timezone]]
    reject_execution!('Invalid timezone.', code: 'invalid_timezone') unless zone
    return if schedule[:supplied_offset] == zone.tzinfo.period_for_utc(schedule[:start_time].utc).utc_total_offset

    reject_execution!(
      'Appointment timezone does not match the ISO 8601 offset.',
      code: 'timezone_offset_mismatch'
    )
  end

  def validate_consent!(conversation, schedule)
    consent = Captain::Conversation::DemoConsent.new(conversation)
    return if consent.confirmed_slot?(schedule[:start_time], schedule[:timezone])

    reject_execution!(
      'The customer has not confirmed this exact demonstration slot.',
      code: 'demo_slot_not_confirmed'
    )
  end

  def validate_timing!(schedule)
    start_time = schedule[:start_time]
    reject_execution!('The appointment must be in the future.', code: 'appointment_in_past') unless start_time.future?
    reject_execution!('The appointment is too far in the future.', code: 'appointment_too_far') if
      start_time > MAX_ADVANCE.from_now
    reject_execution!('Duration must be between 10 and 120 minutes.', code: 'invalid_duration') unless
      schedule[:duration].between?(MIN_DURATION, MAX_DURATION)
    return if schedule[:end_time] > start_time

    reject_execution!('Appointment end must be after start.', code: 'invalid_interval')
  end

  def validate_contact!(contact)
    missing = Captain::Conversation::ContactProfileStatus.new(contact).missing_fields
    return if missing.empty?

    reject_execution!(
      "Collect and save these contact fields before scheduling: #{missing.join(', ')}.",
      code: 'incomplete_contact'
    )
  end

  def resolve_specialist!
    specialist = @assistant.configured_demo_specialist
    return specialist if specialist

    reject_execution!('No demonstration specialist is configured.', code: 'specialist_not_configured')
  end

  def create_appointment!(conversation, contact, specialist, schedule)
    specialist.with_lock do
      existing = Captain::Appointment.find_by(account: @assistant.account, idempotency_key: schedule[:idempotency_key])
      next existing if existing

      start_time = schedule[:start_time]
      end_time = schedule[:end_time]
      conflict = Captain::Appointment.active
                                     .where(account: @assistant.account, specialist: specialist)
                                     .overlapping(start_time, end_time)
                                     .exists?
      reject_execution!('The specialist is not available at that time.', code: 'appointment_conflict') if conflict

      Captain::Appointment.create!(appointment_attributes(conversation, contact, specialist, schedule))
    end
  end

  def appointment_attributes(conversation, contact, specialist, schedule)
    {
      account: @assistant.account,
      assistant: @assistant,
      conversation: conversation,
      contact: contact,
      specialist: specialist,
      starts_at: schedule[:start_time],
      ends_at: schedule[:end_time],
      timezone: schedule[:timezone],
      idempotency_key: schedule[:idempotency_key],
      metadata: { channel_type: conversation.inbox.channel_type }
    }
  end

  def handoff_appointment!(conversation, appointment, specialist)
    route_and_handoff!(
      conversation,
      destination: 'owner',
      reason: "Demonstração agendada. Appointment ##{appointment.id}.",
      trusted: true,
      assignee: specialist
    )
  end

  def register_appointment!(conversation, appointment)
    ensure_label(conversation, 'demo_agendada', color: '#2563EB')
    Captain::Conversation::LeadClassificationService.new(conversation: conversation).perform(
      classification: 'lead_quente',
      trusted_signal: 'demo_scheduled'
    )
    conversation.update!(
      additional_attributes: conversation.additional_attributes.to_h.merge(
        'captain_demo_appointment_id' => appointment.id
      )
    )
    create_private_audit_note(
      conversation,
      "Demonstração ##{appointment.id} agendada para " \
      "#{appointment.starts_at.in_time_zone(appointment.timezone).strftime('%d/%m/%Y %H:%M %Z')}."
    )
  end

  def appointment_key(conversation, contact, start_time, end_time)
    Digest::SHA256.hexdigest(
      ['demo', @assistant.account_id, conversation.id, contact.id, start_time.utc.iso8601, end_time.utc.iso8601].join(':')
    )
  end
end
