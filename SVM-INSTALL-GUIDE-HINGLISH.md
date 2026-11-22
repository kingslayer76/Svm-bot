# SVM Bot — Complete Install + "Run Nahi Kar Raha" Fix Guide (Hinglish)

> Ye guide **is repo ke actual code** ko padh kar likhi gayi hai (`Svm-v13.4-bot.zip` ke andar ka `install.sh`,
> `bot.py`, `systemd/svm.service`, `.env.example`, `requirements.txt`).
> Jo commands aur error messages neeche hain, wo source se liye gaye hain — guess nahi.

---

## 0. TL;DR — 60 second me

| Cheez | Answer |
|---|---|
| Ye kya hai | **SVM Advanced AI** — ek Discord bot + web panel jo **VPS (LXC/KVM) banata, manage karta, IP/port allot karta, payments leta** hai. Made by **AnkitCoder**. |
| Language | Python 3.9+ (discord.py 2.x + Flask + paramiko) |
| Latest version | **V13.4** → file: `Svm-v13.4-bot.zip` (08-Nov-2026, 605 KB) |
| Install command | `sudo bash install.sh` (zip extract karke) |
| Install kahan hota hai | `/opt/svm` + systemd service `svm` |
| Ports | `5000` (WebSSH + Admin), `8787` (payment webhook), `20000–50000` (customer VPS ports) |
| 90% "run nahi hota" ka kaaran | (1) `DISCORD_TOKEN` nahi daala, (2) **Message Content / Server Members intent** Developer Portal me ON nahi, (3) token galat/quote ke saath, (4) bot v13.3 ka purana bug (v13.4 use karo) |
| Turant check | `systemctl status svm` → `journalctl -u svm -n 100 --no-pager` |
| Auto-diagnose | `sudo bash diagnose.sh` (is repo me diya hua script) |

---

## 1. Isme kya-kya hai (asli inventory)

Repo `kingslayer76/Svm-bot` me sirf 3 tarah ki cheezein hain:

```
README.md              ← installer ki documentation (bootstrap ke baare me)
install.sh             ← 6.5 KB ka BOOTSTRAP (zip extract karke andar wala installer chalata hai)
SVM-V12.2.zip          ← purane versions
SVM-V12.3.zip
SVM-V13.zip
SVM-V13.2.zip
Svm-v13.3-bot.zip
Svm-v13.4-bot.zip      ← ★ LATEST (isko use karo)
```

`Svm-v13.4-bot.zip` ke andar (extract karne par):

| File | Kaam |
|---|---|
| `bot.py` (16,273 lines) | Discord commands + Flask web panel (WebSSH/Admin/File Manager) |
| `install.sh` (1,416 lines) | Asli installer: apt packages, venv, pip, systemd, LXD, firewall, backup |
| `svm12.py` | Plans, payments, DB migrations, LXC provider core |
| `svm_ipam.py`, `svm_net.py`, `svm_ssh.py` | IP allotment, iptables/NAT, SSH diagnose |
| `svm_kvm.py` | KVM (libvirt/qemu) create/start/stop/delete |
| `svm_map.py`, `svm_topology.py`, `svm_ip_discovery.py` | Network map + IP scan |
| `svm_dns.py`, `svm_files.py`, `svm_tools.py`, `svm_neofetch.py` | DNS, SFTP, tools, status SVG/PNG |
| `admin.html`, `webssh.html`, `filemanager.html` | Web UI |
| `requirements.txt` | discord.py, python-dotenv, requests, paramiko, flask, flask-cors, pillow, cairosvg |
| `systemd/svm.service` | Service ka template |
| `tests/` | Unit tests (17 files) |

**Important:** `README.md` V13.3 bolta hai, banner "V14" bolta hai, `.env.example` V14 bolta hai,
bootstrap installer V13.3 bolta hai, lekin **zip aur code V13.4** hai. Version labels mix hain — kaam ka
version **13.4** hai. Isse confuse mat hona.

---

