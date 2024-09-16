# Дипломная работа: Развертывание отказоустойчивой инфраструктуры с использованием Terraform и Ansible

## Описание проекта
Проект включает развёртывание отказоустойчивой инфраструктуры для веб-сайта в кластерной среде Docker-swarm с использованием Terraform и Ansible. Основные компоненты: веб-серверы, балансировщик, мониторинг Zabbix, сбор логов с помощью Elasticsearch и Kibana. Вся инфраструктура поднимается с помощью Terraform. Приложения разворачиваются с помощью Ansible.

## Содержание репозитория
### Структура каталогов
- `terraform-files/` — содержит конфигурации Terraform для развертывания инфраструктуры.
- `ansible-playbooks/` — содержит плейбуки и роли для автоматизации установки и настройки серверов.
- `README.md` — данный файл с описанием проекта.

---

## Terraform
### Описание файлов

1. **`web.tf`**:
    - Основной файл конфигурации Terraform, который содержит описание всех ресурсов для развертывания инфраструктуры, включая:
        - Веб-сервера на базе NGINX.
        - Балансировщик для распределения трафика между веб-серверами.
        - Настройки виртуальных машин (ВМ) для Zabbix, Kibana и Elasticsearch.
        - Сетевые компоненты (VPC, подсети, NAT, Security Groups).

2. **`variables.tf`**:
    - Файл переменных, используемых в конфигурации Terraform. Содержит все необходимые параметры для гибкой настройки ресурсов, такие как:
        - Размеры виртуальных машин.
        - Имена и зоны размещения.
        - Параметры балансировщика.

3. **`meta.yml`**, **`meta_bastion.yml`**, **`meta_kibana.yml`**, **`meta_zabbix.yml`**:
    - Отдельные конфигурационные файлы для настройки различных компонентов инфраструктуры, таких как бастион-сервер, Kibana, Zabbix. Эти файлы содержат метаданные, необходимые для корректной работы сервисов.

### Подготовка

Для разворота инфраструктуры необходим контейнер docker с установленными:
1. Terraform. В `variables.tf` нужно подставить свой `cloud_id` и `folder_id`
2. Ansible вместе с плагином `community.docker`.
3. RSA ключами
4. Настроенными переменными окружения для Yandex Cloud.

### Пример запуска
1. Перейдите в каталог `terraform-files/web-tf`.
2. Инициализизация Terraform:
    ```bash
    terraform init
    ```
3. Проверка плана создания инфраструктуры:
    ```bash
    terraform plan
    ```
4. Применение конфигурации:
    ```bash
    terraform apply
    ```

5. После успешного деплоя инфраструктуры, нужно привязать таблицу маршрутизации `web-routing-table` к внутренним сегментам сети.

6. На всех хостах с публичным IP в `/etc/netplan/50-cloud-init.yaml` необходимо отключить обновление маршрутов по DHCP для интерфейса `eth0`:

    ```bash
    eth0:
                dhcp4: true
                dhcp4-overrides:
                    route-metric: 100
                    use-routes: false  # Отключаем обновление маршрутов через DHCP
    ```

7. Можно создать файл, который явно будет запрещать обновление маршрутов по DHCP:

    ```
    $ cat /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    network: {config: disabled}
    ```
    
7. Перед запуском `ansible-playbook`, нужно записать публичный ключ к бастиону. Подключившись к нему, нужно записать публичный ключ каждого хоста схемы в `known_hosts` bastion-хоста для юзера `user`.

8. Если доменное имя бастиона приватное, то внутри контейнера в файле `/etc/hosts` прописать IP и домен бастион-хоста.

---

## Ansible
### Описание файлов

1. **`inventory.ini`**:
    - Файл инвентаря, который содержит описание всех серверов, используемых в инфраструктуре. 
    - Серверы сгруппированы по ролям: веб-серверы, мониторинг, сбор логов и т.д.
    - Пример структуры:
      ```ini
        [docker_swarm_manager]
        web1.internal-cloud 

        [docker_swarm_workers]
        web2.internal-cloud 
        web3.internal-cloud 

        [bastion]
        bastion.internal-cloud 

        [monitoring]
        zabbix.internal-cloud 

        [elk]
        elastic.internal-cloud
        kibana.internal-cloud
      ```

2. **Роли и шаблоны**:
    - **`roles/`** — содержит роли для автоматизации установки и настройки сервисов:
        - **`docker`** — настройка и установка docker на хостах.
        - **`ELK`** — установка и настройка Elasticsearch, Kibana и Filebeat для сбора, анализа и отправки логов.
        - **`nginx_swarm`** — настройка и установка NGINX на веб-серверах в кластерной среде Docker-swarm.
        - **`zabbix`** — установка Zabbix Server в docker-контейнере и агентов на все сервера.
    - **`templates/`** — содержит шаблоны конфигурационных файлов для сервисов (например, конфигурационные файлы для Zabbix, Docker).

