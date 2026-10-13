#!/usr/bin/env bash
# Run as student on the assigned server; installs the controller, then configures
# the host twice with Ansible. Terraform and application deployment are later steps.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
if (( EUID == 0 )); then
    echo 'Run this script as student, without sudo; it uses sudo where needed.' >&2
    exit 2
fi
for command_name in sudo apt-get python3; do
    command -v "$command_name" >/dev/null || { echo "Missing command: $command_name" >&2; exit 2; }
done
sudo -v
sudo apt-get update
sudo apt-get install -y python3-venv ca-certificates curl openssh-client
python3 -m venv "$root/.venv"
"$root/.venv/bin/python" -m pip install -r "$root/requirements.txt"
export PATH="$root/.venv/bin:$PATH"
export ANSIBLE_HOME="$root/.ansible"
export ANSIBLE_NOCOLOR=1
run_dir="$root/evidence/server"
mkdir -p "$ANSIBLE_HOME" "$run_dir"

# This dedicated controller key stays outside Git and is reused on later runs.
key_file="${HOME}/.ssh/devops_homework"
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
if [[ ! -e $key_file && ! -e $key_file.pub ]]; then
    ssh-keygen -q -t ed25519 -N '' -C devops-homework-local-controller -f "$key_file"
fi
if [[ ! -r $key_file ]]; then
    echo "Private controller key is missing: $key_file" >&2
    exit 2
fi
if [[ ! -e $key_file.pub ]]; then
    ssh-keygen -y -f "$key_file" > "$key_file.pub"
fi
chmod 600 "$key_file"
chmod 644 "$key_file.pub"
vars_file="$ANSIBLE_HOME/local-setup-vars.json"
python - "$key_file.pub" "$vars_file" <<'PY'
import json
from pathlib import Path
import sys
Path(sys.argv[2]).write_text(json.dumps({'deployer_public_key_file': sys.argv[1]}))
PY

capture() {
    local logfile=$1
    shift
    "$@" 2>&1 | tee "$run_dir/$logfile"
}
ansible_options=(-i inventory.local.ini --extra-vars "@$vars_file")
if ! sudo -n true 2>/dev/null; then
    ansible_options+=(--ask-become-pass)
fi
cd "$root/ansible"
capture ansible-first.txt ansible-playbook setup_host.yml "${ansible_options[@]}"
capture ansible-second.txt ansible-playbook setup_host.yml "${ansible_options[@]}"
if ! awk '/PLAY RECAP/{recap=1;next} recap && /ok=/{seen=1; if ($0 !~ /changed=0[[:space:]]/ || $0 !~ /failed=0[[:space:]]/ || $0 !~ /unreachable=0[[:space:]]/) bad=1} END{exit !seen || bad}' "$run_dir/ansible-second.txt"; then
    echo 'Second Ansible run is not idempotent; send evidence/server/ansible-second.txt.' >&2
    exit 1
fi
cd "$root"
capture docker-version.txt sudo -u deployer docker version
capture compose-version.txt sudo -u deployer docker compose version
capture deployer-user.txt id deployer
sudo -u deployer sudo -n true
python scripts/render_evidence.py --input-dir "$run_dir" --output-dir "$run_dir/screenshots"
printf '\nHost setup complete: second Ansible run has changed=0.\n'
printf 'Send the final PLAY RECAP; logs are in evidence/server/ansible-first.txt and evidence/server/ansible-second.txt.\n'
