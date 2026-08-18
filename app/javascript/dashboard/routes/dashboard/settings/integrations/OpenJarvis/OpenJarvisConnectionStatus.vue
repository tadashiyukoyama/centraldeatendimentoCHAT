<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Label from 'dashboard/components-next/label/Label.vue';

const props = defineProps({
  status: { type: String, default: 'not_configured' },
  lastTestAt: { type: String, default: '' },
  lastTestError: { type: String, default: '' },
});

const { t, d } = useI18n();

const STATUS_KEYS = {
  not_configured: 'INTEGRATION_APPS.OPENJARVIS.STATUS.not_configured',
  awaiting_openjarvis: 'INTEGRATION_APPS.OPENJARVIS.STATUS.awaiting_openjarvis',
  not_tested: 'INTEGRATION_APPS.OPENJARVIS.STATUS.not_tested',
  connected: 'INTEGRATION_APPS.OPENJARVIS.STATUS.connected',
  unreachable: 'INTEGRATION_APPS.OPENJARVIS.STATUS.unreachable',
  disabled: 'INTEGRATION_APPS.OPENJARVIS.STATUS.disabled',
};

const color = computed(() => {
  if (props.status === 'connected') return 'teal';
  if (['unreachable', 'disabled'].includes(props.status)) return 'ruby';
  if (['awaiting_openjarvis', 'not_tested'].includes(props.status))
    return 'amber';
  return 'slate';
});

const label = computed(() =>
  t(STATUS_KEYS[props.status] || STATUS_KEYS.not_configured)
);

const formattedLastTest = computed(() =>
  props.lastTestAt ? d(new Date(props.lastTestAt), 'short') : ''
);
</script>

<template>
  <section
    class="flex flex-col gap-3 p-5 outline outline-1 outline-n-container bg-n-card rounded-xl"
    aria-live="polite"
  >
    <div class="flex flex-wrap items-center justify-between gap-3">
      <h2 class="text-heading-2 text-n-slate-12">
        {{ $t('INTEGRATION_APPS.OPENJARVIS.STATUS.TITLE') }}
      </h2>
      <Label :label="label" :color="color" />
    </div>
    <p v-if="formattedLastTest" class="text-body-small text-n-slate-11">
      {{
        $t('INTEGRATION_APPS.OPENJARVIS.STATUS.LAST_TEST', {
          date: formattedLastTest,
        })
      }}
    </p>
    <p v-if="lastTestError" class="text-body-small text-n-ruby-11">
      {{ lastTestError }}
    </p>
  </section>
</template>
