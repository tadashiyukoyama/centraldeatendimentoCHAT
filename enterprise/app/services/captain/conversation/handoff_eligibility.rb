class Captain::Conversation::HandoffEligibility
  HUMAN_REQUEST_PATTERN = /\b(?:
    falar com (?:um|uma )?(?:humano|atendente|pessoa|alguem)
    | atendimento humano
    | me transf
    | transfer(?:ir|a)
    | especialista
  )\b/ix
  DEPARTMENT_PATTERN = /\b(?:financeiro|contas? a pagar|recursos? humanos?|rh|gerencia|representante|suporte)\b/ix
  COMMERCIAL_SIGNAL_PATTERN = /\b(?:
    preco
    | valor
    | plano
    | proposta
    | contrat(?:ar|acao)
    | demo(?:nstracao)?
    | comprar
    | assinar
    | adquirir
    | orcamento
  )\b/ix
  PAYMENT_SIGNAL_PATTERN = /\b(?:
    paguei
    | pagamento
    | comprovante
    | pix
    | transferencia bancaria
  )\b/ix
  ACCEPTANCE_PATTERN = /\A\s*(?:ok(?:ay)?|sim|pode(?: ser)?|quero|claro|tudo bem|ta bom|esta bom|aceito|vamos)\b/ix
  HANDOFF_OFFER_PATTERN = /\b(?:
    especialista
    | atendimento humano
    | falar com
    | transfer(?:ir|a)
    | equipe responsavel
    | setor
    | demonstracao
    | demo
    | agendar
    | agenda
    | conhecer na pratica
  )\b/ix

  DENIED_MESSAGE = 'Handoff is not appropriate for the latest customer message. Reply to the customer and keep the conversation with Captain.'.freeze

  def initialize(conversation)
    @conversation = conversation
  end

  def allowed?
    latest_customer_message.present? && explicit_handoff_signal?
  end

  def denied_message
    DENIED_MESSAGE
  end

  private

  def latest_customer_message
    message = public_messages.last
    return unless message&.incoming? && message.sender_type == 'Contact'

    message
  end

  def explicit_handoff_signal?
    content = normalized_content(latest_customer_message)
    content.match?(HUMAN_REQUEST_PATTERN) ||
      content.match?(DEPARTMENT_PATTERN) ||
      content.match?(COMMERCIAL_SIGNAL_PATTERN) ||
      content.match?(PAYMENT_SIGNAL_PATTERN) ||
      accepts_previous_handoff_offer?(content)
  end

  def accepts_previous_handoff_offer?(content)
    return false unless content.match?(ACCEPTANCE_PATTERN)

    previous_message = public_messages[-2]
    return false unless previous_message&.outgoing? && captain_message?(previous_message)

    normalized_content(previous_message).match?(HANDOFF_OFFER_PATTERN)
  end

  def public_messages
    Captain::Conversation::MessageContextWindow.new(@conversation).perform.reject(&:activity?)
  end

  def captain_message?(message)
    %w[Captain::Assistant AgentBot].include?(message.sender_type)
  end

  def normalized_content(message)
    ActiveSupport::Inflector.transliterate(message.content_for_llm.to_s).downcase
  end
end
