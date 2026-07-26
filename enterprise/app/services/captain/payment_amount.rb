require 'bigdecimal'

class Captain::PaymentAmount
  class InvalidAmount < ArgumentError; end

  class << self
    def to_cents(value)
      normalized = normalize_decimal(value)
      cents = (BigDecimal(normalized) * 100).round.to_i
      raise InvalidAmount if cents <= 0

      cents
    rescue ArgumentError
      raise InvalidAmount
    end

    private

    def normalize_decimal(value)
      raw = value.to_s.strip.gsub(/[^\d,.-]/, '')
      raise InvalidAmount if raw.blank? || raw.include?('-')

      decimal_separator = decimal_separator_for(raw)
      return raw.delete(',.') unless decimal_separator

      integer, decimal = raw.rpartition(decimal_separator).values_at(0, 2)
      "#{integer.delete(',.')}.#{decimal}"
    end

    def decimal_separator_for(raw)
      return raw.rindex(',') > raw.rindex('.') ? ',' : '.' if raw.include?(',') && raw.include?('.')
      return raw[/([,.])\d{1,2}\z/, 1] if raw.match?(/[,.]\d{1,2}\z/)

      nil
    end
  end
end
