<script setup>
import { reactive, computed, watch, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import {
  required,
  minLength,
  minValue,
  maxValue,
  sameAs,
} from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const route = useRoute();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getWhatsAppCampaignInboxes'),
  getFilteredWhatsAppTemplates: useMapGetter(
    'inboxes/getFilteredWhatsAppTemplates'
  ),
};

const initialState = {
  title: '',
  inboxId: null,
  templateId: null,
  scheduledAt: null,
  selectedAudience: [],
  message: '',
  messageVariantTwo: '',
  messageVariantThree: '',
  deliveryIntervalMinutes: 4,
  lawfulBasisConfirmed: false,
};

const state = reactive({ ...initialState });
const templateParserRef = ref(null);

const selectedInbox = computed(() =>
  formState.inboxes.value.find(inbox => inbox.id === Number(state.inboxId))
);

const isEvolutionInbox = computed(
  () => selectedInbox.value?.provider === 'evolution'
);

const rules = computed(() => ({
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  templateId: isEvolutionInbox.value ? {} : { required },
  scheduledAt: { required },
  selectedAudience: { required },
  message: isEvolutionInbox.value ? { required, minLength: minLength(1) } : {},
  deliveryIntervalMinutes: isEvolutionInbox.value
    ? { required, minValue: minValue(4), maxValue: maxValue(45) }
    : {},
  lawfulBasisConfirmed: isEvolutionInbox.value ? { sameAs: sameAs(true) } : {},
}));

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  // Added to disable the scheduled at field from being set to the current time
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const audienceList = computed(() =>
  mapToOptions(formState.labels.value, 'id', 'title')
);

const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);

const templateOptions = computed(() => {
  if (!state.inboxId) return [];
  const templates = formState.getFilteredWhatsAppTemplates.value(state.inboxId);
  return templates.map(template => {
    // Create a more user-friendly label from template name
    const friendlyName = template.name
      .replace(/_/g, ' ')
      .replace(/\b\w/g, l => l.toUpperCase());

    return {
      value: template.id,
      label: `${friendlyName} (${template.language || 'en'})`,
      template: template,
    };
  });
});

const selectedTemplate = computed(() => {
  if (!state.templateId) return null;
  return templateOptions.value.find(option => option.value === state.templateId)
    ?.template;
});

const errorMessages = computed(() => ({
  title: t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.ERROR'),
  inboxId: t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.ERROR'),
  templateId: t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.ERROR'),
  scheduledAt: t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.ERROR'),
  selectedAudience: t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.ERROR'),
  message: t('CAMPAIGN.WHATSAPP.CREATE.FORM.MESSAGE.ERROR'),
  deliveryIntervalMinutes: t(
    'CAMPAIGN.WHATSAPP.CREATE.FORM.DELIVERY_INTERVAL.ERROR'
  ),
  lawfulBasisConfirmed: t('CAMPAIGN.WHATSAPP.CREATE.FORM.LAWFUL_BASIS.ERROR'),
}));

const getErrorMessage = field =>
  v$.value[field].$error ? errorMessages.value[field] : '';

const formErrors = computed(() => ({
  title: getErrorMessage('title'),
  inbox: getErrorMessage('inboxId'),
  template: getErrorMessage('templateId'),
  scheduledAt: getErrorMessage('scheduledAt'),
  audience: getErrorMessage('selectedAudience'),
  message: getErrorMessage('message'),
  deliveryInterval: getErrorMessage('deliveryIntervalMinutes'),
  lawfulBasis: getErrorMessage('lawfulBasisConfirmed'),
}));

const hasRequiredTemplateParams = computed(() => {
  if (isEvolutionInbox.value) return true;
  return templateParserRef.value?.v$?.$invalid === false || true;
});

const isSubmitDisabled = computed(
  () => v$.value.$invalid || !hasRequiredTemplateParams.value
);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const handleCancel = () => emit('cancel');

