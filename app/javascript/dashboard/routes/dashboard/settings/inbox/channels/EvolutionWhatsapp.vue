<script setup>
import { computed, onBeforeUnmount, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import WhatsappChannel from 'dashboard/api/channel/whatsappChannel';
import NextButton from 'next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';

const POLL_INTERVAL_MS = 2000;

const router = useRouter();
const { t } = useI18n();

const inboxName = ref('');
const publicId = ref('');
const qrCode = ref('');
const status = ref('');
const connectedNumber = ref('');
const isCreating = ref(false);
const isCancelling = ref(false);
let pollTimer;
let pollProvisioning = () => {};

const isWaitingForConnection = computed(() =>
  ['waiting_qr', 'connecting'].includes(status.value)
);
const qrCodeSource = computed(() => {
  if (!qrCode.value) return '';
  return qrCode.value.startsWith('data:')
    ? qrCode.value
    : `data:image/png;base64,${qrCode.value}`;
});
const canSubmit = computed(
  () => inboxName.value.trim().length > 0 && !isCreating.value
);
const statusText = computed(() => {
  const statuses = {
    provisioning: t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS.PROVISIONING'),
    waiting_qr: t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS.WAITING_QR'),
    connecting: t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS.CONNECTING'),
    connected: t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS.CONNECTED'),
    disconnected: t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS.DISCONNECTED'),
    failed: t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS.FAILED'),
    deleting: t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS.DELETING'),
    deleted: t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS.DELETED'),
  };
  return statuses[status.value] || status.value;
});

const stopPolling = () => {
  if (pollTimer) {
    clearTimeout(pollTimer);
    pollTimer = undefined;
  }
};

const schedulePoll = () => {
  stopPolling();
  pollTimer = setTimeout(pollProvisioning, POLL_INTERVAL_MS);
};

const finishSetup = inboxId => {
  stopPolling();
  router.replace({
    name: 'settings_inboxes_add_agents',
    params: {
      page: 'new',
      inbox_id: inboxId,
    },
  });
};

const applyProvisioningState = data => {
  status.value = data.status;
  qrCode.value = data.qr_code || qrCode.value;
  connectedNumber.value = data.connected_number || '';

  if (data.inbox_id) {
    finishSetup(data.inbox_id);
    return;
  }

  if (isWaitingForConnection.value) {
    schedulePoll();
  } else {
    stopPolling();
  }
};

pollProvisioning = async () => {
  if (!publicId.value) return;

  try {
    const { data } = await WhatsappChannel.getEvolutionProvisioning(
      publicId.value
    );
    applyProvisioningState(data);
  } catch (error) {
    stopPolling();
    status.value = error.response?.data?.status || 'failed';
    useAlert(
      parseAPIErrorResponse(error) ||
        t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.ERROR')
    );
  }
};

const createProvisioning = async () => {
  if (!canSubmit.value) return;

  isCreating.value = true;
  try {
    const { data } = await WhatsappChannel.createEvolutionProvisioning({
      inbox_name: inboxName.value.trim(),
    });
    publicId.value = data.id;
    applyProvisioningState(data);
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) ||
        t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.ERROR')
    );
  } finally {
    isCreating.value = false;
  }
};

const cancelProvisioning = async () => {
  if (!publicId.value) return;

  stopPolling();
  isCancelling.value = true;
  try {
    await WhatsappChannel.deleteEvolutionProvisioning(publicId.value);
    publicId.value = '';
    qrCode.value = '';
    status.value = '';
    connectedNumber.value = '';
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) ||
        t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.CANCEL_ERROR')
    );
  } finally {
    isCancelling.value = false;
  }
};

onBeforeUnmount(stopPolling);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="flex items-start gap-3">
      <div
        class="flex size-11 shrink-0 items-center justify-center rounded-full bg-n-alpha-2"
      >
        <Icon icon="i-woot-whatsapp" class="size-6 text-n-slate-10" />
      </div>
      <div>
        <h3 class="mb-1 text-base font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.TITLE') }}
        </h3>
        <p class="text-sm leading-6 text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.DESCRIPTION') }}
        </p>
      </div>
    </div>

    <form
      v-if="!publicId"
      class="flex max-w-lg flex-col gap-4"
      @submit.prevent="createProvisioning"
    >
      <label>
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.LABEL') }}
        <input
          v-model="inboxName"
          type="text"
          maxlength="100"
          required
          :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.PLACEHOLDER')"
        />
      </label>
      <NextButton
        type="submit"
        solid
        blue
        :disabled="!canSubmit"
        :is-loading="isCreating"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.CREATE')"
      />
    </form>

    <div v-else class="flex max-w-lg flex-col items-start gap-4">
      <div
        v-if="qrCodeSource && isWaitingForConnection"
        class="rounded-xl border border-n-weak bg-white p-4"
      >
        <img
          :src="qrCodeSource"
          class="size-64"
          :alt="$t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_ALT')"
        />
      </div>

      <div>
        <p class="font-medium text-n-slate-12">
          {{
            isWaitingForConnection
              ? $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.SCAN_TITLE')
              : $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS_TITLE')
          }}
        </p>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ statusText }}
        </p>
        <p v-if="connectedNumber" class="mt-1 text-sm text-n-slate-11">
          {{ connectedNumber }}
        </p>
      </div>

      <NextButton
        v-if="isWaitingForConnection || status === 'failed'"
        outline
        ruby
        :is-loading="isCancelling"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.CANCEL')"
        @click="cancelProvisioning"
      />
    </div>
  </div>
</template>
