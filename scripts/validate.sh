#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
export PATH="$root/.venv/bin:$PATH"
export ANSIBLE_HOME="$root/.ansible"
(cd ansible && ansible-playbook --syntax-check setup_host.yml && ansible-playbook --syntax-check deploy_app.yml && ansible-inventory --graph)
docker compose -f compose/docker-compose.yml config --quiet
bash -n scripts/*.sh
python -m unittest discover -s tests -v
python - <<'PY'
from pathlib import Path
import hcl2
for file in sorted(Path('terraform').glob('*.tf')):
    with file.open() as source:
        hcl2.load(source)
    print(f'HCL syntax OK: {file}')
PY
git diff --check
if command -v terraform >/dev/null 2>&1; then
    terraform -chdir=terraform fmt -check
    terraform -chdir=terraform init -backend=false -input=false
    terraform -chdir=terraform validate
else
    echo 'NOT RUN: Terraform fmt/init/validate (binary not installed). HCL parsing only.'
fi