## 2. Server requirements (ye galat hua to install beech me mar jaayega)

| Cheez | Minimum | Recommended |
|---|---|---|
| Host OS | Ubuntu 20.04/22.04/24.04, Debian 11/12 | **Ubuntu 22.04 ya 24.04 LTS** |
| Root access | **Zaroori** (`sudo`) | — |
| RAM | 2 GB | 4 GB+ (LXD containers chalane hain to) |
| Disk | 20 GB free | **40 GB+** (installer LXD pool 90 GiB maangta hai, free kam ho to `dir` driver par fallback karta hai) |
| Arch | x86_64 | x86_64 |
| Python | 3.9+ (installer check karta hai) | 3.11/3.12 |
| systemd | **Zaroori** | — |
| KVM feature ke liye | `/dev/kvm` + nested virt | KVM VPS, OpenVZ nahi |

**Kahan install NA karo:**
- Windows / macOS (Linux-only)
- OpenVZ / LXC *container* VPS jisme systemd nahi (service start hi nahi hoga)
- Free shared hosters jahan snap/apt/iptables block hote hain
- 1 GB RAM wale box (pip build + LXD me OOM)

Kaunsa provider chahiye: **KVM-based VPS** (Contabo/Hetzner/DigitalOcean/OVH types), Ubuntu 22.04 clean image.

---

## 3. Step-by-step INSTALL

### Step 3.1 — Server taiyar karo

```bash
# root ya sudo user
sudo apt update
sudo apt install -y git unzip curl
```

### Step 3.2 — Code laao (do tarike)

**Tarika A — poora repo clone (bootstrap ke saath):**

```bash
cd /root
git clone https://github.com/kingslayer76/Svm-bot.git
cd Svm-bot
ls -lh          # Svm-v13.4-bot.zip dikhna chahiye
```

**Tarika B — sirf latest zip (recommended, kam surprise):**

```bash
cd /root
mkdir -p svm-src && cd svm-src
# zip ko yahan upload karo (scp / wget), phir:
unzip -o Svm-v13.4-bot.zip -d .
ls              # bot.py, install.sh, svm12.py ... dikhna chahiye
```

### Step 3.3 — Zip pehle verify karo (30 second, safety)

```bash
unzip -tq Svm-v13.4-bot.zip          # "No errors detected" aana chahiye
unzip -l Svm-v13.4-bot.zip | head -30 # bot.py + install.sh root me hone chahiye
```

### Step 3.4 — Installer chalao

**Agar Tarika A (repo) use kiya — bootstrap:**

```bash
cd /root/Svm-bot
sudo bash install.sh
```

> ⚠️ **Ye bootstrap `Svm-v13.4-bot.zip` naam dhoondhta hai** (code me hardcoded hai), lekin README
> `Svm-v13.3-bot.zip` bolta hai. Agar aapne sirf v13.3 zip rakha hai to error aayega:
> `Cannot find Svm-v13.4-bot.zip in: /root/Svm-bot`.
> **Fix:** v13.4 zip download karo, ya `sed -i 's/Svm-v13.4-bot.zip/Svm-v13.3-bot.zip/' install.sh`
> (isi naam se dono jagah, `PROJECT_DIR` bhi).

**Agar Tarika B (zip) use kiya — direct:**

```bash
cd /root/svm-src
sudo bash install.sh
```

### Step 3.5 — Wizard ke jawab (jo poochhega)

Installer kram se ye karta/poochhta hai:

