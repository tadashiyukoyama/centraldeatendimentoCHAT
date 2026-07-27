/* global axios */
import ApiClient from './ApiClient';

class InstagramCommentAutomationsAPI extends ApiClient {
  constructor() {
    super('instagram/comment_automations', { accountScoped: true });
  }

  getAll(inboxId) {
    return axios.get(this.url, { params: { inbox_id: inboxId } });
  }

  createAutomation(inboxId, automation) {
    return axios.post(this.url, {
      inbox_id: inboxId,
      comment_automation: automation,
    });
  }

  updateAutomation(inboxId, id, automation) {
    return axios.patch(`${this.url}/${id}`, {
      inbox_id: inboxId,
      comment_automation: automation,
    });
  }

  deleteAutomation(inboxId, id) {
    return axios.delete(`${this.url}/${id}`, {
      params: { inbox_id: inboxId },
    });
  }

  getEvents(inboxId) {
    return axios.get(
      this.url.replace('comment_automations', 'comment_events'),
      { params: { inbox_id: inboxId, limit: 50 } }
    );
  }

  getSubscription(inboxId) {
    return axios.get(
      this.url.replace('comment_automations', 'comment_webhook_subscription'),
      { params: { inbox_id: inboxId } }
    );
  }

  activateSubscription(inboxId) {
    return axios.post(
      this.url.replace('comment_automations', 'comment_webhook_subscription'),
      { inbox_id: inboxId }
    );
  }
}

export default new InstagramCommentAutomationsAPI();
