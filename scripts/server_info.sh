#!/usr/bin/env bash
# Run on the assigned server before choosing controller packages and deployment mode.
# Reads system information; makes no configuration changes and never asks for passwords.
set -uo pipefail
printf 'Current user and groups:\n'
id
printf '\nOperating system:\n'
cat /etc/os-release
printf '\nPython:\n'
if command -v python3 >/dev/null 2>&1; then
    python3 --version
else
    printf 'python3 is not installed\n'
fi
printf '\nAvailable tools:\n'
for tool in git curl terraform ansible-playbook docker; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf '%s: %s\n' "$tool" "$(command -v "$tool")"
    else
        printf '%s: not installed\n' "$tool"
    fi
done
printf '\nSudo:\n'
if (( EUID == 0 )); then
    printf 'Running as root\n'
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    printf 'Non-interactive sudo is available\n'
else
    printf 'Non-interactive sudo is unavailable; an interactive check may be needed\n'
fi
printf '\nDocker packages:\n'
if command -v dpkg-query >/dev/null 2>&1; then
    dpkg-query -W -f='${binary:Package} ${db:Status-Status} ${Version}\n' \
        docker.io docker-ce docker-ce-cli docker-compose docker-compose-v2 \
        docker-compose-plugin containerd containerd.io podman-docker 2>/dev/null || true
fi
printf '\nDocker service:\n'
if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active docker 2>&1 || true
fi
printf '\nPorts used by the homework (22, 80, 8080):\n'
if command -v ss >/dev/null 2>&1; then
    ss -lnt '( sport = :22 or sport = :80 or sport = :8080 )'
fi
printf '\nSSH public key availability:\n'
if [[ -r ${HOME}/.ssh/id_ed25519.pub ]]; then
    printf 'id_ed25519.pub exists\n'
elif [[ -r ${HOME}/.ssh/id_rsa.pub ]]; then
    printf 'id_rsa.pub exists\n'
else
    printf 'No default SSH public key found\n'
fi
