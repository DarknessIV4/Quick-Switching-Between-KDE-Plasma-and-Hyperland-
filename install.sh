#!/bin/bash
# install.sh - KDE Plasma <-> Hyprland session switcher (terminal menus)
set -u

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user, not root (it calls sudo itself)."; exit 1
fi
if [ ! -t 0 ] || [ ! -t 1 ]; then
  echo "Run this as a file in a terminal:  bash install.sh"; exit 1
fi
command -v sudo >/dev/null 2>&1 || { echo "sudo is required."; exit 1; }

# ---------------- terminal helpers ----------------
CHOICE=0
menu() {   # menu "Question" "option 1" "option 2" ...   -> sets CHOICE (1-based)
  local q=$1 n i ans; shift; n=$#
  echo; echo "$q"
  i=1; for o in "$@"; do echo "  $i) $o"; i=$((i+1)); done
  while :; do
    read -r -p "Choose [1-$n]: " ans || { echo; echo "No input - aborting."; exit 1; }
    case "$ans" in
      ''|*[!0-9]*) ;;
      *) if [ "$ans" -ge 1 ] && [ "$ans" -le "$n" ]; then CHOICE=$ans; return; fi ;;
    esac
    echo "Please enter a number from 1 to $n."
  done
}
ask_text() {   # ask_text "prompt" "default" -> sets ANSWER (no subshell, so EOF really aborts)
  local a; read -r -p "$1 [$2]: " a || { echo; echo "No input - aborting."; exit 1; }
  ANSWER=${a:-$2}
}
ask_key() {    # ask_key "prompt" "default" VARNAME -> shortcut text; re-asks if it contains " or \
  local v
  while :; do
    ask_text "$1" "$2"; v=$ANSWER
    case "$v" in
      *\"*|*\\*) echo "Please don't use double quotes or backslashes in a shortcut." ;;
      *) break ;;
    esac
  done
  printf -v "$3" '%s' "$v"
}

echo "=== KDE Plasma <-> Hyprland session switcher ==="

# ---------------- detect sessions ----------------
command -v sddm >/dev/null 2>&1 || { echo "ERROR: SDDM not found - this setup needs SDDM."; exit 1; }

