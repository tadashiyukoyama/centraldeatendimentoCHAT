import { flushPromises, shallowMount } from '@vue/test-utils';

import EmailCampaignDialog from './EmailCampaignDialog.vue';
import EmailCampaignForm from './EmailCampaignForm.vue';

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
  title: 'Product update',
  message: 'Hello',
  inbox_id: 7,
};

describe('EmailCampaignDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('closes only after the campaign is created successfully', async () => {
    dispatch.mockResolvedValue({});
    const wrapper = shallowMount(EmailCampaignDialog);

    wrapper
      .findComponent(EmailCampaignForm)
      .vm.$emit('submit', campaignDetails);
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('campaigns/create', campaignDetails);
    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  it('keeps the form open when campaign creation fails', async () => {
    dispatch.mockRejectedValue(new Error('Request failed'));
    const wrapper = shallowMount(EmailCampaignDialog);

    wrapper
      .findComponent(EmailCampaignForm)
      .vm.$emit('submit', campaignDetails);
    await flushPromises();

    expect(wrapper.emitted('close')).toBeUndefined();
    expect(useAlert).toHaveBeenCalledWith(
      'CAMPAIGN.EMAIL.CREATE.FORM.API.ERROR_MESSAGE'
    );
  });
});
