#!/bin/bash
set -Eeuo pipefail

MAIL_TO="root"
LOG_FILE="/var/log/nginx/access.log"

STATE_DIR="/var/tmp/web-report"
STATE_FILE="${STATE_DIR}/last_line.state"
LOCK_DIR="${STATE_DIR}/web-report.lock"

TOP_LIMIT=10

cleanup() {
    rm -rf "$LOCK_DIR"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

get_log_file() {
    local dir
    local name
    local found

    dir="$(dirname "$LOG_FILE")"
    name="$(basename "$LOG_FILE")"

    found="$(find "$dir" -maxdepth 1 -type f -name "$name" -print -quit)"

    [[ -n "$found" ]] || die "Log file not found: $LOG_FILE"

    echo "$found"
}

prepare_lock() {
    mkdir -p "$STATE_DIR"

    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        die "Another script instance is already running"
    fi

    trap cleanup EXIT INT TERM
}

read_last_line() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo 0
    fi
}

save_last_line() {
    local line="$1"

    echo "$line" > "$STATE_FILE"
}

extract_time_range() {
    local file="$1"
    local first_time
    local last_time

    first_time="$(sed -n '1s/.*\[\([^]]*\)\].*/\1/p' "$file")"
    last_time="$(sed -n '$s/.*\[\([^]]*\)\].*/\1/p' "$file")"

    echo "${first_time:-unknown} - ${last_time:-unknown}"
}

print_top_ips() {
    local file="$1"

    awk '{print $1}' "$file" \
        | sort \
        | uniq -c \
        | sort -rn \
        | head -n "$TOP_LIMIT"
}

print_top_urls() {
    local file="$1"

    awk -F '"' '
        $2 != "" {
            split($2, request, " ")
            if (request[2] != "") {
                print request[2]
            }
        }
    ' "$file" \
        | sort \
        | uniq -c \
        | sort -rn \
        | head -n "$TOP_LIMIT"
}

print_http_codes() {
    local file="$1"

    awk -F '"' '
        $3 != "" {
            split($3, fields, " ")
            status = fields[1]
            if (status ~ /^[0-9][0-9][0-9]$/) {
                print status
            }
        }
    ' "$file" \
        | sort \
        | uniq -c \
        | sort -rn
}

print_errors() {
    local file="$1"

    awk -F '"' '
        $3 != "" {
            split($3, fields, " ")
            status = fields[1]
            if (status ~ /^[45][0-9][0-9]$/) {
                print $0
            }
        }
    ' "$file"
}

build_report() {
    local chunk="$1"
    local range="$2"

    {
        echo "Web server hourly report"
        echo "========================"
        echo
        echo "Processed time range:"
        echo "$range"
        echo
        echo "Top IP addresses:"
        echo "-----------------"
        print_top_ips "$chunk"
        echo
        echo "Top requested URLs:"
        echo "-------------------"
        print_top_urls "$chunk"
        echo
        echo "HTTP response codes:"
        echo "--------------------"
        print_http_codes "$chunk"
        echo
        echo "Web server/application errors, HTTP 4xx/5xx:"
        echo "---------------------------------------------"
        print_errors "$chunk"
    }
}

send_report() {
    local report="$1"
    local range="$2"

    mail -s "Web server hourly report: $range" "$MAIL_TO" < "$report"
}

main() {
    local log_file
    local last_line
    local current_line
    local start_line
    local chunk
    local report
    local range

    prepare_lock

    log_file="$(get_log_file)"
    last_line="$(read_last_line)"
    current_line="$(wc -l < "$log_file")"

    if (( last_line > current_line )); then
        last_line=0
    fi

    if (( current_line == last_line )); then
        exit 0
    fi

    start_line=$((last_line + 1))

    chunk="$(mktemp)"
    report="$(mktemp)"

    sed -n "${start_line},${current_line}p" "$log_file" > "$chunk"

    range="$(extract_time_range "$chunk")"

    build_report "$chunk" "$range" > "$report"

    send_report "$report" "$range"

    save_last_line "$current_line"

    rm -f "$chunk" "$report"
}
