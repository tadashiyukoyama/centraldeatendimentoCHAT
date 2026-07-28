<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';
import EmailCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/EmailCampaign/EmailCampaignDialog.vue';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';
import SMSCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/SMSCampaignEmptyState.vue';

const { t } = useI18n();
const getters = useStoreGetters();

const selectedCampaign = ref(null);
const [showDialog, toggleDialog] = useToggle();
const dialogRef = ref(null);

const uiFlags = useMapGetter('campaigns/getUIFlags');
const campaigns = computed(() => getters['campaigns/getEmailCampaigns'].value);
const isFetching = computed(() => uiFlags.value.isFetching);
const hasNoCampaigns = computed(
  () => campaigns.value.length === 0 && !isFetching.value
);

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  dialogRef.value.dialogRef.open();
};
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.EMAIL.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.EMAIL.NEW_CAMPAIGN')"
    @click="toggleDialog()"
    @close="toggleDialog(false)"
  >
    <template #action>
      <EmailCampaignDialog v-if="showDialog" @close="toggleDialog(false)" />
    </template>
    <div
      v-if="isFetching"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <CampaignList
      v-else-if="!hasNoCampaigns"
      :campaigns="campaigns"
      @delete="handleDelete"
    />
    <SMSCampaignEmptyState
      v-else
      :title="t('CAMPAIGN.EMAIL.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.EMAIL.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />
    <ConfirmDeleteCampaignDialog
      ref="dialogRef"
      :selected-campaign="selectedCampaign"
    />
  </CampaignLayout>
</template>
