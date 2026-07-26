class Acelerachat::PublicContent::PortalProfile
  def self.attributes(portal_marker:)
    {
      name: 'Central de Ajuda AceleraChat',
      slug: 'acelerachat',
      page_title: 'AceleraChat — Ajuda, privacidade e operação',
      header_text: 'Encontre orientações sobre canais, setores, segurança, Nemmo e seus direitos.',
      homepage_link: 'https://atendimento.meugerenciador.pro',
      color: '#2563EB',
      archived: false,
      config: portal_config(portal_marker)
    }
  end

  def self.portal_config(portal_marker)
    {
      'allowed_locales' => %w[pt_BR en],
      'default_locale' => 'pt_BR',
      'draft_locales' => [],
      'layout' => 'documentation',
      'website_token' => portal_marker,
      'locale_translations' => locale_translations
    }
  end
  private_class_method :portal_config

  def self.locale_translations
    {
      'pt_BR' => {
        'name' => 'Central de Ajuda AceleraChat',
        'page_title' => 'AceleraChat — Ajuda, privacidade e operação',
        'header_text' => 'Orientações sobre canais, setores, segurança, Nemmo e seus direitos.'
      },
      'en' => {
        'name' => 'AceleraChat Help Center',
        'page_title' => 'AceleraChat — Help, privacy, and operations',
        'header_text' => 'Guidance on channels, teams, security, Nemmo, and privacy rights.'
      }
    }
  end
  private_class_method :locale_translations
end
