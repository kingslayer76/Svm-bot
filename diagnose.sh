#!/usr/bin/env bash
# =============================================================================
#  SVM Bot — READ-ONLY DIAGNOSTIC
#  Kuch bhi change nahi karta. Sirf padhta hai aur batata hai kya galat hai.
#
#  Run:  sudo bash diagnose.sh
#  (root ke bina bhi chal jayega, par kuch cheezein "unknown" dikhengi)
#
#  Made for SVM Advanced AI v13.4 installs at /opt/svm (systemd service: svm)
# =============================================================================

APP_DIR="${SVM_DIR:-/opt/svm}"
SERVICE="${SVM_SERVICE:-svm}"
ENV_FILE="$APP_DIR/.env"
WEB_PORT_HINT="5000"
HOOK_PORT_HINT="8787"

OK_N=0; BAD_N=0; WARN_N=0
ISSUES=()

if [ -t 1 ]; then
  R=$'\033[0m'; B=$'\033[1m'; C=$'\033[36m'; G=$'\033[32m'; Y=$'\033[33m'; E=$'\033[31m'
else
  R=''; B=''; C=''; G=''; Y=''; E=''
fi

sec()  { printf '\n%s%s━━━ %s ━━━%s\n' "$B" "$C" "$*" "$R"; }
ok()   { OK_N=$((OK_N+1));   printf '  %s✓%s %s\n' "$G" "$R" "$*"; }
bad()  { BAD_N=$((BAD_N+1)); printf '  %s✗%s %s\n' "$E" "$R" "$*"; ISSUES+=("$*"); }
warn() { WARN_N=$((WARN_N+1)); printf '  %s!%s %s\n' "$Y" "$R" "$*"; }
note() { printf '      %s\n' "$*"; }

envval() { [ -f "$ENV_FILE" ] || return 0; grep -E "^[[:space:]]*$1=" "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- | tr -d '\r' | sed -E "s/^['\"]//; s/['\"]$//"; }
mask()   { local v="$1"; if [ ${#v} -le 10 ]; then printf '***'; else printf '%s…%s' "${v:0:6}" "${v: -4}"; fi; }

printf '\n%s%s  SVM BOT DIAGNOSTIC%s\n' "$B" "$C" "$R"
printf '  %s\n' "$(date -u '+%Y-%m-%d %H:%M UTC')"
printf '  app dir: %s   service: %s\n' "$APP_DIR" "$SERVICE"

# ─────────────────────────────────────────────────────────────────────────────
sec "1. HOST / OS"
OS_NAME="$( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}" )"
note "OS      : $OS_NAME"
note "Kernel  : $(uname -r)   Arch: $(uname -m)"
note "KVM?    : $( [ -c /dev/kvm ] && echo yes || echo 'no (KVM feature is off)' )"
if command -v systemd-detect-virt >/dev/null 2>&1; then
  VIRT="$(systemd-detect-virt 2>/dev/null || echo none)"
  note "Virt    : $VIRT"
  case "$VIRT" in
    openvz|lxc|lxc-libvirt|docker|podman) warn "Container/VPS type '$VIRT' — isme systemd, snap, iptables aksar kaam nahi karte. KVM VPS recommended." ;;
  esac
fi
case "$(uname -m)" in x86_64|aarch64) ok "Architecture supported ($(uname -m))" ;; *) warn "Arch $(uname -m) — x86_64 recommended" ;; esac
MEM_MB="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)"
DISK_GB="$(df -BG --output=avail "$APP_DIR" 2>/dev/null | tail -n1 | tr -dc '0-9')" ; [ -n "$DISK_GB" ] || DISK_GB="$(df -BG --output=avail / 2>/dev/null | tail -n1 | tr -dc '0-9')"
note "RAM     : ${MEM_MB} MB    Free disk: ${DISK_GB:-?} GB"
[ "${MEM_MB:-0}" -ge 1800 ] 2>/dev/null && ok "RAM >= 1.8 GB" || warn "RAM ${MEM_MB} MB — 2 GB se kam par pip/LXD OOM ho sakta hai"
[ "${DISK_GB:-0}" -ge 5 ] 2>/dev/null && ok "Disk free >= 5 GB" || bad "Disk almost full (${DISK_GB:-?} GB) — pip install / DB write fail honge"