PLASMA_LIST=(); HYPR_LIST=()
for d in /usr/share/wayland-sessions /usr/local/share/wayland-sessions; do
  [ -d "$d" ] || continue
  for f in "$d"/*.desktop; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    ex=$(grep -m1 -i '^Exec=' "$f" 2>/dev/null)
    if [[ "$b" == hyprland*.desktop ]] || grep -qi 'hyprland' <<<"$ex"; then
      HYPR_LIST+=("$f")
    elif [[ "$b" == plasma*.desktop ]] || grep -qi 'startplasma' <<<"$ex"; then
      PLASMA_LIST+=("$f")
    fi
  done
done

echo; echo "Detected Wayland sessions:"
echo "  Plasma   : $( [ ${#PLASMA_LIST[@]} -gt 0 ] && printf '%s ' "${PLASMA_LIST[@]##*/}" || echo 'NONE')"
echo "  Hyprland : $( [ ${#HYPR_LIST[@]} -gt 0 ] && printf '%s ' "${HYPR_LIST[@]##*/}" || echo 'NONE')"
if [ ${#PLASMA_LIST[@]} -eq 0 ] || [ ${#HYPR_LIST[@]} -eq 0 ]; then
  echo; echo "ERROR: both a Plasma and a Hyprland Wayland session are required. All sessions found:"
  ls /usr/share/wayland-sessions /usr/local/share/wayland-sessions 2>/dev/null
  exit 1
fi

describe() {
  local f=$1 n e
  n=$(grep -m1 '^Name=' "$f" | cut -d= -f2-); e=$(grep -m1 '^Exec=' "$f" | cut -d= -f2-)
  echo "$(basename "$f")  [${n:-?}]  runs: ${e:-?}"
}
pick_session() {   # pick_session "n/6" "Label" ARRAYNAME -> sets PICKED (full path)
  local step=$1 label=$2; local -n arr=$3; local opts=() f
  if [ "${#arr[@]}" -eq 1 ]; then
    PICKED=${arr[0]}; echo; echo "$step) $label session: only one found, using $(basename "$PICKED")"; return
  fi
  for f in "${arr[@]}"; do opts+=("$(describe "$f")"); done
  if [ "$label" = Hyprland ]; then
    echo; echo "(A 'uwsm' session is managed by systemd/UWSM - pick the one you normally log in with.)"
  fi
  menu "$step) Which $label session should the switch use?" "${opts[@]}"
  PICKED=${arr[$((CHOICE-1))]}
}

# ---------------- questions (in order) ----------------
KDE_KEY="Meta+Shift+Backspace"          # KDE format
HYPR_KEY="SUPER + SHIFT + BACKSPACE"    # Hyprland Lua format
HYPR_CFG="$HOME/.config/hypr/hyprland.lua"

pick_session "1/6" "Plasma"   PLASMA_LIST; PLASMA_FILE=$PICKED
pick_session "2/6" "Hyprland" HYPR_LIST;   HYPR_FILE=$PICKED

menu "3/6) Default environment after boot  (what the SDDM login screen pre-selects on every boot)" \
     "KDE Plasma   ($(basename "$PLASMA_FILE"))" \
     "Hyprland     ($(basename "$HYPR_FILE"))"
[ "$CHOICE" = 1 ] && DEFAULT_ENV=plasma || DEFAULT_ENV=hyprland

menu "4/6) Logout behavior when switching" \
     "Fast logout, no confirmation to any app  (the old session is cut at once - quickest, but unsaved work in it is lost)" \
     "Normal logout  (on KDE, apps are asked to close first; an app with unsaved work can ask you to confirm and hold up the switch until you answer)"
[ "$CHOICE" = 1 ] && FAST=1 || FAST=0

menu "5/6) Shortcuts" \
     "Auto assign shortcuts  (creates the KDE shortcut and edits your hyprland.lua)" \
     "Don't assign shortcuts  (the exact lines to add are printed at the end of the install)"
if [ "$CHOICE" = 1 ]; then
  SHORTCUTS=auto
  echo; echo "KDE format example: Meta+Shift+Backspace   |   Hyprland format example: SUPER + SHIFT + BACKSPACE"
  ask_key "Shortcut in KDE to switch to Hyprland" "$KDE_KEY" KDE_KEY
  ask_key "Shortcut in Hyprland to switch to Plasma" "$HYPR_KEY" HYPR_KEY
else
  SHORTCUTS=manual
fi

menu "6/6) Zoom-out OUTRO  (your current desktop shrinks and fades on every monitor when you switch)" \
     "Install the outro  (needs mpv, ffmpeg, jq, grim, spectacle - installed for you on Arch-based systems)" \
     "No outro  (instant switch, no extra packages)"
[ "$CHOICE" = 1 ] && OUTRO=1 || OUTRO=0

yn() { [ "$1" = 1 ] && echo yes || echo no; }
if [ "$OUTRO" = 1 ]; then SWITCH_NAME=switch-with-outro; else SWITCH_NAME=switch-now; fi
SWITCH_CMD="$HOME/.local/bin/$SWITCH_NAME"

echo; echo "---------------- summary ----------------"
echo "  Plasma session   : $(basename "$PLASMA_FILE")"
echo "  Hyprland session : $(basename "$HYPR_FILE")"
echo "  Default on boot  : $DEFAULT_ENV"
echo "  Fast logout      : $(yn $FAST)"
echo "  Shortcuts        : $SHORTCUTS"
[ "$SHORTCUTS" = auto ] && { echo "    KDE -> Hyprland : $KDE_KEY"; echo "    Hyprland -> KDE : $HYPR_KEY"; }
echo "  Outro            : $(yn $OUTRO)"
menu "Ready to install?" "Yes, install now" "No, cancel"
[ "$CHOICE" = 1 ] || { echo "Cancelled."; exit 0; }

# ---------------- installer ----------------
U=$(id -un); G=$(id -gn)
sudo -v || exit 1
put_root() { local t; t=$(mktemp); cat > "$t"; sudo install -D -m "$1" -o root -g root "$t" "$2"; rm -f "$t"; }
put_user() { local t; t=$(mktemp); cat > "$t"; install -D -m "$1" -o "$U" -g "$G" "$t" "$2"; rm -f "$t"; }

# ---- hyprland.lua helpers: only ever touch a COMPLETE marker block, follow symlinks, keep a backup
strip_block() {   # strip_block FILE -> removes the session-switch block and the blank line before it
  local f tmp rc; f=$(readlink -f "$1") || return 1
  grep -q '>>> session-switch' "$f" || return 0
  grep -q '<<< session-switch' "$f" || return 2
  tmp=$(mktemp) || return 1
  awk '
    inb { if (index($0, "<<< session-switch")) inb = 0; next }
    index($0, ">>> session-switch") { held = 0; inb = 1; next }
    /^[[:space:]]*$/ { if (held) print ""; held = 1; next }
    { if (held) print ""; held = 0; print }
    END { if (held) print "" }
  ' "$f" > "$tmp" && cat "$tmp" > "$f"
  rc=$?; rm -f "$tmp"; return $rc
}
patch_hypr() {    # returns 0 if patched, 1 if skipped (reason already printed)
  local real bak
  real=$(readlink -f "$HYPR_CFG") || return 1
  if [ ! -w "$real" ]; then echo "  $HYPR_CFG is not writable (managed by Nix/home-manager?)"; return 1; fi
  if grep -q '>>> session-switch' "$real" && ! grep -q '<<< session-switch' "$real"; then
    echo "  found a '>>> session-switch' line without its '<<<' end line - not touching it"; return 1
  fi
  bak="$HYPR_CFG.bak-session-switch-$(date +%Y%m%d-%H%M%S)"
  cp -L "$HYPR_CFG" "$bak" || { echo "  could not write a backup"; return 1; }
  echo "  backup saved: $bak"
  strip_block "$real" || { echo "  could not update the existing block"; return 1; }
  [ -n "$(tail -c1 "$real")" ] && echo >> "$real"     # add a missing final newline
  [ -n "$(tail -n1 "$real")" ] && echo >> "$real"     # blank separator line
  { echo "-- >>> session-switch (KDE <-> Hyprland) >>>"; hypr_snippet; echo "-- <<< session-switch <<<"; } >> "$real"
}

hypr_snippet() {
  printf 'hl.bind("%s", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/%s plasma"))\n' "$HYPR_KEY" "$SWITCH_NAME"
  if [ "$OUTRO" = 1 ]; then
    printf '%s\n' 'hl.window_rule({ name = "switch-outro-nanim", match = { class = "^mpv$", title = "^switch-shot" }, no_anim = true })'
  fi
}
SHOW_KDE=0; SHOW_HYPR=0
[ "$SHORTCUTS" = manual ] && { SHOW_KDE=1; SHOW_HYPR=1; }
print_manual() {
  echo "=================== MANUAL SHORTCUT SETUP ==================="
  if [ "$SHOW_KDE" = 1 ]; then
    echo; echo "KDE  (Plasma -> Hyprland)"
    echo "  1. System Settings -> Keyboard -> Shortcuts -> Add New -> Command or Script"
    echo "  2. Command (full path - KDE does not expand ~):"
    echo "       $SWITCH_CMD hyprland"
    echo "  3. Assign your key combo (e.g. $KDE_KEY), click Apply,"
    echo "     then log out and back in once."
  fi
  if [ "$SHOW_HYPR" = 1 ]; then
    echo; echo "HYPRLAND  (Hyprland -> Plasma)"
    echo "  Add this to $HYPR_CFG (Hyprland reloads it when you save):"; echo
    hypr_snippet | sed 's/^/    /'
    echo; echo "  Old hyprlang .conf instead? Use:"
    echo "    bind = SUPER SHIFT, BACKSPACE, exec, $SWITCH_CMD plasma"
  fi
  echo "============================================================="
}

echo; echo "== 1/6 dependencies"
if [ "$OUTRO" = 1 ]; then
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm mpv ffmpeg jq grim spectacle qt6-tools libkscreen || {
      echo "ERROR: pacman failed. If it says 404 / 'target not found', your package database is stale:"
      echo "       run 'sudo pacman -Syu' first, then re-run this installer."
      exit 1; }
  else
    echo "Not an Arch-based system: make sure these are installed: mpv ffmpeg jq grim spectacle qdbus6 kscreen-doctor"
  fi
else
  echo "no extra packages needed without the outro"
fi

declare -A PKG=( [systemd-run]=systemd [loginctl]=systemd [flock]=util-linux [pgrep]=procps-ng
  [pkill]=procps-ng [mpv]=mpv [ffmpeg]=ffmpeg [ffprobe]=ffmpeg [jq]=jq [grim]=grim
  [spectacle]=spectacle [kscreen-doctor]=libkscreen [qdbus6]=qt6-tools [hyprctl]=hyprland )
NEED="systemd-run loginctl flock pgrep pkill"
[ "$OUTRO" = 1 ] && NEED="$NEED mpv ffmpeg ffprobe jq grim spectacle kscreen-doctor"
[ "$FAST" = 0 ]  && NEED="$NEED qdbus6"
{ [ "$OUTRO" = 1 ] || [ "$FAST" = 0 ]; } && NEED="$NEED hyprctl"
MISSING=0
for c in $NEED; do
  command -v "$c" >/dev/null 2>&1 || { echo "ERROR: '$c' is missing (Arch package: ${PKG[$c]:-?})"; MISSING=1; }
done
[ "$MISSING" = 1 ] && exit 1

echo "== 2/6 root helper (/usr/local/bin/switch-session)"
put_root 755 /usr/local/bin/switch-session <<'HELPER_EOF'
#!/bin/bash
PLASMA_FILE=@PLASMA_FILE@
HYPR_FILE=@HYPR_FILE@
DEFAULT_ENV=@DEFAULT_ENV@
S=/var/lib/sddm/state.conf
A=/etc/sddm.conf.d/zz-switch-autologin.conf
TOK=/run/switch-session.token
BEF=/run/switch-session.before
LOCK=/run/switch-session.lock
LOG=/var/log/switch-session.log

log() { echo "$(date +%T.%N | cut -c1-12) $*" >> "$LOG"; }

sess_file() {
  case "$1" in
    plasma)   echo "$PLASMA_FILE" ;;
    hyprland) echo "$HYPR_FILE" ;;
  esac
}

set_state() {
  local F; F=$(sess_file "$1")
  mkdir -p /var/lib/sddm
  [ -f "$S" ] || printf '[Last]\n' > "$S"
  grep -q '^\[Last\]' "$S" || echo '[Last]' >> "$S"
  if grep -q '^Session=' "$S"; then
    sed -i "s|^Session=.*|Session=$F|" "$S"
  else
    sed -i "/^\[Last\]/a Session=$F" "$S"
  fi
}

sddm_ids() { loginctl list-sessions --no-legend | awk '$3=="sddm"{print $1}'; }

new_greeter() {
  local id
  for id in $(sddm_ids); do
    grep -qx "$id" "$BEF" 2>/dev/null || return 0
  done
  return 1
}

find_leader() {
  local id
  for id in $(loginctl list-sessions --no-legend | awk -v u="$1" '$3==u{print $1}'); do
    [ "$(loginctl show-session "$id" -p Active --value)" = yes ] || continue
    case "$(loginctl show-session "$id" -p Type --value)" in
      wayland|x11) loginctl show-session "$id" -p Leader --value; return 0 ;;
    esac
  done
  return 1
}

