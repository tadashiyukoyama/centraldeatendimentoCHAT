class Captain::Conversation::HandoffEligibility
  HUMAN_REQUEST_PATTERN = /\b(?:falar com (?:um|uma )?(?:humano|atendente|pessoa|algu[eé]m)|atendimento humano|me transf|transfer(?:ir|a)|especialista)\b/i
  DEPARTMENT_PATTERN = /\b(?:financeiro|contas? a pagar|recursos? humanos?|rh|ger[eê]ncia|representante|suporte)\b/i
  COMMERCIAL_SIGNAL_PATTERN = /\b(?:pre[cç]o|valor|plano|proposta|contrat(?:ar|a[cç][aã]o)|demo(?:nstra[cç][aã]o)?|comprar|assinar|adquirir|or[cç]amento)\b/i

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
    messages = Captain::Conversation::MessageContextWindow.new(@conversation).perform
    messages.reverse.find { |message| message.incoming? && message.sender_type == 'Contact' }
  end

  def explicit_handoff_signal?
    content = latest_customer_message.content_for_llm.to_s
    content.match?(HUMAN_REQUEST_PATTERN) || content.match?(DEPARTMENT_PATTERN) || content.match?(COMMERCIAL_SIGNAL_PATTERN)
  end
end