1. **System dependencies** — apt se python3, venv, pip, sqlite3, curl, git, jq, openssl… (2–5 min)
2. **Backup** — purana install ho to `/opt/svm/backups/upgrade-<timestamp>/` (fresh install par khaali)
3. **Sources** — local files ya git clone fallback
4. **.env** — naya banega, ya purana **preserve** hoga (overwrite nahi hota)
5. **Network auto-detect** — `YOUR_SERVER_IP` khud bhar deta hai
6. **LXD auto-init** — snap se LXD, bridge `lxdbr0`, pool `default` (90 GiB; fail ho to `dir`)
7. **Discord token** — **yahan paste karo** (visible hota hai, taaki paste kaam kare)
8. **Config wizard** (y/n):
   - `MAIN_ADMIN_ID` — aapka Discord user ID (numeric, 15–21 digits)
   - `YOUR_SERVER_IP` — public IP
   - `SVM_PUBLIC_URL` — blank chhod sakte ho (payments auto-verify nahi chahiye to)
   - payments: Razorpay / Stripe / UPI (skip kar sakte ho, sirf plans ke liye prices)
   - `IPAM_BIND_MODE` — single public IP par **`portfwd`** (default, sahi)
   - port range `20000–50000`
9. **Deploy** → `/opt/svm` (bot.py, modules, html files)
10. **Python env** → `/opt/svm/venv` + `pip install -r requirements.txt`
11. **Static validation** → bot.py + svm12.py compile, "bot.run() last hona chahiye" check, DB migration dry-run
12. **Firewall** → ufw active ho to 5000, 8787, 20000-50000 open
13. **systemd** → `/etc/systemd/system/svm.service` + daily backup timer
14. **CLI** → `/usr/local/bin/svm`
15. **Health check** → service start karke 40 s tak log dekhta hai; **fail hua to bot.py rollback + exit**
16. **Summary** → `/admin` ka **password ek baar** print hota hai (likh lo!)

Agar token skip kar diya:
```bash
sudo bash install.sh --configure     # sirf config wizard
sudo systemctl restart svm
```

### Step 3.6 — Discord side (ye step log bahut skip karte hain → "bot online hi nahi aata")

1. <https://discord.com/developers/applications> → **New Application** → naam do
2. Left me **Bot** → **Reset Token** → **Copy** (ye `DISCORD_TOKEN` hai; kahin safe rakho, dobara nahi dikhega)
3. Usi **Bot** page par neeche **Privileged Gateway Intents**:
   - ✅ **MESSAGE CONTENT INTENT** → **ON** ← iske bina `!commands` kaam nahi karte
   - ✅ **SERVER MEMBERS INTENT** → **ON** (code `intents.members = True` set karta hai)
   - ⬜ PRESENCE INTENT → OFF (zaroorat nahi)
   - **Save Changes** dabao
4. **OAuth2 → URL Generator**:
   - Scopes: `bot`, `applications.commands`
   - Bot Permissions: `Administrator` (aasaan), ya kam se kam: Send Messages, Embed Links, Attach Files, Read Message History, Manage Channels, Manage Roles
   - Generate URL → browser me kholo → apne server me add karo
5. Apna **user ID** lo: Discord Settings → Advanced → **Developer Mode ON** → apne naam par right-click → **Copy User ID**
   → ye `MAIN_ADMIN_ID` hai
6. `.env` me daalo (agar install me nahi daala):
   ```bash
   sudo nano /opt/svm/.env
   # DISCORD_TOKEN=xxxxx.yyyyy.zzzzz
   # MAIN_ADMIN_ID=123456789012345678
   sudo systemctl restart svm
   ```

### Step 3.7 — Verify (3 test)

```bash
# 1) Service chal rahi hai?
systemctl status svm --no-pager

# 2) Log me login dikha?
journalctl -u svm -n 50 --no-pager

# 3) Web panel zinda hai?
curl -s http://127.0.0.1:5000/api/health
# {"status":"ok", ... "admin_panel":true, "admin_html":true, ...}
```

Discord me bot **online** dikhe, phir channel me:
```
!botinfo
!plans
!svm-health        (admin)
!ipool             (admin)
```
Web: `http://YOUR_IP:5000/` (WebSSH), `http://YOUR_IP:5000/admin`, `:5000/filemanager`

### Step 3.8 — Cloud firewall bhi kholo

`ufw` sirf OS-level hai. Provider panel (AWS SG / Oracle / Hetzner firewall) me bhi kholo:

