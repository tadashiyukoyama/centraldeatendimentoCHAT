<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Banner from 'dashboard/components-next/banner/Banner.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import instagramClient from 'dashboard/api/channel/instagramClient';
import api from 'dashboard/api/instagramCommentAutomations';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const loading = ref(true);
const saving = ref(false);
const activating = ref(false);
const rules = ref([]);
const events = ref([]);
const subscription = ref({
  success: false,
  subscribed_fields: [],
  missing_fields: ['comments', 'live_comments'],
  reauthorization_required: true,
});

const blankForm = () => ({
  id: null,
  lock_version: 0,
  name: '',
  enabled: false,
  match_type: 'whole_word',
  keywordsText: 'demo',
  media_id: '',
  include_nested_replies: false,
  public_reply_enabled: true,
  public_reply_template:
    'Pronto, {{username}}! Enviei os detalhes no Direct. ✉️',
  private_reply_enabled: true,
  private_reply_template:
    'Olá, {{username}}! Vi que você comentou {{keyword}}. Quer conhecer na prática os benefícios e funcionalidades do AI Food Manager?',
  conversation_context:
    'Lead interessado em uma demonstração do AI Food Manager. Qualifique nome, telefone e empresa; esclareça dúvidas e ofereça agendamento com um especialista.',
  conversation_label: 'instagram_demo',
  priority: 0,
});

const form = reactive(blankForm());

const subscriptionReady = computed(
  () =>
    subscription.value.success && subscription.value.missing_fields.length === 0
);

const eventStatusClass = status => {
  if (status === 'completed') return 'text-n-teal-11';
  if (['failed', 'partially_failed'].includes(status)) return 'text-n-ruby-11';
  if (status === 'ignored') return 'text-n-slate-10';
  return 'text-n-amber-11';
};

const normalizeRule = rule => ({
  ...rule,
  keywordsText: (rule.keywords || []).join(', '),
  media_id: rule.media_id || '',
  conversation_context: rule.conversation_context || '',
  conversation_label: rule.conversation_label || '',
});

const resetForm = () => {
  Object.assign(form, blankForm());
};

const editRule = rule => {
  Object.assign(form, normalizeRule(rule));
  window.scrollTo({ top: 0, behavior: 'smooth' });
};

const payload = () => ({
  name: form.name.trim(),
  enabled: form.enabled,
  match_type: form.match_type,
  keywords: form.keywordsText
    .split(',')
    .map(keyword => keyword.trim())
    .filter(Boolean),
  media_id: form.media_id.trim() || null,
  include_nested_replies: form.include_nested_replies,
  public_reply_enabled: form.public_reply_enabled,
  public_reply_template: form.public_reply_template,
  private_reply_enabled: form.private_reply_enabled,
  private_reply_template: form.private_reply_template,
  conversation_context: form.conversation_context,
  conversation_label: form.conversation_label.trim() || null,
  priority: Number(form.priority),
  lock_version: form.lock_version,
});

const errorMessage = error =>
  error?.response?.data?.error ||
  error?.response?.data?.message ||
  t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.ERROR');

const load = async () => {
  loading.value = true;
  try {
    const [rulesResponse, eventsResponse] = await Promise.all([
      api.getAll(props.inbox.id),
      api.getEvents(props.inbox.id),
    ]);
    rules.value = rulesResponse.data.payload;
    events.value = eventsResponse.data.payload;

    try {
      const response = await api.getSubscription(props.inbox.id);
      subscription.value = response.data;
    } catch (error) {
      subscription.value = error.response?.data || subscription.value;
    }
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    loading.value = false;
  }
};

