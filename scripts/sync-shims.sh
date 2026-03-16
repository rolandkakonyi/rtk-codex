#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${repo_root}/shims"
target_root="${RTK_SHIM_TARGET_ROOT:-${source_root}}"
bin_dir="${target_root}/bin"
commands_file="${source_root}/shim-commands.txt"
shim_source="${repo_root}/scripts/rtk-shim-dispatcher.sh"
env_file="${target_root}/env.sh"

if [[ -n "${RTK_SHIM_REAL_PATH:-}" ]]; then
  export PATH="${RTK_SHIM_REAL_PATH}"
fi

if [[ ! -f "${commands_file}" ]]; then
  RTK_SHIM_SKIP_SYNC=1 "${repo_root}/scripts/update-rtk-supported-commands.sh"
fi

if [[ ! -f "${shim_source}" ]]; then
  printf 'missing shim dispatcher source: %s\n' "${shim_source}" >&2
  exit 1
fi

mkdir -p "${bin_dir}"

cat > "${env_file}" <<'EOF'
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
EOF

chmod +x "${env_file}"

if [[ "${shim_source}" != "${bin_dir}/rtk-shim" ]]; then
  cp "${shim_source}" "${bin_dir}/rtk-shim"
  chmod +x "${bin_dir}/rtk-shim"
fi

find "${bin_dir}" -maxdepth 1 -type f ! -name 'rtk-shim' -delete

while IFS= read -r command_name; do
  [[ -z "${command_name}" ]] && continue
  [[ "${command_name}" =~ ^[[:space:]]*# ]] && continue

  cat > "${bin_dir}/${command_name}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

export RTK_SHIM_COMMAND="${command_name}"
exec "\$(dirname "\$0")/rtk-shim" "\$@"
EOF

  chmod +x "${bin_dir}/${command_name}"
done < "${commands_file}"
