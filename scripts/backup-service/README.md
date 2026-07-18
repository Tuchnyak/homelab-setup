# backup-service

Weekly zip backup of the paths listed in `backup.list` into
`/srv/backups/homeserver/` on `homeserver`. Runs as a user-level systemd
timer under `tuchnyak` — no root required. See
`docs/superpowers/specs/2026-07-18-backup-service-design.md` for the full
design rationale.

## Deploying to the server

Run from a checkout of this repo, on a machine with `ssh homeserver` configured:

```bash
scp backup.sh backup.list homeserver:~/backup-service/
scp backup-homeserver.service backup-homeserver.timer homeserver:~/.config/systemd/user/
ssh homeserver 'chmod +x ~/backup-service/backup.sh'
ssh homeserver 'systemctl --user daemon-reload'
ssh homeserver 'systemctl --user enable --now backup-homeserver.timer'
```

(`scp` to `~/backup-service/` and `~/.config/systemd/user/` requires those
directories to exist first — create with `ssh homeserver 'mkdir -p ~/backup-service ~/.config/systemd/user'`.)

## Verifying

```bash
ssh homeserver 'systemctl --user list-timers backup-homeserver.timer'
ssh homeserver 'systemctl --user start backup-homeserver.service'   # trigger a run now
ssh homeserver 'journalctl --user -u backup-homeserver.service -n 20 --no-pager'
ssh homeserver 'ls -la /srv/backups/homeserver/'
```

## Changing what gets backed up

Edit `backup.list` (one absolute path per line, `#` for comments), then
re-`scp` it to `~/backup-service/backup.list` on the server. No service
restart needed — the list is read fresh on every run.
