# Weekly backup service — design

## Purpose

Weekly, unattended backup of user documents/notes on `homeserver`. Currently this means only
`/srv/syncthing/data` (~578 MiB: `my-brain-sync-data`, `my-notes-full`, `quick-notes`, plus an
empty legacy `my-brain-sync` folder) — Syncthing-synced documents and text files. Everything else
under `/srv` is either handled separately (Nextcloud — backed up manually via laptop sync) or is
replaceable media/downloads (Jellyfin, qBittorrent) not worth backing up.

## Context / investigation findings

- `/srv/backups/homeserver/` already exists (empty), created by the user as the intended target
  directory for this service.
- Several `/srv` service data directories (`nextcloud/db`, `nextcloud/html/data`, `firefly/db`,
  `syncthing/config`, `training/db/pg`) are **not readable** by the `tuchnyak` user — owned by
  container-internal UIDs (e.g. `100999`). `/srv/syncthing/data` itself *is* world-readable
  (`drwxr-xr-x`, owned by `100999:100999`), confirmed via `du`/`ls` without sudo.
- Tarring/zipping a live database's raw data directory risks an inconsistent backup — out of scope
  here since DB directories are excluded entirely (Nextcloud handled manually; other DBs not
  requested for backup).
- All other custom automation on this host already runs as **rootless Podman Quadlet** user-level
  systemd units (`~/arch-services/*.container` → generated `container-*.service`, env files in
  `~/compose/*.env`). `loginctl show-user tuchnyak` confirms `Linger=yes`, so user-level systemd
  timers run reliably even without an active login session — same mechanism the container services
  already rely on.
- `/usr/local/bin` and `~` have no existing precedent for standalone backup scripts — this is new
  ground, so it follows the closest existing convention (a dedicated named folder under `~`, like
  `arch-services` / `compose`).
- No `cron` package is installed on this host (confirmed earlier in this session) — scheduling here
  uses systemd timers exclusively, consistent with the rest of the box.
- Existing scheduled jobs land at 04:00 Asia/Yerevan on Sundays (`snapper-timeline.timer`) and daily
  (`apt-daily-upgrade.timer`, also 04:00 after this session's earlier reschedule). To avoid stacking
  I/O-heavy jobs at the same instant, this service runs on a different day (**Friday**) rather than
  sharing Sunday 04:00.
- `zip` was not installed on the server; the user has since installed it manually.

## Architecture

**User-level systemd timer**, running as `tuchnyak`, no root — matches the existing container-service
pattern on this host and needs no elevated privileges, since the only backed-up path is already
readable by this user. Rejected alternative: a system-level (root) timer — would work too, but adds
unnecessary privilege for no benefit and breaks from the established convention on this box.

Script source lives in this git repo (`scripts/backup-service/`) for version history and review;
deployment to the server is a manual copy (no CI/CD for this repo).

## Components

- **`scripts/backup-service/backup.list`** — plain text, one absolute path per line. Blank lines and
  `#`-prefixed lines are ignored. Ships with one active entry (`/srv/syncthing/data`) and a few
  commented-out candidates (`/srv/adguardhome`, `/srv/npm`, `/srv/misc_data`) as a hint for future
  additions.

- **`scripts/backup-service/backup.sh`** — the backup script:
  1. Reads `backup.list` (relative to the script's own directory), skipping blank/comment lines.
  2. For each listed path: if it doesn't exist, log a warning and skip it (does not abort the whole
     run — a single missing/unmounted directory shouldn't block backing up the rest).
  3. If at least one path exists, `zip -r` all of them into
     `/srv/backups/homeserver/homeserver-backup_YYYY-MM-DD.zip` (date = run date). If none exist,
     exit non-zero without creating an archive. Re-running on the same day intentionally overwrites
     that day's archive (idempotent by date, not by run).
  4. Retention: after a successful archive, list `homeserver-backup_*.zip` in the target directory
     sorted by name (which sorts chronologically given the `YYYY-MM-DD` naming), keep the newest 8,
     delete the rest.
  5. `set -euo pipefail`; a `trap` on `ERR`/`EXIT` removes a partially-written archive so a failed
     run never leaves a corrupt zip counted toward retention.

- **`scripts/backup-service/backup-homeserver.service`** + **`backup-homeserver.timer`** — systemd
  **user** unit templates (deployed to `~/.config/systemd/user/` on the server):
  - Service: `Type=oneshot`, `ExecStart=%h/backup-service/backup.sh`.
  - Timer: `OnCalendar=Fri *-*-* 04:00:00` (interpreted in the server's local timezone,
    `Asia/Yerevan`, set earlier this session), `Persistent=true` (catches up on next boot if the
    server was off at the scheduled time).

- **Logging**: no dedicated log file — relies on the systemd journal
  (`journalctl --user -u backup-homeserver.service`), consistent with how every other job on this
  host was inspected during this session.

## Deployment steps (server-side, manual)

1. `zip` package — already installed by the user.
2. Copy `scripts/backup-service/{backup.sh,backup.list}` to `~/backup-service/` on the server;
   `chmod +x backup.sh`.
3. Copy the two unit files to `~/.config/systemd/user/`.
4. `systemctl --user daemon-reload`
5. `systemctl --user enable --now backup-homeserver.timer`
6. Verify: `systemctl --user list-timers backup-homeserver.timer`.

## Error handling

- Missing source directory → warning + skip, run continues.
- Zero valid source directories → exit non-zero, no archive created, no retention cleanup runs.
- `zip` failure (disk full, permissions, etc.) → script exits non-zero via `set -e`; partial archive
  is removed by the `ERR`/`EXIT` trap; failure is visible via `systemctl --user status
  backup-homeserver.service` / `journalctl --user -u backup-homeserver.service` and via the "last"
  column of `systemctl --user list-timers`. No separate alerting — single-user home server, checked
  manually.

## Out of scope

- Database-aware backups (`pg_dump` etc.) for Nextcloud/Firefly/training Postgres data.
- Off-box copy of the resulting archives (3-2-1 strategy's "copy 2" — separate, pre-existing concern
  from guide chapter 6, not addressed here).
- Alerting/notifications on failure.
