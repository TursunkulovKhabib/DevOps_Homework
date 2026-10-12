#!/usr/bin/env bash
# monitor.sh — проверка статуса systemd-сервиса и ошибок в syslog за последний час.
#
# Использование: monitor.sh <service> [syslog_file]
#   service      имя systemd-юнита, например docker (суффикс .service не обязателен)
#   syslog_file  по умолчанию /var/log/syslog
#
# Коды выхода:
#   0 — сервис активен
#   1 — сервис не активен (inactive/failed/activating…)
#   2 — неверные аргументы или нет нужных утилит
#   3 — сервис не найден
set -uo pipefail

readonly LOG_LINES=10
readonly WINDOW_SECONDS=3600

if [[ -t 1 ]]; then
  RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
else
  RED=''; GREEN=''; YELLOW=''; BOLD=''; RESET=''
fi

usage() {
  echo "Usage: $(basename "$0") <service> [syslog_file]" >&2
  echo "Example: $(basename "$0") docker" >&2
}

err()  { echo "${RED}ERROR:${RESET} $*" >&2; }
warn() { echo "${YELLOW}WARN:${RESET} $*" >&2; }

# Выполнить команду, а если не хватает прав — повторить через sudo без пароля.
run_privileged() {
  local out
  if out=$("$@" 2>&1); then
    printf '%s\n' "$out"
    return 0
  fi
  if [[ $EUID -ne 0 ]] && sudo -n true 2>/dev/null; then
    sudo -n "$@"
    return $?
  fi
  printf '%s\n' "$out"
  return 1
}

# --- аргументы ---------------------------------------------------------------
if [[ $# -lt 1 || $# -gt 2 || -z "${1:-}" ]]; then
  usage
  exit 2
fi
case "$1" in -h|--help) usage; exit 0 ;; esac

SERVICE="${1%.service}"
SYSLOG="${2:-/var/log/syslog}"

# Защита от инъекций в аргументы systemctl/journalctl
if [[ ! "$SERVICE" =~ ^[A-Za-z0-9@._:-]+$ ]]; then
  err "invalid service name: '$1'"
  exit 2
fi

for bin in systemctl journalctl grep awk date; do
  command -v "$bin" >/dev/null 2>&1 || { err "required command not found: $bin"; exit 2; }
done

echo "${BOLD}== monitor.sh: ${SERVICE} on $(hostname) at $(date '+%F %T %Z')${RESET}"

# --- 1. существует ли юнит --------------------------------------------------
# LoadState=not-found означает, что такого юнита нет.
load_state=$(systemctl show -p LoadState --value "${SERVICE}.service" 2>/dev/null)
if [[ -z "$load_state" || "$load_state" == "not-found" ]]; then
  err "service '${SERVICE}' not found (systemctl LoadState=${load_state:-unknown})"
  exit 3
fi

# --- 2. статус ---------------------------------------------------------------
status=$(systemctl is-active "${SERVICE}.service" 2>/dev/null)
rc=0
if [[ "$status" == "active" ]]; then
  echo "Status: ${GREEN}${status}${RESET}"
else
  rc=1
  echo "Status: ${RED}${status:-unknown}${RESET}"
  echo
  echo "${BOLD}-- last ${LOG_LINES} journal lines for ${SERVICE} --${RESET}"
  journal=$(run_privileged journalctl -u "${SERVICE}.service" -n "$LOG_LINES" --no-pager -q)
  if [[ -z "${journal//[[:space:]]/}" || "$journal" == *"No entries"* ]]; then
    warn "journal for '${SERVICE}' is empty"
  else
    printf '%s\n' "$journal"
  fi
fi

# --- 3. ошибки в syslog за последний час ------------------------------------
echo
echo "${BOLD}-- errors in ${SYSLOG} for the last hour --${RESET}"
if [[ ! -e "$SYSLOG" ]]; then
  warn "${SYSLOG} does not exist (rsyslog not installed?) — skipping"
  exit "$rc"
fi
if [[ ! -s "$SYSLOG" ]]; then
  echo "Errors: 0 (log is empty)"
  exit "$rc"
fi

# Поддерживаются оба формата rsyslog:
#   RFC3339:      2026-10-11T22:03:01.123456+03:00 host prog[pid]: msg  (Ubuntu 24.04)
#   традиционный: Oct 11 22:03:01 host prog[pid]: msg
# Время приводится к строке YYYYMMDDHHMMSS и сравнивается лексикографически —
# это работает в mawk (в Ubuntu по умолчанию нет gawk/mktime).
cutoff=$(date -d "@$(( $(date +%s) - WINDOW_SECONDS ))" '+%Y%m%d%H%M%S')
year=$(date +%Y)

# Строки logfmt вида `level=info ... error="..."` (containerd, dockerd) —
# информационные, хотя содержат слово error; их отбрасываем.
count_errors() {
  grep -aiE 'error|critical|fatal|fail(ed|ure)?' "$SYSLOG" |
    grep -avE 'level=(info|debug|trace|warn(ing)?)\b' |
    awk -v cutoff="$cutoff" -v year="$year" '
      BEGIN {
        split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", m, " ")
        for (i = 1; i <= 12; i++) mon[m[i]] = sprintf("%02d", i)
      }
      {
        if ($1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/) {
          ts = substr($1, 1, 19); gsub(/[-T:]/, "", ts); prog = $3
        } else if ($1 in mon) {
          t = $3; gsub(/:/, "", t)
          ts = year mon[$1] sprintf("%02d", $2) t; prog = $5
        } else next
        if (ts >= cutoff) {
          total++
          sub(/\[[0-9]+\]:?$/, "", prog); sub(/:$/, "", prog)
          by_prog[prog]++
        }
      }
      END {
        printf "Errors: %d\n", total + 0
        if (total > 0) {
          print "Top sources:"
          for (p in by_prog) printf "  %6d  %s\n", by_prog[p], p | "sort -rn | head -5"
        }
      }'
}

if [[ -r "$SYSLOG" ]]; then
  count_errors
elif [[ $EUID -ne 0 ]] && sudo -n true 2>/dev/null; then
  # Нет прав на чтение — перезапускаем только подсчёт с sudo
  sudo -n bash -c "$(declare -f count_errors); SYSLOG=\$1 cutoff=\$2 year=\$3 count_errors" \
    _ "$SYSLOG" "$cutoff" "$year"
else
  warn "no permission to read ${SYSLOG} (add user to group adm or run with sudo)"
fi

exit "$rc"
