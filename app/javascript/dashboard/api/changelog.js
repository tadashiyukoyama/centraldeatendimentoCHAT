import axios from 'axios';
import ApiClient from './ApiClient';
import { CHANGELOG_API_URL } from 'shared/constants/links';

class ChangelogApi extends ApiClient {
  constructor() {
    super('changelog', { apiVersion: 'v1' });
  }

  // eslint-disable-next-line class-methods-use-this
  fetchFromHub() {
    if (!CHANGELOG_API_URL) return Promise.resolve({ data: { posts: [] } });

    return axios.get(CHANGELOG_API_URL);
  }
}

export default new ChangelogApi();
