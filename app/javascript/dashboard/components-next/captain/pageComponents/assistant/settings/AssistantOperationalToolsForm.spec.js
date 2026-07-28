import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import AssistantOperationalToolsForm from './AssistantOperationalToolsForm.vue';

const { dispatch, adminState, getterValues, useAlert } = vi.hoisted(() => ({
  dispatch: vi.fn(),
  adminState: { value: true },
  useAlert: vi.fn(),
  getterValues: {
    'agents/getVerifiedAgents': {
      value: [
        { id: 7, name: 'Especialista', email: 'especialista@example.com' },
      ],
    },
    'teams/getTeams': {
      value: [{ id: 9, name: 'Financeiro' }],
    },
  },
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: key => getterValues[key],
}));

vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({
    isAdmin: {
      __v_isRef: true,
      get value() {
        return adminState.value;
      },
    },
  }),
}));

vi.mock('dashboard/composables', () => ({ useAlert }));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const SwitchStub = {
  name: 'Switch',
  props: ['modelValue', 'disabled'],
  emits: ['update:modelValue', 'change'],
  template: '<button type="button" />',
};

const SelectStub = {
  name: 'Select',
  props: ['modelValue', 'disabled', 'options', 'placeholder', 'error'],
  emits: ['update:modelValue'],
  template: '<select />',
};

const ButtonStub = {
  name: 'Button',
  props: ['label', 'disabled'],
  emits: ['click'],
  template:
    '<button data-test="save-operational-tools" :disabled="disabled" @click="$emit(\'click\')" />',
};

const mountComponent = assistant =>
  shallowMount(AssistantOperationalToolsForm, {
    props: { assistant },
    global: {
      stubs: {
        Switch: SwitchStub,
        Select: SelectStub,
        Button: ButtonStub,
      },
    },
  });

describe('AssistantOperationalToolsForm', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    adminState.value = true;
    getterValues['agents/getVerifiedAgents'].value = [
      { id: 7, name: 'Especialista', email: 'especialista@example.com' },
    ];
    getterValues['teams/getTeams'].value = [{ id: 9, name: 'Financeiro' }];
  });

  it('loads tenant resources and submits a complete configuration without discarding existing values', async () => {
    getterValues['agents/getVerifiedAgents'].value = [];
    getterValues['teams/getTeams'].value = [];
    const wrapper = mountComponent({
      id: 1,
      config: { feature_faq: true },
      operational_tools: {},
    });

    expect(dispatch).toHaveBeenCalledWith('agents/get');
    expect(dispatch).toHaveBeenCalledWith('teams/get');

    const switches = wrapper.findAllComponents(SwitchStub);
    switches[1].vm.$emit('update:modelValue', true);
    switches[1].vm.$emit('change');
    switches[2].vm.$emit('update:modelValue', true);
    await nextTick();

    const selects = wrapper.findAllComponents(SelectStub);
    selects[0].vm.$emit('update:modelValue', 7);
    selects[1].vm.$emit('update:modelValue', 9);
    await nextTick();

    await wrapper.get('[data-test="save-operational-tools"]').trigger('click');

    expect(wrapper.emitted('submit')).toEqual([
      [
        {
          config: {
            feature_faq: true,
            feature_contact_attributes: true,
            feature_demo_scheduling: true,
            demo_assignee_id: 7,
            feature_payment_notices: true,
            finance_team_id: 9,
          },
        },
      ],
    ]);
  });

  it('keeps operational settings read-only for non-administrators', () => {
    adminState.value = false;
    const wrapper = mountComponent({
      id: 1,
      config: { feature_contact_attributes: true },
    });

    expect(wrapper.text()).toContain(
      'CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.READ_ONLY'
    );
    expect(wrapper.find('[data-test="save-operational-tools"]').exists()).toBe(
      false
    );
    expect(
      wrapper
        .findAllComponents(SwitchStub)
        .every(item => item.props('disabled'))
    ).toBe(true);
  });

  it('resolves legacy specialist configuration returned by the backend', () => {
    const wrapper = mountComponent({
      id: 1,
      config: {
        feature_demo_scheduling: true,
        demo_assignee_email: 'especialista@example.com',
      },
      operational_tools: {
        demo_scheduling: { ready: true, assignee_id: 7 },
      },
    });

    expect(wrapper.findComponent(SelectStub).props('modelValue')).toBe(7);
  });
});
