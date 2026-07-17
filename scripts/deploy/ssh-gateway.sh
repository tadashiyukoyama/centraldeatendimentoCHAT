#!/usr/bin/env bash
set -Eeuo pipefail

command_line=${SSH_ORIGINAL_COMMAND:-}
read -r action first_arg second_arg extra <<< "$command_line"

readonly deploy_script=/usr/local/sbin/central-atendimento-deploy
readonly rollback_script=/usr/local/sbin/central-atendimento-rollback
readonly install_env_script=/usr/local/sbin/central-atendimento-install-env
readonly compose_file=/opt/central-atendimento/compose/docker-compose.production.yaml
readonly gateway_script=/usr/local/sbin/central-atendimento-ssh-gateway

print_contract_hash() {
  local label=$1
  local path=$2
  local hash

  hash=$(sha256sum "$path" | awk '{print $1}')
  printf '%s %s\n' "$label" "$hash"
}

case "$action" in
  verify-contract)
    test -z "${first_arg:-}"
    test -z "${second_arg:-}"
    test -z "${extra:-}"
    print_contract_hash deploy-production.sh "$deploy_script"
    print_contract_hash rollback-production.sh "$rollback_script"
    print_contract_hash install-production-env.sh "$install_env_script"
    print_contract_hash docker-compose.production.yaml "$compose_file"
    print_contract_hash ssh-gateway.sh "$gateway_script"
    ;;
  install-env)
    test -z "${first_arg:-}"
    exec sudo -n /usr/local/sbin/central-atendimento-install-env
    ;;
  deploy-production)
    test -n "${first_arg:-}"
    test -n "${second_arg:-}"
    read -r third_arg fourth_arg fifth_arg <<< "${extra:-}"
    test -n "${third_arg:-}"
    test -n "${fourth_arg:-}"
    test -z "${fifth_arg:-}"
    exec sudo -n /usr/local/sbin/central-atendimento-deploy "$first_arg" "$second_arg" "$third_arg" "$fourth_arg"
    ;;
  rollback-production)
    test -n "${first_arg:-}"
    test -n "${second_arg:-}"
    read -r third_arg fourth_arg fifth_arg <<< "${extra:-}"
    test -n "${third_arg:-}"
    test -n "${fourth_arg:-}"
    test -z "${fifth_arg:-}"
    exec sudo -n /usr/local/sbin/central-atendimento-rollback "$first_arg" "$second_arg" "$third_arg" "$fourth_arg"
    ;;
  *)
    echo 'Unsupported SSH command' >&2
    exit 64
    ;;
esac
