<script setup>
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  agents: { type: Array, default: () => [] },
  inboxes: { type: Array, default: () => [] },
  scopeOptions: { type: Array, default: () => [] },
  subscriptionOptions: { type: Array, default: () => [] },
  isSaving: { type: Boolean, default: false },
  isValid: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);
const form = defineModel({ type: Object, required: true });
const enabled = defineModel('enabled', { type: Boolean, default: true });

const toggleArrayValue = (key, value) => {
  const values = [...(form.value[key] || [])];
  form.value[key] = values.includes(value)
    ? values.filter(item => item !== value)
    : [...values, value];
};
</script>

<template>
  <section
    class="flex flex-col gap-6 p-5 outline outline-1 outline-n-container bg-n-card rounded-xl"
  >
    <h2 class="text-heading-2 text-n-slate-12">
      {{ $t('INTEGRATION_APPS.OPENJARVIS.FORM.TITLE') }}
    </h2>

    <div class="flex items-start justify-between gap-6">
      <div>
        <label class="text-heading-3 text-n-slate-12">
          {{ $t('INTEGRATION_APPS.OPENJARVIS.FORM.ENABLED') }}
        </label>
        <p class="mt-1 text-body-small text-n-slate-11">
          {{ $t('INTEGRATION_APPS.OPENJARVIS.FORM.ENABLED_HELP') }}
        </p>
      </div>
      <Switch
        v-model="enabled"
        :aria-label="$t('INTEGRATION_APPS.OPENJARVIS.FORM.ENABLED')"
      />
    </div>

    <Input
      v-model="form.endpoint_url"
      type="url"
      :label="$t('INTEGRATION_APPS.OPENJARVIS.FORM.ENDPOINT')"
      placeholder="https://openjarvis.example.com/webhooks/acelerachat"
      :message="$t('INTEGRATION_APPS.OPENJARVIS.FORM.ENDPOINT_HELP')"
    />

    <label class="flex flex-col gap-2">
      <span class="text-heading-3 text-n-slate-12">
        {{ $t('INTEGRATION_APPS.OPENJARVIS.FORM.SERVICE_USER') }}
      </span>
      <Select
        v-model="form.service_user_id"
        class="w-full"
        :options="agents"
        :placeholder="$t('INTEGRATION_APPS.OPENJARVIS.FORM.SERVICE_USER')"
        :aria-label="$t('INTEGRATION_APPS.OPENJARVIS.FORM.SERVICE_USER')"
      />
      <p class="text-body-small text-n-slate-11">
        {{ $t('INTEGRATION_APPS.OPENJARVIS.FORM.SERVICE_USER_HELP') }}
      </p>
    </label>

    <fieldset class="flex flex-col gap-2">
      <legend class="mb-2 text-heading-3 text-n-slate-12">
        {{ $t('INTEGRATION_APPS.OPENJARVIS.FORM.INBOXES') }}
      </legend>
      <label
        class="mb-2 flex min-h-11 cursor-pointer items-center gap-3 rounded-lg px-3 bg-n-alpha-1"
      >
        <Checkbox
          :model-value="form.inbox_access_mode === 'all_account'"
          @change="
            form.inbox_access_mode =
              form.inbox_access_mode === 'all_account'
                ? 'selected'
                : 'all_account'
          "
        />
        <span class="flex flex-col">
          <span class="text-body-main text-n-slate-12">
            {{ $t('INTEGRATION_APPS.OPENJARVIS.FORM.ALL_INBOXES') }}
          </span>
          <span class="text-body-small text-n-slate-11">
            {{ $t('INTEGRATION_APPS.OPENJARVIS.FORM.ALL_INBOXES_HELP') }}
          </span>
        </span>
      </label>
      <label
        v-for="inbox in inboxes"
        v-show="form.inbox_access_mode !== 'all_account'"
        :key="inbox.id"
        class="flex min-h-11 cursor-pointer items-center gap-3 rounded-lg px-3 hover:bg-n-alpha-2"
      >
        <Checkbox
          :model-value="form.allowed_inbox_ids.includes(inbox.id)"
          @change="toggleArrayValue('allowed_inbox_ids', inbox.id)"
        />
        <span class="text-body-main text-n-slate-12">{{ inbox.name }}</span>
      </label>
    </fieldset>

    <fieldset class="flex flex-col gap-2">
      <legend class="mb-2 text-heading-3 text-n-slate-12">
        {{ $t('INTEGRATION_APPS.OPENJARVIS.FORM.SCOPES') }}
      </legend>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
        <label
          v-for="scope in scopeOptions"
          :key="scope"
          class="flex min-h-11 cursor-pointer items-center gap-3 rounded-lg px-3 hover:bg-n-alpha-2"
        >
          <Checkbox
            :model-value="form.scopes.includes(scope)"
            @change="toggleArrayValue('scopes', scope)"
          />
          <code class="text-sm text-n-slate-12">{{ scope }}</code>
        </label>
      </div>
    </fieldset>

    <div class="flex items-start justify-between gap-6">
      <label class="text-heading-3 text-n-slate-12">
        {{ $t('INTEGRATION_APPS.OPENJARVIS.FORM.WEBHOOKS') }}
      </label>
      <Switch
        v-model="form.webhooks_enabled"
        :aria-label="$t('INTEGRATION_APPS.OPENJARVIS.FORM.WEBHOOKS')"
      />
    </div>

    <fieldset class="flex flex-col gap-2" :disabled="!form.webhooks_enabled">
      <legend class="mb-2 text-heading-3 text-n-slate-12">
        {{ $t('INTEGRATION_APPS.OPENJARVIS.FORM.SUBSCRIPTIONS') }}
      </legend>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
        <label
          v-for="event in subscriptionOptions"
          :key="event"
          class="flex min-h-11 items-center gap-3 rounded-lg px-3"
          :class="
            form.webhooks_enabled
              ? 'cursor-pointer hover:bg-n-alpha-2'
              : 'opacity-50'
          "
        >
          <Checkbox
            :model-value="form.subscriptions.includes(event)"
            :disabled="!form.webhooks_enabled"
            @change="toggleArrayValue('subscriptions', event)"
          />
          <code class="text-sm text-n-slate-12">{{ event }}</code>
        </label>
      </div>
    </fieldset>

    <div
      class="flex flex-col items-start gap-3 border-t border-n-weak pt-5 sm:flex-row sm:items-center sm:justify-between"
    >
      <p
        v-if="!isValid"
        class="text-body-small text-n-ruby-11"
        role="alert"
        aria-live="polite"
      >
        {{ $t('INTEGRATION_APPS.OPENJARVIS.FORM.VALIDATION') }}
      </p>
      <span v-else />
      <Button
        :label="$t('INTEGRATION_APPS.OPENJARVIS.FORM.SAVE')"
        :is-loading="isSaving"
        :disabled="!isValid || isSaving"
        @click="emit('save')"
      />
    </div>
  </section>
</template>
