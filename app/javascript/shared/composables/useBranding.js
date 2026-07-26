/**
 * Composable for branding-related utilities
 * Provides methods to customize text with installation-specific branding
 */
import { useMapGetter } from 'dashboard/composables/store.js';

export function useBranding() {
  const globalConfig = useMapGetter('globalConfig/get');
  /**
   * Replaces "Chatwoot" in text with the installation name from global config
   * @param {string} text - The text to process
   * @returns {string} - Text with "Chatwoot" replaced by installation name
   */
  const replaceInstallationName = text => {
    if (!text) return text;

    const installationName = globalConfig.value?.installationName;
    if (!installationName) return text;

    const assistantName = globalConfig.value?.assistantPublicName || 'Nemmo';
    const planName = globalConfig.value?.publicPlanName || 'PRO';

    return text
      .replace(/Chatwoot/gi, installationName)
      .replace(/Captain|Capitão/gi, assistantName)
      .replace(/\bEnterprise\b/gi, planName);
  };

  return {
    replaceInstallationName,
  };
}
