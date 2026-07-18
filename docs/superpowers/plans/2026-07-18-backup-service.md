# Weekly Backup Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and deploy a weekly, unattended zip backup of `/srv/syncthing/data` on `homeserver`, driven by a pure-bash script and a user-level systemd timer.

**Architecture:** A single bash script (`backup.sh`) reads a plain-text list of source paths, zips whatever exists into a dated archive under `/srv/backups/homeserver/`, prunes old archives beyond a retention count, and is triggered weekly by a `systemctl --user` timer (no root, no cron — matches the existing Podman-Quadlet convention on this host).

**Tech Stack:** bash (5.x), `zip`/`unzip`, systemd user units (`Type=oneshot` service + `OnCalendar` timer).

## Global Constraints

- No new language runtimes or test frameworks — plain bash, verified with hand-rolled shell test scripts (repo has no existing test tooling).
- User-level systemd only (`systemctl --user`), never root/system-level — the only backed-up path (`/srv/syncthing/data`) is already readable by `tuchnyak`.
- No cron — not installed on `homeserver`, and not used anywhere else on the box.
- Archive format: `zip`. Retention: keep newest 8 archives. Filename: `homeserver-backup_YYYY-MM-DD.zip`.
- Schedule: `Fri *-*-* 04:00:00`, interpreted in the server's local timezone (`Asia/Yerevan`, already configured).
- No dedicated log file — rely on `journalctl --user -u backup-homeserver.service`.
- Script/unit source lives in this repo at `scripts/backup-service/`; deployment to the server is a manual file copy (this repo has no CI/CD).
- Spec: `docs/superpowers/specs/2026-07-18-backup-service-design.md`.

---

## File Structure

- `scripts/backup-service/backup.sh` — the backup script (create in Task 1, extend in Task 2).
- `scripts/backup-service/backup.list` — property file listing source paths (Task 1).
- `scripts/backup-service/test/test_backup_core.sh` — test for list parsing, zip creation, missing-path handling (Task 1).
- `scripts/backup-service/test/test_backup_retention.sh` — test for retention pruning and same-day overwrite (Task 2).
- `scripts/backup-service/backup-homeserver.service` — systemd user service unit (Task 3).
- `scripts/backup-service/backup-homeserver.timer` — systemd user timer unit (Task 3).
- `scripts/backup-service/README.md` — deployment instructions (Task 4).

---

### Task 1: `backup.sh` core (list parsing, zip creation, missing-path handling)

**Files:**
- Create: `scripts/backup-service/backup.list`
- Create: `scripts/backup-service/backup.sh`
- Test: `scripts/backup-service/test/test_backup_core.sh`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `backup.sh` accepts env vars `BACKUP_LIST` (default: `backup.list` next to the script), `BACKUP_DEST` (default: `/srv/backups/homeserver`). Reads newline-separated paths from `BACKUP_LIST`, skipping blank lines and lines starting with `#`. Writes `$BACKUP_DEST/homeserver-backup_<YYYY-MM-DD>.zip`. Exits 1 with no archive written if zero listed paths exist. Later tasks (2, 3) depend on this exact env-var interface and exit-code behavior.

- [ ] **Step 1: Write `backup.list`**

```
# Weekly backup source list — one absolute path per line.
# Blank lines and lines starting with # are ignored.

/srv/syncthing/data

# Candidates for later, currently excluded:
# /srv/adguardhome
# /srv/npm
# /srv/misc_data
```

Save as `scripts/backup-service/backup.list`.

