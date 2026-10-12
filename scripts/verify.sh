#!/usr/bin/env bash
set -euo pipefail
if (( $# < 1 || $# > 2 )); then
    echo "Usage: $0 <server-ip> [terraform-http-port]" >&2
    exit 2
fi
server=$1
port=${2:-8080}
for url in "http://$server:$port/" "http://$server/"; do
    printf '\nChecking %s\n' "$url"
    curl --fail --show-error --silent --max-time 15 --retry 3 -i "$url"
done
body=$(curl --fail --show-error --silent --max-time 15 "http://$server/")
[[ $body == *'Hello World'* ]] || { echo 'Missing Hello World in proxy response' >&2; exit 1; }
