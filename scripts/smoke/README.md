# Controlled production smoke tests

## Strict team conversation visibility

`strict-team-conversation-visibility.mjs` validates the strict privacy feature
through the public Platform and Application APIs. It creates an isolated,
temporary account with:

- one administrator;
- two agents;
- one shared inbox;
- two teams, one agent per team;
- one conversation per team and one conversation without a team.

The runner attests the deployed Git SHA and verifies list, direct access,
search, unread counts, notifications, contact surfaces, bulk contact actions,
assignment and participant exceptions, team and inbox membership changes,
human replies, team transfers, direct-upload authorization, ActionCable event
isolation, feature rollback, and feature reactivation. It then requests
deletion of all temporary resources and polls until their removal is confirmed.

The smoke opens two authenticated ActionCable subscriptions. This requires
Node.js 22 or newer and a production WebSocket endpoint at `/cable`.

The required Platform App must be temporary. Store its token in a private file
outside the Git repository and pass only the file path to the runner. Never put
the token on the command line, in Git, in a report, or in a chat message.

Example:

```powershell
node scripts/smoke/strict-team-conversation-visibility.mjs `
  --base-url 'https://chat.example.com' `
  --platform-token-file 'D:\private\platform-api-token.txt' `
  --expected-deploy-sha '0000000000000000000000000000000000000000' `
  --runner-sha '1111111111111111111111111111111111111111' `
  --report-file 'D:\private\strict-privacy-smoke-report.json'
```

After a successful run, delete the temporary Platform App in Super Admin to
revoke its privileged token. The redacted report intentionally records this as
a required manual revocation.
