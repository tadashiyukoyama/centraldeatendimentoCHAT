import { applyPublicBrandToMessages } from '../publicBrandMessages';

describe('applyPublicBrandToMessages', () => {
  afterEach(() => {
    window.globalConfig = {};
  });

  it('does not change locale messages when no profile is active', () => {
    const messages = { TITLE: 'Chatwoot Enterprise and Captain' };

    expect(applyPublicBrandToMessages(messages)).toBe(messages);
  });

  it('rebrands nested locale values and isolates legacy first-party links', () => {
    window.globalConfig = {
      PUBLIC_BRAND_PROFILE: 'acelerachat',
      INSTALLATION_NAME: 'AceleraChat',
      ASSISTANT_PUBLIC_NAME: 'Nemmo',
      PUBLIC_PLAN_NAME: 'PRO',
      HELP_CENTER_URL: '/hc/acelerachat',
      TERMS_URL: '/legal/terms',
      PRIVACY_URL: '/legal/privacy',
      MAILER_SUPPORT_EMAIL: 'ajuda@meugerenciador.pro',
    };

    const result = applyPublicBrandToMessages({
      TITLE: 'Chatwoot Enterprise with Captain',
      LINKS: [
        'https://www.chatwoot.com/terms-of-service',
        'https://www.chatwoot.com/privacy-policy',
        'https://chwt.app/hc/agents',
        'hello@chatwoot.com',
      ],
    });

    expect(result.TITLE).toBe('AceleraChat PRO with Nemmo');
    expect(result.LINKS).toEqual([
      '/legal/terms',
      '/legal/privacy',
      '/hc/acelerachat',
      'ajuda@meugerenciador.pro',
    ]);
  });

  it('cleans every dashboard, widget, and survey locale without changing translation keys', () => {
    window.globalConfig = {
      PUBLIC_BRAND_PROFILE: 'acelerachat',
      INSTALLATION_NAME: 'AceleraChat',
      ASSISTANT_PUBLIC_NAME: 'Nemmo',
      PUBLIC_PLAN_NAME: 'PRO',
      HELP_CENTER_URL: '/hc/acelerachat',
      TERMS_URL: '/legal/terms',
      PRIVACY_URL: '/legal/privacy',
    };

    const localeFiles = {
      ...import.meta.glob('../../../dashboard/i18n/locale/**/*.json', {
        eager: true,
        import: 'default',
      }),
      ...import.meta.glob('../../../widget/i18n/locale/**/*.json', {
        eager: true,
        import: 'default',
      }),
      ...import.meta.glob('../../../survey/i18n/locale/**/*.json', {
        eager: true,
        import: 'default',
      }),
    };

    expect(Object.keys(localeFiles).length).toBeGreaterThan(160);
    Object.entries(localeFiles).forEach(([path, messages]) => {
      const transformedMessages = applyPublicBrandToMessages(messages);
      const collectValues = value => {
        if (typeof value === 'string') return [value];
        if (Array.isArray(value)) return value.flatMap(collectValues);
        if (value && typeof value === 'object') {
          return Object.values(value).flatMap(collectValues);
        }
        return [];
      };
      const transformed = collectValues(transformedMessages).join('\n');
      expect(transformed, path).not.toMatch(
        /Chatwoot|Captain|Capitão|\bEnterprise\b/i
      );
      expect(transformed, path).not.toMatch(
        /chatwoot\.com|chatwoot\.help|chwt\.app/i
      );
    });
  });
});
