#!/bin/sh

# Usage:
#   ./script.sh save <preloader|uboot|linux>
#   ./script.sh write <preloader|uboot|linux> <file>
#   ./script.sh restore <preloader|uboot|linux>

set -eu

set_target_vars()
{
    case "$1" in
        preloader)
            PARTITION=preloader
            START=0
            LENGTH=4194304
            BACKUP_FILE="backups/boot0.bin"
            ;;
        uboot)
            PARTITION=data
            START=1048576
            LENGTH=1048576
            BACKUP_FILE="backups/UBOOT.bin"
            ;;
        linux)
            PARTITION=data
            START=19922944
            LENGTH=50331648
            BACKUP_FILE="backups/boot_a.bin"
            ;;
        *)
            echo "Unknown target: $1" >&2
            exit 2
            ;;
    esac
}

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 {save|write|restore} {preloader|uboot|linux} [file]" >&2
    exit 2
fi

CMD=$1
REGION=$2

set_target_vars "$REGION"

case "$CMD" in
    save)
        mkdir -p backups
        echo "Saving $REGION to $BACKUP_FILE"
        ./stage2.py "$PARTITION" --start "$START" --length "$LENGTH" --filename "$BACKUP_FILE"
        ;;
    write)
        [ -n "${3-}" ] || { echo "write requires a filename" >&2; exit 2; }
        WRITE_FILE=$3
        # Ensure file exists
        if [ ! -f "$WRITE_FILE" ]; then
            echo "File not found: $WRITE_FILE" >&2
            exit 2
        fi
        # Check file size matches expected length
        ACTUAL_SIZE=$(stat -c%s "$WRITE_FILE")
        if [ "$ACTUAL_SIZE" -ne "$LENGTH" ]; then
            echo "File size mismatch: $WRITE_FILE is $ACTUAL_SIZE bytes but expected $LENGTH bytes." >&2
            echo "To resize the file: truncate -s $LENGTH \"$WRITE_FILE\"" >&2
            exit 2
        fi
        echo "Writing $WRITE_FILE to $REGION"
        ./stage2.py "$PARTITION" --start "$START" --length "$LENGTH" --filename "$WRITE_FILE" --write
        ;;
    restore)
        echo "Restoring $REGION from $BACKUP_FILE"
        ./stage2.py "$PARTITION" --start "$START" --length "$LENGTH" --filename "$BACKUP_FILE" --write
        ;;
    *)
        echo "Unknown command: $CMD" >&2
        echo "Usage: $0 {save|write|restore} {preloader|uboot|linux} [file]" >&2
        exit 2
        ;;
esac
