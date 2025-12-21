# План по установке и настройке домашнего сервера на Ubuntu Server

**Версия:** 0.9.1
**Дата:** Декабрь 2025  

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

☐ Что мы будем строить?
☐ Что нужно знать заранее
☐ Необходимое оборудование
☐ Скачивание Ubuntu Server
☐ Создание загрузочного USB
☐ Подготовка сервера к установке
☐ Что мы планируем в итоге получить

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

### 1.4. Обновление системы

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

### 1.5. Установка базовых утилит

**Критически важно:** Установите базовые утилиты до настройки сетевых параметров. Они нужны для последующих операций.

**На сервере:**
```bash
sudo apt install -y vim iputils-ping git curl wget htop top net-tools tree lsof
```

**Что установили:**
- `vim` — текстовый редактор (альтернатива nano)
- `iputils-ping` — утилита ping (для проверки сетевых соединений)
- `git` — система контроля версий
- `curl`, `wget` — утилиты для скачивания файлов
- `htop`, `top` — мониторы процессов (интерактивный и текстовый)
- `net-tools` — классические сетевые утилиты (ifconfig, netstat)
- `tree` — отображение дерева каталогов
- `lsof` — список открытых файлов и портов

Эти утилиты критичны для диагностики и работы с сервером на следующих этапах.

### 1.6. Настройка сети (Ethernet или Wi-Fi со статическим IP)

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

### 1.7. Подключение по SSH с другого компьютера

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

### 1.9. Настройка Swap и ZRAM

У вас 16 ГБ RAM, но некоторые сервисы (Nextcloud, Jellyfin, LLM модели) могут потреблять много памяти. Swap защищает от OOM Killer (Out Of Memory Killer), который убивает процессы при нехватке RAM.

#### Решение для Btrfs + Snapper + Swap

**Проблема:** Swap-файл на рутовом томе Btrfs конфликтует с CoW (Copy-on-Write) и Snapper, что приводит к ошибке `swapon failed: invalid argument`.

**Решение:** Создание отдельного подтома `@swap` на top-level 5 для изоляции swap-файла.

**Шаг 1: Создание подтома @swap**

**На сервере:**
```bash
sudo btrfs subvolume create /@swap
```

**Шаг 2: Подготовка точки монтирования**

```bash
sudo mkdir -p /swap
```

**Шаг 3: Добавление в fstab для монтирования**

```bash
echo "UUID=$(sudo blkid -s UUID -o value /dev/nvme0n1p2) /@swap btrfs noatime,nodiscard,subvol=@swap 0 0" | sudo tee -a /etc/fstab
```

Замените `/dev/nvme0n1p2` на ваш корневой раздел Btrfs (узнайте через `lsblk`)

**Шаг 4: Монтирование подтома**

```bash
sudo mount /swap
```

**Проверка монтирования:**
```bash
mount | grep swap
```

Должен показать монтирование подтома `@swap` на `/swap`.

**Шаг 5: Отключение CoW для подтома**

Copy-on-Write конфликтует со swap-файлом, поэтому отключим его:

```bash
sudo chattr +C /swap
```

**Шаг 6: Создание swap-файла**

Создадим 8 ГБ swap-файл:

```bash
sudo dd if=/dev/zero of=/swap/swapfile bs=1M count=8192 status=progress
```

**Шаг 7: Установка прав доступа**

```bash
sudo chmod 600 /swap/swapfile
```

**Шаг 8: Инициализация swap**

```bash
sudo mkswap /swap/swapfile
sudo swapon /swap/swapfile
```

**Шаг 9: Проверка active swap**

```bash
sudo swapon --show
free -h
```

Вы должны увидеть swap файл размером 8 ГБ.

**Шаг 10: Добавление в fstab для автозагрузки**

```bash
echo "/swap/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
```

**Шаг 11: Проверка безопасности конфигурации**

Убедитесь что `@swap` находится на top-level 5 (вне рутового подтома):

```bash
sudo btrfs subvolume list /
```

Ищите строку с `/@swap` — ID должна быть отличающимся от остальных (обычно 5+).

Snapper конфиг НЕ требует изменений — исключения добавлять не нужно.

#### ZRAM (сжатый swap в памяти)

