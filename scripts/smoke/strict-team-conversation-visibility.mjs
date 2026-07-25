#!/usr/bin/env node

import { randomBytes } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

const FEATURE = 'strict_team_conversation_visibility';
const REQUEST_TIMEOUT_MS = 20_000;
const CLEANUP_TIMEOUT_MS = 90_000;

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
    `${label}: expected ${normalizedExpected.length} visible conversation(s), observed ${normalizedActual.length}`
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
  };
  const checks = [];
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

  const platform = (path, optionsForRequest = {}) =>
    request(path, { ...optionsForRequest, token: platformToken });

  try {
    process.stdout.write(`[smoke] run ${runId} against ${baseUrl}\n`);

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
      };
      assert(
        conversations[definition.key].id > 0,
        `${definition.key} conversation creation did not return an id`
      );
    }

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
    const expectDenied = async (path, token) => {
      const response = await request(path, {
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
      'team transfer revokes old access and grants new access immediately',
      async () => {
        await request(
          `${accountPath}/conversations/${conversations.teamA.id}/assignments`,
          {
            method: 'POST',
            token: admin.token,
            body: { team_id: teamBId },
          }
        );
        assertExactIds(
          await listIds(agentA.token),
          [],
          'team A list after transfer'
        );
        assertExactIds(
          await listIds(agentB.token),
          [conversations.teamA.id, conversations.teamB.id],
          'team B list after transfer'
        );
        await expectDenied(
          `${accountPath}/conversations/${conversations.teamA.id}`,
          agentA.token
        );
        await request(
          `${accountPath}/conversations/${conversations.teamA.id}`,
          { token: agentB.token }
        );

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
        return {
          revoked_from_old_team: true,
          granted_to_new_team: true,
          original_state_restored: true,
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

    outcome = 'passed';
  } catch (error) {
    failure = error instanceof Error ? error.message : String(error);
    process.stderr.write(`[smoke] FAILED: ${failure}\n`);
  } finally {
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
      schema_version: 1,
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