if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  ok "systemd present (PID 1 standard)"
else
  bad "systemd nahi mila — service install/start nahi hoga. KVM VPS chahiye (OpenVZ/LXC container nahi)."
fi

# ─────────────────────────────────────────────────────────────────────────────
sec "2. FILES (/opt/svm)"
if [ -d "$APP_DIR" ]; then
  ok "Directory present: $APP_DIR"
  for f in bot.py svm12.py requirements.txt .env webssh.html admin.html; do
    if [ -f "$APP_DIR/$f" ]; then ok "$f present ($(stat -c '%s' "$APP_DIR/$f" 2>/dev/null) bytes)"
    else
      case "$f" in
        admin.html) bad "admin.html MISSING — /admin 404 dega. Fix: sudo bash $APP_DIR/source/install.sh" ;;
        .env)       bad ".env MISSING — bot ke paas token/config nahi. Fix: sudo bash $APP_DIR/source/install.sh --configure" ;;
        *)          bad "$f MISSING — install adhoora hai. Fix: installer dobara chalao (§4.9 of guide)" ;;
      esac
    fi
  done
  [ -d "$APP_DIR/venv" ] && ok "venv present ($APP_DIR/venv)" || bad "venv MISSING — Fix: sudo bash $APP_DIR/source/install.sh"
  [ -d "$APP_DIR/backups" ] && note "Backups: $(ls -1 "$APP_DIR/backups" 2>/dev/null | wc -l) snapshot(s)"
  [ -f "$APP_DIR/vps.db" ] && ok "Database present: $APP_DIR/vps.db ($(du -h "$APP_DIR/vps.db" 2>/dev/null | cut -f1))" || warn "vps.db abhi nahi bana (pehli baar bot chalne par banega)"
else
  bad "$APP_DIR nahi mila — install hi nahi hua, ya SVM_DIR alag hai. Fix: sudo bash install.sh"
fi

# ─────────────────────────────────────────────────────────────────────────────
sec "3. PYTHON / DEPENDENCIES"
if command -v python3 >/dev/null 2>&1; then
  PYV="$(python3 -c 'import sys;print("%d.%d.%d"%sys.version_info[:3])' 2>/dev/null)"
  note "system python3: $PYV"
  python3 -c 'import sys; exit(0 if sys.version_info >= (3,9) else 1)' 2>/dev/null \
    && ok "Python >= 3.9" || bad "Python $PYV < 3.9 — installer fail karega. python3.11 install karo."
fi
VPY=""
for cand in "$APP_DIR/venv/bin/python3" "$APP_DIR/venv/bin/python"; do
  [ -x "$cand" ] && { VPY="$cand"; break; }
done
if [ -n "$VPY" ]; then
  ok "venv python: $VPY ($("$VPY" -V 2>&1))"
  IMP="$("$VPY" - <<'PY' 2>&1
mods = ["discord","dotenv","requests","paramiko","flask","flask_cors","PIL"]
missing = []
for m in mods:
    try:
        __import__(m)
    except Exception:
        missing.append(m)
print("MISSING:" + ",".join(missing) if missing else "ALL_OK")
PY
)"
  case "$IMP" in
    ALL_OK) ok "Saare Python modules import ho rahe hain (discord, dotenv, requests, paramiko, flask, flask_cors, PIL)" ;;
    MISSING:*) bad "Modules missing → $IMP  |  Fix: sudo $APP_DIR/venv/bin/pip install --upgrade -r $APP_DIR/requirements.txt" ;;
    *) bad "venv python me import test fail: $(printf '%s' "$IMP" | head -2 | tr '\n' ' ')" ;;
  esac
else
  bad "venv python nahi mila — Fix: sudo bash $APP_DIR/source/install.sh"
fi