find_comp() {
  local c
  for c in Hyprland kwin_wayland; do
    if pgrep -u "$1" -x "$c" >/dev/null; then echo "$c"; return 0; fi
  done
  return 1
}

case "$1" in
  default)
    echo cancel > "$TOK"
    rm -f "$A"
    set_state "$DEFAULT_ENV"
    ;;
  plasma|hyprland)
    U=${SUDO_USER:-}
    [ -n "$U" ] || exit 1
    [ -f "$(sess_file "$1")" ] || exit 1
    MODE=$2
    T=$(date +%s%N)
    echo "$T" > "$TOK"
    sddm_ids > "$BEF"
    L=$(find_leader "$U")
    C=$(find_comp "$U")
    log "---- switch to $1 ($MODE): user=$U leader='$L' comp='$C'"
    set_state "$1"
    mkdir -p /etc/sddm.conf.d
    printf '[Autologin]\nUser=%s\nSession=%s\n' "$U" "$(basename "$(sess_file "$1")")" > "$A"
    systemd-run --no-block --quiet "$0" finish "$U" "$T" "$L" "$C" "$MODE"
    ;;
  finish)
    U=$2; T=$3; L=$4; C=$5; MODE=$6
    exec 9>"$LOCK"
    flock -w 20 9 || { log "finish: lock busy, exiting"; exit 0; }
    for i in $(seq 2400); do
      [ "$(cat "$TOK" 2>/dev/null)" = "$T" ] || { log "finish: superseded/cancelled"; exit 0; }
      known=0; alive=0
      if [ -n "$L" ]; then known=1; [ -d "/proc/$L" ] && alive=1; fi
      if [ -n "$C" ]; then known=1; pgrep -u "$U" -x "$C" >/dev/null && alive=1; fi
      gone=0
      if [ "$MODE" = now ]; then
        gone=1
      elif [ "$known" = 1 ]; then
        [ "$alive" = 0 ] && gone=1
      else
        new_greeter && gone=1
      fi
      if [ "$gone" = 1 ]; then
        log "finish: restarting sddm (mode=${MODE:-wait}, polls=$i)"
        echo done > "$TOK"
        systemctl reset-failed sddm
        systemctl restart sddm
        log "finish: restart exit=$? (done)"
        exec 9>&-
        sleep 8
        [ "$(cat "$TOK" 2>/dev/null)" = done ] && rm -f "$A"
        exit 0
      fi
      sleep 0.05
    done
    log "finish: timeout, session never ended"
    [ "$(cat "$TOK" 2>/dev/null)" = "$T" ] && rm -f "$A"
    ;;
  *) exit 1 ;;
