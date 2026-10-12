# Copyright (c) 2027 Charles L. Sherman
# SPDX-License-Identifier: MIT
#
# Windows twin of run_emulator_tests.sh: build d1r32_ili9486 with PlatformIO,
# merge a 4MB flash image and boot it in Espressif QEMU (esp32) as a smoke test.
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_emulator_tests.ps1 [-Timeout SEC] [-NoBuild] [-Log PATH_BASE] [-KeepWdt]
# By default the TIMG (TG0/TG1) watchdogs are disabled in QEMU only (timer.esp32.timg
# wdt_disable=true): their resets are a QEMU timing artifact. Real hardware keeps its
# watchdog. -KeepWdt leaves them enabled.
# Exit: 0 PASS, 1 FAIL (or required tool MISSING). Tool check prints FOUND / MISSING / DEFERRED only.
param(
    [int]$Timeout = 60,
    [switch]$NoBuild,
    [switch]$KeepWdt,
    [string]$Log = ""
)
$ErrorActionPreference = "Continue"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $Root
$EnvName = "d1r32_ili9486"
if (-not $Log) { $Log = Join-Path $Root ".pio/emulator-smoke" }
New-Item -ItemType Directory -Force -Path (Split-Path $Log) | Out-Null
$wsBin = "/workspace/tools/bin"
if (Test-Path -LiteralPath $wsBin) { $env:PATH = "$wsBin" + [IO.Path]::PathSeparator + $env:PATH }

function Find-Exe([string[]]$names) {
    foreach ($n in $names) { $c = Get-Command $n -ErrorAction SilentlyContinue; if ($c) { return $c.Source } }
    return $null
}
$pio = Find-Exe @("pio", "pio.exe", "platformio")
$qemu = Find-Exe @("qemu-system-xtensa.exe", "qemu-system-xtensa")
if (-not $qemu -and $env:QEMU_ESP -and (Test-Path -LiteralPath $env:QEMU_ESP)) { $qemu = $env:QEMU_ESP }
$core = if ($env:PLATFORMIO_CORE_DIR) { $env:PLATFORMIO_CORE_DIR } else { Join-Path $HOME ".platformio" }
$bootApp0 = Join-Path $core "packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin"
$esptool = Join-Path $core "packages/tool-esptoolpy/esptool.py"

Write-Host "=== tool check ==="
$missing = $false
function Chk([string]$name, $path, [string]$deferReason = "") {
    if ($path -and (Test-Path -LiteralPath $path)) { Write-Host ("FOUND     {0,-20} {1}" -f $name, $path) }
    elseif ($deferReason) { Write-Host ("DEFERRED  {0,-20} {1}" -f $name, $deferReason) }
    else { Write-Host ("MISSING   {0,-20}" -f $name); $script:missing = $true }
}
Chk "pio" $pio
Chk "qemu-system-xtensa" $qemu
if (-not $qemu) { Write-Host "          get Espressif QEMU: https://github.com/espressif/qemu/releases (set QEMU_ESP or add to PATH)" }
if (Test-Path -LiteralPath $esptool) { Chk "esptool.py" $esptool } else { Chk "esptool.py" $null "installed by PlatformIO on first build" }
if (Test-Path -LiteralPath $bootApp0) { Chk "boot_app0.bin" $bootApp0 } else { Chk "boot_app0.bin" $null "installed by PlatformIO on first build" }
if ($missing) { Write-Host "EMU smoke RESULT: FAIL (required tool MISSING)"; exit 1 }

$buildDir = Join-Path $Root ".pio/build/$EnvName"
if (-not $NoBuild) {
    Write-Host "=== pio run -e $EnvName ==="
    & $pio run -e $EnvName *> "$Log.build.log"
    if ($LASTEXITCODE -ne 0) {
        Get-Content "$Log.build.log" -Tail 20
        Write-Host "EMU smoke RESULT: FAIL (build failed, see $Log.build.log)"; exit 1
    }
    Write-Host "build OK (log $Log.build.log)"
}
foreach ($f in @((Join-Path $buildDir "bootloader.bin"), (Join-Path $buildDir "partitions.bin"), (Join-Path $buildDir "firmware.bin"), $bootApp0)) {
    if (-not (Test-Path -LiteralPath $f)) { Write-Host "MISSING   $f"; Write-Host "EMU smoke RESULT: FAIL"; exit 1 }
}

