require 'digest'

class Captain::Tools::RecordPaymentNoticeTool < Captain::Tools::BasePublicTool
  description 'Record a customer payment notice for human financial verification'
  param :amount, type: 'string', desc: 'Amount reported by the customer, using decimal notation', required: false
  param :currency, type: 'string', desc: 'ISO 4217 currency code', required: false
  param :reference, type: 'string', desc: 'Invoice, transaction, or payment reference', required: false

  def perform(tool_context, amount: nil, currency: 'BRL', reference: nil)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    contact = conversation.contact
    return 'Contact not found' unless contact

    details = { amount: amount, currency: currency, reference: reference }
    with_tool_audit(
      tool_context,
      request_summary: { fields: present_fields(amount, reference) }
    ) do
      process_notice(conversation, contact, details)
    end
  rescue Captain::PaymentAmount::InvalidAmount
    'Invalid payment amount.'
  end

  private

  def process_notice(conversation, contact, details)
    validate_payment_notice!(conversation, details)
    team = configured_finance_team!
    details[:idempotency_key] = payment_notice_key(conversation, latest_customer_message(conversation))
    notice = create_notice!(conversation, contact, details)
    register_notice!(conversation, notice)
    handoff_result = route_payment_notice!(conversation, notice, team)
    "#{handoff_result}. Payment notice ##{notice.id} recorded as pending verification."
  end

  def validate_payment_notice!(conversation, details)
    evidence = Captain::Conversation::PaymentNoticeEvidence.new(conversation)
    validate_currency!(details[:currency])
    validate_notice_presence!(evidence)
    validate_evidence_value!(evidence, :amount, details[:amount])
    validate_evidence_value!(evidence, :reference, details[:reference])
    return if evidence.currency_explicit?(details[:currency])

    reject_execution!(
      'The payment currency was not found in the latest customer message.',
      code: 'payment_currency_not_explicit'
    )
  end

  def validate_currency!(currency)
    return if currency.to_s.upcase.match?(/\A[A-Z]{3}\z/)

    reject_execution!('Invalid ISO 4217 payment currency.', code: 'invalid_currency')
  end

  def validate_notice_presence!(evidence)
    return if evidence.present?

    reject_execution!(
      'No explicit payment notice was found in the latest customer message.',
      code: 'payment_notice_not_explicit'
    )
  end

  def validate_evidence_value!(evidence, field, value)
    return if value.blank? || evidence.public_send("#{field}_explicit?", value)

    message, code = evidence_error(field)
    reject_execution!(message, code: code)
  end

  def evidence_error(field)
    {
      amount: ['The reported amount was not found in the latest customer message.', 'payment_amount_not_explicit'],
      reference: ['The payment reference was not found in the latest customer message.', 'payment_reference_not_explicit']
    }.fetch(field)
  end

  def create_notice!(conversation, contact, details)
    existing = Captain::PaymentNotice.find_by(
      account: @assistant.account,
      idempotency_key: details.fetch(:idempotency_key)
    )
    return existing if existing

    Captain::PaymentNotice.create_or_find_by!(
      account: @assistant.account,
      idempotency_key: details.fetch(:idempotency_key)
    ) do |notice|
      notice.assign_attributes(
        assistant: @assistant,
        conversation: conversation,
        contact: contact,
        amount_cents: amount_to_cents(details[:amount]),
        currency: normalize_currency(details[:currency]),
        reference: details[:reference].to_s.squish.first(120).presence,
        metadata: { channel_type: conversation.inbox.channel_type }
      )
    end
  end

  def route_payment_notice!(conversation, notice, team)
    route_and_handoff!(
      conversation,
      destination: 'financeiro',
      reason: "Aviso de pagamento ##{notice.id} aguardando conferência.",
      trusted: true,
      team: team
    )
  end

  def register_notice!(conversation, notice)
    ensure_label(conversation, 'pagamento_informado', color: '#06B6D4')
    conversation.update!(
      additional_attributes: conversation.additional_attributes.to_h.merge(
        'captain_payment_notice_id' => notice.id
      )
    )
    create_private_audit_note(
      conversation,
      "Aviso de pagamento ##{notice.id} registrado como pendente de conferência. " \
      'O agente não confirmou a liquidação.'
    )
  end

  def amount_to_cents(amount)
    return if amount.blank?

    Captain::PaymentAmount.to_cents(amount)
  end

  def normalize_currency(currency)
    value = currency.to_s.upcase
    raise ArgumentError unless value.match?(/\A[A-Z]{3}\z/)

    value
  end

  def latest_customer_message(conversation)
    Captain::Conversation::MessageContextWindow.new(conversation)
                                               .perform
                                               .reverse
                                               .find { |message| message.incoming? && message.sender_type == 'Contact' }
  end

  def payment_notice_key(conversation, message)
    Digest::SHA256.hexdigest(
      ['payment_notice', @assistant.account_id, conversation.id, message&.id].join(':')
    )
  end

  def configured_finance_team
    @assistant.configured_finance_team
  end

  def configured_finance_team!
    configured_finance_team || reject_execution!(
      'No finance team is configured for payment notices.',
      code: 'finance_team_not_configured'
    )
  end

  def present_fields(amount, reference)
    {
      amount: amount,
      reference: reference
    }.select { |_key, value| value.present? }.keys.map(&:to_s)
  end
end
