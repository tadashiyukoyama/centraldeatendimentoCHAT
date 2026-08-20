#!/usr/bin/env bash
set -Eeuo pipefail

readonly APP_ROOT=${APP_ROOT:-/opt/central-atendimento}
readonly COMPOSE_FILE=${COMPOSE_FILE:-$APP_ROOT/compose/docker-compose.production.yaml}
readonly ENV_FILE=${CHATWOOT_ENV_FILE:-$APP_ROOT/shared/env/chatwoot.production.env}
readonly PRIMARY_IMAGE_REPOSITORY=ghcr.io/cesaryukoyama28-eng/centraldeatendimentochat
readonly LEGACY_IMAGE_REPOSITORY=ghcr.io/tadashiyukoyama/centraldeatendimentochat
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

validate_image_repository() {
  case "$1" in
    "$PRIMARY_IMAGE_REPOSITORY"|"$LEGACY_IMAGE_REPOSITORY") return 0 ;;
    *) return 1 ;;
  esac
}

image_tag_from_reference() {
  local reference=$1
  local repository
  local tag

  for repository in "$PRIMARY_IMAGE_REPOSITORY" "$LEGACY_IMAGE_REPOSITORY"; do
    if [[ "$reference" == "$repository:"* ]]; then
      tag=${reference#"$repository:"}
      [[ "$tag" =~ ^[0-9a-f]{40}$ ]] || return 1
      printf '%s\n' "$tag"
      return 0
    fi
  done
  return 1
}

pull_public_image() {
  local anonymous_config

  anonymous_config=$(mktemp -d "$APP_ROOT/shared/.ghcr-anonymous.XXXXXX")
  chmod 700 "$anonymous_config"
  if ! DOCKER_CONFIG="$anonymous_config" docker pull "$image" >/dev/null; then
    rm -rf -- "$anonymous_config"
    return 1
  fi
  rm -rf -- "$anonymous_config"
}

if [[ $# -ne 5 ]]; then
  echo 'deploy-production requires an allowed GHCR repository, image SHA, Chatwoot domain, ICP panel domain and expected IPv4' >&2
  exit 64
fi

image_repository=$1
image_tag=$2
chatwoot_domain=$3
icp_panel_domain=$4
expected_public_ip=$5
if ! validate_image_repository "$image_repository"; then
  echo 'image repository is not allowed' >&2
  exit 64
fi
readonly image_repository
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

readonly active_image_file="$APP_ROOT/shared/active-image"
readonly bootstrap_attempt_file="$APP_ROOT/shared/bootstrap-attempt"
readonly backup_root="$APP_ROOT/shared/backups/postgres"
active_image=''
backup_file=''
backup_sha256=''
backup_metadata_file=''
if [[ -e "$active_image_file" ]]; then
  if [[ ! -f "$active_image_file" ]]; then
    echo 'Active image marker is not a regular file; manual audit is required.' >&2
    exit 78
  fi
  active_image=$(tr -d '\r\n' < "$active_image_file")
  if ! active_image_tag=$(image_tag_from_reference "$active_image"); then
    echo 'Active image marker is invalid; manual audit is required.' >&2
    exit 78
  fi
  if [[ ! -d "$backup_root" ]]; then
    echo 'Subsequent deployment blocked: database backup gate is not configured.' >&2
    echo "Expected backup directory: $backup_root" >&2
    exit 78
  fi
fi
if [[ -e "$bootstrap_attempt_file" ]]; then
  if [[ ! -f "$bootstrap_attempt_file" ]] || ! grep -Fxq 'state=completed' "$bootstrap_attempt_file"; then
    echo 'Incomplete first deployment detected: manual audit is required before retry.' >&2
    exit 79
  fi
fi

readonly image="$image_repository:$image_tag"
readonly compose_args=(--env-file "$ENV_FILE" -f "$COMPOSE_FILE" -p centraldeatendimentochat-production)

run_compose() {
  docker compose "${compose_args[@]}" "$@"
}

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

create_database_backup() {
  local timestamp
  local temp_dir
  local temp_dump
  local final_dump
  local final_checksum
  local final_metadata
  local latest_marker
  local digest
  local size_bytes

  timestamp=$(date -u +%Y%m%dT%H%M%SZ)
  install -d -o root -g root -m 700 "$backup_root"
  temp_dir=$(mktemp -d "$backup_root/.tmp.XXXXXX")
  trap 'rm -rf -- "$temp_dir"' RETURN
  temp_dump="$temp_dir/chatwoot.dump"

  # shellcheck disable=SC2016
  if ! run_compose exec -T postgres sh -c 'pg_dump --format=custom --no-owner --no-acl -U "$POSTGRES_USER" -d "$POSTGRES_DB"' > "$temp_dump"; then
    echo 'Database backup failed: pg_dump did not complete.' >&2
    return 1
  fi
  if [[ ! -s "$temp_dump" ]]; then
    echo 'Database backup failed: the dump is empty.' >&2
    return 1
  fi
  if ! run_compose exec -T postgres sh -c 'pg_restore --list >/dev/null' < "$temp_dump"; then
    echo 'Database backup failed: pg_restore validation did not complete.' >&2
    return 1
  fi

  digest=$(sha256sum "$temp_dump" | awk '{print $1}')
  size_bytes=$(stat -c '%s' "$temp_dump")
  final_dump="$backup_root/chatwoot-${timestamp}-${active_image_tag}.dump"
  final_checksum="$backup_root/chatwoot-${timestamp}-${active_image_tag}.sha256"
  final_metadata="$backup_root/chatwoot-${timestamp}-${active_image_tag}.metadata"
  latest_marker="$backup_root/latest"

  mv "$temp_dump" "$final_dump"
  printf '%s  %s\n' "$digest" "$(basename "$final_dump")" > "$temp_dir/checksum"
  chmod 600 "$final_dump" "$temp_dir/checksum"
  chown root:root "$final_dump"
  mv "$temp_dir/checksum" "$final_checksum"
  chown root:root "$final_checksum"
  if ! (cd "$backup_root" && sha256sum -c "$(basename "$final_checksum")" >/dev/null); then
    echo 'Database backup failed: the final checksum does not match the dump.' >&2
    return 1
  fi

  printf 'source_image=%s\ncreated_at=%s\nformat=postgres-custom\nbackup_file=%s\nsha256=%s\nsize_bytes=%s\nvalidation=pg_restore-list\n' \
    "$active_image" "$timestamp" "$final_dump" "$digest" "$size_bytes" > "$temp_dir/metadata"
  printf 'backup_file=%s\nchecksum_file=%s\nmetadata_file=%s\nsha256=%s\ncreated_at=%s\nsource_image=%s\n' \
    "$final_dump" "$final_checksum" "$final_metadata" "$digest" "$timestamp" "$active_image" > "$temp_dir/latest"

  chmod 600 "$temp_dir/metadata" "$temp_dir/latest"
  mv "$temp_dir/metadata" "$final_metadata"
  mv "$temp_dir/latest" "$latest_marker"
  chown root:root "$final_checksum" "$final_metadata" "$latest_marker"

  backup_file="$final_dump"
  backup_sha256="$digest"
  backup_metadata_file="$final_metadata"
  trap - RETURN
  rmdir "$temp_dir"
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
    if [[ -n "$backup_file" ]]; then
      printf 'backup_file=%s\n' "$backup_file"
      printf 'backup_sha256=%s\n' "$backup_sha256"
      printf 'backup_metadata=%s\n' "$backup_metadata_file"
    fi
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

# Both allowed packages are public. An isolated empty Docker configuration
# proves that the release does not depend on a developer or runner credential.
pull_public_image

export CHATWOOT_IMAGE="$image"
# These gates use the new immutable image and the protected production
# environment, but override the normal entrypoint so they neither wait for nor
# mutate PostgreSQL. A missing/unsafe SMTP or Sentry setup stops the release
# before a backup, the bootstrap marker, and all stateful Compose operations.
run_compose run --rm --no-deps --entrypoint bundle rails \
  exec rake acelerachat:email:check acelerachat:monitoring:check

if [[ -n "$active_image" ]]; then
  create_database_backup
fi

started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
write_bootstrap_marker started "$started_at"
trap rollback_on_error ERR

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