ZRAM — это виртуальный диск в оперативной памяти со сжатием. Быстрее чем swap на диске, но использует часть RAM.

**Преимущество:** Меньше износ SSD, быстрее работает.

**Можно использовать оба метода вместе:** ZRAM для быстрого swap, и swap-файл как резервный.

**На сервере:**
```bash
sudo apt install -y zram-tools
```

**Настройка ZRAM:**

```bash
sudo vim /etc/default/zramswap
```

Установите:
```
ALGO=zstd
PERCENT=20
```

**Объяснение:**
- `ALGO=zstd` — алгоритм сжатия (zstd более производителен)
- `PERCENT=20` — ZRAM размером 20% от RAM (рекомендуется, чтобы не переусложнить)
  - На 16 ГБ RAM это будет 3.2 ГБ ZRAM

Перезагрузите ZRAM:
```bash
sudo systemctl restart zramswap.service
```

**Проверка:**

```bash
free -h
```

Вы должны увидеть:
- `Mem:` 16G (физическая память)
- `Swap:` 11.2G (сумма ZRAM 3.2G + swapfile 8G)

После настройки swap будет показываться как сумма swapfile + zram.

### 1.10. Чек-лист Главы 1

☐ Ubuntu Server 24.04 LTS установлен  
☐ Btrfs файловая система настроена  
☐ Система обновлена (apt update && apt upgrade)  
☐ Базовые утилиты установлены  
☐ Сеть работает (Ethernet или Wi-Fi)  
☐ Статический IP адрес назначен  
☐ SSH подключение работает  
☐ Snapper настроен для автоматических снапшотов  
☐ Swap-файл на отдельном подтоме @swap настроен  
☐ ZRAM (20%) настроен

---

## Глава 2: Безопасность и удаленный доступ

Безопасность — критически важна для домашнего сервера. В этой главе мы настроим:
- SSH доступ только по ключам (без паролей)
- UFW firewall для фильтрации трафика
- fail2ban для защиты от брутфорс атак

В приложениях есть описание настройки 2FA.

### 2.1. SSH с публичными ключами (без паролей)

Пароли можно подобрать брутфорсом. Ключи — нельзя (при достаточной длине).

#### Генерация SSH ключей на вашем локальном компьютере

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

#### Копирование публичного ключа на сервер

**На локальном компьютере:**
```bash
ssh-copy-id -i ~/.ssh/homeserver_key.pub tuchnyak@192.168.1.100
```

Введите пароль вашего пользователя на сервере (последний раз!).

Команда скопирует ваш публичный ключ в `~/.ssh/authorized_keys` на сервере.

**Если ssh-copy-id не работает (например, на Windows):**
```bash
cat ~/.ssh/homeserver_key.pub | ssh tuchnyak@192.168.1.100 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

#### Проверка входа по ключу

**На локальном компьютере попробуйте подключиться:**
```bash
ssh -i ~/.ssh/homeserver_key tuchnyak@192.168.1.100
```

Теперь вход должен происходить БЕЗ запроса пароля (или с запросом passphrase для ключа, если вы его установили).

Если работает — отлично!

#### Удобство: Добавление конфига SSH

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

#### Отключение входа по паролю на сервере

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

#### Установка и базовые правила

**На сервере** установите политики по умолчанию (запретить входящие, разрешить исходящие):
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

#### Создание резервных копий конфигурации

```bash
sudo cp /etc/ufw/before.rules /etc/ufw/before.rules.bak
sudo cp /etc/ufw/after.rules /etc/ufw/after.rules.bak
sudo cp /etc/default/ufw /etc/default/ufw.bak
```

#### Разрешение необходимых сервисов

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

#### Включение UFW

**На сервере:**
```bash
sudo ufw enable
```

Появится предупреждение о возможном разрыве SSH соединения. Если вы разрешили SSH выше — всё нормально, нажмите `y` и Enter.

#### Проверка статуса

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

#### Установка

**На сервере:**
```bash
sudo apt install -y fail2ban
```

#### Конфигурация SSH protection

fail2ban использует файл `jail.conf` для настроек. Мы НЕ редактируем его напрямую, а создаём локальный файл.

**На сервере:**
```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

