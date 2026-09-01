import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import InstagramCommentAutomationPage from './InstagramCommentAutomationPage.vue';
import api from 'dashboard/api/instagramCommentAutomations';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('dashboard/api/channel/instagramClient', () => ({
  default: {
    generateAuthorization: vi.fn(),
  },
}));

vi.mock('dashboard/api/instagramCommentAutomations', () => ({
  default: {
    getAll: vi.fn(),
    getEvents: vi.fn(),
    getSubscription: vi.fn(),
    createAutomation: vi.fn(),
    updateAutomation: vi.fn(),
    deleteAutomation: vi.fn(),
    activateSubscription: vi.fn(),
  },
}));

const mountComponent = () =>
  mount(InstagramCommentAutomationPage, {
    props: {
      inbox: { id: 21 },
    },
    global: {
      mocks: {
        $t: key => key,
      },
      stubs: {
        Banner: {
          template: '<div><slot /></div>',
        },
        Button: true,
        Spinner: true,
      },
    },
  });

describe('InstagramCommentAutomationPage', () => {
  beforeEach(() => {
    api.getAll.mockReset();
    api.getEvents.mockReset();
    api.getSubscription.mockReset();

    api.getAll.mockResolvedValue({ data: { payload: [] } });
    api.getEvents.mockResolvedValue({
      data: {
        payload: [
          {
            id: 1,
            comment_text: 'demo',
            sender_username: 'cliente_teste',
            automation_name: null,
            status: 'ignored',
          },
        ],
      },
    });
    api.getSubscription.mockResolvedValue({
      data: {
        success: true,
        subscribed_fields: ['comments', 'live_comments'],
        missing_fields: [],
        reauthorization_required: false,
      },
    });
  });

  it('renders an Instagram username without parsing @ as an i18n link', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.text()).toContain('@cliente_teste');
  });
});
