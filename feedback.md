# Установка ПО 
Перед настройкой статического адреса нужно переместить раздел установки базовых утилит.
vim, iputils, git, curl, wget, htop, top, net-tools, tree, lsof

# swapfile
При настройке свапфайла нужно учесть, что на руте у нас работает снаппер, поэтому свап надо выделить в отдельный подтом @swap - /swap/swapfile

 1. Btrfs + Snapper + Swap: решение проблемы несовместимости

Проблема: ошибка swapon failed: invalid argument при попытке подключить swap-файл на Btrfs с активным Snapper
Причина: CoW (Copy-on-Write) в Btrfs и конфликты с снапшотами Snapper при наличии swap на рутовом подтоме
Решение архитектуры: создание отдельного подтома @swap на top level 5 (плоская структура)
Создание нового подтома btrfs subvolume create /@swap
Монтирование подтома с опциями noatime,nodiscard
Отключение CoW через chattr +C /swap
Создание 8GB swap-файла через dd if=/dev/zero of=/swap/swapfile bs=1M count=8192
Инициализация swap через mkswap и swapon
Добавление в fstab для автозагрузки

Примерно такая последовательность.
   45  sudo btrfs subvolume create /@swap
   46  sudo mkdir -p /swap
   50  sudo mount /swap/
   51  mount | grep swap
   60  sudo mount /swap
   61  mount | grep swap
   62  sudo chattr +C /swap
   63  sudo dd if=/dev/zero of=/swap/swapfile bs=1M count=8192 status=progress
   64  sudo chmod 600 /swap/swapfile
   65  sudo mkswap /swap/swapfile
   66  sudo swapon /swap/swapfile
   68  sudo swapon --show

2. Проверка безопасности конфигурации

btrfs subvolume list / — подтверждение, что @swap находится на top level 5 (вне рутового подтома)

Snapper конфиг не требует изменений — исключения добавлять не нужно

swapon --show и free -h — проверка активного swap

## Zram и его роль
Упомянуть, что 20% достаточно. А после настройки свап будет показываться как сумма swapfile + zram

# Fail2Ban и проблема с логированием SSH
Ошибка: Failed during configuration: Have not found any log file for sshd jail
Причина: на systemd-journald использование, а не файловых логов /var/log/auth.log
Решение: изменение конфига /etc/fail2ban/jail.local на использование logpath = systemd-journal и backend = systemd


# NPM, DNS, mkcert
Для текущей версии отказываемся от "красивых" адресов - у меня не получилось настроить пока что.
Поэтому всё связанное с адресами убираем полностью и записываем в отдельный файл с будущими приложениями, с учётом ниижеследующих замечаний.

1. mkcert для локальных HTTPS-сертификатов
Установка зависимости libnss3-tools (для поддержки Firefox/Chrome)
Установка mkcert через apt
Создание локального CA и сертификатов для localhost через mkcert -install и mkcert localhost 127.0.0.1

2. AdGuard Home в Podman контейнере (systemd unit)
Проблема: после мастера настройки веб-интерфейс недоступен
Анализ логов контейнера и конфига /srv/adguardhome/conf/AdGuardHome.yaml
Обнаружение: AdGuard слушает на порту 80 по умолчанию, но в unit-файле опубликован только порт 3000
Решение: изменение конфига на address: 0.0.0.0:3000 в секции http
Проверка firewall правил через ufw status verbose — убедиться, что порт открыт для нужных сетей
Финальная проверка: telnet 192.168.1.100 3000 и доступ к веб-интерфейсу

# UFW
При настройке сервиса за сервисом, например Самба, я столкнулся с недоступностью после конфигурации. Оказалось, что нужно открывать порт каждого приложения или сервиса в файрволле.
Для каждого сервиса нужно указывать команды для UFW для открытия доступа как минимум из-под маски 16. 445 -> Samba port.

# Системные квадлеты от пользователя 
В мануале указаны неактуальные пути и способы вызова.
Путь для конфига контейнера: `~/.config/containers/systemd`
Имя файла: `container-<container_name>.container`
Старт контейнера: `systemctl --user start container-<container_name>.service`
Соответственно, это нужно отразить в описани настройки каждого сервиса.
