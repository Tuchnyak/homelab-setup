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
