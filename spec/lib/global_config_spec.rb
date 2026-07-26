require 'rails_helper'

describe GlobalConfig do
  subject(:trigger) { described_class }

  describe 'execute' do
    context 'when called with default options' do
      before do
        described_class.clear_cache
      end

      it 'hit DB for the first call' do
        expect(InstallationConfig).to receive(:find_by)
        described_class.get('test')
      end

      it 'get from cache for subsequent calls' do
        # this loads from DB
        described_class.get('test')

        # subsequent calls should not hit DB
        expect(InstallationConfig).not_to receive(:find_by)
        described_class.get('test')
      end

      it 'clears cache and fetch from DB next time, when clear_cache is called' do
        # this loads from DB and is cached
        described_class.get('test')

        # clears the cache
        described_class.clear_cache

        # should be loaded from DB
        expect(InstallationConfig).to receive(:find_by).with({ name: 'test' }).and_return(nil)
        described_class.get('test')
      end

      it 'applies the active public brand after reading persisted configuration' do
        create(:installation_config, name: 'INSTALLATION_NAME', value: 'Persisted name')

        with_modified_env PUBLIC_BRAND_PROFILE: 'acelerachat' do
          PublicBrand.reset!
          expect(described_class.get('INSTALLATION_NAME')['INSTALLATION_NAME']).to eq('AceleraChat')
        end
      ensure
        PublicBrand.reset!
      end
    end
  end
end
