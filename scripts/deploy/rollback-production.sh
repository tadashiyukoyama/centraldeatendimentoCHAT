#!/usr/bin/env bash
set -Eeuo pipefail

readonly APP_ROOT=${APP_ROOT:-/opt/central-atendimento}
readonly COMPOSE_FILE=${COMPOSE_FILE:-$APP_ROOT/compose/docker-compose.production.yaml}
readonly ENV_FILE=${CHATWOOT_ENV_FILE:-$APP_ROOT/shared/env/chatwoot.production.env}
readonly IMAGE_REPOSITORY=${IMAGE_REPOSITORY:-ghcr.io/tadashiyukoyama/centraldeatendimentochat}
readonly ICP_CONTAINER=${ICP_CONTAINER:-ic-openresty-tATe}
readonly ICP_IMAGE=${ICP_IMAGE:-icontainer/openresty:1.29.2.3}
readonly ICP_NETWORK=${ICP_NETWORK:-icontainer-network}

image_tag=${1:?previous image tag is required}
chatwoot_domain=${2:?Chatwoot domain is required}
icp_panel_domain=${3:?ICP panel domain is required}
if [[ ! "$image_tag" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'image tag must be a full commit SHA' >&2
  exit 64
fi
if [[ ! "$chatwoot_domain" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]]; then
  echo 'Chatwoot domain is invalid' >&2
  exit 64
fi
if [[ ! "$icp_panel_domain" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]]; then
  echo 'ICP panel domain is invalid' >&2
  exit 64
fi

readonly image="$IMAGE_REPOSITORY:$image_tag"
readonly active_image_file="$APP_ROOT/shared/active-image"
readonly compose_args=(--env-file "$ENV_FILE" -f "$COMPOSE_FILE" -p centraldeatendimentochat-production)
run_compose() { docker compose "${compose_args[@]}" "$@"; }

test "$(docker inspect --format '{{.Config.Image}}' "$ICP_CONTAINER")" = "$ICP_IMAGE"
test "$(docker inspect --format '{{.State.Running}}' "$ICP_CONTAINER")" = true
docker network inspect "$ICP_NETWORK" >/dev/null
curl --fail --silent --show-error --insecure --max-time 15 "https://${icp_panel_domain}" >/dev/null
run_compose config --quiet

registry_token=$(cat)
if [[ -n "$registry_token" ]]; then
  printf '%s' "$registry_token" | docker login ghcr.io --username tadashiyukoyama --password-stdin >/dev/null
fi
docker pull "$image" >/dev/null
docker logout ghcr.io >/dev/null 2>&1 || true

export CHATWOOT_IMAGE="$image"
run_compose up -d rails sidekiq >/dev/null
for attempt in $(seq 1 30); do
  if curl --fail --silent --show-error --max-time 5 http://127.0.0.1:${CHATWOOT_APP_PORT:-3000}/health >/dev/null; then
    curl --fail --silent --show-error --max-time 20 "https://${chatwoot_domain}/health" >/dev/null
    curl --fail --silent --show-error --insecure --max-time 15 "https://${icp_panel_domain}" >/dev/null
    printf '%s\n' "$image" > "$active_image_file"
    echo "Rollback prepared for $image"
    exit 0
  fi
  sleep 5
done
exit 1
