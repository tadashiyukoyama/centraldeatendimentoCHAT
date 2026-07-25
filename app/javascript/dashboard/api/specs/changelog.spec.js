import axios from 'axios';
import changelogAPI, { sanitizeChangelogURL } from '../changelog';

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
  },
}));

describe('#ChangelogAPI', () => {
  it('returns an empty feed without contacting an external service by default', async () => {
    await expect(changelogAPI.fetchFromHub()).resolves.toEqual({
      data: { posts: [] },
    });
    expect(axios.get).not.toHaveBeenCalled();
  });

  it('accepts only HTTPS links from the configured feed', () => {
    const scriptURL = ['java', 'script:alert(1)'].join('');

    expect(
      sanitizeChangelogURL('https://updates.acelerachat.example/post')
    ).toBe('https://updates.acelerachat.example/post');
    expect(
      sanitizeChangelogURL('http://updates.acelerachat.example/post')
    ).toBeNull();
    expect(sanitizeChangelogURL(scriptURL)).toBeNull();
    expect(sanitizeChangelogURL('not-a-url')).toBeNull();
    expect(sanitizeChangelogURL('https://hub.2.chatwoot.com/post')).toBeNull();
    expect(
      sanitizeChangelogURL(
        'https://user:password@updates.acelerachat.example/post'
      )
    ).toBeNull();
  });
});
