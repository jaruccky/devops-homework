# Запуск на сервере

Поддерживается Ubuntu 22.04+; локальный контроллер из requirements.txt требует Python 3.11+. На проверенном сервере используется Python 3.12.3. Первоначальный доступ — `student` с sudo.

```bash
git clone https://github.com/jaruccky/devops-homework.git
cd devops-homework
bash scripts/server_info.sh
bash scripts/setup_local.sh
```

`setup_local.sh` устанавливает Ansible, создаёт SSH-ключ и запускает настройку дважды с проверкой `changed=0`. Логи сохраняются в `evidence/server/`.

### Terraform

Для установки Terraform и провайдера используются зеркала Yandex Cloud.

```bash
sudo apt-get install -y unzip
curl -fL https://hashicorp-releases.yandexcloud.net/terraform/1.13.3/terraform_1.13.3_linux_amd64.zip -o /tmp/devops-terraform.zip &&
sudo unzip -o /tmp/devops-terraform.zip terraform -d /usr/local/bin

sudo install -d -o deployer -g deployer /opt/devops-hw1-terraform
sudo cp terraform/*.tf /opt/devops-hw1-terraform/
sudo chown deployer:deployer /opt/devops-hw1-terraform/*.tf
sudo install -o deployer -g deployer -m 0644 terraform/.terraform.lock.hcl /opt/devops-hw1-terraform/.terraform.lock.hcl
sudo install -o deployer -g deployer -m 0644 terraform/terraform.local.tfvars.example /opt/devops-hw1-terraform/terraform.tfvars
sudo install -o deployer -g deployer -m 0644 terraform/terraformrc.mirror.example /opt/devops-hw1-terraform/terraform.rc

tf() {
  sudo -H -u deployer env TF_CLI_CONFIG_FILE=/opt/devops-hw1-terraform/terraform.rc \
    terraform -chdir=/opt/devops-hw1-terraform "$@"
}
tf init
tf validate
tf plan -out=homework.tfplan
tf apply homework.tfplan
tf state list
tf plan -detailed-exitcode
curl --fail -i http://127.0.0.1:8080/
```

Повторный план должен вернуть код 0; код 2 означает изменения, 1 — ошибку. Запуск от student выдаст permission denied при чтении state: используйте функцию tf выше. Lock file фиксирует Docker provider 3.9.0 и checksum для linux_amd64, архитектуры проверенного сервера. Для другой платформы необходимо сформировать дополнительные checksums.

### Compose и проверки

```bash
(cd ansible && ../.venv/bin/ansible-playbook -i inventory.local.ini deploy_app.yml -K)
sudo docker compose -f /opt/app/docker-compose.yml ps
sudo -H -u deployer bash -s < scripts/verify_remote.sh
sudo /usr/local/bin/monitor.sh docker
./scripts/verify.sh 111.88.162.109
```

Playbook копирует проект в `/opt/app` и запускает Compose с ожиданием готовности контейнеров.