| Port | Kaam |
|---|---|
| 22 | SSH (aap) |
| 5000/tcp | WebSSH + Admin |
| 8787/tcp | Payment webhook (public HTTPS proxy ke peeche rakho) |
| 20000–50000 tcp+udp | Customer VPS port forwards |

---

## 4. "Install kar liya, par RUN/KAAM nahi kar raha" — 12 asli kaaran

> Neeche har case me **pehchan ka command** + **exact fix** hai. Up-to-down order me hai (sabse common pehle).

### 🔴 4.1 `DISCORD_TOKEN` khaali hai → bot turant exit
**Symptom:** `systemctl status svm` = `activating` ↔ `failed` ka loop, restart counter badhta hai.
**Log:**
```
ERROR - [ERROR] No valid Discord token found!
ERROR - Please update your .env file with a valid Discord bot token.
ERROR - DISCORD_TOKEN in .env is currently set to: None
```
(Ye maine is repo ke code ko chala kar **verify kiya** — process `exit 1` karta hai, isliye systemd use baar-baar restart karta hai aur `StartLimitBurst` ke baad service **failed** ho jaati hai.)

**Check:**
```bash
sudo grep -c '^DISCORD_TOKEN=.\+' /opt/svm/.env     # 0 aaya to token nahi hai
```
**Fix:**
```bash
sudo bash /opt/svm/source/install.sh --configure    # token + admin id daalo
sudo systemctl restart svm && journalctl -u svm -f
```

---

### 🔴 4.2 Token galat / extra quote / space → `LoginFailure`
**Symptom:** log me `discord.errors.LoginFailure: Improper token has been passed.` ya `401 Unauthorized`
**Kaaran:** token copy karte waqt `"` , `'` , space, ya line break aa gaya; ya token **regenerate** kar diya (purana token mar gaya).

**Check (masked):**
```bash
sudo grep '^DISCORD_TOKEN=' /opt/svm/.env | sed -E 's/(DISCORD_TOKEN=)(.{6}).*(.{4})$/\1\2…\3/'
sudo awk -F= '/^DISCORD_TOKEN=/{print "length="length($2)}' /opt/svm/.env   # ~70-80 chars hona chahiye
```
**Fix:** Developer Portal → Bot → Reset Token → naya token, bina quotes:
```bash
sudo sed -i '/^DISCORD_TOKEN=/d' /opt/svm/.env
echo 'DISCORD_TOKEN=naya_token_yahan' | sudo tee -a /opt/svm/.env
sudo chmod 600 /opt/svm/.env && sudo systemctl restart svm
```

---

### 🔴 4.3 Privileged Intents OFF → `PrivilegedIntentsRequired`
**Symptom:** bot **online nahi** aata, log me:
```
discord.errors.PrivilegedIntentsRequired: Shard ID None is requesting privileged intents
that have not been explicitly enabled in the developer portal.
```
**Kaaran:** `bot.py` me hai `intents.message_content = True` aur `intents.members = True`.
Developer Portal me ye ON nahi hain to login hi reject ho jaata hai.
**Fix:** §3.6 ka step 3 — **Message Content** + **Server Members** dono ON → Save → `sudo systemctl restart svm`.
> Ye #1 kaaran hai "install ho gaya par bot online nahi aata" ka.

---

### 🟠 4.4 Bot online hai, par `!command` ka koi jawab nahi
1. **v13.3 ka bug** — v13.3 me `bot.py` ke `__main__` me ek "dedupe" loop `bot.remove_command()` se
   `!create`, `!manage`, `!kvm-*`, `!neofetch`, `!vpsmap`, `!ipscan` jaise commands **delete** kar deta tha
   → unknown command = silence. **v13.4 me fix ho chuka hai.**
   → `grep -c "V13 command dedupe" /opt/svm/bot.py` (comment mile = v13.4) ; nahi mile to **v13.4 install karo**.
