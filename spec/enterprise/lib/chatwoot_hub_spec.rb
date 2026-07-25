require 'rails_helper'

RSpec.describe ChatwootHub do
  describe '.base_url' do
    it 'uses the configured Acelera Control URL outside development' do
      with_modified_env ACELERA_CONTROL_URL: 'https://control.acelerachat.example' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

        expect(described_class.base_url).to eq('https://control.acelerachat.example')
      end
    end

    it 'never restores the legacy URL in development' do
      with_modified_env ACELERA_CONTROL_URL: 'https://hub.2.chatwoot.com' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))

        expect(described_class.base_url).to be_nil
      end
    end
  end
end
