# verify-and-dump.ps1 - run ON the VM, normally under psexec -s.
#
# Two jobs:
#
#  1. VERIFY (default). Proves the crash-capture flags from enable-heapdump.ps1
#     are actually live in the running JVM, rather than assuming the registry
#     edit took. Checks the effective command line, the JFR recording state, and
#     that gc.log is being written.
#
#  2. DUMP (-Dump). Writes the current JFR recording to a file so it can be
#     analysed now, without waiting for another OutOfMemoryError. The recording
#     keeps running afterwards.
#
# Usage:
#   psexec -s powershell -ExecutionPolicy Bypass -File C:\temp\heapdiag\verify-and-dump.ps1
#   psexec -s powershell -ExecutionPolicy Bypass -File C:\temp\heapdiag\verify-and-dump.ps1 -Dump

param(
  [string]$OutDir    = $PSScriptRoot,
  [string]$JcmdPath  = '',
  [int]   $PidTarget = 0,
  [switch]$Dump
)

$ErrorActionPreference = 'Stop'

# --- locate jcmd -------------------------------------------------------------
$jcmd = @(
  $JcmdPath
  (Join-Path $PSScriptRoot 'jdk25\bin\jcmd.exe')
  'C:\temp\heapdiag\jdk25\bin\jcmd.exe'
  'C:\Program Files\Zulu\zulu-25\bin\jcmd.exe'
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $jcmd) { throw "jcmd.exe not found. Pass -JcmdPath '<path>'." }
Write-Host "jcmd: $jcmd"

# --- locate the JVM ---------------------------------------------------------
# procrun hosts the JVM in-process, so it never appears in `jcmd -l`; ask the
# service control manager for the pid instead.
if ($PidTarget -le 0) {
  $svc = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
         Where-Object {
           $_.State -eq 'Running' -and $_.ProcessId -gt 0 -and
           ($_.PathName -match 'Deepnet|DualShield|prunsrv|tomcat')
         }
  if (-not $svc) { throw "No DualShield/procrun service found. Pass -PidTarget <pid>." }
  $pick = @($svc | Where-Object { $_.PathName -match 'DualShield' })[0]
  if (-not $pick) { $pick = @($svc)[0] }
  $PidTarget = [int]$pick.ProcessId
  Write-Host ("Service '{0}' pid={1} (logon account: {2})" -f $pick.Name, $PidTarget, $pick.StartName)
}

# VM.version prints e.g. "OpenJDK 64-Bit Server VM version 25.0.4+7-LTS" then
# "JDK 25.0.4" - note there is no literal "JVM" in that output, so match on what
# is actually there.
$probe = & $jcmd $PidTarget VM.version 2>&1 | Out-String
if ($probe -notmatch 'VM version|\bJDK\b|HotSpot|OpenJDK|Zulu') {
  throw "Attach to pid $PidTarget failed:`n$probe"
}
Write-Host "Attach OK.`n"

# --- 1. are the flags actually live? ----------------------------------------
Write-Host "=== Effective JVM command line ==="
$cmdline = & $jcmd $PidTarget VM.command_line 2>&1 | Out-String
$cmdline -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { Write-Host "  $($_.Trim())" }

Write-Host "`n=== Flag check ==="
$expect = @{
  'HeapDumpOnOutOfMemoryError' = 'heap dump on OOM'
  'HeapDumpPath'               = 'heap dump location'
  'ExitOnOutOfMemoryError'     = 'clean exit on OOM'
  'StartFlightRecording'       = 'JFR leak recording'
  'Xlog:gc'                    = 'GC log'
}
$missing = @()
foreach ($k in $expect.Keys) {
  if ($cmdline -match [regex]::Escape($k)) {
    Write-Host ("  present : {0,-28} ({1})" -f $k, $expect[$k])
  } else {
    Write-Host ("  MISSING : {0,-28} ({1})" -f $k, $expect[$k])
    $missing += $k
  }
}
if ($missing.Count) {
  Write-Host "`n  Some flags did not load. Either the service was not restarted after"
  Write-Host "  enable-heapdump.ps1 -Apply, or the edit landed on a different procrun"
  Write-Host "  service than the one running. Re-run enable-heapdump.ps1 (dry run) and"
  Write-Host "  check the service name it picks matches the one above."
}

# --- 2. JFR state -----------------------------------------------------------
Write-Host "`n=== JFR recordings ==="
$check = & $jcmd $PidTarget JFR.check 2>&1 | Out-String
$check -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { Write-Host "  $($_.Trim())" }

# --- 3. gc.log ---------------------------------------------------------------
Write-Host "`n=== GC log ==="
if ($cmdline -match 'Xlog:gc[^\s]*file=([^:]+(?::[^:\\/]*)?[^\s:]*\.log)') {
  $gcPath = $Matches[1]
  $found  = Get-ChildItem -LiteralPath (Split-Path $gcPath -Parent) -Filter "$(Split-Path $gcPath -Leaf)*" -ErrorAction SilentlyContinue
  if ($found) {
    $found | ForEach-Object {
      Write-Host ("  {0}  {1} KB  last written {2}" -f $_.Name, [math]::Round($_.Length/1KB), $_.LastWriteTime)
    }
  } else {
    Write-Host "  No gc.log found at $gcPath - check the path is writable by the service account."
  }
} else {
  Write-Host "  Could not read the gc.log path from the command line above."
}

# --- 4. optional JFR dump ---------------------------------------------------
if ($Dump) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $out   = Join-Path $OutDir "leak-$stamp.jfr"
  Write-Host "`n=== Dumping JFR recording ==="
  Write-Host "  This does not stop the recording; it keeps running afterwards."
  $r = & $jcmd $PidTarget JFR.dump name=leak filename=$out 2>&1 | Out-String
  Write-Host "  $($r.Trim())"
  if (Test-Path -LiteralPath $out) {
    Write-Host ("  Written: {0}  ({1} MB)" -f $out, [math]::Round((Get-Item $out).Length/1MB,2))
    Write-Host ""
    Write-Host "  Read it on a machine with a JDK:"
    Write-Host "    jfr summary `"$out`""
    Write-Host "    jfr print --events jdk.OldObjectSample `"$out`""
    Write-Host "  jdk.OldObjectSample carries the allocation stack traces of objects that"
    Write-Host "  SURVIVED, which is what identifies the leaking code path. It needs time to"
    Write-Host "  accumulate samples - a dump taken minutes after startup will be near-empty,"
    Write-Host "  so leave the JVM running a few hours before relying on it."
  } else {
    Write-Host "  Dump file was not created - see the jcmd output above."
  }
} else {
  Write-Host "`nRe-run with -Dump to write the JFR recording out for analysis."
}
