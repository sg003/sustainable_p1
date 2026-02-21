#!/usr/bin/env bash
set -euo pipefail

CHROME_BIN="$(command -v google-chrome)"
ENERGIBRIDGE="$HOME/Desktop/sustainable/adblocker/EnergiBridge/target/release/energibridge"
OUTDIR="$HOME/Desktop/sustainable/adblocker/energibridge_outputs"
SCROLLER="$HOME/Desktop/sustainable/adblocker/scroll_chrome.py"

# Your real Chrome data dir (DO NOT run measurements directly against this)
REAL_DATA_DIR="$HOME/.config/google-chrome"

# Where we create SAFE copies (these are what we actually launch)
RUN_BASE="$HOME/Desktop/sustainable/adblocker/chrome_userdata_clones"

mkdir -p "$OUTDIR" "$RUN_BASE"

WARMUP_OUTDIR="$HOME/Desktop/sustainable/adblocker/energibridge_outputs_warmup"
WARMUP_RUNS=3

mkdir -p "$WARMUP_OUTDIR"

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
  local profile="$1"   # "Profile 1"
  local tag="$2"       # "profile1"
  local port="$3"      # 9222, 9223, ...

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
# After that, it’s isolated anyway.
# run_profile "Profile 1" "profile1" 9222
# run_profile "Profile 2" "profile2" 9223

ORIGINAL_OUTDIR="$OUTDIR"
OUTDIR="$WARMUP_OUTDIR"

PROFILES=(
  "Profile 1:profile1:9222"
  "Profile 2:profile2:9223"
)

echo
echo "############################################"
echo "#           WARM-UP PHASE (3 runs)          #"
echo "#   Results stored separately and ignored  #"
echo "############################################"

for run in $(seq 1 "$WARMUP_RUNS"); do
  echo
  echo "------------------------------"
  echo " Warm-up run $run / $WARMUP_RUNS"
  echo "------------------------------"

  # Randomize order even during warm-up
  mapfile -t SHUFFLED < <(printf '%s\n' "${PROFILES[@]}" | shuf)

  first=1
  for entry in "${SHUFFLED[@]}"; do
    IFS=":" read -r profile tag port <<< "$entry"

    if [[ $first -eq 0 ]]; then
      echo "[warmup] Cooldown between profiles: 15s"
      sleep 15
    fi
    first=0

    run_profile "$profile" "$tag" "$port"
  done

  echo "[warmup] Cooldown after warm-up run $run: 30s"
  sleep 30
done

echo
echo "[warmup] Warm-up phase complete."
echo "[warmup] Warm-up CSVs saved in: $WARMUP_OUTDIR"

RUNS=30
OUTDIR="$ORIGINAL_OUTDIR"


for run in $(seq 1 "$RUNS"); do
  echo
  echo "=============================="
  echo " Starting experiment run $run "
  echo "=============================="

  # Shuffle profile order for this run
  mapfile -t SHUFFLED < <(printf '%s\n' "${PROFILES[@]}" | shuf)

  first=1
  for entry in "${SHUFFLED[@]}"; do
    IFS=":" read -r profile tag port <<< "$entry"

    # 15s cooldown BETWEEN profiles (but not before the first one)
    if [[ $first -eq 0 ]]; then
      echo "[info] Cooldown between profiles: 15s"
      sleep 15
    fi
    first=0

    run_profile "$profile" "$tag" "$port"
  done

  # 30s cooldown AFTER both profiles
  echo "[info] Cooldown after run $run: 30s"
  sleep 30
done

echo
echo "All measurements complete. CSVs are in: ${OUTDIR}"
