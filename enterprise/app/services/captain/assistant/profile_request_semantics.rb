class Captain::Assistant::ProfileRequestSemantics
  PROFILE_REQUEST_PATTERNS = {
    'name' => [
      /\b(?:seu nome|nome (?:da|do) (?:pessoa|responsavel|contato)|(?:nome (?:da|do) )?pessoa responsavel)\b/,
      /\bcomo (?:posso|devo) (?:te|lhe) chamar\b/,
      /\bcom quem (?:eu )?(?:falo|estou falando)\b/
    ],
    'company_name' => [
      /\bnome (?:da|do|de seu|do seu) (?:restaurante|empresa|estabelecimento|negocio)\b/,
      /\bqual (?:e )?(?:a |o )?(?:sua empresa|seu restaurante|seu estabelecimento|seu negocio)\b/,
      /\b(?:empresa|restaurante|estabelecimento|negocio) (?:se chama|voce representa)\b/
    ],
    'phone_number' => [
      /\bwhats(?:app)?\b/,
      /\b(?:telefone|celular|numero (?:de )?(?:contato|telefone))\b/
    ],
    'email' => [/\be[ -]?mail\b/]
  }.freeze

  def initialize(response:, requested_fields:)
    @response = response.to_s
    @requested_fields = requested_fields
  end

  def missing_fields
    @requested_fields.reject { |field| field_requested?(field) }
  end

  private

  def field_requested?(field)
    Array(PROFILE_REQUEST_PATTERNS[field]).any? { |pattern| normalized_question_context.match?(pattern) }
  end

  def normalized_question_context
    @normalized_question_context ||= begin
      paragraphs = @response.split(/\n\s*\n/)
      question_paragraphs = paragraphs.select { |paragraph| paragraph.include?('?') }
      ActiveSupport::Inflector.transliterate(question_paragraphs.join(' ')).downcase.squish
    end
  end
end