### Пример запуска
1. Подготовка инфраструктуры с помощью Terraform.
2. Запуск Ansible playbook для установки Docker на нужных хостах.
    ```bash
    ansible-playbook -i inventory.ini roles/docker/install_docker.yml -v
    ```
3. Установка nginx в Docker-swarm на веб-хостах:
    ```bash
    ansible-playbook -i inventory.ini roles/nginx_swarm/deploy-nginx-swarm.yaml
    ```
4. Настройка мониторинга с помощью Zabbix:
    ```bash
    ansible-playbook -i inventory.ini roles/zabbix-deploy.yaml
    ansible-playbook -i inventory.ini roles/zabbix-agent-deploy.yaml
    ```
5. Настройка сбора логов с помощью Elasticsearch и Kibana:
    ```bash
    ansible-playbook -i inventory.ini roles/ELK/elasticsearch.yml
    ansible-playbook -i inventory.ini roles/ELK/filebeat.yml
    ansible-playbook -i inventory.ini roles/ELK/kibana.yml
    ```
---

### Нюансы установки приложений

1. Для деплоя Zabbix, сначала нужно использовать плей `zabbix-deploy.yaml`, затем `zabbix-agent-deploy.yaml`.

2. После успешного деплоя Zabbix, веб будет доступен через несколько минут. Ошибка DB пропадет со временем. На хостах проверить запуск `zabbix-agent2`. Далее на вебе Zabbix настроить все хосты схемы. Дефолтный пароль: `zabbix` для юзера `Admin` следует поменять в целях безопасности.

3. После деплоя Elastic / Kibana / Filebeat, для генерации пароля выполняем на ноде с `elastic`:

    ```bash
    docker exec -it <container id> /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
    ```

Будет выдан пароль для супер-юзера `elastic`.

4. Для генерации `SERVICE_TOKEN`, который нужен для авторизации Kibana к Elasticsearch, нужно использовать скрипт `/usr/share/elasticsearch/bin/elasticsearch-service-tokens`

    ```bash
    root@elastic:/home/user# docker exec -it 21ca99098351 /usr/share/elasticsearch/bin/elasticsearch-service-tokens create elastic/kibana kibana-token
    SERVICE_TOKEN elastic/kibana/kibana-token = <your secret token here>
    ```
Данный токен нужно использовать на хосте `kibana.internal-cloud` в конфиг-файле `/opt/kibana/config/kibana.yml`, параметр `elasticsearch.serviceAccountToken: ""`

После его добавления, необходимо перезапустить контейнер: `docker restart kibana`.

5. Login и password для сервисного юзера Filebeat необходимо подставить в `/opt/filebeat/config/filebeat.yml` и перезапустить контейнер. Не рекомендуется использовать параметры авторизации для elastic-суперюзера.

---

## Компоненты инфраструктуры

### Веб-сайт
- Три ВМ с установленным NGINX внутри кластера Docker-swarm.
- ВМ находятся в разных зонах отказа для обеспечения высокой доступности.
- Балансировка нагрузки с использованием Yandex Application Load Balancer.

### Мониторинг
- Используется Zabbix для мониторинга серверов (CPU, RAM, диск, сеть).
- Установлены агенты на всех серверах, данные отправляются на Zabbix Server.

### Логи
- Логи NGINX отправляются на Elasticsearch с помощью Filebeat.
- Данные визуализируются с помощью Kibana, которая позволяет просматривать и анализировать логи.

### Сеть
- Виртуальная сеть (VPC) с приватными и публичными подсетями.
- Публичные сервера (Zabbix, Kibana) находятся в публичной подсети.
- Приватные сервера (NGINX, Elasticsearch) находятся в приватной подсети.
- Используется бастион-сервер для доступа к приватным серверам.

---

## Критерии сдачи
- Инфраструктура развёрнута и соответствует требованиям.
- Предоставлен доступ ко всем веб-ресурсам: веб-сайт, Zabbix, Kibana.
- Приложены скриншоты подтверждения работы ресурсов.

---

## Упрощенная схема

![Упрощенная схема](HA-web.drawio.svg)

- Zabbix, bastion и elastic будут иметь публичные IP после деплоя инфраструктуры. На схеме они не отображены.

---

## Доступы

1. Zabbix доступен по **http://51.250.2.236**
2. Elastic доступен по **http://51.250.81.224:5601**. В Discover доступны nginx логи с трех [хостов](http://screenshot.alarislabs.com/ib2024/image_20240915211720_a5bb70ce.png)
3. Веб-сайт доступен по **http://51.250.38.224**. Там же можно проверить работу балансировщика, обновляя страницу с помощью `F5` или `CTRL+F5` (для актуализации кеша). Сайт возвращает приватный IP хоста, на который пришел запрос.

Пример работы:

```
curl -s http://51.250.38.224/ | grep 'ip-box' | awk -F '[><]' '{print $3}'
10.11.0.10
curl -s http://51.250.38.224/ | grep 'ip-box' | awk -F '[><]' '{print $3}'
10.12.0.10
curl -s http://51.250.38.224/ | grep 'ip-box' | awk -F '[><]' '{print $3}'
10.10.0.10
```

