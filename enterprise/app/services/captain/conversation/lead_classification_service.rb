class Captain::Conversation::LeadClassificationService
  CLASSIFICATIONS = %w[cliente lead_morno lead_quente].freeze

  HOT_LEAD_SIGNALS = [
    'preco', 'plano', 'planos', 'valor', 'proposta', 'contratar', 'contratacao',
    'comprar', 'compra', 'assinar', 'assinatura', 'demonstracao', 'demo', 'orcamento',
    'quanto custa', 'quero comprar', 'quero contratar'
  ].freeze

  CUSTOMER_SIGNALS = [
    'cliente', 'suporte', 'problema', 'erro', 'falha', 'login', 'acesso', 'senha',
    'boleto', 'fatura', 'pagamento', 'cancelar', 'cancelamento', 'minha conta',
    'ja sou', 'nao consigo', 'estou com dificuldade'
  ].freeze

  LABEL_COLORS = {
    'cliente' => '#10b981',
    'lead_morno' => '#f59e0b',
    'lead_quente' => '#ef4444'
  }.freeze

  def initialize(conversation:)
    @conversation = conversation
  end

  def perform(classification: nil)
    normalized_classification = normalize(classification)
    source = 'model'

    if normalized_classification.blank?
      normalized_classification = fallback_classification
      source = 'heuristic'
    end

    ensure_label!(normalized_classification)
    apply_classification!(normalized_classification)

    Rails.logger.info(
      "[CAPTAIN][LeadClassification] conversation=#{@conversation.display_id} " \
      "classification=#{normalized_classification} source=#{source}"
    )

    normalized_classification
  end

  private

  def normalize(classification)
    value = classification.to_s.strip.downcase
    CLASSIFICATIONS.include?(value) ? value : nil
  end

  def fallback_classification
    content = latest_customer_message&.content_for_llm.to_s
    normalized_content = ActiveSupport::Inflector.transliterate(content).downcase

    return 'lead_quente' if HOT_LEAD_SIGNALS.any? { |signal| normalized_content.include?(signal) }
    return 'cliente' if CUSTOMER_SIGNALS.any? { |signal| normalized_content.include?(signal) }

    'lead_morno'
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
    labels = (@conversation.label_list - CLASSIFICATIONS) + [classification]
    @conversation.update_labels(labels) unless labels == @conversation.label_list
  end
end
