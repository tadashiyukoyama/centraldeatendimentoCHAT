---
id: "help.inboxes.en"
kind: "help"
locale: "en"
slug: "inboxes-and-teams-en"
title: "Inboxes, WhatsApp QR, and teams"
category_slug: "channels"
category_name: "Channels"
position: 11
managed: true
---

Connect channels, assign teams, and operate one number with clear access boundaries.

## Setup

1. Open **Settings** with an authorized role.
2. Review scope, involved users, and the data that will be processed.
3. Apply the change in a controlled environment and validate it with a test account.
4. Record the owner, result, and rollback path.

## Good practices

- apply least privilege and never share credentials;
- document names, owners, and purpose;
- test light and dark themes on desktop and mobile;
- confirm that sensitive data is absent from URLs, logs, and screenshots.

## WhatsApp QR/Evolution

The QR channel uses a WhatsApp session linked to the scanned number and is not Meta's official API. The official 24-hour window must not block replies from this inbox. WhatsApp rules still apply, and the session may disconnect or be blocked. Never expose tokens, internal instance names, QR data, or raw provider payloads in the browser.

## Support

Contact `{{SUPPORT_CONTACT_EMAIL}}` with the protocol only. Never send passwords, tokens, or QR codes.
