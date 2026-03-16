#!/usr/bin/env bash
set -euo pipefail

codex_home="${CODEX_HOME:-${HOME}/.codex}"
config_file="${codex_home}/config.toml"
managed_start="# BEGIN RTK SHIM CONFIG"
managed_end="# END RTK SHIM CONFIG"

if [[ ! -f "${config_file}" ]]; then
  printf 'No Codex config found at %s\n' "${config_file}"
  exit 0
fi

CONFIG_FILE="${config_file}" \
MANAGED_START="${managed_start}" \
MANAGED_END="${managed_end}" \
python3 - <<'PY'
from pathlib import Path
import os
import re
import sys

config_file = Path(os.environ["CONFIG_FILE"])
managed_start = os.environ["MANAGED_START"]
managed_end = os.environ["MANAGED_END"]

text = config_file.read_text()
managed_pattern = re.compile(
    rf"(?ms)^\s*{re.escape(managed_start)}\n.*?^\s*{re.escape(managed_end)}\n?"
)

if not managed_pattern.search(text):
    sys.exit(0)

new_text = managed_pattern.sub("", text, count=1)
new_text = re.sub(r"\n{3,}", "\n\n", new_text).strip()

if new_text:
    config_file.write_text(new_text + "\n")
else:
    config_file.unlink()
PY

printf 'Removed RTK shim config block from %s\n' "${config_file}"
