export const assistantAsset = fileName => {
  const baseURL =
    window.globalConfig?.ASSISTANT_ASSET_BASE_URL ||
    '/assets/images/dashboard/captain';
  return `${baseURL}/${fileName}`;
};

export const assistantAvatar = () =>
  window.globalConfig?.ASSISTANT_AVATAR_URL ||
  '/assets/images/chatwoot_bot.png';

export const integrationAssetId = integrationId => {
  if (
    window.globalConfig?.PUBLIC_BRAND_PROFILE === 'acelerachat' &&
    integrationId === 'captain'
  ) {
    return 'nemmo';
  }
  return integrationId;
};

export const publicHelpCenterURL = () =>
  window.chatwootConfig?.helpCenterURL || '/hc/acelerachat';

export const contextualHelpURL = key =>
  window.chatwootConfig?.helpUrls?.[key] || publicHelpCenterURL();
