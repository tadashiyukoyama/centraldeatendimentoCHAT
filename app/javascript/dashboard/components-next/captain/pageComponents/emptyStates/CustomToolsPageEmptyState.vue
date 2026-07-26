<script setup>
import { useAccount } from 'dashboard/composables/useAccount';
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import FeatureSpotlight from 'dashboard/components-next/feature-spotlight/FeatureSpotlight.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { assistantAsset } from 'shared/helpers/publicBrand';
import { getHelpUrlForFeature } from 'dashboard/helper/featureHelper';

const emit = defineEmits(['click']);
const { isOnChatwootCloud } = useAccount();

const onClick = () => {
  emit('click');
};
</script>

<template>
  <FeatureSpotlight
    :title="$t('CAPTAIN.CUSTOM_TOOLS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
    :note="$t('CAPTAIN.CUSTOM_TOOLS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
    :fallback-thumbnail="assistantAsset('assistant-light.svg')"
    :fallback-thumbnail-dark="assistantAsset('assistant-dark.svg')"
    :learn-more-url="getHelpUrlForFeature('captain')"
    class="mb-8"
    :hide-actions="!isOnChatwootCloud"
  />
  <EmptyStateLayout
    :title="$t('CAPTAIN.CUSTOM_TOOLS.EMPTY_STATE.TITLE')"
    :subtitle="$t('CAPTAIN.CUSTOM_TOOLS.EMPTY_STATE.SUBTITLE')"
    :action-perms="['administrator']"
  >
    <template #empty-state-item>
      <div class="min-h-[600px]" />
    </template>
    <template #actions>
      <Button
        :label="$t('CAPTAIN.CUSTOM_TOOLS.ADD_NEW')"
        icon="i-lucide-plus"
        @click="onClick"
      />
    </template>
  </EmptyStateLayout>
</template>