2. **Message Content Intent OFF** (bot online rehta hai, message padh nahi paata) → §4.3
3. **Prefix galat** — default `!` hai; `.env` me `PREFIX` check karo
4. **Channel permission** — bot ko us channel me *View Channel + Send Messages* nahi hai
5. **Admin command** — `!create`/`!ipool` sirf `MAIN_ADMIN_ID`/admins ke liye; aapka ID galat hai to chup-chaap ignore
6. Typo — v13.4 me `on_command_error` "Did you mean …?" bhejta hai; jawab aana chahiye

```bash
# prefix
sudo grep '^PREFIX=' /opt/svm/.env
# aapka id sahi hai?
sudo grep '^MAIN_ADMIN_ID=' /opt/svm/.env
```

---

### 🟠 4.5 `ModuleNotFoundError: No module named 'discord'` (ya flask/paramiko)
**Kaaran:** venv adhoora bana, ya pip install fail hua (network/disk), ya systemd `python` galat path se chala raha hai.
**Check:**
```bash
sudo /opt/svm/venv/bin/python -c "import discord, dotenv, flask, paramiko, requests; print('imports ok', discord.__version__)"
grep ExecStart /etc/systemd/system/svm.service
```
**Fix:**
```bash
sudo /opt/svm/venv/bin/pip install --upgrade -r /opt/svm/requirements.txt
sudo /opt/svm/venv/bin/pip install "discord.py>=2.3" python-dotenv requests paramiko flask flask-cors pillow
sudo systemctl restart svm
```

---

### 🟠 4.6 Port 5000 already in use → WebSSH/Admin down (bot chalta rehta hai)
**Symptom:** `curl localhost:5000/api/health` fail, log me `OSError: [Errno 98] Address already in use`
**Check / fix:**
```bash
sudo ss -ltnp | grep -E ':5000|:8787'
sudo systemctl stop svm
sudo ss -ltnp | grep :5000      # koi aur process? kill karo
sudo systemctl start svm
```
Doosra instance bhi dekh lo (ye common hai — pehle `screen` me manually chalaya tha):
```bash
pgrep -af 'bot\.py'
```

---

### 🟠 4.7 Discord tak network nahi ja raha → `ClientConnectorError`
**Symptom:** `aiohttp.client_exceptions.ClientConnectorError: Cannot connect to host discord.com:443`
(maine sandbox me yahi error dekha jab outbound block tha)
**Kaaran:** host ka DNS kharab, IPv6 routing tuti hui, provider ne outbound block kiya, ya `/etc/resolv.conf` galat.
**Check:**
```bash
curl -sS -o /dev/null -w '%{http_code}\n' --max-time 8 https://discord.com/api/v10/gateway
getent hosts discord.com
cat /etc/resolv.conf
```
**Fix:**
```bash
echo 'nameserver 1.1.1.1' | sudo tee /etc/resolv.conf
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1   # agar IPv6 toota hua hai
sudo systemctl restart svm
```

---

### 🟡 4.8 Installer khud HEALTH CHECK par mar gaya
**Symptom:** install ke end me:
```
Service unhealthy after upgrade — rolling bot.py back
...
✗ Upgrade failed and there was no previous version to restore
```
**Iska matlab hosting kharab nahi hai** — installer ne service start ki, log me problem mili (usually §4.1–4.5),
aur safe rehne ke liye rollback kar diya. **Files install ho chuki hoti hain.**
**Fix:** `journalctl -u svm -n 100 --no-pager` dekho → jo asli error hai wo fix karo (§4.1–4.7) → `sudo systemctl restart svm`.
Phir installer dobara chalane ki zaroorat nahi.

---

### 🟡 4.9 `svm.service` hi nahi milti / `Unit svm.service not found`
**Kaaran:** installer `install_service` tak pahuncha hi nahi (apt/pip/validation par ruk gaya), ya service doosre naam se hai.
**Check:**
```bash
systemctl list-unit-files | grep -i svm
ls -la /opt/svm /opt/svm/venv/bin/python 2>&1 | head
```
**Fix:** installer dobara chalao aur **pehla error** padho (last line nahi):
```bash
cd /root/svm-src && sudo bash install.sh 2>&1 | tee /root/svm-install.log
grep -nE '✗|Error|error:|FAILED' /root/svm-install.log | head -20
```

