# rtk-codex

Use [rtk](https://github.com/rtk-ai/rtk) transparently inside Codex CLI and Codex Desktop with a TypeScript CLI that installs shim wrappers and a managed Codex `shell_environment_policy`.

## Platform Support

- macOS
- Linux

Windows is not supported at this stage.

## What It Does

- installs machine-level shim binaries into `~/.rtk-codex`
- updates `~/.codex/config.toml` so Codex resolves selected commands through those shims
- lets Codex keep using ordinary commands like `git status`, `ls`, `cat AGENTS.md`, and `gh pr view`
- delegates rewrite decisions to `rtk rewrite`

If RTK rewrites a command, the shim executes the rewritten form. If not, it falls back to the real binary.

## Requirements

- `rtk` installed and available on `PATH`
- Codex using the standard config location at `~/.codex/config.toml`
- Node.js 20 or newer

## Install

Published package flow:

```bash
npx rtk-codex install
```

or:

```bash
bunx rtk-codex install
```

Local checkout flow:

```bash
npm install
npm run build
./install.sh
```

This installs machine-level shims into `~/.rtk-codex` and writes a managed RTK block into `~/.codex/config.toml`.

## Uninstall

Published package flow:

```bash
npx rtk-codex uninstall
```

or:

```bash
bunx rtk-codex uninstall
```

Local checkout flow:

```bash
./uninstall.sh
```

This removes only the managed RTK block from `~/.codex/config.toml`.

It does not delete `~/.rtk-codex`.

## Update Shim Coverage

```bash
npx rtk-codex update
```

Optional pinned-ref override:

```bash
npx rtk-codex update --ref <commit-or-tag>
```

This:

1. fetches the pinned upstream RTK rule source
2. regenerates the upstream command manifest
3. merges local extras
4. regenerates repo-local shim wrappers

Pinned upstream ref:

- [shims/rtk-upstream-ref.txt](/Users/rolandk/Developer/rtk-codex/shims/rtk-upstream-ref.txt)

Local command additions:

- [shims/shim-commands.extra.txt](/Users/rolandk/Developer/rtk-codex/shims/shim-commands.extra.txt)

## Validate

Installer/config tests:

```bash
npm run build
node dist/cli.js test-config
```

Low-level shim rewrite tests:

```bash
node dist/cli.js test-shims
```

Codex CLI end-to-end validation in `tmux`:

```bash
node dist/cli.js validate-tmux
```

## How It Works

`rtk-codex` has two layers:

1. repo-local TypeScript source and shim metadata
2. machine-level installed shims used by Codex

Source of truth in this repo:

- [package.json](/Users/rolandk/Developer/rtk-codex/package.json)
- [tsconfig.json](/Users/rolandk/Developer/rtk-codex/tsconfig.json)
- [install.sh](/Users/rolandk/Developer/rtk-codex/install.sh)
- [uninstall.sh](/Users/rolandk/Developer/rtk-codex/uninstall.sh)
- [src/cli.ts](/Users/rolandk/Developer/rtk-codex/src/cli.ts)
- [src/core.ts](/Users/rolandk/Developer/rtk-codex/src/core.ts)
- [src/templates.ts](/Users/rolandk/Developer/rtk-codex/src/templates.ts)
- [shims/rtk-upstream-ref.txt](/Users/rolandk/Developer/rtk-codex/shims/rtk-upstream-ref.txt)
- [shims/shim-commands.extra.txt](/Users/rolandk/Developer/rtk-codex/shims/shim-commands.extra.txt)

Generated repo-local artifacts:

- `dist/*`
- `shims/bin/*`
- `shims/env.sh`
- `shims/shim-commands.txt`
- `shims/shim-commands.upstream.txt`

Installed machine-level artifacts:

- `~/.rtk-codex/bin/*`
- `~/.rtk-codex/env.sh`
- `~/.rtk-codex/shim-commands.txt`

## Notes

- Codex CLI and Codex Desktop both use the same managed `shell_environment_policy` approach.
- If you need exact native behavior for a command, call the real binary explicitly, for example `/opt/homebrew/bin/git`.
- Shim logging is controlled by `RTK_SHIM_LOG_FILE`. The default managed config uses `/tmp/codex-rtk-shim.log`.
