#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE=${CHATWOOT_ENV_FILE:-/opt/central-atendimento/shared/env/chatwoot.production.env}
tmp_file=$(mktemp "${ENV_FILE}.XXXXXX")
trap 'rm -f "$tmp_file"' EXIT

umask 077
cat > "$tmp_file"
test -s "$tmp_file"
install -o root -g root -m 600 "$tmp_file" "$ENV_FILE"