Редактируем локальный файл:
```bash
sudo vim /etc/fail2ban/jail.local
```

Найдите секцию `[sshd]` и убедитесь что:
```ini
[sshd]
enabled = true
```

**Добавьте для systemd-journald (современный способ логирования):**

Найдите строку с `logpath` и `backend` в секции `[sshd]`, добавьте/измените:
```ini
[sshd]
enabled = true
backend = systemd
logpath = systemd-journal
```

Это позволит fail2ban работать с systemd-journald вместо файловых логов.

#### Запуск fail2ban

**На сервере:**
```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo systemctl status fail2ban
```

Статус должен быть `active (running)`.

#### Проверка работы

```bash
sudo fail2ban-client status
```

Должны увидеть активные jail'ы:
```
Status
|- Number of jail:      1
`- Jail list:           sshd
```

### 2.4. Изменение SSH порта (опционально, для параноиков)

Порт 22 для SSH известен всем. Можно сменить на нестандартный (например, 2222) для защиты от массовых сканеров.

**Внимание:** Это необязательно, но добавляет слой безопасности через obscurity.

#### Резервная копия конфигурации SSH

**На сервере:**
```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak_before_port_change
```

#### Изменение порта в конфигурации SSH

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

#### Разрешение нового порта в UFW

**На сервере:**
```bash
sudo ufw allow 2222/tcp
sudo ufw reload
```

#### Перезагрузка SSH сервиса

**На сервере:**
```bash
sudo systemctl restart sshd
```

#### Проверка подключения на новом порту

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

☐ SSH ключи сгенерированы  
☐ Публичный ключ скопирован на сервер  
☐ Вход по ключу работает  
☐ Вход по паролю отключен  
☐ UFW установлен и включен  
☐ SSH, HTTP, HTTPS разрешены в UFW  
☐ fail2ban установлен и работает  
☐ fail2ban настроен на systemd-journald  
☐ (Опционально) SSH порт изменен на 2222

---

## Глава 3: Фундамент для сервисов

В этой главе подготовим систему для контейнеризированных сервисов:
- Создадим каталоги для хранения данных сервисов
- Установим Podman (контейнеризация)
- Настроим systemd quadlets для автозапуска
- (Опционально) Установим инструменты для мониторинга и удобства

### 3.1. Создание структуры /srv для данных сервисов

Все данные наших сервисов будут в `/srv` для лёгкого бэкапирования и управления.

**На сервере:**
```bash
# Создание основного каталога
sudo mkdir -p /srv

# Создание подкаталогов для каждого сервиса
sudo mkdir -p /srv/nextcloud/db
sudo mkdir -p /srv/nextcloud/html
sudo mkdir -p /srv/jellyfin/config
sudo mkdir -p /srv/jellyfin/media
sudo mkdir -p /srv/qbittorrent/config
sudo mkdir -p /srv/qbittorrent/downloads
sudo mkdir -p /srv/syncthing/config
sudo mkdir -p /srv/syncthing/data
sudo mkdir -p /srv/ollama
sudo mkdir -p /srv/open-webui
sudo mkdir -p /srv/gitea
sudo mkdir -p /srv/backups

# Установка прав доступа
# Сменяем владельца на вашего пользователя
sudo chown -R $(whoami):$(whoami) /srv

# Установка прав доступа (755 для каталогов)
sudo chmod -R 755 /srv
```

**Проверка:**
```bash
ls -la /srv
whoami
```

Вы должны быть владельцем всех каталогов в `/srv`.

### 3.2. Установка Podman

Podman — это аналог Docker, но rootless (работает без прав root), что безопаснее.

**На сервере:**
```bash
sudo apt install -y podman podman-docker
```

- `podman` — основной пакет контейнеризации
- `podman-docker` — совместимость с Docker командами (нужно для Kamal)

**Проверка:**
```bash
podman --version
```

Должна показать версию Podman (например, `podman version 4.3.1`).

### 3.3. Настройка rootless режима для Podman

**КРИТИЧЕСКИ ВАЖНО!**

Для того чтобы пользовательские systemd сервисы (и контейнеры через systemd quadlets) запускались при загрузке системы **БЕЗ** входа пользователя, нужно включить **linger**:

**На сервере:**
```bash
# Включение лингерного режима (автозапуск сервисов пользователя при загрузке)
sudo loginctl enable-linger $(whoami)