const prepareCampaignDetails = () => {
  if (isEvolutionInbox.value) {
    const messageVariants = [
      state.messageVariantTwo,
      state.messageVariantThree,
    ].filter(message => message.trim());

    return {
      title: state.title,
      message: state.message,
      inbox_id: state.inboxId,
      scheduled_at: formatToUTCString(state.scheduledAt),
      audience: state.selectedAudience?.map(id => ({
        id,
        type: 'Label',
      })),
      trigger_rules: {
        delivery_interval_minutes: Number(state.deliveryIntervalMinutes),
        lawful_basis_confirmed: state.lawfulBasisConfirmed,
        message_variants: messageVariants,
      },
    };
  }

  // Find the selected template to get its content
  const currentTemplate = selectedTemplate.value;
  const parserData = templateParserRef.value;

  // Extract template content - this should be the template message body
  const templateContent = parserData?.renderedTemplate || '';

  // Prepare template_params object with the same structure as used in contacts
  const templateParams = {
    name: currentTemplate?.name || '',
    namespace: currentTemplate?.namespace || '',
    category: currentTemplate?.category || 'UTILITY',
    language: currentTemplate?.language || 'en_US',
    processed_params: parserData?.processedParams || {},
  };

  return {
    title: state.title,
    message: templateContent,
    template_params: templateParams,
    inbox_id: state.inboxId,
    scheduled_at: formatToUTCString(state.scheduledAt),
    audience: state.selectedAudience?.map(id => ({
      id,
      type: 'Label',
    })),
  };
};

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('submit', prepareCampaignDetails());
};

// Reset template selection when inbox changes
watch(
  () => state.inboxId,
  () => {
    state.templateId = null;
    state.message = '';
    state.messageVariantTwo = '';
    state.messageVariantThree = '';
  }
);
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.PLACEHOLDER')"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <div v-if="!isEvolutionInbox" class="flex flex-col gap-1">
      <label for="template" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.LABEL') }}
      </label>
      <ComboBox
        id="template"
        v-model="state.templateId"
        :options="templateOptions"
        :has-error="!!formErrors.template"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.PLACEHOLDER')"
        :message="formErrors.template"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.INFO') }}
      </p>
    </div>

    <!-- Template Parser -->
    <WhatsAppTemplateParser
      v-if="!isEvolutionInbox && selectedTemplate"
      ref="templateParserRef"
      :template="selectedTemplate"
    />

    <template v-if="isEvolutionInbox">
      <div
        class="rounded-lg border border-n-weak bg-n-alpha-2 p-3 text-xs text-n-slate-11"
      >
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.PERSONALIZATION.INFO') }}
        <router-link
          :to="{
            name: 'contacts_dashboard_index',
            params: { accountId: route.params.accountId },
          }"
          class="ml-1 font-medium text-n-blue-11"
        >
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.LINK') }}
        </router-link>
      </div>

      <TextArea
        v-model="state.message"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.MESSAGE.LABEL')"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.MESSAGE.PLACEHOLDER')"
        :message="formErrors.message"
        :message-type="formErrors.message ? 'error' : 'info'"
      />
      <TextArea
        v-model="state.messageVariantTwo"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.VARIANT_TWO.LABEL')"
        :placeholder="
          t('CAMPAIGN.WHATSAPP.CREATE.FORM.VARIANT_TWO.PLACEHOLDER')
        "
      />
      <TextArea
        v-model="state.messageVariantThree"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.VARIANT_THREE.LABEL')"
        :placeholder="
          t('CAMPAIGN.WHATSAPP.CREATE.FORM.VARIANT_THREE.PLACEHOLDER')
        "
      />
      <Input
        v-model="state.deliveryIntervalMinutes"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.DELIVERY_INTERVAL.LABEL')"
        type="number"
        min="4"
        max="45"
        :message="
          formErrors.deliveryInterval ||
          t('CAMPAIGN.WHATSAPP.CREATE.FORM.DELIVERY_INTERVAL.INFO')
        "
        :message-type="formErrors.deliveryInterval ? 'error' : 'info'"
      />
    </template>

    <div class="flex flex-col gap-1">
      <label for="audience" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        v-model="state.selectedAudience"
        :options="audienceList"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL')"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
        :has-error="!!formErrors.audience"
        :message="formErrors.audience"
        class="[&>div>button]:bg-n-alpha-black2"
      />
    </div>

    <Input
      v-model="state.scheduledAt"
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.LABEL')"
      type="datetime-local"
      :min="currentDateTime"
      :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')"
      :message="formErrors.scheduledAt"
      :message-type="formErrors.scheduledAt ? 'error' : 'info'"
    />

    <template v-if="isEvolutionInbox">
      <label class="flex items-start gap-2 text-sm text-n-slate-11">
        <Checkbox
          v-model="state.lawfulBasisConfirmed"
          class="mt-0.5 shrink-0"
        />
        <span>{{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.LAWFUL_BASIS.LABEL') }}</span>
      </label>
      <span v-if="formErrors.lawfulBasis" class="text-xs text-n-ruby-9">
        {{ formErrors.lawfulBasis }}
      </span>
    </template>

    <div class="flex gap-3 justify-between items-center w-full">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
