# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A single-purpose helper for pulling backups of a remote BPP (Bibliografia Publikacji Pracowników) deployment to the local machine. The entire codebase is one shell script: `bpp-backup.sh`. Backup archives produced by the script (`backup-*.tar.gz`) live alongside it.

## How the backup script works

`./bpp-backup.sh <ssh-host>` connects to the given host and:

1. SSHes in and reads `$HOME/bpp-deploy/.env`, extracting `BPP_CONFIGS_DIR` and `COMPOSE_PROJECT_NAME` (falling back to `basename "$BPP_CONFIGS_DIR"` when the latter is unset — this matches the convention documented in the upstream `bpp-deploy/.env.sample`).
2. Streams a single `tar -czf -` over SSH that packages **two** directories: `$HOME/bpp-deploy` and `$BPP_CONFIGS_DIR`. Two `-C` flags are used so the archive contains `bpp-deploy/...` and `<configs-basename>/...` at the top level (no `/home/<user>/` prefix).
3. Writes the stream locally to `./backup-<host>-<compose_project>-<YYYYMMDD-HHMMSS>.tar.gz` via a `.partial` file that is `mv`'d into place only on success; an `EXIT` trap cleans up the partial on failure.

The remote host is assumed to follow the upstream layout: `bpp-deploy` checked out at `$HOME/bpp-deploy`, with `.env` defining `BPP_CONFIGS_DIR` pointing at a configs directory **outside** the deploy repo. Reference layout (for understanding the format) lives at `/Users/mpasternak/Programowanie/bpp-deploy/` on this machine.

## Common commands

- Run a backup: `./bpp-backup.sh deploy@host`
- Syntax check before committing changes: `bash -n bpp-backup.sh`
- Inspect a produced archive: `tar -tzf backup-<host>-<project>-<timestamp>.tar.gz | head`

## Conventions when editing the script

- Keep `set -euo pipefail` and the `trap 'rm -f "$PARTIAL"' EXIT` (cleared with `trap - EXIT` on success) — together they guarantee no half-written archive masquerades as a real backup.
- The remote-side logic runs inside heredocs passed to `ssh "$HOST" 'bash -s'`. Watch the heredoc quoting carefully: the env-reading heredoc uses `<<'REMOTE'` (no expansion, everything resolved on the remote), but the tar heredoc uses unquoted `<<REMOTE_TAR` so that `${BPP_CONFIGS_DIR}` is interpolated locally while `\$HOME`, `\$(dirname …)`, etc. are escaped to run remotely.
- Per the user's global instructions: never silently swallow errors. Any new `if`/`grep`/parse step that can fail must either log+exit or propagate the error.

## License

MIT — see `LICENSE` at the repo root. Copyright © 2026 Michał Pasternak.
