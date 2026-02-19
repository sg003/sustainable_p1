#!/usr/bin/env bash
set -euo pipefail

CHROME_BIN="$(command -v google-chrome)"
ENERGIBRIDGE="$HOME/Desktop/sustainable/adblocker/EnergiBridge/target/release/energibridge"
OUTDIR="$HOME/Desktop/sustainable/adblocker/energibridge_outputs"
SCROLLER="$HOME/Desktop/sustainable/adblocker/scroll_chrome.py"

# Your real Chrome data dir (not to run measurements directly against this)
REAL_DATA_DIR="$HOME/.config/google-chrome"

# Where we create safe copies
RUN_BASE="$HOME/Desktop/sustainable/adblocker/chrome_userdata_clones"

mkdir -p "$OUTDIR" "$RUN_BASE"

# Clone only what we need for each profile into a dedicated user-data-dir.
# This avoids profile locks + avoids corrupting real profiles.
clone_profile() {
  local profile="$1"           # e.g., "Profile 1"
  local target_dir="$2"        # e.g., "$RUN_BASE/profile1"

  rm -rf "$target_dir"
  mkdir -p "$target_dir"

  echo "[info] Cloning $profile -> $target_dir"

  # Local State is needed so Chrome recognizes profiles correctly
  rsync -a --delete \
    --exclude="**/Cache/**" \
    --exclude="**/Code Cache/**" \
    --exclude="**/GPUCache/**" \
    --exclude="**/Service Worker/CacheStorage/**" \
    "$REAL_DATA_DIR/Local State" \
    "$target_dir/Local State" 2>/dev/null || true

  # Copy only the requested profile folder
  rsync -a --delete \
    --exclude="**/Cache/**" \
    --exclude="**/Code Cache/**" \
    --exclude="**/GPUCache/**" \
    --exclude="**/Service Worker/CacheStorage/**" \
    "$REAL_DATA_DIR/$profile/" \
    "$target_dir/$profile/"
}

run_profile() {
  local profile="$1"   
  local tag="$2"     
  local port="$3"     

  local ts out user_data_dir
  ts=$(date +"%Y%m%d_%H%M%S")
  out="$OUTDIR/energy_${tag}_${ts}.csv"
  user_data_dir="$RUN_BASE/${tag}"

  clone_profile "$profile" "$user_data_dir"

  echo "=== Running ${profile} (CLONE) → ${out}"
  echo "[info] Using user-data-dir: $user_data_dir"
  echo "[info] DevTools port: $port"

  # Start a fresh, isolated Chrome instance (won't reuse existing sessions)
  "$CHROME_BIN" \
    --remote-debugging-address=127.0.0.1 \
    --remote-debugging-port="$port" \
    --remote-allow-origins="*" \
    --user-data-dir="$user_data_dir" \
    --profile-directory="$profile" \
    --no-first-run \
    --no-default-browser-check \
    about:blank >/tmp/chrome_measure_${tag}.log 2>&1 &

  CHROME_PID=$!
  echo "[info] Chrome PID: $CHROME_PID"

  # wait until DevTools is up
  for i in {1..30}; do
    if curl -s "http://127.0.0.1:${port}/json" >/dev/null 2>&1; then
      break
    fi
    sleep 0.3
  done

  # Measure the scrolling workload (Python talks to the DevTools port)
  "$ENERGIBRIDGE" -o "$out" -- \
    python3 "$SCROLLER" --port "$port" || true

  # Clean shutdown
  kill -TERM "$CHROME_PID" 2>/dev/null || true
  wait "$CHROME_PID" 2>/dev/null || true

  echo "Done: $out"
}

# IMPORTANT: close all normal Chrome windows before running this once.
run_profile "Profile 1" "profile1" 9222
run_profile "Profile 2" "profile2" 9223
