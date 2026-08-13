<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { getInboxIconByType, INBOX_TYPES } from 'dashboard/helper/inbox';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import LiveChatCampaignDetails from './LiveChatCampaignDetails.vue';
import SMSCampaignDetails from './SMSCampaignDetails.vue';

const props = defineProps({
  title: {
    type: String,
    default: '',
  },
  message: {
    type: String,
    default: '',
  },
  isLiveChatType: {
    type: Boolean,
    default: false,
  },
  isEnabled: {
    type: Boolean,
    default: false,
  },
  status: {
    type: String,
    default: '',
  },
  sender: {
    type: Object,
    default: null,
  },
  inbox: {
    type: Object,
    default: null,
  },
  scheduledAt: {
    type: Number,
    default: 0,
  },
  deliveryCounts: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['edit', 'delete', 'view']);

const { t } = useI18n();

const STATUS_COMPLETED = 'completed';
const STATUS_PROCESSING = 'processing';

const { formatMessage } = useMessageFormatter();

const isActive = computed(() =>
  props.isLiveChatType ? props.isEnabled : props.status !== STATUS_COMPLETED
);

const statusTextColor = computed(() => ({
  'text-n-teal-11': isActive.value,
  'text-n-slate-12': !isActive.value,
}));

const campaignStatus = computed(() => {
  if (props.isLiveChatType) {
    return props.isEnabled
      ? t('CAMPAIGN.LIVE_CHAT.CARD.STATUS.ENABLED')
      : t('CAMPAIGN.LIVE_CHAT.CARD.STATUS.DISABLED');
  }

  if (props.status === STATUS_COMPLETED) {
    return t('CAMPAIGN.SMS.CARD.STATUS.COMPLETED');
  }

  if (props.status === STATUS_PROCESSING) {
    return t('CAMPAIGN.SMS.CARD.STATUS.PROCESSING');
  }

  return t('CAMPAIGN.SMS.CARD.STATUS.SCHEDULED');
});

const inboxName = computed(() => props.inbox?.name || '');
const isEmailCampaign = computed(
  () => props.inbox?.channel_type === INBOX_TYPES.EMAIL
);
const isWhatsAppCampaign = computed(
  () => props.inbox?.channel_type === INBOX_TYPES.WHATSAPP
);
const hasTrackedDeliveries = computed(
  () =>
    (isEmailCampaign.value || isWhatsAppCampaign.value) &&
    Object.values(props.deliveryCounts).some(count => Number(count) > 0)
);

const deliveryCountParams = computed(() => ({
  pending:
    Number(props.deliveryCounts.pending || 0) +
    Number(props.deliveryCounts.processing || 0),
  queued: Number(props.deliveryCounts.queued || 0),
  skipped: Number(props.deliveryCounts.skipped || 0),
  failed: Number(props.deliveryCounts.failed || 0),
}));

const deliveryCountsText = computed(() =>
  isEmailCampaign.value
    ? t('CAMPAIGN.EMAIL.CARD.DELIVERY_COUNTS', deliveryCountParams.value)
    : t('CAMPAIGN.WHATSAPP.CARD.DELIVERY_COUNTS', deliveryCountParams.value)
);

const inboxIcon = computed(() => {
  const { medium, channel_type: type } = props.inbox || {};
  return getInboxIconByType(type, medium);
});
</script>

<template>
  <CardLayout layout="row">
    <div
      class="flex flex-col items-start justify-between flex-1 min-w-0 gap-2"
      :class="{ 'cursor-pointer': isWhatsAppCampaign }"
      :role="isWhatsAppCampaign ? 'button' : undefined"
      :tabindex="isWhatsAppCampaign ? 0 : undefined"
      @click="isWhatsAppCampaign && emit('view')"
      @keydown.enter="isWhatsAppCampaign && emit('view')"
      @keydown.space.prevent="isWhatsAppCampaign && emit('view')"
    >
      <div class="flex justify-between gap-3 w-fit">
        <span
          class="text-base font-medium capitalize text-n-slate-12 line-clamp-1"
        >
          {{ title }}
        </span>
        <span
          class="text-xs font-medium inline-flex items-center h-6 px-2 py-0.5 rounded-md bg-n-alpha-2"
          :class="statusTextColor"
        >
          {{ campaignStatus }}
        </span>
      </div>
      <div
        v-dompurify-html="formatMessage(message, false, false, false)"
        class="text-sm text-n-slate-11 line-clamp-1 [&>p]:mb-0 h-6"
      />
      <div class="flex items-center w-full h-6 gap-2 overflow-hidden">
        <LiveChatCampaignDetails
          v-if="isLiveChatType"
          :sender="sender"
          :inbox-name="inboxName"
          :inbox-icon="inboxIcon"
        />
        <SMSCampaignDetails
          v-else
          :inbox-name="inboxName"
          :inbox-icon="inboxIcon"
          :scheduled-at="scheduledAt"
        />
        <span
          v-if="hasTrackedDeliveries"
          class="flex-1 text-xs truncate text-n-slate-11"
        >
          {{ deliveryCountsText }}
        </span>
      </div>
    </div>
    <div class="flex items-center justify-end gap-2">
      <Button
        v-if="isWhatsAppCampaign"
        variant="faded"
        color="slate"
        size="sm"
        icon="i-lucide-activity"
        :label="t('CAMPAIGN.WHATSAPP.CARD.TRACK')"
        @click.stop="emit('view')"
      />
      <Button
        v-if="isLiveChatType"
        variant="faded"
        size="sm"
        color="slate"
        icon="i-lucide-sliders-vertical"
        @click.stop="emit('edit')"
      />
      <Button
        variant="faded"
        color="ruby"
        size="sm"
        icon="i-lucide-trash"
        @click.stop="emit('delete')"
      />
    </div>
  </CardLayout>
</template>