# Проверка
sudo loginctl show-user $(whoami)
```

Должна быть строка: `Linger=yes`

Теперь вы сможете запускать контейнеры без `sudo`:
```bash
podman ps
```

### 3.4. (Опционально) Установка Cockpit для веб-интерфейса управления

Cockpit — веб-интерфейс для управления сервером (очень удобно!).

**На сервере:**
```bash
sudo apt install -y cockpit cockpit-podman
```

**Включение и запуск:**
```bash
sudo systemctl enable --now cockpit.socket
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

**Первый вход:**
- Username: ваш username (например, tuchnyak)
- Password: ваш пароль на сервере

**Что можно делать в Cockpit:**
- Просмотр использования CPU, RAM, диска
- Управление сервисами и контейнерами
- Просмотр логов
- Файловый менеджер
- Установка обновлений
- Перезагрузка системы

### 3.5. (Опционально) Установка Zellij для удобного терминала

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
Внутри Zellij:
- `Alt+n` — новая вкладка
- `Alt+←/→` — переключение вкладок
- `Alt+↓` — разделить окно горизонтально
- `Alt+→` — разделить окно вертикально
- `Alt+x` — закрыть окно
- `Alt+Esc` — выход

### 3.6. (Опционально) Настройка Vim для удобства

Многие любят настроить Vim под себя. Вот базовая конфигурация.

**На сервере:**
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

☐ Каталоги `/srv/*` созданы  
☐ Права доступа на `/srv` проверены  
☐ Podman установлен  
☐ podman-docker установлен (для Kamal)  
☐ Linger включён для пользователя (loginctl show-user)  
☐ (Опционально) Cockpit установлен и доступен на :9090  
☐ (Опционально) Zellij установлен  
☐ (Опционально) Vim настроен

---

## Глава 4: Файловый доступ

В этой главе мы настроим:
- Samba для доступа к файлам из Windows/macOS

### 4.1. Развертывание Samba для файлового доступа

Samba позволяет получить доступ к файлам на сервере из Windows, macOS и Linux.

#### Установка Samba

**На сервере:**
```bash
sudo apt install -y samba samba-common-bin
```

#### Создание каталогов для шар

**На сервере:**
```bash
mkdir -p /srv/Media
mkdir -p /srv/Sync
mkdir -p /srv/Backups

# Установка прав доступа
chmod 755 /srv/Media
chmod 755 /srv/Sync
chmod 755 /srv/Backups
```

#### Конфигурация Samba

Резервная копия:
```bash
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
```

Редактирование конфигурации:
```bash
sudo vim /etc/samba/smb.conf
```

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

#### Добавление пользователя Samba

Samba использует отдельную базу пользователей.

**На сервере:**
```bash
sudo smbpasswd -a tuchnyak
```

Введите пароль для доступа к Samba шарам.

#### Запуск и включение Samba

**На сервере:**
```bash
sudo systemctl restart smbd
sudo systemctl restart nmbd
```

- `smbd` — основной сервис SMB (File Sharing)
- `nmbd` — NetBIOS для отображения в сетевом окружении

**Проверка:**
```bash
sudo systemctl status smbd
```

#### UFW: Открытие портов для Samba

Samba использует порты 137, 138 (UDP) и 139, 445 (TCP).

**На сервере:**
```bash
sudo ufw allow from 192.168.1.0/24 to any port 137
sudo ufw allow from 192.168.1.0/24 to any port 138
sudo ufw allow from 192.168.1.0/24 to any port 139
sudo ufw allow from 192.168.1.0/24 to any port 445
sudo ufw reload
```

**Объяснение:** `from 192.168.1.0/24` разрешает доступ только из сети 192.168.1.0-255 (маска /24 означает это подсеть из 256 адресов). Измените на вашу подсеть если нужно.

**Проверка:**
```bash
sudo ufw status verbose | grep -E "137|138|139|445"
```

#### Подключение к Samba шарам

