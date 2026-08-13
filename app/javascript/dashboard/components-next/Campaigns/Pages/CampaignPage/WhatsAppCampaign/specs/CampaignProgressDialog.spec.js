import { flushPromises, mount } from '@vue/test-utils';

import CampaignsAPI from 'dashboard/api/campaigns';
import CampaignProgressDialog from '../CampaignProgressDialog.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    locale: { value: 'pt-BR' },
    t: (key, values = {}) => `${key} ${JSON.stringify(values)}`,
  }),
}));

vi.mock('dashboard/api/campaigns', () => ({
  default: { getDeliveries: vi.fn() },
}));

const campaign = { id: 6, title: 'rest2' };
const basePayload = {
  campaign: {
    id: 6,
    title: 'rest2',
    status: 'active',
    scheduled_at: '2026-08-13T12:18:00Z',
  },
  deliveries: [],
  meta: { current_page: 1, total_pages: 0, total_count: 0 },
};

const mountDialog = payload => {
  CampaignsAPI.getDeliveries.mockResolvedValue({ data: payload });

  return mount(CampaignProgressDialog, {
    props: { campaign },
    global: {
      stubs: {
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open() {}, close() {} },
        },
        Button: true,
        Spinner: true,
      },
    },
  });
};

describe('CampaignProgressDialog', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.clearAllMocks();
  });

  it('shows the planned audience while a campaign is waiting for its scheduled processing', async () => {
    const wrapper = mountDialog({
      ...basePayload,
      progress: {
        phase: 'scheduled',
        planned_total: 200,
        total: 0,
        percentage: 0,
      },
    });

    await wrapper.vm.open();
    await flushPromises();

    expect(wrapper.text()).toContain(
      'CAMPAIGN.WHATSAPP.PROGRESS.SCHEDULED_TITLE'
    );
    expect(wrapper.text()).toContain('"count":200');
    expect(wrapper.text()).not.toContain(
      'CAMPAIGN.WHATSAPP.PROGRESS.EMPTY_TITLE'
    );
  });

  it('only shows the empty-audience state after processing finishes without deliveries', async () => {
    const wrapper = mountDialog({
      ...basePayload,
      campaign: { ...basePayload.campaign, status: 'completed' },
      progress: {
        phase: 'empty',
        planned_total: 200,
        total: 0,
        percentage: 0,
      },
    });

    await wrapper.vm.open();
    await flushPromises();

    expect(wrapper.text()).toContain('CAMPAIGN.WHATSAPP.PROGRESS.EMPTY_TITLE');
    expect(wrapper.text()).not.toContain(
      'CAMPAIGN.WHATSAPP.PROGRESS.SCHEDULED_TITLE'
    );
  });
});
