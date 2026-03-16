export function buildEnvScript(): string {
  return `#!/usr/bin/env bash

codex_env_had_nounset=0
case $- in
  *u*) codex_env_had_nounset=1 ;;
esac

set -eo pipefail

if [[ -n "\${BASH_SOURCE[0]:-}" ]]; then
  codex_source_file="\${BASH_SOURCE[0]}"
elif [[ -n "\${ZSH_VERSION:-}" ]]; then
  codex_source_file="\${(%):-%N}"
else
  codex_source_file="$0"
fi

shim_root="$(cd "$(dirname "\${codex_source_file}")" && pwd)"
shim_bin_dir="\${shim_root}/bin"

export RTK_SHIM_ROOT="\${shim_root}"
export RTK_SHIM_REAL_PATH="\${RTK_SHIM_REAL_PATH:-\${PATH}}"

case ":\${PATH}:" in
  *":\${shim_bin_dir}:"*) ;;
  *) export PATH="\${shim_bin_dir}:\${PATH}" ;;
esac

if [[ -n "\${ZSH_VERSION:-}" ]]; then
  rehash
else
  hash -r 2>/dev/null || true
fi

mkdir -p "\${shim_root}/logs"

if [[ "\${codex_env_had_nounset}" -eq 1 ]]; then
  set -u
fi
`;
}

export function buildDispatcherScript(): string {
  return `#!/usr/bin/env bash
set -euo pipefail

cmd_name="\${RTK_SHIM_COMMAND:-$(basename "$0")}"
shim_bin_dir="$(cd "$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

log_event() {
  local decision="$1"
  local original="$2"
  local target="$3"

  if [[ -n "\${RTK_SHIM_LOG_FILE:-}" ]]; then
    mkdir -p "$(dirname "\${RTK_SHIM_LOG_FILE}")"
    {
      printf '%s\\t%s\\t%s\\t%s\\n' \\
        "$(date '+%Y-%m-%dT%H:%M:%S%z')" \\
        "\${decision}" \\
        "\${original}" \\
        "\${target}" >> "\${RTK_SHIM_LOG_FILE}"
    } 2>/dev/null || true
  fi

  if [[ "\${RTK_SHIM_DEBUG:-0}" == "1" ]]; then
    printf '[rtk-shim] %s: %s => %s\\n' "\${decision}" "\${original}" "\${target}" >&2
  fi
}

build_command_line() {
  local args=("\${cmd_name}")
  local quoted

  for arg in "$@"; do
    printf -v quoted '%q' "\${arg}"
    args+=("\${quoted}")
  done

  local joined
  printf -v joined '%s ' "\${args[@]}"
  printf '%s' "\${joined% }"
}

derive_real_path() {
  if [[ -n "\${RTK_SHIM_REAL_PATH:-}" ]]; then
    printf '%s' "\${RTK_SHIM_REAL_PATH}"
    return
  fi

  local clean_entries=()
  local entry
  IFS=':' read -r -a current_entries <<< "\${PATH:-}"

  for entry in "\${current_entries[@]}"; do
    if [[ "\${entry%/}" == "\${shim_bin_dir%/}" ]]; then
      continue
    fi
    clean_entries+=("\${entry}")
  done

  local clean_path
  printf -v clean_path '%s:' "\${clean_entries[@]}"
  printf '%s' "\${clean_path%:}"
}

real_path="$(derive_real_path)"
original_command="$(build_command_line "$@")"

if command -v rtk >/dev/null 2>&1; then
  rewritten_command="$(rtk rewrite "\${original_command}" 2>/dev/null || true)"

  if [[ -n "\${rewritten_command}" && "\${rewritten_command}" != "\${original_command}" ]]; then
    log_event "rewrite" "\${original_command}" "\${rewritten_command}"
    if [[ "\${RTK_SHIM_DRY_RUN:-0}" == "1" ]]; then
      printf 'REWRITE\\t%s\\t%s\\n' "\${original_command}" "\${rewritten_command}"
      exit 0
    fi
    exec /usr/bin/env PATH="\${real_path}" bash -c "\${rewritten_command}"
  fi
fi

real_cmd="$(PATH="\${real_path}" command -v -- "\${cmd_name}" || true)"

if [[ -z "\${real_cmd}" ]]; then
  printf 'rtk-shim: could not resolve real binary for %s\\n' "\${cmd_name}" >&2
  exit 127
fi

log_event "fallback" "\${original_command}" "\${real_cmd}"
if [[ "\${RTK_SHIM_DRY_RUN:-0}" == "1" ]]; then
  printf 'FALLBACK\\t%s\\t%s\\n' "\${original_command}" "\${real_cmd}"
  exit 0
fi
exec /usr/bin/env PATH="\${real_path}" "\${real_cmd}" "$@"
`;
}

export function buildWrapperScript(commandName: string): string {
  return `#!/usr/bin/env bash
set -euo pipefail

export RTK_SHIM_COMMAND="${commandName}"
exec "$(dirname "$0")/rtk-shim" "$@"
`;
}