**Из Windows:**
1. Откройте "Этот компьютер" → "Подключить сетевой диск"
2. Папка: `\\192.168.1.100\Media` (или Sync, Backups)
3. Нажмите "Обзор" и выберите папку
4. Отметьте "Подключать при входе"
5. Нажмите Готово
6. Введите username `tuchnyak` и пароль от Samba

**Из macOS:**
1. Finder → Go → Connect to Server (Cmd+K)
2. Адрес: `smb://192.168.1.100/Media`
3. Нажмите Connect
4. Введите username и пароль

**Из Linux:**
```bash
# Установка инструментов
sudo apt install -y cifs-utils

# Подключение
sudo mount -t cifs //192.168.1.100/Media /mnt/media -o username=tuchnyak

# Просмотр подключенных шар
mount | grep cifs
```

### 4.2. Чек-лист Главы 4
☐ Samba установлена  
☐ Конфигурация Samba отредактирована  
☐ Пользователь Samba добавлен (smbpasswd)  
☐ Samba сервис запущен и включён  
☐ Порты Samba открыты в UFW  
☐ Подключение к Samba шарам протестировано

-
--

## Глава 5: Развертывание основных сервисов

В этой главе развернём основные сервисы:
- Nextcloud (личное облако)
- Jellyfin (медиасервер)
- qBittorrent (торрент-клиент)
- Syncthing (синхронизация файлов)

Для каждого сервиса:
1. Создаём quadlet файл (конфигурация)
2. Запускаем через systemd
3. Открываем необходимые порты в UFW

### 5.1. Подготовка конфигурации systemd quadlets

systemd quadlets — это способ управления контейнерами через systemd без docker-compose.

**На сервере:**
```bash
# Создание каталога для quadlet файлов
mkdir -p ~/.config/containers/systemd

# Проверка пути
ls -la ~/.config/containers/systemd
```

**Что это:** Systemd quadlets — это файлы конфигурации (расширение `.container`, `.volume`, `.pod`), которые systemd автоматически преобразует в systemd unit файлы.

**Начальный пример quadlet файла** (используется для всех сервисов в дальнейшем):

```ini
[Unit]
Description=My Service
After=network.target

[Container]
Image=docker.io/myimage:latest
ContainerName=myservice
PublishPort=8080:8080
Volume=/srv/myservice:/data

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**Объяснение:**
- `[Unit]` — метаданные сервиса
- `[Container]` — конфигурация контейнера
- `[Service]` — поведение systemd
- `[Install]` — автозапуск при загрузке

**Важно:** Quadlet файлы должны быть именованы так: `container-<NAME>.container` или `pod-<NAME>.pod`

Управление:
```bash
# Перечитать конфигурацию systemd
systemctl --user daemon-reload

# Запустить сервис
systemctl --user start container-<NAME>.service

# Включить автозапуск
systemctl --user enable container-<NAME>.service

# Статус
systemctl --user status container-<NAME>.service

# Логи
journalctl --user -f -u container-<NAME>.service
```

### 5.2. Nextcloud (личное облако)

Nextcloud — замена Google Drive, хранилище файлов с веб-интерфейсом и мобильным приложением.

### 5.3. PostgreSQL (база данных для Nextcloud)

#### Создание переменных окружения

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

#### Создание quadlet для PostgreSQL

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
Network=nextcloud-net

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**Примечание:** `%h` в systemd означает домашнюю директорию пользователя (`/home/tuchnyak`).

**На сервере запустите:**
```bash
podman network create nextcloud-net
systemctl --user daemon-reload
systemctl --user start container-nextclouddb.service
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

### 5.4. Nextcloud (личное облако)

#### Создание quadlet для Nextcloud

**На сервере:**
```bash
vim ~/.config/containers/systemd/container-nextcloudapp.container
```

```ini
[Unit]
Description=Nextcloud Application
After=network.target container-nextclouddb.service
Requires=container-nextclouddb.service

[Container]
Image=docker.io/nextcloud:latest
ContainerName=nextcloudapp
PublishPort=8180:80
Volume=/srv/nextcloud/html:/var/www/html
Environment=POSTGRES_HOST=nextclouddb
Environment=POSTGRES_PORT=5432
EnvironmentFile=%h/compose/nextcloud.env
Network=nextcloud-net

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
systemctl --user start container-nextcloudapp.service
sudo ufw allow 8180/tcp comment "Nextcloud"
```

