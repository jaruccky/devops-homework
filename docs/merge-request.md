Подготавливает выданный Ubuntu-сервер для контейнерного приложения с учётом уточнения преподавателя: сначала Ansible, затем Terraform Docker. Terraform создаёт nginx на порту 8080 с отдельной сетью и именованным томом; Compose разворачивает reverse proxy на порту 80 и app с Hello World в другой сети.

Ansible устанавливает Docker/Compose, включает сервисы и создаёт deployer с ключевым доступом и sudo. Добавлены мониторинг, локальный inventory, зеркала Terraform, lock file для Docker provider 3.9.0, инструкции и сохранённые фактические результаты.

Проверки на сервере: второй Ansible changed=0/failed=0; Terraform validate успешен, apply создал 4 ресурса; все три контейнера healthy; PASS проверки сетей и тома; Docker active и 0 ошибок syslog за час. Ассистент по SSH подтвердил повторный Terraform plan: No changes, код 0. Оба публичных HTTP-порта также проверены извне: 200 OK, nginx welcome и Hello World.

Локально проходят Bash/Ansible/Compose/HCL проверки и 10 тестов мониторинга. Само-ревью — docs/self-review.md; исходные транскрипты и PNG-представления результатов — evidence/ и screenshots/. Terraform state и учётные данные не публикуются.
