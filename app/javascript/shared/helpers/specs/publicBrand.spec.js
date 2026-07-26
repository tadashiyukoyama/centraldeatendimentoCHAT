import {
  assistantAsset,
  assistantAvatar,
  contextualHelpURL,
  integrationAssetId,
  publicHelpCenterURL,
} from '../publicBrand';

describe('publicBrand helpers', () => {
  afterEach(() => {
    window.globalConfig = {};
    window.chatwootConfig = {};
  });

  it('resolves contextual help from the canonical runtime registry', () => {
    window.chatwootConfig = {
      helpCenterURL: '/hc/acelerachat',
      helpUrls: { reports: '/hc/acelerachat/articles/relatorios' },
    };

    expect(publicHelpCenterURL()).toBe('/hc/acelerachat');
    expect(contextualHelpURL('reports')).toBe(
      '/hc/acelerachat/articles/relatorios'
    );
    expect(contextualHelpURL('missing')).toBe('/hc/acelerachat');
  });

  it('uses legacy assistant assets without a public profile', () => {
    window.globalConfig = {};

    expect(assistantAsset('logo.svg')).toBe(
      '/assets/images/dashboard/captain/logo.svg'
    );
    expect(assistantAvatar()).toBe('/assets/images/chatwoot_bot.png');
    expect(integrationAssetId('captain')).toBe('captain');
  });

  it('uses AceleraChat assets with the acelerachat profile', () => {
    window.globalConfig = {
      PUBLIC_BRAND_PROFILE: 'acelerachat',
      ASSISTANT_ASSET_BASE_URL: '/assets/images/dashboard/nemmo',
      ASSISTANT_AVATAR_URL: '/assets/images/nemmo_bot.png',
    };

    expect(assistantAsset('logo.svg')).toBe(
      '/assets/images/dashboard/nemmo/logo.svg'
    );
    expect(assistantAvatar()).toBe('/assets/images/nemmo_bot.png');
    expect(integrationAssetId('captain')).toBe('nemmo');
  });
});
