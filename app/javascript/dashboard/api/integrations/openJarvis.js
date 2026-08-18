/* global axios */

import ApiClient from '../ApiClient';

class OpenJarvisAPI extends ApiClient {
  constructor() {
    super('integrations/openjarvis', { accountScoped: true });
  }

  update(payload) {
    return axios.put(this.url, payload);
  }

  rotateAccessToken() {
    return axios.post(`${this.url}/rotate_access_token`);
  }

  rotateWebhookSecret() {
    return axios.post(`${this.url}/rotate_webhook_secret`);
  }

  testConnection() {
    return axios.post(`${this.url}/test_connection`);
  }

  getDeliveries() {
    return axios.get(`${this.url}/deliveries`);
  }

  disconnect() {
    return axios.delete(this.url);
  }
}

export default new OpenJarvisAPI();
