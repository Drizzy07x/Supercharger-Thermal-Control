#!/system/bin/sh
MODDIR=${MODDIR:-${0%/*}/..}
. "$MODDIR/bin/profile_lib.sh"
TARGET="$1"
CURRENT="$(read_profile)"
[ -n "$TARGET" ] || TARGET="$CURRENT"
log_info "switch_profile invoked: previous=$CURRENT target=$TARGET"
if apply_profile_files "$TARGET"; then
  echo "Previous profile: $CURRENT"
  echo "Selected profile: $TARGET"
  echo "Status: success"
  echo "Reboot required to apply overlay."
  exit 0
else
  log_error "switch_profile failed: previous=$CURRENT target=$TARGET"
  echo "Previous profile: $CURRENT"
  echo "Requested profile: $TARGET"
  echo "Status: failure"
  echo "Check action.log inside the module directory."
  exit 1
fi
