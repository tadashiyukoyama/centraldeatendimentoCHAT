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

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  campaignAudiences: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['submit', 'cancel', 'import']);

const { t } = useI18n();

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
  audienceSource: 'list',
  message: '',
  messageVariantTwo: '',
  messageVariantThree: '',
  deliveryIntervalMinMinutes: 4,
  deliveryIntervalMaxMinutes: 45,
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

const isLessThanMaximumInterval = value =>
  Number(value) < Number(state.deliveryIntervalMaxMinutes);
const isGreaterThanMinimumInterval = value =>
  Number(value) > Number(state.deliveryIntervalMinMinutes);

const rules = computed(() => ({
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  templateId: isEvolutionInbox.value ? {} : { required },
  scheduledAt: { required },
  selectedAudience: { required },
  message: isEvolutionInbox.value ? { required, minLength: minLength(1) } : {},
  deliveryIntervalMinMinutes: isEvolutionInbox.value
    ? {
        required,
        minValue: minValue(4),
        maxValue: maxValue(45),
        isLessThanMaximumInterval,
      }
    : {},
  deliveryIntervalMaxMinutes: isEvolutionInbox.value
    ? {
        required,
        minValue: minValue(4),
        maxValue: maxValue(45),
        isGreaterThanMinimumInterval,
      }
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
  mapToOptions(
    formState.labels.value.filter(
      label =>
        !props.campaignAudiences.some(
          audience => Number(audience.label_id) === Number(label.id)
        )
    ),
    'id',
    'title'
  )
);

const importedAudienceOptions = computed(() =>
  props.campaignAudiences
    .filter(
      audience =>
        ['completed', 'completed_with_errors'].includes(audience.status) &&
        audience.contact_count > 0 &&
        audience.label_id
    )
    .map(audience => ({
      value: audience.label_id,
      label: t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LIST_OPTION', {
        name: audience.name,
        count: audience.contact_count,
      }),
    }))
);

const audienceSourceOptions = computed(() => [
  {
    value: 'list',
    label: t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.SOURCE_LIST'),
  },
  {
    value: 'labels',
    label: t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.SOURCE_LABELS'),
  },
]);

const selectedImportedAudience = computed({
  get: () => state.selectedAudience[0] || null,
  set: value => {
    state.selectedAudience = value ? [value] : [];
  },
});

const activeAudienceImports = computed(() =>
  props.campaignAudiences.filter(audience =>
    ['pending', 'processing'].includes(audience.status)
  )
);

const selectImportedAudience = labelId => {
  state.audienceSource = 'list';
  state.selectedAudience = [labelId];
  v$.value.selectedAudience.$touch();
};

defineExpose({ selectImportedAudience });

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
  deliveryIntervalMinMinutes: t(
    'CAMPAIGN.WHATSAPP.CREATE.FORM.DELIVERY_INTERVAL.ERROR'
  ),
  deliveryIntervalMaxMinutes: t(
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
  deliveryIntervalMin: getErrorMessage('deliveryIntervalMinMinutes'),
  deliveryIntervalMax: getErrorMessage('deliveryIntervalMaxMinutes'),
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
        delivery_interval_min_minutes: Number(state.deliveryIntervalMinMinutes),
        delivery_interval_max_minutes: Number(state.deliveryIntervalMaxMinutes),
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

watch(
  () => state.audienceSource,
  () => {
    state.selectedAudience = [];
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
        class="flex flex-col gap-3 rounded-lg border border-n-weak bg-n-alpha-2 p-3"
      >
        <p class="mb-0 text-xs leading-5 text-n-slate-11">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.PERSONALIZATION.INFO') }}
        </p>
        <p class="mb-0 text-xs leading-5 text-n-slate-11">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.INFO') }}
        </p>
        <div class="flex flex-wrap items-center gap-2">
          <Button
            type="button"
            variant="outline"
            color="slate"
            size="sm"
            icon="i-lucide-upload"
            :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.LINK')"
            @click="emit('import')"
          />
          <a
            href="/downloads/import-contacts-sample.csv"
            download="import-contacts-sample.csv"
            class="inline-flex min-h-8 items-center text-xs font-medium text-n-blue-11 hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
          >
            {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.SAMPLE') }}
          </a>
        </div>
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
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Input
          v-model="state.deliveryIntervalMinMinutes"
          :label="
            t('CAMPAIGN.WHATSAPP.CREATE.FORM.DELIVERY_INTERVAL.MIN_LABEL')
          "
          type="number"
          min="4"
          max="45"
          :message="formErrors.deliveryIntervalMin"
          :message-type="formErrors.deliveryIntervalMin ? 'error' : 'info'"
        />
        <Input
          v-model="state.deliveryIntervalMaxMinutes"
          :label="
            t('CAMPAIGN.WHATSAPP.CREATE.FORM.DELIVERY_INTERVAL.MAX_LABEL')
          "
          type="number"
          min="4"
          max="45"
          :message="formErrors.deliveryIntervalMax"
          :message-type="formErrors.deliveryIntervalMax ? 'error' : 'info'"
        />
      </div>
      <p class="-mt-2 mb-0 text-xs leading-5 text-n-slate-11">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.DELIVERY_INTERVAL.INFO') }}
      </p>
    </template>

    <div v-if="isEvolutionInbox" class="flex flex-col gap-3">
      <div class="flex flex-col gap-1">
        <label
          for="audience-source"
          class="mb-0.5 text-sm font-medium text-n-slate-12"
        >
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.SOURCE_LABEL') }}
        </label>
        <ComboBox
          id="audience-source"
          v-model="state.audienceSource"
          :options="audienceSourceOptions"
          class="[&>div>button]:bg-n-alpha-black2"
        />
      </div>

      <div v-if="state.audienceSource === 'list'" class="flex flex-col gap-1">
        <label
          for="imported-audience"
          class="mb-0.5 text-sm font-medium text-n-slate-12"
        >
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LIST_LABEL') }}
        </label>
        <ComboBox
          id="imported-audience"
          v-model="selectedImportedAudience"
          :options="importedAudienceOptions"
          :has-error="!!formErrors.audience"
          :placeholder="
            t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LIST_PLACEHOLDER')
          "
          :message="formErrors.audience"
          class="[&>div>button]:bg-n-alpha-black2"
        />
        <p class="mt-1 mb-0 text-xs leading-5 text-n-slate-11">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LIST_HELP') }}
        </p>
        <p
          v-if="activeAudienceImports.length"
          class="mt-1 mb-0 text-xs leading-5 text-n-blue-11"
          aria-live="polite"
        >
          {{
            t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.IMPORTING', {
              name: activeAudienceImports[0].name,
            })
          }}
        </p>
      </div>

      <div v-else class="flex flex-col gap-1">
        <label
          for="audience"
          class="mb-0.5 text-sm font-medium text-n-slate-12"
        >
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABELS_LABEL') }}
        </label>
        <TagMultiSelectComboBox
          id="audience"
          v-model="state.selectedAudience"
          :options="audienceList"
          :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABELS_LABEL')"
          :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
          :has-error="!!formErrors.audience"
          :message="formErrors.audience"
          class="[&>div>button]:bg-n-alpha-black2"
        />
      </div>
    </div>

    <div v-else class="flex flex-col gap-1">
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
