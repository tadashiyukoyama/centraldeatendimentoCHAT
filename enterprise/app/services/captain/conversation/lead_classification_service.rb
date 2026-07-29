class Captain::Conversation::LeadClassificationService
  CLASSIFICATIONS = %w[cliente lead_morno lead_quente].freeze

  HOT_LEAD_SIGNALS = [
    'preco', 'plano', 'planos', 'valor', 'proposta', 'contratar', 'contratacao',
    'comprar', 'compra', 'assinar', 'assinatura', 'demonstracao', 'demo', 'orcamento',
    'quanto custa', 'quero comprar', 'quero contratar'
  ].freeze

  CUSTOMER_PATTERNS = [
    /\b(?:ja\s+)?sou\s+cliente\b/,
    /\bja\s+(?:uso|utilizo)\s+(?:o|a)?\s*(?:sistema|plataforma|solucao|ai food manager)\b/,
    /\b(?:uso|utilizo)\s+(?:o|a)\s+(?:sistema|plataforma|solucao|ai food manager)\b/,
    /\bminh[ao]s?\s+(?:conta|assinatura|fatura|boleto|plano|acesso|senha|pagamento)\b/,
    /\bnao\s+consigo\s+(?:entrar|acessar|fazer\s+login|usar\s+(?:minha\s+)?conta)\b/,
    /\bestou\s+com\s+dificuldade\s+(?:no|na|para)\s+(?:login|acesso|sistema|plataforma|conta|painel)\b/,
    /\b(?:esqueci|redefinir|trocar)\s+(?:a\s+)?(?:minha\s+)?senha\b/,
    /\bcancelar\s+(?:a\s+)?(?:minha\s+)?(?:conta|assinatura|plano)\b/,
    /\b(?:preciso|gostaria)\s+de\s+(?:ajuda|suporte)\s+(?:com|no|na)\s+(?:minha\s+)?(?:conta|assinatura|fatura|boleto|acesso)\b/
  ].freeze

  LABEL_COLORS = {
    'cliente' => '#10b981',
    'lead_morno' => '#f59e0b',
    'lead_quente' => '#ef4444'
  }.freeze

  def initialize(conversation:)
    @conversation = conversation
  end

  TRUSTED_SIGNALS = %w[demo_scheduled].freeze

  def perform(classification: nil, trusted_signal: nil)
    normalized_classification = trusted_classification(trusted_signal) || safe_classification(classification)
    source = @classification_source || 'model'

    if normalized_classification.blank?
      normalized_classification = fallback_classification
      source = 'heuristic'
    end

    ensure_label!(normalized_classification)
    apply_classification!(normalized_classification)

    effective_classification = @effective_classification || normalized_classification

    Rails.logger.info(
      "[CAPTAIN][LeadClassification] conversation=#{@conversation.display_id} " \
      "classification=#{effective_classification} source=#{source}"
    )

    effective_classification
  end

  private

  def trusted_classification(trusted_signal)
    return unless TRUSTED_SIGNALS.include?(trusted_signal.to_s)

    @classification_source = 'trusted_tool'
    'lead_quente'
  end

  def normalize(classification)
    value = classification.to_s.strip.downcase
    CLASSIFICATIONS.include?(value) ? value : nil
  end

  def fallback_classification
    content = latest_customer_message&.content_for_llm.to_s
    normalized_content = ActiveSupport::Inflector.transliterate(content).downcase

    return 'lead_quente' if HOT_LEAD_SIGNALS.any? { |signal| normalized_content.include?(signal) }
    return 'cliente' if CUSTOMER_PATTERNS.any? { |pattern| normalized_content.match?(pattern) }

    'lead_morno'
  end

  def safe_classification(classification)
    heuristic = fallback_classification
    if %w[cliente lead_quente].include?(heuristic)
      @classification_source = 'heuristic'
      return heuristic
    end

    normalized = normalize(classification)
    if %w[cliente lead_quente].include?(normalized)
      @classification_source = 'heuristic'
      return heuristic
    end

    @classification_source = normalized.present? ? 'model' : 'heuristic'
    normalized
  end

  def latest_customer_message
    @conversation.messages
                 .where(message_type: :incoming, private: false, sender_type: 'Contact')
                 .order(created_at: :desc)
                 .first
  end

  def ensure_label!(classification)
    Label.find_or_create_by!(account_id: @conversation.account_id, title: classification) do |label|
      label.color = LABEL_COLORS.fetch(classification)
      label.show_on_sidebar = true
    end
  end

  def apply_classification!(classification)
    @conversation.reload
    current = current_classification
    effective_classification = monotonic_classification(current, classification)
    labels = (@conversation.label_list - CLASSIFICATIONS) + [effective_classification]
    @conversation.update_labels(labels) unless labels == @conversation.label_list
    @effective_classification = effective_classification
  end

  def current_classification
    CLASSIFICATIONS.find { |classification| @conversation.label_list.include?(classification) }
  end

  def monotonic_classification(current, requested)
    return current if %w[cliente lead_quente].include?(current)
    return 'lead_quente' if current == 'lead_morno' && requested == 'lead_quente'

    requested
  end
end