- [ ] **Step 2: Write the test script (will fail — `backup.sh` doesn't exist yet)**

Create `scripts/backup-service/test/test_backup_core.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SH="$SCRIPT_DIR/../backup.sh"

# Scenario 1: one valid path + one missing path -> archive created, warning printed
TESTDIR1="$(mktemp -d)"
TESTDIR2="$(mktemp -d)"
cleanup() { rm -rf "$TESTDIR1" "$TESTDIR2"; }
trap cleanup EXIT

mkdir -p "$TESTDIR1/src1" "$TESTDIR1/dest"
echo "hello" > "$TESTDIR1/src1/file.txt"
cat > "$TESTDIR1/backup.list" <<EOF
# comment line, should be ignored

$TESTDIR1/src1
$TESTDIR1/does-not-exist
EOF

OUTPUT="$(BACKUP_LIST="$TESTDIR1/backup.list" BACKUP_DEST="$TESTDIR1/dest" "$BACKUP_SH" 2>&1)"

echo "$OUTPUT" | grep -q "WARN: skipping missing path: $TESTDIR1/does-not-exist" || {
    echo "FAIL: expected warning about missing path not found"
    echo "$OUTPUT"
    exit 1
}

ARCHIVE="$TESTDIR1/dest/homeserver-backup_$(date +%F).zip"
[[ -f "$ARCHIVE" ]] || { echo "FAIL: archive not created at $ARCHIVE"; exit 1; }

unzip -l "$ARCHIVE" | grep -q "file.txt" || { echo "FAIL: archive does not contain expected file"; exit 1; }

echo "PASS: scenario 1 (basic run, missing path skipped)"

# Scenario 2: all listed paths missing -> exit non-zero, no archive written
mkdir -p "$TESTDIR2/dest"
echo "$TESTDIR2/nope" > "$TESTDIR2/backup.list"

if BACKUP_LIST="$TESTDIR2/backup.list" BACKUP_DEST="$TESTDIR2/dest" "$BACKUP_SH" 2>/dev/null; then
    echo "FAIL: expected non-zero exit when no valid paths exist"
    exit 1
fi
[[ -z "$(ls -A "$TESTDIR2/dest" 2>/dev/null)" ]] || { echo "FAIL: dest should be empty, no archive should have been written"; exit 1; }

echo "PASS: scenario 2 (all paths missing -> fail, no archive)"
echo "PASS: test_backup_core.sh"
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `chmod +x scripts/backup-service/test/test_backup_core.sh && ./scripts/backup-service/test/test_backup_core.sh`
Expected: FAIL — `backup.sh: No such file or directory` (or similar), non-zero exit.

- [ ] **Step 4: Write `backup.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_LIST="${BACKUP_LIST:-$SCRIPT_DIR/backup.list}"
BACKUP_DEST="${BACKUP_DEST:-/srv/backups/homeserver}"
RETENTION_COUNT="${RETENTION_COUNT:-8}"

ARCHIVE_NAME="homeserver-backup_$(date +%F).zip"
ARCHIVE_PATH="$BACKUP_DEST/$ARCHIVE_NAME"
PARTIAL_PATH="$ARCHIVE_PATH.partial"

cleanup() {
    [[ -f "$PARTIAL_PATH" ]] && rm -f "$PARTIAL_PATH"
    return 0
}
trap cleanup ERR EXIT

mkdir -p "$BACKUP_DEST"

paths=()
while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(echo -n "$line" | xargs)"
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ -e "$line" ]]; then
        paths+=("$line")
    else
        echo "WARN: skipping missing path: $line" >&2
    fi
done < "$BACKUP_LIST"

