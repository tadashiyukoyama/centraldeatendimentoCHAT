#!/usr/bin/env node

import { randomBytes } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

const FEATURE = 'strict_team_conversation_visibility';
const UNREAD_FEATURE = 'conversation_unread_counts';
const REQUEST_TIMEOUT_MS = 20_000;
const CLEANUP_TIMEOUT_MS = 90_000;
const EVENT_TIMEOUT_MS = 20_000;

function parseArgs(argv) {
  const options = {};

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (!argument.startsWith('--')) {
      throw new Error(`Unexpected positional argument: ${argument}`);
    }

    const name = argument.slice(2);
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`Missing value for --${name}`);
    }

    options[name] = value;
    index += 1;
  }

  const required = [
    'base-url',
    'platform-token-file',
    'expected-deploy-sha',
    'runner-sha',
    'report-file',
  ];

  for (const name of required) {
    if (!options[name]) {
      throw new Error(`Missing required argument: --${name}`);
    }
  }

  return options;
}

function validateOptions(options) {
  const baseUrl = new URL(options['base-url']);
  if (baseUrl.protocol !== 'https:') {
    throw new Error('--base-url must use HTTPS');
  }
  if (baseUrl.username || baseUrl.password || baseUrl.search || baseUrl.hash) {
    throw new Error(
      '--base-url must not contain credentials, query parameters, or a fragment'
    );
  }

  for (const name of ['expected-deploy-sha', 'runner-sha']) {
    if (!/^[0-9a-f]{40}$/.test(options[name])) {
      throw new Error(
        `--${name} must be a full lowercase 40-character Git SHA`
      );
    }
  }

  return baseUrl.origin;
}

