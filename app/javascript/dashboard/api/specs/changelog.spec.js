import axios from 'axios';
import changelogAPI from '../changelog';

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
});
