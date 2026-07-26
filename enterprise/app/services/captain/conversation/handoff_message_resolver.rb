class Captain::Conversation::HandoffMessageResolver
  def initialize(conversation:, assistant:)
    @conversation = conversation
    @assistant = assistant
  end

  def perform
    demo_message || payment_message || configured_message
  end

  private

  def demo_message
    appointment_id = @conversation.additional_attributes.to_h['captain_demo_appointment_id']
    appointment = account_scoped(Captain::Appointment).find_by(id: appointment_id)
    return unless appointment&.scheduled?

    local_time = appointment.starts_at.in_time_zone(appointment.timezone)
    "Sua demonstração foi agendada para #{I18n.l(local_time, format: :long)}. " \
      'Vou encaminhar a conversa para o especialista responsável.'
  end

  def payment_message
    notice_id = @conversation.additional_attributes.to_h['captain_payment_notice_id']
    notice = account_scoped(Captain::PaymentNotice).find_by(id: notice_id)
    return unless notice&.pending_verification?

    'Recebi seu aviso de pagamento e encaminhei para conferência do financeiro. ' \
      'A confirmação será feita após a validação.'
  end

  def configured_message
    @assistant.config['handoff_message'].presence || I18n.t('conversations.captain.handoff')
  end

  def account_scoped(model)
    model.where(account_id: @conversation.account_id)
  end
end