$flash = Join-Path $buildDir "flash_4mb.bin"
Write-Host "=== merge_bin -> $flash ==="
& $pio pkg exec -p tool-esptoolpy -- esptool.py --chip esp32 merge_bin --fill-flash-size 4MB -o $flash `
    --flash_mode dio --flash_freq 40m --flash_size 4MB `
    0x1000 (Join-Path $buildDir "bootloader.bin") 0x8000 (Join-Path $buildDir "partitions.bin") `
    0xe000 $bootApp0 0x10000 (Join-Path $buildDir "firmware.bin") *> "$Log.merge.log"
if ($LASTEXITCODE -ne 0) { Get-Content "$Log.merge.log"; Write-Host "EMU smoke RESULT: FAIL (merge_bin)"; exit 1 }

$qemuLog = "$Log.qemu.log"
Write-Host "=== QEMU esp32 boot (timeout ${Timeout}s) -> $qemuLog ==="
# -icount shift=auto avoids a spurious early-boot TG0/TG1 watchdog reset under QEMU timing.
# Same argument list as run_emulator_tests.sh. Start-Process joins -ArgumentList with
# plain spaces (no quoting) on Windows PowerShell 5.1, so build one string and quote
# any argument that contains a space (e.g. a flash path under "C:\Users\First Last").
$qargs = @("-machine", "esp32", "-nographic", "-no-reboot", "-icount", "shift=auto", "-drive", "file=$flash,if=mtd,format=raw", "-serial", "mon:stdio")
# Emulator-only: disable TIMG (TG0/TG1) watchdogs; under QEMU timing they fire spuriously
# in early boot (TG0WDT/TG1WDT_SYS_RESET). Real hardware keeps its watchdog.
if (-not $KeepWdt) { $qargs += @("-global", "driver=timer.esp32.timg,property=wdt_disable,value=true") }
$qargLine = ($qargs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
Write-Host "qemu: $qemu $qargLine"
# Match the .sh "< /dev/null": give QEMU an empty stdin so mon:stdio never reads the console.
$emptyIn = "$qemuLog.stdin"
Set-Content -LiteralPath $emptyIn -Value $null -NoNewline
$p = Start-Process -FilePath $qemu -ArgumentList $qargLine -NoNewWindow -PassThru `
    -RedirectStandardInput $emptyIn -RedirectStandardOutput $qemuLog -RedirectStandardError "$qemuLog.err"
# Cache the process handle now: without it, Windows PowerShell's Start-Process -PassThru
# object returns an empty ExitCode once the process has exited.
$null = $p.Handle
if ($p.WaitForExit($Timeout * 1000)) {
    $p.WaitForExit()          # flush redirected output after a natural exit
    $qrc = $p.ExitCode
} else {
    try { $p.Kill() } catch { }
    $null = $p.WaitForExit(5000)
    $qrc = 124                # same meaning as GNU timeout in the .sh
}
if ($null -eq $qrc -or "$qrc" -eq "") { $qrc = -1 }
Write-Host "EMU qemu exit=$qrc (124 = stopped by timeout, expected)"

$esc = [char]27
# Serial output is QEMU stdout ($qemuLog); QEMU's own messages go to $qemuLog.err.
# The .sh merges both (2>&1), so evaluate both here too. Strip ANSI colour and CR
# (Windows CRLF) so '^rst:' and the banner match on every line.
$text = ""
foreach ($f in @($qemuLog, "$qemuLog.err")) {
    if (Test-Path -LiteralPath $f) {
        $t = Get-Content -LiteralPath $f -Raw -ErrorAction SilentlyContinue
        if ($t) { $text += $t + "`n" }
    }
}
$text = $text -replace "$esc\[[0-9;]*m", "" -replace "`r", ""
$lines = $text -split "`n"
$cleanLog = "$Log.qemu.clean.log"
Set-Content -LiteralPath $cleanLog -Value $lines
$fail = $false
if (-not ($lines | Select-String -SimpleMatch "=== Minimal D1 R32")) { Write-Host "FAIL: app boot banner not seen"; $fail = $true }
$bad = $lines | Select-String -Pattern 'Guru Meditation|panic|abort\(\)|Backtrace:'
if ($bad) { $bad | ForEach-Object { Write-Host $_.Line }; Write-Host "FAIL: panic/abort in serial log"; $fail = $true }
$rst = @($lines | Select-String -Pattern '^rst:').Count
if ($rst -gt 1) { Write-Host "FAIL: reset loop ($rst resets)"; $fail = $true }
if ($qrc -ne 0 -and $qrc -ne 124) { Write-Host "FAIL: QEMU exited $qrc"; $fail = $true }
Write-Host "--- key boot lines ---"
$lines | Select-String -Pattern '^rst:|Minimal D1 R32|Compiled:|TFT init|init \+ draw|\[Uptime' | Select-Object -First 15 | ForEach-Object { Write-Host $_.Line }
if (-not $fail) { Write-Host "EMU smoke RESULT: PASS (log $qemuLog)"; exit 0 }
Write-Host "--- last serial/QEMU lines ---"
$lines | Where-Object { $_ -ne "" } | Select-Object -Last 15 | ForEach-Object { Write-Host $_ }
Write-Host "EMU smoke RESULT: FAIL (log $qemuLog)"; exit 1
