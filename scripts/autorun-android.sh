#!/data/data/com.termux/files/usr/bin/env bash
# ~/.termux/boot/startup.sh

# ——— CONFIG —————————————————————————————————————————————
[ -f "$HOME/.env" ] && source "$HOME/.env"

LOGDIR="$HOME/termux-boot-logs"
mkdir -p "$LOGDIR"

COPYPARTY_DIR="$HOME/copyparty"
MYFILES_DIR="$HOME/myfiles"

EMAIL_TO="ashutoshsharmawhy@gmail.com"
EMAIL_FROM="alexmerser591@gmail.com"
# ensure GMAIL_APP_PASSWORD is defined in ~/.env

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

# ——— NETWORK CHECK (optional, uncomment if needed) ——————
# wait_for_net() {
#   echo "$(timestamp) Forcing radios on…" >> "$LOGDIR/general.log"
#   svc wifi enable
#   svc data enable
# 
#   echo "$(timestamp) Waiting for network (up to 3 min) ..." >> "$LOGDIR/general.log"
#   for i in $(seq 1 36); do
#     if dumpsys connectivity | grep -q "NetworkAgentInfo.*state=CONNECTED"; then
#       echo "$(timestamp) Network is up." >> "$LOGDIR/general.log"
#       return 0
#     fi
#     sleep 5
#   done
#   echo "$(timestamp) ⚠️ Network did not come up after 3 min, continuing anyway." >> "$LOGDIR/general.log"
# }

# ——— DAEMON STARTER —————————————————————————————————————
start_if_needed() {
  local name="$1"; shift
  local pgrep_pat="$1"; shift
  local cmd=( "$@" )
  local logfile="$LOGDIR/${name}_$(timestamp).log"

  if pgrep -f "$pgrep_pat" >/dev/null; then
    echo "$(timestamp) [$name] already running, skipping." >> "$LOGDIR/general.log"
  else
    echo "$(timestamp) [$name] starting…" >> "$LOGDIR/general.log"
    "${cmd[@]}" >> "$logfile" 2>&1 &
    echo "$(timestamp) [$name] PID=$! (log: $logfile)" >> "$LOGDIR/general.log"
  fi
}

# ——— SEND EMAIL ———————————————————————————————————————
send_email() {
  local url="$1"
  {
    echo "From: $EMAIL_FROM"
    echo "To: $EMAIL_TO"
    echo "Subject: 🔗 Copyparty Link"
    echo "MIME-Version: 1.0"
    echo "Content-Type: text/html; charset=UTF-8"
    echo
    cat <<EOF
<html>
  <body style="font-family:sans-serif; line-height:1.4;">
    <p>Your Copyparty URL is:</p>
    <p><a href="$url" target="_blank">$url</a></p>
  </body>
</html>
EOF
  } | curl --url 'smtps://smtp.gmail.com:465' \
           --ssl-reqd \
           --mail-from "$EMAIL_FROM" \
           --mail-rcpt "$EMAIL_TO" \
           --user "$EMAIL_FROM:$GMAIL_APP_PASSWORD" \
           -T - >> "$LOGDIR/general.log" 2>&1
}

# ——— MAIN ——————————————————————————————————————————————
# wait_for_net

start_if_needed "sshd" "sshd:.*8022" sshd

start_if_needed "copyparty" "python -m copyparty" bash -c "
  cd \"$COPYPARTY_DIR\" && exec python -m copyparty \
    -a admin:ashu \
    -v \"$MYFILES_DIR/public\":/public:r,'*':A,admin \
    -v \"$MYFILES_DIR\"::A,admin \
    --https --qr -s -e2dsa --xff-hdr cf-connecting-ip \
    --q-mp3=q3 --th-ram-max=2
"

# --- START CLOUDFLARED AND WATCH FOR URL ---
if pgrep -f "cloudflared tunnel" >/dev/null; then
  echo "$(timestamp) [cloudflared] already running, skipping." >> "$LOGDIR/general.log"
else
  # Define the log file for this specific instance
  CLOUDFLARED_LOG="$LOGDIR/cloudflared_$(timestamp).log"

  echo "$(timestamp) [cloudflared] starting…" >> "$LOGDIR/general.log"
  
  # Start cloudflared in the background, sending all output to its log
  cloudflared tunnel --url https://127.0.0.1:3923 --no-tls-verify >> "$CLOUDFLARED_LOG" 2>&1 &
  
  echo "$(timestamp) [cloudflared] PID=$! (log: $CLOUDFLARED_LOG)" >> "$LOGDIR/general.log"

  # Start a background watcher for the URL
  (
    echo "$(timestamp) Waiting for Cloudflare URL in $CLOUDFLARED_LOG..." >> "$LOGDIR/general.log"
    
    # Wait max 2 minutes for the URL to appear in the log file
    # grep -m 1 makes it stop after the first match
    url=$(timeout 120 tail -f "$CLOUDFLARED_LOG" | grep -m 1 -oE 'https://[a-z0-9.-]+\.trycloudflare\.com')

    if [[ -n "$url" ]]; then
      echo "$(timestamp) Found URL: $url" >> "$LOGDIR/general.log"
      send_email "$url"
    else
      echo "$(timestamp) ⚠️ Timed out waiting for TryCloudflare URL." >> "$LOGDIR/general.log"
    fi
  ) &
fi


echo "$(timestamp) All startup tasks dispatched." >> "$LOGDIR/general.log"