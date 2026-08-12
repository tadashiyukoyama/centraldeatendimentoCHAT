import { createI18n } from 'vue-i18n';

import enCampaign from 'dashboard/i18n/locale/en/campaign.json';
import ptBRCampaign from 'dashboard/i18n/locale/pt_BR/campaign.json';

const evolutionMessageKeys = [
  'CAMPAIGN.WHATSAPP.CREATE.FORM.PERSONALIZATION.INFO',
  'CAMPAIGN.WHATSAPP.CREATE.FORM.MESSAGE.PLACEHOLDER',
  'CAMPAIGN.WHATSAPP.CREATE.FORM.MESSAGE.ERROR',
  'CAMPAIGN.WHATSAPP.CREATE.FORM.VARIANT_TWO.PLACEHOLDER',
  'CAMPAIGN.WHATSAPP.CREATE.FORM.VARIANT_THREE.PLACEHOLDER',
];

describe('WhatsApp Evolution campaign translations', () => {
  it.each([
    ['en', enCampaign],
    ['pt_BR', ptBRCampaign],
  ])('renders Liquid contact variables literally in %s', (locale, messages) => {
    const consoleError = vi
      .spyOn(console, 'error')
      .mockImplementation(() => {});
    const i18n = createI18n({
      legacy: false,
      locale,
      messages: { [locale]: messages },
    });

    evolutionMessageKeys.forEach(key => {
      // eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
      expect(i18n.global.t(key)).toContain('{{contact.name}}');
    });
    expect(consoleError).not.toHaveBeenCalled();
    consoleError.mockRestore();
  });
});