esac
HELPER_EOF
sudo sed -i "s|@PLASMA_FILE@|$PLASMA_FILE|; s|@HYPR_FILE@|$HYPR_FILE|; s|@DEFAULT_ENV@|$DEFAULT_ENV|" /usr/local/bin/switch-session
sudo bash -n /usr/local/bin/switch-session || { echo "ERROR: helper syntax check failed"; exit 1; }

echo "== 3/6 sudoers rule + boot default service"
t=$(mktemp)
echo "$U ALL=(root) NOPASSWD: /usr/local/bin/switch-session" > "$t"
if sudo visudo -cf "$t" >/dev/null; then
  sudo install -m 440 -o root -g root "$t" /etc/sudoers.d/switch-session
else
  echo "ERROR: sudoers validation failed"; rm -f "$t"; exit 1
fi
rm -f "$t"
# remove the service from older versions of this setup
if [ -f /etc/systemd/system/sddm-default-plasma.service ]; then
  sudo systemctl disable sddm-default-plasma.service 2>/dev/null
  sudo rm -f /etc/systemd/system/sddm-default-plasma.service
fi
put_root 644 /etc/systemd/system/sddm-default-session.service <<'SERVICE_EOF'
[Unit]
Description=Set the default SDDM session after boot
Before=sddm.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/switch-session default

