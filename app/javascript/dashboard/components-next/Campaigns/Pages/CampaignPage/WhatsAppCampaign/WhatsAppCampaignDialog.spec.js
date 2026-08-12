import { flushPromises, shallowMount } from '@vue/test-utils';

import WhatsAppCampaignDialog from './WhatsAppCampaignDialog.vue';
import WhatsAppCampaignForm from './WhatsAppCampaignForm.vue';

const { dispatch, useAlert, useTrack } = vi.hoisted(() => ({
  dispatch: vi.fn(),
  useAlert: vi.fn(),
  useTrack: vi.fn(),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert,
  useTrack,
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const campaignDetails = {
  title: 'Prospecção autorizada',
  message: 'Olá, {{contact.name}}!',
  inbox_id: 7,
};

describe('WhatsAppCampaignDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('closes only after the campaign is created successfully', async () => {
    dispatch.mockResolvedValue({});
    const wrapper = shallowMount(WhatsAppCampaignDialog);

    wrapper
      .findComponent(WhatsAppCampaignForm)
      .vm.$emit('submit', campaignDetails);
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('campaigns/create', campaignDetails);
    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  it('keeps the form open when campaign creation fails', async () => {
    dispatch.mockRejectedValue(new Error('Request failed'));
    const wrapper = shallowMount(WhatsAppCampaignDialog);

    wrapper
      .findComponent(WhatsAppCampaignForm)
      .vm.$emit('submit', campaignDetails);
    await flushPromises();

    expect(wrapper.emitted('close')).toBeUndefined();
    expect(useAlert).toHaveBeenCalledWith(
      'CAMPAIGN.WHATSAPP.CREATE.FORM.API.ERROR_MESSAGE'
    );
  });
});
