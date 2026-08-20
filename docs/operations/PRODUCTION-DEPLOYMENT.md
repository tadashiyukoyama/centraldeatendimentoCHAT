# Production deployment contract

Production deployment is manual and image-pinned. The first deployment is not authorized by this document; it requires explicit approval after the draft PR and the ICP domain are reviewed.

The first-deploy exception is intentionally narrow: when `/opt/central-atendimento/shared/active-image` does not exist and `/opt/central-atendimento/shared/bootstrap-attempt` does not exist, the empty-database bootstrap may proceed without a backup because the database will be created empty and there are no real production data yet. Once `active-image` exists, a new deployment must create and validate a PostgreSQL backup before any stateful Compose operation. If the backup directory is absent, the deployment stops with `Subsequent deployment blocked: database backup gate is not configured.` If a first bootstrap has already started without completing, `bootstrap-attempt` blocks retry with `Incomplete first deployment detected: manual audit is required before retry.`

## Required GitHub configuration

Secrets:

- `PROD_SSH_KEY`: private key for the restricted `centraldeploy` account;
- `PROD_ENV_FILE`: complete production environment file, without committing its values.
- `PROD_SMTP_PASSWORD`: password for the approved global SMTP account; it is
  merged in memory with the versioned non-secret email overlay and is never
  printed.
- `PROD_SENTRY_DSN`: HTTPS DSN of the AceleraChat Sentry project. The deploy
  applies it to backend and frontend with tracing and default PII disabled.

Variables:

- `PROD_HOST`
- `PROD_PORT`
- `PROD_USER` (expected: `centraldeploy`)
- `PROD_DOMAIN`
- `PROD_SSH_HOST_KEY` (SHA-256 SSH host-key fingerprint)
- `ICP_PANEL_DOMAIN`
- `PROD_EXPECTED_IP` (required IPv4 variable in the `production` environment; documentation placeholder: `192.0.2.44`)

The domain must be created through the ICP panel as a dedicated subdomain. TLS must be enabled there after DNS resolves to the VPS. The panel domain remains separate.

## Pipeline

1. `build-production-image.yml` runs the Ruby quality gate and the reusable
   production-contract gate on ephemeral GitHub-hosted runners. It builds the exact immutable image on the
   repository-scoped self-hosted runner carrying the unique `acelerachat-ci`
   label for explicit dispatches. Pull-request image
   builds remain on `ubuntu-latest`, so untrusted fork code never executes on
   the persistent runner. The runner is isolated on the dedicated Actions host
   and is not one of the 3V Tintas or OZ3D runner services.
2. The image is published to GHCR with the full commit SHA as tag.
3. `deploy-production.yml` runs only through `workflow_dispatch` and requires an explicit full SHA.
4. The workflow checks out `inputs.image_tag`, proves that commit is present, proves it is an ancestor of `origin/main`, and verifies the deployment scripts are the blobs from that same commit.
5. Before sending the environment file, the runner calculates the five contract hashes from the selected commit and calls the restricted `verify-contract` action. A mismatch aborts with `Production contract mismatch: remote root-owned files do not match the selected commit.` The workflow never updates root-owned files automatically.
6. The runner pins the audited ED25519 SSH host key with `ssh-keyscan -t
ed25519`. It requires exactly one unique fingerprint, places only the
   validated ED25519 line in `known_hosts`, and uses the restricted deploy key.
7. Before any mutating SSH command, the runner validates the immutable image exists in the public GHCR package using an isolated empty Docker configuration, validates `PROD_EXPECTED_IP`, checks that `PROD_DOMAIN` resolves exclusively to it, and performs strict HTTPS checks for the Chatwoot and ICP panel domains. HTTP 200-599 is accepted because the application may not be active yet; status 000 or invalid TLS blocks the operation.
8. The protected base environment is merged with
   `infra/env/acelerachat.production.public.env.example` and
   the protected `PROD_SMTP_PASSWORD` and `PROD_SENTRY_DSN` values in a
   runner-temporary file with mode 0600. The merged environment is sent over
   the authenticated SSH channel and stored with mode 0600; its values are
   never printed, and the runner copy is removed unconditionally.