[Install]
WantedBy=graphical.target
SERVICE_EOF
sudo systemctl daemon-reload
sudo systemctl enable sddm-default-session.service
sudo /usr/local/bin/switch-session default

echo "== 4/6 user scripts (~/.local/bin)"
if [ "$OUTRO" = 1 ]; then
rm -f "$HOME/.local/bin/switch-now"
put_user 644 "$HOME/.local/bin/outro-logout.lua" <<'LUA_EOF'
local img  = os.getenv("OUTRO_IMG")
local mark = os.getenv("OUTRO_MARK")
local DUR, MINZ, FADE = 1.2, 0.55, 0.45   -- length (s), end size, fade-out length (s)
local started, fired = false, false

local function ease(p) return p * p * (3 - 2 * p) end

mp.register_event("file-loaded", function()
  if started then return end
  started = true
  local t0 = mp.get_time()
  local removed = false
  local timer
  timer = mp.add_periodic_timer(1/120, function()
    if not removed then
      removed = true
      if img then os.remove(img) end
    end
    local p = math.min((mp.get_time() - t0) / DUR, 1)
    mp.set_property_number("video-zoom", math.log(1 - (1 - MINZ) * ease(p)) / math.log(2))
    local f = (p * DUR - (DUR - FADE)) / FADE
    if f > 0 then
      mp.set_property_number("brightness", -math.floor(100 * math.min(f, 1) + 0.5))
    end
    if p >= 1 and not fired then
      fired = true
      timer:kill()
      if mark then local m = io.open(mark, "w"); if m then m:close() end end
    end
  end)
end)
LUA_EOF