# ─────────────────────────────────────────────────────────────────────────────
sec "4. CONFIG (.env)"
if [ -f "$ENV_FILE" ]; then
  PERM="$(stat -c '%a' "$ENV_FILE" 2>/dev/null)"
  [ "$PERM" = "600" ] && ok ".env permissions 600 (theek)" || warn ".env permissions $PERM hain, 600 hona chahiye: sudo chmod 600 $ENV_FILE"
  if grep -q $'\r' "$ENV_FILE" 2>/dev/null; then
    bad ".env me Windows CRLF line endings hain — systemd/token toot sakta hai. Fix: sudo sed -i 's/\r$//' $ENV_FILE && sudo systemctl restart $SERVICE"
  else
    ok "Line endings theek (LF)"
  fi

  TOK="$(envval DISCORD_TOKEN)"
  if [ -z "$TOK" ]; then
    bad "DISCORD_TOKEN KHAALI hai → bot exit ho jayega (verified: '[ERROR] No valid Discord token found!', exit 1)"
    note "Fix: sudo bash $APP_DIR/source/install.sh --configure   (token + MAIN_ADMIN_ID daalo)"
  elif [ "$TOK" = "your_discord_bot_token_here" ]; then
    bad "DISCORD_TOKEN abhi bhi placeholder hai — real token daalo"
  elif printf '%s' "$TOK" | grep -qE '[[:space:]"'"'"']'; then
    bad "DISCORD_TOKEN me space/quote hai (${#TOK} chars) — quotes hatao, sirf token rakho"
  else
    TLEN=${#TOK}
    if [ "$TLEN" -ge 60 ] && [ "$TLEN" -le 100 ]; then
      ok "DISCORD_TOKEN set aur format theek lagta hai ($(mask "$TOK"), $TLEN chars)"
    else
      warn "DISCORD_TOKEN set hai par length $TLEN unusual hai (normal ~70-80) — token adhoora ho sakta hai"
    fi
  fi

  ADM="$(envval MAIN_ADMIN_ID)"
  if [ -z "$ADM" ]; then
    warn "MAIN_ADMIN_ID khaali — bot code me hardcoded ID (1210291131301101618) use hoga; admin commands aapke liye kaam nahi karenge"
    note "Fix: .env me MAIN_ADMIN_ID=<aapka numeric user id> daalo"
  elif printf '%s' "$ADM" | grep -qE '^[0-9]{15,21}$'; then
    ok "MAIN_ADMIN_ID set ($ADM)"
  else
    bad "MAIN_ADMIN_ID '$ADM' numeric 15-21 digit nahi hai — installer validate karega nahi, par admin commands fail hongi"
  fi

  PREFIX_SHOW="$(envval PREFIX)"; PREFIX_SHOW="${PREFIX_SHOW:-!}"
  BOTNAME_SHOW="$(envval BOT_NAME)"; BOTNAME_SHOW="${BOTNAME_SHOW:-<unset>}"
  VER_SHOW="$(envval BOT_VERSION)"; VER_SHOW="${VER_SHOW:-<unset>}"
  note "PREFIX=${PREFIX_SHOW}  BOT_NAME=${BOTNAME_SHOW}  VERSION=${VER_SHOW}"
  note "WEBSSH_PORT=$(envval WEBSSH_PORT)  IPAM_BIND_MODE=$(envval IPAM_BIND_MODE)  PORTS=$(envval PORT_RANGE_START)-$(envval PORT_RANGE_END)"
  WEP="$(envval WEBSSH_PORT)"; WEB_PORT_HINT="${WEP:-5000}"
  HOP="$(envval PAYMENT_WEBHOOK_PORT)"; HOOK_PORT_HINT="${HOP:-8787}"
  [ -n "$(envval ADMIN_WEB_PASSWORD)" ] && ok "ADMIN_WEB_PASSWORD set (/admin login chalega)" || warn "ADMIN_WEB_PASSWORD khaali — /admin login nahi karega. Fix: sudo svm admin-password"
  [ -n "$(envval YOUR_SERVER_IP)" ] && ok "YOUR_SERVER_IP=$(envval YOUR_SERVER_IP)" || warn "YOUR_SERVER_IP khaali — links me 127.0.0.1 dikhega"
else
  bad ".env nahi mila — Fix: sudo bash $APP_DIR/source/install.sh --configure"
fi

# ─────────────────────────────────────────────────────────────────────────────
sec "5. SERVICE (systemd: $SERVICE)"
UNIT="/etc/systemd/system/${SERVICE}.service"
if [ -f "$UNIT" ]; then
  ok "Unit file present: $UNIT"
  ES="$(grep -E '^ExecStart=' "$UNIT" | cut -d= -f2-)"
  note "ExecStart: $ES"
  case "$ES" in
    "$APP_DIR/venv/bin/python"*) ok "ExecStart venv python use kar raha hai" ;;
    *) warn "ExecStart expected nahi hai (venv python nahi). Fix: sudo bash $APP_DIR/source/install.sh" ;;
  esac
  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    ST="$(systemctl is-active "$SERVICE" 2>/dev/null)"
    EN="$(systemctl is-enabled "$SERVICE" 2>/dev/null)"
    case "$ST" in
      active)   ok "Service ACTIVE chal rahi hai" ;;
      activating) warn "Service 'activating' — restart loop me hai (logs dekho)" ;;
      failed)   bad "Service FAILED hai — Fix: journal dekho, root cause fix karo, phir 'sudo systemctl restart $SERVICE'" ;;
      *)        bad "Service state: ${ST:-unknown} — start karo: sudo systemctl start $SERVICE" ;;
    esac
    [ "$EN" = "enabled" ] && ok "Boot par enabled" || warn "Service enabled nahi ($EN) — Fix: sudo systemctl enable $SERVICE"
    if command -v systemctl >/dev/null 2>&1; then
      RC="$(systemctl show -p NRestarts --value "$SERVICE" 2>/dev/null)"
      [ -n "$RC" ] && { [ "$RC" -gt 3 ] 2>/dev/null && warn "Restart count: $RC (baar-baar crash ho raha hai)" || note "Restart count: $RC"; }
      EX="$(systemctl show -p ExecMainStatus --value "$SERVICE" 2>/dev/null)"
      [ -n "$EX" ] && note "Last exit code: $EX   $( [ "$EX" = "1" ] && echo '(1 = bot ne khud exit kiya: token/config galat)' )"
    fi
  fi