9. The deploy command receives exactly five arguments: an allowlisted GHCR repository, image SHA, Chatwoot domain, ICP panel domain and expected IPv4. The gateway rejects missing or extra arguments, and the script accepts only the current AceleraChat namespace or the preserved legacy namespace.
10. The deploy script repeats the DNS, strict TLS and ICP checks before changing application state, validates Compose and pulls the immutable public image with an isolated empty Docker configuration before creating any bootstrap marker. It never consumes a workstation, runner or production registry credential.
11. When `shared/active-image` already exists, the script runs `pg_dump --format=custom --no-owner --no-acl` inside the existing PostgreSQL container. It rejects an empty dump, validates the archive with `pg_restore --list`, writes a SHA-256 checksum and metadata, and atomically updates the `latest` backup record. A failed or unverifiable backup aborts the deployment before the bootstrap marker or any stateful Compose operation.
12. A successful image pull, and successful backup when required, are followed immediately by the atomic `shared/bootstrap-attempt` marker with the image, UTC start time, `state=started` and backup provenance when applicable.
13. PostgreSQL and Redis start on the private network; `db:chatwoot_prepare` runs; Rails and Sidekiq start.
14. The internal Rails health endpoint, public Chatwoot domain, ICP panel and ICP container are tested with strict TLS verification. Only after all healthchecks does the script atomically write `active-image` and mark the bootstrap `completed`.
15. A first-deploy failure preserves PostgreSQL, Redis, storage and `bootstrap-attempt`, stops project services, and does not create `active-image`. A later failure also preserves the validated database backup; it does not restore schema or data automatically.

## Self-hosted runner boundary

The AceleraChat runner is repository-scoped and must be registered with the
unique label `acelerachat-ci`. Its service account, runner directory, work
directory and rootless Docker state are separate from every other runner on the
host. It must not receive labels belonging to 3V Tintas, OZ3D or OpenJarvis.

The versioned installation source is `infra/ci-runner/`. Run
`provision-runner.sh` before requesting a repository-scoped ephemeral
registration token, pass that token only through the process environment to
`register-runner.sh`, and finish with `verify-runner.sh`. The scripts create
only `ghr-acelerachat`, `/srv/ci/runners/acelerachat`,
`/srv/ci/cache/acelerachat`, its rootless Docker daemon and its systemd units.
They do not install host packages, modify SSH, or alter another runner.

The image workflow refuses a runner name other than
`vps10056-acelerachat`, refuses a Docker daemon that does not report rootless
mode and requires at least 18 GiB free before BuildKit starts. Existing caches
belonging to another repository are never an automatic cleanup target.

Only trusted `push` events on `main`, explicit `workflow_dispatch` image builds,
production deploys and rollbacks use this runner. Pull-request jobs continue to
use GitHub-hosted infrastructure. The production environment remains the only
source for deploy secrets and variables; no production credential is persisted
in the runner installation or its service environment.

Before enabling the workflow, verify through the GitHub API that exactly one
online, idle runner matches `acelerachat-ci`, then verify rootless Docker from
that runner's operating-system account. If the runner is offline or ambiguous,
the workflow must remain queued rather than fall back to another host.

Runner rollback is repository-scoped: remove `vps10056-acelerachat` from the
GitHub repository, stop and disable only its generated service, and preserve
its directories until diagnostics and artifact provenance have been recorded.
Do not prune the 3V Tintas or OZ3D Docker daemons during this rollback.

The installation verified on 2026-08-20 is derived from functional SHA
`12d6fcd7bb9993b96bab07d827d83e2ca9b64395`. GitHub reported the exact runner
`vps10056-acelerachat` online and idle; the host-side verifier confirmed runner
2.336.0, rootless Docker 29.6.2, a closed public Docker API and 22 GiB free.
The workflow smoke remains the first post-publication gate and performs no
application or provider mutation.

The GitHub Actions control plane is still required even when execution is
self-hosted. An account-level Actions or billing lock prevents orchestration and
must be resolved separately; the dedicated VPS is not a bypass for that lock.

## Production filesystem

