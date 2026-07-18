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
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
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

mapfile -t old_archives < <(find "$BACKUP_DEST" -maxdepth 1 -name 'homeserver-backup_*.zip' -printf '%f\n' | sort -r | tail -n "+$((RETENTION_COUNT + 1))")
for old in "${old_archives[@]}"; do
    echo "Removing old archive: $old"
    rm -f "$BACKUP_DEST/$old"
done
