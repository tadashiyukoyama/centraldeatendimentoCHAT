#!/usr/bin/env bash
set -Eeuo pipefail

readonly APP_ROOT=${APP_ROOT:-/opt/central-atendimento}
readonly COMPOSE_FILE=${COMPOSE_FILE:-$APP_ROOT/compose/docker-compose.production.yaml}
readonly ENV_FILE=${CHATWOOT_ENV_FILE:-$APP_ROOT/shared/env/chatwoot.production.env}
readonly IMAGE_REPOSITORY=${IMAGE_REPOSITORY:-ghcr.io/tadashiyukoyama/centraldeatendimentochat}
readonly ICP_CONTAINER=${ICP_CONTAINER:-ic-openresty-tATe}
readonly ICP_IMAGE=${ICP_IMAGE:-icontainer/openresty:1.29.2.3}
readonly ICP_NETWORK=${ICP_NETWORK:-icontainer-network}
readonly EXPECTED_PUBLIC_IP=${PROD_EXPECTED_IP:-216.22.27.48}

image_tag=${1:?image tag is required}
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

readonly active_image_file="$APP_ROOT/shared/active-image"
readonly bootstrap_attempt_file="$APP_ROOT/shared/bootstrap-attempt"
if [[ -e "$active_image_file" ]]; then
  echo 'Subsequent deployment blocked: database backup gate is not configured.' >&2
  exit 78
fi
if [[ -e "$bootstrap_attempt_file" ]]; then
  echo 'Incomplete first deployment detected: manual audit is required before retry.' >&2
  exit 79
fi

readonly image="$IMAGE_REPOSITORY:$image_tag"
readonly compose_args=(--env-file "$ENV_FILE" -f "$COMPOSE_FILE" -p centraldeatendimentochat-production)

run_compose() {
  docker compose "${compose_args[@]}" "$@"
}

check_public_domain() {
  local http_status
  local resolved_ips=()

  mapfile -t resolved_ips < <(getent ahostsv4 "$chatwoot_domain" | awk '{print $1}' | sort -u)
  if (( ${#resolved_ips[@]} != 1 )) || [[ "${resolved_ips[0]:-}" != "$EXPECTED_PUBLIC_IP" ]]; then
    echo "Chatwoot domain does not resolve exclusively to expected VPS IP ${EXPECTED_PUBLIC_IP}: ${chatwoot_domain}" >&2
    return 1
  fi

  if ! http_status=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 15 "https://${chatwoot_domain}/"); then
    echo "Chatwoot domain TLS validation failed for https://${chatwoot_domain}/" >&2
    return 1
  fi
  if [[ "$http_status" == 000 || ! "$http_status" =~ ^[0-9]{3}$ || "$http_status" -lt 200 || "$http_status" -gt 599 ]]; then
    echo "Chatwoot domain returned an invalid or unreachable HTTP status: ${http_status}" >&2
    return 1
  fi
  printf 'Chatwoot domain status observed: %s\n' "$http_status"
}

assert_icp() {
  test "$(docker inspect --format '{{.Config.Image}}' "$ICP_CONTAINER")" = "$ICP_IMAGE"
  test "$(docker inspect --format '{{.State.Running}}' "$ICP_CONTAINER")" = true
  docker network inspect "$ICP_NETWORK" >/dev/null
  if ! curl --fail --silent --show-error --max-time 15 "https://${icp_panel_domain}" >/dev/null; then
    echo "ICP panel TLS validation failed for https://${icp_panel_domain}" >&2
    echo 'Observed certificate:' >&2
    timeout 15 openssl s_client -connect "${icp_panel_domain}:443" -servername "$icp_panel_domain" </dev/null 2>/dev/null \
      | openssl x509 -noout -subject -issuer -dates -fingerprint -sha256 >&2 \
      || echo 'Unable to read the presented certificate.' >&2
    return 1
  fi
}

wait_for_rails() {
  local attempt
  for ((attempt = 1; attempt <= 30; attempt++)); do
    if curl --fail --silent --show-error --max-time 5 "http://127.0.0.1:${CHATWOOT_APP_PORT:-3000}/health" >/dev/null; then
      return 0
    fi
    sleep 5
  done
  return 1
}

write_bootstrap_marker() {
  local state=$1
  local started_at=$2
  local temp_file

  temp_file=$(mktemp "${bootstrap_attempt_file}.tmp.XXXXXX")
  {
    printf 'image=%s\n' "$image"
    printf 'started_at=%s\n' "$started_at"
    printf 'state=%s\n' "$state"
  } > "$temp_file"
  chmod 600 "$temp_file"
  chown root:root "$temp_file"
  mv -f "$temp_file" "$bootstrap_attempt_file"
}

write_active_image() {
  local temp_file

  temp_file=$(mktemp "${active_image_file}.tmp.XXXXXX")
  printf '%s\n' "$image" > "$temp_file"
  chmod 600 "$temp_file"
  chown root:root "$temp_file"
  mv -f "$temp_file" "$active_image_file"
}

rollback_on_error() {
  local status=$?
  trap - ERR
  run_compose stop rails sidekiq postgres redis >/dev/null 2>&1 || true
  exit "$status"
}

check_public_domain
assert_icp
run_compose config --quiet
started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
write_bootstrap_marker started "$started_at"
trap rollback_on_error ERR

# The workflow passes a short-lived GHCR token through stdin. It is not persisted.
registry_token=$(cat)
if [[ -n "$registry_token" ]]; then
  printf '%s' "$registry_token" | docker login ghcr.io --username tadashiyukoyama --password-stdin >/dev/null
fi
docker pull "$image" >/dev/null
docker logout ghcr.io >/dev/null 2>&1 || true

export CHATWOOT_IMAGE="$image"
run_compose up -d postgres redis >/dev/null
run_compose run --rm rails bundle exec rails db:chatwoot_prepare >/dev/null
run_compose up -d rails sidekiq >/dev/null
wait_for_rails
curl --fail --silent --show-error --max-time 20 "https://${chatwoot_domain}/health" >/dev/null
assert_icp

write_active_image
write_bootstrap_marker completed "$started_at"
trap - ERR
echo "Deployment prepared for $image"
