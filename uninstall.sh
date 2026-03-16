#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dist_cli="${repo_root}/dist/cli.js"

if [[ ! -f "${dist_cli}" ]]; then
  printf 'missing built CLI: %s\nrun `npm install && npm run build` first\n' "${dist_cli}" >&2
  exit 1
fi

exec node "${dist_cli}" uninstall "$@"
