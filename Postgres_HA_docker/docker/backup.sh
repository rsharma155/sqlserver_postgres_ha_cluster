#!/bin/sh
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=${BACKUP_DIR:-/backups}
WAL_DIR=${WAL_DIR:-/wal_archive}
RETENTION_DAYS=${RETENTION_DAYS:-7}
LOG_FILE=$BACKUP_DIR/backup.log
MODE="${1:-full}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

do_full() {
    log "=== Full logical backup started ==="
    FILE="$BACKUP_DIR/full_backup_$TIMESTAMP.sql"
    pg_dumpall -h haproxy -p 5000 -U postgres -f "$FILE"
    if [ $? -eq 0 ]; then
        gzip "$FILE"
        log "Full backup completed: $(basename $FILE).gz ($(du -h ${FILE}.gz | cut -f1))"
    else
        log "ERROR: Full backup FAILED"
        rm -f "$FILE"
        return 1
    fi
}

do_wal() {
    log "=== WAL archive started ==="
    if [ ! -d "$WAL_DIR" ] || [ -z "$(ls -A "$WAL_DIR" 2>/dev/null)" ]; then
        log "WAL archive: no files to archive"
        return 0
    fi
    WAL_FILE="$BACKUP_DIR/wal_$TIMESTAMP.tar.gz"
    tar czf "$WAL_FILE" -C "$WAL_DIR" .
    log "WAL archive completed: $(basename $WAL_FILE) ($(du -h $WAL_FILE | cut -f1))"
}

do_cleanup() {
    log "=== Cleanup started ==="

    # Remove full backups older than RETENTION_DAYS
    OLD_FULL=$(find "$BACKUP_DIR" -name "full_backup_*.sql.gz" -mtime +$RETENTION_DAYS)
    if [ -n "$OLD_FULL" ]; then
        echo "$OLD_FULL" | while read f; do
            rm -f "$f"
            log "Removed old full backup: $(basename $f)"
        done
    else
        log "No expired full backups to remove."
    fi

    # Remove WAL tarballs older than RETENTION_DAYS
    OLD_WAL=$(find "$BACKUP_DIR" -name "wal_*.tar.gz" -mtime +$RETENTION_DAYS)
    if [ -n "$OLD_WAL" ]; then
        echo "$OLD_WAL" | while read f; do
            rm -f "$f"
            log "Removed old WAL archive: $(basename $f)"
        done
    else
        log "No expired WAL archives to remove."
    fi

    # Clean stale WAL segments from the archive volume (keep 3 days worth)
    if [ -d "$WAL_DIR" ]; then
        CLEANED=$(find "$WAL_DIR" -type f -name "0*" -mtime +3 -delete -print 2>/dev/null | wc -l)
        CLEANED_HISTORY=$(find "$WAL_DIR" -type f -name "*.history" -mtime +3 -delete -print 2>/dev/null | wc -l)
        if [ "$CLEANED" -gt 0 ] || [ "$CLEANED_HISTORY" -gt 0 ]; then
            log "Cleaned $CLEANED WAL segments and $CLEANED history files from archive (older than 3 days)"
        fi
    fi

    # Clean backup logs older than 30 days
    OLD_LOGS=$(find "$BACKUP_DIR" -name "backup.log.*" -mtime +30 2>/dev/null)
    if [ -n "$OLD_LOGS" ]; then
        echo "$OLD_LOGS" | while read f; do rm -f "$f"; done
        log "Rotated old log files."
    fi

    log "Cleanup complete."
}

# ── Main ──────────────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"

case "$MODE" in
    full)
        do_full
        ;;
    wal)
        do_wal
        ;;
    cleanup)
        do_cleanup
        ;;
    *)
        # Legacy mode: full backup + WAL + cleanup (for direct script execution)
        do_full
        do_wal
        do_cleanup
        ;;
esac
