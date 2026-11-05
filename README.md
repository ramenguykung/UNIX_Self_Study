# Docker Compose Web Log Analyzer

This small coursework project runs a Python API behind Nginx. Nginx saves access and error logs on the host. An optional, persistent Alpine container lets you run a POSIX shell script on demand to summarize the access log with `grep`, `awk`, `sort`, and `uniq`.

## Architecture

```text
Browser / curl
     |
     v
Nginx :8080 ──> Python API :8000
     |
     v
logs/access.log ──> analyzer container ──> reports/summary.txt and CSV files
logs/error.log
```

The API port is internal to Compose; only Nginx is exposed to the host. `POST /login` is a simulated failed login and has no real user accounts or passwords.

## Start and generate log data

Run these commands from this directory with Docker Desktop (or another Docker engine) running:

```powershell
docker compose up -d --build
docker compose ps
curl.exe -i http://localhost:8080/
curl.exe -i http://localhost:8080/health
curl.exe -i http://localhost:8080/missing
curl.exe -i http://localhost:8080/error
1..5 | ForEach-Object { curl.exe -s -o NUL -w "%{http_code}\n" -X POST http://localhost:8080/login }
```

Expected statuses: `/` and `/health` return `200`, an unknown path returns `404`, `/error` returns a simulated `500`, and each `POST /login` returns `401`. The five failed logins from one host meet the default alert threshold. On macOS/Linux, use `curl` in place of `curl.exe` and `/dev/null` in place of `NUL`.

To use a different host port in PowerShell, set `$env:HTTP_PORT = "8081"` before `docker compose up -d --build`.

## Logs and analysis

Nginx writes `logs/access.log` in the standard combined format and `logs/error.log` at warning level. For example:

```text
192.0.2.10 - - [28/Sep/2026:10:00:00 +0700] "POST /login HTTP/1.1" 401 35 "-" "curl/8.0"
```

The access log includes response statuses from the API. A simulated API `500` appears in the access log; Nginx's error log records Nginx or upstream errors and may remain empty during normal demo requests.

Start the persistent analyzer container, then run the script inside it. The analyzer stays running so you can repeat the analysis as logs grow:

```powershell
docker compose --profile tools up -d analyzer
docker compose --profile tools exec analyzer sh /work/analyze.sh
```

Optional arguments are the log file, failed-login threshold, and output directory, in that order:

```powershell
docker compose --profile tools exec analyzer sh /work/analyze.sh /logs/access.log 3 /reports
```

To enter the persistent analyzer container interactively, run `docker compose --profile tools exec analyzer sh`. Then run `sh /work/analyze.sh /logs/access.log 5 /reports` at its shell prompt. To run just one report without keeping an analyzer container, use `docker compose run --rm --entrypoint sh analyzer /work/analyze.sh`.

The outputs are `summary.txt`, `ip_counts.csv`, `url_counts.csv`, `status_counts.csv`, and `alerts.csv`. An empty log produces zero counts and CSV headers. A missing/unreadable log or invalid threshold produces an error and a nonzero exit code.

This uses Docker's container shell; no SSH server is needed in the container. If Docker runs on another machine, SSH into that host and run the same Compose commands there.

## UNIX tools and regular expressions

The script uses `awk` to select the IP (field 1), URL (field 7), and status (field 9) from valid combined-format lines. It uses `sort | uniq -c` to count repeated values, then sorts by frequency. `grep -E '" [45][0-9]{2} '` matches `4xx` and `5xx` statuses after the quoted request. The `awk` pattern `$9 == 401` selects simulated failed logins, and the threshold flags IPs with enough failures.

View the raw data and reports from PowerShell:

```powershell
Get-Content logs/access.log -Tail 10
Get-Content reports/summary.txt
Get-Content reports/alerts.csv
```

Stop the services with `docker compose --profile tools down`. Logs and reports remain in their host folders so they can be inspected after shutdown.
