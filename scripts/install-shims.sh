#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${repo_root}/shims"
install_root="${RTK_SHIM_HOME:-${HOME}/.rtk-codex}"

mkdir -p "${install_root}"
RTK_SHIM_TARGET_ROOT="${install_root}" "${repo_root}/scripts/sync-shims.sh"
cp "${source_root}/shim-commands.txt" "${install_root}/shim-commands.txt"

printf 'Installed RTK shims into %s\n' "${install_root}"
