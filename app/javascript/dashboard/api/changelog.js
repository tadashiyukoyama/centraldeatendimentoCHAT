import axios from 'axios';
import ApiClient from './ApiClient';
import { CHANGELOG_API_URL } from 'shared/constants/links';

const LEGACY_HOST_SUFFIXES = ['chatwoot.com', 'chatwoot.help', 'chwt.app'];

export const sanitizeChangelogURL = value => {
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase().replace(/\.$/, '');
    const legacyHost = LEGACY_HOST_SUFFIXES.some(
      suffix => host === suffix || host.endsWith(`.${suffix}`)
    );
    const safe =
      url.protocol === 'https:' &&
      !url.username &&
      !url.password &&
      !legacyHost;
    return safe ? url.toString() : null;
  } catch {
    return null;
  }
};

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