---

### 🟡 4.10 `.env` Windows/CRLF ya systemd-incompatible hai
**Symptom:** systemd `Failed to load environment files` ya token me invisible `\r` (login fail).
**Check / fix:**
```bash
sudo file /opt/svm/.env                       # "CRLF line terminators" dikhe to niche wala chalao
sudo sed -i 's/\r$//' /opt/svm/.env
sudo grep -nE '^(export |[A-Za-z_]+ *=)' /opt/svm/.env   # systemd ke liye "KEY=value" hona chahiye
sudo systemctl restart svm
```

---

### 🟡 4.11 systemd hi nahi (OpenVZ / LXC VPS)
```bash
systemctl --version 2>&1 | head -1     # "System has not been booted with systemd" = ye case
```
**Fix:** aisa VPS chhodo (KVM VPS lo). Temporary: `tmux` me manual chalao —
```bash
cd /opt/svm && set -a && . ./.env && set +a && ./venv/bin/python bot.py
```
(par ye reboot par band, aur production ke liye galat hai)

---

### 🟡 4.12 Bot chal raha hai, par provisioning/KVM fail hota hai (bot ki galti nahi)
| Symptom | Kaaran | Check | Fix |
|---|---|---|---|
| `!create` fail | LXD nahi | `lxc storage list` | `sudo bash /opt/svm/source/install.sh lxd-init` |
| `!kvm-*` fail | `/dev/kvm` nahi | `ls -l /dev/kvm` | nested-virt KVM VPS lo; `sudo bash install.sh --with-virt` |
| KVM image missing | qcow2 nahi | `ls /var/lib/svm/images` | `KVM_BASE_IMAGE` path par cloud image rakho |
| `/admin` blank / 404 | `admin.html` nahi | `ls /opt/svm/admin.html` | `sudo bash install.sh` dobara |
| `/admin` "password not set" | `ADMIN_WEB_PASSWORD` khaali | `sudo svm admin-password` | naya password set karo |
| `!askai` dead | LocalAI nahi (default skip) | `sudo bash install.sh ai-status` | `sudo bash install.sh --with-ai` (multi-GB download) |

---

## 5. Ek command me poora diagnosis

Is repo me `diagnose.sh` diya hai — ye **kuch change nahi karta**, sirf padhta hai aur verdict deta hai.

**File VPS par kaise le jaayein** (repo clone karne ke bajaye):

```bash
# apne laptop se:
scp diagnose.sh root@YOUR_SERVER_IP:/root/
# ya VPS par nano kholo aur content paste kar do:
nano /root/diagnose.sh
```

Chalane ka tarika:

```bash
sudo bash /root/diagnose.sh                 # default /opt/svm
sudo SVM_DIR=/kuch/alag/path bash diagnose.sh   # custom install path
```

Ye check karta hai: OS/kernel/systemd, python+venv, `/opt/svm` files, `.env` (token masked, admin id, prefix,
ports), service state + restart count, journal ka asli error (intents/token/module/port), port 5000/8787,
`/api/health`, DB schema, LXD, `/dev/kvm`, discord.com connectivity, duplicate instances, disk/RAM.
Aakhir me **"VERDICT"** section me seedha batata hai kya galat hai aur kya command chalani hai.

---

## 6. Rozana ke commands (cheat sheet)