```text
/opt/central-atendimento/compose/
/opt/central-atendimento/releases/
/opt/central-atendimento/shared/env/chatwoot.production.env
/opt/central-atendimento/shared/bootstrap-attempt
/opt/central-atendimento/shared/active-image
/opt/central-atendimento/shared/backups/postgres/
/opt/central-atendimento/shared/storage/postgres/
/opt/central-atendimento/shared/storage/redis/
/opt/central-atendimento/shared/storage/ (Active Storage)
/var/log/central-atendimento/
```

The PostgreSQL backup directory is outside the clone and outside Docker volumes. Files are root-owned with mode 0600; the directory is mode 0700. The directory is a local recovery safeguard on the VPS, not an off-site disaster-recovery copy.

## Backup gate

The gate has two states:

- First empty-database bootstrap: permitted without a backup only when both
  `shared/active-image` and `shared/bootstrap-attempt` are absent.
- Subsequent deployment: permitted only when
  `shared/backups/postgres/` exists and a fresh PostgreSQL custom-format dump is
  successfully produced from the active database, is non-empty, passes
  `pg_restore --list`, and has a matching SHA-256 checksum and metadata record.

Each subsequent deployment creates a file named
`chatwoot-<UTC timestamp>-<active SHA>.dump`, its `.sha256` and `.metadata`
sidecars, and the atomically replaced `latest` record. The bootstrap marker
records the backup path, digest and metadata path. No database password is put
in a command argument, marker, metadata file or log; `pg_dump` reads the
container's existing database environment.

The gate protects against deploying a new application image without a known
database recovery artifact. It does not restore backups, reverse migrations or
make the local VPS copy a complete disaster-recovery solution. Off-site backup,
retention and restore drills remain separate operational work and must be
implemented before production data volume requires them.

## Remote contract pinning

The restricted SSH gateway exposes only the fixed-path `verify-contract` read action for contract inspection. It hashes the deployed root-owned deploy, rollback, environment-install, Compose and gateway files and accepts no user-supplied path, glob or shell. The workflow compares all five values with the selected commit before it sends any environment file. Installing the exact root-owned blobs is a separate administrative gate after merge; this workflow never performs that installation. That gate must preserve the previous five files in a timestamped root-only directory, install only the fixed audited paths atomically and verify every SHA-256 before a deploy is dispatched.

## SSH host-key pinning

The production workflow validates only the audited ED25519 host key. It calls
`ssh-keyscan -t ed25519`, requires exactly one unique SHA-256 fingerprint, and
compares it with `PROD_SSH_HOST_KEY`. The resulting `known_hosts` file contains
only the validated `ssh-ed25519` line. The workflow does not depend on the
order in which RSA, ECDSA, or ED25519 keys might otherwise be returned, and a
mismatch stops the job before remote SSH, environment transfer, or registry
token handling.

The variable is not changed to accommodate a scan result. Any mismatch must
be independently audited; no fallback accepts an arbitrary or unvalidated
fingerprint.

The incident recorded for this contract is:

```text
Run: 29632260934
Failure: Prepare pinned SSH host key
Persistent state started: NO
VPS altered: NO
Rerun: NO
```

## Failed first bootstrap

The first deploy has no previous application image for rollback. A failure after `bootstrap-attempt` is created must leave the marker in place, preserve database and storage paths, stop `rails`, `sidekiq`, `postgres` and `redis` when present, and leave `active-image` absent. Retrying is prohibited until a manual audit and explicit owner authorization remove the marker through a separate administrative command. Error handling never deletes volumes, containers or the marker and never touches ICP/OpenResty.

## Preflight and secret handling

The current and legacy GHCR packages are public. The runner and production scripts create isolated empty Docker configuration directories and perform anonymous manifest inspection and pull. No GHCR credential is read, sent to the VPS, persisted or placed in an argument. A package that stops being anonymously readable fails the preflight before `install-env` or any stateful operation.

The active-image marker may reference either of the two allowlisted repositories during the namespace transition. New deployments use `ghcr.io/cesaryukoyama28-eng/centraldeatendimentochat`; rollback requires an explicit repository choice so the preserved production image can continue to come from `ghcr.io/tadashiyukoyama/centraldeatendimentochat` without ambiguity.

`PROD_EXPECTED_IP` is an environment variable, not a secret and not a repository fallback. The repository contains only documentation placeholders; the production environment supplies the actual IPv4 value.
