<script setup>
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert, useTrack } from 'dashboard/composables';
import { CAMPAIGN_TYPES } from 'shared/constants/campaign.js';
import { CAMPAIGNS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events.js';

import EmailCampaignForm from './EmailCampaignForm.vue';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const addCampaign = async campaignDetails => {
  try {
    await store.dispatch('campaigns/create', campaignDetails);
    useTrack(CAMPAIGNS_EVENTS.CREATE_CAMPAIGN, {
      type: CAMPAIGN_TYPES.ONE_OFF,
      channel: 'email',
    });
    useAlert(t('CAMPAIGN.EMAIL.CREATE.FORM.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    useAlert(
      error?.response?.message ||
        t('CAMPAIGN.EMAIL.CREATE.FORM.API.ERROR_MESSAGE')
    );
  }
};
</script>

<template>
  <div
    class="w-[28rem] max-h-[calc(100vh-8rem)] overflow-y-auto z-50 min-w-0 absolute top-10 ltr:right-0 rtl:left-0 bg-n-alpha-3 backdrop-blur-[100px] p-6 rounded-xl border border-n-weak shadow-md flex flex-col gap-6"
  >
    <h3 class="text-base font-medium text-n-slate-12">
      {{ t('CAMPAIGN.EMAIL.CREATE.TITLE') }}
    </h3>
    <EmailCampaignForm @submit="addCampaign" @cancel="emit('close')" />
  </div>
</template>