else
  bad "Unit file nahi mila ($UNIT) — installer systemd step tak pahuncha hi nahi. Fix: sudo bash install.sh (pehla error padho)"
fi

# ─────────────────────────────────────────────────────────────────────────────
sec "6. LOGS (asli error yahan milega)"
LOGS=""
if command -v journalctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  LOGS="$(journalctl -u "$SERVICE" -n 250 --no-pager 2>/dev/null)"
fi
if [ -z "$LOGS" ]; then
  for lf in "$APP_DIR/logs/"*.log "/var/log/svm.log"; do [ -f "$lf" ] && LOGS="$LOGS$(tail -n 250 "$lf" 2>/dev/null)"; done
fi
if [ -z "$LOGS" ]; then
  warn "Koi log nahi mila (service kabhi chali hi nahi ho sakti)"
else
  found=0
  if printf '%s' "$LOGS" | grep -q 'PrivilegedIntentsRequired'; then
    found=1; bad "LOG: PrivilegedIntentsRequired → Discord Developer Portal me MESSAGE CONTENT INTENT + SERVER MEMBERS INTENT ON karo, phir restart"
  fi
  if printf '%s' "$LOGS" | grep -qE 'No valid Discord token|DISCORD_TOKEN in .env is currently set to: None'; then
    found=1; bad "LOG: token missing → .env me DISCORD_TOKEN daalo (sudo bash $APP_DIR/source/install.sh --configure)"
  fi
  if printf '%s' "$LOGS" | grep -qE 'LoginFailure|Improper token|401 Unauthorized|Unauthorized'; then
    found=1; bad "LOG: token galat/expired → Developer Portal se naya token lo, quotes ke bina .env me daalo"
  fi
  if printf '%s' "$LOGS" | grep -qE 'ModuleNotFoundError|ImportError'; then
    found=1; bad "LOG: Python module missing → sudo $APP_DIR/venv/bin/pip install --upgrade -r $APP_DIR/requirements.txt"
  fi
  if printf '%s' "$LOGS" | grep -qE 'Address already in use'; then
    found=1; bad "LOG: port already in use → sudo ss -ltnp | grep -E ':5000|:8787' ; purana process kill karo"
  fi
  if printf '%s' "$LOGS" | grep -qE 'ClientConnectorError|Cannot connect to host discord|Temporary failure in name resolution'; then
    found=1; bad "LOG: network/DNS problem (discord.com reachable nahi) → DNS/outbound fix karo (§4.7)"
  fi
  if printf '%s' "$LOGS" | grep -qE 'PermissionError.*vps\.db|database is locked'; then
    found=1; bad "LOG: DB permission/lock issue → service band karke permissions theek karo: sudo chown -R root:root $APP_DIR"
  fi
  if printf '%s' "$LOGS" | grep -q 'SyntaxError'; then
    found=1; bad "LOG: SyntaxError → bot.py corrupt/adhoora deploy hua. Installer dobara chalao"
  fi
  if [ "$found" = "0" ]; then
    ok "Log me koi known fatal pattern nahi mila"
    note "Last 5 lines:"
    printf '%s\n' "$LOGS" | tail -n 5 | sed 's/^/        /'
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
sec "7. PORTS / WEB PANEL"
if command -v ss >/dev/null 2>&1; then
  for p in "$WEB_PORT_HINT" "$HOOK_PORT_HINT"; do
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${p}$"; then
      ok "Port $p listening"
    else
      case "$p" in
        5000) bad "Port $p (WebSSH/Admin) listening nahi — bot chal raha hai? Mgmt: sudo ss -ltnp | grep :$p" ;;
        *)    warn "Port $p (webhook) listening nahi — payments webhook band rahega (sirf zaroori ho to)" ;;
      esac
    fi
  done
