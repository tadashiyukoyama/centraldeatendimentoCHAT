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

export const integrationAssetPath = (integrationId, dark = false) => {
  const assetId = integrationAssetId(integrationId);
  const extension = assetId === 'openjarvis' ? 'svg' : 'png';
  const colorScheme = dark ? '-dark' : '';
  return `/dashboard/images/integrations/${assetId}${colorScheme}.${extension}`;
};

export const publicHelpCenterURL = () =>
  window.chatwootConfig?.helpCenterURL || '/hc/acelerachat';

export const contextualHelpURL = key =>
  window.chatwootConfig?.helpUrls?.[key] || publicHelpCenterURL();
