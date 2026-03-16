#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${repo_root}/shims"
ref_file="${source_root}/rtk-upstream-ref.txt"
upstream_file="${source_root}/shim-commands.upstream.txt"
extra_file="${source_root}/shim-commands.extra.txt"
output_file="${source_root}/shim-commands.txt"
upstream_repo="rtk-ai/rtk"

ref_override=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      ref_override="${2:?missing value for --ref}"
      shift 2
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ -n "${ref_override}" ]]; then
  ref="${ref_override}"
else
  ref="$(tr -d '[:space:]' < "${ref_file}")"
fi

rules_url="https://raw.githubusercontent.com/${upstream_repo}/${ref}/src/discover/rules.rs"
rules_tmp="$(mktemp)"
trap 'rm -f "${rules_tmp}"' EXIT
curl -fsSL "${rules_url}" -o "${rules_tmp}"

python3 - <<'PY' "${rules_tmp}" "${ref}" "${upstream_file}" "${extra_file}" "${output_file}" "${ref_file}" "${ref_override}"
from pathlib import Path
import re
import shlex
import sys

rules_path = Path(sys.argv[1])
ref = sys.argv[2]
upstream_file = Path(sys.argv[3])
extra_file = Path(sys.argv[4])
output_file = Path(sys.argv[5])
ref_file = Path(sys.argv[6])
ref_override = sys.argv[7]

text = rules_path.read_text()
commands = set()
for block in re.findall(r"rewrite_prefixes:\s*&\[(.*?)\]", text, re.S):
    for prefix in re.findall(r'"([^"]+)"', block):
        commands.add(shlex.split(prefix)[0])

upstream_commands = sorted(commands)

extra_commands = []
if extra_file.exists():
    for line in extra_file.read_text().splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        extra_commands.append(stripped)

merged = sorted(set(upstream_commands).union(extra_commands))

upstream_file.write_text(
    "# Generated from rtk-ai/rtk\n"
    f"# Source ref: {ref}\n"
    "\n"
    + "\n".join(upstream_commands)
    + "\n"
)

output_file.write_text(
    "# Generated: upstream manifest plus local extras\n"
    f"# Upstream ref: {ref}\n"
    "\n"
    + "\n".join(merged)
    + "\n"
)

if ref_override:
    ref_file.write_text(ref + "\n")
PY

if [[ -z "${RTK_SHIM_SKIP_SYNC:-}" ]]; then
  "${repo_root}/scripts/sync-shims.sh"
fi

printf 'Updated shim manifest from %s at %s\n' "${upstream_repo}" "${ref}"
