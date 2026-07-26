require 'rails_helper'

RSpec.describe PublicBrand do
  def string_values(value)
    return [value] if value.is_a?(String)
    return value.flat_map { |item| string_values(item) } if value.is_a?(Array)
    return value.values.flat_map { |item| string_values(item) } if value.is_a?(Hash)

    []
  end

  it 'cleans visible values from every Rails locale without changing translation keys' do
    with_modified_env PUBLIC_BRAND_PROFILE: 'acelerachat' do
      locale_files = Rails.root.glob('config/locales/*.yml')
      expect(locale_files.size).to be > 56

      locale_files.each do |path|
        values = string_values(YAML.safe_load(path.read, aliases: true))
        transformed = described_class.public_text(values).join("\n")
        expect(transformed).not_to match(/Chatwoot|Captain|Capitão|\bEnterprise\b/i), path.to_s
        expect(transformed).not_to match(/chatwoot\.com|chatwoot\.help|chwt\.app/i), path.to_s
      end
    end
  end
end
