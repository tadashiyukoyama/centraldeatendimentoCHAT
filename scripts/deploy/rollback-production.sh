#!/usr/bin/env bash
set -Eeuo pipefail

readonly APP_ROOT=${APP_ROOT:-/opt/central-atendimento}
readonly COMPOSE_FILE=${COMPOSE_FILE:-$APP_ROOT/compose/docker-compose.production.yaml}
readonly ENV_FILE=${CHATWOOT_ENV_FILE:-$APP_ROOT/shared/env/chatwoot.production.env}
readonly IMAGE_REPOSITORY=${IMAGE_REPOSITORY:-ghcr.io/tadashiyukoyama/centraldeatendimentochat}
readonly ICP_CONTAINER=${ICP_CONTAINER:-ic-openresty-tATe}
readonly ICP_IMAGE=${ICP_IMAGE:-icontainer/openresty:1.29.2.3}
readonly ICP_NETWORK=${ICP_NETWORK:-icontainer-network}

validate_ipv4() {
  local ip=$1
  local IFS=.
  local -a octets
  local octet

  read -r -a octets <<< "$ip"
  if (( ${#octets[@]} != 4 )); then
    return 1
  fi
  for octet in "${octets[@]}"; do
    [[ "$octet" =~ ^[0-9]{1,3}$ ]] || return 1
    if [[ ${#octet} -gt 1 && "$octet" == 0* ]]; then
      return 1
    fi
    (( 10#$octet <= 255 )) || return 1
  done
}

if [[ $# -ne 4 ]]; then
  echo 'rollback-production requires image SHA, Chatwoot domain, ICP panel domain and expected IPv4' >&2
  exit 64
fi

image_tag=$1
chatwoot_domain=$2
icp_panel_domain=$3
expected_public_ip=$4
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
if ! validate_ipv4 "$expected_public_ip"; then
  echo 'expected public IP must be a canonical IPv4 address' >&2
  exit 64
fi
readonly expected_public_ip

readonly image="$IMAGE_REPOSITORY:$image_tag"
readonly active_image_file="$APP_ROOT/shared/active-image"
readonly compose_args=(--env-file "$ENV_FILE" -f "$COMPOSE_FILE" -p centraldeatendimentochat-production)
run_compose() { docker compose "${compose_args[@]}" "$@"; }

check_public_domain() {
  local http_status
  local resolved_ips=()

  mapfile -t resolved_ips < <(getent ahostsv4 "$chatwoot_domain" | awk '{print $1}' | sort -u)
  if (( ${#resolved_ips[@]} != 1 )) || [[ "${resolved_ips[0]:-}" != "$expected_public_ip" ]]; then
    echo "Chatwoot domain does not resolve exclusively to expected VPS IP ${expected_public_ip}: ${chatwoot_domain}" >&2
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

check_public_domain
assert_icp
run_compose config --quiet

registry_token=$(cat)
# The cleanup function is invoked indirectly by the EXIT trap.
# shellcheck disable=SC2317
cleanup_registry_auth() {
  docker logout ghcr.io >/dev/null 2>&1 || true
}
trap cleanup_registry_auth EXIT
if [[ -n "$registry_token" ]]; then
  printf '%s' "$registry_token" | docker login ghcr.io --username tadashiyukoyama --password-stdin >/dev/null
fi
unset registry_token
docker pull "$image" >/dev/null
docker logout ghcr.io >/dev/null 2>&1 || true

export CHATWOOT_IMAGE="$image"
run_compose up -d rails sidekiq >/dev/null
for ((attempt = 1; attempt <= 30; attempt++)); do
  if curl --fail --silent --show-error --max-time 5 "http://127.0.0.1:${CHATWOOT_APP_PORT:-3000}/health" >/dev/null; then
    curl --fail --silent --show-error --max-time 20 "https://${chatwoot_domain}/health" >/dev/null
    assert_icp
    printf '%s\n' "$image" > "$active_image_file"
    echo "Rollback prepared for $image"
    exit 0
  fi
  sleep 5
done
exit 1
