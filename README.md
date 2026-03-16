# rtk-codex

Use [rtk](https://github.com/rtk-ai/rtk) transparently inside Codex CLI and Codex Desktop by installing a shim layer and a managed Codex `shell_environment_policy`.

## What It Does

- installs machine-level shim binaries into `~/.rtk-codex`
- updates `~/.codex/config.toml` so Codex resolves selected commands through those shims
- lets Codex keep using ordinary commands like `git status`, `ls`, `cat AGENTS.md`, and `gh pr view`
- delegates rewrite decisions to `rtk rewrite`

If RTK rewrites a command, the shim executes the rewritten form. If not, it falls back to the real binary.

## Requirements

- `rtk` installed and available on `PATH`
- `codex` using the standard config location at `~/.codex/config.toml`
- `bash`, `curl`, and `python3`

## Install

```bash
./install.sh
```

This will:

1. generate the repo-local shim artifacts if needed
2. install machine-level shims into `~/.rtk-codex`
3. write a managed RTK block into `~/.codex/config.toml`

## Uninstall

```bash
./uninstall.sh
```

This removes only the managed RTK block from `~/.codex/config.toml`.

It does not delete `~/.rtk-codex`.

## Update Shim Coverage

```bash
./scripts/update-rtk-supported-commands.sh
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

Low-level shim tests:

```bash
./scripts/test-shims.sh
```

Installer/config tests:

```bash
./scripts/test-codex-config.sh
```

Codex CLI end-to-end validation in `tmux`:

```bash
./scripts/validate-codex-tmux.sh
```

## How It Works

`rtk-codex` has two layers:

1. Repo-local source and generation logic
2. Machine-level installed shims used by Codex

Source of truth in this repo:

- [install.sh](/Users/rolandk/Developer/rtk-codex/install.sh)
- [uninstall.sh](/Users/rolandk/Developer/rtk-codex/uninstall.sh)
- [scripts/install-codex-config.sh](/Users/rolandk/Developer/rtk-codex/scripts/install-codex-config.sh)
- [scripts/install-shims.sh](/Users/rolandk/Developer/rtk-codex/scripts/install-shims.sh)
- [scripts/sync-shims.sh](/Users/rolandk/Developer/rtk-codex/scripts/sync-shims.sh)
- [scripts/update-rtk-supported-commands.sh](/Users/rolandk/Developer/rtk-codex/scripts/update-rtk-supported-commands.sh)
- [scripts/rtk-shim-dispatcher.sh](/Users/rolandk/Developer/rtk-codex/scripts/rtk-shim-dispatcher.sh)
- [shims/rtk-upstream-ref.txt](/Users/rolandk/Developer/rtk-codex/shims/rtk-upstream-ref.txt)
- [shims/shim-commands.extra.txt](/Users/rolandk/Developer/rtk-codex/shims/shim-commands.extra.txt)

Generated repo-local artifacts:

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
