#!/usr/bin/env bash
# Exit codes: 0 = active; 1 = inactive; 2 = usage/logging/system error.
set -uo pipefail

if (( $# != 1 )) || [[ ! $1 =~ ^[a-zA-Z0-9_][a-zA-Z0-9_@.:-]*$ ]]; then
    echo "Usage: $0 <service>" >&2
    exit 2
fi
service=$1
syslog_file=${MONITOR_SYSLOG_FILE:-/var/log/syslog}
for command_name in systemctl journalctl grep awk date; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing command: $command_name" >&2
        exit 2
    fi
done

result=0
if status=$(systemctl is-active -- "$service" 2>/dev/null); then
    printf 'Service %s: %s\n' "$service" "$status"
else
    result=1
    if [[ -z $status ]]; then
        echo "Cannot query systemd service status." >&2
        result=2
    fi
    printf 'Service %s: %s\n' "$service" "${status:-unavailable}"
    printf 'Last 10 journal lines for %s:\n' "$service"
    if ! journalctl --no-pager -u "$service" -n 10; then
        echo 'Cannot read service journal.' >&2
        result=2
    fi
fi

now=$(date +%s)
cutoff=$((now - 3600))
# Filter by severity first, then by time. grep exit 1 means no matching errors.
# RFC3164 local timestamps and RFC3339 timestamps with offsets are supported.
if [[ -f $syslog_file ]]; then
    if [[ ! -r $syslog_file ]]; then
        printf '%s is not readable; run with sudo.\n' "$syslog_file" >&2
        exit 2
    fi
    errors=$( { grep -Ei '(^|[^[:alnum:]_])(error|err|crit|alert|emerg|fatal|failed|failure)([^[:alnum:]_]|$)' "$syslog_file" || [[ $? == 1 ]]; } | awk -v cutoff="$cutoff" -v now="$now" '
        BEGIN {
            split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", names, " ")
            for (i=1; i<=12; i++) months[names[i]]=i
            year=strftime("%Y", now)
        }
        function offset(value, sign, hours, minutes) {
            sign=substr(value,1,1)=="-" ? -1 : 1
            hours=substr(value,2,2)+0
            minutes=substr(value,length(value)-1,2)+0
            return sign*(hours*3600+minutes*60)
        }
        {
            timestamp=-1
            if ($1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/) {
                token=$1
                calendar=substr(token,1,19)
                gsub(/[-T:]/," ",calendar)
                timestamp=mktime(calendar " -1")
                # mktime interprets wall time in the host timezone.
                local_offset=offset(strftime("%z",timestamp))
                if (token ~ /Z$/) timestamp+=local_offset
                else if (token ~ /[+-][0-9][0-9]:[0-9][0-9]$/)
                    timestamp+=local_offset-offset(substr(token,length(token)-5))
                else timestamp=-1
            } else if ($1 in months && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/) {
                clock=$3
                gsub(/:/," ",clock)
                timestamp=mktime(year " " months[$1] " " $2 " " clock " -1")
                # RFC3164 has no year; a future date may be last December.
                if (timestamp>now+86400)
                    timestamp=mktime((year-1) " " months[$1] " " $2 " " clock " -1")
            }
            if (timestamp>=cutoff && timestamp<=now) count++
        }
        END { print count+0 }
    ')
    if [[ $? != 0 ]]; then
        echo 'Cannot analyze syslog.' >&2
        exit 2
    fi
    printf 'Errors in %s during the last hour: %s\n' "$syslog_file" "$errors"
else
    # Some systems use journald without rsyslog (including a local workstation).
    journal_output=$(journalctl --no-pager --since "@$cutoff" --until "@$now" -o short-iso 2>&1)
    journal_status=$?
    if (( journal_status != 0 )) || [[ $journal_output == *'not seeing messages'* || $journal_output == *'No journal files were opened'* || $journal_output == *'No journal files were found'* ]]; then
        printf 'Cannot read system logs: %s\n' "$journal_output" >&2
        exit 2
    fi
    errors=$(printf '%s\n' "$journal_output" | { grep -Ei '(^|[^[:alnum:]_])(error|err|crit|alert|emerg|fatal|failed|failure)([^[:alnum:]_]|$)' || [[ $? == 1 ]]; } | awk 'END {print NR+0}')
    printf 'No /var/log/syslog; errors in journald during the last hour: %s\n' "$errors"
fi
exit "$result"
