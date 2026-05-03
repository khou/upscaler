#!/usr/bin/env bash
# Diagnostic dump for Upscaler.app crashes.
# Run on the machine that's crashing. Send the printed output to whoever's helping.

APP="${1:-/Applications/Upscaler.app}"
ENGINE="$APP/Contents/Resources/engine/upscayl-bin"

echo "=== System ==="
echo "macOS:  $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
echo "Arch:   $(uname -m)"
echo "Model:  $(sysctl -n hw.model 2>/dev/null)"
echo "Memory: $(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024)) GB"
echo

echo "=== App bundle ==="
if [ ! -d "$APP" ]; then
  echo "MISSING: $APP"
  echo "Pass the path as: $0 /path/to/Upscaler.app"
  exit 1
fi
echo "Path:        $APP"
echo "Engine:      $(file "$ENGINE" 2>&1 | sed 's/^[^:]*: //')"
echo "Engine size: $(stat -f%z "$ENGINE" 2>/dev/null) bytes"
echo "Quarantine:  $(xattr "$APP" 2>&1 | grep -c quarantine) attr(s)"
echo "Codesign:    $(codesign -dv "$APP" 2>&1 | head -2 | tail -1)"
echo

echo "=== Engine standalone test (should print usage, not crash) ==="
"$ENGINE" -h 2>&1 | head -20
echo "Exit: $?"
echo

echo "=== Latest crash reports for upscaler/upscayl/droplet ==="
find ~/Library/Logs/DiagnosticReports -type f 2>/dev/null \
  \( -iname '*upscayl*' -o -iname '*upscaler*' -o -iname '*droplet*' -o -iname 'osascript*' \) \
  -mtime -7 \
  | sort -r | head -3 \
  | while read -r f; do
      echo "--- $f ---"
      head -80 "$f"
      echo
    done

echo "=== Recent osascript / Upscaler entries in unified log (last 5 min) ==="
log show --last 5m --predicate 'process == "osascript" OR process CONTAINS "upscayl" OR process == "Upscaler"' --style compact 2>/dev/null | tail -40
