---
version: 1.0.0
tags:
  - linux
  - manual
  - selfhosting
  - containers
  - podman
translated-by: perplexity-labs
---

# Home Server Setup and Configuration Guide for Ubuntu Server

## Foreword

This is a step-by-step guide to building a home server from scratch. We'll use Ubuntu Server, Podman (containerization), and systemd quadlets to create our own media system while getting hands-on experience with Linux.

The guide was initially generated with Gemini CLI, then refined and verified through Perplexity PRO.

However, this is not a "blind" AI generation. I've personally walked through every section in the final version, doing my best to identify all potential pitfalls and inconsistencies.

Each tool we install deserves its own comprehensive documentation. Details about individual usage and integration with other applications should be researched separately—here we'll focus on basic scenarios only.

I'm not a system administrator; I'm just a Linux enthusiast. This work isn't free from errors and inaccuracies, especially regarding non-Linux commands. From user to users!

As my own learning progresses, this document will be updated accordingly.

You can praise and thank me on [X](https://x.com/MirrorHedgehog) and [Mastodon](https://techhub.social/deck/@tuchnyak).

---

## Chapter 0: Preparation

### 0.1. What Are We Building?

A multi-purpose home server for:
- **Personal Cloud** (Nextcloud) — Google Drive/Dropbox replacement
- **Media Server** (Jellyfin) — your own Netflix for your collection
- **Torrent Client** (qBittorrent) with web interface
- **File Synchronization** (Syncthing) across devices
- **Local LLM Models** (Ollama + Open WebUI)

### 0.2. Prerequisites

Basic knowledge:
- Comfortable with Linux command line (cd, ls, mkdir, etc.)
- Understanding of IP addresses and ports
- Basic text file editing skills

Unclear terms? Ask any LLM chat today—they're great at explaining.

### 0.3. Required Hardware

**Minimum requirements:**
- **CPU:** 4 cores (e.g., AMD Ryzen 5 3500U)
- **RAM:** 8 GB (16 GB recommended)
- **Storage:** SSD/NVMe from 256 GB (1 TB optimal)
- **Network:** Ethernet port (Wi-Fi works too, but slower)

**Example configuration from this guide:**
- CPU: AMD Ryzen 5 3500U (4 cores)
- RAM: 16 GB DDR4
- Storage: 1 TB PCIe3 NVMe SSD

**Additionally:**
- USB flash drive (minimum 4 GB) for installation
- Monitor and keyboard (needed only for setup)
- Ethernet cable (recommended)
- External hard drive 500 GB–1 TB (for backups, we'll add later)

### 0.4. Downloading Ubuntu Server

**Step 1:** Go to the official Ubuntu website and download the latest LTS release (Long-Term Support):
- URL: https://ubuntu.com/download/server
- Choose the LTS version (e.g., 24.04 LTS)

**Step 2:** Verify file integrity using SHA256

SHA256SUMS will be available alongside the image.

**Verification commands:**

Linux/macOS:
```bash
shasum -a 256 ubuntu-24.04.1-live-server-amd64.iso
```

Windows (PowerShell):
```powershell
CertUtil -hashfile ubuntu-24.04.1-live-server-amd64.iso SHA256
```

**Step 3:** Compare the resulting hash with the official one from SHA256SUMS

### 0.5. Creating Bootable USB

You'll need a USB flash drive of at least 4 GB (all data will be erased).

**Recommended tool:** BalenaEtcher (works on Windows/macOS/Linux)

Download from https://www.balena.io/etcher/

**Process:**
1. Open BalenaEtcher
2. Click "Flash from file" and select the downloaded Ubuntu Server .iso
3. Insert your USB drive and select it in BalenaEtcher
4. Click "Flash!" and wait for completion

### 0.6. Preparing the Server for Installation

**How to find your router's IP address:**

On any computer on your network (Windows/macOS/Linux):
```bash
# Linux/macOS
ip route | grep default
# or
netstat -rn | grep default

# Output will be something like: default via 192.168.1.1 dev eth0
# 192.168.1.1 is your router's IP
```

Windows (cmd or PowerShell):
```powershell
ipconfig
# Look for "Default Gateway" — that's your router's IP
```

Alternatively, check the label on your router (the address is usually there).

### 0.7. What We're Planning to Get

**Architecture:**
- Btrfs filesystem with automatic snapshots
- All service data in `/srv` for easy backup
- Wi-Fi or Ethernet with static IP
- SSH access by key only (no passwords)
- UFW firewall for protection
- fail2ban protection against brute force
- Podman containers instead of Docker (rootless, more secure)
- systemd quadlets for container autostart

---

## Chapter 1: System Installation and Basic Configuration

### 1.1. Booting from USB and Starting Installation

**Step 1:** Insert USB flash drive into server

**Step 2:** Turn on the computer and enter BIOS/UEFI
- Usually press F2, F12, F7, Delete, or Esc during startup
- Depends on motherboard manufacturer

**Step 3:** Change the boot order (Boot Order)
- Place USB flash drive first
- Save and exit (usually F10), following the on-screen prompts

**Step 4:** Computer will boot from USB and show Ubuntu Server installation menu

### 1.2. Ubuntu Server Installation Process with Btrfs

Now begins the installation process. Follow the instructions carefully.

#### Language Selection
- **Choice:** English
- Use arrow keys for navigation, Enter to confirm

#### Installer Update
- **Choice:** Continue without updating (can update after installation)

#### Keyboard Layout
- **Choice:** English (US)
- Or your preferred layout

#### Installation Type
- **Choice:** Ubuntu Server (minimized)
- This is the minimal version without extra packages

#### Network Configuration

**If Ethernet is connected:**
- DHCP usually works automatically
- You'll see the assigned IP address
- Can leave as is (we'll configure static IP later)

**If using Wi-Fi:**
1. Select Wi-Fi network from list
2. Enter Wi-Fi password
3. Wait for connection

**Note:** If Wi-Fi doesn't appear, make sure the adapter is supported by Linux kernel.

#### Proxy
- **Choice:** Leave blank

#### Mirror
- **Choice:** Ubuntu Default is fine.
    * Note: You might need a different region.

#### Disk Partitioning (Important!)

Here we'll set up Btrfs instead of standard ext4.

**Step 1:** Select **Custom storage layout**

**Step 2:** You'll see your SSD/NVMe disk (usually `/dev/nvme0n1` or `/dev/sda`)

**Step 3:** Create GPT partition table (if disk is new).
Take your time and carefully read all interface labels.

**Partitioning:**

**1. Boot partition (required):**
- Click "Add GPT Partition"
- **Size:** 1 GB
- **Format:** ext4
- **Mount point:** `/boot`

**2. Root partition (Btrfs):**
- Select remaining space
- **Size:** Leave remaining space (or specify, e.g., 100 GB for system)
- **Format:** btrfs
- **Mount point:** `/`

**Note:** You could create a separate subvolume for `/home`, but for a server it's not critical. The root partition will contain everything: system, `/home/myusername`, and everything else.

**Step 4:** Review partitioning and click Done

#### User Profile

Create main user account (NOT root):

- **Your name:** Your name (e.g., "George")
- **Your server's name:** Server name (e.g., "homeserver")
  - This name will be visible on the network
- **Pick a username:** Your login (e.g., "myusername")
  - Do NOT use "root" or "admin"
- **Choose a password:** Create a strong password
  - Minimum 12 characters, mix of letters, numbers, special characters

#### SSH Setup

**IMPORTANT:** Check the box:
☑ **Install OpenSSH server**

This is critical for remote access.

**Import SSH identity:** Can skip (we'll set up later)

#### Featured Server Snaps

Skip all Snap packages. We'll install what we need via apt.

#### Installation Complete

Read carefully 😊

1. Wait for installation to complete (5–10 minutes)
2. Remove USB drive when prompted
3. Press Enter to reboot

### 1.3. First Boot and Login

After reboot you'll see login prompt:

```
Ubuntu 24.04 LTS homeserver tty1
homeserver login: _
```

**Login:**
1. Enter your username (e.g., `myusername`)
2. Press Enter
3. Enter your password
4. Press Enter

You should see the command prompt:

```bash
myusername@homeserver:~$
```

Congratulations! The system is installed. Give yourself a pat on the back.

### 1.4. System Update

First thing: update all packages:

**On server:**
```bash
sudo apt update
sudo apt upgrade -y
```

This may take a few minutes.

**Recommendation:** Update manually approximately every 2 weeks:
```bash
sudo apt update
sudo apt list --upgradable  # See what's updating
sudo apt upgrade -y
```

Manual updates are safer than automatic—you see what's changing and can rollback via Btrfs snapshot if needed.

### 1.5. Installing Basic Utilities

**Critical:** Install basic utilities before network configuration. They're needed for subsequent operations.

**On server:**
```bash
sudo apt install -y vim iputils-ping git curl wget htop top net-tools tree lsof
```

**What we installed:**
- `vim` — text editor (nano alternative)
- `iputils-ping` — ping utility (check network connections)
- `git` — version control system
- `curl`, `wget` — file download utilities
- `htop`, `top` — process monitors (interactive and text-based)
- `net-tools` — classic network utilities (ifconfig, netstat)
- `tree` — directory tree display
- `lsof` — list open files and ports

These utilities are critical for diagnosing and working with the server in subsequent steps.

#### About VIM

Vim is a console text editor that shocks unprepared users. Some still can't exit it. But don't worry—it's simpler than it seems.

Vim has three working modes:
1. **NORMAL** — mode for text navigation, text manipulation, and entering commands starting with ":"
2. **INSERT** — mode for direct text input. Enter from normal mode by pressing "i". Return to normal mode with "Esc".
3. **VISUAL** — text selection mode for subsequent manipulation of selected text.

##### Basic Actions
- Navigate text using j, k, h, l keys in normal mode (down, up, left, right). Arrow keys usually work too.
- Position cursor, press "i", and type.
- Press "Esc" to return to normal mode.
- To select text, position cursor, press "v", and select.
  - Then delete with "d", for example.

At first it'll be tricky, but I believe everyone can figure it out.

**Basic Vim Cheat Sheet (for beginners):**

- `i` — enter insert mode
- `Esc` — return to normal mode
- `:w` — save
- `:q` — quit
- `:q!` — quit without saving
- `:wq` — save and quit
- `dd` — delete line
- `yy` — copy line
- `p` — paste
- `/word` — search for word
- `n` — next match

More info: `:help` in vim or `vimtutor` in terminal.

### 1.6. Network Configuration (Ethernet or Wi-Fi with Static IP)

You likely have a dynamic IP from DHCP. For a server, static IP is better.

#### Checking Current Connection

**On server:**
```bash
ip a
```

You'll see list of network interfaces. Find the active one (with UP status):
- Ethernet usually called `eth0`, `enp1s0`, or similar
- Wi-Fi usually called `wlan0`, `wlp1s0`, `wlo1`, or similar

In our example we use `wlo1` (Wi-Fi).

#### Finding Router IP Address

**On server:**
```bash
ip route | grep default
```

Output will be something like:
```
default via 192.168.1.1 dev wlo1
```

Here `192.168.1.1` is your router's IP address (gateway).

#### Choosing Free IP Address

**Important:** Choose an IP that's NOT used by other devices on network.

**How to check:**

1. Look at router—usually its address is `192.168.1.1` or `192.168.0.1`
2. Choose address from same range, e.g., `192.168.1.100`
3. Verify address is free:

**From another computer on network (Windows/macOS/Linux):**
```bash
ping -c 3 192.168.1.100
```

If you get "Destination Host Unreachable" or "Request timed out"—address is free, great!

If ping succeeds—choose different address (e.g., .101, .102, etc.)

**Linux/macOS alternative (uses ARP):**
```bash
sudo arping -c 3 -I eth0 192.168.1.100
```

If "0 packets received"—address is free.

#### Setting Static IP via Netplan

Ubuntu uses Netplan for network configuration.

**Step 1:** On server, backup configuration
```bash
sudo cp /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bak
```

**Step 2:** On server, edit Netplan configuration (filename might differ slightly)
```bash
sudo vim /etc/netplan/00-installer-config.yaml
```

**Important:** YAML formatting is critical! Use spaces (not Tab).

**Example configuration for Wi-Fi with static IP:**

```yaml
# This is the network config written by 'subiquity'
network:
  version: 2
  renderer: networkd
  wifis:
    wlo1:  # Your Wi-Fi interface name, replace with yours (see ip a)
      dhcp4: no
      access-points:
        "YOUR_WIFI_SSID":  # Replace with your Wi-Fi network name (SSID)
          password: "YOUR_WIFI_PASSWORD"  # Replace with Wi-Fi password
      addresses:
        - 192.168.1.100/24  # Your static IP address /24 = netmask 255.255.255.0
      routes:
        - to: default
          via: 192.168.1.1  # Your router's IP address (gateway)
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8]  # DNS servers (router + Google DNS)
```

**Parameter explanation:**
- `192.168.1.100/24` — your static IP, `/24` means netmask `255.255.255.0`
  - Allows addresses from `192.168.1.0` to `192.168.1.255` in same network
- `192.168.1.1` — router's IP (default gateway)
- `[192.168.1.1, 8.8.8.8]` — DNS servers (try router first, then Google)

**For Ethernet, configuration is similar, but use `ethernets:` section instead of `wifis:`:**

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:  # Your Ethernet interface
      dhcp4: no
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8]
```

**Step 3:** On server, apply Netplan configuration

First test (auto-reverts after 120 sec if something goes wrong):
```bash
sudo netplan try
```

If everything works, press Enter to confirm.

If NOT working or you lost SSH—wait 120 seconds, system auto-reverts.

Apply permanently:
```bash
sudo netplan apply
```

**Step 4:** Verification

On server:
```bash
ip a
```

You should see your static IP (e.g., `192.168.1.100`) on Wi-Fi (`wlo1`) or Ethernet interface.

Check internet on server:
```bash
ping google.com -c 4
```

If packets pass (0% packet loss)—everything works!

Time for a celebration snack.

### 1.7. SSH Connection from Another Computer

Now you can disconnect monitor and keyboard from server and work remotely ~~by Morse code~~ via SSH.

**From your main computer (Windows/macOS/Linux):**

```bash
ssh myusername@192.168.1.100
```

Replace:
- `myusername` with your username
- `192.168.1.100` with your server's IP

At first connection you'll be asked about key verification:
```
Are you sure you want to continue connecting (yes/no)?
```

Type `yes` and press Enter.

Enter your user password.

You should see command prompt:
```
myusername@homeserver:~$
```

Congratulations! You're connected via SSH.

### 1.8. Btrfs Snapshots via Snapper

Btrfs supports snapshots—instant filesystem snapshots. This lets you revert system if something breaks.

We use `snapper` for automatic snapshot creation.

**Step 1:** On server, install Snapper and apt integration
```bash
sudo apt install -y snapper apt-btrfs-snapshot
```

**Step 2:** On server, create Snapper configuration for root partition
```bash
sudo snapper -c root create-config /
```

This creates configuration in `/etc/snapper/configs/root`

**Step 3:** On server, edit snapper configuration

```bash
sudo vim /etc/snapper/configs/root
```

**Important parameters to change:**

Find `SUBVOLUME` and ensure it points to `/`:
```
SUBVOLUME="/"
```

Find `TIMELINE_CREATE` and set to `yes` for automatic snapshot creation:
```
TIMELINE_CREATE="yes"
```

Change from `no` to `yes` if it shows `no`.

Also configure old snapshot cleanup (so disk doesn't fill):
```
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
```

This means: keep 5 hourly and 7 daily snapshots.
Feel free to adjust. You're in charge!

**Step 4:** On server, start snapper timers

```bash
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
```

- `snapper-timeline.timer` — creates snapshots on schedule
- `snapper-cleanup.timer` — removes old snapshots

**Step 5:** On server, check snapshots

```bash
sudo snapper list-configs
```

Should show `root` configuration with `/` subvolume.

```bash
sudo snapper -c root list
```

Shows snapshot list. Should have at least 1–2 snapshots (created during install or apt).

**View snapshot size:**
```bash
sudo btrfs filesystem usage /
```

Shows how much space snapshots use.

**Automatic snapshots on updates:**

Thanks to `apt-btrfs-snapshot` package, each `apt upgrade` automatically creates a snapshot.

**Restore from snapshot (if something breaks):**
```bash
sudo snapper -c root list
sudo snapper -c root rollback <snapshot_number>
sudo reboot
```

### 1.9. Swap and ZRAM Configuration

You have 16 GB RAM, but some services (Nextcloud, Jellyfin, LLM models) use lots of memory. Swap protects from OOM Killer (Out Of Memory Killer), which kills processes when RAM runs out.

#### Solution for Btrfs + Snapper + Swap

**Problem:** Swap file on root Btrfs volume conflicts with CoW (Copy-on-Write) and Snapper, causing `swapon failed: invalid argument` error.

**Solution:** Create separate `@swap` subvolume at top-level 5 to isolate swap file.

**Step 1: Create @swap subvolume**

**On server:**
```bash
sudo btrfs subvolume create /@swap
```

**Step 2: Prepare mount point**

```bash
sudo mkdir -p /swap
```

**Step 3: Add to fstab for mounting**

```bash
echo "UUID=$(sudo blkid -s UUID -o value /dev/nvme0n1p2) /@swap btrfs noatime,nodiscard,subvol=@swap 0 0" | sudo tee -a /etc/fstab
```

Replace `/dev/nvme0n1p2` with your Btrfs root partition (find via `lsblk`)

**Step 4: Mount subvolume**

```bash
sudo mount /swap
```

**Check mounting:**
```bash
mount | grep swap
```

Should show `@swap` subvolume mounted at `/swap`.

**Step 5: Disable CoW for subvolume**

Copy-on-Write conflicts with swap file, so disable it:

```bash
sudo chattr +C /swap
```

**Step 6: Create swap file**

Create 8 GB swap file:

```bash
sudo dd if=/dev/zero of=/swap/swapfile bs=1M count=8192 status=progress
```

**Step 7: Set permissions**

```bash
sudo chmod 600 /swap/swapfile
```

**Step 8: Initialize swap**

```bash
sudo mkswap /swap/swapfile
sudo swapon /swap/swapfile
```

**Step 9: Check active swap**

```bash
sudo swapon --show
free -h
```

You should see 8 GB swap file.

**Step 10: Add to fstab for autoload**

```bash
echo "/swap/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
```

**Step 11: Verify configuration safety**

Ensure `@swap` is at top-level 5 (outside root subvolume):

```bash
sudo btrfs subvolume list /
```

Look for line with `/@swap`—ID should be different from others (usually 5+).

Snapper config needs NO changes—don't add exclusions.

#### ZRAM (Compressed Swap in RAM)

ZRAM is virtual disk in RAM with compression. Faster than disk swap, but uses some RAM.

**Advantage:** Less SSD wear, faster operation.

**Can use both methods together:** ZRAM for fast swap, swap file as backup.

**On server:**
```bash
sudo apt install -y zram-tools
```

**Configure ZRAM:**

```bash
sudo vim /etc/default/zramswap
```

Set:
```
ALGO=zstd
PERCENT=20
```

**Explanation:**
- `ALGO=zstd` — compression algorithm (zstd is more efficient)
- `PERCENT=20` — ZRAM at 20% of RAM (recommended to keep things simple)
  - On 16 GB RAM this will be 3.2 GB ZRAM

Restart ZRAM:
```bash
sudo systemctl restart zramswap.service
```

**Check:**

```bash
free -h
```

You should see:
- `Mem:` 16G (physical RAM)
- `Swap:` 11.2G (sum of ZRAM 3.2G + swapfile 8G)

After swap setup, swap will show as sum of swapfile + zram.

---

You're doing great—time to celebrate!

---

## Chapter 2: Security and Remote Access

Security is critical for home servers. In this chapter we'll configure:
- SSH access by key only (no passwords)
- UFW firewall for traffic filtering
- fail2ban protection against brute force attacks

Appendix has 2FA setup descriptions.

### 2.1. SSH with Public Keys (No Passwords)

Passwords can be brute-forced. Keys cannot (with sufficient length).

#### Generating SSH Keys on Your Local Computer

**On your main computer** (not server):

Modern way (recommended):
```bash
ssh-keygen -t ed25519 -f ~/.ssh/homeserver_key -C "myusername@homeserver"
```

Or traditional way (maximum compatibility):
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/homeserver_key -C "myusername@homeserver"
```

**Process:**
1. Press Enter to confirm path (or confirm `~/.ssh/homeserver_key`)
2. Enter passphrase (optional, but recommended for extra security)
3. Confirm passphrase

Creates two files:
- `~/.ssh/homeserver_key` — private key (NEVER share!)
- `~/.ssh/homeserver_key.pub` — public key (can share)

**Why ED25519 is better than RSA:**
- ED25519 is compact (256 bits vs 4096)
- Faster computation
- Compatible with all modern systems
- Mathematically more secure

#### Copying Public Key to Server

**On local computer:**
```bash
ssh-copy-id -i ~/.ssh/homeserver_key.pub myusername@192.168.1.100
```

Enter your server user password (last time!).

Command copies public key to `~/.ssh/authorized_keys` on server.

**If ssh-copy-id doesn't work (e.g., Windows):**
```bash
cat ~/.ssh/homeserver_key.pub | ssh myusername@192.168.1.100 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

#### Verifying Key Login

**On local computer, try connecting:**
```bash
ssh -i ~/.ssh/homeserver_key myusername@192.168.1.100
```

Now login should work WITHOUT password request (or with passphrase request for key if you set one).

If it works—great!

#### Convenience: Adding SSH Config

**On local computer, create config:**
```
vim ~/.ssh/config
```

```bash
Host homeserver
    HostName 192.168.1.100
    User myusername
    IdentityFile ~/.ssh/homeserver_key
    Port 22
```

Now you can simply:
```bash
ssh homeserver
```

#### Disabling Password Login on Server

**Important:** Do this ONLY after confirming key login works!

**On server**, edit SSH configuration:
```bash
sudo vim /etc/ssh/sshd_config
```

Find and change these lines (use `/` for search in vim):

```
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
```

If lines are commented (start with `#`), uncomment them.

Save and exit (`:wq` in vim).

Reload SSH service:
```bash
sudo systemctl restart sshd
```

**Important:** Don't close current SSH session! Open new terminal and test SSH connection. Only after that close old session.

If something goes wrong and you lose access—connect monitor and keyboard, login locally, and revert changes.

### 2.2. UFW Configuration (Uncomplicated Firewall)

UFW is simple yet powerful firewall for Ubuntu.

#### Installation and Basic Rules

**On server**, set default policies (deny incoming, allow outgoing):
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

#### Backing Up Configuration

```bash
sudo cp /etc/ufw/before.rules /etc/ufw/before.rules.bak
sudo cp /etc/ufw/after.rules /etc/ufw/after.rules.bak
sudo cp /etc/default/ufw /etc/default/ufw.bak
```

#### Allowing Required Services

We must allow SSH, HTTP, HTTPS, otherwise we can't connect.

**On server:**
```bash
# SSH (port 22, or your custom port)
sudo ufw allow ssh

# HTTP (port 80)
sudo ufw allow http

# HTTPS (port 443)
sudo ufw allow https
```

#### Enabling UFW

**On server:**
```bash
sudo ufw enable
```

Warning about SSH disconnection may appear. If you allowed SSH above—that's fine, press `y` and Enter.

#### Checking Status

**On server:**
```bash
sudo ufw status verbose
```

You should see rules list:
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
```

### 2.3. Installing and Configuring fail2ban

fail2ban monitors logs and bans IP addresses making too many failed login attempts.

#### Installation

**On server:**
```bash
sudo apt install -y fail2ban
```

#### SSH Protection Configuration

fail2ban uses `jail.conf` for settings. We don't edit it directly, but create local file.

**On server:**
```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

Edit local file:
```bash
sudo vim /etc/fail2ban/jail.local
```

Find `[sshd]` section and ensure:
```ini
[sshd]
enabled = true
```

**Add for systemd-journald (modern logging method):**

Find `logpath` and `backend` lines in `[sshd]` section, add/change:
```ini
[sshd]
enabled = true
backend = systemd
logpath = systemd-journal
```

This lets fail2ban work with systemd-journald instead of file logs.

#### Starting fail2ban

**On server:**
```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo systemctl status fail2ban
```

Status should be `active (running)`.

#### Checking Operation

```bash
sudo fail2ban-client status
```

Should show active jails:
```
Status
|- Number of jail:      1
`- Jail list:           sshd
```

### 2.4. Changing SSH Port (Optional, for Security-Conscious)

Port 22 for SSH is known to everyone. Can change to non-standard (e.g., 2222) for protection against mass scanners.

**Note:** Optional, but adds obscurity layer.

#### Backing Up SSH Config

**On server:**
```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak_before_port_change
```

#### Changing Port in SSH Config

**On server:**
```bash
sudo vim /etc/ssh/sshd_config
```

Find line:
```
#Port 22
```

Uncomment (remove `#`) and change to 2222 (or any port 1024–65535):
```
Port 2222
```

Can keep both ports temporarily for testing:
```
Port 22
Port 2222
```

After confirming port 2222 works, remove line `Port 22`.

#### Allowing New Port in UFW

**On server:**
```bash
sudo ufw allow 2222/tcp
sudo ufw reload
```

#### Reloading SSH Service

**On server:**
```bash
sudo systemctl restart sshd
```

#### Testing New Port

**On local computer — don't close current SSH session!**

Open new terminal and connect:
```bash
ssh -i ~/.ssh/homeserver_key -p 2222 myusername@192.168.1.100
```

If it works—great! Now can remove port 22 from SSH config and UFW.

**On server, remove old port:**
```bash
sudo ufw delete allow ssh  # or sudo ufw delete allow 22/tcp
sudo ufw reload
```

---

That was stressful. It gets easier from here. :)

---

## Chapter 3: Foundation for Services

This chapter prepares system for containerized services:
- Create directories for service data storage
- Install Podman (containerization)
- Configure systemd quadlets for autostart
- (Optional) Install monitoring and convenience tools

### 3.1. Creating /srv Structure for Service Data

All service data lives in `/srv` for easy backup and management.

**On server:**
```bash
# Create main directory
sudo mkdir -p /srv

# Create subdirectories for each service (with room for future)
sudo mkdir -p /srv/nextcloud/db
sudo mkdir -p /srv/nextcloud/html
sudo mkdir -p /srv/jellyfin/config
sudo mkdir -p /srv/jellyfin/media
sudo mkdir -p /srv/jellyfin/media/movies
sudo mkdir -p /srv/jellyfin/media/shows
sudo mkdir -p /srv/jellyfin/media/music
sudo mkdir -p /srv/qbittorrent/config
sudo mkdir -p /srv/qbittorrent/downloads
sudo mkdir -p /srv/qbittorrent/downloads/movies
sudo mkdir -p /srv/qbittorrent/downloads/shows
sudo mkdir -p /srv/qbittorrent/downloads/music
sudo mkdir -p /srv/syncthing/config
sudo mkdir -p /srv/syncthing/data
sudo mkdir -p /srv/ollama
sudo mkdir -p /srv/open-webui
sudo mkdir -p /srv/gitea
sudo mkdir -p /srv/backups

# Set permissions
# Change owner to your user
sudo chown -R $(whoami):$(whoami) /srv

# Set access rights (755 for directories)
sudo chmod -R 755 /srv
```

**Verify:**
```bash
ls -la /srv
whoami
```

You should own all directories in `/srv`.

### 3.2. Installing Podman

Podman is Docker alternative, but rootless (no root needed), which is more secure.

**On server:**
```bash
sudo apt install -y podman podman-docker
```

- `podman` — main containerization package
- `podman-docker` — Docker command compatibility (needed for Kamal)

**Verify:**
```bash
podman --version
```

Should show Podman version (e.g., `podman version 4.3.1`).

### 3.3. Configuring Rootless Mode for Podman

**CRITICAL!**

For user systemd services (and container systemd quadlets) to autostart on boot **WITHOUT** user login, enable **linger**:

**On server:**
```bash
# Enable linger mode (autostart user services on boot)
sudo loginctl enable-linger $(whoami)

# Verify
sudo loginctl show-user $(whoami)
```

Should show: `Linger=yes`

Now you can run containers without `sudo`:
```bash
podman ps
```

### 3.4. (Optional) Installing Cockpit for Web Management

Cockpit is web interface for server management (very convenient!).

**On server:**
```bash
sudo apt install -y cockpit cockpit-podman
```

**Enable and start:**
```bash
sudo systemctl enable --now cockpit.socket
```

**On server, allow Cockpit in UFW:**

Cockpit runs on port 9090. Allow from local network only:

```bash
# Replace 192.168.0.0/16 with your network range
# E.g., if your IP is 192.168.1.100, use 192.168.0.0/16 or 192.168.1.0/24
sudo ufw allow from 192.168.0.0/16 to any port 9090
sudo ufw reload
```

**Accessing Cockpit:**

On any computer on network, open browser and go to `https://192.168.1.100:9090` (replace IP with your server's).

**First login:**
- Username: your username (e.g., myusername)
- Password: your server password

**What you can do in Cockpit:**
- View CPU, RAM, disk usage
- Manage services and containers
- View logs
- File manager
- Install updates
- Reboot system

### 3.5. (Optional) Installing Zellij for Convenient Terminal

Zellij is modern tmux/screen alternative. Lets you create multiple windows and panels in one SSH session.

**On server, download and install Zellij:**

```bash
cd ~
wget https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz
tar -xvf zellij-x86_64-unknown-linux-musl.tar.gz
# Move to PATH
sudo mv zellij /usr/local/bin/
rm zellij-x86_64-unknown-linux-musl.tar.gz
```

**On server, verify:**
```bash
zellij --version
```

**Usage:**
- Start: `zellij`
- Detach (leave running, close SSH): `Ctrl+o`, then `d`
- Reattach: `zellij attach`

Very useful for long operations (e.g., large downloads)—detach and close SSH, process continues.

Inside Zellij:
- `Alt+n` — new tab
- `Alt+←/→` — switch tabs
- `Alt+↓` — split window horizontally
- `Alt+→` — split window vertically
- `Alt+x` — close window
- `Alt+Esc` — exit

### 3.6. (Optional) Configuring Vim for Convenience

Many like custom Vim setup. Here's basic configuration.

**On server:**
```bash
vim ~/.vimrc
```

Example configuration:
```vim
" Enable syntax highlighting
syntax on

" Color scheme
colorscheme desert

" Show line numbers
set number
set relativenumber

" Tab size (4 spaces)
set tabstop=4
set shiftwidth=4
set expandtab

" Show status bar
set laststatus=2
```

Save (`:wq` in vim).

Now Vim will be more convenient for config editing.

**Basic Vim Cheat Sheet (beginners):**

- `i` — enter insert mode
- `Esc` — return to normal mode
- `:w` — save
- `:q` — quit
- `:wq` — save and quit
- `dd` — delete line
- `yy` — copy line
- `p` — paste
- `/word` — search word
- `n` — next match

More info: `:help` in vim or `vimtutor` in terminal.

---

Recommendation: Bookmark all services you set up and will set up going forward.

---

## Chapter 4: File Access

This chapter covers:
- Samba for file access from PC

### 4.1. Deploying Samba for File Access

Samba lets you access server files from Windows, macOS, and Linux.

#### Installing Samba

**On server:**
```bash
sudo apt install -y samba samba-common-bin
```

#### Creating Share Directories

**On server:**
```bash
# Set access rights
chmod 755 /srv/jellyfin/media
chmod 755 /srv/qbittorrent/downloads
chmod 755 /srv/backups
```

#### Configuring Samba

Backup:
```bash
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
```

Edit:
```bash
sudo vim /etc/samba/smb.conf
```

```ini
[global]
   # Disable guest access
   map to guest = never
   
   # Encryption (for security)
   server smb encrypt = required
```

**Add shares to end of file:**

```ini
# Media files for Jellyfin
[Media]
   comment = Media files for Jellyfin
   path = /srv/jellyfin/media
   browseable = yes
   guest ok = no
   read only = no
   writable = yes
   create mask = 0755
   directory mask = 0755
   valid users = myusername

# Torrent downloads from qBittorrent
[Torrents]
   comment = Torrent downloads from qBittorrent
   path = /srv/qbittorrent/downloads
   browseable = yes
   guest ok = no
   read only = no
   writable = yes
   create mask = 0755
   directory mask = 0755
   valid users = myusername

# Client machine backups
[Backups]
   comment = Client machine backups
   path = /srv/backups
   browseable = yes
   guest ok = no
   read only = no
   writable = yes
   create mask = 0755
   directory mask = 0755
   valid users = myusername
```

**Note:** `valid users = myusername` limits access to your user. Can add multiple: `valid users = myusername, user2` or group: `valid users = @familygroup`.

#### Adding Samba User

Samba uses separate user database.

**On server:**
```bash
sudo smbpasswd -a myusername
```

Enter Samba access password.

#### Starting and Enabling Samba

**On server:**
```bash
sudo systemctl restart smbd
sudo systemctl restart nmbd
```

- `smbd` — main SMB service (File Sharing)
- `nmbd` — NetBIOS for network visibility

**Check:**
```bash
sudo systemctl status smbd
```

#### UFW: Opening Ports for Samba

Samba uses ports 137, 138 (UDP) and 139, 445 (TCP).

**On server:**
```bash
sudo ufw allow from 192.168.1.0/24 to any port 137
sudo ufw allow from 192.168.1.0/24 to any port 138
sudo ufw allow from 192.168.1.0/24 to any port 139
sudo ufw allow from 192.168.1.0/24 to any port 445
sudo ufw reload
```

**Explanation:** `from 192.168.1.0/24` allows access only from network 192.168.1.0-255 (mask /24 means subnet of 256 addresses). Change to your subnet if needed.

**Verify:**
```bash
sudo ufw status verbose | grep -E "137|138|139|445"
```

#### Connecting to Samba Shares

**From Windows:**
1. Open "This PC" → "Map network drive"
2. Folder: `\\192.168.1.100\Media` (or Torrents, Backups)
3. Click "Browse" and select folder
4. Check "Reconnect at startup"
5. Click Finish
6. Enter username `myusername` and Samba password

**From Linux:**
```bash
# Install tools
sudo apt install -y cifs-utils

# Mount
sudo mount -t cifs //192.168.1.100/Media /mnt/media -o username=myusername

# View mounted shares
mount | grep cifs
```

---

## Chapter 5: Deploying Main Services

This chapter deploys main services:
- Nextcloud (personal cloud)
- Jellyfin (media server)
- qBittorrent (torrent client)
- Syncthing (file sync)

For each service:
1. Create quadlet file (configuration)
2. Run via systemd
3. Open necessary ports in UFW

### 5.1. Preparing systemd Quadlets Configuration

systemd quadlets manage containers via systemd without docker-compose.

**On server:**
```bash
# Create directory for quadlet files
mkdir -p ~/.config/containers/systemd

# Verify path
ls -la ~/.config/containers/systemd
```

**What it is:** Systemd quadlets are config files (`.container`, `.volume`, `.pod` extensions) that systemd auto-transforms into systemd unit files.

**Basic quadlet file example** (used for all services):

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

**Explanation:**
- `[Unit]` — service metadata
- `[Container]` — container configuration
- `[Service]` — systemd behavior
- `[Install]` — autostart on boot

**Important:** Quadlet files must be named: `container-<NAME>.container`

Management:
```bash
# Reload systemd config
systemctl --user daemon-reload

# Start service
systemctl --user start container-<NAME>.service

# Enable autostart
systemctl --user enable container-<NAME>.service

# Status
systemctl --user status container-<NAME>.service

# Logs
journalctl --user -f -u container-<NAME>.service
# Navigate like in Vim
```

### 5.2. Nextcloud (Personal Cloud)

Nextcloud replaces Google Drive—file storage with web interface and mobile app.

### 5.3. PostgreSQL (Database for Nextcloud)

#### Creating Environment Variables

**On server**, create directory for env files:
```bash
mkdir -p ~/compose
```

Create env file:
```bash
vim ~/compose/nextcloud.env
```

Contents:
```
POSTGRES_USER=nextcloud
POSTGRES_PASSWORD=your_very_strong_password_min_16_chars
POSTGRES_DB=nextcloud
```

**Important:** Replace password with real **strong** password!

Restrict permissions:
```bash
chmod 600 ~/compose/nextcloud.env
```

#### Creating PostgreSQL Quadlet

**On server:**
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

**Note:** `%h` in systemd means home directory (`/home/myusername`).

**On server, start:**
```bash
podman network create nextcloud-net
systemctl --user daemon-reload
systemctl --user start container-nextclouddb.service
```

Check:
```bash
systemctl --user status nextcloud-db.container
```

**Note for future:** If new service needs PostgreSQL, can add new database to existing container:
```bash
podman exec -it nextclouddb psql -U postgres -c "CREATE DATABASE newservice;"
```

Or create separate container on different port (5433, 5434, etc.) if different PostgreSQL version needed.
Better yet, connect new service to separate container network like `Network=nextcloud-net`.

### 5.4. Nextcloud (Personal Cloud)

#### Creating Nextcloud Quadlet

**On server:**
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

**Note:**
- `Requires=nextcloud-db.service` — Nextcloud depends on DB
- `After=nextcloud-db.service` — Nextcloud starts AFTER DB
- `POSTGRES_HOST=127.0.0.1` — local DB connection

**On server, start:**
```bash
systemctl --user daemon-reload
systemctl --user start container-nextcloudapp.service
sudo ufw allow 8180/tcp comment "Nextcloud"
```

#### Initial Nextcloud Setup

On any computer on home network, open browser: `http://192.168.1.100:8180`

You'll see Nextcloud setup wizard.

1. Create **admin account** (username and password)
2. **Data folder:** keep default (`/var/www/html/data`)
3. **Database:**
- Select **PostgreSQL**
- **User:** `nextcloud`
- **Password:** (your password from nextcloud.env)
- **Database:** `nextcloud`
- **Host:** `127.0.0.1:5432`
4. Click **Finish setup**

Nextcloud will install (may take 1–2 minutes).

#### Personal Experience
Currently Nextcloud performs well in these scenarios:
1. Two-way file sync desktop ↔ cloud.
2. Uploading photos/videos from smartphone camera to cloud.
3. One-way uploading arbitrary phone directories to cloud.

### 5.5. Jellyfin (Media Server)

#### Creating Jellyfin Quadlet

**On server:**
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
Volume=/srv/jellyfin/media/movies:/media/movies
Volume=/srv/jellyfin/media/shows:/media/shows
Volume=/srv/jellyfin/media/music:/media/music
Volume=/srv/qbittorrent/downloads/movies:/media/downloads/movies
Volume=/srv/qbittorrent/downloads/music:/media/downloads/music
Volume=/srv/qbittorrent/downloads/shows:/media/downloads/shows

[Service]
Restart=always

[Install]
WantedBy=default.target
```

I decided to also give access to torrent download directories. Alternatively, could move downloads to Jellyfin media directory.

**On server, start:**
```bash
systemctl --user daemon-reload
systemctl --user start container-jellyfin.service
sudo ufw allow 8096/tcp comment "Jellyfin HTTP"
sudo ufw allow 8920/tcp comment "Jellyfin HTTPS"
#sudo ufw allow from 192.168.1.0/16 to any port 8920/tcp comment "Jellyfin HTTPS"
```

#### Initial Jellyfin Setup

On any computer, open browser: `http://192.168.1.100:8096`

Go through setup wizard:
1. Select language
2. Create user (admin)
3. **Add Media Library:**
- **Type:** Movies (or other)
- **Folders:** `/media` (path inside container, can add multiple)
4. Finish setup

#### Adding Media Files

For Jellyfin to recognize movies/music/shows, files must be in correct directories connected to appropriate library, and follow certain file structure. E.g., movies documentation: [https://jellyfin.org/docs/general/server/media/movies](https://jellyfin.org/docs/general/server/media/movies)

Work with any LLM chat to organize files even from terminal 😊 I believe in us!

### 5.6. qBittorrent (Torrent Client)

#### Creating qBittorrent Quadlet

**On server:**
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

**Note:** We use port **8090** on host (instead of 8080) to avoid conflicts!

**Variable explanation:**
- `PUID=1000` — User ID (your user, usually 1000)
- `PGID=1000` — Group ID
- `TZ=Europe/Moscow` — timezone (change to yours)

**On server, start:**
```bash
systemctl --user daemon-reload
systemctl --user start container-qbittorrent.service
sudo ufw allow 8090/tcp comment "qBittorrent WebUI"
sudo ufw allow 6881/tcp comment "qBittorrent DHT"
sudo ufw allow 6881/udp comment "qBittorrent DHT UDP"
```

Note: qBittorrent marks files/directories with user 100999. I didn't fight this. Manage and move files for Jellyfin via `sudo` if needed.

#### Initial qBittorrent Setup

On any computer, open: `http://192.168.1.100:8090`

**Default login:**
- Username: `admin`
- Password: `adminadmin`

**Change password immediately!**

Go to **Tools** → **Options** → **Web UI** and change password.

##### Possible Issues

1. "Unauthorized" instead of login window.
```bash
sudo vim /srv/qbittorrent/config/qBittorrent/qBittorrent.conf
```

Find or add line:
```
WebUI\HostHeaderValidation=false
```

If password `adminadmin` didn't work, check Cockpit container logs for temporary password to replace.

#### Download Directory Setup

**Tools** → **Options** → **Downloads:**
- **Default Save Path:** `/downloads` (inside container, matches `/srv/qbittorrent/downloads` on host)

Files save to `/srv/qbittorrent/downloads` on host.

### 5.7. Syncthing (File Synchronization)

#### Creating Syncthing Quadlet

**On server:**
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

**On server, start:**
```bash
systemctl --user daemon-reload
systemctl --user start container-syncthing.service
sudo ufw allow 8384/tcp comment "Syncthing WebUI"
sudo ufw allow 22000/tcp comment "Syncthing Sync TCP"
sudo ufw allow 22000/udp comment "Syncthing Sync UDP"
sudo ufw allow 21027/udp comment "Syncthing Discovery"
```

#### Initial Syncthing Setup

On any computer, open: `http://192.168.1.100:8384`

First launch shows warning about GUI from external network.

Configure:
1. **Actions** → **Settings**
2. **GUI:**
- Set **GUI Authentication** (username and password)
3. Add folders for synchronization

#### Personal Experience

I use this for syncing notes library with LogSeq. My approach:
- Smartphone is primary device (always online, most work).
- Two-way sync to notebook and home server from phone.
- Between notebook and server—no link to reduce sync conflict risk.

### 5.8. Several Ways to Troubleshoot

**Container won't start:**
```bash
# Check logs
journalctl --user -f -u container-<NAME>.service

# Restart
systemctl --user restart container-<NAME>.service
```

**Container "crashes":**
```bash
# Check status
podman ps -a | grep <NAME>

# Check container logs
podman logs <container_id>
```

**Port is busy:**
```bash
# Check what's listening on port
sudo lsof -i :<port_number>

# Stop container
systemctl --user stop container-<NAME>.service
```

---

Congratulations! Time to fill your server with content!

---

## Chapter 6: Backup Strategy

**ATTENTION!** This section I haven't personally completed yet, since I can't afford a backup disk (sad times). However, I decided to include it in the manual release. Be careful!

Backups protect from data loss on disk failure or mistakes.

### 6.1. The 3-2-1 Rule

Ideally, follow this strategy:

**3-2-1 Rule:**
- **3 copies** of data (original + 2 backups)
- **2 different** media types (disk + external disk)
- **1 copy** in separate location (optional, can skip)

**Our implementation:**
- Copy 1: main disk with Btrfs snapshots
- Copy 2: external USB disk (weekly backup)
- Copy 3: optional cloud (like Nextcloud or Google Drive), not our own cloud

### 6.2. Automatic Btrfs Snapshots (Already Configured)

Snapper creates hourly snapshots and on every update.

**Check:**
```bash
sudo snapper list
sudo snapper -c root list
sudo btrfs filesystem usage /
```

**Restore:**
```bash
sudo snapper -c root rollback <snapshot_number>
sudo reboot
```

### 6.3. Backup to External Disk

Connect external USB disk (500 GB–1 TB) for weekly backup.

#### Preparing External Disk

**On server, connect disk and verify:**
```bash
lsblk
```

Find your disk (usually `/dev/sdb` or `/dev/sdc`).

**Format (data will be erased!):**
```bash
sudo mkfs.ext4 /dev/sdb1  # Replace with your partition
```

**Create mount point:**
```bash
sudo mkdir -p /mnt/backup
sudo mount /dev/sdb1 /mnt/backup
```

**Verify:**
```bash
mount | grep backup
```

#### Backup Script

**On server, create script:**
```bash
cat > ~/backup.sh << 'EOF'
#!/bin/bash
set -e

BACKUP_DIR="/mnt/backup"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Backup started: $TIMESTAMP ==="

# Check disk is mounted
if ! mount | grep -q "$BACKUP_DIR"; then
    echo "Error: $BACKUP_DIR not mounted"
    exit 1
fi

# Backup /srv directories
rsync -avz --delete /srv/ "$BACKUP_DIR/srv_backup_$DATE/"

echo "=== Backup completed: $(date +%Y%m%d_%H%M%S) ==="
EOF

chmod +x ~/backup.sh
```

Flags:
- `-a` — archive mode (preserves permissions, times, etc.)
- `-v` — verbose (show progress)
- `-z` — compression
- `--delete` — remove destination files not in source

For space-efficient dated copies, adjust rsync:
```bash
rsync -avz --delete /srv/ /mnt/backup/srv/
```

**Run manually:**
```bash
~/backup.sh
```

#### Automating with Cron

**Add to crontab (weekly backup, Sundays 2:00 AM):**

```bash
crontab -e
```

**Add line:**
```
0 2 * * 0 /home/myusername/backup.sh >> /home/myusername/backup.log 2>&1
```

**Verify:**
```bash
crontab -l
```

### 6.4. Monitoring Backups

**Check backup size:**
```bash
du -sh /mnt/backup/
```

**Check last backup status:**
```bash
tail -20 ~/backup.log
```

### 6.5. Restoring from Backup

**If data deleted/corrupted in /srv:**
```bash
# Stop containers
systemctl --user stop container-*.service

# Restore from backup
rsync -av /mnt/backup/srv_backup_<DATE>/ /srv/

# Restart containers
systemctl --user start container-*.service
```

**Permanent disk mounting (optional):**

**On server**, add to fstab:
```bash
sudo blkid /dev/sdb1
# Remember UUID

sudo vim /etc/fstab
```

Add:
```
UUID=<your-uuid-here> /mnt/backup ext4 defaults,nofail 0 2
```

`nofail` means system boots even if disk disconnected.

---

What's next? Planned chapters with additional services. At minimum: Ollama + Open WebUI, Gitea, and Homeassistant.

Morning is wiser than evening.

---

## Appendices

### Appendix A: Checking Logs and Debugging

#### Container Logs

**On server**, via systemd:
```bash
systemctl --user status container-jellyfin.service
journalctl --user -u container-jellyfin.service -f  # Live logs
```

#### Entering Container

**On server:**
```bash
podman exec -it jellyfin bash
```

Now you're inside container and can run commands.

#### Restarting Service

**On server:**
```bash
systemctl --user restart container-jellyfin.service
```

#### Resource Usage

**On server:**
```bash
podman stats jellyfin
```

Shows CPU, RAM, network in real-time.

### Appendix B: Updating Container Images

**On server**, update image manually:

```bash
# 1. Stop container
systemctl --user disable container-jellyfin.service
systemctl --user stop container-jellyfin.service

# 2. Download new image
podman pull docker.io/jellyfin/jellyfin:latest

# 3. Reload systemd (recreates container)
systemctl --user daemon-reload

# 4. Start container (will use new image)
systemctl --user start container-jellyfin.service

# 5. Verify
systemctl --user status container-jellyfin.service
```

**On server**, remove old images:
```bash
podman image prune  # Remove unused images
podman image prune -a  # Remove ALL images (be careful!)
```

### Appendix C: Command Cheat Sheet

#### systemd (Service Management)

**On server:**
```bash
# Reload config
systemctl --user daemon-reload

# Start service
systemctl --user start container-<service>.service

# Stop service
systemctl --user stop container-<service>.service

# Restart service
systemctl --user restart container-<service>.service

# Enable autostart
systemctl --user enable container-<service>.service

# Disable autostart
systemctl --user disable container-<service>.service

# Service status
systemctl --user status container-<service>.service

# Logs
journalctl --user -u container-<service>.service -f

# All user services
systemctl --user list-units --type=service
```

#### Podman (Container Management)

**On server:**
```bash
# Running containers
podman ps

# All containers (including stopped)
podman ps -a

# Container logs (live)
podman logs <container_name> -f

# Enter container
podman exec -it <container_name> bash

# Stop container
podman stop <container_name>

# Start container
podman start <container_name>

# Remove container
podman rm <container_name>

# Download image
podman pull <image_name>

# List images
podman images

# Remove image
podman rmi <image_id>

# Resource stats
podman stats
```

#### Networking

**On server:**
```bash
# Show all interfaces and IPs
ip a

# Only IPv4
ip -4 a

# Routes (default gateway, etc.)
ip route

# ARP table (IP → MAC mapping)
ip neigh

# Ping
ping google.com -c 4

# Open ports
sudo ss -tulpn | grep LISTEN
sudo lsof -i :<port>

# DNS servers
cat /etc/resolv.conf

# Reconnect interface
sudo ip link set <interface> down
sudo ip link set <interface> up
```

### Appendix D: Understanding `ip a` Output

The `ip address show` command (shortened `ip a`) shows all network interfaces and their assigned IPs.

#### Example Output

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

#### Breaking Down Each Line

**Interface number and name:**
```
1: lo:
2: eth0:
3: wlo1:
```
- `1, 2, 3` — interface order in system
- `lo` — **loopback** (virtual interface for localhost)
- `eth0` — **Ethernet** (wired connection)
- `wlo1` — **Wireless** (Wi-Fi adapter)

**Interface status:**
```
<BROADCAST,MULTICAST,UP,LOWER_UP>
```
- `UP` — interface enabled
- `DOWN` — interface disabled
- `LOWER_UP` — physical layer OK (cable/Wi-Fi present)
- `UP,LOWER_UP` = working ✅
- `UP` (no LOWER_UP) = no physical connection ❌

**MAC address:**
```
link/ether 08:00:27:e4:e2:a1
```
- Physical adapter address
- Format: `XX:XX:XX:XX:XX:XX` (6 pairs hexadecimal)

**IPv4 address:**
```
inet 192.168.1.100/24 scope global dynamic eth0
```
- `192.168.1.100` — IP address
- `/24` — CIDR notation (netmask, equals 255.255.255.0)
- `dynamic` — address from DHCP
- `static` — manual address
- `scope global` — visible to whole network
- `scope host` — visible only on this computer

**Address lifetime:**
```
valid_lft 3599sec preferred_lft 3599sec
```
- `valid_lft` — seconds until address expires (for DHCP)
- `forever` — address doesn't expire

#### Practical Examples

**Find active interface:**
```bash
ip a | grep "state UP"
```

**Find only IPv4 addresses:**
```bash
ip a | grep "inet " | grep -v "127.0.0.1"
```

**Check if internet available:**
```bash
ip a | grep "state UP" | grep -v "lo:"
```

If nothing appears—no active connection.

**Find adapter MAC address:**
```bash
ip a show eth0 | grep "link/ether"
```

**Find router IP (gateway):**
```bash
ip route | grep default
```

#### Status Interpretation Table

| Status | Meaning | Action |
|--------|---------|--------|
| `UP,LOWER_UP` | ✅ Works | Normal, all OK |
| `UP` (no LOWER_UP) | ⚠️ Enabled, no link | Check cable/Wi-Fi |
| `DOWN` | ❌ Disabled | `sudo ip link set eth0 up` |
| `dynamic` (IP) | 📶 IP from DHCP | Can change |
| `static` (IP) | 🔒 Permanent IP | Manual setup |

---
