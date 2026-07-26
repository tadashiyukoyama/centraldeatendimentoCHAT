require 'rails_helper'
require 'tmpdir'

RSpec.describe PublicBrand do
  after { described_class.reset! }

  describe '.apply' do
    it 'keeps persisted values when the profile is disabled' do
      with_modified_env PUBLIC_BRAND_PROFILE: '' do
        expect(described_class.apply('INSTALLATION_NAME' => 'Legacy')).to include('INSTALLATION_NAME' => 'Legacy')
      end
    end

    it 'overrides persisted values without changing the input' do
      persisted = {
        'INSTALLATION_NAME' => 'Legacy',
        'BRAND_NAME' => 'Legacy',
        'CLOUD_ANALYTICS_TOKEN' => 'legacy-token'
      }

      with_modified_env PUBLIC_BRAND_PROFILE: 'acelerachat' do
        resolved = described_class.apply(persisted)

        expect(resolved).to include('INSTALLATION_NAME' => 'AceleraChat', 'BRAND_NAME' => 'AceleraChat')
        expect(resolved['CLOUD_ANALYTICS_TOKEN']).to be_nil
        expect(persisted).to include('INSTALLATION_NAME' => 'Legacy', 'BRAND_NAME' => 'Legacy')
        expect(persisted['CLOUD_ANALYTICS_TOKEN']).to eq('legacy-token')
      end
    end
  end

  describe '.help_urls' do
    it 'uses Portuguese articles for pt_BR' do
      with_modified_env PUBLIC_BRAND_PROFILE: 'acelerachat' do
        expect(described_class.help_urls(locale: :pt_BR).fetch('agents')).to eq(
          '/hc/acelerachat/articles/usuarios-papeis-e-permissoes'
        )
      end
    end

    it 'falls back to English for unsupported locales' do
      with_modified_env PUBLIC_BRAND_PROFILE: 'acelerachat' do
        expect(described_class.help_urls(locale: :fr).fetch('agents')).to eq(
          '/hc/acelerachat/articles/users-roles-and-permissions-en'
        )
      end
    end
  end

  describe '.public_text' do
    it 'rebrands backend translations and removes legacy first-party links' do
      with_modified_env PUBLIC_BRAND_PROFILE: 'acelerachat' do
        expect(described_class.public_text('Chatwoot Enterprise usa Capitão at https://chwt.app/help')).to eq(
          'AceleraChat PRO usa Nemmo at /hc/acelerachat'
        )
      end
    end
  end

  describe '.validate!' do
    it 'rejects an unknown profile' do
      with_modified_env PUBLIC_BRAND_PROFILE: 'missing' do
        expect { described_class.validate! }.to raise_error(PublicBrand::InvalidProfile, /Unknown public brand profile/)
      end
    end

    it 'rejects HTTP, credential-bearing, and legacy first-party URLs' do
      unsafe_urls = [
        'http://atendimento.meugerenciador.pro',
        'https://user:secret@atendimento.meugerenciador.pro',
        'https://docs.chatwoot.com/help',
        'https://docs.chatwoot.com./help',
        '//attacker.example/path',
        '/\\attacker.example/path'
      ]

      Dir.mktmpdir do |directory|
        stub_const('PublicBrand::PROFILES_PATH', Pathname(directory))
        unsafe_urls.each do |unsafe_url|
          Pathname(directory).join('unsafe.yml').write(
            {
              'version' => 1,
              'profile_name' => 'unsafe',
              'global_config' => accelerating_global_config.merge(
                'PUBLIC_BRAND_PROFILE' => 'unsafe',
                'BRAND_URL' => unsafe_url
              ),
              'help_locales' => ['en'],
              'help_articles' => {}
            }.to_yaml
          )
          described_class.reset!

          with_modified_env PUBLIC_BRAND_PROFILE: 'unsafe' do
            expect { described_class.validate! }.to raise_error(PublicBrand::InvalidProfile, /(?:Unsafe|Invalid) URL/)
          end
        end
      end
    end

    it 'rejects invalid and legacy first-party email addresses' do
      unsafe_emails = ['not-an-email', 'support@chatwoot.com']

      Dir.mktmpdir do |directory|
        stub_const('PublicBrand::PROFILES_PATH', Pathname(directory))
        unsafe_emails.each do |unsafe_email|
          Pathname(directory).join('unsafe.yml').write(
            {
              'version' => 1,
              'profile_name' => 'unsafe',
              'global_config' => accelerating_global_config.merge(
                'PUBLIC_BRAND_PROFILE' => 'unsafe',
                'MAILER_SUPPORT_EMAIL' => unsafe_email
              ),
              'help_locales' => ['en'],
              'help_articles' => {}
            }.to_yaml
          )
          described_class.reset!

          with_modified_env PUBLIC_BRAND_PROFILE: 'unsafe' do
            expect { described_class.validate! }.to raise_error(PublicBrand::InvalidProfile, /Unsafe email/)
          end
        end
      end
    end

    it 'applies URL validation to logo resources' do
      with_temporary_profile('LOGO' => 'https://assets.chatwoot.com/logo.svg') do
        expect { described_class.validate! }.to raise_error(PublicBrand::InvalidProfile, /Unsafe URL for LOGO/)
      end
    end

    it 'rejects malformed help center slugs' do
      with_temporary_profile({}, 'help_center_slug' => '../acelerachat') do
        expect { described_class.validate! }.to raise_error(PublicBrand::InvalidProfile, /Help center slug/)
      end
    end

    it 'rejects malformed help article slugs' do
      with_temporary_profile(
        {},
        'help_articles' => { 'agents' => { 'pt_BR' => 'agentes', 'en' => '../agents' } }
      ) do
        expect { described_class.validate! }.to raise_error(PublicBrand::InvalidProfile, /Invalid help article slug/)
      end
    end
  end

  def accelerating_global_config
    YAML.safe_load(
      Rails.root.join('config/public_brand_profiles/acelerachat.yml').read,
      aliases: false
    ).fetch('global_config')
  end

  def with_temporary_profile(global_overrides = {}, profile_overrides = {}, &)
    Dir.mktmpdir do |directory|
      stub_const('PublicBrand::PROFILES_PATH', Pathname(directory))
      source = YAML.safe_load(
        Rails.root.join('config/public_brand_profiles/acelerachat.yml').read,
        aliases: false
      )
      global_config = source.fetch('global_config').merge('PUBLIC_BRAND_PROFILE' => 'unsafe').merge(global_overrides)
      profile = source.merge(
        'profile_name' => 'unsafe',
        'global_config' => global_config
      ).merge(profile_overrides)
      Pathname(directory).join('unsafe.yml').write(profile.to_yaml)
      described_class.reset!

      with_modified_env(PUBLIC_BRAND_PROFILE: 'unsafe', &)
    ensure
      described_class.reset!
    end
  end
end