fi
if command -v curl >/dev/null 2>&1; then
  H="$(curl -fsS --max-time 4 "http://127.0.0.1:${WEB_PORT_HINT}/api/health" 2>/dev/null)"
  if [ -n "$H" ]; then
    ok "Web panel jawab de raha hai: $H"
    printf '%s' "$H" | grep -q '"admin_panel": *true'  || warn "/admin login ready nahi (ADMIN_WEB_PASSWORD?) → sudo svm admin-password"
    printf '%s' "$H" | grep -q '"admin_html": *true'   || bad "admin.html server ko nahi mila → installer dobara chalao"
  else
    bad "http://127.0.0.1:${WEB_PORT_HINT}/api/health jawab nahi de raha — Flask thread nahi chala (bot ke logs dekho)"
  fi
fi
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q 'Status: active'; then
  note "ufw active — rules:"; ufw status 2>/dev/null | grep -E '5000|8787|20000' | sed 's/^/        /' || note "  5000/8787/20000-50000 ke rules nahi dikhe → sudo ufw allow 5000/tcp"
fi
note "Cloud provider firewall/security-group bhi check karo (ufw kaafi nahi)."

# ─────────────────────────────────────────────────────────────────────────────
sec "8. DATABASE"
if [ -f "$APP_DIR/vps.db" ] && command -v sqlite3 >/dev/null 2>&1; then
  V="$(sqlite3 "$APP_DIR/vps.db" 'select coalesce(max(version),0) from svm_schema_migrations' 2>/dev/null)"
  if [ -n "$V" ]; then
    [ "$V" -ge 12007 ] 2>/dev/null && ok "DB schema v$V (migrations applied)" || warn "DB schema v$V — expected >=12007; bot pehli baar chalne par migrate karega"
  else
    warn "svm_schema_migrations table nahi mila — DB purana/khaali hai"
  fi
  I="$(sqlite3 "$APP_DIR/vps.db" 'pragma integrity_check' 2>/dev/null | head -1)"
  [ "$I" = "ok" ] && ok "DB integrity OK" || bad "DB integrity problem: $I  (backup: $APP_DIR/db_backups)"
else
  [ -f "$APP_DIR/vps.db" ] && warn "sqlite3 binary nahi hai (apt install sqlite3) — DB check skip" || warn "vps.db abhi nahi bana"
fi

