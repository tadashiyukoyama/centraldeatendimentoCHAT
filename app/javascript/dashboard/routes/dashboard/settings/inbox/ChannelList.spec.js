import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import ChannelList from './ChannelList.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref({}),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountId: ref(1),
    currentAccount: ref(undefined),
  }),
}));

describe('ChannelList', () => {
  it('renders supported inbox channels before account features finish loading', () => {
    window.chatwootConfig = {};
    const wrapper = mount(ChannelList, {
      global: {
        stubs: {
          ChannelItem: {
            props: ['channel'],
            template: '<div data-test="channel" :data-channel="channel.key" />',
          },
        },
      },
    });

    const channels = wrapper
      .findAll('[data-test="channel"]')
      .map(item => item.attributes('data-channel'));

    expect(channels).toContain('email');
    expect(channels).not.toContain('voice');
    expect(channels).not.toContain('whatsapp_call');
  });
});
