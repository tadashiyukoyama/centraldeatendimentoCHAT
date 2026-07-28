<script setup>
import { computed, onMounted, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { useMapGetter } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';

import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const { isAdmin } = useAdmin();
const store = useStore();
const agents = useMapGetter('agents/getVerifiedAgents');
const teams = useMapGetter('teams/getTeams');

const state = reactive({
  contactProfile: false,
  demoScheduling: false,
  demoAssigneeId: '',
  paymentNotices: false,
  financeTeamId: '',
});

const agentOptions = computed(() =>
  agents.value
    .filter(agent => agent.email)
    .map(agent => ({
      value: agent.id,
      label: `${agent.name} (${agent.email})`,
    }))
);

const teamOptions = computed(() =>
  teams.value.map(team => ({
    value: team.id,
    label: team.name,
  }))
);

const demoReady = computed(
  () => !state.demoScheduling || Boolean(state.demoAssigneeId)
);
const paymentReady = computed(
  () => !state.paymentNotices || Boolean(state.financeTeamId)
);
const canSubmit = computed(
  () => isAdmin.value && demoReady.value && paymentReady.value
);

const updateStateFromAssistant = assistant => {
  const { config = {} } = assistant;
  const operationalTools = assistant.operational_tools || {};
  state.contactProfile = Boolean(config.feature_contact_attributes);
  state.demoScheduling = Boolean(config.feature_demo_scheduling);
  const demoAssigneeId =
    config.demo_assignee_id || operationalTools.demo_scheduling?.assignee_id;
  state.demoAssigneeId = demoAssigneeId ? Number(demoAssigneeId) : '';
  state.paymentNotices = Boolean(config.feature_payment_notices);
  const financeTeamId =
    config.finance_team_id || operationalTools.payment_notices?.finance_team_id;
  state.financeTeamId = financeTeamId ? Number(financeTeamId) : '';
};

const handleDemoToggle = () => {
  if (state.demoScheduling) state.contactProfile = true;
};

const handleContactToggle = () => {
  if (!state.contactProfile && state.demoScheduling) {
    state.contactProfile = true;
    useAlert(
      t(
        'CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.CONTACT_PROFILE.REQUIRED_FOR_DEMO'
      )
    );
  }
};

const handleSubmit = () => {
  if (!canSubmit.value) {
    useAlert(
      t('CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.INCOMPLETE_MESSAGE')
    );
    return;
  }

  emit('submit', {
    config: {
      ...props.assistant.config,
      feature_contact_attributes: state.contactProfile,
      feature_demo_scheduling: state.demoScheduling,
      demo_assignee_id: state.demoAssigneeId || null,
      feature_payment_notices: state.paymentNotices,
      finance_team_id: state.financeTeamId || null,
    },
  });
};

onMounted(() => {
  if (!agents.value.length) store.dispatch('agents/get');
  if (!teams.value.length) store.dispatch('teams/get');
});

watch(
  () => props.assistant,
  newAssistant => {
    if (newAssistant) updateStateFromAssistant(newAssistant);
  },
  { immediate: true }
);
</script>

<template>
  <div class="flex flex-col gap-4">
    <p
      v-if="!isAdmin"
      class="rounded-lg bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-11"
    >
      {{ t('CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.READ_ONLY') }}
    </p>

    <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
      <div class="flex items-start justify-between gap-4">
        <div>
          <h4 class="text-sm font-medium text-n-slate-12">
            {{
              t(
                'CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.CONTACT_PROFILE.TITLE'
              )
            }}
          </h4>
          <p class="mt-1 text-sm text-n-slate-11">
            {{
              t(
                'CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.CONTACT_PROFILE.DESCRIPTION'
              )
            }}
          </p>
        </div>
        <Switch
          v-model="state.contactProfile"
          :disabled="!isAdmin"
          @change="handleContactToggle"
        />
      </div>
    </div>

    <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
      <div class="flex items-start justify-between gap-4">
        <div>
          <h4 class="text-sm font-medium text-n-slate-12">
            {{
              t(
                'CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.DEMO_SCHEDULING.TITLE'
              )
            }}
          </h4>
          <p class="mt-1 text-sm text-n-slate-11">
            {{
              t(
                'CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.DEMO_SCHEDULING.DESCRIPTION'
              )
            }}
          </p>
        </div>
        <Switch
          v-model="state.demoScheduling"
          :disabled="!isAdmin"
          @change="handleDemoToggle"
        />
      </div>
      <label
        v-if="state.demoScheduling"
        class="mt-4 flex flex-col gap-1.5 text-sm font-medium text-n-slate-12"
      >
        {{
          t(
            'CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.DEMO_SCHEDULING.ASSIGNEE'
          )
        }}
        <Select
          v-model="state.demoAssigneeId"
          class="!w-full [&>select]:w-full"
          :disabled="!isAdmin"
          :options="agentOptions"
          :placeholder="
            t(
              'CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.DEMO_SCHEDULING.SELECT_ASSIGNEE'
            )
          "
          :error="demoReady ? '' : 'required'"
        />
      </label>
    </div>

    <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
      <div class="flex items-start justify-between gap-4">
        <div>
          <h4 class="text-sm font-medium text-n-slate-12">
            {{
              t(
                'CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.PAYMENT_NOTICES.TITLE'
              )
            }}
          </h4>
          <p class="mt-1 text-sm text-n-slate-11">
            {{
              t(
                'CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.PAYMENT_NOTICES.DESCRIPTION'
              )
            }}
          </p>
        </div>
        <Switch v-model="state.paymentNotices" :disabled="!isAdmin" />
      </div>
      <label
        v-if="state.paymentNotices"
        class="mt-4 flex flex-col gap-1.5 text-sm font-medium text-n-slate-12"
      >
        {{
          t(
            'CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.PAYMENT_NOTICES.TEAM'
          )
        }}
        <Select
          v-model="state.financeTeamId"
          class="!w-full [&>select]:w-full"
          :disabled="!isAdmin"
          :options="teamOptions"
          :placeholder="
            t(
              'CAPTAIN.ASSISTANTS.SETTINGS.OPERATIONAL_TOOLS.PAYMENT_NOTICES.SELECT_TEAM'
            )
          "
          :error="paymentReady ? '' : 'required'"
        />
      </label>
    </div>

    <div v-if="isAdmin">
      <Button
        :label="t('CAPTAIN.ASSISTANTS.FORM.UPDATE')"
        :disabled="!canSubmit"
        @click="handleSubmit"
      />
    </div>
  </div>
</template>
