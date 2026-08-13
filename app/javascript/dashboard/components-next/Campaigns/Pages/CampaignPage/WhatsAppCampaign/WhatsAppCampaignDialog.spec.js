import { flushPromises, shallowMount } from '@vue/test-utils';

import WhatsAppCampaignDialog from './WhatsAppCampaignDialog.vue';
import WhatsAppCampaignForm from './WhatsAppCampaignForm.vue';
import CampaignAudienceImportDialog from './CampaignAudienceImportDialog.vue';

const { dispatch, useAlert, useTrack, getAudiences, createList } = vi.hoisted(
  () => ({
    dispatch: vi.fn(),
    useAlert: vi.fn(),
    useTrack: vi.fn(),
    getAudiences: vi.fn(),
    createList: vi.fn(),
  })
);

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

vi.mock('dashboard/api/campaignAudiences', () => ({
  default: {
    get: getAudiences,
    createList,
  },
}));

const campaignDetails = {
  title: 'Prospecção autorizada',
  message: 'Olá, {{contact.name}}!',
  inbox_id: 7,
};

describe('WhatsAppCampaignDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    getAudiences.mockResolvedValue({ data: [] });
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

  it('imports a contact CSV from the campaign flow', async () => {
    createList.mockResolvedValue({
      data: {
        id: 12,
        name: 'Leads agosto',
        label_id: 18,
        status: 'pending',
        contact_count: 0,
      },
    });
    const wrapper = shallowMount(WhatsAppCampaignDialog);
    const file = new File(['name,phone_number,labels'], 'leads.csv', {
      type: 'text/csv',
    });

    wrapper.findComponent(CampaignAudienceImportDialog).vm.$emit('import', {
      name: 'Leads agosto',
      file,
    });
    await flushPromises();

    expect(createList).toHaveBeenCalledWith({ name: 'Leads agosto', file });
    expect(useAlert).toHaveBeenCalledWith(
      'CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.SUCCESS'
    );
    expect(wrapper.emitted('close')).toBeUndefined();
  });

  it('keeps the campaign form open when contact import fails', async () => {
    createList.mockRejectedValue({
      response: { data: { message: 'Falha na lista' } },
    });
    const wrapper = shallowMount(WhatsAppCampaignDialog);

    wrapper.findComponent(CampaignAudienceImportDialog).vm.$emit('import', {
      name: 'Leads',
      file: new File(['invalid'], 'leads.csv'),
    });
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith('Falha na lista');
    expect(wrapper.emitted('close')).toBeUndefined();
  });
});
