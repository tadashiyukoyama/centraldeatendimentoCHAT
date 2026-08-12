<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert, useTrack } from 'dashboard/composables';
import { CAMPAIGN_TYPES } from 'shared/constants/campaign.js';
import { CAMPAIGNS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events.js';

import WhatsAppCampaignForm from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignForm.vue';
import ContactImportDialog from 'dashboard/components-next/Contacts/ContactsForm/ContactImportDialog.vue';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();
const contactImportDialogRef = ref(null);

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
      error?.response?.message ||
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

const handleContactImport = async file => {
  try {
    await store.dispatch('contacts/import', file);
    contactImportDialogRef.value?.dialogRef?.close();
    useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.SUCCESS'));
  } catch (error) {
    useAlert(
      error?.message || t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.ERROR')
    );
  }
};
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
        @submit="handleSubmit"
        @cancel="handleClose"
        @import="handleOpenContactImport"
      />
    </div>
  </div>
  <ContactImportDialog
    ref="contactImportDialogRef"
    @import="handleContactImport"
  />
</template>
