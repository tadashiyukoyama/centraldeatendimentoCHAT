<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import OpenJarvisAPI from 'dashboard/api/integrations/openJarvis';
import Button from 'dashboard/components-next/button/Button.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import OpenJarvisConnectionStatus from './OpenJarvis/OpenJarvisConnectionStatus.vue';
import OpenJarvisAccessForm from './OpenJarvis/OpenJarvisAccessForm.vue';
import OpenJarvisCredentials from './OpenJarvis/OpenJarvisCredentials.vue';
import OpenJarvisDeliveries from './OpenJarvis/OpenJarvisDeliveries.vue';

const SCOPES = [
  'inboxes:read',
  'conversations:read',
  'messages:read',
  'messages:write',
  'contacts:read',
  'contacts:write',
  'conversations:write',
  'diagnostics:read',
];

const SUBSCRIPTIONS = [
  'message.created',
  'message.updated',
  'conversation.created',
  'conversation.updated',
  'conversation.status_changed',
  'contact.created',
  'contact.updated',
];
const BLOCKED_ENDPOINT_HOSTS = ['chatwoot.com', 'chatwoot.help', 'chwt.app'];

const emptyForm = () => ({
  endpoint_url: '',
  service_user_id: '',
  allowed_inbox_ids: [],
  scopes: [...SCOPES],
  subscriptions: [...SUBSCRIPTIONS],
  webhooks_enabled: false,
});

const store = useStore();
const { t } = useI18n();

const isLoading = ref(true);
const isSaving = ref(false);
const isTesting = ref(false);
const isDisconnecting = ref(false);
const isLoadingDeliveries = ref(false);
const connection = ref({
  configured: false,
  status: 'not_configured',
  settings: emptyForm(),
});
const form = ref(emptyForm());
const enabled = ref(true);
const oneTimeCredentials = ref({});
const deliveries = ref([]);
const confirmDialog = ref(null);
const disconnectDialog = ref(null);

const agents = computed(() =>
  (store.getters['agents/getAgents'] || []).map(agent => ({
    value: agent.id,
    label: `${agent.name} (${agent.email})`,
  }))
);

const inboxes = computed(() => store.getters['inboxes/getInboxes'] || []);

const endpointIsValid = value => {
  if (!value) return true;
  try {
    const endpoint = new URL(value);
    const hostname = endpoint.hostname.toLowerCase().replace(/\.$/, '');
    const usesBlockedHost = BLOCKED_ENDPOINT_HOSTS.some(
      host => hostname === host || hostname.endsWith(`.${host}`)
    );
    return (
      endpoint.protocol === 'https:' &&
      hostname &&
      !usesBlockedHost &&
      !endpoint.username &&
      !endpoint.password &&
      !endpoint.search &&
      !endpoint.hash
    );
  } catch {
    return false;
  }
};

const isValid = computed(() => {
  const endpoint = form.value.endpoint_url.trim();
  return (
    form.value.service_user_id &&
    form.value.allowed_inbox_ids.length > 0 &&
    form.value.scopes.length > 0 &&
    endpointIsValid(endpoint) &&
    (!form.value.webhooks_enabled || endpoint)
  );
});

const applyConnection = payload => {
  connection.value = payload;
  enabled.value = payload.configured ? payload.enabled : true;
  form.value = { ...emptyForm(), ...(payload.settings || {}) };
  if (payload.credentials) oneTimeCredentials.value = payload.credentials;
};

const errorMessage = error =>
  error.response?.data?.error?.message ||
  error.response?.data?.message ||
  t('INTEGRATION_APPS.OPENJARVIS.ALERTS.SAVE_FAILED');

const loadDeliveries = async () => {
  if (!connection.value.configured) return;
  isLoadingDeliveries.value = true;
  try {
    const { data } = await OpenJarvisAPI.getDeliveries();
    deliveries.value = data.data || [];
  } finally {
    isLoadingDeliveries.value = false;
  }
};

const load = async () => {
  isLoading.value = true;
  try {
    const [, , response] = await Promise.all([
      store.dispatch('agents/get'),
      store.dispatch('inboxes/get'),
      OpenJarvisAPI.get(),
    ]);
    applyConnection(response.data);
    await loadDeliveries();
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isLoading.value = false;
  }
};