#### Первоначальная настройка Nextcloud

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

### 5.5. Jellyfin (медиасервер)

#### Создание quadlet для Jellyfin

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
#sudo ufw allow from 192.168.1.0/16 to any port 8920/tcp comment "Jellyfin HTTPS"
```

#### Первоначальная настройка Jellyfin

На любом компьютере откройте браузер: `http://192.168.1.100:8096`

Пройдите мастер настройки:
1. Выберите язык
2. Создайте пользователя (admin)
3. **Add Media Library:**
- **Type:** Movies (или другое)
- **Folders:** `/media` (путь внутри контейнера)
4. Завершите настройку

#### Добавление медиафайлов

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

### 5.6. qBittorrent (торрент-клиент)

#### Создание quadlet для qBittorrent

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

#### Первоначальная настройка qBittorrent

На любом компьютере откройте: `http://192.168.1.100:8090`

**Логин по умолчанию:**
- Username: `admin`
- Password: `adminadmin`

**Сразу измените пароль!**

Перейдите **Tools** → **Options** → **Web UI** и измените пароль.

##### Возможные проблемы
1. "Unauthorized" вместо окна логина.
```bash
sudo vim #TODO
```

#### Настройка каталога загрузки

**Tools** → **Options** → **Downloads:**
- **Default Save Path:** `/downloads` (внутри контейнера, соответствует `/srv/qbittorrent/downloads` на хосте)

Файлы будут сохраняться в `/srv/qbittorrent/downloads` на хосте.

### 5.7. Syncthing (синхронизация файлов)

#### Создание quadlet для Syncthing

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

#### Первоначальная настройка Syncthing

На любом компьютере откройте: `http://192.168.1.100:8384`

При первом запуске появится предупреждение о GUI доступе из внешней сети.

Настройте:
1. **Actions** → **Settings**
2. **GUI:**
- Установите **GUI Authentication** (username и пароль)
3. Добавьте папки для синхронизации

### 5.8. Несколько способов попробовать подступиться к разбору возможной проблемы.

**Контейнер не запускается:**
```bash
# Посмотреть логи
journalctl --user -f -u container-<NAME>.service

# Перезапустить
systemctl --user restart container-<NAME>.service
```

**Контейнер "падает" (crashed):**
```bash
# Посмотреть статус
podman ps -a | grep <NAME>

# Посмотреть логи контейнера
podman logs <container_id>
```

**Порт занят:**
```bash
# Проверить что слушает на порту
sudo lsof -i :<port_number>

# Остановить контейнер
systemctl --user stop container-<NAME>.service
```

### 5.9. Чек-лист Главы 5

☐ Nextcloud запущен и доступен на :8082  
☐ Jellyfin запущен и доступен на :8096  
☐ qBittorrent запущен и доступен на :8081  
☐ Syncthing запущен и доступен на :8384  
☐ Все порты открыты в UFW

---

## Глава 6: Стратегия резервного копирования

Резервные копии защищают от потери данных при сбое диска или ошибке.

### 6.1. Стратегия 3-2-1
В идеале следует стремиться к выполнении данной стратегии.
**Правило 3-2-1:**
- **3 копии** данных (оригинал + 2 бэкапа)
- **2 разных типа** носителя (диск + внешний диск)
- **1 копия в отдельном месте** (опционально, можно отступить)

**Наша реализация:**
- Копия 1: основной диск с Btrfs снапшотами
- Копия 2: внешний USB диск (еженедельный бэкап)
- Копия 3: опционально облако (например, Nextcloud или Google Drive)

### 6.2. Автоматические снапшоты Btrfs (уже настроены)

Snapper уже создаёт снапшоты каждый час и при каждом обновлении.

**Проверка:**
```bash
sudo snapper list
sudo snapper -c root list
sudo btrfs filesystem usage /
```

**Восстановление:**
```bash
sudo snapper -c root rollback <snapshot_number>
sudo reboot
```

### 6.3. Резервное копирование на внешний диск

Подключите внешний USB диск (500 ГБ-1 ТБ) для еженедельного бэкапа.