put_user 755 "$HOME/.local/bin/switch-with-outro" <<'OUTRO_EOF'
#!/bin/bash
# usage: switch-with-outro plasma|hyprland|preview
exec 8>/tmp/switch-outro.lock
flock -n 8 || exit 0
umask 077

FAST=@FAST@   # 1 = restart SDDM at once (faster, cuts the session), 0 = normal logout
RT="${XDG_RUNTIME_DIR:-/tmp}"
D="$RT/switch-outro"
mkdir -p "$HOME/.cache"
LOG="$HOME/.cache/switch-outro.log"
log() { echo "$(date +%T.%3N) $*" >> "$LOG"; }
: > "$LOG"
rm -rf "$D"; mkdir -p "$D"

is_hypr() {   # am I inside Hyprland? (the env var alone can go stale, so cross-check)
  case "${XDG_CURRENT_DESKTOP:-}" in
    *[Hh]yprland*) return 0 ;;
    *KDE*) return 1 ;;
  esac
  [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && pgrep -u "$(id -u)" -x Hyprland >/dev/null 2>&1
}
if is_hypr; then
  if command -v uwsm >/dev/null 2>&1 && uwsm check is-active >/dev/null 2>&1; then
    LOGOUT="uwsm stop"       # uwsm-managed session: let uwsm shut it down in order
  else
    LOGOUT="hyprctl dispatch 'hl.dsp.exit()'"
  fi
else
  LOGOUT="qdbus6 org.kde.Shutdown /Shutdown logout"
fi

case "$1" in
  plasma|hyprland)
    if [ "$FAST" = 1 ]; then FINAL="sudo -n /usr/local/bin/switch-session $1 now"
    else FINAL="sudo -n /usr/local/bin/switch-session $1 && $LOGOUT"; fi ;;
  preview) FINAL="pkill -f '[o]utro-logout.lua'" ;;
  *) exit 1 ;;
esac
log "start target=$1"

NAMES=(); IMGS=(); CROPS=()

if is_hypr; then
  # Hyprland: one screenshot per monitor, taken in parallel
  mapfile -t MONS < <(hyprctl monitors -j | jq -r '.[].name')
  for m in "${MONS[@]}"; do
    grim -l 0 -o "$m" "$D/switch-shot-$m.png" 2>/dev/null &
  done
  wait
  for m in "${MONS[@]}"; do
    if [ -s "$D/switch-shot-$m.png" ]; then
      NAMES+=("$m"); IMGS+=("$D/switch-shot-$m.png"); CROPS+=("")
    fi
  done