const save = async () => {
  isSaving.value = true;
  try {
    const { data } = await OpenJarvisAPI.update({
      enabled: enabled.value,
      openjarvis: form.value,
    });
    applyConnection(data);
    await store.dispatch('integrations/get');
    useAlert(t('INTEGRATION_APPS.OPENJARVIS.ALERTS.SAVED'));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSaving.value = false;
  }
};

const testConnection = async () => {
  isTesting.value = true;
  try {
    const { data } = await OpenJarvisAPI.testConnection();
    applyConnection(data);
    useAlert(t('INTEGRATION_APPS.OPENJARVIS.ALERTS.CONNECTED'));
  } catch (error) {
    if (error.response?.data) applyConnection(error.response.data);
    useAlert(errorMessage(error));
  } finally {
    isTesting.value = false;
  }
};

const copyCredential = async value => {
  await navigator.clipboard.writeText(value);
  useAlert(t('INTEGRATION_APPS.OPENJARVIS.ALERTS.COPIED'));
};

const requestRotation = async type => {
  const confirmed = await confirmDialog.value.showConfirmation();
  if (!confirmed) return;

  try {
    const request =
      type === 'access_token'
        ? OpenJarvisAPI.rotateAccessToken()
        : OpenJarvisAPI.rotateWebhookSecret();
    const { data } = await request;
    oneTimeCredentials.value = {
      ...oneTimeCredentials.value,
      [type]: data.credential.value,
    };
    await load();
    oneTimeCredentials.value[type] = data.credential.value;
    useAlert(t('INTEGRATION_APPS.OPENJARVIS.ALERTS.ROTATED'));
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

const disconnect = async () => {
  const confirmed = await disconnectDialog.value.showConfirmation();
  if (!confirmed) return;

  isDisconnecting.value = true;
  try {
    const { data } = await OpenJarvisAPI.disconnect();
    oneTimeCredentials.value = {};
    deliveries.value = [];
    applyConnection(data);
    await store.dispatch('integrations/get');
    useAlert(t('INTEGRATION_APPS.OPENJARVIS.ALERTS.DISCONNECTED'));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isDisconnecting.value = false;
  }
};

onMounted(load);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('INTEGRATION_APPS.FETCHING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('INTEGRATION_APPS.OPENJARVIS.HEADER')"
        :description="$t('INTEGRATION_APPS.OPENJARVIS.DESCRIPTION')"
        :back-button-label="$t('INTEGRATION_SETTINGS.HEADER')"
      >
        <template v-if="connection.configured" #actions>
          <Button
            faded
            blue
            icon="i-lucide-plug-zap"
            :label="$t('INTEGRATION_APPS.OPENJARVIS.ACTIONS.TEST')"
            :is-loading="isTesting"
            :disabled="isTesting || !connection.settings.endpoint_url"
            @click="testConnection"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div class="mx-auto flex w-full max-w-6xl flex-col gap-5 pb-10">
        <OpenJarvisConnectionStatus
          :status="connection.status"
          :last-test-at="connection.settings.last_test_at"
          :last-test-error="connection.settings.last_test_error"
        />
        <OpenJarvisAccessForm
          v-model="form"
          v-model:enabled="enabled"
          :agents="agents"
          :inboxes="inboxes"
          :scope-options="SCOPES"
          :subscription-options="SUBSCRIPTIONS"
          :is-saving="isSaving"
          :is-valid="isValid"
          @save="save"
        />
        <OpenJarvisCredentials
          v-if="connection.configured"
          :api-base-url="connection.api_base_url"
          :credentials="oneTimeCredentials"
          :metadata="connection.credential_metadata"
          :is-disconnecting="isDisconnecting"
          @copy="copyCredential"
          @rotate="requestRotation"
          @disconnect="disconnect"
        />
        <OpenJarvisDeliveries
          v-if="connection.configured"
          :deliveries="deliveries"
          :is-loading="isLoadingDeliveries"
          @refresh="loadDeliveries"
        />
      </div>
      <woot-confirm-modal
        ref="confirmDialog"
        :title="$t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.ROTATE_TITLE')"
        :description="
          $t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.ROTATE_DESCRIPTION')
        "
      />
      <woot-confirm-modal
        ref="disconnectDialog"
        :title="$t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.DISCONNECT_TITLE')"
        :description="
          $t('INTEGRATION_APPS.OPENJARVIS.CREDENTIALS.DISCONNECT_DESCRIPTION')
        "
      />
    </template>
  </SettingsLayout>
</template>
