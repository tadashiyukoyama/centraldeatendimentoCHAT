<script setup>
import Button from 'dashboard/components-next/button/Button.vue';
import Label from 'dashboard/components-next/label/Label.vue';

defineProps({
  deliveries: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
});

defineEmits(['refresh']);

const statusColor = status => {
  if (status === 'delivered') return 'teal';
  if (status === 'failed') return 'ruby';
  if (status === 'delivering') return 'amber';
  return 'slate';
};

const formatDate = value => (value ? new Date(value).toLocaleString() : '—');
</script>

<template>
  <section
    class="flex flex-col gap-4 p-5 outline outline-1 outline-n-container bg-n-card rounded-xl"
  >
    <div class="flex items-center justify-between gap-3">
      <h2 class="text-heading-2 text-n-slate-12">
        {{ $t('INTEGRATION_APPS.OPENJARVIS.DELIVERIES.TITLE') }}
      </h2>
      <Button
        faded
        slate
        size="sm"
        icon="i-lucide-refresh-cw"
        :is-loading="isLoading"
        :label="$t('INTEGRATION_APPS.OPENJARVIS.ACTIONS.REFRESH')"
        @click="$emit('refresh')"
      />
    </div>
    <p
      v-if="!deliveries.length"
      class="py-5 text-center text-body-main text-n-slate-11"
    >
      {{ $t('INTEGRATION_APPS.OPENJARVIS.DELIVERIES.EMPTY') }}
    </p>
    <div v-else class="overflow-x-auto">
      <table class="w-full min-w-[640px] text-left">
        <thead class="text-label-small text-n-slate-11">
          <tr>
            <th scope="col" class="px-3 py-2">
              {{ $t('INTEGRATION_APPS.OPENJARVIS.DELIVERIES.EVENT') }}
            </th>
            <th scope="col" class="px-3 py-2">
              {{ $t('INTEGRATION_APPS.OPENJARVIS.DELIVERIES.STATUS') }}
            </th>
            <th scope="col" class="px-3 py-2">
              {{ $t('INTEGRATION_APPS.OPENJARVIS.DELIVERIES.ATTEMPTS') }}
            </th>
            <th scope="col" class="px-3 py-2">
              {{ $t('INTEGRATION_APPS.OPENJARVIS.DELIVERIES.TIME') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak">
          <tr v-for="delivery in deliveries" :key="delivery.delivery_id">
            <td class="px-3 py-3">
              <code class="text-sm">{{ delivery.event_name }}</code>
            </td>
            <td class="px-3 py-3">
              <Label
                compact
                :label="delivery.status"
                :color="statusColor(delivery.status)"
              />
            </td>
            <td class="px-3 py-3 text-body-main text-n-slate-12">
              {{ delivery.attempts }}
            </td>
            <td class="px-3 py-3 text-body-small text-n-slate-11">
              {{ formatDate(delivery.created_at) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