else
  # KDE: one screenshot of all screens, cropped per monitor by mpv
  ALL="$D/all.png"
  spectacle -b -n -f -o "$ALL" >/dev/null 2>&1
  if [ -s "$ALL" ]; then
    IFS=, read -r IW IH < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$ALL")
    log "all-screens image ${IW}x${IH}"
    while read -r name cw ch cx cy; do
      ln "$ALL" "$D/switch-shot-$name.png"
      NAMES+=("$name"); IMGS+=("$D/switch-shot-$name.png"); CROPS+=("${cw}x${ch}+${cx}+${cy}")
    done < <(kscreen-doctor -j | jq -r '
      [.outputs[] | select(.enabled)
       | (if (.rotation==2 or .rotation==8) then {w:(.size.height/.scale), h:(.size.width/.scale)}
          else {w:(.size.width/.scale), h:(.size.height/.scale)} end) as $s
       | {name:.name, x:.pos.x, y:.pos.y, w:$s.w, h:$s.h}] as $o
      | ($o|map(.x)|min) as $minx | ($o|map(.y)|min) as $miny
      | ($o|map(.x+.w)|max) as $maxx | ($o|map(.y+.h)|max) as $maxy
      | $o[] | [.name, (.x-$minx), (.y-$miny), .w, .h, ($maxx-$minx), ($maxy-$miny)] | @tsv' \
      | awk -v iw="$IW" '{f=iw/$6; printf "%s %d %d %d %d\n", $1, $4*f, $5*f, $2*f, $3*f}')
    rm -f "$ALL"
  fi
fi
log "monitors: ${NAMES[*]} | crops: ${CROPS[*]}"

PIDS=()
for i in "${!NAMES[@]}"; do
  n=${NAMES[$i]}; img=${IMGS[$i]}; extra=()
  [ -n "${CROPS[$i]}" ] && extra+=(--video-crop="${CROPS[$i]}")
  OUTRO_IMG="$img" OUTRO_MARK="$D/mark-$n" mpv --no-config --profile=fast --vo=gpu \
    --fs --fs-screen-name="$n" "${extra[@]}" \
    --no-osc --osd-level=0 --no-terminal --really-quiet --no-audio --ytdl=no \
    --load-stats-overlay=no --load-osd-console=no --cursor-autohide=1 \
    --no-input-default-bindings --image-display-duration=inf \
    --script="$HOME/.local/bin/outro-logout.lua" "$img" &
  PIDS+=($!)
done

# wait until every monitor's animation has finished (max 6 s)
if [ "${#NAMES[@]}" -gt 0 ]; then
  t0=${EPOCHREALTIME/[.,]/}
  while :; do
    marks=$(ls "$D"/mark-* 2>/dev/null | wc -l)
    [ "$marks" -ge "${#NAMES[@]}" ] && break
    alive=0; for p in "${PIDS[@]}"; do kill -0 "$p" 2>/dev/null && alive=1; done
    [ "$alive" = 0 ] && break
    [ $(( (${EPOCHREALTIME/[.,]/} - t0) / 1000 )) -gt 6000 ] && break
    sleep 0.02
  done
  log "animations done: marks=$marks/${#NAMES[@]}"
fi

# watchdog: if the switch never happens (logout cancelled/blocked, sudo failed) don't leave
# frozen screenshots covering every monitor. It only ever kills THIS run's mpv PIDs (and only
# if they are still outro windows), so a leftover watchdog can never hit a later switch.
# fd 8 is closed so it doesn't hold the single-instance lock.
kill_outro() {
  local p
  for p in "${PIDS[@]}"; do
    grep -qa 'outro-logout[.]lua' "/proc/$p/cmdline" 2>/dev/null && kill "$p" 2>/dev/null
  done
}
if [ "$1" != preview ]; then
  ( exec 8>&-; sleep 25; kill_outro ) >/dev/null 2>&1 &
fi
if ! sh -c "$FINAL"; then
  log "switch command failed - removing outro windows"
  kill_outro
fi
rm -rf "$D"
OUTRO_EOF
sed -i "s|^FAST=@FAST@|FAST=$FAST|" "$HOME/.local/bin/switch-with-outro"
bash -n "$HOME/.local/bin/switch-with-outro" || { echo "ERROR: script syntax check failed"; exit 1; }
else
rm -f "$HOME/.local/bin/switch-with-outro" "$HOME/.local/bin/outro-logout.lua"
put_user 755 "$HOME/.local/bin/switch-now" <<'NOW_EOF'
#!/bin/bash
# usage: switch-now plasma|hyprland   (instant switch, no animation)
case "$1" in plasma|hyprland) ;; *) exit 1 ;; esac
FAST=@FAST@   # 1 = cut the old session at once, 0 = normal logout
is_hypr() {   # am I inside Hyprland? (the env var alone can go stale, so cross-check)
  case "${XDG_CURRENT_DESKTOP:-}" in
    *[Hh]yprland*) return 0 ;;
    *KDE*) return 1 ;;
  esac
  [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && pgrep -u "$(id -u)" -x Hyprland >/dev/null 2>&1
}
if is_hypr; then
  if command -v uwsm >/dev/null 2>&1 && uwsm check is-active >/dev/null 2>&1; then
    LOGOUT="uwsm stop"
  else
    LOGOUT="hyprctl dispatch 'hl.dsp.exit()'"
  fi