# ─────────────────────────────────────────────────────────────────────────────
sec "9. VIRTUALIZATION (sirf VPS provisioning ke liye)"
if command -v lxc >/dev/null 2>&1; then
  ok "lxc CLI present ($(lxc --version 2>/dev/null || echo '?'))"
  POOLS="$(lxc storage list --format csv 2>/dev/null | cut -d, -f1 | sed '/^$/d' | tr '\n' ' ')"
  [ -n "$POOLS" ] && ok "LXD pools: $POOLS" || warn "LXD init nahi hua → sudo bash $APP_DIR/source/install.sh lxd-init"
  lxc network list 2>/dev/null | grep -q . || warn "LXD network list khaali — lxdbr0 missing?"
else
  warn "lxc/LXD nahi mila — '!create' (LXC) kaam nahi karega. Fix: sudo bash $APP_DIR/source/install.sh lxd-init"
fi
[ -c /dev/kvm ] && ok "/dev/kvm present — KVM feature available" || warn "/dev/kvm nahi — '!kvm-*' kaam nahi karega (KVM VPS + nested virt chahiye)"
command -v virsh  >/dev/null 2>&1 && ok "virsh present" || warn "virsh/libvirt nahi (KVM ke liye: sudo bash install.sh --with-virt)"
[ -f "${SVM_KVM_IMAGE:-/var/lib/svm/images/ubuntu-22.04-cloudimg.qcow2}" ] && ok "KVM base image mil gaya" || warn "KVM base qcow2 nahi mila (KVM_BASE_IMAGE path) — KVM create fail hoga"

# ─────────────────────────────────────────────────────────────────────────────
sec "10. CONNECTIVITY"
if command -v curl >/dev/null 2>&1; then
  CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 8 https://discord.com/api/v10/gateway 2>/dev/null)"
  case "$CODE" in
    200|401|403|429) ok "discord.com reachable (HTTP $CODE)" ;;
    "") bad "discord.com reachable NAHI — DNS/firewall/IPv6 issue (§4.7). Bot kabhi online nahi aayega" ;;
    *)  warn "discord.com HTTP $CODE — proxy/firewall check karo" ;;
  esac
  DNSIP="$(getent hosts discord.com 2>/dev/null | head -1 | awk '{print $1}')"
  note "DNS resolve: ${DNSIP:-FAILED}"
fi
MB="$(pgrep -fc 'bot\.py' 2>/dev/null || true)"
if [ "${MB:-0}" -gt 1 ] 2>/dev/null; then
  warn "$MB bot.py processes chal rahe hain (duplicate!) — ek hi rakhna chahiye"; pgrep -af 'bot\.py' 2>/dev/null | sed 's/^/        /'
elif [ "${MB:-0}" = "1" ]; then
  ok "Sirf 1 bot.py process"
fi

# ─────────────────────────────────────────────────────────────────────────────
sec "VERDICT"
if [ "$BAD_N" -eq 0 ]; then
  printf '  %s✓ Koi fatal problem nahi mili.%s\n' "$G" "$R"
  [ "$WARN_N" -gt 0 ] && printf '  %s! %d warning(s) hain (upar dekho).%s\n' "$Y" "$WARN_N" "$R"
  printf '  Discord me bot online hai par command jawab nahi de raha? → PREFIX + Message Content Intent + channel permission check karo.\n'
else
  printf '  %s✗ %d problem(s) mili — upar se neeche fix karo:%s\n' "$E" "$BAD_N" "$R"
  i=0
  for msg in "${ISSUES[@]}"; do i=$((i+1)); printf '   %d) %s\n' "$i" "$msg"; done
  printf '\n  Useful next commands:\n'
  printf '    sudo systemctl status %s --no-pager\n' "$SERVICE"
  printf '    sudo journalctl -u %s -n 100 --no-pager\n' "$SERVICE"
  printf '    sudo bash %s/source/install.sh --configure\n' "$APP_DIR"
  printf '    sudo systemctl restart %s\n' "$SERVICE"
fi
printf '\n  %sSummary:%s %d OK · %d warning · %d problem\n\n' "$B" "$R" "$OK_N" "$WARN_N" "$BAD_N"
