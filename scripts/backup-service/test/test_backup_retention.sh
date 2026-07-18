#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SH="$SCRIPT_DIR/../backup.sh"

TESTDIR="$(mktemp -d)"
TESTDIR3="$(mktemp -d)"
trap 'rm -rf "$TESTDIR" "$TESTDIR3"' EXIT

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

# Scenario 3: fewer existing archives than RETENTION_COUNT -> no pruning occurs
mkdir -p "$TESTDIR3/src1" "$TESTDIR3/dest"
echo "hello" > "$TESTDIR3/src1/file.txt"
echo "$TESTDIR3/src1" > "$TESTDIR3/backup.list"

# Pre-seed only 2 archives, well under RETENTION_COUNT=8 default
touch "$TESTDIR3/dest/homeserver-backup_2020-01-01.zip"
touch "$TESTDIR3/dest/homeserver-backup_2020-01-02.zip"

BACKUP_LIST="$TESTDIR3/backup.list" BACKUP_DEST="$TESTDIR3/dest" "$BACKUP_SH" >/dev/null

COUNT3="$(find "$TESTDIR3/dest" -maxdepth 1 -name 'homeserver-backup_*.zip' | wc -l)"
[[ "$COUNT3" -eq 3 ]] || { echo "FAIL: expected 3 archives (2 pre-existing + today's new one, none pruned since under RETENTION_COUNT default of 8), got $COUNT3"; exit 1; }

for f in "$TESTDIR3/dest/homeserver-backup_2020-01-01.zip" "$TESTDIR3/dest/homeserver-backup_2020-01-02.zip"; do
    [[ -f "$f" ]] || { echo "FAIL: pre-existing archive $f should not have been pruned"; exit 1; }
done

echo "PASS: scenario 3 (fewer archives than RETENTION_COUNT -> nothing pruned)"
echo "PASS: test_backup_retention.sh"
