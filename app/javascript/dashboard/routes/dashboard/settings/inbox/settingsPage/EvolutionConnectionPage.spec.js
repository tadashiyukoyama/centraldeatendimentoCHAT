import { flushPromises, mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import EvolutionConnectionPage from './EvolutionConnectionPage.vue';
import WhatsappChannel from 'dashboard/api/channel/whatsappChannel';

const alert = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => alert(message),
}));

vi.mock('dashboard/store/utils/api', () => ({
  parseAPIErrorResponse: () => '',
}));

vi.mock('dashboard/api/channel/whatsappChannel', () => ({
  default: {
    getEvolutionProvisioning: vi.fn(),
    reconnectEvolutionProvisioning: vi.fn(),
    disconnectEvolutionProvisioning: vi.fn(),
  },
}));

const mountComponent = connection => {
  const store = createStore({
    modules: {
      inboxes: {
        namespaced: true,
        actions: { get: vi.fn() },
      },
    },
  });

  return mount(EvolutionConnectionPage, {
    props: {
      inbox: { id: 7, evolution_connection: connection },
    },
    global: {
      plugins: [store],
      mocks: { $t: key => key },
      stubs: {
        NextButton: {
          props: ['label'],
          emits: ['click'],
          template:
            '<button type="button" @click="$emit(\'click\')">{{ label }}</button>',
        },
        Icon: true,
      },
    },
  });
};

describe('EvolutionConnectionPage', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    alert.mockReset();
    WhatsappChannel.getEvolutionProvisioning.mockReset();
    WhatsappChannel.reconnectEvolutionProvisioning.mockReset();
    WhatsappChannel.disconnectEvolutionProvisioning.mockReset();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('reconnects a disconnected inbox and renders the new QR Code', async () => {
    WhatsappChannel.getEvolutionProvisioning.mockResolvedValue({
      data: { id: 'public-id', status: 'disconnected' },
    });
    WhatsappChannel.reconnectEvolutionProvisioning.mockResolvedValue({
      data: {
        id: 'public-id',
        status: 'waiting_qr',
        qr_code: 'qr-base64',
      },
    });
    const wrapper = mountComponent({
      public_id: 'public-id',
      status: 'disconnected',
    });
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('RECONNECT'))
      .trigger('click');
    await flushPromises();

    expect(WhatsappChannel.reconnectEvolutionProvisioning).toHaveBeenCalledWith(
      'public-id'
    );
    expect(wrapper.find('img').attributes('src')).toBe(
      'data:image/png;base64,qr-base64'
    );
  });

  it('disconnects a connected inbox without deleting it', async () => {
    WhatsappChannel.getEvolutionProvisioning.mockResolvedValue({
      data: { id: 'public-id', status: 'connected' },
    });
    WhatsappChannel.disconnectEvolutionProvisioning.mockResolvedValue({
      data: { id: 'public-id', status: 'disconnected' },
    });
    const wrapper = mountComponent({
      public_id: 'public-id',
      status: 'connected',
    });
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('DISCONNECT'))
      .trigger('click');
    await flushPromises();

    expect(
      WhatsappChannel.disconnectEvolutionProvisioning
    ).toHaveBeenCalledWith('public-id');
    expect(alert).toHaveBeenCalledWith(
      'INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.DISCONNECT_SUCCESS'
    );
    expect(wrapper.find('img').exists()).toBe(false);
  });
});