else
  LOGOUT="qdbus6 org.kde.Shutdown /Shutdown logout"
fi
if [ "$FAST" = 1 ]; then
  exec sudo -n /usr/local/bin/switch-session "$1" now
else
  sudo -n /usr/local/bin/switch-session "$1" && sh -c "$LOGOUT"
fi
NOW_EOF
sed -i "s|^FAST=@FAST@|FAST=$FAST|" "$HOME/.local/bin/switch-now"
bash -n "$HOME/.local/bin/switch-now" || { echo "ERROR: script syntax check failed"; exit 1; }
fi

echo "== 5/6 KDE shortcut"
# clean up the zoom-in intro effect from older versions of this setup
if command -v kpackagetool6 >/dev/null 2>&1 && kpackagetool6 --type KWin/Effect --list 2>/dev/null | grep -q switchintro; then
  kwriteconfig6 --file kwinrc --group Plugins --key switchintroEnabled false 2>/dev/null
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  kpackagetool6 --type KWin/Effect --remove switchintro >/dev/null 2>&1
  echo "removed the old KWin intro effect"
fi
if [ "$SHORTCUTS" = auto ]; then
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    put_user 644 "$HOME/.local/share/applications/switch-to-hyprland.desktop" <<DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=Switch to Hyprland
Exec=$SWITCH_CMD hyprland
NoDisplay=true
X-KDE-GlobalAccel-CommandShortcut=true
DESKTOP_EOF
    kbuildsycoca6 >/dev/null 2>&1 || true
    kwriteconfig6 --file kglobalshortcutsrc --group services --group switch-to-hyprland.desktop --key _launch "$KDE_KEY"
    echo "KDE shortcut set: $KDE_KEY (takes effect after you log out and back in)"
  else
    echo "kwriteconfig6 not found - the KDE shortcut is printed below instead"
    SHOW_KDE=1
  fi
else
  echo "KDE shortcut left alone (manual)"
fi

echo "== 6/6 Hyprland config"
if [ "$SHORTCUTS" = auto ]; then
  if [ -f "$HYPR_CFG" ]; then
    if patch_hypr; then
      echo "Hyprland config patched: $HYPR_CFG"
    else
      echo "Hyprland config NOT changed - the Hyprland part is printed below instead"
      SHOW_HYPR=1
    fi
  else
    echo "No $HYPR_CFG found - the Hyprland part is printed below instead"
    SHOW_HYPR=1
  fi
else
  echo "hyprland.lua left alone (manual)"
fi

echo
echo "Installed. Default session on boot: $DEFAULT_ENV. Log out and back in once so the shortcuts load."
[ "$OUTRO" = 1 ] && echo "Test the animation without switching:  $SWITCH_CMD preview"
if [ "$SHOW_KDE" = 1 ] || [ "$SHOW_HYPR" = 1 ]; then
  echo
  INSTR="$HOME/session-switch-instructions.txt"
  print_manual | tee "$INSTR"
  echo "(saved to $INSTR)"
fi
