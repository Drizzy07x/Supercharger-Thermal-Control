#!/system/bin/sh
MODDIR=${MODDIR:-${0%/*}/..}
PROFILE_FILE="$MODDIR/current_profile"
STATUS_FILE="$MODDIR/last_action_status.txt"
ACTIVE_DIR="$MODDIR/system/vendor/etc"
LOG_FILE="$MODDIR/action.log"
MODULE_ID="supercharger_thermal_control"

log() {
  echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}

read_profile() {
  if [ -f "$PROFILE_FILE" ]; then
    tr -d '
' < "$PROFILE_FILE"
  else
    echo balanced
  fi
}

write_profile() {
  p="$1"
  echo "$p" > "$PROFILE_FILE"
  chmod 0644 "$PROFILE_FILE" 2>/dev/null || true
  if command -v ksud >/dev/null 2>&1; then
    ksud module config set selected_profile "$p" >/dev/null 2>&1 || true
    ksud module config set override.description "Active profile: $p | Reboot required after switching" >/dev/null 2>&1 || true
  fi
}

copy_one() {
  src="$1"
  dst="$2"
  [ -f "$src" ] || return 1
  cp -f "$src" "$dst" || return 1
  chmod 0644 "$dst" 2>/dev/null || true
}

apply_profile_files() {
  p="$1"
  srcdir="$MODDIR/profiles/$p/vendor/etc"
  [ -d "$srcdir" ] || return 1
  mkdir -p "$ACTIVE_DIR" || return 1
  copy_one "$srcdir/thermal_info_config.json" "$ACTIVE_DIR/thermal_info_config.json" || return 1
  copy_one "$srcdir/thermal_info_config_charge.json" "$ACTIVE_DIR/thermal_info_config_charge.json" || return 1
  copy_one "$srcdir/thermal_info_config_lpm.json" "$ACTIVE_DIR/thermal_info_config_lpm.json" || return 1
  write_profile "$p"
  {
    echo "Selected profile: $p"
    echo "Status: success"
    echo "Reboot required to apply overlay."
  } > "$STATUS_FILE"
  chmod 0644 "$STATUS_FILE" 2>/dev/null || true
  log "profile applied to overlay: $p"
  return 0
}

next_profile() {
  case "$1" in
    gaming) echo balanced ;;
    balanced) echo charge_cool ;;
    charge_cool) echo gaming ;;
    *) echo gaming ;;
  esac
}