```bash
# service
sudo systemctl status svm            # state + last exit
sudo systemctl restart svm           # restart
sudo systemctl stop svm              # stop
journalctl -u svm -n 100 --no-pager   # logs
journalctl -u svm -f                 # live logs

# built-in CLI (/usr/local/bin/svm)
svm status        # bot + webhook status
svm doctor        # token, webssh, admin.html, db schema, kvm, ports, webhook
svm logs          # journal tail
svm restart
svm config        # edit .env
svm env DISCORD_TOKEN
svm backup        # DB + .env + code snapshot
svm rollback      # last snapshot wapas
svm update        # git pull + deploy
svm admin-password   # naya web admin password
svm ai-status | ai-models | ai-doctor

# installer ke extra modes
sudo bash install.sh --configure      # sirf wizard
sudo bash install.sh upgrade          # bina sawaal upgrade (LocalAI skip, LXD auto)
sudo bash install.sh upgrade --with-ai
sudo bash install.sh doctor
sudo bash install.sh backup
sudo bash install.sh rollback
sudo bash install.sh lxd-status
sudo bash install.sh test             # unit tests
```

---

## 7. Upgrade (v13.3 → v13.4) — data safe

```bash
sudo bash /opt/svm/source/install.sh backup        # pehle backup
cd /root && unzip -o Svm-v13.4-bot.zip -d svm-v134 && cd svm-v134
sudo bash install.sh upgrade                        # .env + vps.db ko chhoota nahi
sudo systemctl restart svm
svm doctor
```
Rollback: `sudo bash /opt/svm/source/install.sh rollback` → phir `systemctl restart svm`.

`upgrade` ka behaviour (v13.4): sawaal nahi poochhta, LocalAI skip, LXD agar pehle se init hai to **touch nahi karta**,
`.env` ke purane values preserve karta hai, sirf naye keys add karta hai.

---

## 8. Security (padh lo, ye bot root me chalta hai)

- Bot **root** ke roop me chalta hai (`User=root`), kyunki LXC/iptables/libvirt host par control karta hai.
  Isliye VPS sirf isi kaam ke liye rakho.
- `install.sh` root me `apt-get` + `snap install lxd` karta hai — **bharose ka source** hona chahiye.
  Pehle `less install.sh` se padh lo.
- `.env` me token, Razorpay secret, admin password sab hai → `chmod 600`, kabhi GitHub par commit na karo.
- `:5000` par WebSSH/Admin bina HTTPS ke khula hota hai → public internet par directly na kholo;
  Caddy/Nginx + HTTPS lagao (`SVM_PUBLIC_URL=https://…` set karke installer Caddy option deta hai).
- `8787` webhook **0.0.0.0** par plain HTTP — HTTPS proxy ke peeche rakho.
- `/admin` password ek hi baar install ke end me print hota hai — likh lo, warna `svm admin-password`.

---

## 9. FAQ chhota

**Q: `Svm-v13.3-bot.zip` hai, chalega?**
Chalega, par usme **commands silent** hone ka bug hai (§4.4). **v13.4 lo.**

**Q: GitHub "Download ZIP" kiya, `install.sh` mila hi nahi?**
Wo repo ka zip hai, app ka nahi. App zip = `Svm-v13.4-bot.zip` (repo ke andar).

**Q: Root ke bina chal sakta hai?**
Nahi. `install.sh` `id -u == 0` check karke `Run as root` bolta hai.

**Q: Install ke baad bot Discord par online hai par `!help` kuch nahi?**
`PREFIX` (default `!`) + Message Content Intent + channel permission — §4.4.

**Q: `!create` "LXD not available" bolta hai?**
`sudo bash /opt/svm/source/install.sh lxd-init` (snap wale VPS chahiye). Bot phir bhi chalega.

**Q: payments nahi chahiye?**
Wizard me Razorpay/Stripe/UPI skip kar do; `PAYMENT_GATEWAYS` khaali. Plans/prices phir bhi set kar sakte ho.

**Q: DB kahan hai?**
`/opt/svm/vps.db` (sqlite). Backup: `svm backup` — rozana 03:00-ish timer bhi laga hota hai.

---

*Guide is repo ke code (v13.4) se banayi gayi hai. Jo cheez "verified" nahi thi, use verified bata kar nahi likha gaya.*
