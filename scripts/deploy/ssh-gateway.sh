#!/usr/bin/env bash
set -Eeuo pipefail

command_line=${SSH_ORIGINAL_COMMAND:-}
read -r action first_arg second_arg extra <<< "$command_line"

case "$action" in
  install-env)
    test -z "${first_arg:-}"
    exec sudo -n /usr/local/sbin/central-atendimento-install-env
    ;;
  deploy-production)
    test -n "${first_arg:-}"
    test -n "${second_arg:-}"
    read -r third_arg fourth_arg <<< "${extra:-}"
    test -n "${third_arg:-}"
    test -z "${fourth_arg:-}"
    exec sudo -n /usr/local/sbin/central-atendimento-deploy "$first_arg" "$second_arg" "$third_arg"
    ;;
  rollback-production)
    test -n "${first_arg:-}"
    test -n "${second_arg:-}"
    read -r third_arg fourth_arg <<< "${extra:-}"
    test -n "${third_arg:-}"
    test -z "${fourth_arg:-}"
    exec sudo -n /usr/local/sbin/central-atendimento-rollback "$first_arg" "$second_arg" "$third_arg"
    ;;
  *)
    echo 'Unsupported SSH command' >&2
    exit 64
    ;;
esac
