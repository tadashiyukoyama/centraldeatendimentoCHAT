class Captain::TextIntegrity
  MOJIBAKE_MARKERS = [
    "\uFFFD",
    "\u00C3\u00A9",
    "\u00C3\u00A3",
    "\u00C3\u00A7",
    "\u00C3\u00B5",
    "\u00C3\u00A1",
    "\u00C3\u00B3",
    "\u00C3\u00AA",
    "\u00E2\u20AC"
  ].freeze
  QUESTION_MARK_CORRUPTION = /(?:\p{L}\?\p{L}|\bol\?(?:!|\s|$))/i

  class << self
    def errors(values)
      flatten_strings(values).flat_map do |field, value|
        value_errors(field, value)
      end
    end

    private

    def value_errors(field, value)
      errors = []
      errors << "#{field}: invalid UTF-8" unless value.valid_encoding?
      errors << "#{field}: possible mojibake" if MOJIBAKE_MARKERS.any? { |marker| value.include?(marker) }
      errors << "#{field}: possible question-mark corruption" if value.match?(QUESTION_MARK_CORRUPTION)
      errors
    end

    def flatten_strings(value, prefix = nil)
      case value
      when Hash
        value.flat_map { |key, nested| flatten_strings(nested, [prefix, key].compact.join('.')) }
      when Array
        value.each_with_index.flat_map { |nested, index| flatten_strings(nested, "#{prefix}[#{index}]") }
      when String
        [[prefix, value]]
      else
        []
      end
    end
  end
end
