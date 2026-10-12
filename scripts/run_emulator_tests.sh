#!/usr/bin/env bash
# Copyright (c) 2027 Charles L. Sherman
# SPDX-License-Identifier: MIT
#
# Build d1r32_ili9486 with PlatformIO, merge a 4MB flash image and boot it in
# Espressif QEMU (qemu-system-xtensa -machine esp32) as a boot smoke test.
# Usage: bash scripts/run_emulator_tests.sh [--timeout SEC] [--no-build] [--log PATH_BASE]
# Exit: 0 PASS, 1 FAIL (or required tool MISSING).
# Tool check prints FOUND / MISSING / DEFERRED only.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

ENV_NAME=d1r32_ili9486
timeout_sec=60
no_build=0
log_base="$root/.pio/emulator-smoke"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) timeout_sec="$2"; shift 2 ;;
    --no-build) no_build=1; shift ;;
    --log) log_base="$2"; shift 2 ;;
    -h|--help) sed -n 2,10p "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
mkdir -p "$(dirname "$log_base")"

[[ -d /workspace/tools/bin ]] && export PATH="/workspace/tools/bin:${PATH}"

# --- locate pio ---
pio_bin="$(command -v pio || true)"
if [[ -z "$pio_bin" && -f /workspace/env/platformio.sh ]]; then
  # shellcheck source=/dev/null
  source /workspace/env/platformio.sh
  pio_bin="$(command -v pio || true)"
fi
# --- locate QEMU: PATH, then QEMU_ESP, then /workspace/env/emulators.sh ---
qemu_bin="$(command -v qemu-system-xtensa || true)"
if [[ -z "$qemu_bin" && -n "${QEMU_ESP:-}" && -x "${QEMU_ESP}" ]]; then qemu_bin="$QEMU_ESP"; fi
if [[ -z "$qemu_bin" && -f /workspace/env/emulators.sh ]]; then
  # shellcheck source=/dev/null
  source /workspace/env/emulators.sh
  qemu_bin="$(command -v qemu-system-xtensa || true)"
  [[ -z "$qemu_bin" && -n "${QEMU_ESP:-}" && -x "${QEMU_ESP}" ]] && qemu_bin="$QEMU_ESP"
fi
pkg_dir="${PLATFORMIO_CORE_DIR:-$HOME/.platformio}/packages"
esptool_py="$pkg_dir/tool-esptoolpy/esptool.py"
boot_app0="$pkg_dir/framework-arduinoespressif32/tools/partitions/boot_app0.bin"
py_bin="$(command -v python3 || command -v python || true)"
timeout_bin="$(command -v timeout || true)"

echo "=== tool check ==="
missing=0
chk() { # name path deferred_reason
  if [[ -n "$2" && -e "$2" ]]; then printf 'FOUND     %-20s %s\n' "$1" "$2"
  elif [[ -n "${3:-}" ]]; then printf 'DEFERRED  %-20s %s\n' "$1" "$3"
  else printf 'MISSING   %-20s\n' "$1"; missing=1; fi
}
chk pio "$pio_bin"
chk qemu-system-xtensa "$qemu_bin"
chk python3 "$py_bin"
chk timeout "$timeout_bin"
if [[ -e "$esptool_py" ]]; then chk esptool.py "$esptool_py"
else chk esptool.py "" "installed by PlatformIO on first build"; fi
if [[ -e "$boot_app0" ]]; then chk boot_app0.bin "$boot_app0"
else chk boot_app0.bin "" "installed by PlatformIO on first build"; fi
if [[ $missing -ne 0 ]]; then
  echo "EMU smoke RESULT: FAIL (required tool MISSING; QEMU: https://github.com/espressif/qemu/releases)"
  exit 1
fi

# --- build ---
build_dir="$root/.pio/build/$ENV_NAME"
if [[ $no_build -eq 0 ]]; then
  echo "=== pio run -e $ENV_NAME ==="
  if ! "$pio_bin" run -e "$ENV_NAME" > "$log_base.build.log" 2>&1; then
    tail -20 "$log_base.build.log"
    echo "EMU smoke RESULT: FAIL (build failed, see $log_base.build.log)"; exit 1
  fi
  echo "build OK (log $log_base.build.log)"
fi
for f in bootloader.bin partitions.bin firmware.bin; do
  [[ -f "$build_dir/$f" ]] || { echo "MISSING   $build_dir/$f"; echo "EMU smoke RESULT: FAIL"; exit 1; }
done
for f in "$esptool_py" "$boot_app0"; do
  [[ -f "$f" ]] || { echo "MISSING   $f"; echo "EMU smoke RESULT: FAIL"; exit 1; }
done

# --- merge 4MB flash image ---
flash_img="$build_dir/flash_4mb.bin"
echo "=== merge_bin -> $flash_img ==="
# Use PlatformIO's own Python (has pyserial) via pkg exec.
if ! "$pio_bin" pkg exec -p tool-esptoolpy -- esptool.py --chip esp32 merge_bin --fill-flash-size 4MB -o "$flash_img" \
     --flash_mode dio --flash_freq 40m --flash_size 4MB \
     0x1000 "$build_dir/bootloader.bin" 0x8000 "$build_dir/partitions.bin" \
     0xe000 "$boot_app0" 0x10000 "$build_dir/firmware.bin" > "$log_base.merge.log" 2>&1; then
  cat "$log_base.merge.log"; echo "EMU smoke RESULT: FAIL (merge_bin)"; exit 1
fi

# --- boot in QEMU ---
# -icount shift=auto: without it, host-speed timing makes the early boot trip a
# spurious TG0/TG1 watchdog reset in QEMU in most runs (seen 5 of 6 on the box).
# -no-reboot turns any reset into a QEMU exit, so a real rst loop still FAILs.
qemu_log="$log_base.qemu.log"
echo "=== QEMU esp32 boot (timeout ${timeout_sec}s) -> $qemu_log ==="
"$timeout_bin" "$timeout_sec" "$qemu_bin" -machine esp32 -nographic -no-reboot -icount shift=auto \
  -drive "file=$flash_img,if=mtd,format=raw" -serial mon:stdio < /dev/null > "$qemu_log" 2>&1
qrc=$?
echo "EMU qemu exit=$qrc (124 = stopped by timeout, expected)"

# --- evaluate ---
clean_log="$log_base.qemu.clean.log"
sed -e 's/\x1b\[[0-9;]*m//g' -e 's/\r$//' "$qemu_log" > "$clean_log"
boot_marker='=== Minimal D1 R32'
fail=0
grep -q "$boot_marker" "$clean_log" || { echo "FAIL: app boot banner not seen"; fail=1; }
if grep -nE "Guru Meditation|panic|abort\(\)|Backtrace:" "$clean_log"; then echo "FAIL: panic/abort in serial log"; fail=1; fi
rst_count=$(grep -c "^rst:" "$clean_log" || true)
if [[ "$rst_count" -gt 1 ]]; then echo "FAIL: reset loop ($rst_count resets)"; fail=1; fi
if [[ $qrc -ne 0 && $qrc -ne 124 ]]; then echo "FAIL: QEMU exited $qrc"; fail=1; fi
echo "--- key boot lines ---"
grep -E "^rst:|^boot:|Minimal D1 R32|Compiled:|TFT init|init \+ draw|\[Uptime" "$clean_log" | head -15
if [[ $fail -eq 0 ]]; then
  echo "EMU smoke RESULT: PASS (log $qemu_log)"; exit 0
fi
echo "EMU smoke RESULT: FAIL (log $qemu_log)"; exit 1
