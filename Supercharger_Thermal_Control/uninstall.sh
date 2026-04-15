#!/system/bin/sh
MODDIR=${0%/*}
rm -f "$MODDIR/last_action_status.txt" "$MODDIR/action.log" "$MODDIR/current_profile" 2>/dev/null || true
if command -v ksud >/dev/null 2>&1; then
  ksud module config delete selected_profile >/dev/null 2>&1 || true
  ksud module config delete override.description >/dev/null 2>&1 || true
fi
exit 0