function sleep(milliseconds) {
  return new Promise(resolvePromise =>
    setTimeout(resolvePromise, milliseconds)
  );
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function assertExactIds(actual, expected, label) {
  const normalizedActual = [...actual]
    .map(Number)
    .sort((left, right) => left - right);
  const normalizedExpected = [...expected]
    .map(Number)
    .sort((left, right) => left - right);
  assert(
    JSON.stringify(normalizedActual) === JSON.stringify(normalizedExpected),
    `${label}: expected ids [${normalizedExpected.join(',')}], observed ids [${normalizedActual.join(',')}]`
  );
}

function conversationIds(response) {
  const payload = response?.data?.payload ?? response?.payload;
  assert(
    Array.isArray(payload),
    'Conversation response did not contain data.payload'
  );
  return payload.map(conversation => Number(conversation.id));
}

function contactIds(response) {
  const payload = response?.data?.payload ?? response?.payload;
  assert(Array.isArray(payload), 'Contact response did not contain payload');
  return payload.map(contact => Number(contact.id));
}

function notificationConversationIds(response) {
  const payload = response?.data?.payload;
  assert(
    Array.isArray(payload),
    'Notification response did not contain data.payload'
  );
  return payload.map(notification => Number(notification.primary_actor?.id));
}

function unreadCounts(response) {
  const payload = response?.payload;
  assert(
    payload && Number.isInteger(payload.all_count),
    'Unread count response did not contain payload.all_count'
  );
  return payload;
}

function featureEnabled(features, name) {
  if (Array.isArray(features)) {
    return features.includes(name);
  }

  return features?.[name] === true;
}

async function readToken(tokenFile) {
  const token = (await readFile(resolve(tokenFile), 'utf8')).trim();
  assert(token.length >= 20, 'Platform token file is empty or invalid');
  assert(!/\s/.test(token), 'Platform token file must contain only the token');
  return token;
}

async function waitUntil(operation, description, timeout = EVENT_TIMEOUT_MS) {
  const deadline = Date.now() + timeout;
  let lastValue;

  while (Date.now() < deadline) {
    lastValue = await operation();
    if (lastValue) {
      return lastValue;
    }
    await sleep(200);
  }

  throw new Error(`Timed out waiting for ${description}`);
}

async function connectActionCable(baseUrl, user, accountId) {
  const cableUrl = new URL('/cable', baseUrl);
  cableUrl.protocol = 'wss:';
  const identifier = JSON.stringify({
    channel: 'RoomChannel',
    pubsub_token: user.pubsubToken,
    account_id: accountId,
    user_id: user.id,
  });
  const events = [];
  const socket = new WebSocket(cableUrl, ['actioncable-v1-json']);

  await new Promise((resolvePromise, rejectPromise) => {
    const timeout = setTimeout(() => {
      rejectPromise(
        new Error(`Timed out subscribing ${user.key} to ActionCable`)
      );
    }, EVENT_TIMEOUT_MS);

    const fail = message => {
      clearTimeout(timeout);
      rejectPromise(new Error(message));
    };

    socket.addEventListener('error', () => {
      fail(`ActionCable connection failed for ${user.key}`);
    });
    socket.addEventListener('close', event => {
      if (event.code !== 1000) {
        fail(
          `ActionCable closed for ${user.key} with code ${event.code || 'unknown'}`
        );
      }
    });
    socket.addEventListener('message', event => {
      let payload;
      try {
        payload = JSON.parse(String(event.data));
      } catch {
        return;
      }

      if (payload.type === 'welcome') {
        socket.send(JSON.stringify({ command: 'subscribe', identifier }));
      } else if (
        payload.type === 'confirm_subscription' &&
        payload.identifier === identifier
      ) {
        clearTimeout(timeout);
        resolvePromise();
      } else if (payload.type === 'reject_subscription') {
        fail(`ActionCable rejected the subscription for ${user.key}`);
      } else if (payload.message?.event) {
        events.push(payload.message);
      }
    });
  });

  return {
    events,
    clear: () => events.splice(0, events.length),
    close: () => socket.close(1000, 'smoke complete'),
  };
}

async function attestDeploySha(baseUrl, expectedSha) {
  const response = await fetch(new URL('/app/login', baseUrl), {
    redirect: 'error',
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  assert(
    response.ok,
    `Deployment attestation returned HTTP ${response.status}`
  );
  const html = await response.text();
  const observedSha = html.match(/"GIT_SHA":"([0-9a-f]{40})"/)?.[1];
  assert(observedSha, 'Deployment page did not expose a full GIT_SHA');
  assert(
    observedSha === expectedSha,
    `Deployment SHA mismatch: expected ${expectedSha}, observed ${observedSha}`
  );
  return observedSha;
}

function createClient(baseUrl) {
  return async function request(
    path,
    { method = 'GET', token, body, expected = [200] } = {}
  ) {
    const url = new URL(path, baseUrl);
    const headers = {
      Accept: 'application/json',
      'User-Agent': 'centraldeatendimentochat-strict-privacy-smoke/1',
    };

    if (token) {
      headers['api-access-token'] = token;
    }
    if (body !== undefined) {
      headers['Content-Type'] = 'application/json';
    }

    let response;
    try {
      response = await fetch(url, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
        redirect: 'error',
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });
    } catch (error) {
      throw new Error(
        `${method} ${url.pathname} failed before receiving an HTTP response: ${error.message}`
      );
    }

    const text = await response.text();
    if (!expected.includes(response.status)) {
      throw new Error(
        `${method} ${url.pathname} returned unexpected HTTP ${response.status}`
      );
    }

    if (!text) {
      return { status: response.status, data: null };
    }

    try {
      return { status: response.status, data: JSON.parse(text) };
    } catch {
      throw new Error(`${method} ${url.pathname} returned a non-JSON response`);
    }
  };
}

async function pollDeleted(request, resources, platformToken) {
  const deadline = Date.now() + CLEANUP_TIMEOUT_MS;
  const remaining = new Map(
    resources.map(resource => [resource.key, resource])
  );

  while (remaining.size > 0 && Date.now() < deadline) {
    for (const [key, resource] of remaining) {
      const response = await request(resource.path, {
        token: platformToken,
        expected: [200, 404],
      });
      if (response.status === 404) {
        remaining.delete(key);
      }
    }

    if (remaining.size > 0) {
      await sleep(1_500);
    }
  }

  return [...remaining.keys()];
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const baseUrl = validateOptions(options);
  const platformToken = await readToken(options['platform-token-file']);
  const request = createClient(baseUrl);
  const startedAt = new Date().toISOString();
  const runId = `${startedAt.replaceAll(/[-:.TZ]/g, '').slice(0, 14)}-${randomBytes(4).toString('hex')}`;
  const marker = `strict-privacy-smoke-${runId}`;
  const reportPath = resolve(options['report-file']);
  const resources = {
    accountId: null,
    users: [],
    cables: [],
  };
  const checks = [];
  const findings = [];
  const cleanup = {
    requested: false,
    verified: false,
    pending_resources: [],
    platform_app_revocation_required: true,
  };
  let outcome = 'failed';
  let failure = null;

  const record = async (name, operation) => {
    process.stdout.write(`[smoke] ${name} ... `);
    const detail = await operation();
    checks.push({ name, status: 'passed', detail });
    process.stdout.write('OK\n');
  };

  const recordFinding = async (name, operation) => {
    process.stdout.write(`[smoke] ${name} ... `);
    const result = await operation();
    const status = result.passed ? 'passed' : 'failed';
    checks.push({ name, status, detail: result.detail });
    if (!result.passed) {
      findings.push(name);
    }
    process.stdout.write(result.passed ? 'OK\n' : 'FINDING\n');
  };

  const platform = (path, optionsForRequest = {}) =>
    request(path, { ...optionsForRequest, token: platformToken });

  try {
    process.stdout.write(`[smoke] run ${runId} against ${baseUrl}\n`);

    await record(
      'production deployment SHA matches the requested target',
      async () => ({
        observed_deploy_sha: await attestDeploySha(
          baseUrl,
          options['expected-deploy-sha']
        ),
      })
    );

    const accountResponse = await platform('/platform/api/v1/accounts', {
      method: 'POST',
      body: {
        name: `Smoke Privacidade ${runId}`,
        locale: 'pt_BR',
        custom_attributes: {
          purpose: 'strict_team_conversation_visibility_smoke',
          run_id: runId,
        },
        features: {
          [FEATURE]: true,
          [UNREAD_FEATURE]: true,
        },
      },
    });
    resources.accountId = Number(accountResponse.data.id);
    assert(
      resources.accountId > 0,
      'Platform account creation did not return an id'
    );
    assert(
      featureEnabled(accountResponse.data.features, FEATURE),
      `Feature ${FEATURE} was not enabled on the smoke account`
    );

    const password = () => `Aa1!${randomBytes(18).toString('base64url')}`;
    const userDefinitions = [
      { key: 'admin', name: 'Smoke Admin', role: 'administrator' },
      { key: 'agentA', name: 'Smoke Agente Setor A', role: 'agent' },
      { key: 'agentB', name: 'Smoke Agente Setor B', role: 'agent' },
    ];

    for (const definition of userDefinitions) {
      const userResponse = await platform('/platform/api/v1/users', {
        method: 'POST',
        body: {
          name: definition.name,
          email: `${definition.key}.${runId}@example.invalid`,
          password: password(),
          custom_attributes: {
            purpose: 'strict_team_conversation_visibility_smoke',
            run_id: runId,
          },
        },
      });
      const user = {
        ...definition,
        id: Number(userResponse.data.id),
        token: userResponse.data.access_token,
      };
      assert(
        user.id > 0 &&
          typeof user.token === 'string' &&
          user.token.length >= 20,
        `Invalid ${definition.key} user response`
      );
      resources.users.push(user);

      await platform(
        `/platform/api/v1/accounts/${resources.accountId}/account_users`,
        {
          method: 'POST',
          body: {
            user_id: user.id,
            role: user.role,
          },
        }
      );
    }

    const admin = resources.users.find(user => user.key === 'admin');
    const agentA = resources.users.find(user => user.key === 'agentA');
    const agentB = resources.users.find(user => user.key === 'agentB');
    const accountPath = `/api/v1/accounts/${resources.accountId}`;

    await record(
      'three authenticated identities belong to the isolated account',
      async () => {
        for (const user of resources.users) {
          const profile = await request('/api/v1/profile', {
            token: user.token,
          });
          const accountIds = (profile.data.accounts || []).map(account =>
            Number(account.id)
          );
          assert(
            accountIds.includes(resources.accountId),
            `${user.key} profile does not include the smoke account`
          );
          user.pubsubToken = profile.data.pubsub_token;
          assert(
            typeof user.pubsubToken === 'string' &&
              user.pubsubToken.length >= 20,
            `${user.key} profile does not include a pubsub token`
          );
        }
        return { identities: 3, roles: ['administrator', 'agent', 'agent'] };
      }
    );

    const teamAResponse = await request(`${accountPath}/teams`, {
      method: 'POST',
      token: admin.token,
      body: { team: { name: `Setor A ${runId}`, allow_auto_assign: false } },
    });
    const teamBResponse = await request(`${accountPath}/teams`, {
      method: 'POST',
      token: admin.token,
      body: { team: { name: `Setor B ${runId}`, allow_auto_assign: false } },
    });
    const teamAId = Number(teamAResponse.data.id);
    const teamBId = Number(teamBResponse.data.id);

    await request(`${accountPath}/teams/${teamAId}/team_members`, {
      method: 'POST',
      token: admin.token,
      body: { user_ids: [agentA.id] },
    });
    await request(`${accountPath}/teams/${teamBId}/team_members`, {
      method: 'POST',
      token: admin.token,
      body: { user_ids: [agentB.id] },
    });

    const inboxResponse = await request(`${accountPath}/inboxes`, {
      method: 'POST',
      token: admin.token,
      body: {
        name: `Caixa Unica ${runId}`,
        enable_auto_assignment: false,
        channel: {
          type: 'api',
          webhook_url: '',
        },
      },
    });
    const inboxId = Number(inboxResponse.data.id);
    assert(inboxId > 0, 'Inbox creation did not return an id');

    await request(`${accountPath}/inbox_members`, {
      method: 'POST',
      token: admin.token,
      body: {
        inbox_id: inboxId,
        user_ids: [agentA.id, agentB.id],
      },
    });

    await record(
      'both agents share one inbox but belong to different teams',
      async () => ({
        inboxes: 1,
        teams: 2,
        agents_in_shared_inbox: 2,
        agents_per_team: 1,
      })
    );

    for (const agent of [agentA, agentB]) {
      resources.cables.push({
        key: agent.key,
        client: await connectActionCable(baseUrl, agent, resources.accountId),
      });
    }
    await sleep(500);
    resources.cables.forEach(resource => resource.client.clear());

    const conversations = {};
    for (const definition of [
      { key: 'teamA', teamId: teamAId },
      { key: 'teamB', teamId: teamBId },
      { key: 'unassigned', teamId: null },
    ]) {
      const sourceId = `${marker}-${definition.key}-${randomBytes(8).toString('hex')}`;
      const contactResponse = await request(`${accountPath}/contacts`, {
        method: 'POST',
        token: admin.token,
        body: {
          name: `${marker}-${definition.key}`,
          identifier: sourceId,
          inbox_id: inboxId,
          source_id: sourceId,
        },
      });
      const contactId = Number(contactResponse.data?.payload?.contact?.id);
      assert(
        contactId > 0,
        `${definition.key} contact creation did not return an id`
      );

      const conversationBody = {
        source_id: sourceId,
        status: 'open',
        message: {
          content: `${marker} ${definition.key}`,
          message_type: 'incoming',
        },
      };
      if (definition.teamId) {
        conversationBody.team_id = definition.teamId;
      }

      const conversationResponse = await request(
        `${accountPath}/conversations`,
        {
          method: 'POST',
          token: admin.token,
          body: conversationBody,
        }
      );
      conversations[definition.key] = {
        id: Number(conversationResponse.data.id),
        contactId,
        sourceId,
      };
      assert(
        conversations[definition.key].id > 0,
        `${definition.key} conversation creation did not return an id`
      );
    }

    const cableFor = key =>
      resources.cables.find(resource => resource.key === key).client;
    const conversationEventIds = client =>
      client.events
        .filter(event => event.event === 'conversation.created')
        .map(event => Number(event.data?.id));

    await record(
      'real-time conversation creation events do not leak across teams',
      async () => {
        await waitUntil(
          () =>
            conversationEventIds(cableFor('agentA')).includes(
              conversations.teamA.id
            ) &&
            conversationEventIds(cableFor('agentB')).includes(
              conversations.teamB.id
            ),
          'isolated conversation.created events'
        );
        await sleep(1_500);
        assertExactIds(
          conversationEventIds(cableFor('agentA')),
          [conversations.teamA.id],
          'team A real-time conversation events'
        );
        assertExactIds(
          conversationEventIds(cableFor('agentB')),
          [conversations.teamB.id],
          'team B real-time conversation events'
        );
        return {
          action_cable_subscriptions: 2,
          team_a_events: 1,
          team_b_events: 1,
          leaked_events: 0,
        };
      }
    );

    const listIds = async token => {
      const response = await request(
        `${accountPath}/conversations?status=all`,
        { token }
      );
      return conversationIds(response.data);
    };
    const searchIds = async token => {
      const response = await request(
        `${accountPath}/conversations/search?status=all&q=${encodeURIComponent(marker)}`,
        { token }
      );
      return conversationIds(response.data);
    };
    const listContactIds = async token => {
      const response = await request(
        `${accountPath}/contacts?include_contact_inboxes=false`,
        { token }
      );
      return contactIds(response.data);
    };
    const searchContactIds = async token => {
      const response = await request(
        `${accountPath}/contacts/search?include_contact_inboxes=false&q=${encodeURIComponent(marker)}`,
        { token }
      );
      return contactIds(response.data);
    };
    const getUnreadCounts = async token => {
      const response = await request(
        `${accountPath}/conversations/unread_counts`,
        {
          token,
        }
      );
      return unreadCounts(response.data);
    };
    const getNotificationConversationIds = async token => {
      const response = await request(`${accountPath}/notifications`, { token });
      return notificationConversationIds(response.data);
    };
    const getContactLabels = async contactId => {
      const response = await request(
        `${accountPath}/contacts/${contactId}/labels`,
        { token: admin.token }
      );
      assert(
        Array.isArray(response.data?.payload),
        'Contact labels response did not contain payload'
      );
      return response.data.payload;
    };
    const getParticipantIds = async conversationId => {
      const response = await request(
        `${accountPath}/conversations/${conversationId}/participants`,
        { token: admin.token }
      );
      assert(
        Array.isArray(response.data),
        'Conversation participants response was not an array'
      );
      return response.data.map(participant => Number(participant.id));
    };
    const eventCount = (client, eventName) =>
      client.events.filter(event => event.event === eventName).length;
    const waitForEvent = async (client, eventName, description) =>
      waitUntil(
        () => eventCount(client, eventName) > 0,
        description || eventName
      );
    const expectDenied = async (path, token, requestOptions = {}) => {
      const response = await request(path, {
        ...requestOptions,
        token,
        expected: [401, 403, 404],
      });
      return response.status;
    };

    await record(
      'strict list visibility isolates each team and hides unassigned conversations',
      async () => {
        assertExactIds(
          await listIds(admin.token),
          [
            conversations.teamA.id,
            conversations.teamB.id,
            conversations.unassigned.id,
          ],
          'administrator list'
        );
        assertExactIds(
          await listIds(agentA.token),
          [conversations.teamA.id],
          'team A list'
        );
        assertExactIds(
          await listIds(agentB.token),
          [conversations.teamB.id],
          'team B list'
        );
        return {
          administrator_visible: 3,
          team_a_visible: 1,
          team_b_visible: 1,
          unassigned_agent_visible: 0,
        };
      }
    );

    await record(
      'strict unread counts match visible conversations',
      async () => {
        const adminCounts = await getUnreadCounts(admin.token);
        const teamACounts = await getUnreadCounts(agentA.token);
        const teamBCounts = await getUnreadCounts(agentB.token);
        assert(
          adminCounts.all_count === 3,
          'administrator unread count must be 3'
        );
        assert(teamACounts.all_count === 1, 'team A unread count must be 1');
        assert(teamBCounts.all_count === 1, 'team B unread count must be 1');
        assert(
          teamACounts.inboxes?.[String(inboxId)] === 1 &&
            teamACounts.teams?.[String(teamAId)] === 1,
          'team A unread breakdown is not isolated'
        );
        assert(
          teamBCounts.inboxes?.[String(inboxId)] === 1 &&
            teamBCounts.teams?.[String(teamBId)] === 1,
          'team B unread breakdown is not isolated'
        );
        return {
          administrator_unread: 3,
          team_a_unread: 1,
          team_b_unread: 1,
        };
      }
    );

    await record(
      'strict direct access blocks cross-team and unassigned conversations',
      async () => {
        const statuses = [
          await expectDenied(
            `${accountPath}/conversations/${conversations.teamB.id}`,
            agentA.token
          ),
          await expectDenied(
            `${accountPath}/conversations/${conversations.teamA.id}`,
            agentB.token
          ),
          await expectDenied(
            `${accountPath}/conversations/${conversations.unassigned.id}`,
            agentA.token
          ),
          await expectDenied(
            `${accountPath}/conversations/${conversations.unassigned.id}`,
            agentB.token
          ),
        ];
        return {
          denied_requests: statuses.length,
          observed_statuses: [...new Set(statuses)].sort(),
        };
      }
    );

    await record(
      'strict search does not leak cross-team conversations',
      async () => {
        assertExactIds(
          await searchIds(agentA.token),
          [conversations.teamA.id],
          'team A search'
        );
        assertExactIds(
          await searchIds(agentB.token),
          [conversations.teamB.id],
          'team B search'
        );
        return { team_a_search_results: 1, team_b_search_results: 1 };
      }
    );

    await record(
      'strict contact access follows conversation visibility',
      async () => {
        await request(
          `${accountPath}/contacts/${conversations.teamA.contactId}`,
          { token: agentA.token }
        );
        await request(
          `${accountPath}/contacts/${conversations.teamB.contactId}`,
          { token: agentB.token }
        );
        const statuses = [
          await expectDenied(
            `${accountPath}/contacts/${conversations.teamB.contactId}`,
            agentA.token
          ),
          await expectDenied(
            `${accountPath}/contacts/${conversations.teamA.contactId}`,
            agentB.token
          ),
          await expectDenied(
            `${accountPath}/contacts/${conversations.unassigned.contactId}`,
            agentA.token
          ),
        ];
        return { allowed_requests: 2, denied_requests: statuses.length };
      }
    );

    await record(
      'contact lists, searches and contact-inbox lookup respect team visibility',
      async () => {
        assertExactIds(
          await listContactIds(agentA.token),
          [conversations.teamA.contactId],
          'team A contact list'
        );
        assertExactIds(
          await listContactIds(agentB.token),
          [conversations.teamB.contactId],
          'team B contact list'
        );
        assertExactIds(
          await searchContactIds(agentA.token),
          [conversations.teamA.contactId],
          'team A contact search'
        );
        assertExactIds(
          await searchContactIds(agentB.token),
          [conversations.teamB.contactId],
          'team B contact search'
        );

        const ownLookup = await request(
          `${accountPath}/contact_inboxes/filter`,
          {
            method: 'POST',
            token: agentA.token,
            body: {
              inbox_id: inboxId,
              source_id: conversations.teamA.sourceId,
            },
          }
        );
        assert(
          Number(ownLookup.data?.id) === conversations.teamA.contactId,
          'team A contact-inbox lookup did not return its own contact'
        );
        await request(`${accountPath}/contact_inboxes/filter`, {
          method: 'POST',
          token: agentA.token,
          body: {
            inbox_id: inboxId,
            source_id: conversations.teamB.sourceId,
          },
          expected: [404],
        });
        return {
          list_checks: 2,
          search_checks: 2,
          own_source_lookup: 'allowed',
          cross_team_source_lookup: 'denied',
        };
      }
    );

    await record(
      'cross-team contact merge and direct-upload authorization are blocked',
      async () => {
        const mergeStatus = await expectDenied(
          `${accountPath}/actions/contact_merge`,
          agentA.token,
          {
            method: 'POST',
            body: {
              base_contact_id: conversations.teamA.contactId,
              mergee_contact_id: conversations.teamB.contactId,
            },
          }
        );
        const uploadResponse = await request(
          `${accountPath}/conversations/${conversations.teamB.id}/direct_uploads`,
          {
            method: 'POST',
            token: agentA.token,
            body: { blob: {} },
            expected: [204, 401, 403, 404],
          }
        );
        assert(
          uploadResponse.data === null,
          'cross-team direct upload returned upload credentials'
        );
        return {
          cross_team_merge_status: mergeStatus,
          cross_team_upload_status: uploadResponse.status,
          upload_credentials_issued: false,
        };
      }
    );

    await record(
      'strict assignment accepts eligible agents and rejects cross-team agents',
      async () => {
        const teamAAssignment = await request(
          `${accountPath}/conversations/${conversations.teamA.id}/assignments`,
          {
            method: 'POST',
            token: admin.token,
            body: { assignee_id: agentA.id },
          }
        );
        const teamBAssignment = await request(
          `${accountPath}/conversations/${conversations.teamB.id}/assignments`,
          {
            method: 'POST',
            token: admin.token,
            body: { assignee_id: agentB.id },
          }
        );
        assert(
          Number(teamAAssignment.data?.id) === agentA.id &&
            Number(teamBAssignment.data?.id) === agentB.id,
          'eligible assignment did not return the expected agents'
        );

        const invalidAssignment = await request(
          `${accountPath}/conversations/${conversations.teamA.id}/assignments`,
          {
            method: 'POST',
            token: admin.token,
            body: { assignee_id: agentB.id },
            expected: [404, 422],
          }
        );
        const teamAConversation = await request(
          `${accountPath}/conversations/${conversations.teamA.id}`,
          { token: admin.token }
        );
        assert(
          Number(teamAConversation.data?.meta?.assignee?.id) === agentA.id,
          'rejected cross-team assignment changed the current assignee'
        );

        await waitUntil(
          async () =>
            (await getNotificationConversationIds(agentA.token)).includes(
              conversations.teamA.id
            ) &&
            (await getNotificationConversationIds(agentB.token)).includes(
              conversations.teamB.id
            ),
          'assignment notifications'
        );
        assertExactIds(
          await getNotificationConversationIds(agentA.token),
          [conversations.teamA.id],
          'team A notifications'
        );
        assertExactIds(
          await getNotificationConversationIds(agentB.token),
          [conversations.teamB.id],
          'team B notifications'
        );
        return {
          eligible_assignments: 2,
          rejected_cross_team_status: invalidAssignment.status,
          notifications_isolated: true,
        };
      }
    );

    await record(
      'agents can reply only to conversations currently visible to them',
      async () => {
        await request(
          `${accountPath}/conversations/${conversations.teamA.id}/messages`,
          {
            method: 'POST',
            token: agentA.token,
            body: {
              content: `${marker} resposta humana setor A`,
              message_type: 'outgoing',
              private: false,
            },
          }
        );
        await request(
          `${accountPath}/conversations/${conversations.teamB.id}/messages`,
          {
            method: 'POST',
            token: agentB.token,
            body: {
              content: `${marker} resposta humana setor B`,
              message_type: 'outgoing',
              private: false,
            },
          }
        );
        const crossStatus = await expectDenied(
          `${accountPath}/conversations/${conversations.teamB.id}/messages`,
          agentA.token,
          {
            method: 'POST',
            body: {
              content: `${marker} resposta cruzada bloqueada`,
              message_type: 'outgoing',
              private: false,
            },
          }
        );
        return {
          own_team_replies_created: 2,
          cross_team_reply_status: crossStatus,
        };
      }
    );

    await recordFinding(
      'team transfer revokes old access and grants new access immediately',
      async () => {
        const participantIdsBeforeTransfer = await waitUntil(async () => {
          const ids = await getParticipantIds(conversations.teamA.id);
          return ids.includes(agentA.id) ? ids : null;
        }, 'assigned agent participation before transfer');
        cableFor('agentA').clear();
        cableFor('agentB').clear();
        await request(
          `${accountPath}/conversations/${conversations.teamA.id}/assignments`,
          {
            method: 'POST',
            token: admin.token,
            body: { team_id: teamBId },
          }
        );
        const teamAIdsAfterTransfer = await listIds(agentA.token);
        const transferredConversation = await request(
          `${accountPath}/conversations/${conversations.teamA.id}`,
          { token: admin.token }
        );
        const transferredAssigneeId = Number(
          transferredConversation.data?.meta?.assignee?.id
        );
        const participantIdsAfterTransfer = await getParticipantIds(
          conversations.teamA.id
        );
        const oldTeamAccessRevoked = !teamAIdsAfterTransfer.includes(
          conversations.teamA.id
        );
        const incompatibleAssigneeCleared = transferredAssigneeId !== agentA.id;
        assertExactIds(
          await listIds(agentB.token),
          [conversations.teamA.id, conversations.teamB.id],
          'team B list after transfer'
        );
        await request(
          `${accountPath}/conversations/${conversations.teamA.id}`,
          { token: agentB.token }
        );
        await waitForEvent(
          cableFor('agentB'),
          'team.changed',
          'team B real-time grant after transfer'
        );

        if (oldTeamAccessRevoked) {
          await expectDenied(
            `${accountPath}/conversations/${conversations.teamA.id}`,
            agentA.token
          );
          await waitForEvent(
            cableFor('agentA'),
            'page:reload',
            'team A real-time revocation after transfer'
          );
        } else {
          if (!incompatibleAssigneeCleared) {
            await request(
              `${accountPath}/conversations/${conversations.teamA.id}/assignments`,
              {
                method: 'POST',
                token: admin.token,
                body: { assignee_id: null },
              }
            );
          }
          if (participantIdsAfterTransfer.includes(agentA.id)) {
            await request(
              `${accountPath}/conversations/${conversations.teamA.id}/participants`,
              {
                method: 'DELETE',
                token: admin.token,
                body: { user_ids: [agentA.id] },
              }
            );
          }
          await expectDenied(
            `${accountPath}/conversations/${conversations.teamA.id}`,
            agentA.token
          );
          await waitForEvent(
            cableFor('agentA'),
            'page:reload',
            'team A real-time revocation after explicit visibility cleanup'
          );
        }
        assertExactIds(
          await listIds(agentA.token),
          [],
          'team A list after transfer normalization'
        );
        assertExactIds(
          await getNotificationConversationIds(agentA.token),
          [],
          'team A notifications after transfer'
        );
        assertExactIds(
          await getNotificationConversationIds(agentB.token),
          [conversations.teamB.id],
          'team B notifications after transfer'
        );
        await request(
          `${accountPath}/conversations/${conversations.teamA.id}/messages`,
          {
            method: 'POST',
            token: agentB.token,
            body: {
              content: `${marker} resposta após transferência para setor B`,
              message_type: 'outgoing',
              private: false,
            },
          }
        );

        cableFor('agentA').clear();
        cableFor('agentB').clear();
        await request(
          `${accountPath}/conversations/${conversations.teamA.id}/assignments`,
          {
            method: 'POST',
            token: admin.token,
            body: { team_id: teamAId },
          }
        );
        assertExactIds(
          await listIds(agentA.token),
          [conversations.teamA.id],
          'team A list after transfer restore'
        );
        assertExactIds(
          await listIds(agentB.token),
          [conversations.teamB.id],
          'team B list after transfer restore'
        );
        await waitForEvent(
          cableFor('agentB'),
          'page:reload',
          'team B real-time revocation after transfer restore'
        );
        await waitForEvent(
          cableFor('agentA'),
          'team.changed',
          'team A real-time grant after transfer restore'
        );
        assertExactIds(
          await getNotificationConversationIds(agentA.token),
          [conversations.teamA.id],
          'team A notifications after transfer restore'
        );
        return {
          passed: oldTeamAccessRevoked,
          detail: {
            assigned_agent_was_participant_before_transfer:
              participantIdsBeforeTransfer.includes(agentA.id),
            incompatible_assignee_cleared_automatically:
              incompatibleAssigneeCleared,
            participant_retained_after_transfer:
              participantIdsAfterTransfer.includes(agentA.id),
            transferred_assignee_id:
              Number.isInteger(transferredAssigneeId) &&
              transferredAssigneeId > 0
                ? transferredAssigneeId
                : null,
            explicit_normalization_required: !oldTeamAccessRevoked,
            revoked_from_old_team_automatically: oldTeamAccessRevoked,
            revoked_after_normalization: true,
            granted_to_new_team: true,
            original_state_restored: true,
            realtime_revocation_events: 2,
            transferred_team_reply_created: true,
            stale_notification_hidden: true,
          },
        };
      }
    );

    await recordFinding(
      'direct assignee exception grants and then revokes unassigned access',
      async () => {
        cableFor('agentA').clear();
        await request(
          `${accountPath}/conversations/${conversations.unassigned.id}/assignments`,
          {
            method: 'POST',
            token: admin.token,
            body: { assignee_id: agentA.id },
          }
        );
        assertExactIds(
          await listIds(agentA.token),
          [conversations.teamA.id, conversations.unassigned.id],
          'team A list with direct assignment exception'
        );
        assert(
          (await getUnreadCounts(agentA.token)).all_count === 2,
          'team A unread count did not include direct assignment exception'
        );
        await waitUntil(
          async () =>
            (await getNotificationConversationIds(agentA.token)).includes(
              conversations.unassigned.id
            ),
          'direct assignment notification'
        );

        cableFor('agentA').clear();
        await request(
          `${accountPath}/conversations/${conversations.unassigned.id}/assignments`,
          {
            method: 'POST',
            token: admin.token,
            body: { assignee_id: null },
          }
        );
        const idsAfterUnassignment = await listIds(agentA.token);
        const participantIdsAfterUnassignment = await getParticipantIds(
          conversations.unassigned.id
        );
        const accessRevokedAutomatically = !idsAfterUnassignment.includes(
          conversations.unassigned.id
        );
        if (!accessRevokedAutomatically) {
          await request(
            `${accountPath}/conversations/${conversations.unassigned.id}/participants`,
            {
              method: 'DELETE',
              token: admin.token,
              body: { user_ids: [agentA.id] },
            }
          );
        }
        assertExactIds(
          await listIds(agentA.token),
          [conversations.teamA.id],
          'team A list after direct assignment removal'
        );
        assert(
          (await getUnreadCounts(agentA.token)).all_count === 1,
          'team A unread count retained revoked direct assignment'
        );
        await waitForEvent(
          cableFor('agentA'),
          'page:reload',
          'direct assignment real-time revocation'
        );
        assertExactIds(
          await getNotificationConversationIds(agentA.token),
          [conversations.teamA.id],
          'team A notifications after direct assignment removal'
        );
        return {
          passed: accessRevokedAutomatically,
          detail: {
            assigned_exception_visible: true,
            access_revoked_automatically: accessRevokedAutomatically,
            participant_retained_after_unassignment:
              participantIdsAfterUnassignment.includes(agentA.id),
            explicit_participant_removal_required: !accessRevokedAutomatically,
            removal_revoked_access_after_normalization: true,
            unread_counts_updated: true,
            stale_notification_hidden: true,
            realtime_reload_received: true,
          },
        };
      }
    );

    await record(
      'participant exception grants and then revokes unassigned access',
      async () => {
        cableFor('agentB').clear();
        await request(
          `${accountPath}/conversations/${conversations.unassigned.id}/participants`,
          {
            method: 'POST',
            token: admin.token,
            body: { user_ids: [agentB.id] },
          }
        );
        assertExactIds(
          await listIds(agentB.token),
          [conversations.teamB.id, conversations.unassigned.id],
          'team B list with participant exception'
        );
        await request(
          `${accountPath}/conversations/${conversations.unassigned.id}`,
          { token: agentB.token }
        );
        assert(
          (await getUnreadCounts(agentB.token)).all_count === 2,
          'team B unread count did not include participant exception'
        );
        await waitForEvent(
          cableFor('agentB'),
          'page:reload',
          'participant real-time grant'
        );

        cableFor('agentB').clear();
        await request(
          `${accountPath}/conversations/${conversations.unassigned.id}/participants`,
          {
            method: 'DELETE',
            token: admin.token,
            body: { user_ids: [agentB.id] },
          }
        );
        assertExactIds(
          await listIds(agentB.token),
          [conversations.teamB.id],
          'team B list after participant removal'
        );
        await expectDenied(
          `${accountPath}/conversations/${conversations.unassigned.id}`,
          agentB.token
        );
        assert(
          (await getUnreadCounts(agentB.token)).all_count === 1,
          'team B unread count retained revoked participant conversation'
        );
        await waitForEvent(
          cableFor('agentB'),
          'page:reload',
          'participant real-time revocation'
        );
        return {
          participant_exception_visible: true,
          removal_revoked_access: true,
          unread_counts_updated: true,
          realtime_reload_events: 2,
        };
      }
    );

    await record(
      'team and inbox membership changes refresh visibility immediately',
      async () => {
        cableFor('agentA').clear();
        await request(`${accountPath}/teams/${teamAId}/team_members`, {
          method: 'DELETE',
          token: admin.token,
          body: { user_ids: [agentA.id] },
        });
        assertExactIds(
          await listIds(agentA.token),
          [],
          'team A member removal'
        );
        assert(
          (await getUnreadCounts(agentA.token)).all_count === 0,
          'team removal did not clear unread count'
        );
        await waitForEvent(
          cableFor('agentA'),
          'page:reload',
          'team member removal reload'
        );

        cableFor('agentA').clear();
        await request(`${accountPath}/teams/${teamAId}/team_members`, {
          method: 'POST',
          token: admin.token,
          body: { user_ids: [agentA.id] },
        });
        assertExactIds(
          await listIds(agentA.token),
          [conversations.teamA.id],
          'team A member re-addition'
        );
        assert(
          (await getUnreadCounts(agentA.token)).all_count === 1,
          'team re-addition did not restore unread count'
        );
        await waitForEvent(
          cableFor('agentA'),
          'page:reload',
          'team member re-addition reload'
        );

        cableFor('agentA').clear();
        await request(`${accountPath}/inbox_members`, {
          method: 'DELETE',
          token: admin.token,
          body: { inbox_id: inboxId, user_ids: [agentA.id] },
        });
        assertExactIds(await listIds(agentA.token), [], 'inbox member removal');
        assert(
          (await getUnreadCounts(agentA.token)).all_count === 0,
          'inbox removal did not clear unread count'
        );
        await waitForEvent(
          cableFor('agentA'),
          'page:reload',
          'inbox member removal reload'
        );

        cableFor('agentA').clear();
        await request(`${accountPath}/inbox_members`, {
          method: 'POST',
          token: admin.token,
          body: { inbox_id: inboxId, user_ids: [agentA.id] },
        });
        assertExactIds(
          await listIds(agentA.token),
          [conversations.teamA.id],
          'inbox member re-addition'
        );
        assert(
          (await getUnreadCounts(agentA.token)).all_count === 1,
          'inbox re-addition did not restore unread count'
        );
        await waitForEvent(
          cableFor('agentA'),
          'page:reload',
          'inbox member re-addition reload'
        );
        return {
          team_remove_and_restore: 'passed',
          inbox_remove_and_restore: 'passed',
          unread_transitions: [0, 1, 0, 1],
          realtime_reload_events: 4,
        };
      }
    );

    await record(
      'bulk contact labels affect only contacts visible to the requesting agent',
      async () => {
        const labelTitle = `smoke-${runId}`;
        await request(`${accountPath}/bulk_actions`, {
          method: 'POST',
          token: agentA.token,
          body: {
            type: 'Contact',
            ids: [conversations.teamA.contactId, conversations.teamB.contactId],
            labels: { add: [labelTitle] },
          },
        });
        await waitUntil(
          async () =>
            (await getContactLabels(conversations.teamA.contactId)).includes(
              labelTitle
            ),
          'visible contact bulk label assignment'
        );
        assert(
          !(await getContactLabels(conversations.teamB.contactId)).includes(
            labelTitle
          ),
          'bulk action labeled a cross-team contact'
        );

        await request(`${accountPath}/bulk_actions`, {
          method: 'POST',
          token: agentA.token,
          body: {
            type: 'Contact',
            ids: [conversations.teamA.contactId, conversations.teamB.contactId],
            labels: { remove: [labelTitle] },
          },
        });
        await waitUntil(
          async () =>
            !(await getContactLabels(conversations.teamA.contactId)).includes(
              labelTitle
            ),
          'visible contact bulk label removal'
        );
        return {
          requested_contacts: 2,
          visible_contacts_changed: 1,
          cross_team_contacts_changed: 0,
          label_removed_after_check: true,
        };
      }
    );

    await record(
      'feature rollback restores legacy shared-inbox visibility',
      async () => {
        const disableResponse = await platform(
          `/platform/api/v1/accounts/${resources.accountId}`,
          {
            method: 'PATCH',
            body: { features: { [FEATURE]: false } },
          }
        );
        assert(
          !featureEnabled(disableResponse.data.features, FEATURE),
          `Feature ${FEATURE} remained enabled after rollback`
        );
        const allIds = [
          conversations.teamA.id,
          conversations.teamB.id,
          conversations.unassigned.id,
        ];
        assertExactIds(
          await listIds(agentA.token),
          allIds,
          'team A list with feature disabled'
        );
        assertExactIds(
          await listIds(agentB.token),
          allIds,
          'team B list with feature disabled'
        );
        await request(
          `${accountPath}/conversations/${conversations.teamB.id}`,
          { token: agentA.token }
        );
        await request(
          `${accountPath}/conversations/${conversations.teamA.id}`,
          { token: agentB.token }
        );
        return { feature_enabled: false, team_a_visible: 3, team_b_visible: 3 };
      }
    );

    await record('feature reactivation restores strict isolation', async () => {
      const enableResponse = await platform(
        `/platform/api/v1/accounts/${resources.accountId}`,
        {
          method: 'PATCH',
          body: { features: { [FEATURE]: true } },
        }
      );
      assert(
        featureEnabled(enableResponse.data.features, FEATURE),
        `Feature ${FEATURE} was not re-enabled`
      );
      assertExactIds(
        await listIds(agentA.token),
        [conversations.teamA.id],
        'team A list after reactivation'
      );
      assertExactIds(
        await listIds(agentB.token),
        [conversations.teamB.id],
        'team B list after reactivation'
      );
      await expectDenied(
        `${accountPath}/conversations/${conversations.teamB.id}`,
        agentA.token
      );
      await expectDenied(
        `${accountPath}/conversations/${conversations.teamA.id}`,
        agentB.token
      );
      return { feature_enabled: true, team_a_visible: 1, team_b_visible: 1 };
    });

    if (findings.length > 0) {
      outcome = 'failed';
      failure = `${findings.length} product finding(s): ${findings.join('; ')}`;
    } else {
      outcome = 'passed';
    }
  } catch (error) {
    failure = error instanceof Error ? error.message : String(error);
    process.stderr.write(`[smoke] FAILED: ${failure}\n`);
  } finally {
    for (const resource of resources.cables) {
      resource.client.close();
    }
    cleanup.requested = true;
    process.stdout.write('[smoke] cleanup temporary account and users ... ');

    try {
      const pendingResources = [];
      if (resources.accountId) {
        await platform(`/platform/api/v1/accounts/${resources.accountId}`, {
          method: 'DELETE',
          expected: [200, 202, 204, 404],
        });
        pendingResources.push({
          key: `account:${resources.accountId}`,
          path: `/platform/api/v1/accounts/${resources.accountId}`,
        });
      }

      for (const user of resources.users) {
        await platform(`/platform/api/v1/users/${user.id}`, {
          method: 'DELETE',
          expected: [200, 202, 204, 404],
        });
        pendingResources.push({
          key: `user:${user.id}`,
          path: `/platform/api/v1/users/${user.id}`,
        });
      }

      cleanup.pending_resources = await pollDeleted(
        request,
        pendingResources,
        platformToken
      );
      cleanup.verified = cleanup.pending_resources.length === 0;
      process.stdout.write(cleanup.verified ? 'OK\n' : 'PENDING\n');
      if (!cleanup.verified && outcome === 'passed') {
        outcome = 'failed';
        failure =
          'Temporary resource cleanup did not complete before the verification timeout';
      }
    } catch (cleanupError) {
      cleanup.error =
        cleanupError instanceof Error
          ? cleanupError.message
          : String(cleanupError);
      process.stdout.write('FAILED\n');
      if (outcome === 'passed') {
        outcome = 'failed';
        failure = 'Temporary resource cleanup failed';
      }
    }

    const report = {
      schema_version: 2,
      run_id: runId,
      result: outcome,
      failure,
      target: {
        base_url: baseUrl,
        expected_deploy_sha: options['expected-deploy-sha'],
        runner_sha: options['runner-sha'],
        feature: FEATURE,
      },
      started_at: startedAt,
      finished_at: new Date().toISOString(),
      topology: {
        isolated_account: true,
        shared_inbox_count: 1,
        team_count: 2,
        agent_count: 2,
        administrator_count: 1,
        temporary_conversation_count: 3,
        action_cable_subscription_count: 2,
      },
      checks,
      cleanup,
    };

    await mkdir(dirname(reportPath), { recursive: true });
    await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`, {
      encoding: 'utf8',
      mode: 0o600,
    });
    process.stdout.write(`[smoke] redacted report: ${reportPath}\n`);
  }

  if (outcome !== 'passed') {
    process.exitCode = 1;
  }
}

await main();
