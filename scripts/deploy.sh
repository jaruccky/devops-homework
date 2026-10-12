#!/usr/bin/env bash
# Usage: ./scripts/deploy.sh [-k] [-K] [other ansible-playbook options]
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
export ANSIBLE_HOME="$root/.ansible"
export PATH="$root/.venv/bin:$PATH"
for command_name in ansible-playbook terraform ssh curl; do
    command -v "$command_name" >/dev/null || { echo "Install $command_name first" >&2; exit 2; }
done
mkdir -p evidence screenshots
capture() {
    local logfile=$1
    shift
    "$@" 2>&1 | tee "$root/evidence/$logfile"
}
cd "$root/ansible"
capture ansible-first.txt ansible-playbook setup_host.yml "$@"
capture ansible-second.txt ansible-playbook setup_host.yml "$@"
# Every host in PLAY RECAP must report no changes and no failures.
if ! awk '/PLAY RECAP/{recap=1;next} recap && /ok=/{seen=1; if ($0 !~ /changed=0[[:space:]]/ || $0 !~ /failed=0[[:space:]]/ || $0 !~ /unreachable=0[[:space:]]/) bad=1} END{exit !seen || bad}' "$root/evidence/ansible-second.txt"; then
    echo 'Second Ansible run is not idempotent; see evidence/ansible-second.txt' >&2
    exit 1
fi
cd "$root/terraform"
capture terraform-init.txt terraform init -input=false
capture terraform-validate.txt terraform validate
capture terraform-plan.txt terraform plan -input=false -out=homework.tfplan
capture terraform-apply.txt terraform apply -input=false homework.tfplan
capture terraform-state.txt terraform state list
cd "$root/ansible"
capture compose-deploy.txt ansible-playbook deploy_app.yml "$@"
cd "$root"
server=${SERVER_IP:-111.88.162.109}
port=${TERRAFORM_HTTP_PORT:-8080}
remote=${SSH_TARGET:-deployer@$server}
capture monitor-remote.txt ssh "$remote" 'sudo /usr/local/bin/monitor.sh docker'
capture compose-ps.txt ssh "$remote" 'cd /opt/app && docker compose ps'
capture networks.txt ssh "$remote" 'bash -s' < scripts/verify_remote.sh
capture curl.txt ./scripts/verify.sh "$server" "$port"
# Detailed exit code 0 confirms that a subsequent plan is empty.
cd "$root/terraform"
capture terraform-second-plan.txt terraform plan -input=false -detailed-exitcode
cd "$root"
python scripts/render_evidence.py
