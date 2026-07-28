import { mount } from '@vue/test-utils';
import ChannelItem from './ChannelItem.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const mountChannelItem = props =>
  mount(ChannelItem, {
    props: {
      channel: {
        key: 'email',
        title: 'E-mail',
        description: 'Caixa de entrada por e-mail',
        icon: 'i-woot-mail',
      },
      ...props,
    },
    global: {
      stubs: {
        ChannelSelector: {
          props: ['disabled'],
          emits: ['click'],
          template:
            '<button data-test="channel" :disabled="disabled" @click="$emit(\'click\')" />',
        },
      },
    },
  });

describe('ChannelItem', () => {
  it('fails closed while the account feature catalog is unavailable', () => {
    const wrapper = mountChannelItem();

    expect(wrapper.get('[data-test="channel"]').attributes('disabled')).toBe(
      ''
    );
  });

  it('enables and emits the selected email channel when its feature is active', async () => {
    const wrapper = mountChannelItem({
      enabledFeatures: { channel_email: true },
    });

    const button = wrapper.get('[data-test="channel"]');
    expect(button.attributes('disabled')).toBeUndefined();

    await button.trigger('click');

    expect(wrapper.emitted('channelItemClick')).toEqual([['email']]);
  });
});
