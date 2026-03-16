#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_shim_root="${repo_root}/shims"
shim_root="${RTK_SHIM_HOME:-${HOME}/.rtk-codex}"
shim_bin_dir="${shim_root}/bin"
codex_home="${CODEX_HOME:-${HOME}/.codex}"
config_file="${codex_home}/config.toml"
managed_start="# BEGIN RTK SHIM CONFIG"
managed_end="# END RTK SHIM CONFIG"
default_log_file="${RTK_SHIM_LOG_FILE:-/tmp/codex-rtk-shim.log}"

"${repo_root}/scripts/install-shims.sh"

toml_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "${value}"
}

build_real_path() {
  local base_path="${RTK_SHIM_REAL_PATH:-${PATH}}"
  local part
  local -a parts=()
  local -a filtered=()

  IFS=':' read -r -a parts <<< "${base_path}"
  for part in "${parts[@]}"; do
    [[ -z "${part}" ]] && continue
    [[ "${part}" == "${shim_bin_dir}" ]] && continue
    [[ "${part}" == "${repo_shim_root}/bin" ]] && continue
    [[ "${part}" == *"/.codex/tmp/arg0/"* ]] && continue
    filtered+=("${part}")
  done

  (
    IFS=':'
    printf '%s' "${filtered[*]}"
  )
}

real_path="$(build_real_path)"
managed_block="$(cat <<EOF
${managed_start}
[shell_environment_policy]
inherit = "all"

[shell_environment_policy.set]
PATH = "$(toml_escape "${shim_bin_dir}:${real_path}")"
RTK_SHIM_ROOT = "$(toml_escape "${shim_root}")"
RTK_SHIM_REAL_PATH = "$(toml_escape "${real_path}")"
RTK_SHIM_LOG_FILE = "$(toml_escape "${default_log_file}")"
${managed_end}
EOF
)"

mkdir -p "${codex_home}"

CONFIG_FILE="${config_file}" \
MANAGED_BLOCK="${managed_block}" \
MANAGED_START="${managed_start}" \
MANAGED_END="${managed_end}" \
python3 - <<'PY'
from pathlib import Path
import os
import sys
import re

config_file = Path(os.environ["CONFIG_FILE"])
managed_block = os.environ["MANAGED_BLOCK"].strip() + "\n"
managed_start = os.environ["MANAGED_START"]
managed_end = os.environ["MANAGED_END"]

text = config_file.read_text() if config_file.exists() else ""

managed_pattern = re.compile(
    rf"(?ms)^\s*{re.escape(managed_start)}\n.*?^\s*{re.escape(managed_end)}\n?"
)

def find_shell_environment_block(source: str):
    lines = source.splitlines(keepends=True)
    start = None
    end = None

    for index, line in enumerate(lines):
        if line.strip() == "[shell_environment_policy]":
            start = index
            end = len(lines)
            break

    if start is None:
        return None

    for index in range(start + 1, len(lines)):
        stripped = lines[index].strip()
        if stripped.startswith("[") and stripped not in {
            "[shell_environment_policy]",
            "[shell_environment_policy.set]",
        }:
            end = index
            break

    block = "".join(lines[start:end])
    prefix = "".join(lines[:start])
    suffix = "".join(lines[end:])
    return prefix, block, suffix

if managed_pattern.search(text):
    new_text = managed_pattern.sub(managed_block, text, count=1)
else:
    existing_block = find_shell_environment_block(text)
    if existing_block is not None:
        prefix, block, suffix = existing_block
        if "RTK_SHIM_ROOT" in block or "RTK_SHIM_REAL_PATH" in block or "RTK_SHIM_LOG_FILE" in block:
            prefix = prefix.rstrip("\n")
            suffix = suffix.lstrip("\n")
            if prefix:
                prefix += "\n\n"
            if suffix:
                suffix = "\n\n" + suffix
            new_text = prefix + managed_block.rstrip("\n") + suffix
        else:
            sys.stderr.write(
                f"refusing to overwrite existing shell_environment_policy in {config_file}\n"
            )
            sys.exit(2)
    else:
        if text and not text.endswith("\n"):
            text += "\n"
        if text.strip():
            text = text.rstrip("\n") + "\n\n"
        new_text = text + managed_block

config_file.write_text(new_text)
PY

printf 'Installed RTK shim config block into %s\n' "${config_file}"