const save = async () => {
  if (form.enabled && !subscriptionReady.value) {
    useAlert(
      t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.SUBSCRIPTION_REQUIRED')
    );
    return;
  }

  saving.value = true;
  try {
    if (form.id) {
      await api.updateAutomation(props.inbox.id, form.id, payload());
    } else {
      await api.createAutomation(props.inbox.id, payload());
    }
    useAlert(t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.SAVED'));
    resetForm();
    await load();
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    saving.value = false;
  }
};

const remove = async rule => {
  // Browser confirmation keeps deletion explicit without mutating until the
  // administrator accepts.
  // eslint-disable-next-line no-alert
  const confirmed = window.confirm(
    t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.DELETE_CONFIRM', {
      name: rule.name,
    })
  );
  if (!confirmed) return;

  try {
    await api.deleteAutomation(props.inbox.id, rule.id);
    useAlert(t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.DELETED'));
    await load();
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

const activateSubscription = async () => {
  activating.value = true;
  try {
    const response = await api.activateSubscription(props.inbox.id);
    subscription.value = response.data;
    useAlert(t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.SUBSCRIPTION_ACTIVE'));
  } catch (error) {
    subscription.value = error.response?.data || subscription.value;
    useAlert(t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.REAUTHORIZE_REQUIRED'));
  } finally {
    activating.value = false;
  }
};

const reauthorize = async () => {
  try {
    const response = await instagramClient.generateAuthorization();
    window.location.href = response.data.url;
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

onMounted(load);
</script>

<template>
  <div class="max-w-6xl">
    <div v-if="loading" class="flex justify-center py-16">
      <Spinner :size="28" />
    </div>

    <div v-else class="flex flex-col gap-6">
      <Banner :color="subscriptionReady ? 'teal' : 'amber'">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="font-medium text-n-slate-12">
              {{
                subscriptionReady
                  ? $t(
                      'INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.SUBSCRIPTION_OK'
                    )
                  : $t(
                      'INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.SUBSCRIPTION_MISSING'
                    )
              }}
            </p>
            <p v-if="!subscriptionReady" class="text-sm text-n-slate-11">
              {{
                $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.SUBSCRIPTION_HELP')
              }}
            </p>
          </div>
          <div v-if="!subscriptionReady" class="flex flex-wrap gap-2">
            <Button
              :label="
                $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.ACTIVATE_WEBHOOK')
              "
              :is-loading="activating"
              @click="activateSubscription"
            />
            <Button
              outline
              :label="$t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.REAUTHORIZE')"
              @click="reauthorize"
            />
          </div>
        </div>
      </Banner>

      <section class="rounded-xl border border-n-weak bg-n-solid-2 p-5">
        <div class="mb-5">
          <h3 class="text-lg font-medium text-n-slate-12">
            {{
              form.id
                ? $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.EDIT')
                : $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.NEW')
            }}
          </h3>
          <p class="text-sm text-n-slate-11">
            {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.DESCRIPTION') }}
          </p>
        </div>

        <div class="grid gap-4 md:grid-cols-2">
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.NAME') }}
            <input v-model="form.name" type="text" maxlength="120" />
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.KEYWORDS') }}
            <input v-model="form.keywordsText" type="text" maxlength="1000" />
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.MATCH_TYPE') }}
            <select v-model="form.match_type">
              <option value="whole_word">
                {{
                  $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.MATCH_WHOLE_WORD')
                }}
              </option>
              <option value="exact">
                {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.MATCH_EXACT') }}
              </option>
              <option value="contains">
                {{
                  $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.MATCH_CONTAINS')
                }}
              </option>
            </select>
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.MEDIA_ID') }}
            <input v-model="form.media_id" type="text" inputmode="numeric" />
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.PRIORITY') }}
            <input
              v-model.number="form.priority"
              type="number"
              min="-100"
              max="100"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.LABEL') }}
            <input
              v-model="form.conversation_label"
              type="text"
              maxlength="50"
            />
          </label>
        </div>

        <div class="mt-5 grid gap-5 md:grid-cols-2">
          <div class="rounded-lg border border-n-weak p-4">
            <label class="mb-3 flex items-center gap-2 font-medium">
              <input v-model="form.public_reply_enabled" type="checkbox" />
              {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.PUBLIC_REPLY') }}
            </label>
            <textarea
              v-model="form.public_reply_template"
              :disabled="!form.public_reply_enabled"
              maxlength="300"
              rows="4"
              class="w-full"
            />
          </div>
          <div class="rounded-lg border border-n-weak p-4">
            <label class="mb-3 flex items-center gap-2 font-medium">
              <input v-model="form.private_reply_enabled" type="checkbox" />
              {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.PRIVATE_REPLY') }}
            </label>
            <textarea
              v-model="form.private_reply_template"
              :disabled="!form.private_reply_enabled"
              maxlength="1000"
              rows="4"
              class="w-full"
            />
          </div>
        </div>

        <label class="mt-5 flex flex-col gap-1 text-sm text-n-slate-12">
          {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.NEMMO_CONTEXT') }}
          <textarea
            v-model="form.conversation_context"
            maxlength="2000"
            rows="4"
          />
        </label>

        <div class="mt-4 flex flex-wrap items-center justify-between gap-3">
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <input
              v-model="form.enabled"
              type="checkbox"
              :disabled="!subscriptionReady"
            />
            {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.ENABLED') }}
          </label>
          <div class="flex gap-2">
            <Button
              v-if="form.id"
              outline
              :label="$t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.CANCEL')"
              @click="resetForm"
            />
            <Button
              :label="$t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.SAVE')"
              :is-loading="saving"
              :disabled="!form.name.trim() || !form.keywordsText.trim()"
              @click="save"
            />
          </div>
        </div>
      </section>

      <section class="rounded-xl border border-n-weak bg-n-solid-2 p-5">
        <h3 class="mb-4 text-lg font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.RULES') }}
        </h3>
        <p v-if="rules.length === 0" class="text-sm text-n-slate-11">
          {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.NO_RULES') }}
        </p>
        <div v-else class="flex flex-col divide-y divide-n-weak">
          <div
            v-for="rule in rules"
            :key="rule.id"
            class="flex flex-wrap items-center justify-between gap-3 py-4"
          >
            <div>
              <div class="flex items-center gap-2">
                <span class="font-medium text-n-slate-12">{{ rule.name }}</span>
                <span
                  class="rounded-full px-2 py-0.5 text-xs"
                  :class="
                    rule.enabled
                      ? 'bg-n-teal-3 text-n-teal-11'
                      : 'bg-n-slate-3 text-n-slate-10'
                  "
                >
                  {{
                    rule.enabled
                      ? $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.ACTIVE')
                      : $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.INACTIVE')
                  }}
                </span>
              </div>
              <p class="text-sm text-n-slate-11">
                {{ rule.keywords.join(', ') }}
              </p>
            </div>
            <div class="flex gap-2">
              <Button
                xs
                outline
                :label="$t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.EDIT')"
                @click="editRule(rule)"
              />
              <Button
                xs
                ruby
                outline
                :label="$t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.DELETE')"
                @click="remove(rule)"
              />
            </div>
          </div>
        </div>
      </section>

      <section class="rounded-xl border border-n-weak bg-n-solid-2 p-5">
        <h3 class="mb-4 text-lg font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.RECENT_EVENTS') }}
        </h3>
        <p v-if="events.length === 0" class="text-sm text-n-slate-11">
          {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.NO_EVENTS') }}
        </p>
        <div v-else class="overflow-x-auto">
          <table class="w-full text-left text-sm">
            <thead class="text-n-slate-11">
              <tr>
                <th class="py-2 pr-4">
                  {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.COMMENT') }}
                </th>
                <th class="py-2 pr-4">
                  {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.RULE') }}
                </th>
                <th class="py-2 pr-4">
                  {{ $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.STATUS') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr v-for="event in events" :key="event.id">
                <td class="max-w-lg py-3 pr-4">
                  <p class="truncate text-n-slate-12">
                    {{ event.comment_text }}
                  </p>
                  <p class="text-xs text-n-slate-10">
                    {{
                      $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.USERNAME', {
                        username: event.sender_username || 'instagram',
                      })
                    }}
                  </p>
                </td>
                <td class="py-3 pr-4 text-n-slate-11">
                  {{
                    event.automation_name ||
                    $t('INBOX_MGMT.INSTAGRAM_COMMENT_AUTOMATION.NONE')
                  }}
                </td>
                <td
                  class="py-3 pr-4 font-medium"
                  :class="eventStatusClass(event.status)"
                >
                  {{ event.status }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </div>
  </div>
</template>
