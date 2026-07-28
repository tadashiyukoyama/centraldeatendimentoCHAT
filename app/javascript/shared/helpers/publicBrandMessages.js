const replacePublicBrandText = (text, config) => {
  const helpCenterURL = config.HELP_CENTER_URL || '/hc/acelerachat';
  const termsURL = config.TERMS_URL || '/legal/terms';
  const privacyURL = config.PRIVACY_URL || '/legal/privacy';
  const supportEmail =
    config.MAILER_SUPPORT_EMAIL || 'suporte@aifoodmanager.pro';

  return text
    .replace(
      /https:\/\/(?:www\.)?chatwoot\.com\/(?:terms(?:-of-service)?|terms-of-use)[^\s"'<>)]*/gi,
      termsURL
    )
    .replace(
      /https:\/\/(?:www\.)?chatwoot\.com\/privacy(?:-policy)?[^\s"'<>)]*/gi,
      privacyURL
    )
    .replace(
      /https:\/\/(?:[a-z0-9-]+\.)*(?:chatwoot\.com|chatwoot\.help|chwt\.app)[^\s"'<>)]*/gi,
      helpCenterURL
    )
    .replace(/[A-Z0-9._%+-]+@chatwoot\.com/gi, supportEmail)
    .replace(/Chatwoot/gi, config.INSTALLATION_NAME || 'AceleraChat')
    .replace(/Captain|Capitão/gi, config.ASSISTANT_PUBLIC_NAME || 'Nemmo')
    .replace(/\bEnterprise\b/gi, config.PUBLIC_PLAN_NAME || 'PRO');
};

const transform = (value, config) => {
  if (typeof value === 'string') return replacePublicBrandText(value, config);
  if (Array.isArray(value)) return value.map(item => transform(item, config));
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, transform(item, config)])
    );
  }
  return value;
};

export const applyPublicBrandToMessages = messages => {
  const config = window.globalConfig || {};
  if (config.PUBLIC_BRAND_PROFILE !== 'acelerachat') return messages;

  return transform(messages, config);
};
