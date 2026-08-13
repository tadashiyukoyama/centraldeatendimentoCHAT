<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['import']);
const { t } = useI18n();

const dialogRef = ref(null);
const fileInput = ref(null);
const listName = ref('');
const selectedFile = ref(null);

const canSubmit = computed(
  () => listName.value.trim() && selectedFile.value && !props.isLoading
);

const openFilePicker = () => fileInput.value?.click();

const handleFileChange = event => {
  selectedFile.value = event.target.files?.[0] || null;
  if (!listName.value && selectedFile.value) {
    listName.value = selectedFile.value.name.replace(/\.csv$/i, '');
  }
};

const handleSubmit = () => {
  if (!canSubmit.value) return;
  emit('import', { name: listName.value.trim(), file: selectedFile.value });
};

const reset = () => {
  listName.value = '';
  selectedFile.value = null;
  if (fileInput.value) fileInput.value.value = '';
};

defineExpose({ dialogRef, reset });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.DIALOG_TITLE')"
    :confirm-button-label="
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.IMPORT')
    "
    :is-loading="isLoading"
    :disable-confirm-button="!canSubmit"
    @confirm="handleSubmit"
  >
    <template #description>
      <p class="mb-0 text-sm leading-6 text-n-slate-11">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.DIALOG_DESCRIPTION') }}
      </p>
    </template>

    <div class="flex flex-col gap-4">
      <Input
        v-model="listName"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.NAME_LABEL')"
        :placeholder="
          t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.NAME_PLACEHOLDER')
        "
      />

      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.FILE_LABEL') }}
        </span>
        <div
          class="flex min-h-11 items-center justify-between gap-3 rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-2"
        >
          <span class="min-w-0 truncate text-sm text-n-slate-11">
            {{
              selectedFile?.name ||
              t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.NO_FILE')
            }}
          </span>
          <Button
            type="button"
            color="slate"
            variant="outline"
            size="sm"
            icon="i-lucide-upload"
            :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.CHOOSE_FILE')"
            @click="openFilePicker"
          />
        </div>
        <p class="mb-0 text-xs leading-5 text-n-slate-11">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.IMPORT_LEADS.FILE_HELP') }}
        </p>
      </div>
    </div>

    <input
      ref="fileInput"
      class="hidden"
      type="file"
      accept=".csv,text/csv"
      @change="handleFileChange"
    />
  </Dialog>
</template>
