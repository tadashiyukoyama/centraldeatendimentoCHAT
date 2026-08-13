/* global axios */

import ApiClient from './ApiClient';

class CampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns', { accountScoped: true });
  }

  getDeliveries(id, params = {}) {
    return axios.get(`${this.url}/${id}/deliveries`, { params });
  }
}

export default new CampaignsAPI();
