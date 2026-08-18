import { mount } from '@vue/test-utils';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import OpenJarvisAccessForm from './OpenJarvisAccessForm.vue';

describe('OpenJarvisAccessForm', () => {
  it('updates authorized inboxes through the controlled checklist', async () => {
    const form = {
      endpoint_url: '',
      service_user_id: 1,
      allowed_inbox_ids: [],
      scopes: ['inboxes:read'],
      subscriptions: [],
      webhooks_enabled: false,
    };
    const wrapper = mount(OpenJarvisAccessForm, {
      props: {
        modelValue: form,
        enabled: true,
        agents: [{ value: 1, label: 'Admin' }],
        inboxes: [{ id: 10, name: 'Suporte' }],
        scopeOptions: ['inboxes:read'],
        subscriptionOptions: [],
        isValid: true,
      },
    });

    await wrapper.findAllComponents(Checkbox)[0].vm.$emit('change');

    expect(form.allowed_inbox_ids).toEqual([10]);
  });

  it('disables saving when the parent validation fails', () => {
    const wrapper = mount(OpenJarvisAccessForm, {
      props: {
        modelValue: {
          endpoint_url: '',
          service_user_id: '',
          allowed_inbox_ids: [],
          scopes: [],
          subscriptions: [],
          webhooks_enabled: false,
        },
        enabled: true,
        isValid: false,
      },
    });

    expect(wrapper.find('button[disabled]').exists()).toBe(true);
  });
});
