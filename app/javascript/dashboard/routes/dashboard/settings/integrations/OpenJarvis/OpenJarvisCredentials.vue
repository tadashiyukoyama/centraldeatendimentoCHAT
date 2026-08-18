<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  apiBaseUrl: { type: String, default: '' },
  credentials: { type: Object, default: () => ({}) },
  metadata: { type: Object, default: () => ({}) },
  isDisconnecting: { type: Boolean, default: false },
});

const emit = defineEmits(['copy', 'rotate', 'disconnect']);
const { t } = useI18n();

const rows = computed(() => [
  {
    key: 'access_token',
    label: t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.BEARER'),
    value: props.credentials.access_token,
    suffix: props.metadata.access_token_last_four,
  },
  {
    key: 'webhook_secret',
    label: t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.SIGNING_SECRET'),
    value: props.credentials.webhook_secret,
    suffix: props.metadata.webhook_secret_last_four,
  },
]);
</script>

<template>
  <section
    class="flex flex-col gap-5 p-5 outline outline-1 outline-n-container bg-n-card rounded-xl"
  >
    <h2 class="text-heading-2 text-n-slate-12">
      {{ $t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.TITLE') }}
    </h2>
    <div class="rounded-lg bg-n-alpha-2 p-4">
      <p class="text-label-small text-n-slate-11">
        {{ $t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.API_BASE') }}
      </p>
      <code class="mt-1 block break-all text-sm text-n-slate-12">{{
        apiBaseUrl
      }}</code>
    </div>
    <p
      v-if="rows.some(row => row.value)"
      class="text-body-small text-n-amber-11"
    >
      {{ $t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.ONE_TIME') }}
    </p>
    <div
      v-for="row in rows"
      :key="row.key"
      class="rounded-lg border border-n-weak p-4"
    >
      <div
        class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
      >
        <div class="min-w-0">
          <p class="text-heading-3 text-n-slate-12">{{ row.label }}</p>
          <code
            v-if="row.value"
            class="mt-1 block break-all text-sm text-n-slate-12"
          >
            {{ row.value }}
          </code>
          <p v-else class="mt-1 text-body-small text-n-slate-11">
            {{
              $t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.MASKED', {
                suffix: row.suffix || '----',
              })
            }}
          </p>
        </div>
        <div class="flex flex-shrink-0 gap-2">
          <Button
            v-if="row.value"
            faded
            slate
            :label="$t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.COPY')"
            icon="i-lucide-copy"
            @click="emit('copy', row.value)"
          />
          <Button
            faded
            ruby
            :label="$t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.ROTATE')"
            icon="i-lucide-refresh-cw"
            @click="emit('rotate', row.key)"
          />
        </div>
      </div>
    </div>
    <div
      class="flex flex-col items-start gap-3 border-t border-n-weak pt-5 sm:flex-row sm:items-center sm:justify-between"
    >
      <p class="max-w-2xl text-body-small text-n-slate-11">
        {{ $t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.DISCONNECT_HELP') }}
      </p>
      <Button
        faded
        ruby
        icon="i-lucide-unplug"
        :is-loading="isDisconnecting"
        :disabled="isDisconnecting"
        :label="$t('INTEGRATION_APPS.OPENJARVIS.ACTIONS.DISCONNECT')"
        @click="emit('disconnect')"
      />
    </div>
  </section>
</template>
