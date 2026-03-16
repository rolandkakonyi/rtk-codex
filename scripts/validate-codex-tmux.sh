#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
session_name="${1:-rtk-codex-validate}"
log_file="/tmp/codex-rtk-shim.log"
output_file="/tmp/${session_name}.txt"
console_file="/tmp/${session_name}.console"
exit_file="/tmp/${session_name}.exit"
prompt_file="$(mktemp)"

cleanup() {
  rm -f "${prompt_file}"
}
trap cleanup EXIT

cat > "${prompt_file}" <<'EOF'
Inspect this repository and use ordinary shell commands, not explicit `rtk ...` commands, to do the following:
1. Run `git status`.
2. Run `ls`.
3. Run `cat AGENTS.md`.

Do not modify any files. In the final response, summarize what you ran and what you observed.
EOF

rm -f "${log_file}" "${output_file}" "${console_file}" "${exit_file}"

if tmux has-session -t "${session_name}" 2>/dev/null; then
  tmux kill-session -t "${session_name}"
fi

tmux new-session -d -s "${session_name}" \
  "cd '${repo_root}' && \
   codex exec --full-auto --color never -C '${repo_root}' -o '${output_file}' - < '${prompt_file}' > '${console_file}' 2>&1; \
   rc=\$?; \
   printf '%s\n' \"\$rc\" > '${exit_file}'"

deadline=$((SECONDS + 180))
while (( SECONDS < deadline )); do
  if [[ -f "${exit_file}" ]]; then
    break
  fi
  sleep 2
done

if [[ ! -f "${exit_file}" ]]; then
  printf 'validation failed: timed out waiting for %s\n' "${exit_file}" >&2
  exit 1
fi

sed -n '1,200p' "${console_file}"

if [[ "$(cat "${exit_file}")" != "0" ]]; then
  printf 'validation failed: Codex exited with %s\n' "$(cat "${exit_file}")" >&2
  exit 1
fi

if [[ ! -f "${output_file}" ]]; then
  printf 'validation failed: Codex did not write %s\n' "${output_file}" >&2
  exit 1
fi

if [[ ! -f "${log_file}" ]]; then
  printf 'validation failed: shim log was not created\n' >&2
  exit 1
fi

grep -E $'\trewrite\tgit status( --porcelain)?\trtk git status( --porcelain)?$' "${log_file}" >/dev/null
grep -E $'\trewrite\tls(\s.*)?\trtk ls(\s.*)?$' "${log_file}" >/dev/null
grep -E $'\trewrite\tcat AGENTS\\.md\trtk read AGENTS\\.md$' "${log_file}" >/dev/null

printf '\nValidation summary\n'
printf 'session: %s\n' "${session_name}"
printf 'shim log: %s\n' "${log_file}"
printf 'codex message: %s\n' "${output_file}"
