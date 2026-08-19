import { sanitizeAllowedInboxIds } from './formSanitizer';

describe('sanitizeAllowedInboxIds', () => {
  it('removes deleted inbox ids before the integration form is saved again', () => {
    const settings = { allowed_inbox_ids: ['5', 19, '20'] };
    const inboxes = [{ id: 5 }, { id: 20 }];

    expect(sanitizeAllowedInboxIds(settings, inboxes)).toEqual([5, 20]);
  });
});
