<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert, useTrack } from 'dashboard/composables';
import { CAMPAIGN_TYPES } from 'shared/constants/campaign.js';
import { CAMPAIGNS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events.js';

import WhatsAppCampaignForm from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignForm.vue';
import CampaignAudienceImportDialog from './CampaignAudienceImportDialog.vue';
import CampaignAudiencesAPI from 'dashboard/api/campaignAudiences';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();
const contactImportDialogRef = ref(null);
const campaignFormRef = ref(null);
const campaignAudiences = ref([]);
const isImportingAudience = ref(false);
let audiencePollTimer = null;

const addCampaign = async campaignDetails => {
  try {
    await store.dispatch('campaigns/create', campaignDetails);

    useTrack(CAMPAIGNS_EVENTS.CREATE_CAMPAIGN, {
      type: CAMPAIGN_TYPES.ONE_OFF,
    });

    useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    const errorMessage =
      error?.response?.data?.message ||
      error?.response?.data?.error ||
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
};

const handleSubmit = campaignDetails => {
  addCampaign(campaignDetails);
};

const handleClose = () => emit('close');

const handleOpenContactImport = () =>
  contactImportDialogRef.value?.dialogRef?.open();

const refreshCampaignAudiences = async () => {
  const { data } = await CampaignAudiencesAPI.get();
  campaignAudiences.value = data;
  return data;
};

const waitForAudienceImport = importId => {
  window.clearTimeout(audiencePollTimer);
  audiencePollTimer = window.setTimeout(async () => {
    try {
      const audiences = await refreshCampaignAudiences();
      const importedAudience = audiences.find(item => item.id === importId);
      if (['pending', 'processing'].includes(importedAudience?.status)) {
        waitForAudienceImport(importId);
        return;
      }

      if (importedAudience?.contact_count > 0) {
        campaignFormRef.value?.selectImportedAudience(
          importedAudience.label_id
        );
        useAlert(
          t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.READY', {
            count: importedAudience.contact_count,
          })
        );
      } else {
        useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.EMPTY'));
      }
    } catch (error) {
      useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.STATUS_ERROR'));
    }
  }, 2500);
};

const handleContactImport = async importDetails => {
  try {
    isImportingAudience.value = true;
    const { data } = await CampaignAudiencesAPI.createList(importDetails);
    campaignAudiences.value = [data, ...campaignAudiences.value];
    contactImportDialogRef.value?.dialogRef?.close();
    contactImportDialogRef.value?.reset?.();
    useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.SUCCESS'));
    waitForAudienceImport(data.id);
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.ERROR')
    );
  } finally {
    isImportingAudience.value = false;
  }
};

onMounted(async () => {
  try {
    await refreshCampaignAudiences();
  } catch (error) {
    useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.STATUS_ERROR'));
  }
});

onBeforeUnmount(() => window.clearTimeout(audiencePollTimer));
</script>

<template>
  <div
    class="w-[25rem] max-w-[calc(100vw-2rem)] z-50 min-w-0 absolute top-10 ltr:right-0 rtl:left-0 bg-n-alpha-3 backdrop-blur-[100px] rounded-xl border border-n-weak shadow-md max-h-[80vh] overflow-y-auto"
  >
    <div class="p-6 flex flex-col gap-6">
      <h3 class="text-base font-medium text-n-slate-12 flex-shrink-0">
        {{ t(`CAMPAIGN.WHATSAPP.CREATE.TITLE`) }}
      </h3>
      <WhatsAppCampaignForm
        ref="campaignFormRef"
        :campaign-audiences="campaignAudiences"
        @submit="handleSubmit"
        @cancel="handleClose"
        @import="handleOpenContactImport"
      />
    </div>
  </div>
  <CampaignAudienceImportDialog
    ref="contactImportDialogRef"
    :is-loading="isImportingAudience"
    @import="handleContactImport"
  />
</template>
