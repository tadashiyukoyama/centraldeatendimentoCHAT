import { flushPromises, mount } from '@vue/test-utils';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import EvolutionWhatsapp from './EvolutionWhatsapp.vue';
import WhatsappChannel from 'dashboard/api/channel/whatsappChannel';

const replace = vi.fn();
const alert = vi.fn();

vi.mock('vue-router', () => ({
  useRouter: () => ({ replace }),
}));

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
    createEvolutionProvisioning: vi.fn(),
    getEvolutionProvisioning: vi.fn(),
    deleteEvolutionProvisioning: vi.fn(),
  },
}));

const mountComponent = () =>
  mount(EvolutionWhatsapp, {
    global: {
      mocks: { $t: key => key },
      stubs: {
        NextButton: {
          props: ['label'],
          template: '<button type="submit">{{ label }}</button>',
        },
        Icon: true,
      },
    },
  });

describe('EvolutionWhatsapp', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    replace.mockReset();
    alert.mockReset();
    WhatsappChannel.createEvolutionProvisioning.mockReset();
    WhatsappChannel.getEvolutionProvisioning.mockReset();
    WhatsappChannel.deleteEvolutionProvisioning.mockReset();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('creates a provisioning, renders its QR Code and routes only after the inbox exists', async () => {
    WhatsappChannel.createEvolutionProvisioning.mockResolvedValue({
      data: {
        id: 'public-id',
        status: 'waiting_qr',
        qr_code: 'qr-base64',
      },
    });
    WhatsappChannel.getEvolutionProvisioning.mockResolvedValue({
      data: {
        id: 'public-id',
        status: 'connected',
        inbox_id: 42,
        connected_number: '+5511999999999',
      },
    });
    const wrapper = mountComponent();

    await wrapper.find('input').setValue('Sales WhatsApp');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(WhatsappChannel.createEvolutionProvisioning).toHaveBeenCalledWith({
      inbox_name: 'Sales WhatsApp',
    });
    expect(wrapper.find('img').attributes('src')).toBe(
      'data:image/png;base64,qr-base64'
    );
    expect(replace).not.toHaveBeenCalled();

    await vi.advanceTimersByTimeAsync(2000);
    await flushPromises();

    expect(WhatsappChannel.getEvolutionProvisioning).toHaveBeenCalledWith(
      'public-id'
    );
    expect(replace).toHaveBeenCalledWith({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: 42 },
    });
  });

  it('deletes an unfinished remote session when the administrator cancels', async () => {
    WhatsappChannel.createEvolutionProvisioning.mockResolvedValue({
      data: {
        id: 'public-id',
        status: 'waiting_qr',
        qr_code: 'qr-base64',
      },
    });
    WhatsappChannel.deleteEvolutionProvisioning.mockResolvedValue({});
    const wrapper = mountComponent();

    await wrapper.find('input').setValue('Finance WhatsApp');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    await wrapper.findAll('button').at(-1).trigger('click');
    await flushPromises();

    expect(WhatsappChannel.deleteEvolutionProvisioning).toHaveBeenCalledWith(
      'public-id'
    );
    expect(wrapper.find('form').exists()).toBe(true);
  });
});
