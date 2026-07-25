<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import WhatsappChannel from 'dashboard/api/channel/whatsappChannel';
import NextButton from 'next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  inbox: { type: Object, required: true },
});

const POLL_INTERVAL_MS = 2000;

const { t } = useI18n();
const store = useStore();
const status = ref('');
const qrCode = ref('');
const connectedNumber = ref('');
const profileName = ref('');
const isRefreshing = ref(false);
const isReconnecting = ref(false);
const isDisconnecting = ref(false);
let pollTimer;
let refreshConnection = () => {};

const publicId = computed(
  () => props.inbox.evolution_connection?.public_id || ''
);
const canManageConnection = computed(() => Boolean(publicId.value));
const isWaitingForConnection = computed(() =>
  ['waiting_qr', 'connecting'].includes(status.value)
);
const qrCodeSource = computed(() => {
  if (!qrCode.value) return '';
  return qrCode.value.startsWith('data:')
    ? qrCode.value
    : `data:image/png;base64,${qrCode.value}`;
});
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

const initializeState = () => {
  const connection = props.inbox.evolution_connection || {};
  status.value = connection.status || '';
  connectedNumber.value = connection.connected_number || '';
  profileName.value = connection.profile_name || '';
};

const stopPolling = () => {
  if (pollTimer) {
    clearTimeout(pollTimer);
    pollTimer = undefined;
  }
};

const schedulePoll = () => {
  stopPolling();
  pollTimer = setTimeout(
    () => refreshConnection({ quiet: true }),
    POLL_INTERVAL_MS
  );
};

const applyConnectionState = data => {
  status.value = data.status || status.value;
  qrCode.value = data.qr_code || qrCode.value;
  connectedNumber.value = data.connected_number || connectedNumber.value;
  profileName.value = data.profile_name || profileName.value;

  if (isWaitingForConnection.value) {
    schedulePoll();
  } else {
    stopPolling();
    qrCode.value = '';
  }
};

refreshConnection = async ({ quiet = false } = {}) => {
  if (!publicId.value) return;

  if (!quiet) isRefreshing.value = true;
  try {
    const { data } = await WhatsappChannel.getEvolutionProvisioning(
      publicId.value
    );
    applyConnectionState(data);
    if (!quiet) await store.dispatch('inboxes/get');
  } catch (error) {
    stopPolling();
    status.value = error.response?.data?.status || status.value;
    if (!quiet) {
      useAlert(
        parseAPIErrorResponse(error) ||
          t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.REFRESH_ERROR')
      );
    }
  } finally {
    if (!quiet) isRefreshing.value = false;
  }
};

const reconnect = async () => {
  if (!publicId.value) return;

  stopPolling();
  isReconnecting.value = true;
  qrCode.value = '';
  try {
    const { data } = await WhatsappChannel.reconnectEvolutionProvisioning(
      publicId.value
    );
    applyConnectionState(data);
    await store.dispatch('inboxes/get');
  } catch (error) {
    status.value = error.response?.data?.status || 'failed';
    useAlert(
      parseAPIErrorResponse(error) ||
        t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.RECONNECT_ERROR')
    );
  } finally {
    isReconnecting.value = false;
  }
};

const disconnect = async () => {
  if (!publicId.value) return;

  stopPolling();
  isDisconnecting.value = true;
  try {
    const { data } = await WhatsappChannel.disconnectEvolutionProvisioning(
      publicId.value
    );
    applyConnectionState(data);
    await store.dispatch('inboxes/get');
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.DISCONNECT_SUCCESS'));
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) ||
        t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.DISCONNECT_ERROR')
    );
  } finally {
    isDisconnecting.value = false;
  }
};

watch(() => props.inbox.evolution_connection, initializeState, {
  deep: true,
  immediate: true,
});
onMounted(() => refreshConnection({ quiet: true }));
onBeforeUnmount(stopPolling);
</script>

<template>
  <div class="flex max-w-2xl flex-col gap-6 py-6">
    <div class="flex items-start gap-3">
      <div
        class="flex size-11 shrink-0 items-center justify-center rounded-full bg-n-alpha-2"
      >
        <Icon icon="i-woot-whatsapp" class="size-6 text-n-slate-10" />
      </div>
      <div>
        <h3 class="mb-1 text-base font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.SETTINGS_TITLE') }}
        </h3>
        <p class="text-sm leading-6 text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.SETTINGS_DESCRIPTION') }}
        </p>
      </div>
    </div>

    <div class="rounded-xl border border-n-weak bg-n-alpha-1 p-5">
      <p class="text-sm font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS_TITLE') }}
      </p>
      <p class="mt-1 text-sm text-n-slate-11">{{ statusText }}</p>
      <p v-if="connectedNumber" class="mt-2 text-sm text-n-slate-11">
        {{ connectedNumber }}
        <span v-if="profileName" class="ml-2">{{ profileName }}</span>
      </p>
    </div>

    <div
      v-if="qrCodeSource && isWaitingForConnection"
      class="flex flex-col items-start gap-3"
    >
      <p class="text-sm font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.SCAN_TITLE') }}
      </p>
      <div class="rounded-xl border border-n-weak bg-white p-4">
        <img
          :src="qrCodeSource"
          class="size-64"
          :alt="$t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_ALT')"
        />
      </div>
    </div>

    <div v-if="canManageConnection" class="flex flex-wrap gap-3">
      <NextButton
        v-if="status !== 'connected'"
        solid
        blue
        :is-loading="isReconnecting"
        :disabled="isDisconnecting"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.RECONNECT')"
        @click="reconnect"
      />
      <NextButton
        v-if="status === 'connected'"
        outline
        ruby
        :is-loading="isDisconnecting"
        :disabled="isReconnecting"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.DISCONNECT')"
        @click="disconnect"
      />
      <NextButton
        outline
        :is-loading="isRefreshing"
        :disabled="isReconnecting || isDisconnecting"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.REFRESH')"
        @click="refreshConnection()"
      />
    </div>
  </div>
</template>
