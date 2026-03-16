#!/usr/bin/env bash

codex_env_had_nounset=0
case $- in
  *u*) codex_env_had_nounset=1 ;;
esac

set -eo pipefail

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  codex_source_file="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  codex_source_file="${(%):-%N}"
else
  codex_source_file="$0"
fi

shim_root="$(cd "$(dirname "${codex_source_file}")" && pwd)"
shim_bin_dir="${shim_root}/bin"

export RTK_SHIM_ROOT="${shim_root}"
export RTK_SHIM_REAL_PATH="${RTK_SHIM_REAL_PATH:-${PATH}}"

case ":${PATH}:" in
  *":${shim_bin_dir}:"*) ;;
  *) export PATH="${shim_bin_dir}:${PATH}" ;;
esac

if [[ -n "${ZSH_VERSION:-}" ]]; then
  rehash
else
  hash -r 2>/dev/null || true
fi

mkdir -p "${shim_root}/logs"

if [[ "${codex_env_had_nounset}" -eq 1 ]]; then
  set -u
fi
