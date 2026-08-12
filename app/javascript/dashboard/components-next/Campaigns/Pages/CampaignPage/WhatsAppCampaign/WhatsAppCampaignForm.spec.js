import { flushPromises, shallowMount } from '@vue/test-utils';

import WhatsAppCampaignForm from './WhatsAppCampaignForm.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const { mappedValues } = vi.hoisted(() => ({
  mappedValues: {
    'campaigns/getUIFlags': { value: { isCreating: false } },
    'labels/getLabels': { value: [{ id: 9, title: 'prospectos' }] },
    'inboxes/getWhatsAppCampaignInboxes': {
      value: [
        { id: 7, name: 'WhatsApp QR', provider: 'evolution' },
        { id: 8, name: 'WhatsApp Cloud', provider: 'whatsapp_cloud' },
      ],
    },
    'inboxes/getFilteredWhatsAppTemplates': { value: () => [] },
  },
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => mappedValues[key],
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
}));

describe('WhatsAppCampaignForm', () => {
  it('creates an Evolution campaign without Meta templates and with auditable cadence', async () => {
    const wrapper = shallowMount(WhatsAppCampaignForm, {
      global: { stubs: { 'router-link': true } },
    });

    wrapper.findAllComponents(ComboBox)[0].vm.$emit('update:modelValue', 7);
    await flushPromises();

    expect(wrapper.findComponent(WhatsAppTemplateParser).exists()).toBe(false);
    expect(wrapper.findAllComponents(TextArea)).toHaveLength(3);

    const inputs = wrapper.findAllComponents(Input);
    inputs[0].vm.$emit('update:modelValue', 'Campanha autorizada');
    wrapper
      .findAllComponents(TextArea)[0]
      .vm.$emit('update:modelValue', 'Olá, {{contact.name}}!');
    wrapper
      .findAllComponents(TextArea)[1]
      .vm.$emit('update:modelValue', 'Boa tarde, {{contact.name}}!');
    inputs[1].vm.$emit('update:modelValue', 10);
    inputs[2].vm.$emit('update:modelValue', '2026-08-13T12:00');
    wrapper
      .findComponent(TagMultiSelectComboBox)
      .vm.$emit('update:modelValue', [9]);
    wrapper.findComponent(Checkbox).vm.$emit('update:modelValue', true);
    await flushPromises();

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    const payload = wrapper.emitted('submit')[0][0];
    expect(payload).toMatchObject({
      title: 'Campanha autorizada',
      message: 'Olá, {{contact.name}}!',
      inbox_id: 7,
      audience: [{ id: 9, type: 'Label' }],
      trigger_rules: {
        delivery_interval_minutes: 10,
        lawful_basis_confirmed: true,
        message_variants: ['Boa tarde, {{contact.name}}!'],
      },
    });
    expect(payload.template_params).toBeUndefined();
  });
});
