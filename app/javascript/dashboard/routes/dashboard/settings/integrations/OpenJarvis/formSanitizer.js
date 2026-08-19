export const sanitizeAllowedInboxIds = (settings, inboxes) => {
  const availableIds = new Set(inboxes.map(inbox => Number(inbox.id)));
  const selectedIds = Array.isArray(settings.allowed_inbox_ids)
    ? settings.allowed_inbox_ids
    : [];
  return [...new Set(selectedIds.map(Number))].filter(id =>
    availableIds.has(id)
  );
};
