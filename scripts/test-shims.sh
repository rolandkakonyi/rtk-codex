#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"${repo_root}/scripts/sync-shims.sh"
source "${repo_root}/shims/env.sh"

commands_file="${repo_root}/shims/shim-commands.txt"
bin_dir="${repo_root}/shims/bin"

missing=0
while IFS= read -r command_name; do
  [[ -z "${command_name}" ]] && continue
  [[ "${command_name}" =~ ^[[:space:]]*# ]] && continue
  if [[ ! -x "${bin_dir}/${command_name}" ]]; then
    printf 'missing wrapper: %s\n' "${command_name}" >&2
    missing=1
  fi
done < "${commands_file}"

if [[ "${missing}" -ne 0 ]]; then
  exit 1
fi

run_case() {
  local description="$1"
  local expected="$2"
  shift 2

  local output
  output="$(RTK_SHIM_DRY_RUN=1 "$@" 2>/dev/null)"
  if [[ "${output}" != "${expected}" ]]; then
    printf 'FAIL  %s\nexpected: %s\nactual:   %s\n' "${description}" "${expected}" "${output}" >&2
    exit 1
  fi
  printf 'PASS  %s\n' "${description}"
}

run_case "git status" $'REWRITE\tgit status\trtk git status' git status
run_case "env + git status" $'REWRITE\tenv GIT_PAGER=cat git status\tenv GIT_PAGER=cat rtk git status' env GIT_PAGER=cat git status
run_case "sudo + git status" $'REWRITE\tsudo git status\tsudo rtk git status' sudo git status
run_case "gh release list" $'REWRITE\tgh release list\trtk gh release list' gh release list
run_case "cargo test" $'REWRITE\tcargo test\trtk cargo test' cargo test
run_case "pnpm outdated" $'REWRITE\tpnpm outdated\trtk pnpm outdated' pnpm outdated
run_case "npm run build" $'REWRITE\tnpm run build\trtk npm run build' npm run build
run_case "npx prisma migrate" $'REWRITE\tnpx prisma migrate\trtk prisma migrate' npx prisma migrate
run_case "cat file" $'REWRITE\tcat AGENTS.md\trtk read AGENTS.md' cat AGENTS.md
run_case "head -20 file" $'REWRITE\thead -20 AGENTS.md\trtk read AGENTS.md --max-lines 20' head -20 AGENTS.md
run_case "tail -n 5 file" $'REWRITE\ttail -n 5 AGENTS.md\trtk read AGENTS.md --tail-lines 5' tail -n 5 AGENTS.md
run_case "grep pattern" $'REWRITE\tgrep -rn pattern src/\trtk grep -rn pattern src/' grep -rn pattern src/
run_case "rg pattern" $'REWRITE\trg pattern src/\trtk grep pattern src/' rg pattern src/
run_case "ls -la" $'REWRITE\tls -la\trtk ls -la' ls -la
run_case "find name" $'REWRITE\tfind -name \\*.ts src/\trtk find -name \\*.ts src/' find -name '*.ts' src/
run_case "tsc" $'REWRITE\ttsc --noEmit\trtk tsc --noEmit' tsc --noEmit
run_case "eslint" $'REWRITE\teslint src\trtk lint src' eslint src
run_case "prettier" $'REWRITE\tprettier --check .\trtk prettier --check .' prettier --check .
run_case "next build" $'REWRITE\tnext build\trtk next' next build
run_case "vitest" $'REWRITE\tvitest run\trtk vitest run' vitest run
run_case "playwright" $'REWRITE\tplaywright test\trtk playwright test' playwright test
run_case "docker compose logs" $'REWRITE\tdocker compose logs web\trtk docker compose logs web' docker compose logs web
run_case "kubectl describe" $'REWRITE\tkubectl describe pod foo\trtk kubectl describe pod foo' kubectl describe pod foo
run_case "tree" $'REWRITE\ttree src/\trtk tree src/' tree src/
run_case "diff" $'REWRITE\tdiff a b\trtk diff a b' diff a b
run_case "curl" $'REWRITE\tcurl -s https://example.com\trtk curl -s https://example.com' curl -s https://example.com
run_case "wget" $'REWRITE\twget https://example.com/file\trtk wget https://example.com/file' wget https://example.com/file
run_case "python -m mypy" $'REWRITE\tpython -m mypy src\trtk mypy src' python -m mypy src
run_case "ruff check" $'REWRITE\truff check src\trtk ruff check src' ruff check src
run_case "python -m pytest" $'REWRITE\tpython -m pytest tests\trtk pytest tests' python -m pytest tests
run_case "uv pip install" $'REWRITE\tuv pip install requests\trtk uv pip install requests' uv pip install requests
run_case "go test" $'REWRITE\tgo test ./...\trtk go test ./...' go test ./...
run_case "golangci-lint" $'REWRITE\tgolangci-lint run\trtk golangci-lint run' golangci-lint run
run_case "aws" $'REWRITE\taws sts get-caller-identity\trtk aws sts get-caller-identity' aws sts get-caller-identity
run_case "psql" $'REWRITE\tpsql -c select\\ 1\trtk psql -c select\\ 1' psql -c 'select 1'
run_case "brew install" $'REWRITE\tbrew install jq\trtk brew install jq' brew install jq
run_case "dotnet build" $'REWRITE\tdotnet build\trtk dotnet build' dotnet build
run_case "terraform plan" $'REWRITE\tterraform plan\trtk terraform plan' terraform plan
run_case "tofu plan" $'REWRITE\ttofu plan\trtk tofu plan' tofu plan
run_case "uv sync" $'REWRITE\tuv sync\trtk uv sync' uv sync
run_case "fallback env true" $'FALLBACK\tenv true\t/usr/bin/env' env true
