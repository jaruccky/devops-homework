#!/usr/bin/env bash
# Run on the Docker host as deployer after both deployments.
set -euo pipefail
cd /opt/app
docker compose ps
mapfile -t compose_ids < <(docker compose ps -q)
(( ${#compose_ids[@]} == 2 )) || { echo 'Expected two Compose containers' >&2; exit 1; }
for container_id in devops-hw1-terraform-nginx "${compose_ids[@]}"; do
    docker inspect --format '{{.Name}}: networks={{json .NetworkSettings.Networks}} mounts={{json .Mounts}} health={{.State.Health.Status}}' "$container_id"
    [[ $(docker inspect --format '{{.State.Health.Status}}' "$container_id") == healthy ]]
done
[[ $(docker inspect --format '{{len .NetworkSettings.Networks}}' devops-hw1-terraform-nginx) == 1 ]]
[[ $(docker inspect --format '{{range $name, $net := .NetworkSettings.Networks}}{{$name}}{{end}}' devops-hw1-terraform-nginx) == devops-hw1-terraform ]]
for container_id in "${compose_ids[@]}"; do
    [[ $(docker inspect --format '{{len .NetworkSettings.Networks}}' "$container_id") == 1 ]]
    [[ $(docker inspect --format '{{range $name, $net := .NetworkSettings.Networks}}{{$name}}{{end}}' "$container_id") == devops-hw1-compose ]]
done
[[ $(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/usr/share/nginx/html"}}{{.Name}}{{end}}{{end}}' devops-hw1-terraform-nginx) == devops-hw1-nginx-html ]]
echo 'PASS: services healthy, networks separated, named volume attached.'