if [[ ${#paths[@]} -eq 0 ]]; then
    echo "ERROR: no valid paths to back up" >&2
    exit 1
fi

rm -f "$PARTIAL_PATH"
zip -r -q "$PARTIAL_PATH" "${paths[@]}"
mv "$PARTIAL_PATH" "$ARCHIVE_PATH"
echo "Created $ARCHIVE_PATH"
```

Save as `scripts/backup-service/backup.sh`, then `chmod +x scripts/backup-service/backup.sh`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `./scripts/backup-service/test/test_backup_core.sh`
Expected:
```
PASS: scenario 1 (basic run, missing path skipped)
PASS: scenario 2 (all paths missing -> fail, no archive)
PASS: test_backup_core.sh
```

- [ ] **Step 6: Commit**

```bash
git add scripts/backup-service/backup.sh scripts/backup-service/backup.list scripts/backup-service/test/test_backup_core.sh
git commit -m "$(cat <<'EOF'
Add backup.sh core: list parsing, zip creation, missing-path handling

Reads BACKUP_LIST (plain path-per-line, # comments), zips whatever
exists into BACKUP_DEST/homeserver-backup_<date>.zip, skips missing
paths with a warning instead of aborting, fails without writing an
archive if nothing exists to back up.
EOF
)"
```

---

### Task 2: Retention/rotation + same-day overwrite

**Files:**
- Modify: `scripts/backup-service/backup.sh` (append retention block after archive creation)
- Test: `scripts/backup-service/test/test_backup_retention.sh`

**Interfaces:**
- Consumes: `backup.sh`'s `BACKUP_LIST`/`BACKUP_DEST` env vars and archive-naming convention from Task 1.
- Produces: `backup.sh` additionally accepts env var `RETENTION_COUNT` (default: `8`). After writing today's archive, keeps only the `RETENTION_COUNT` newest `homeserver-backup_*.zip` files in `BACKUP_DEST`, deleting the rest. Task 4's deployed timer relies on the default of 8.

- [ ] **Step 1: Write the test script (will fail — retention not implemented yet)**

Create `scripts/backup-service/test/test_backup_retention.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SH="$SCRIPT_DIR/../backup.sh"

TESTDIR="$(mktemp -d)"
trap 'rm -rf "$TESTDIR"' EXIT

mkdir -p "$TESTDIR/src1" "$TESTDIR/dest"
echo "hello" > "$TESTDIR/src1/file.txt"
echo "$TESTDIR/src1" > "$TESTDIR/backup.list"

# Pre-seed 10 fake old archives, all older than "today"
for i in $(seq -w 1 10); do
    touch "$TESTDIR/dest/homeserver-backup_2020-01-$i.zip"
done

RETENTION_COUNT=3 BACKUP_LIST="$TESTDIR/backup.list" BACKUP_DEST="$TESTDIR/dest" "$BACKUP_SH" >/dev/null

COUNT="$(find "$TESTDIR/dest" -maxdepth 1 -name 'homeserver-backup_*.zip' | wc -l)"
[[ "$COUNT" -eq 3 ]] || { echo "FAIL: expected 3 archives retained (RETENTION_COUNT), got $COUNT"; exit 1; }

TODAY_ARCHIVE="$TESTDIR/dest/homeserver-backup_$(date +%F).zip"
[[ -f "$TODAY_ARCHIVE" ]] || { echo "FAIL: today's archive missing"; exit 1; }

for i in 09 10; do
    [[ -f "$TESTDIR/dest/homeserver-backup_2020-01-$i.zip" ]] || { echo "FAIL: expected retained old archive 2020-01-$i missing"; exit 1; }
done
for i in 01 02 03 04 05 06 07 08; do
    [[ ! -f "$TESTDIR/dest/homeserver-backup_2020-01-$i.zip" ]] || { echo "FAIL: expected old archive 2020-01-$i to be pruned"; exit 1; }
done

echo "PASS: scenario 1 (retention keeps newest RETENTION_COUNT)"

# Scenario 2: same-day rerun overwrites in place, total count unchanged
SUM1="$(md5sum "$TODAY_ARCHIVE" | cut -d' ' -f1)"
echo "changed" >> "$TESTDIR/src1/file.txt"
RETENTION_COUNT=3 BACKUP_LIST="$TESTDIR/backup.list" BACKUP_DEST="$TESTDIR/dest" "$BACKUP_SH" >/dev/null
SUM2="$(md5sum "$TODAY_ARCHIVE" | cut -d' ' -f1)"
[[ "$SUM1" != "$SUM2" ]] || { echo "FAIL: archive was not overwritten on same-day rerun"; exit 1; }

COUNT2="$(find "$TESTDIR/dest" -maxdepth 1 -name 'homeserver-backup_*.zip' | wc -l)"
[[ "$COUNT2" -eq 3 ]] || { echo "FAIL: expected still 3 archives after same-day rerun, got $COUNT2"; exit 1; }

echo "PASS: scenario 2 (same-day rerun overwrites, no duplicate)"
echo "PASS: test_backup_retention.sh"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `chmod +x scripts/backup-service/test/test_backup_retention.sh && ./scripts/backup-service/test/test_backup_retention.sh`
Expected: FAIL at the first `COUNT` check — all 11 archives present (10 pre-seeded + today's), since retention pruning doesn't exist yet.

- [ ] **Step 3: Add retention logic to `backup.sh`**

Append to the end of `scripts/backup-service/backup.sh` (after the `echo "Created $ARCHIVE_PATH"` line):

```bash

mapfile -t old_archives < <(find "$BACKUP_DEST" -maxdepth 1 -name 'homeserver-backup_*.zip' -printf '%f\n' | sort -r | tail -n "+$((RETENTION_COUNT + 1))")
for old in "${old_archives[@]}"; do
    echo "Removing old archive: $old"
    rm -f "$BACKUP_DEST/$old"
done
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `./scripts/backup-service/test/test_backup_retention.sh`
Expected:
```
PASS: scenario 1 (retention keeps newest RETENTION_COUNT)
PASS: scenario 2 (same-day rerun overwrites, no duplicate)
PASS: test_backup_retention.sh
```

- [ ] **Step 5: Re-run Task 1's test to confirm no regression**

Run: `./scripts/backup-service/test/test_backup_core.sh`
Expected: same three `PASS` lines as in Task 1, Step 5.

- [ ] **Step 6: Commit**

```bash
git add scripts/backup-service/backup.sh scripts/backup-service/test/test_backup_retention.sh
git commit -m "$(cat <<'EOF'
Add retention pruning to backup.sh

Keeps the newest RETENTION_COUNT (default 8) homeserver-backup_*.zip
archives in BACKUP_DEST after each run, deleting older ones. Reruns on
the same day overwrite that day's archive in place rather than
duplicating it.
EOF
)"
```

---

### Task 3: systemd user unit files

**Files:**
- Create: `scripts/backup-service/backup-homeserver.service`
- Create: `scripts/backup-service/backup-homeserver.timer`

**Interfaces:**
- Consumes: the deployed script path convention `%h/backup-service/backup.sh` (i.e., `~/backup-service/backup.sh` once deployed — see Task 4).
- Produces: unit pair named `backup-homeserver.{service,timer}`, consumed by Task 4's `systemctl --user enable --now backup-homeserver.timer`.

- [ ] **Step 1: Write the service unit**

Create `scripts/backup-service/backup-homeserver.service`:

```ini
[Unit]
Description=Weekly backup of homeserver documents to /srv/backups/homeserver

[Service]
Type=oneshot
ExecStart=%h/backup-service/backup.sh
```

- [ ] **Step 2: Write the timer unit**

Create `scripts/backup-service/backup-homeserver.timer`:

```ini
[Unit]
Description=Weekly timer for backup-homeserver.service

[Timer]
OnCalendar=Fri *-*-* 04:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

- [ ] **Step 3: Verify the units with `systemd-analyze` (self-contained, no changes to your real home directory)**

Run:
```bash
TMPHOME="$(mktemp -d)"
mkdir -p "$TMPHOME/backup-service"
cp scripts/backup-service/backup.sh "$TMPHOME/backup-service/backup.sh"
chmod +x "$TMPHOME/backup-service/backup.sh"
HOME="$TMPHOME" systemd-analyze --user verify scripts/backup-service/backup-homeserver.service scripts/backup-service/backup-homeserver.timer
echo "exit=$?"
rm -rf "$TMPHOME"
```
Expected: no output, `exit=0`. (The `HOME` override makes `%h` resolve to a throwaway directory containing a stand-in executable, purely so `systemd-analyze` can confirm `ExecStart` points at something real — this doesn't touch your actual `$HOME`.)

- [ ] **Step 4: Commit**

```bash
git add scripts/backup-service/backup-homeserver.service scripts/backup-service/backup-homeserver.timer
git commit -m "$(cat <<'EOF'
Add systemd user unit pair for the weekly backup timer

Type=oneshot service running ~/backup-service/backup.sh, triggered by
a timer at Fri 04:00 server-local time (Asia/Yerevan), deliberately on
a different day from the existing Sunday 04:00 snapper/apt jobs to
avoid stacking I/O. Persistent=true catches up after downtime.
EOF
)"
```

---

### Task 4: Deployment README + deploy to `homeserver`

**Files:**
- Create: `scripts/backup-service/README.md`
- Deploy (server-side, via SSH — no sudo needed, all user-level): copy files to `~/backup-service/` and `~/.config/systemd/user/` on `homeserver`, enable the timer, verify a real run.

**Interfaces:**
- Consumes: all artifacts from Tasks 1–3 (`backup.sh`, `backup.list`, the two unit files).
- Produces: a running `backup-homeserver.timer` on `homeserver` and this task's own verification that a manually-triggered run produces a real archive in `/srv/backups/homeserver/`.

- [ ] **Step 1: Write the README**

Create `scripts/backup-service/README.md`:

```markdown
# backup-service

Weekly zip backup of the paths listed in `backup.list` into
`/srv/backups/homeserver/` on `homeserver`. Runs as a user-level systemd
timer under `tuchnyak` — no root required. See
`docs/superpowers/specs/2026-07-18-backup-service-design.md` for the full
design rationale.

## Deploying to the server

Run from a checkout of this repo, on a machine with `ssh homeserver` configured:

\`\`\`bash
scp backup.sh backup.list homeserver:~/backup-service/
scp backup-homeserver.service backup-homeserver.timer homeserver:~/.config/systemd/user/
ssh homeserver 'chmod +x ~/backup-service/backup.sh'
ssh homeserver 'systemctl --user daemon-reload'
ssh homeserver 'systemctl --user enable --now backup-homeserver.timer'
\`\`\`

(`scp` to `~/backup-service/` and `~/.config/systemd/user/` requires those
directories to exist first — create with `ssh homeserver 'mkdir -p ~/backup-service ~/.config/systemd/user'`.)

## Verifying

\`\`\`bash
ssh homeserver 'systemctl --user list-timers backup-homeserver.timer'
ssh homeserver 'systemctl --user start backup-homeserver.service'   # trigger a run now
ssh homeserver 'journalctl --user -u backup-homeserver.service -n 20 --no-pager'
ssh homeserver 'ls -la /srv/backups/homeserver/'
\`\`\`

## Changing what gets backed up

Edit `backup.list` (one absolute path per line, `#` for comments), then
re-`scp` it to `~/backup-service/backup.list` on the server. No service
restart needed — the list is read fresh on every run.
```

- [ ] **Step 2: Commit the README**

```bash
git add scripts/backup-service/README.md
git commit -m "Add backup-service deployment README"
```

- [ ] **Step 3: Create target directories on the server**

Run: `ssh homeserver 'mkdir -p ~/backup-service ~/.config/systemd/user'`
Expected: no output, exit 0.

- [ ] **Step 4: Copy the script, property file, and unit files to the server**

Run:
```bash
scp scripts/backup-service/backup.sh scripts/backup-service/backup.list homeserver:~/backup-service/
scp scripts/backup-service/backup-homeserver.service scripts/backup-service/backup-homeserver.timer homeserver:~/.config/systemd/user/
ssh homeserver 'chmod +x ~/backup-service/backup.sh'
```
Expected: `scp` prints transfer progress for each file, no errors.

- [ ] **Step 5: Reload the user systemd instance and enable the timer**

Run:
```bash
ssh homeserver 'systemctl --user daemon-reload'
ssh homeserver 'systemctl --user enable --now backup-homeserver.timer'
ssh homeserver 'systemctl --user list-timers backup-homeserver.timer --no-pager'
```
Expected: `list-timers` shows `backup-homeserver.timer` with a `NEXT` value on the upcoming Friday at `04:00` server-local time (Asia/Yerevan).

- [ ] **Step 6: Trigger a real run and verify the archive**

Run:
```bash
ssh homeserver 'systemctl --user start backup-homeserver.service'
ssh homeserver 'journalctl --user -u backup-homeserver.service -n 20 --no-pager'
ssh homeserver 'ls -la /srv/backups/homeserver/'
```
Expected: journal shows `Created /srv/backups/homeserver/homeserver-backup_<today's date>.zip` with no `WARN`/`ERROR` lines (the only listed path, `/srv/syncthing/data`, exists); `ls` shows that archive file with a non-trivial size (hundreds of MB, matching the ~578 MiB source data, compressed).

- [ ] **Step 7: Confirm archive contents look right**

Run: `ssh homeserver 'unzip -l /srv/backups/homeserver/homeserver-backup_$(date +%F).zip | tail -20'`
Expected: listing includes entries under `srv/syncthing/data/my-brain-sync-data/`, `srv/syncthing/data/my-notes-full/`, and `srv/syncthing/data/quick-notes/`.

---

## Self-Review Notes

- **Spec coverage:** property file format (Task 1), zip archive + missing-path skip (Task 1), retention 8 + same-day overwrite (Task 2), user-level systemd + Friday 04:00 schedule (Task 3), deployment steps + real verification (Task 4), journald-only logging (no task needed — it's the absence of a feature, verified by Task 4 Step 6 showing journal output). All spec sections are covered.
- **Placeholder scan:** no TBD/TODO; every step has complete, previously-executed-and-verified code or commands.
- **Type/interface consistency:** `BACKUP_LIST`/`BACKUP_DEST`/`RETENTION_COUNT` env var names and the `homeserver-backup_<date>.zip` naming are used identically across Tasks 1, 2, and the Task 4 README/verification steps.
