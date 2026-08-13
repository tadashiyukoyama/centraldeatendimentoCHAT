<script setup>
import { computed, onBeforeUnmount, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import CampaignsAPI from 'dashboard/api/campaigns';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  campaign: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close', 'updated']);
const { t, locale } = useI18n();

const dialogRef = ref(null);
const payload = ref(null);
const isLoading = ref(false);
const errorMessage = ref('');
const currentPage = ref(1);
let pollTimer = null;

const progress = computed(() => payload.value?.progress || {});
const deliveries = computed(() => payload.value?.deliveries || []);
const meta = computed(() => payload.value?.meta || {});
const phase = computed(() => progress.value.phase || 'in_progress');
const isQueuePending = computed(() =>
  ['scheduled', 'preparing'].includes(phase.value)
);
const displayTotal = computed(() =>
  isQueuePending.value
    ? Number(progress.value.planned_total || 0)
    : Number(progress.value.total || 0)
);

const sentCount = computed(
  () =>
    Number(progress.value.sent || 0) +
    Number(progress.value.delivered || 0) +
    Number(progress.value.read || 0)
);

const errorCount = computed(
  () => Number(progress.value.failed || 0) + Number(progress.value.skipped || 0)
);

const scheduledCount = computed(() => {
  const queued =
    Number(progress.value.pending || 0) +
    Number(progress.value.processing || 0) +
    Number(progress.value.queued || 0);

  return isQueuePending.value ? displayTotal.value : queued;
});

const dateFormatter = computed(
  () =>
    new Intl.DateTimeFormat(locale.value, {
      dateStyle: 'short',
      timeStyle: 'short',
    })
);

const formatDate = value =>
  value ? dateFormatter.value.format(new Date(value)) : '—';

const queueState = computed(() => {
  if (phase.value === 'scheduled') {
    return {
      icon: 'i-lucide-calendar-clock',
      title: t('CAMPAIGN.WHATSAPP.PROGRESS.SCHEDULED_TITLE'),
      description: t('CAMPAIGN.WHATSAPP.PROGRESS.SCHEDULED_DESCRIPTION', {
        count: displayTotal.value,
        date: formatDate(payload.value?.campaign?.scheduled_at),
      }),
    };
  }

  if (phase.value === 'preparing') {
    return {
      icon: 'i-lucide-loader-circle animate-spin',
      title: t('CAMPAIGN.WHATSAPP.PROGRESS.PREPARING_TITLE'),
      description: t('CAMPAIGN.WHATSAPP.PROGRESS.PREPARING_DESCRIPTION', {
        count: displayTotal.value,
      }),
    };
  }

  return {
    icon: 'i-lucide-users-round',
    title: t('CAMPAIGN.WHATSAPP.PROGRESS.EMPTY_TITLE'),
    description: t('CAMPAIGN.WHATSAPP.PROGRESS.EMPTY_DESCRIPTION'),
  };
});

const statusLabels = computed(() => ({
  pending: t('CAMPAIGN.WHATSAPP.PROGRESS.STATUS.PENDING'),
  processing: t('CAMPAIGN.WHATSAPP.PROGRESS.STATUS.PROCESSING'),
  queued: t('CAMPAIGN.WHATSAPP.PROGRESS.STATUS.QUEUED'),
  sent: t('CAMPAIGN.WHATSAPP.PROGRESS.STATUS.SENT'),
  delivered: t('CAMPAIGN.WHATSAPP.PROGRESS.STATUS.DELIVERED'),
  read: t('CAMPAIGN.WHATSAPP.PROGRESS.STATUS.READ'),
  skipped: t('CAMPAIGN.WHATSAPP.PROGRESS.STATUS.SKIPPED'),
  failed: t('CAMPAIGN.WHATSAPP.PROGRESS.STATUS.FAILED'),
}));

const statusLabel = status => statusLabels.value[status] || status;

const statusClass = status => ({
  'bg-n-blue-3 text-n-blue-11': ['pending', 'processing', 'queued'].includes(
    status
  ),
  'bg-n-teal-3 text-n-teal-11': ['sent', 'delivered', 'read'].includes(status),
  'bg-n-ruby-3 text-n-ruby-11': ['failed', 'skipped'].includes(status),
});

const loadProgress = async ({ quiet = false } = {}) => {
  if (!props.campaign?.id) return;
  if (!quiet) isLoading.value = true;
  errorMessage.value = '';

  try {
    const { data } = await CampaignsAPI.getDeliveries(props.campaign.id, {
      page: currentPage.value,
      per_page: 50,
    });
    payload.value = data;
    emit('updated');
  } catch (error) {
    errorMessage.value = t('CAMPAIGN.WHATSAPP.PROGRESS.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

const schedulePoll = () => {
  window.clearInterval(pollTimer);
  pollTimer = window.setInterval(() => loadProgress({ quiet: true }), 5000);
};

const open = async () => {
  currentPage.value = 1;
  payload.value = null;
  dialogRef.value?.open();
  await loadProgress();
  schedulePoll();
};

const close = () => {
  window.clearInterval(pollTimer);
  dialogRef.value?.close();
};

const changePage = async page => {
  currentPage.value = page;
  await loadProgress();
};

onBeforeUnmount(() => window.clearInterval(pollTimer));
defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="3xl"
    position="top"
    overflow-y-auto
    :title="
      t('CAMPAIGN.WHATSAPP.PROGRESS.TITLE', {
        title: campaign?.title || '',
      })
    "
    :show-confirm-button="false"
    :cancel-button-label="t('CAMPAIGN.WHATSAPP.PROGRESS.CLOSE')"
    @close="emit('close')"
  >
    <div
      v-if="isLoading && !payload"
      class="flex min-h-64 items-center justify-center"
    >
      <Spinner />
    </div>

    <div
      v-else-if="errorMessage && !payload"
      class="flex min-h-56 flex-col items-center justify-center gap-3 text-center"
      role="alert"
    >
      <span class="i-lucide-circle-alert size-8 text-n-ruby-10" />
      <p class="mb-0 text-sm text-n-slate-11">{{ errorMessage }}</p>
      <Button
        color="slate"
        variant="outline"
        icon="i-lucide-refresh-cw"
        :label="t('CAMPAIGN.WHATSAPP.PROGRESS.RETRY')"
        @click="loadProgress()"
      />
    </div>

    <div v-else class="flex max-h-[70vh] flex-col gap-5 overflow-y-auto pr-1">
      <section class="flex flex-col gap-3" aria-live="polite">
        <div class="flex items-end justify-between gap-3">
          <div>
            <p
              class="mb-1 text-xs font-medium uppercase tracking-wide text-n-slate-10"
            >
              {{ t('CAMPAIGN.WHATSAPP.PROGRESS.COMPLETION') }}
            </p>
            <p class="mb-0 text-2xl font-semibold tabular-nums text-n-slate-12">
              {{
                t('CAMPAIGN.WHATSAPP.PROGRESS.PERCENTAGE', {
                  value: progress.percentage || 0,
                })
              }}
            </p>
          </div>
          <p class="mb-0 text-xs text-n-slate-11">
            {{ t('CAMPAIGN.WHATSAPP.PROGRESS.AUTO_REFRESH') }}
          </p>
        </div>
        <div
          class="h-2 overflow-hidden rounded-full bg-n-alpha-3"
          role="progressbar"
          :aria-valuenow="progress.percentage || 0"
          aria-valuemin="0"
          aria-valuemax="100"
          :aria-label="t('CAMPAIGN.WHATSAPP.PROGRESS.COMPLETION')"
        >
          <div
            class="h-full rounded-full bg-n-brand transition-[width] duration-300"
            :style="{ width: `${progress.percentage || 0}%` }"
          />
        </div>
      </section>

      <section class="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div class="rounded-lg border border-n-weak bg-n-alpha-2 p-3">
          <p class="mb-1 text-xs text-n-slate-11">
            {{ t('CAMPAIGN.WHATSAPP.PROGRESS.TOTAL') }}
          </p>
          <p class="mb-0 text-xl font-semibold tabular-nums text-n-slate-12">
            {{ displayTotal }}
          </p>
        </div>
        <div class="rounded-lg border border-n-weak bg-n-alpha-2 p-3">
          <p class="mb-1 text-xs text-n-slate-11">
            {{ t('CAMPAIGN.WHATSAPP.PROGRESS.SENT') }}
          </p>
          <p class="mb-0 text-xl font-semibold tabular-nums text-n-teal-11">
            {{ sentCount }}
          </p>
        </div>
        <div class="rounded-lg border border-n-weak bg-n-alpha-2 p-3">
          <p class="mb-1 text-xs text-n-slate-11">
            {{ t('CAMPAIGN.WHATSAPP.PROGRESS.SCHEDULED') }}
          </p>
          <p class="mb-0 text-xl font-semibold tabular-nums text-n-blue-11">
            {{ scheduledCount }}
          </p>
        </div>
        <div class="rounded-lg border border-n-weak bg-n-alpha-2 p-3">
          <p class="mb-1 text-xs text-n-slate-11">
            {{ t('CAMPAIGN.WHATSAPP.PROGRESS.ERRORS') }}
          </p>
          <p class="mb-0 text-xl font-semibold tabular-nums text-n-ruby-11">
            {{ errorCount }}
          </p>
        </div>
      </section>

      <p v-if="progress.next_delivery_at" class="mb-0 text-sm text-n-slate-11">
        {{
          t('CAMPAIGN.WHATSAPP.PROGRESS.NEXT_DELIVERY', {
            date: formatDate(progress.next_delivery_at),
          })
        }}
      </p>

      <section class="flex flex-col gap-2">
        <h4 class="mb-0 text-sm font-semibold text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP.PROGRESS.DELIVERIES') }}
        </h4>

        <div
          v-if="!deliveries.length"
          class="flex flex-col items-center rounded-lg border border-dashed border-n-weak p-6 text-center"
          :class="{ 'bg-n-blue-2': isQueuePending }"
        >
          <span
            class="mb-3 size-6"
            :class="[
              queueState.icon,
              isQueuePending ? 'text-n-blue-10' : 'text-n-slate-10',
            ]"
            aria-hidden="true"
          />
          <p class="mb-1 text-sm font-medium text-n-slate-12">
            {{ queueState.title }}
          </p>
          <p class="mb-0 text-xs leading-5 text-n-slate-11">
            {{ queueState.description }}
          </p>
        </div>

        <div v-else class="overflow-x-auto rounded-lg border border-n-weak">
          <table class="w-full min-w-[680px] border-collapse text-left text-sm">
            <thead class="bg-n-alpha-2 text-xs text-n-slate-11">
              <tr>
                <th class="px-3 py-2 font-medium">
                  {{ t('CAMPAIGN.WHATSAPP.PROGRESS.CONTACT') }}
                </th>
                <th class="px-3 py-2 font-medium">
                  {{ t('CAMPAIGN.WHATSAPP.PROGRESS.STATUS_LABEL') }}
                </th>
                <th class="px-3 py-2 font-medium">
                  {{ t('CAMPAIGN.WHATSAPP.PROGRESS.SCHEDULE') }}
                </th>
                <th class="px-3 py-2 font-medium">
                  {{ t('CAMPAIGN.WHATSAPP.PROGRESS.DETAIL') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="delivery in deliveries"
                :key="delivery.id"
                class="border-t border-n-weak"
              >
                <td class="px-3 py-3">
                  <p class="mb-0 font-medium text-n-slate-12">
                    {{ delivery.contact.name || '—' }}
                  </p>
                  <p class="mb-0 text-xs text-n-slate-11">
                    {{ delivery.contact.phone_number || '—' }}
                  </p>
                </td>
                <td class="px-3 py-3">
                  <span
                    class="inline-flex rounded-md px-2 py-1 text-xs font-medium"
                    :class="statusClass(delivery.status)"
                  >
                    {{ statusLabel(delivery.status) }}
                  </span>
                </td>
                <td class="px-3 py-3 tabular-nums text-n-slate-11">
                  {{ formatDate(delivery.scheduled_for) }}
                </td>
                <td class="max-w-64 px-3 py-3 text-xs text-n-slate-11">
                  {{ delivery.error_message || '—' }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div
          v-if="meta.total_pages > 1"
          class="flex items-center justify-between gap-3 pt-2"
        >
          <Button
            color="slate"
            variant="outline"
            size="sm"
            icon="i-lucide-chevron-left"
            :label="t('CAMPAIGN.WHATSAPP.PROGRESS.PREVIOUS')"
            :disabled="meta.current_page <= 1"
            @click="changePage(meta.current_page - 1)"
          />
          <span class="text-xs tabular-nums text-n-slate-11">
            {{
              t('CAMPAIGN.WHATSAPP.PROGRESS.PAGE', {
                current: meta.current_page,
                total: meta.total_pages,
              })
            }}
          </span>
          <Button
            color="slate"
            variant="outline"
            size="sm"
            icon="i-lucide-chevron-right"
            trailing-icon
            :label="t('CAMPAIGN.WHATSAPP.PROGRESS.NEXT')"
            :disabled="meta.current_page >= meta.total_pages"
            @click="changePage(meta.current_page + 1)"
          />
        </div>
      </section>
    </div>
  </Dialog>
</template>