#### Подготовка внешнего диска

**На сервере подключите диск и проверьте:**
```bash
lsblk
```

Найдите ваш диск (обычно `/dev/sdb` или `/dev/sdc`).

**Форматирование (осторожно, данные будут удалены!):**
```bash
sudo mkfs.ext4 /dev/sdb1  # Замените на ваш раздел
```

**Создание точки монтирования:**
```bash
sudo mkdir -p /mnt/backup
sudo mount /dev/sdb1 /mnt/backup
```

**Проверка:**
```bash
mount | grep backup
```

#### Скрипт резервного копирования

**На сервере создайте скрипт:**
```bash
cat > ~/backup.sh << 'EOF'
#!/bin/bash
set -e

BACKUP_DIR="/mnt/backup"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Резервное копирование начато: $TIMESTAMP ==="

# Проверка что диск подключен
if ! mount | grep -q "$BACKUP_DIR"; then
    echo "Ошибка: $BACKUP_DIR не смонтирован"
    exit 1
fi

# Резервное копирование каталогов /srv
rsync -avz --delete /srv/ "$BACKUP_DIR/srv_backup_$DATE/"

echo "=== Резервное копирование завершено: $(date +%Y%m%d_%H%M%S) ==="
EOF

chmod +x ~/backup.sh
```
Флаги
- `-a` — архивный режим (сохраняет права, время и т.д.)
- `-v` — verbose (показывать процесс)
- `-z` — сжатие
- `--delete` — удалять файлы в назначении которых нет в источнике

Если копии по датам будут занимать много места, то можно откорректировать rsync:
```bash
rsync -avz --delete /srv/ /mnt/backup/srv/
```

**Запуск вручную:**
```bash
~/backup.sh
```

#### Автоматизация через cron

**Добавьте в crontab (еженедельный бэкап, по воскресеньям в 2:00 ночи):**

```bash
crontab -e
```

**Добавьте строку:**
```
0 2 * * 0 /home/tuchnyak/backup.sh >> /home/tuchnyak/backup.log 2>&1
```

**Проверка:**
```bash
crontab -l
```

### 6.4. Мониторинг резервных копий

**Просмотр размера бэкапа:**
```bash
du -sh /mnt/backup/
```

**Просмотр статуса последнего бэкапа:**
```bash
tail -20 ~/backup.log
```

### 6.5. Восстановление данных из бэкапа

**Если что-то удалено/повреждено в /srv:**
```bash
# Остановить контейнеры
systemctl --user stop container-*.service

# Восстановить из бэкапа
rsync -av /mnt/backup/srv_backup_<DATE>/ /srv/

# Перезапустить контейнеры
systemctl --user start container-*.service
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

### 6.6. Чек-лист Главы 6

☐ Внешний USB диск подготовлен  
☐ Диск смонтирован на `/mnt/backup`  
☐ Скрипт `backup.sh` создан  
☐ Скрипт резервного копирования протестирован  
☐ Cron задача добавлена для автоматического бэкапа  
☐ Логи бэкапа проверяются еженедельно

---

## Глава 7: Развертывание собственных приложений с помощью Kamal

Kamal — инструмент для развертывания Docker контейнеров на удалённых серверах.

**Примечание:** Это продвинутая тема для разработчиков. Если вы просто хотите использовать готовые сервисы — этот раздел можно пропустить.

### 7.1. Установка Kamal

**На локальном компьютере (не на сервере):**

**macOS:**
```bash
brew install kamal
```

**Linux:**
```bash
sudo apt install -y ruby-full
sudo gem install kamal
```

**Windows (WSL):**
```bash
curl -fsSL https://github.com/basecamp/kamal/releases/latest/download/kamal-x86_64-linux > kamal
chmod +x kamal
sudo mv kamal /usr/local/bin/
```

**Проверка:**
```bash
kamal version
```

### 7.2. Подготовка приложения

Ваше приложение должно быть в Docker контейнере.

**Требования:**
- Dockerfile в корне проекта
- Docker образ для вашего приложения
- Доступ к реестру контейнеров (Docker Hub, GitHub Container Registry и т.д.)

### 7.3. Конфигурация Kamal

В корне вашего проекта создайте `config/deploy.yml`:

```yaml
service: myapp
image: username/myapp:latest

