# План по установке и настройке домашнего сервера на Ubuntu Server

**Версия:** 2.1 (исправленная, полная, готовая к выполнению)  
**Дата:** Ноябрь 2025

Это **максимально подробное пошаговое руководство** по созданию многоцелевого домашнего сервера с нуля. Мы будем использовать Ubuntu Server, Podman (контейнеризация) и systemd quadlets, чтобы построить безопасную, легко управляемую и мощную систему.

---

## Оглавление

- [Глава 0: Подготовка](#глава-0-подготовка)
- [Глава 1: Установка и базовая настройка системы](#глава-1-установка-и-базовая-настройка-системы)
- [Глава 2: Безопасность и удаленный доступ](#глава-2-безопасность-и-удаленный-доступ)
- [Глава 3: Фундамент для сервисов](#глава-3-фундамент-для-сервисов)
- [Глава 4: Сетевая инфраструктура и файловый доступ](#глава-4-сетевая-инфраструктура-и-файловый-доступ)
- [Глава 5: Развертывание основных сервисов](#глава-5-развертывание-основных-сервисов)
- [Глава 6: Стратегия резервного копирования](#глава-6-стратегия-резервного-копирования)
- [Глава 7: Развертывание собственных приложений с помощью Kamal](#глава-7-развертывание-собственных-приложений)
- [Глава 8: Дополнительные сервисы и расширения](#глава-8-дополнительные-сервисы-и-расширения)
- [Приложения](#приложения)

---

## Глава 0: Подготовка

### 0.1. Что мы будем строить?

Многоцелевой домашний сервер для:
- **Личного облака** (Nextcloud) - замена Google Drive/Dropbox
- **Медиасервера** (Jellyfin) - домашний Netflix для вашей коллекции
- **Torrent-клиента** (qBittorrent) с веб-интерфейсом
- **Синхронизации файлов** (Syncthing) между устройствами
- **Прокси и SSL** (Nginx Proxy Manager) для красивых HTTPS адресов
- **DNS фильтрации** (AdGuard Home) - блокировка рекламы для всей сети
- **Разработки и деплоя** своих приложений (Kamal)
- **Локальных LLM моделей** (Ollama + Open WebUI)

### 0.2. Что нужно знать заранее

Базовые знания:
- Умение работать с командной строкой Linux (cd, ls, mkdir и т.д.)
- Понимание что такое IP-адреса и порты
- Базовые навыки редактирования текстовых файлов

Не обязательно быть экспертом! Всё объясним подробно.

### 0.3. Необходимое оборудование

**Минимальные требования:**
- **CPU:** 4 ядра (например, AMD Ryzen 5 3500U)
- **RAM:** 8 ГБ (рекомендуется 16 ГБ)
- **Хранение:** SSD/NVMe от 256 ГБ (оптимально 1 ТБ)
- **Сеть:** Ethernet-порт (Wi-Fi тоже работает, но медленнее)

**Пример конфигурации из руководства:**
- CPU: AMD Ryzen 5 3500U (4 cores)
- RAM: 16 GB DDR4
- Storage: 1 TB PCIe3 NVMe SSD

**Дополнительно:**
- USB флешка (минимум 4 ГБ) для установки
- Монитор и клавиатура (нужны только для установки)
- Ethernet кабель (рекомендуется)
- Внешний жёсткий диск 500 ГБ-1 ТБ (для резервных копий, подключим позже)

### 0.4. Скачивание Ubuntu Server

**Шаг 1:** Перейдите на официальный сайт Ubuntu и скачайте последний LTS релиз (Long-Term Support):
- Адрес: https://ubuntu.com/download/server
- Выбирайте LTS версию (например, 24.04 LTS)

**Шаг 2:** Проверьте целостность файла через SHA256

На Ubuntu SHA256SUMS будет доступен рядом с образом.

**Команды для проверки:**

Linux/macOS:
```bash
shasum -a 256 ubuntu-24.04.1-live-server-amd64.iso
```

Windows (PowerShell):
```powershell
CertUtil -hashfile ubuntu-24.04.1-live-server-amd64.iso SHA256
```

**Шаг 3:** Сравните полученный хэш с официальным из файла SHA256SUMS

### 0.5. Создание загрузочного USB

Вам понадобится USB флешка минимум 4 ГБ (все данные с неё будут удалены).

**Рекомендуемая программа:** BalenaEtcher (работает на Windows/macOS/Linux)

Скачайте с https://www.balena.io/etcher/

**Процесс:**
1. Откройте BalenaEtcher
2. Нажмите "Flash from file" и выберите скачанный .iso образ Ubuntu Server
3. Вставьте USB-флешку и выберите её в BalenaEtcher
4. Нажмите "Flash!" и дождитесь завершения

### 0.6. Подготовка сервера к установке

**Чек-лист перед установкой:**

☐ Скачан Ubuntu Server 24.04 LTS ISO  
☐ Проверена целостность образа (SHA256)  
☐ Создан загрузочный USB  
☐ Подготовлен компьютер для сервера  
☐ Подключен монитор и клавиатура  
☐ Подключен Ethernet кабель (или настроен Wi-Fi)  
☐ Найден IP адрес роутера (обычно 192.168.1.1 или 192.168.0.1)

**Как узнать IP адрес роутера:**

На любом компьютере в сети (Windows/macOS/Linux):
```bash
# Linux/macOS
ip route | grep default
# или
netstat -rn | grep default

# Вывод будет примерно: default via 192.168.1.1 dev eth0
# 192.168.1.1 — это IP роутера
```

Windows (cmd или PowerShell):
```powershell
ipconfig
# Ищи "Default Gateway" — это IP роутера
```

Альтернативно: посмотри на наклейку на роутере (обычно там указан адрес).

### 0.7. Что мы планируем в итоге получить

**Архитектура:**
- Btrfs файловая система с автоматическими снапшотами
- Все данные сервисов в `/srv` для лёгкого бэкапа
- Wi-Fi или Ethernet со статическим IP
- SSH доступ только по ключам (без паролей)
- UFW firewall для защиты
- fail2ban для защиты от брутфорса
- Podman контейнеры вместо Docker (rootless, безопаснее)
- systemd quadlets для автозапуска контейнеров
- Nginx Proxy Manager для красивых .internal доменов с HTTPS

---

## Глава 1: Установка и базовая настройка системы

### 1.1. Загрузка с USB и начало установки

**Шаг 1:** Вставьте USB флешку в сервер

**Шаг 2:** Включите компьютер и войдите в BIOS/UEFI
- Обычно нужно нажать F2, F12, Delete или Esc при загрузке
- Зависит от производителя материнской платы

**Шаг 3:** Измените порядок загрузки (Boot Order)
- Поставьте USB флешку на первое место
- Сохраните и выйдите (обычно F10)

**Шаг 4:** Компьютер загрузится с USB и покажет меню установки Ubuntu Server

### 1.2. Процесс установки Ubuntu Server с Btrfs

Теперь начинается пошаговый процесс установки. Внимательно следуйте инструкциям.

#### Выбор языка
- **Выбор:** English
- Используйте стрелки для навигации, Enter для подтверждения

#### Обновление установщика
- **Выбор:** Continue without updating (можно обновить после установки)

#### Раскладка клавиатуры
- **Выбор:** English (US)
- Или ваша предпочитаемая раскладка

#### Тип установки
- **Выбор:** Ubuntu Server (minimized)
- Это минимальная версия без лишних пакетов

#### Сетевая конфигурация

**Если Ethernet подключен:**
- DHCP обычно работает автоматически
- Вы увидите назначенный IP адрес
- Можно оставить как есть (настроим статический IP позже)

**Если используется Wi-Fi:**
1. Выберите Wi-Fi сеть из списка
2. Введите пароль от Wi-Fi
3. Дождитесь подключения

**Примечание:** Если Wi-Fi не отображается, убедитесь что адаптер поддерживается ядром Linux.

#### Proxy
- **Выбор:** Leave blank (оставьте пустым)

#### Mirror
- **Выбор:** Ubuntu Default is fine (оставьте по умолчанию)

#### Разметка диска (важно!)

Здесь мы настроим Btrfs вместо стандартного ext4.

**Шаг 1:** Выберите **Custom storage layout**

**Шаг 2:** Вы увидите ваш SSD/NVMe диск (обычно `/dev/nvme0n1` или `/dev/sda`)

**Шаг 3:** Создайте таблицу разделов GPT (если диск новый)

**Разметка:**

**1. Boot раздел (обязательно):**
- Нажмите "Add GPT Partition"
- **Size:** 1GB
- **Format:** ext4
- **Mount point:** `/boot`

**2. Root раздел (Btrfs):**
- Выберите оставшееся место
- **Size:** Оставьте остальное место (или укажите конкретно, например 100GB для системы)
- **Format:** btrfs
- **Mount point:** `/`

**Примечание:** Можно создать отдельный subvolume для `/home`, но для сервера это не критично. Root раздел будет содержать всё: систему, `/home/tuchnyak` и всё остальное.

**Шаг 4:** Проверьте разметку и нажмите Done

#### Профиль пользователя

Создайте основного пользователя (НЕ root):

- **Your name:** Ваше имя (например, "George")
- **Your server's name:** Имя сервера (например, "homeserver")
  - Это имя будет видно в сети
- **Pick a username:** Ваш логин (например, "tuchnyak")
  - НЕ используйте "root" или "admin"
- **Choose a password:** Придумайте сильный пароль
  - Минимум 12 символов, комбинация букв, цифр и спецсимволов

#### SSH Setup

**ВАЖНО:** Отметьте галочкой:
☑ **Install OpenSSH server**

Это критически важно для удалённого доступа.

**Import SSH identity:** Можно пропустить (настроим позже)

#### Featured Server Snaps

Пропустите все Snap пакеты. Мы установим нужное позже через apt.

#### Завершение установки

1. Дождитесь завершения установки (5-10 минут)
2. Извлеките USB-флешку когда появится запрос
3. Нажмите Enter для перезагрузки

### 1.3. Первая загрузка и вход в систему

После перезагрузки вы увидите приглашение для входа:

```
Ubuntu 24.04 LTS homeserver tty1

homeserver login: _
```

**Вход:**
1. Введите ваш username (например, `tuchnyak`)
2. Нажмите Enter
3. Введите пароль
4. Нажмите Enter

Вы должны увидеть приглашение командной строки:

```bash
tuchnyak@homeserver:~$
```

Поздравляю! Система установлена.

### 1.4. Настройка сети (Ethernet или Wi-Fi со статическим IP)

Сейчас у вас, скорее всего, динамический IP от DHCP. Для сервера лучше настроить статический IP.

#### Проверка текущего подключения

**На сервере:**
```bash
ip a
```

Вы увидите список сетевых интерфейсов. Найдите активный (со статусом UP):
- Ethernet обычно называется `eth0`, `enp1s0` или похоже
- Wi-Fi обычно называется `wlan0`, `wlp1s0`, `wlo1` или похоже

В нашем примере используется `wlo1` (Wi-Fi).

#### Узнать IP адрес роутера

**На сервере:**
```bash
ip route | grep default
```

Вывод будет примерно:
```
default via 192.168.1.1 dev wlo1
```

Здесь `192.168.1.1` — IP адрес роутера (шлюза).

#### Выбор свободного IP адреса

**Важно:** Выберите IP адрес, который НЕ используется другими устройствами в сети.

**Как проверить:**

1. Посмотрите на роутер — обычно его адрес `192.168.1.1` или `192.168.0.1`
2. Выберите адрес из того же диапазона, например `192.168.1.100`
3. Проверьте что адрес свободен:

**С другого компьютера в сети (Windows/macOS/Linux):**
```bash
ping -c 3 192.168.1.100
```

Если получаете "Destination Host Unreachable" или "Request timed out" — адрес свободен, отлично!

Если ping проходит — выберите другой адрес (например, .101, .102 и т.д.)

**Linux/macOS альтернатива (использует ARP):**
```bash
sudo arping -c 3 -I eth0 192.168.1.100
```

Если "0 packets received" — адрес свободен.

#### Настройка статического IP через Netplan

Ubuntu использует Netplan для настройки сети.

**Шаг 1:** На сервере создайте резервную копию конфигурации
```bash
sudo cp /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bak
```

**Шаг 2:** На сервере отредактируйте конфигурацию Netplan
```bash
sudo vim /etc/netplan/00-installer-config.yaml
```

**Важно:** В YAML форматирование критично! Используйте пробелы (не Tab).

**Пример конфигурации для Wi-Fi со статическим IP:**

```yaml
# This is the network config written by 'subiquity'
network:
  version: 2
  renderer: networkd
  wifis:
    wlo1:  # Имя вашего Wi-Fi интерфейса, замените на ваше (см. ip a)
      dhcp4: no
      access-points:
        "YOUR_WIFI_SSID":  # Замените на имя вашей Wi-Fi сети (SSID)
          password: "YOUR_WIFI_PASSWORD"  # Замените на пароль Wi-Fi
      addresses:
        - 192.168.1.100/24  # Ваш статический IP адрес /24 = маска 255.255.255.0
      routes:
        - to: default
          via: 192.168.1.1  # IP адрес вашего роутера (шлюз)
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8]  # DNS серверы (роутер + Google DNS)
```

**Объяснение параметров:**
- `192.168.1.100/24` — ваш статический IP адрес, `/24` означает маску подсети `255.255.255.0`
  - Это позволяет адресам от `192.168.1.0` до `192.168.1.255` быть в одной сети
- `192.168.1.1` — IP адрес роутера (шлюз по умолчанию)
- `[192.168.1.1, 8.8.8.8]` — DNS серверы (сначала пробуем роутер, потом Google)

**Для Ethernet конфигурация похожа, но секция будет `ethernets:` вместо `wifis:`:**

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:  # Ваш Ethernet интерфейс
      dhcp4: no
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8]
```

**Шаг 3:** На сервере примените конфигурацию Netplan

Сначала тестируем (автоматически откатится через 120 сек если что-то не так):
```bash
sudo netplan try
```

Если всё работает, нажмите Enter для подтверждения.

Если НЕ работает или вы потеряли SSH соединение — подождите 120 секунд, система автоматически откатит изменения.

Применить окончательно:
```bash
sudo netplan apply
```

**Шаг 4:** Проверка

На сервере:
```bash
ip a
```

Вы должны увидеть ваш статический IP (например, `192.168.1.100`) на интерфейсе Wi-Fi (`wlo1`) или Ethernet.

Проверка интернета на сервере:
```bash
ping google.com -c 4
```

Если пакеты проходят (0% packet loss) — отлично, всё работает!

### 1.5. Подключение по SSH с другого компьютера

Теперь можно отключить монитор и клавиатуру от сервера и работать удалённо через SSH.

**С вашего основного компьютера (Windows/macOS/Linux):**

```bash
ssh tuchnyak@192.168.1.100
```

Замените:
- `tuchnyak` на ваш username
- `192.168.1.100` на IP адрес вашего сервера

При первом подключении появится вопрос о добавлении ключа (fingerprint):
```
Are you sure you want to continue connecting (yes/no)?
```

Введите `yes` и нажмите Enter.

Введите пароль вашего пользователя.

Вы должны увидеть приглашение командной строки:
```
tuchnyak@homeserver:~$
```

Поздравляю! Вы подключены по SSH.

### 1.6. Обновление системы

Первым делом обновите все пакеты:

**На сервере:**
```bash
sudo apt update
sudo apt upgrade -y
```

Это может занять несколько минут.

**Рекомендация:** Обновляйте систему примерно раз в 2 недели вручную:
```bash
sudo apt update
sudo apt list --upgradable  # Посмотреть что обновляется
sudo apt upgrade -y
```

Ручное обновление безопаснее, чем автоматическое — вы видите что меняется и можете откатить через Btrfs снапшот если что-то сломается.

### 1.7. Установка базовых утилит

**На сервере:**
```bash
sudo apt install -y vim git curl wget htop net-tools tree
```

**Что установили:**
- `vim` — текстовый редактор (альтернатива nano)
- `git` — система контроля версий
- `curl`, `wget` — утилиты для скачивания файлов
- `htop` — интерактивный монитор процессов
- `net-tools` — классические сетевые утилиты (ifconfig, netstat)
- `tree` — отображение дерева каталогов

### 1.8. Настройка Btrfs снапшотов через Snapper

Btrfs поддерживает снапшоты — моментальные снимки файловой системы. Это позволяет откатить систему если что-то пойдёт не так.

Мы используем `snapper` для автоматического создания снапшотов.

**Шаг 1:** На сервере установите Snapper и интеграцию с apt
```bash
sudo apt install -y snapper apt-btrfs-snapshot
```

**Шаг 2:** На сервере создайте конфигурацию Snapper для root раздела
```bash
sudo snapper -c root create-config /
```

Эта команда создаст конфигурацию в `/etc/snapper/configs/root`

**Шаг 3:** На сервере отредактируйте конфигурацию snapper

```bash
sudo vim /etc/snapper/configs/root
```

**Важные параметры для изменения:**

Найдите параметр `SUBVOLUME` и убедитесь что он указывает на `/`:
```
SUBVOLUME="/"
```

Найдите `TIMELINE_CREATE` и установите `yes` для автоматического создания снапшотов:
```
TIMELINE_CREATE="yes"
```

Измените с `TIMELINE_CREATE="no"` на `TIMELINE_CREATE="yes"` если стоит `no`.

Также можно настроить очистку старых снапшотов (чтобы диск не забился):
```
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
```

Это значит: храним 5 часовых и 7 дневных снапшотов.

**Шаг 4:** На сервере запустите таймеры snapper

```bash
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
```

- `snapper-timeline.timer` — создаёт снапшоты по расписанию
- `snapper-cleanup.timer` — очищает старые снапшоты

**Шаг 5:** На сервере проверьте снапшоты

```bash
sudo snapper list-configs
```

Должен показать конфигурацию `root` с субволюмом `/`.

```bash
sudo snapper -c root list
```

Показывает список снапшотов. Сейчас должен быть хотя бы 1-2 снапшота (созданные при установке или apt).

**Просмотр размера снапшотов:**
```bash
sudo btrfs filesystem usage /
```

Это покажет сколько места занимают снапшоты.

**Автоматические снапшоты при обновлениях:**

Благодаря пакету `apt-btrfs-snapshot`, каждый раз когда вы делаете `apt upgrade`, автоматически создаётся снапшот.

**Восстановление из снапшота (если что-то сломалось):**
```bash
sudo snapper -c root list
sudo snapper -c root rollback <номер_снапшота>
sudo reboot
```

### 1.9. Настройка Swap (опционально, но рекомендуется)

У вас 16 ГБ RAM, но некоторые сервисы (Nextcloud, Jellyfin, LLM модели) могут потреблять много памяти. Swap защищает от OOM Killer (Out Of Memory Killer), который убивает процессы при нехватке RAM.

**Опция 1: Swap файл (традиционный способ)**

На сервере создадим 8 ГБ swap файл на NVMe SSD:

```bash
# Создание 8 ГБ swap файла
sudo fallocate -l 8G /swapfile

# Установка прав доступа (только root)
sudo chmod 600 /swapfile

# Форматирование как swap
sudo mkswap /swapfile

# Включение swap
sudo swapon /swapfile
```

Проверка:
```bash
sudo swapon --show
free -h
```

Вы должны увидеть swap размером 8 ГБ.

Добавление в fstab для автозагрузки:
```bash
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
```

**Опция 2: ZRAM (сжатый swap в RAM)**

ZRAM — это виртуальный диск в оперативной памяти со сжатием. Быстрее чем swap на диске, но использует часть RAM.

Преимущество: меньше износ SSD, быстрее работает.

На сервере:
```bash
sudo apt install -y zram-tools
```

Настройка ZRAM:
```bash
sudo vim /etc/default/zramswap
```

Установите:
```
ALGO=zstd
PERCENT=25
```

Это создаст ZRAM размером 25% от RAM (4 ГБ из 16 ГБ).

Перезагрузите ZRAM или систему:
```bash
sudo systemctl restart zramswap.service
```

**Рекомендация:** Можно использовать оба метода вместе: ZRAM для быстрого swap, и swap файл как резервный.

### 1.10. Чек-лист Главы 1

☐ Ubuntu Server 24.04 LTS установлен  
☐ Btrfs файловая система настроена  
☐ Сеть работает (Ethernet или Wi-Fi)  
☐ Статический IP адрес назначен  
☐ SSH подключение работает  
☐ Система обновлена (apt update && apt upgrade)  
☐ Базовые утилиты установлены  
☐ Snapper настроен для автоматических снапшотов  
☐ Swap или ZRAM настроен

---

## Глава 2: Безопасность и удаленный доступ

Безопасность — критически важна для домашнего сервера. В этой главе мы настроим:
- SSH доступ только по ключам (без паролей)
- UFW firewall для фильтрации трафика
- fail2ban для защиты от брутфорс атак

В приложениях есть описание настройки 2FA.

### 2.1. SSH с публичными ключами (без паролей)

Пароли можно подобрать брутфорсом. Ключи — нельзя (при достаточной длине).

#### 2.1.1. Генерация SSH ключей на вашем локальном компьютере

**На вашем основном компьютере** (не на сервере):

Современный способ (рекомендуется):
```bash
ssh-keygen -t ed25519 -f ~/.ssh/homeserver_key -C "tuchnyak@homeserver"
```

Или традиционный способ (максимальная совместимость):
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/homeserver_key -C "tuchnyak@homeserver"
```

**Процесс:**
1. Нажмите Enter для сохранения (или подтвердите путь `~/.ssh/homeserver_key`)
2. Введите passphrase (опционально, но рекомендуется для дополнительной защиты)
3. Подтвердите passphrase

Будут созданы два файла:
- `~/.ssh/homeserver_key` — приватный ключ (НИКОМУ не показывайте!)
- `~/.ssh/homeserver_key.pub` — публичный ключ (его можно передавать)

**Почему ED25519 лучше RSA:**
- ED25519 — компактнее (256 бит вместо 4096)
- Быстрее вычисляется
- Совместим со всеми современными системами
- Более безопасен математически

#### 2.1.2. Копирование публичного ключа на сервер

**На локальном компьютере:**
```bash
ssh-copy-id -i ~/.ssh/homeserver_key tuchnyak@192.168.1.100
```

Введите пароль вашего пользователя на сервере (последний раз!).

Команда скопирует ваш публичный ключ в `~/.ssh/authorized_keys` на сервере.

**Если ssh-copy-id не работает (например, на Windows):**
```bash
cat ~/.ssh/homeserver_key.pub | ssh tuchnyak@192.168.1.100 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

#### 2.1.3. Проверка входа по ключу

**На локальном компьютере попробуйте подключиться:**
```bash
ssh -i ~/.ssh/homeserver_key tuchnyak@192.168.1.100
```

Теперь вход должен происходить БЕЗ запроса пароля (или с запросом passphrase для ключа, если вы его установили).

Если работает — отлично!

#### 2.1.4. Удобство: Добавление конфига SSH

**На локальном компьютере создайте конфиг для удобства:**

```bash
cat >> ~/.ssh/config << EOF
Host homeserver
    HostName 192.168.1.100
    User tuchnyak
    IdentityFile ~/.ssh/homeserver_key
    Port 22
EOF
```

Теперь можно просто:
```bash
ssh homeserver
```

#### 2.1.5. Отключение входа по паролю на сервере

**Важно:** Делайте это ТОЛЬКО после того как убедились что вход по ключу работает!

**На сервере** отредактируйте SSH конфигурацию:
```bash
sudo vim /etc/ssh/sshd_config
```

Найдите и измените следующие строки (используйте `/` для поиска в vim):

```
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
```

Если строки закомментированы (начинаются с `#`), раскомментируйте их.

Сохраните и выйдите (`:wq` в vim).

Перезагрузите SSH сервис:
```bash
sudo systemctl restart sshd
```

**Важно:** НЕ закрывайте текущую SSH сессию! Откройте новый терминал и проверьте что SSH подключение работает. Только после этого закрывайте старую сессию.

Если что-то пошло не так и вы потеряли доступ — подключите монитор и клавиатуру, войдите локально и откатите изменения.

### 2.2. Настройка UFW (Uncomplicated Firewall)

UFW — простой и мощный firewall для Ubuntu.

#### 2.2.1. Установка и базовые правила

**На сервере** установите политики по умолчанию (запретить входящие, разрешить исходящие):
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

#### 2.2.2. Создание резервных копий конфигурации

```bash
sudo cp /etc/ufw/before.rules /etc/ufw/before.rules.bak
sudo cp /etc/ufw/after.rules /etc/ufw/after.rules.bak
sudo cp /etc/default/ufw /etc/default/ufw.bak
```

#### 2.2.3. Разрешение необходимых сервисов

Мы должны разрешить SSH, HTTP и HTTPS, иначе не сможем подключиться.

**На сервере:**
```bash
# SSH (порт 22, или ваш кастомный порт)
sudo ufw allow ssh

# HTTP (порт 80)
sudo ufw allow http

# HTTPS (порт 443)
sudo ufw allow https
```

#### 2.2.4. Включение UFW

**На сервере:**
```bash
sudo ufw enable
```

Появится предупреждение о возможном разрыве SSH соединения. Если вы разрешили SSH выше — всё нормально, нажмите `y` и Enter.

#### 2.2.5. Проверка статуса

**На сервере:**
```bash
sudo ufw status verbose
```

Вы должны увидеть список правил:
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
```

### 2.3. Установка и настройка fail2ban

fail2ban мониторит логи и банит IP адреса, которые делают слишком много неудачных попыток входа.

#### 2.3.1. Установка

**На сервере:**
```bash
sudo apt install -y fail2ban
```

#### 2.3.2. Конфигурация

fail2ban использует файл `jail.conf` для настроек. Мы НЕ редактируем его напрямую, а создаём локальный файл.

**На сервере:**
```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

Редактируем локальный файл:
```bash
sudo vim /etc/fail2ban/jail.local
```

Найдите секцию `[sshd]` и убедитесь что `enabled = true`:

```ini
[sshd]
enabled = true
```

Это защитит SSH от брутфорса.

#### 2.3.3. Запуск fail2ban

**На сервере:**
```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo systemctl status fail2ban
```

Статус должен быть `active (running)`.

#### 2.3.4. Защита Nginx Proxy Manager (настроим позже)

**Важно:** Эту секцию мы выполним ТОЛЬКО после установки Nginx Proxy Manager в Главе 4!

Иначе fail2ban будет пытаться мониторить несуществующие логи и выдавать ошибки.

**Напоминание на будущее (для п.4.1):**

После установки NPM создайте фильтр:
```bash
sudo vim /etc/fail2ban/filter.d/npm-general.conf
```

```ini
[Definition]
# Бан за 401, 403, 404 ответы
failregex = ^<HOST> .*"(?:GET|POST|HEAD).*HTTP.*" (?:401|403|404)
ignoreregex =
```

Добавьте jail в `/etc/fail2ban/jail.local`:
```ini
[npm-general]
enabled = true
filter = npm-general
action = iptables-allports[name=npm-general]
logpath = /srv/npm/data/logs/proxy-host-access.log
          /srv/npm/data/logs/fallback-access.log
maxretry = 10
findtime = 600
bantime = 3600
```

Перезапустите fail2ban:
```bash
sudo systemctl restart fail2ban
```

### 2.4. Изменение SSH порта (опционально, для параноиков)

Порт 22 для SSH известен всем. Можно сменить на нестандартный (например, 2222) для защиты от массовых сканеров.

**Внимание:** Это необязательно, но добавляет слой безопасности через obscurity.

#### 2.4.1. Резервная копия конфигурации SSH

**На сервере:**
```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak_before_port_change
```

#### 2.4.2. Изменение порта в конфигурации SSH

**На сервере:**
```bash
sudo vim /etc/ssh/sshd_config
```

Найдите строку:
```
#Port 22
```

Раскомментируйте (уберите `#`) и измените на 2222 (или любой другой порт от 1024 до 65535):
```
Port 2222
```

Можно оставить оба порта временно для тестирования:
```
Port 22
Port 2222
```

После проверки работы порта 2222, уберёте строку `Port 22`.

#### 2.4.3. Разрешение нового порта в UFW

**На сервере:**
```bash
sudo ufw allow 2222/tcp
sudo ufw reload
```

#### 2.4.4. Перезагрузка SSH сервиса

**На сервере:**
```bash
sudo systemctl restart sshd
```

#### 2.4.5. Проверка подключения на новом порту

**На локальном компьютере — НЕ закрывайте текущую SSH сессию!**

Откройте новый терминал и подключитесь:
```bash
ssh -i ~/.ssh/homeserver_key -p 2222 tuchnyak@192.168.1.100
```

Если работает — отлично! Теперь можно убрать порт 22 из конфигурации SSH и UFW.

**На сервере удалите старый порт:**
```bash
sudo ufw delete allow ssh  # или sudo ufw delete allow 22/tcp
sudo ufw reload
```

### 2.5. Чек-лист Главы 2

☐ SSH ключи сгенерированы (ED25519 или RSA 4096)  
☐ Публичный ключ скопирован на сервер  
☐ Вход по SSH работает БЕЗ пароля  
☐ Вход по паролю отключён в sshd_config  
☐ UFW firewall включён  
☐ SSH, HTTP, HTTPS разрешены в UFW  
☐ fail2ban установлен и запущен  
☐ (Опционально) SSH порт изменён на нестандартный  
☐ Создан ~/.ssh/config для удобства

---

## Глава 3: Фундамент для сервисов

В этой главе мы подготовим инфраструктуру для запуска контейнеров с сервисами.

### 3.1. Создание каталога /srv для данных

Все данные сервисов мы будем хранить в `/srv`. Это отдельная файловая система (или subvolume в Btrfs), что упрощает бэкап.

`/srv` — стандартный путь в Linux для "данных, обслуживаемых системой" (от "serve").

**Создание структуры каталогов:**

**На сервере:**
```bash
sudo mkdir -p /srv
```

Теперь создадим подкаталоги для каждого сервиса:

```bash
sudo mkdir -p /srv/nextcloud/db
sudo mkdir -p /srv/nextcloud/html
sudo mkdir -p /srv/jellyfin/config
sudo mkdir -p /srv/jellyfin/media
sudo mkdir -p /srv/qbittorrent/config
sudo mkdir -p /srv/qbittorrent/downloads
sudo mkdir -p /srv/syncthing/config
sudo mkdir -p /srv/syncthing/data
sudo mkdir -p /srv/npm/data/logs
sudo mkdir -p /srv/npm/letsencrypt
sudo mkdir -p /srv/adguardhome/work
sudo mkdir -p /srv/adguardhome/conf
sudo mkdir -p /srv/redis
sudo mkdir -p /srv/ollama
sudo mkdir -p /srv/open-webui
sudo mkdir -p /srv/gitea
sudo mkdir -p /srv/backups
```

Например:
- `/srv/jellyfin/config` — конфигурация Jellyfin
- `/srv/jellyfin/media` — ваша коллекция фильмов/сериалов
- `/srv/qbittorrent/downloads` — скачанные торренты

**Установка прав доступа:**

Для rootless Podman контейнеры работают от имени обычного пользователя, поэтому установим права:

**На сервере:**
```bash
# Сначала проверьте кто вы
whoami

# Установите права (замените tuchnyak на ваш username если нужно)
sudo chown -R tuchnyak:tuchnyak /srv
```

Проверка:
```bash
ls -la /srv
# Должно быть: drwxr-xr-x ... tuchnyak tuchnyak /srv
```

**Примечание о правах доступа для rootless Podman:**

В rootless Podman внутри контейнера используется маппинг UID/GID. То есть root внутри контейнера маппится на обычного пользователя снаружи.

Если возникнут проблемы с правами, можно использовать `podman unshare chown` или монтировать volumes с опцией `:Z` для SELinux relabeling (но в Ubuntu SELinux обычно не используется).

### 3.2. Установка Podman и podman-docker

Podman — альтернатива Docker без daemon, более безопасная (rootless по умолчанию).

**На сервере установите Podman:**
```bash
sudo apt install -y podman
```

**На сервере установите podman-docker (для совместимости с Docker CLI):**

Это нужно для инструментов типа Kamal, которые ожидают Docker API:
```bash
sudo apt install -y podman-docker
```

Это создаст симлинк `docker` → `podman`, и многие Docker-based инструменты будут работать.

**Проверка:**
```bash
podman --version
```

Должна показать версию Podman (например, `podman version 4.3.1`).

### 3.3. Включение linger для rootless контейнеров

**КРИТИЧЕСКИ ВАЖНО!**

Для того чтобы пользовательские systemd сервисы (и контейнеры через systemd quadlets) запускались при загрузке системы **БЕЗ** входа пользователя, нужно включить **linger**:

**На сервере:**
```bash
sudo loginctl enable-linger tuchnyak
```

Замените `tuchnyak` на ваш username.

Проверка:
```bash
loginctl show-user tuchnyak | grep Linger
```

Должно показать `Linger=yes`.

**Без этого:** После перезагрузки сервера контейнеры НЕ запустятся (они запускаются только когда пользователь залогинен).

**С этим:** После перезагрузки контейнеры запустятся автоматически (как если бы пользователь остался залогинен).

**Критическое различие между System и User quadlets:**

| Параметр | System | User (с linger) |
|----------|--------|-----------------|
| Где хранятся | `/etc/systemd/system/` | `~/.config/containers/systemd/` |
| Запуск при загрузке | ✅ Автоматически | ✅ Автоматически (с linger) |
| Из-под какого пользователя | root | Обычный пользователь (безопаснее) |
| Безопасность | ⚠️ root права | ✅ Rootless (безопаснее) |

**Мы используем User quadlets** — это правильный выбор для домашнего сервера (безопаснее, проще с правами доступа).

### 3.4. Установка Cockpit (веб-интерфейс для управления сервером)

Cockpit — удобный веб-интерфейс для мониторинга и управления сервером через браузер.

**На сервере установите Cockpit и плагин для Podman:**
```bash
sudo apt install -y cockpit cockpit-podman
```

**На сервере разрешите Cockpit в UFW:**

Cockpit работает на порту 9090. Мы разрешим доступ только из локальной сети:

```bash
# Замените 192.168.0.0/16 на ваш диапазон сети
# Например, если ваш IP 192.168.1.100, используйте 192.168.0.0/16 или 192.168.1.0/24
sudo ufw allow from 192.168.0.0/16 to any port 9090
sudo ufw reload
```

**Доступ к Cockpit:**

На любом компьютере в сети откройте браузер и перейдите на `https://192.168.1.100:9090` (замените IP на адрес вашего сервера).

Примите самоподписанный сертификат (браузер выдаст предупреждение, это нормально).

Войдите с вашим username и паролем.

**Что можно делать в Cockpit:**
- Мониторить загрузку CPU, RAM, диска
- Смотреть логи systemd
- Управлять systemd сервисами
- **Podman containers** — видеть запущенные контейнеры, логи, статистику
- Обновлять систему
- И многое другое

**Примечание:** Cockpit работает на порту 9090, но мы будем настраивать доступ через Nginx Proxy Manager на красивый домен типа `cockpit.internal` с HTTPS.

### 3.5. Установка Zellij (терминальный мультиплексор)

Zellij — современная альтернатива tmux/screen. Позволяет создавать несколько окон и панелей в одной SSH сессии.

**На сервере скачайте и установите Zellij:**

```bash
cd ~
wget https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz
tar -xvf zellij-x86_64-unknown-linux-musl.tar.gz
# Перемещаем в PATH
sudo mv zellij /usr/local/bin/
rm zellij-x86_64-unknown-linux-musl.tar.gz
```

**На сервере проверьте:**
```bash
zellij --version
```

**Использование:**
- Запуск: `zellij`
- Detach (отсоединиться, оставив сессию работать): `Ctrl+o`, затем `d`
- Вернуться к сессии: `zellij attach`

Zellij очень удобен для длительных операций (например, скачивание больших файлов) — вы можете detach и закрыть SSH, процесс продолжит работать.

### 3.6. Настройка Vim (опционально, для удобства)

Многие любят настроить Vim под себя. Вот базовая конфигурация.

**На сервере создайте ~/.vimrc:**
```bash
vim ~/.vimrc
```

Пример конфигурации:
```vim
" Включить подсветку синтаксиса
syntax on

" Цветовая схема
colorscheme desert

" Показывать номера строк
set number
set relativenumber

" Размер табуляции (4 пробела)
set tabstop=4
set shiftwidth=4
set expandtab

" Показывать статус-бар
set laststatus=2
```

Сохраните (`:wq` в vim).

Теперь Vim будет более удобным для редактирования конфигурационных файлов.

**Базовая шпаргалка Vim (для новичков):**

- `i` — войти в режим вставки (Insert mode)
- `Esc` — вернуться в Normal mode
- `:w` — сохранить
- `:q` — выйти
- `:wq` — сохранить и выйти
- `dd` — удалить строку
- `yy` — скопировать строку
- `p` — вставить
- `/слово` — поиск слова
- `n` — следующее совпадение

Больше информации: `:help` в vim или `vimtutor` в командной строке.

### 3.7. Чек-лист Главы 3

☐ Каталог /srv создан с подкаталогами для всех сервисов  
☐ Права доступа на /srv настроены (проверили whoami и chown)  
☐ Podman установлен  
☐ podman-docker установлен (для Kamal)  
☐ linger включён для пользователя (проверили loginctl)  
☐ Cockpit установлен и доступен  
☐ Zellij установлен  
☐ (Опционально) Vim настроен

---

## Глава 4: Сетевая инфраструктура и файловый доступ

В этой главе мы настроим:
- Nginx Proxy Manager (прокси с HTTPS)
- DNS для .internal доменов
- Samba для доступа к файлам из Windows/macOS

### 4.1. Развертывание Nginx Proxy Manager (NPM)

NPM — веб-интерфейс для Nginx, позволяет легко настраивать прокси, SSL сертификаты и многое другое.

#### 4.1.1. Подготовка логов для fail2ban

**На сервере** подготовьте логи (они будут использоваться fail2ban позже):

```bash
sudo mkdir -p /srv/npm/data/logs
sudo touch /srv/npm/data/logs/proxy-host-access.log
sudo touch /srv/npm/data/logs/fallback-access.log
sudo chown -R 1000:1000 /srv/npm/data
```

#### 4.1.2. Создание systemd quadlet для NPM

**Создание каталога для quadlets на сервере (если ещё не создан):**
```bash
mkdir -p ~/.config/containers/systemd/
```

**На сервере создайте quadlet файл:**
```bash
vim ~/.config/containers/systemd/npm.container
```

**Содержимое:**
```ini
[Unit]
Description=Nginx Proxy Manager
After=network.target

[Container]
Image=docker.io/jc21/nginx-proxy-manager:latest
ContainerName=npm
PublishPort=8080:80
PublishPort=8181:81
PublishPort=4443:443
Volume=/srv/npm/data:/data
Volume=/srv/npm/letsencrypt:/etc/letsencrypt

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**Объяснение:**
- `PublishPort=8080:80` — HTTP (контейнер:хост)
- `PublishPort=8181:81` — Веб-интерфейс NPM
- `PublishPort=4443:443` — HTTPS
- `Volume=/srv/npm/data:/data` — данные NPM
- `Restart=always` — автоматический перезапуск при сбое

**Примечание о портах:** Мы используем 8080, 8181, 4443 на хосте, чтобы избежать конфликтов с другими сервисами и потому что порты <1024 требуют root прав.

#### 4.1.3. Запуск NPM

**На сервере** перечитайте systemd конфигурацию:
```bash
systemctl --user daemon-reload
```

Запустите и включите автозапуск:
```bash
systemctl --user enable --now npm.container
```

Проверка:
```bash
systemctl --user status npm.container
```

Статус должен быть `active (running)`.

#### 4.1.4. Доступ к веб-интерфейсу NPM

На любом компьютере в сети откройте браузер: `http://192.168.1.100:8181`

**Логин по умолчанию:**
- Email: `admin@example.com`
- Password: `changeme`

**Сразу после входа измените пароль!**

### 4.2. Настройка HTTPS для .internal доменов

Теперь мы настроим SSL сертификаты для внутренних доменов типа `jellyfin.internal`, `cloud.internal` и т.д.

#### 4.2.1. Метод 1: mkcert (самоподписанные сертификаты для локальной сети)

**mkcert** — утилита для создания локальных CA (Certificate Authority) и сертификатов, которым доверяют браузеры.

**Шаг 1: На вашем основном компьютере установите mkcert**

**macOS:**
```bash
brew install mkcert
```

**Windows (Chocolatey):**
```powershell
choco install mkcert
```

**Linux:**
```bash
sudo apt install libnss3-tools -y
```

Скачайте mkcert:
```bash
curl -JLO https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64
chmod +x mkcert-v1.4.4-linux-amd64
sudo mv mkcert-v1.4.4-linux-amd64 /usr/local/bin/mkcert
```

**Шаг 2: На локальном компьютере установите локальный CA**

Эта команда создаст локальный CA и установит его в систему доверенных сертификатов:
```bash
mkcert -install
```

**Шаг 3: На локальном компьютере создайте wildcard сертификат для .internal**

```bash
mkcert "*.internal"
```

Будут созданы файлы:
- `_wildcard.internal.pem` — сертификат
- `_wildcard.internal-key.pem` — приватный ключ

**Шаг 4: На локальном компьютере находим корневой CA**

```bash
mkcert -CAROOT
```

Это покажет путь к корневому CA (например, `/Users/george/Library/Application\ Support/mkcert`)

**Шаг 5: Загрузка сертификата в Nginx Proxy Manager**

1. Откройте NPM веб-интерфейс на сервере (`http://192.168.1.100:8181`)
2. Перейдите в **SSL Certificates** → **Add SSL Certificate**
3. Выберите **Custom**
4. **Nickname:** `Internal Wildcard Cert`
5. **Certificate Key:** Скопируйте содержимое `_wildcard.internal-key.pem`
   - Это текст от `-----BEGIN PRIVATE KEY-----` до `-----END PRIVATE KEY-----`
6. **Certificate:** Скопируйте содержимое `_wildcard.internal.pem`
7. Нажмите **Save**

Готово! Теперь у вас есть wildcard SSL сертификат для всех .internal доменов.

**Шаг 6: Установка CA на все ваши устройства**

Чтобы браузеры доверяли сертификатам, нужно установить CA на всех устройствах (ноутбук, телефон и т.д.).

**Linux:**
```bash
sudo cp /path/to/rootCA.pem /usr/local/share/ca-certificates/mkcert-ca.crt
sudo update-ca-certificates
```

**macOS:**
CA уже автоматически установлен в Keychain при `mkcert -install`

**Windows:**
1. Найди файл `rootCA.pem`
2. Кликни дважды на файл
3. Выбери **"Install Certificate"** → **"Local Machine"** → **"Browse"** → **"Trusted Root Certification Authorities"** → **"Next"** → **"Finish"**

**Android:**
1. Скачай `rootCA.pem` через браузер/email
2. Переименуй в `rootCA.crt` (расширение важно!)
3. Settings → Security → Install certificate → CA certificate → выбери файл

**iPhone/iPad:**
1. Скачай `rootCA.pem` через Safari/email
2. Settings → General → VPN & Device Management → Install certificate
3. Settings → General → About → Certificate Trust Settings → Trust mkcert

**Smart TV (Android TV):**
- Аналогично Android, или просто используй HTTP без сертификатов

#### 4.2.2. Метод 2: Let's Encrypt (для публичных доменов)

Если у вас есть публичный домен и вы хотите реальные сертификаты Let's Encrypt:

**Требования:**
- Публичный домен (например, `mydomain.com`)
- DNS провайдер с API (Cloudflare, DigitalOcean, GoDaddy и др.)

**Процесс в NPM:**
1. Перейдите в **SSL Certificates** → **Add SSL Certificate**
2. Выберите **Let's Encrypt**
3. Выберите **DNS Provider** (например, Cloudflare)
4. Введите API ключи вашего DNS провайдера
5. Домены: `*.mydomain.com` (wildcard)
6. Нажмите **Save**

NPM автоматически пройдёт DNS Challenge и получит сертификат.

#### 4.2.3. Метод 3: Self-Signed в NPM (не рекомендуется)

NPM может генерировать самоподписанные сертификаты, но браузеры будут выдавать предупреждения. Не рекомендуется, используйте mkcert.

### 4.3. Настройка DNS для jellyfin.internal и других доменов

Теперь нужно настроить DNS, чтобы домены типа `jellyfin.internal` указывали на IP сервера `192.168.1.100`.

**Три способа:**

#### Способ 1: Настройка на роутере (рекомендуется для всей сети)

Войдите в веб-интерфейс вашего роутера (обычно `192.168.1.1`).

Найдите раздел **DNS** или **Local DNS** или **DHCP/DNS**.

Добавьте записи:
- `jellyfin.internal` → `192.168.1.100`
- `cloud.internal` → `192.168.1.100`
- `torrents.internal` → `192.168.1.100`
- И так далее

Некоторые роутеры поддерживают wildcard записи:
- `*.internal` → `192.168.1.100`

Это самый удобный способ — DNS будет работать для всех устройств в сети.

#### Способ 2: AdGuard Home (DNS фильтрация + кастомные записи)

AdGuard Home — мощный DNS сервер с блокировкой рекламы.

**Важно:** Порт 53 используется системным `systemd-resolved`. Нужно его отключить.

**На сервере отключите systemd-resolved для порта 53:**

```bash
# 1. Отключаем прослушивание systemd-resolved на порту 53
sudo mkdir -p /etc/systemd/resolved.conf.d
echo -e "[Resolve]\nDNSStubListener=no" | sudo tee /etc/systemd/resolved.conf.d/adguardhome.conf

# 2. Удаляем старый симлинк resolv.conf и создаём новый
sudo mv /etc/resolv.conf /etc/resolv.conf.backup
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

# 3. Перезапускаем systemd-resolved
sudo systemctl reload-or-restart systemd-resolved

# 4. Проверка что systemd-resolved ещё живёт
sudo systemctl status systemd-resolved

# 5. Проверка что порт 53 свободен
sudo lsof -i :53
# Должно быть пусто или только AdGuard (если запущен)
```

**На сервере создайте quadlet для AdGuard Home:**

```bash
vim ~/.config/containers/systemd/container-adguardhome.container
```

```ini
[Unit]
Description=AdGuard Home DNS Filter
After=network.target

[Container]
Image=docker.io/adguard/adguardhome:latest
ContainerName=adguardhome
PublishPort=5353:53/tcp
PublishPort=5353:53/udp
PublishPort=3000:3000/tcp
Volume=/srv/adguardhome/work:/opt/adguardhome/work
Volume=/srv/adguardhome/conf:/opt/adguardhome/conf

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**Примечание:** Мы используем порт 5353 для DNS (вместо 53), чтобы не конфликтовать (хотя 53 свободен после отключения stub listener).

**На сервере запустите:**
```bash
systemctl --user daemon-reload
systemctl --user enable --now container-adguardhome.service
```

**Первоначальная настройка AdGuard Home:**

1. На любом компьютере откройте `http://192.168.1.100:3000`
2. Пройдите мастер настройки
3. Установите admin пароль
4. В настройках **DNS Listen Interfaces** выберите ваш сетевой интерфейс

**На AdGuard Home добавьте DNS Rewrites (кастомные домены):**

1. Перейдите **Filters** → **DNS rewrites**
2. Нажмите **Add DNS Rewrite**
3. **Domain:** `*.internal`
4. **IP address:** `192.168.1.100`
5. Нажмите **Save**

Теперь AdGuard Home будет резолвить все .internal домены на ваш сервер.

**На ваших устройствах настройте DNS:**

В настройках сети укажите DNS сервер `192.168.1.100` (или `192.168.1.100:5353` если используем нестандартный порт).

Или настройте на роутере использование `192.168.1.100` как DNS для всей сети.

#### Способ 3: /etc/hosts на каждом клиенте (простой, но не масштабируемый)

На каждом устройстве отредактируйте файл `/etc/hosts`:

**Linux/macOS:**
```bash
sudo vim /etc/hosts
```

**Windows (cmd как администратор):**
```
notepad C:\Windows\System32\drivers\etc\hosts
```

Добавьте:
```
192.168.1.100 jellyfin.internal
192.168.1.100 cloud.internal
192.168.1.100 torrents.internal
192.168.1.100 sync.internal
192.168.1.100 cockpit.internal
192.168.1.100 ollama-ui.internal
192.168.1.100 git.internal
```

Сохраните файл.

**Минусы:** Нужно настраивать на каждом устройстве отдельно.

### 4.4. Настройка Samba для доступа к файлам

Samba позволяет делиться файлами по сети. Например, можно открыть `/srv/jellyfin/media` как сетевой диск и добавлять фильмы с компьютера.

#### 4.4.1. Установка Samba

**На сервере:**
```bash
sudo apt install -y samba
```

#### 4.4.2. Резервная копия конфигурации

**На сервере:**
```bash
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
```

#### 4.4.3. Редактирование конфигурации Samba

**На сервере:**
```bash
sudo vim /etc/samba/smb.conf
```

**Найдите и отредактируйте секцию [global]:**

```ini
[global]
   # Запретить гостевой доступ
   map to guest = never
   
   # Шифрование (для безопасности)
   server smb encrypt = required
```

**Добавьте шары в конец файла:**

```ini
# Медиа файлы для Jellyfin
[Media]
   comment = Media files for Jellyfin
   path = /srv/jellyfin/media
   browseable = yes
   guest ok = no
   read only = no
   writable = yes
   create mask = 0755
   directory mask = 0755
   valid users = tuchnyak

# Торренты из qBittorrent
[Torrents]
   comment = Torrent downloads from qBittorrent
   path = /srv/qbittorrent/downloads
   browseable = yes
   guest ok = no
   read only = no
   writable = yes
   create mask = 0755
   directory mask = 0755
   valid users = tuchnyak

# Резервные копии клиентских машин
[Backups]
   comment = Client machine backups
   path = /srv/backups
   browseable = yes
   guest ok = no
   read only = no
   writable = yes
   create mask = 0755
   directory mask = 0755
   valid users = tuchnyak
```

**Примечание:** `valid users = tuchnyak` ограничивает доступ только вашим пользователем. Можно добавить несколько: `valid users = tuchnyak, user2` или группу: `valid users = @familygroup`.

**На сервере создайте каталог для Backups:**
```bash
sudo mkdir -p /srv/backups
sudo chown tuchnyak:tuchnyak /srv/backups
```

#### 4.4.4. Создание Samba пользователя

**На сервере** Samba использует отдельную базу паролей:

```bash
sudo smbpasswd -a tuchnyak
```

Введите пароль для Samba (может быть отличным от системного пароля).

#### 4.4.5. Перезагрузка Samba

**На сервере:**
```bash
sudo systemctl restart smbd
sudo systemctl restart nmbd
```

#### 4.4.6. Проверка доступа к шарам

**Windows:**
1. Откройте Проводник
2. В адресной строке введите `\\192.168.1.100` и нажмите Enter
3. Должны увидеть шары: Media, Torrents, Backups
4. Войдите с вашим Samba username и паролем

**macOS:**
1. Finder → Go → Connect to Server (Cmd+K)
2. Введите `smb://192.168.1.100`
3. Войдите с вашим Samba username и паролем

**Linux:**
```bash
smbclient -L //192.168.1.100 -U tuchnyak
```

Введите пароль, должен показать список шар.

### 4.5. Чек-лист Главы 4

☐ Nginx Proxy Manager установлен и запущен  
☐ NPM веб-интерфейс доступен на :8181  
☐ Логи NPM подготовлены для fail2ban  
☐ SSL сертификаты для .internal доменов созданы (mkcert)  
☐ CA установлена на всех ваших устройствах  
☐ DNS настроен (роутер, AdGuard Home или /etc/hosts)  
☐ Samba установлен и настроен  
☐ Samba шары доступны с других устройств

---

## Глава 5: Развертывание основных сервисов

Теперь развернём основные сервисы через systemd quadlets.

### 5.1. PostgreSQL (база данных для Nextcloud)

#### 5.1.1. Создание переменных окружения

**На сервере** создайте каталог для env файлов:
```bash
mkdir -p ~/compose
```

Создайте env файл:
```bash
vim ~/compose/nextcloud.env
```

Содержимое:
```
POSTGRES_USER=nextcloud
POSTGRES_PASSWORD=your_very_strong_password_min_16_chars
POSTGRES_DB=nextcloud
```

**Важно:** Замените пароль на реальный сложный пароль!

Ограничьте права доступа:
```bash
chmod 600 ~/compose/nextcloud.env
```

#### 5.1.2. Создание quadlet для PostgreSQL

**На сервере:**
```bash
vim ~/.config/containers/systemd/container-nextclouddb.container
```

```ini
[Unit]
Description=Nextcloud PostgreSQL Database
After=network.target

[Container]
Image=docker.io/postgres:15
ContainerName=nextclouddb
Volume=/srv/nextcloud/db:/var/lib/postgresql/data
EnvironmentFile=%h/compose/nextcloud.env

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**Примечание:** `%h` в systemd означает домашнюю директорию пользователя (`/home/tuchnyak`).

**На сервере запустите:**
```bash
systemctl --user daemon-reload
systemctl --user start nextcloud-db.container
```

Проверка:
```bash
systemctl --user status nextcloud-db.container
```

**Примечание для будущего:** Если появится новый сервис с потребностью в PostgreSQL, можно добавить новую БД в существующий контейнер:
```bash
podman exec -it nextclouddb psql -U postgres -c "CREATE DATABASE newservice;"
```

Или создать отдельный контейнер на другом порту (5433, 5434 и т.д.) если нужна другая версия PostgreSQL.

### 5.2. Nextcloud (личное облако)

#### 5.2.1. Создание quadlet для Nextcloud

**На сервере:**
```bash
vim ~/.config/containers/systemd/container-nextcloudapp.container
```

```ini
[Unit]
Description=Nextcloud Application
After=network.target nextcloud-db.service
Requires=nextcloud-db.service

[Container]
Image=docker.io/nextcloud:latest
ContainerName=nextcloudapp
PublishPort=8180:80
Volume=/srv/nextcloud/html:/var/www/html
Environment=POSTGRES_HOST=127.0.0.1
Environment=POSTGRES_PORT=5432
EnvironmentFile=%h/compose/nextcloud.env

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**Примечание:** 
- `Requires=nextcloud-db.service` — Nextcloud зависит от БД
- `After=nextcloud-db.service` — Nextcloud запускается ПОСЛЕ БД
- `POSTGRES_HOST=127.0.0.1` — подключение к БД на локальном хосте

**На сервере запустите:**
```bash
systemctl --user daemon-reload
systemctl --user start nextcloud-app.container
sudo ufw allow 8180/tcp comment "Nextcloud"
```

#### 5.2.2. Первоначальная настройка Nextcloud

На любом компьютере откройте браузер: `http://192.168.1.100:8180`

Вы увидите мастер установки Nextcloud.

1. Создайте **admin аккаунт** (username и пароль)
2. **Data folder:** оставьте по умолчанию (`/var/www/html/data`)
3. **Database:**
   - Выберите **PostgreSQL**
   - **User:** `nextcloud`
   - **Password:** (ваш пароль из nextcloud.env)
   - **Database:** `nextcloud`
   - **Host:** `127.0.0.1:5432`
4. Нажмите **Finish setup**

Nextcloud установится (может занять 1-2 минуты).

#### 5.2.3. Настройка прокси через NPM для cloud.internal

1. На компьютере откройте NPM (`http://192.168.1.100:8181`)
2. **Hosts** → **Proxy Hosts** → **Add Proxy Host**
3. **Details:**
   - **Domain Names:** `cloud.internal`
   - **Scheme:** `http`
   - **Forward Hostname/IP:** `127.0.0.1`
   - **Forward Port:** `8180`
   - ☑ **Block Common Exploits**
   - ☑ **Websockets Support**
4. **SSL:**
   - **SSL Certificate:** Выберите ваш Internal Wildcard Cert
   - ☑ **Force SSL**
5. **Save**

Теперь можно открыть `https://cloud.internal` и работать с Nextcloud через HTTPS!

**Примечание:** Возможно потребуется добавить `cloud.internal` в `trusted_domains` в Nextcloud конфигурации:

**На сервере:**
```bash
podman exec -it nextcloudapp bash
vi /var/www/html/config/config.php
```

Найдите массив `trusted_domains` и добавьте:
```php
'trusted_domains' =>
array (
  0 => '192.168.1.100:8180',
  1 => 'cloud.internal',
),
```

Сохраните и выйдите.

### 5.3. Jellyfin (медиасервер)

#### 5.3.1. Создание quadlet для Jellyfin

**На сервере:**
```bash
vim ~/.config/containers/systemd/container-jellyfin.container
```

```ini
[Unit]
Description=Jellyfin Media Server
After=network.target

[Container]
Image=docker.io/jellyfin/jellyfin:latest
ContainerName=jellyfin
PublishPort=8096:8096
PublishPort=8920:8920
Volume=/srv/jellyfin/config:/config
Volume=/srv/jellyfin/media:/media
Environment=JELLYFIN_PublishedServerUrl=http://192.168.1.100:8096

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**На сервере запустите:**
```bash
systemctl --user daemon-reload
systemctl --user start container-jellyfin.service
sudo ufw allow 8096/tcp comment "Jellyfin HTTP"
sudo ufw allow 8920/tcp comment "Jellyfin HTTPS"
```

#### 5.3.2. Первоначальная настройка Jellyfin

На любом компьютере откройте браузер: `http://192.168.1.100:8096`

Пройдите мастер настройки:
1. Выберите язык
2. Создайте пользователя (admin)
3. **Add Media Library:**
   - **Type:** Movies (или другое)
   - **Folders:** `/media` (путь внутри контейнера)
4. Завершите настройку

#### 5.3.3. Добавление медиафайлов

**Workflow:**

1. На компьютере используйте Samba шару `Torrents` (\\192.168.1.100\Torrents) или `Downloads` для скачивания торрентов через qBittorrent
2. Скачанные файлы появляются в `/srv/qbittorrent/downloads`
3. Откройте Samba шару `Media` (\\192.168.1.100\Media)
4. Скопируйте или переместите фильм туда
5. В Jellyfin: **Dashboard** → **Libraries** → **Scan Libraries** для обновления

**Альтернатива (если много фильмов):**

**На сервере** создайте символическую ссылку:
```bash
ln -s /srv/qbittorrent/downloads /srv/jellyfin/media/torrents
```

Тогда скачанные файлы сразу видны в Jellyfin без перемещения.

#### 5.3.4. Настройка прокси через NPM для jellyfin.internal

1. В NPM (http://192.168.1.100:8181): **Add Proxy Host**
2. **Domain:** `jellyfin.internal`
3. **Forward:** `127.0.0.1:8096`
4. **SSL:** Internal Wildcard Cert
5. **Save**

Доступ: `https://jellyfin.internal`

### 5.4. qBittorrent (торрент-клиент)

#### 5.4.1. Создание quadlet для qBittorrent

**На сервере:**
```bash
vim ~/.config/containers/systemd/container-qbittorrent.container
```

```ini
[Unit]
Description=qBittorrent Torrent Client
After=network.target

[Container]
Image=lscr.io/linuxserver/qbittorrent:latest
ContainerName=qbittorrent
Environment=PUID=1000
Environment=PGID=1000
Environment=TZ=Europe/Moscow
PublishPort=8090:8080
PublishPort=6881:6881
PublishPort=6881:6881/udp
Volume=/srv/qbittorrent/config:/config
Volume=/srv/qbittorrent/downloads:/downloads

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**Примечание:** Мы используем порт **8090** на хосте (вместо 8080) чтобы избежать конфликта с NPM!

**Объяснение переменных:**
- `PUID=1000` — User ID (ваш пользователь, обычно 1000)
- `PGID=1000` — Group ID
- `TZ=Europe/Moscow` — временная зона (измените на вашу)

**На сервере запустите:**
```bash
systemctl --user daemon-reload
systemctl --user start container-qbittorrent.service
sudo ufw allow 8090/tcp comment "qBittorrent WebUI"
sudo ufw allow 6881/tcp comment "qBittorrent DHT"
sudo ufw allow 6881/udp comment "qBittorrent DHT UDP"
```

#### 5.4.2. Первоначальная настройка qBittorrent

На любом компьютере откройте: `http://192.168.1.100:8090`

**Логин по умолчанию:**
- Username: `admin`
- Password: `adminadmin`

**Сразу измените пароль!**

Перейдите **Tools** → **Options** → **Web UI** и измените пароль.

#### 5.4.3. Настройка каталога загрузки

**Tools** → **Options** → **Downloads:**
- **Default Save Path:** `/downloads` (внутри контейнера, соответствует `/srv/qbittorrent/downloads` на хосте)

Файлы будут сохраняться в `/srv/qbittorrent/downloads` на хосте.

#### 5.4.4. Настройка прокси через NPM

1. В NPM: **Add Proxy Host**
2. **Domain:** `torrents.internal`
3. **Forward:** `127.0.0.1:8090`
4. **SSL:** Internal Wildcard Cert
5. **Save**

Доступ: `https://torrents.internal`

### 5.5. Syncthing (синхронизация файлов)

#### 5.5.1. Создание quadlet для Syncthing

**На сервере:**
```bash
vim ~/.config/containers/systemd/container-syncthing.container
```

```ini
[Unit]
Description=Syncthing File Sync
After=network.target

[Container]
Image=lscr.io/linuxserver/syncthing:latest
ContainerName=syncthing
Environment=PUID=1000
Environment=PGID=1000
Environment=TZ=Europe/Moscow
PublishPort=8384:8384
PublishPort=22000:22000
PublishPort=22000:22000/udp
PublishPort=21027:21027/udp
Volume=/srv/syncthing/config:/config
Volume=/srv/syncthing/data:/data1

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**На сервере запустите:**
```bash
systemctl --user daemon-reload
systemctl --user start container-syncthing.service
sudo ufw allow 8384/tcp comment "Syncthing WebUI"
sudo ufw allow 22000/tcp comment "Syncthing Sync TCP"
sudo ufw allow 22000/udp comment "Syncthing Sync UDP"
sudo ufw allow 21027/udp comment "Syncthing Discovery"
```

#### 5.5.2. Первоначальная настройка Syncthing

На любом компьютере откройте: `http://192.168.1.100:8384`

При первом запуске появится предупреждение о GUI доступе из внешней сети.

Настройте:
1. **Actions** → **Settings**
2. **GUI:**
   - Установите **GUI Authentication** (username и пароль)
3. Добавьте папки для синхронизации

#### 5.5.3. Настройка прокси через NPM

1. В NPM: **Add Proxy Host**
2. **Domain:** `sync.internal`
3. **Forward:** `127.0.0.1:8384`
4. **SSL:** Internal Wildcard Cert
5. ☑ **Websockets Support**
6. **Save**

Доступ: `https://sync.internal`

### 5.6. AdGuard Home (если ещё не установлен)

Уже установлен в п.4.3 (Способ 2).

### 5.7. Чек-лист Главы 5

☐ PostgreSQL запущен для Nextcloud  
☐ Nextcloud установлен и доступен через cloud.internal  
☐ Jellyfin установлен и доступен через jellyfin.internal  
☐ qBittorrent установлен и доступен через torrents.internal (порт 8090!)  
☐ Syncthing установлен и доступен через sync.internal  
☐ Все сервисы добавлены в NPM с HTTPS

---

## Глава 6: Стратегия резервного копирования

### 6.1. Btrfs снапшоты (автоматические)

У вас уже настроен Snapper (см. Главу 1.8).

**На сервере** проверка снапшотов:
```bash
sudo snapper list
```

Просмотр размера:
```bash
sudo btrfs filesystem usage /
```

Восстановление из снапшота (если что-то сломалось):
```bash
sudo snapper -c root list
sudo snapper -c root rollback <номер_снапшота>
sudo reboot
```

### 6.2. Резервное копирование /srv

Все данные сервисов находятся в `/srv`. Это единственное место которое нужно бэкапить.

#### 6.2.1. Метод 1: rsync на внешний диск или NAS

**На сервере** подготовьте внешний диск:

```bash
# 1. Подключите внешний диск/флешку через USB
# Узнайте имя устройства
lsblk
# Например: sdb, sdc и т.д.

# 2. Создайте монтирование точку
sudo mkdir -p /mnt/backup

# 3. Смонтируйте диск (замените /dev/sdb1 на ваше устройство)
sudo mount /dev/sdb1 /mnt/backup

# 4. Проверьте что диск смонтирован
df -h | grep /mnt/backup

# Вывод должен быть примерно:
# /dev/sdb1       500G  10G  490G   2% /mnt/backup
```

**На сервере** выполните rsync:
```bash
rsync -avz --delete /srv/ /mnt/backup/srv/
```

Флаги
- `-a` — архивный режим (сохраняет права, время и т.д.)
- `-v` — verbose (показывать процесс)
- `-z` — сжатие
- `--delete` — удалять файлы в назначении которых нет в источнике

**На сервере** установите автоматический бэкап:
```bash
sudo crontab -e
```

Добавьте:
```
0 2 * * * rsync -avz --delete /srv/ /mnt/backup/srv/
```

Это будет делать бэкап каждый день в 2:00 ночи.

**На сервере** проверка:
```bash
ls -la /mnt/backup/srv/
# Должны видеть все подкаталоги
```

**Постоянное монтирование диска (опционально):**

**На сервере** добавьте в fstab:
```bash
sudo blkid /dev/sdb1
# Запомните UUID

sudo vim /etc/fstab
```

Добавьте:
```
UUID=<your-uuid-here> /mnt/backup ext4 defaults,nofail 0 2
```

Параметр `nofail` означает что система загрузится даже если диск не подключен.

#### 6.2.2. Метод 2: Btrfs send/receive (если есть второй Btrfs диск)

**Требования:** Целевой диск тоже должен быть Btrfs!

**На сервере** подготовьте диск:
```bash
# Смонтируйте внешний Btrfs диск
sudo mount /dev/sdb1 /mnt/backup

# Проверьте файловую систему
df -T | grep /mnt/backup
# Должно показать: btrfs
```

**На сервере** создайте снапшот (если ещё нет):
```bash
sudo snapper -c root list
# Найдите номер последнего снапшота, например 42
```

**На сервере** отправьте снапшот:
```bash
# Локально на внешний диск
sudo btrfs send /var/lib/snapshots/1/snapshot | sudo btrfs receive /mnt/backup/btrfs-snaps

# Удалённо на другой сервер (по SSH)
sudo btrfs send /var/lib/snapshots/1/snapshot | ssh user@backupserver "btrfs receive /mnt/backup"
```

**На сервере** проверка на целевом диске:
```bash
sudo btrfs subvolume list /mnt/backup
```

**Плюсы:** Очень быстро (отправляет только изменения), полная история снапшотов.

#### 6.2.3. Метод 3: Borg Backup (дедупликация и шифрование)

Borg — мощная утилита для инкрементальных зашифрованных бэкапов.

**На сервере** установите:
```bash
sudo apt install -y borgbackup
```

**На сервере** подготовьте внешний диск (любая файловая система):
```bash
sudo mkdir -p /mnt/backup
sudo mount /dev/sdb1 /mnt/backup
sudo mkdir -p /mnt/backup/borg-repo

# Даёте права доступа
sudo chown -R tuchnyak:tuchnyak /mnt/backup/borg-repo
```

**На сервере** инициализируйте репозиторий:
```bash
borg init --encryption=repokey /mnt/backup/borg-repo
# Введите пароль для хранилища
```

**На сервере** создайте первый бэкап:
```bash
borg create --progress /mnt/backup/borg-repo::srv-$(date +%Y-%m-%d) /srv/
# Процесс может занять время (зависит от размера /srv)
```

**На сервере** список бэкапов:
```bash
borg list /mnt/backup/borg-repo
```

Вывод:
```
srv-2025-11-27 Thu, 2025-11-27 14:32:05 [5c5ad6fb8b89c4f8e7c9a4f2f5e8d6f4]
srv-2025-11-28 Fri, 2025-11-28 14:32:05 [a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6]
```

**На сервере** восстановление:
```bash
# Восстановить весь бэкап в текущую директорию
borg extract /mnt/backup/borg-repo::srv-2025-11-28

# Восстановить конкретный файл
borg extract /mnt/backup/borg-repo::srv-2025-11-28 srv/nextcloud/html/config.php
```

**На сервере** информация о бэкапе:
```bash
borg info /mnt/backup/borg-repo::srv-2025-11-28
```

Показывает размер на диске, оригинальный размер, коэффициент сжатия и дедупликации.

**На сервере** удалённый бэкап (если хранилище на другом сервере):
```bash
borg init --encryption=repokey user@backupserver:/mnt/backup/borg-repo
borg create user@backupserver:/mnt/backup/borg-repo::srv-$(date +%Y-%m-%d) /srv/
```

**На сервере** автоматический бэкап:
```bash
sudo crontab -e
```

Добавьте:
```
0 3 * * * borg create --progress /mnt/backup/borg-repo::srv-$(date +\%Y-\%m-\%d) /srv/
```

### 6.3. Проверка восстановления

**Важно:** Периодически проверяйте что бэкапы работают!

**На сервере** создайте тестовый файл:
```bash
echo "test data" > /srv/test.txt
```

**Сделайте бэкап (выберите один метод):**

```bash
# Для rsync
rsync -avz --delete /srv/ /mnt/backup/srv/

# Для Borg
borg create /mnt/backup/borg-repo::test-$(date +%Y-%m-%d) /srv/
```

**На сервере** удалите тестовый файл:
```bash
rm /srv/test.txt
```

**Восстановите из бэкапа:**

```bash
# Для rsync
rsync -avz /mnt/backup/srv/ /srv/

# Для Borg
borg extract /mnt/backup/borg-repo::test-2025-11-28
```

**Проверьте что файл вернулся:**
```bash
cat /srv/test.txt
# Должно вывести: test data
```

Удалите тестовый файл:
```bash
rm /srv/test.txt
```

---

## Глава 7: Развертывание собственных приложений с помощью Kamal

Kamal — инструмент для деплоя Docker (и Podman) приложений на серверы.

### 7.1. Установка Ruby и Kamal

Kamal написан на Ruby.

**На сервере** установите Ruby:
```bash
sudo apt install -y ruby-full
```

**На сервере** или на локальной машине установите Kamal (подходит для обоих):
```bash
gem install kamal
```

Проверка:
```bash
kamal version
```

### 7.2. Настройка Podman совместимости

Kamal ожидает Docker API. У нас установлен `podman-docker` (см. Главу 3.2), который создаёт симлинк `docker` → `podman`.

**На сервере** проверьте:
```bash
docker --version
```

Должно показать Podman.

**На сервере** дополнительно может потребоваться Podman socket:
```bash
systemctl --user enable --now podman.socket
```

### 7.3. Пример деплоя приложения

Допустим у вас есть Rails или другое приложение в Git репозитории.

**Шаг 1: На локальной машине** в вашем проекте создайте `config/deploy.yml`:

```yaml
service: myapp
image: your_dockerhub_username/myapp

servers:
  web:
    - 192.168.1.100

registry:
  username: your_dockerhub_username
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    RAILS_ENV: production
  secret:
    - RAILS_MASTER_KEY
```

**Шаг 2: На локальной машине** установите переменные окружения:

```bash
export KAMAL_REGISTRY_PASSWORD=your_docker_hub_password
export RAILS_MASTER_KEY=your_rails_master_key
```

**Шаг 3: На локальной машине** первый деплой:
```bash
kamal setup
```

Kamal:
- Соберёт Docker образ
- Загрузит в registry (Docker Hub)
- Подключится к серверу по SSH
- Стянет образ на сервер
- Запустит контейнер
- Настроит zero-downtime deployment

**Шаг 4: На локальной машине** последующие деплои:
```bash
kamal deploy
```

**На сервере** проверка запущенных контейнеров:
```bash
podman ps
```

Должен быть контейнер с названием `myapp`.

### 7.4. Интеграция с NPM

**После деплоя через Kamal на сервере** настройте прокси в NPM:

1. Откройте NPM веб-интерфейс (`http://192.168.1.100:8181`)
2. **Hosts** → **Proxy Hosts** → **Add Proxy Host**
3. **Domain:** `myapp.internal`
4. **Forward:** `127.0.0.1:<порт_приложения>` (обычно 3000 для Rails)
5. **SSL:** Internal Wildcard Cert
6. **Save**

Доступ: `https://myapp.internal`

---

## Глава 8: Дополнительные сервисы и расширения

### 8.1. Redis для Nextcloud (кэширование)

**Когда нужен Redis:**
- 5+ активных пользователей Nextcloud
- Синхронизация больших папок
- Частые операции с файлами

**Когда можно обойтись без:**
- 1-2 пользователя
- Редкое использование
- Нет проблем с производительностью

**Утилизация ресурсов:**
- RAM: 200-400 МБ (малая)
- CPU: 1-2%
- Диск: практически не использует

**Примечание:** Redis можно добавить позже без проблем — просто разверните контейнер, отредактируйте Nextcloud конфиг и перезагрузите.

#### Quadlet для Redis

**На сервере:**
```bash
vim ~/.config/containers/systemd/container-redis.container
```

```ini
[Unit]
Description=Redis Cache for Nextcloud
After=network.target

[Container]
Image=docker.io/redis:alpine
ContainerName=redis
PublishPort=6379:6379
Volume=/srv/redis:/data

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**На сервере** запустите:
```bash
systemctl --user daemon-reload
systemctl --user start container-redis.service
```

#### Настройка Nextcloud для использования Redis

**На сервере:**
```bash
podman exec -it nextcloudapp bash
vi /var/www/html/config/config.php
```

Добавьте (найдите конец массива конфигурации):
```php
'memcache.local' => '\\OC\\Memcache\\Redis',
'redis' => [
    'host' => '127.0.0.1',
    'port' => 6379,
],
```

Сохраните и перезапустите Nextcloud:
```bash
systemctl --user restart nextcloud-app.container
```

### 8.2. Ollama + Open WebUI (локальные LLM модели)

Ollama позволяет запускать LLM (например, Phi, Llama) локально.

**На сервере** создайте quadlet для Ollama:

```bash
vim ~/.config/containers/systemd/container-ollama.container
```

```ini
[Unit]
Description=Ollama LLM Server
After=network.target

[Container]
Image=docker.io/ollama/ollama:latest
ContainerName=ollama
PublishPort=11434:11434
Volume=/srv/ollama:/root/.ollama
Environment=OLLAMA_HOST=0.0.0.0:11434

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**На сервере** запустите:
```bash
systemctl --user daemon-reload
systemctl --user start container-ollama.service
```

#### Запуск моделей

**Способ 1: Через CLI (интерактивный чат)**

**На сервере:**
```bash
podman exec -it ollama ollama run phi
```

Тогда можно писать промпты и получать ответы.

**Способ 2: Через REST API**

**На любом компьютере в сети:**
```bash
curl http://192.168.1.100:11434/api/generate -d '{
  "model": "phi",
  "prompt": "Explain quantum computing"
}'
```

**Способ 3: Через Web UI (Open WebUI)**

**На сервере** создайте quadlet для Open WebUI:

```bash
vim ~/.config/containers/systemd/container-openwebui.container
```

```ini
[Unit]
Description=Open WebUI for Ollama
After=network.target ollama.container
Requires=container-ollama.service

[Container]
Image=docker.io/ghcr.io/open-webui/open-webui:latest
ContainerName=open-webui
PublishPort=8888:8080
Volume=/srv/open-webui:/app/backend/data
Environment=OLLAMA_API_BASE_URL=http://127.0.0.1:11434/api
Environment=OLLAMA_BASE_URL=http://ollama:11434
Network=host

[Service]
Restart=always

[Install]
WantedBy=default.target
```

#### 8.1.3. UFW и доступ
```bash
sudo ufw allow 11434/tcp comment "Ollama"
sudo ufw allow 8888/tcp comment "Open WebUI"
```

**На сервере** запустите:
```bash
systemctl --user daemon-reload
systemctl --user start container-openwebui.service
```

**Доступ:** На любом компьютере откройте `http://192.168.1.100:8888`

**Плюсы Open WebUI:**
- Красивый интерфейс как ChatGPT
- Управление моделями
- История чатов
- Возможность загружать свои модели

**Первый запуск моделей:**

**На сервере** скачайте модель:
```bash
podman exec -it ollama ollama pull phi
# или
podman exec -it ollama ollama pull llama2
```

Процесс может занять время (зависит от размера модели, Phi ~3 ГБ).

**Настройка прокси через NPM:**

1. В NPM: **Add Proxy Host**
2. **Domain:** `ollama-ui.internal`
3. **Forward:** `127.0.0.1:8888`
4. **SSL:** Internal Wildcard Cert
5. **Save**

Доступ: `https://ollama-ui.internal`

### 8.3. Gitea (локальный Git сервер)

Для хранения кода локально.

#### Quadlet для Gitea

**На сервере:**
```bash
vim ~/.config/containers/systemd/gitea.container
```

```ini
[Unit]
Description=Gitea Git Server
After=network.target

[Container]
Image=docker.io/gitea/gitea:latest
ContainerName=gitea
PublishPort=3000:3000
PublishPort=2222:22
Volume=/srv/gitea:/data

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**На сервере** запустите:
```bash
systemctl --user daemon-reload
systemctl --user start gitea.container
```

**Доступ:** На любом компьютере откройте `http://192.168.1.100:3000`

**Настройка прокси через NPM:**

1. В NPM: **Add Proxy Host**
2. **Domain:** `git.internal`
3. **Forward:** `127.0.0.1:3000`
4. **SSL:** Internal Wildcard Cert
5. **Save**

Доступ: `https://git.internal`

---

## Приложения

### Приложение A: Проверка логов и отладка

#### Логи контейнера

**На сервере** через systemd:
```bash
systemctl --user status jellyfin.container
journalctl --user -u jellyfin.container -f  # Live логи
```

**На сервере** через podman:
```bash
podman logs jellyfin -f  # -f для live вывода
```

#### Вход в контейнер

**На сервере:**
```bash
podman exec -it jellyfin bash
```

Теперь вы находитесь внутри контейнера и можете выполнять команды.

#### Перезапуск сервиса

**На сервере:**
```bash
systemctl --user restart jellyfin.container
```

#### Просмотр использования ресурсов

**На сервере:**
```bash
podman stats jellyfin
```

Показывает CPU, RAM, сеть в реальном времени.

### Приложение B: Обновление образов контейнеров

**На сервере** обновите образ вручную:

```bash
# 1. Остановить контейнер
systemctl --user stop jellyfin.container

# 2. Скачать новый образ
podman pull docker.io/jellyfin/jellyfin:latest

# 3. Перезагрузить systemd (он пересоздаст контейнер)
systemctl --user daemon-reload

# 4. Запустить контейнер (будет использован новый образ)
systemctl --user start jellyfin.container

# 5. Проверка
systemctl --user status jellyfin.container
```

**На сервере** удаление старых образов:
```bash
podman image prune  # Удалит неиспользуемые образы
podman image prune -a  # Удалит ВСЕ образы (осторожно!)
```

### Приложение C: 2FA для SSH через Google Authenticator

Дополнительная защита SSH через TOTP (Time-based One-Time Password).

#### Установка

**На сервере:**
```bash
sudo apt install -y libpam-google-authenticator
```

#### Настройка для пользователя

**На сервере:**
```bash
google-authenticator
```

Ответьте на вопросы:
- **Do you want authentication tokens to be time-based?** y (для TOTP)
- **Scan QR code** — отсканируйте QR в Google Authenticator, Authy, Microsoft Authenticator и т.д.
- **Update the ~/.google_authenticator file?** y
- **Do you want to disallow multiple uses of the same authentication token?** y
- **By default, a new token is generated every 30 seconds...** (можно оставить по умолчанию, нажать Enter)
- **If the computer that you are logging into does not have the current time, beware!** y (для синхронизации времени)
- **Do you want to enable rate-limiting?** y (для защиты от брутфорса)

Будет выведено 5 резервных кодов — **сохраните их в безопасном месте!** Они позволят войти если потеряете доступ к приложению.

#### Включение в PAM для SSH

**На сервере:**
```bash
sudo vim /etc/pam.d/sshd
```

Добавьте в начало файла:
```
auth required pam_google_authenticator.so
```

Сохраните.

#### Настройка sshd_config

**На сервере:**
```bash
sudo vim /etc/ssh/sshd_config
```

Найдите и измените:
```
ChallengeResponseAuthentication yes
```

Добавьте (если нет):
```
AuthenticationMethods publickey,keyboard-interactive
```

Сохраните.

#### Перезагрузка SSH

**На сервере:**
```bash
sudo systemctl restart sshd
```

#### Проверка

**На локальном компьютере** попробуйте подключиться:
```bash
ssh -i ~/.ssh/homeserver_key tuchnyak@192.168.1.100
```

При входе появится запрос:
```
Verification code: _
```

Введите 6-значный код из приложения на телефоне, нажмите Enter.

Если вошли — 2FA работает!

#### Отключение 2FA

Если 2FA больше не нужна, на сервере:

```bash
# 1. Удалить файл 2FA
rm ~/.google_authenticator

# 2. Отключить в PAM
sudo vim /etc/pam.d/sshd
# Удалить строку: auth required pam_google_authenticator.so

# 3. Отключить в sshd_config
sudo vim /etc/ssh/sshd_config
# Измените обратно: ChallengeResponseAuthentication no

# 4. Перезагрузить SSH
sudo systemctl restart sshd
```

### Приложение D: Шпаргалка по командам

#### systemd (управление сервисами)

**На сервере:**
```bash
# Перезагрузка конфигурации
systemctl --user daemon-reload

# Запуск сервиса
systemctl --user start <service>.container

# Остановка сервиса
systemctl --user stop <service>.container

# Перезапуск сервиса
systemctl --user restart <service>.container

# Включить автозапуск
systemctl --user enable <service>.container

# Отключить автозапуск
systemctl --user disable <service>.container

# Статус сервиса
systemctl --user status <service>.container

# Логи
journalctl --user -u <service>.container -f

# Все сервисы пользователя
systemctl --user list-units --type=service
```

#### Podman (управление контейнерами)

**На сервере:**
```bash
# Список запущенных контейнеров
podman ps

# Все контейнеры (включая остановленные)
podman ps -a

# Логи контейнера (live)
podman logs <container_name> -f

# Вход в контейнер
podman exec -it <container_name> bash

# Остановка контейнера
podman stop <container_name>

# Запуск контейнера
podman start <container_name>

# Удаление контейнера
podman rm <container_name>

# Скачать образ
podman pull <image_name>

# Список образов
podman images

# Удалить образ
podman rmi <image_id>

# Статистика ресурсов
podman stats
```

#### Сеть

**На сервере:**
```bash
# Показать все интерфейсы и IP адреса
ip a

# Показать только IPv4
ip -4 a

# Показать маршруты (default gateway и т.д.)
ip route

# Показать ARP таблицу (IP → MAC соответствия)
ip neigh

# Проверка связи
ping google.com -c 4

# Проверка открытых портов
sudo ss -tulpn | grep LISTEN
sudo lsof -i :<port>

# Посмотреть DNS серверы
cat /etc/resolv.conf

# Переподключить интерфейс
sudo ip link set <interface> down
sudo ip link set <interface> up
```

### Приложение E: Понимание вывода команды `ip a`

Команда `ip address show` (сокращённо `ip a`) показывает все сетевые интерфейсы и назначенные им IP адреса на сервере.

#### Пример вывода

```bash
$ ip a

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever

2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:e4:e2:a1 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.100/24 scope global dynamic eth0
       valid_lft 3599sec preferred_lft 3599sec
    inet6 fe80::a00:27ff:fee4:e2a1/64 scope link
       valid_lft forever preferred_lft forever

3: wlo1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether d8:5d:e2:8f:c1:9a brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.101/24 scope global dynamic wlo1
       valid_lft 7199sec preferred_lft 7199sec
    inet6 fe80::da5d:e2ff:fe8f:c19a/64 scope link
       valid_lft forever preferred_lft forever
```

#### Разбор каждой строки

**Номер интерфейса и имя:**
```
1: lo:
2: eth0:
3: wlo1:
```
- `1, 2, 3` — порядковый номер интерфейса в системе
- `lo` — **loopback** (виртуальный интерфейс для localhost)
- `eth0` — **Ethernet** (проводное подключение)
- `wlo1` — **Wireless** (Wi-Fi адаптер)

**Статус интерфейса:**
```
<BROADCAST,MULTICAST,UP,LOWER_UP>
```
- `UP` — интерфейс включен
- `DOWN` — интерфейс выключен
- `LOWER_UP` — физический уровень в порядке (кабель/Wi-Fi есть)
- `UP,LOWER_UP` = интерфейс работает ✅
- `UP` (без LOWER_UP) = нет физической связи ❌

**MAC адрес:**
```
link/ether 08:00:27:e4:e2:a1
```
- Физический адрес адаптера
- Формат: `XX:XX:XX:XX:XX:XX` (6 пар шестнадцатеричных цифр)

**IPv4 адрес:**
```
inet 192.168.1.100/24 scope global dynamic eth0
```
- `192.168.1.100` — IP адрес
- `/24` — CIDR нотация (маска подсети, эквивалент 255.255.255.0)
- `dynamic` — адрес получен от DHCP
- `static` — адрес установлен вручную
- `scope global` — видна всей сети
- `scope host` — видна только на этом компьютере

**Время жизни:**
```
valid_lft 3599sec preferred_lft 3599sec
```
- `valid_lft` — сколько секунд адрес ещё действителен (для DHCP)
- `forever` — адрес не имеет срока действия

#### Практические примеры

**Найти активный интерфейс:**
```bash
ip a | grep "state UP"
```

**Найти только IPv4 адреса:**
```bash
ip a | grep "inet " | grep -v "127.0.0.1"
```

**Проверить есть ли интернет:**
```bash
ip a | grep "state UP" | grep -v "lo:"
```

Если ничего не вывелось — нет активного подключения.

**Найти MAC адрес адаптера:**
```bash
ip a show eth0 | grep "link/ether"
```

**Найти IP роутера (шлюз):**
```bash
ip route | grep default
```

#### Таблица интерпретации статусов

| Статус | Что означает | Действие |
|--------|-------------|----------|
| `UP,LOWER_UP` | ✅ Работает | Нормально, всё OK |
| `UP` (нет LOWER_UP) | ⚠️ Включен, но нет связи | Проверь кабель/Wi-Fi |
| `DOWN` | ❌ Отключен | `sudo ip link set eth0 up` |
| `dynamic` (IP) | 📶 IP от DHCP | Может измениться |
| `static` (IP) | 🔒 Постоянный IP | Установлен вручную |

---

## Заключение

Поздравляю! Вы успешно развернули полнофункциональный домашний сервер с:

✅ **Ubuntu Server 24.04 LTS** с Btrfs и автоматическими снапшотами  
✅ **Безопасность:** SSH по ключам (ED25519), UFW, fail2ban  
✅ **Podman контейнеры** с systemd quadlets для автозапуска (rootless)  
✅ **Nginx Proxy Manager** с HTTPS для .internal доменов  
✅ **Nextcloud** (личное облако)  
✅ **PostgreSQL** (база данных)  
✅ **Jellyfin** (медиасервер)  
✅ **qBittorrent** (торрент-клиент)  
✅ **Syncthing** (синхронизация файлов)  
✅ **AdGuard Home** (DNS и блокировка рекламы)  
✅ **Samba** (файловый доступ из Windows/macOS)  
✅ **Cockpit** (веб-интерфейс для управления)  
✅ **Redis** (кэширование для Nextcloud)  
✅ **Ollama + Open WebUI** (локальные LLM модели)  
✅ **Gitea** (локальный Git сервер)  
✅ **Резервное копирование** (rsync, Btrfs send/receive, Borg)  
✅ **Kamal** для деплоя собственных приложений  

Ваш сервер готов к работе и легко расширяется!

### Следующие шаги

- Добавьте медиафайлы в Jellyfin (через Samba шару Media)
- Настройте синхронизацию в Syncthing с вашими устройствами
- Загрузите файлы в Nextcloud
- Разверните свои приложения через Kamal
- Настройте автоматическое резервное копирование

### Обслуживание

- **Еженедельно:** Проверяйте обновления: `sudo apt update && sudo apt list --upgradable`
- **Раз в 2 недели:** Делайте: `sudo apt upgrade -y`
- **Ежемесячно:** Проверяйте бэкапы (делайте тестовое восстановление)
- **Постоянно:** Мониторьте логи через Cockpit

### Важные команды для памяти

**На сервере:**
- `systemctl --user status` — статус всех сервисов
- `podman ps` — список контейнеров
- `journalctl --user -f` — живые логи
- `ip a` — сетевые интерфейсы
- `sudo snapper list` — снапшоты

### Безопасность

- ✅ SSH ключи включены (пароли отключены)
- ✅ UFW firewall активен
- ✅ fail2ban защищает от брутфорса
- ✅ Btrfs снапшоты защищают от ошибок
- ✅ Резервные копии защищают от потери данных
- ✅ Rootless Podman контейнеры (без root прав)

---

**Документ подготовлен:** Ноябрь 2025  
**Версия:** 2.1 (Production Ready, полная версия)  
**Статус:** Готов к выполнению ✅
