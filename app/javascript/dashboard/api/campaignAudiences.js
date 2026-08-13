/* global axios */

import ApiClient from './ApiClient';

class CampaignAudiencesAPI extends ApiClient {
  constructor() {
    super('campaign_audiences', { accountScoped: true });
  }

  createList({ name, file }) {
    const formData = new FormData();
    formData.append('name', name);
    formData.append('import_file', file);

    return axios.post(this.url, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }
}

export default new CampaignAudiencesAPI();