servers:
  web:
    - 192.168.1.100

registry:
  server: docker.io
  username: username
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    DB_HOST: postgres
    REDIS_HOST: redis
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL

volumes:
  - "myapp_data:/data"
```
**На локальной машине** установите переменные окружения:

```bash
export KAMAL_REGISTRY_PASSWORD=your_docker_hub_password
export RAILS_MASTER_KEY=your_rails_master_key
```

### 7.4. Развертывание приложения

**На локальном компьютере:**

```bash
# Инициализация
kamal init

# Настройка серверов и конфигурации (отредактируйте config/deploy.yml)

# Развертывание
kamal deploy

# Проверка статуса
kamal app status

# Просмотр логов
kamal app logs

# Остановка
kamal app stop

# Удаление
kamal remove
```

**Примечание:** Более подробная документация Kamal доступна в официальном репозитории: https://github.com/basecamp/kamal

### 7.5. Чек-лист Главы 7

☐ Kamal установлен локально  
☐ Приложение завёрнуто в Docker контейнер  
☐ config/deploy.yml создан и настроен  
☐ Первое развертывание выполнено успешно  
☐ Логи приложения просматриваются

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

#### UFW и доступ
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

### 8.3. Gitea (локальный Git сервер)

Для хранения кода локально.

#### Quadlet для Gitea

**На сервере:**
```bash
vim ~/.config/containers/systemd/container-gitea.container
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
systemctl --user start container-gitea.service
```

**Доступ:** На любом компьютере откройте `http://192.168.1.100:3000`

### 8.4. Homeassistant (умный дом)

Home Assistant — платформа автоматизации для управления умным домом.

```bash
mkdir -p /srv/homeassistant

vim ~/.config/containers/systemd/container-homeassistant.container
```

**Содержимое:**
```ini
[Unit]
Description=Home Assistant
After=network.target

[Container]
Image=docker.io/homeassistant/home-assistant:latest
ContainerName=homeassistant
PublishPort=8123:8123
Volume=/srv/homeassistant:/config
Environment=TZ=UTC

[Service]
Restart=always

[Install]
WantedBy=default.target
```

**Запуск:**
```bash
systemctl --user daemon-reload
systemctl --user enable --now container-homeassistant.service
sudo ufw allow 8123/tcp comment "Home Assistant"
```

Доступ: `http://192.168.1.100:8123`

### 8.5. Важные команды для повседневного использования

```bash
# Контейнеры
podman ps                    # Список работающих контейнеров
podman ps -a                 # Все контейнеры (включая остановленные)
podman logs <container_id>   # Логи контейнера
podman exec -it <id> bash    # Войти в контейнер

# Systemd quadlets
systemctl --user status      # Статус всех сервисов
systemctl --user restart container-<name>.service  # Перезапуск
systemctl --user stop container-<name>.service     # Остановка
journalctl --user -f -u container-<name>.service  # Логи в реальном времени

# Система
sudo snapper list            # Список снапшотов
df -h                        # Использование диска
free -h                      # Использование памяти
sudo systemctl reboot        # Перезагрузка
```

### 8.6. Обновление контейнеров

Время от времени нужно обновлять образы контейнеров.

```bash
# Скачать новый образ
podman pull docker.io/image:latest

# Остановить контейнер
systemctl --user stop container-<name>.service

# Удалить старый контейнер
podman rm <container_id>

# Перезапустить (systemd создаст новый контейнер)
systemctl --user daemon-reload
systemctl --user start container-<name>.service
```

### 8.7. Чек-лист Главы 8

☐ Ollama установлен  
☐ Open WebUI установлен  
☐ Portainer установлен (опционально)  
☐ Home Assistant установлен (опционально)  
☐ Все порты открыты в UFW  
☐ Знаете основные команды управления контейнерами

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
✅ **Nextcloud** (личное облако)  
✅ **PostgreSQL** (база данных)  
✅ **Jellyfin** (медиасервер)  
✅ **qBittorrent** (торрент-клиент)  
✅ **Syncthing** (синхронизация файлов)  
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

