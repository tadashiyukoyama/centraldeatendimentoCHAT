<script setup>
import { reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, sameAs } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getEmailInboxes'),
};

const initialState = {
  title: '',
  subject: '',
  message: '',
  inboxId: null,
  scheduledAt: null,
  selectedAudience: [],
  lawfulBasisConfirmed: false,
};

const state = reactive({ ...initialState });

const rules = {
  title: { required, minLength: minLength(1) },
  subject: { required, minLength: minLength(1) },
  message: { required, minLength: minLength(1) },
  inboxId: { required },
  scheduledAt: { required },
  selectedAudience: { required },
  lawfulBasisConfirmed: { sameAs: sameAs(true) },
};

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
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

const errorMessages = computed(() => ({
  title: t('CAMPAIGN.EMAIL.CREATE.FORM.TITLE.ERROR'),
  subject: t('CAMPAIGN.EMAIL.CREATE.FORM.SUBJECT.ERROR'),
  message: t('CAMPAIGN.EMAIL.CREATE.FORM.MESSAGE.ERROR'),
  inboxId: t('CAMPAIGN.EMAIL.CREATE.FORM.INBOXID.ERROR'),
  selectedAudience: t('CAMPAIGN.EMAIL.CREATE.FORM.SELECTEDAUDIENCE.ERROR'),
  scheduledAt: t('CAMPAIGN.EMAIL.CREATE.FORM.SCHEDULEDAT.ERROR'),
  lawfulBasisConfirmed: t(
    'CAMPAIGN.EMAIL.CREATE.FORM.LAWFULBASISCONFIRMED.ERROR'
  ),
}));

const errorFor = field =>
  v$.value[field].$error ? errorMessages.value[field] : '';

const isSubmitDisabled = computed(() => v$.value.$invalid);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const prepareCampaignDetails = () => ({
  title: state.title,
  message: state.message,
  inbox_id: state.inboxId,
  scheduled_at: formatToUTCString(state.scheduledAt),
  audience: state.selectedAudience.map(id => ({
    id,
    type: 'Label',
  })),
  template_params: {
    subject: state.subject,
    lawful_basis_confirmed: state.lawfulBasisConfirmed,
  },
});

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('submit', prepareCampaignDetails());
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.EMAIL.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.EMAIL.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="errorFor('title')"
      :message-type="errorFor('title') ? 'error' : 'info'"
    />

    <Input
      v-model="state.subject"
      :label="t('CAMPAIGN.EMAIL.CREATE.FORM.SUBJECT.LABEL')"
      :placeholder="t('CAMPAIGN.EMAIL.CREATE.FORM.SUBJECT.PLACEHOLDER')"
      :message="errorFor('subject')"
      :message-type="errorFor('subject') ? 'error' : 'info'"
    />

    <TextArea
      v-model="state.message"
      :label="t('CAMPAIGN.EMAIL.CREATE.FORM.MESSAGE.LABEL')"
      :placeholder="t('CAMPAIGN.EMAIL.CREATE.FORM.MESSAGE.PLACEHOLDER')"
      :message="errorFor('message')"
      :message-type="errorFor('message') ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label
        for="email-campaign-inbox"
        class="text-sm font-medium text-n-slate-12"
      >
        {{ t('CAMPAIGN.EMAIL.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="email-campaign-inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!errorFor('inboxId')"
        :placeholder="t('CAMPAIGN.EMAIL.CREATE.FORM.INBOX.PLACEHOLDER')"
        :message="errorFor('inboxId')"
        class="[&>div>button]:bg-n-alpha-black2"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label
        for="email-campaign-audience"
        class="text-sm font-medium text-n-slate-12"
      >
        {{ t('CAMPAIGN.EMAIL.CREATE.FORM.SELECTEDAUDIENCE.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        id="email-campaign-audience"
        v-model="state.selectedAudience"
        :options="audienceList"
        :label="t('CAMPAIGN.EMAIL.CREATE.FORM.SELECTEDAUDIENCE.LABEL')"
        :placeholder="
          t('CAMPAIGN.EMAIL.CREATE.FORM.SELECTEDAUDIENCE.PLACEHOLDER')
        "
        :has-error="!!errorFor('selectedAudience')"
        :message="errorFor('selectedAudience')"
        class="[&>div>button]:bg-n-alpha-black2"
      />
    </div>

    <Input
      v-model="state.scheduledAt"
      :label="t('CAMPAIGN.EMAIL.CREATE.FORM.SCHEDULEDAT.LABEL')"
      type="datetime-local"
      :min="currentDateTime"
      :message="errorFor('scheduledAt')"
      :message-type="errorFor('scheduledAt') ? 'error' : 'info'"
    />

    <label class="flex items-start gap-2 text-sm text-n-slate-11">
      <Checkbox v-model="state.lawfulBasisConfirmed" class="mt-0.5 shrink-0" />
      <span>{{
        t('CAMPAIGN.EMAIL.CREATE.FORM.LAWFULBASISCONFIRMED.LABEL')
      }}</span>
    </label>
    <span v-if="errorFor('lawfulBasisConfirmed')" class="text-xs text-n-ruby-9">
      {{ errorFor('lawfulBasisConfirmed') }}
    </span>

    <div class="flex items-center justify-between w-full gap-3">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.EMAIL.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full"
        @click="emit('cancel')"
      />
      <Button
        :label="t('CAMPAIGN.EMAIL.CREATE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
