#!/system/bin/sh
MODDIR=${MODDIR:-${0%/*}/..}
PROFILE_FILE="$MODDIR/current_profile"
STATUS_FILE="$MODDIR/last_action_status.txt"
ACTIVE_DIR="$MODDIR/system/vendor/etc"
LOG_FILE="$MODDIR/action.log"
MODULE_ID="supercharger_thermal_control"

log() {
  mkdir -p "${LOG_FILE%/*}" 2>/dev/null || true
  echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
  chmod 0644 "$LOG_FILE" 2>/dev/null || true
}

log_info() {
  log "INFO: $*"
}

log_error() {
  log "ERROR: $*"
}

write_status() {
  status="$1"
  profile="$2"
  message="$3"
  {
    [ -n "$profile" ] && echo "Selected profile: $profile"
    echo "Status: $status"
    echo "$message"
  } > "$STATUS_FILE"
  chmod 0644 "$STATUS_FILE" 2>/dev/null || true
}

verify_active_file() {
  src="$1"
  dst="$2"
  [ -f "$src" ] || return 1
  [ -f "$dst" ] || return 1
  cmp -s "$src" "$dst"
}

log_webui_state_read() {
  outcome="$1"
  profile="$2"
  detail="$3"
  case "$outcome" in
    success)
      log_info "webui state read success: current_profile=${profile:-unknown}"
      ;;
    *)
      log_error "webui state read failure: ${detail:-unknown error}"
      ;;
  esac
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
  if [ "$(read_profile)" = "$p" ]; then
    log_info "current_profile updated: $p"
  else
    log_error "current_profile update verification failed: expected=$p actual=$(read_profile)"
    return 1
  fi
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
  log_info "profile switch requested: $p"
  if [ ! -d "$srcdir" ]; then
    write_status "failure" "$p" "Profile source files are missing."
    log_error "profile source directory missing: $srcdir"
    return 1
  fi
  if ! mkdir -p "$ACTIVE_DIR"; then
    write_status "failure" "$p" "Could not prepare active profile directory."
    log_error "failed to create active directory: $ACTIVE_DIR"
    return 1
  fi
  if ! copy_one "$srcdir/thermal_info_config.json" "$ACTIVE_DIR/thermal_info_config.json"; then
    write_status "failure" "$p" "Could not copy thermal_info_config.json."
    log_error "copy failed: thermal_info_config.json"
    return 1
  fi
  if ! copy_one "$srcdir/thermal_info_config_charge.json" "$ACTIVE_DIR/thermal_info_config_charge.json"; then
    write_status "failure" "$p" "Could not copy thermal_info_config_charge.json."
    log_error "copy failed: thermal_info_config_charge.json"
    return 1
  fi
  if ! copy_one "$srcdir/thermal_info_config_lpm.json" "$ACTIVE_DIR/thermal_info_config_lpm.json"; then
    write_status "failure" "$p" "Could not copy thermal_info_config_lpm.json."
    log_error "copy failed: thermal_info_config_lpm.json"
    return 1
  fi
  log_info "profile files copied: $p"
  if ! verify_active_file "$srcdir/thermal_info_config.json" "$ACTIVE_DIR/thermal_info_config.json"; then
    write_status "failure" "$p" "Active thermal_info_config.json verification failed."
    log_error "active file verification failed: thermal_info_config.json"
    return 1
  fi
  if ! verify_active_file "$srcdir/thermal_info_config_charge.json" "$ACTIVE_DIR/thermal_info_config_charge.json"; then
    write_status "failure" "$p" "Active thermal_info_config_charge.json verification failed."
    log_error "active file verification failed: thermal_info_config_charge.json"
    return 1
  fi
  if ! verify_active_file "$srcdir/thermal_info_config_lpm.json" "$ACTIVE_DIR/thermal_info_config_lpm.json"; then
    write_status "failure" "$p" "Active thermal_info_config_lpm.json verification failed."
    log_error "active file verification failed: thermal_info_config_lpm.json"
    return 1
  fi
  log_info "active files updated in system/vendor/etc: $p"
  if ! write_profile "$p"; then
    write_status "failure" "$p" "Could not save current_profile."
    log_error "profile switch aborted after current_profile write failure: $p"
    return 1
  fi
  write_status "success" "$p" "Reboot required to apply overlay."
  log_info "profile switch complete: $p"
  log_info "reboot required after switching to: $p"
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
