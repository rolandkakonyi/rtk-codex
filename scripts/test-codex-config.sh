#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

config_file="${tmp_dir}/config.toml"
shim_home="${tmp_dir}/.rtk-codex"

cat > "${config_file}" <<'EOF'
model = "gpt-5.4"

[notice]
hide_rate_limit_model_nudge = true
EOF

base_path="/Users/rolandk/.codex/tmp/arg0/test:/opt/homebrew/bin:/usr/bin:/bin"
log_file="/tmp/rtk-shim-test.log"

CODEX_HOME="${tmp_dir}" \
RTK_SHIM_HOME="${shim_home}" \
PATH="${base_path}" \
RTK_SHIM_REAL_PATH="${base_path}" \
RTK_SHIM_LOG_FILE="${log_file}" \
"${repo_root}/scripts/install-codex-config.sh"

python3 - <<'PY' "${config_file}" "${shim_home}" "${base_path}" "${log_file}"
from pathlib import Path
import sys
import tomllib

config_path = Path(sys.argv[1])
shim_home = Path(sys.argv[2])
base_path = sys.argv[3]
log_file = sys.argv[4]
expected_real_path = ":".join(
    part for part in base_path.split(":") if "/.codex/tmp/arg0/" not in part
)

text = config_path.read_text()
assert "# BEGIN RTK SHIM CONFIG" in text
assert "# END RTK SHIM CONFIG" in text

data = tomllib.loads(text)
policy = data["shell_environment_policy"]["set"]

assert data["model"] == "gpt-5.4"
assert data["notice"]["hide_rate_limit_model_nudge"] is True
assert policy["PATH"].startswith(f"{shim_home}/bin:")
assert policy["RTK_SHIM_ROOT"] == str(shim_home)
assert policy["RTK_SHIM_REAL_PATH"] == expected_real_path
assert policy["RTK_SHIM_LOG_FILE"] == log_file
assert (shim_home / "bin" / "rtk-shim").exists()
assert (shim_home / "bin" / "git").exists()
assert (shim_home / "env.sh").exists()
PY

first_contents="$(cat "${config_file}")"

CODEX_HOME="${tmp_dir}" \
RTK_SHIM_HOME="${shim_home}" \
PATH="${base_path}" \
RTK_SHIM_REAL_PATH="${base_path}" \
RTK_SHIM_LOG_FILE="${log_file}" \
"${repo_root}/scripts/install-codex-config.sh"

second_contents="$(cat "${config_file}")"
[[ "${first_contents}" == "${second_contents}" ]]

CODEX_HOME="${tmp_dir}" "${repo_root}/scripts/uninstall-codex-config.sh"

python3 - <<'PY' "${config_file}"
from pathlib import Path
import sys
import tomllib

config_path = Path(sys.argv[1])
text = config_path.read_text()
assert "# BEGIN RTK SHIM CONFIG" not in text
assert "[shell_environment_policy]" not in text
data = tomllib.loads(text)
assert data["model"] == "gpt-5.4"
assert data["notice"]["hide_rate_limit_model_nudge"] is True
PY

cat > "${config_file}" <<EOF
model = "gpt-5.4"

[shell_environment_policy]
inherit = "all"

[shell_environment_policy.set]
PATH = "${shim_home}/bin:${base_path}"
RTK_SHIM_ROOT = "${shim_home}"
RTK_SHIM_REAL_PATH = "/opt/homebrew/bin:/usr/bin:/bin"
RTK_SHIM_LOG_FILE = "${log_file}"
EOF

CODEX_HOME="${tmp_dir}" \
RTK_SHIM_HOME="${shim_home}" \
PATH="${base_path}" \
RTK_SHIM_REAL_PATH="${base_path}" \
RTK_SHIM_LOG_FILE="${log_file}" \
"${repo_root}/scripts/install-codex-config.sh"

python3 - <<'PY' "${config_file}"
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
assert "# BEGIN RTK SHIM CONFIG" in text
assert text.count("[shell_environment_policy]") == 1
PY

cat > "${config_file}" <<'EOF'
model = "gpt-5.4"

[shell_environment_policy]
inherit = "all"
EOF

if CODEX_HOME="${tmp_dir}" RTK_SHIM_HOME="${shim_home}" PATH="${base_path}" RTK_SHIM_REAL_PATH="${base_path}" "${repo_root}/scripts/install-codex-config.sh" >/dev/null 2>&1; then
  printf 'expected installer conflict check to fail\n' >&2
  exit 1
fi

printf 'Codex config install/uninstall tests passed\n'
