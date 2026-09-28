#!/bin/sh
# Summarize Nginx combined-format access logs with basic UNIX tools.
set -eu

log_file=${1:-/logs/access.log}
threshold=${2:-5}
output_dir=${3:-/reports}

if [ ! -f "$log_file" ] || [ ! -r "$log_file" ]; then
    printf 'Error: log file is missing or unreadable: %s\n' "$log_file" >&2
    exit 1
fi

case "$threshold" in
    ''|*[!0-9]*)
        printf 'Error: threshold must be a positive integer.\n' >&2
        exit 1
        ;;
esac
if [ "$threshold" -lt 1 ]; then
    printf 'Error: threshold must be at least 1.\n' >&2
    exit 1
fi

mkdir -p "$output_dir"
ip_csv="$output_dir/ip_counts.csv"
url_csv="$output_dir/url_counts.csv"
status_csv="$output_dir/status_counts.csv"
alerts_csv="$output_dir/alerts.csv"
report_txt="$output_dir/summary.txt"

# In the standard combined format, fields 1, 7, and 9 are IP, URL, and status.
awk 'NF >= 9 && $9 ~ /^[0-9][0-9][0-9]$/ {print $1}' "$log_file" |
    sort | uniq -c | sort -k1,1nr -k2,2 |
    awk 'BEGIN {print "ip,count"} {printf "%s,%s\n", $2, $1}' > "$ip_csv"

awk 'NF >= 9 && $9 ~ /^[0-9][0-9][0-9]$/ {print $7}' "$log_file" |
    sort | uniq -c | sort -k1,1nr -k2,2 |
    awk 'BEGIN {print "url,count"} {
        url=$2; gsub(/"/, "\"\"", url); printf "\"%s\",%s\n", url, $1
    }' > "$url_csv"

awk 'NF >= 9 && $9 ~ /^[0-9][0-9][0-9]$/ {print $9}' "$log_file" |
    sort | uniq -c | sort -k2,2 |
    awk 'BEGIN {print "status,count"} {printf "%s,%s\n", $2, $1}' > "$status_csv"

awk 'NF >= 9 && $9 == 401 {print $1}' "$log_file" |
    sort | uniq -c | sort -k1,1nr -k2,2 |
    awk -v limit="$threshold" 'BEGIN {print "ip,failed_logins"}
        $1 >= limit {printf "%s,%s\n", $2, $1}' > "$alerts_csv"

total_requests=$(awk 'NF >= 9 && $9 ~ /^[0-9][0-9][0-9]$/ {n++} END {print n+0}' "$log_file")
# This regex matches 4xx and 5xx status fields after the quoted request.
error_requests=$(grep -Ec '" [45][0-9]{2} ' "$log_file" || true)
alert_count=$(awk 'END {print (NR > 0 ? NR-1 : 0)}' "$alerts_csv")

{
    printf 'Nginx access log summary\n'
    printf 'Source: %s\n' "$log_file"
    printf 'Total requests: %s\n' "$total_requests"
    printf 'HTTP 4xx/5xx requests: %s\n' "$error_requests"
    printf 'Failed-login alert threshold: %s\n' "$threshold"
    printf 'Alerted IPs: %s\n\n' "$alert_count"
    printf 'Top IPs (ip,count):\n'
    awk 'NR > 1 && NR <= 6 {print "  " $0}' "$ip_csv"
    printf '\nTop URLs (url,count):\n'
    awk 'NR > 1 && NR <= 6 {print "  " $0}' "$url_csv"
    printf '\nStatus counts (status,count):\n'
    awk 'NR > 1 {print "  " $0}' "$status_csv"
    printf '\nFailed-login alerts (ip,count):\n'
    awk 'NR > 1 {print "  " $0}' "$alerts_csv"
} > "$report_txt"

cat "$report_txt"
printf '\nCSV files written to %s\n' "$output_dir"
