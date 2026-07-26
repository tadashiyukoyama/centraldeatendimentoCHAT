class Captain::Tools::LookupPaymentStatusTool < Captain::Tools::BasePublicTool
  description 'Look up the verification status of a payment notice recorded for the current contact'
  param :reference, type: 'string', desc: 'Optional invoice or payment reference', required: false

  def perform(tool_context, reference: nil)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    contact = conversation.contact
    return 'Contact not found' unless contact

    with_tool_audit(
      tool_context,
      request_summary: { reference_supplied: reference.present? }
    ) do
      notice = payment_notice(contact, reference)
      next 'No payment notice was found. Financial verification by a human is required.' unless notice

      "Payment notice ##{notice.id} status: #{notice.status}. #{verification_disclaimer(notice)}"
    end
  end

  private

  def payment_notice(contact, reference)
    scope = Captain::PaymentNotice.where(account: @assistant.account, contact: contact)
    scope = scope.where(reference: reference.to_s.squish) if reference.present?
    scope.order(created_at: :desc).first
  end

  def verification_disclaimer(notice)
    return 'Verification source: linked external provider record.' if notice.external_provider.present?
    return 'Verification source: human financial review.' if notice.verified_by_id.present?

    'This is an unverified internal notice, not a bank confirmation.'
  end
end
