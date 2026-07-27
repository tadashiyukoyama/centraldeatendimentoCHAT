/* global axios */
import api from '../instagramCommentAutomations';
import ApiClient from '../ApiClient';

describe('#InstagramCommentAutomationsAPI', () => {
  beforeEach(() => {
    window.history.pushState({}, '', '/app/accounts/1/settings/inboxes/5');
    vi.stubGlobal('axios', {
      get: vi.fn().mockResolvedValue({ data: {} }),
      post: vi.fn().mockResolvedValue({ data: {} }),
      patch: vi.fn().mockResolvedValue({ data: {} }),
      delete: vi.fn().mockResolvedValue({ data: {} }),
    });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('is account-scoped and requests rules for one inbox', async () => {
    expect(api).toBeInstanceOf(ApiClient);

    await api.getAll(5);

    expect(axios.get).toHaveBeenCalledWith(
      '/api/v1/accounts/1/instagram/comment_automations',
      { params: { inbox_id: 5 } }
    );
  });

  it('activates subscriptions only through the explicit endpoint', async () => {
    await api.activateSubscription(5);

    expect(axios.post).toHaveBeenCalledWith(
      '/api/v1/accounts/1/instagram/comment_webhook_subscription',
      { inbox_id: 5 }
    );
  });

  it('sends optimistic-lock data when updating an automation', async () => {
    const automation = { name: 'Demo', lock_version: 3 };

    await api.updateAutomation(5, 9, automation);

    expect(axios.patch).toHaveBeenCalledWith(
      '/api/v1/accounts/1/instagram/comment_automations/9',
      {
        inbox_id: 5,
        comment_automation: automation,
      }
    );
  });
});
