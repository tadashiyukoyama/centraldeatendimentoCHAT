require 'rails_helper'

RSpec.describe Acelerachat::BrandAudit do
  after { PublicBrand.reset! }

  it 'blocks a legacy first-party destination supplied only at runtime' do
    with_modified_env(
      PUBLIC_BRAND_PROFILE: 'acelerachat',
      ACELERA_CONTROL_ENABLED: 'false',
      LEGACY_CALLBACK_URL: 'https://app.chatwoot.com/callback'
    ) do
      PublicBrand.reset!

      expect { described_class.new.call }.to raise_error(
        ArgumentError,
        /environment key: LEGACY_CALLBACK_URL/
      )
    end
  end
end
