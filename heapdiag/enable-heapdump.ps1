# enable-heapdump.ps1 - run ON nano190013 as Administrator.
#
# Adds crash-capture JVM flags to the DualShield Tomcat service so the NEXT
# OutOfMemoryError leaves behind a heap dump and a GC log. Without these the
# JVM dies silently and there is nothing to analyse - which is exactly the
# situation we are in now.
#
# DualShield's Tomcat runs under Apache procrun, which reads its JVM options
# from the registry (not from setenv.bat / CATALINA_OPTS), so that is what this
# edits.
#
# SAFE BY DEFAULT: with no switches it only REPORTS the current configuration
# and prints the exact change it would make. Nothing is written and the service
# is not touched. Re-run with -Apply to write the change.
#
#   powershell -ExecutionPolicy Bypass -File enable-heapdump.ps1
#   powershell -ExecutionPolicy Bypass -File enable-heapdump.ps1 -Apply
#
# Heap dumps land in -DumpDir, default:
#     D:\heapdiag\dumps
# deliberately off the system drive, since one dump can reach Xmx (4 GB).
#
# The GC log lands in -GcLogDir, default the live Tomcat log directory on the VM:
#     C:\Program Files\Deepnet DualShield\tomcat\logs
# i.e. next to catalina.*.log and dualshield-stderr.*.log.
#
# The new flags take effect only after a service restart, which this script
# never performs - restart it yourself in a window you choose.

param(
  # Heap dumps land next to this script by default, so the heapdiag folder can be
  # dropped on any drive and just work. One dump can reach Xmx (4 GB), so on a
  # box with a spare data volume prefer that over the C: system drive - pass
  # -DumpDir explicitly. The free-space report below tells you if C: is too tight.
  [string]$DumpDir     = (Join-Path $PSScriptRoot 'dumps'),
  # GC log: goes to the real Tomcat log directory, alongside catalina.*.log and
  # dualshield-stderr.*.log, so it is picked up by the usual log collection.
  # Capped at 20 x 20 MB, so ~400 MB worst case.
  [string]$GcLogDir    = 'C:\Program Files\Deepnet DualShield\tomcat\logs',
  [string]$ServiceName = '',
  # Omit the JFR leak-profiling flags. On by default: they need nothing
  # installed on the VM and give allocation stack traces for surviving objects.
  [switch]$NoJfr,
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'

# DualShield's procrun service was installed by a 32-bit installer, so on x64
# its keys land in the WOW6432 registry view. Check that first, then the native
# view, so this works on both old and new installs.
$procrunRoots = @(
  'HKLM:\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0'
  'HKLM:\SOFTWARE\Apache Software Foundation\Procrun 2.0'
)
$procrunRoot = $procrunRoots | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $procrunRoot) {
  throw ("Procrun registry root not found in either view:`n  " +
         ($procrunRoots -join "`n  ") +
         "`nThis service may not be a procrun service. Stop here and report back.")
}
Write-Host "Procrun root: $procrunRoot"

# --- identify the service ----------------------------------------------------
if (-not $ServiceName) {
  $candidates = Get-ChildItem $procrunRoot | Select-Object -ExpandProperty PSChildName
  Write-Host "Procrun services found:"
  $candidates | ForEach-Object { Write-Host "  - $_" }

  $guess = $candidates | Where-Object { $_ -match 'dual|tomcat|shield' }
  if ($guess.Count -eq 1) {
    $ServiceName = $guess
    Write-Host "`nAuto-selected: $ServiceName"
  } else {
    throw "`nCould not pick a service unambiguously. Re-run with -ServiceName <name> using one of the names above."
  }
}

$javaKey = Join-Path $procrunRoot "$ServiceName\Parameters\Java"
if (-not (Test-Path $javaKey)) { throw "Key not found: $javaKey" }

$props = Get-ItemProperty -Path $javaKey

# REG_MULTI_SZ, one JVM arg per element. Guard against the value being absent
# or carrying blank elements - a null slipping into the array would be written
# back as an empty JVM argument and stop the service from starting.
$current = @($props.Options) | Where-Object { $_ -and $_.Trim() -ne '' }

Write-Host "`n=== Current [$ServiceName] Parameters\Java ==="
Write-Host ("  Xms (DWORD MB) : {0}" -f $props.Xms)
Write-Host ("  Xmx (DWORD MB) : {0}" -f $props.Xmx)
Write-Host "  Options:"
if ($current.Count -eq 0) { Write-Host "    <empty>" }
$current | ForEach-Object { Write-Host "    $_" }

# --- flags we want -----------------------------------------------------------
# HeapDumpOnOutOfMemoryError : the artifact we are missing. Writes one .hprof
#                              the first time the heap is exhausted.
# HeapDumpPath               : keep it OFF the C: system drive - a 4 GB dump
#                              filling C: would take the whole box down.
# ExitOnOutOfMemoryError     : after a heap OOM the JVM is unusable (we saw
#                              cascading "zip file closed" damage). Exit so the
#                              service manager restarts it cleanly. The dump is
#                              written before the exit.
# -Xlog:gc*                  : the leak curve. 20 x 20 MB rotating files, written
#                              into the live Tomcat log directory on the VM.
#
# The gc.log path contains spaces ("Program Files", "Deepnet DualShield"). That
# is fine and must NOT be quoted here: procrun stores Options as REG_MULTI_SZ
# and hands each element to the JVM as one argv entry, so no shell splitting
# happens. Adding quotes would make them part of the literal filename.
$wanted = @(
  '-XX:+HeapDumpOnOutOfMemoryError'
  "-XX:HeapDumpPath=$DumpDir"
  '-XX:+ExitOnOutOfMemoryError'
  "-Xlog:gc*,gc+heap=debug:file=$GcLogDir\gc.log:time,uptime,level,tags:filecount=20,filesize=20M"
)

# --- JFR: the leak-attribution flags ----------------------------------------
# Worth adding because the DualShield JRE has no jcmd, but JFR is built into the
# JVM itself and needs nothing installed on the VM.
#
# jdk.OldObjectSample is the event designed for exactly this problem: it samples
# objects that SURVIVE, and records the allocation stack trace. That beats a
# class histogram for attribution - a histogram says "byte[] grew by 3 GB",
# OldObjectSample says which code allocated it.
#
# dumponexit=true pairs with -XX:+ExitOnOutOfMemoryError above: the JVM writes
# the recording out as it dies from the OOM, so the next occurrence yields both
# a heap dump and a JFR recording.
#
# Cost: settings=profile is roughly 1-2% CPU. Irrelevant on a box this idle.
# Read the result on a machine with a JDK: `jfr summary leak.jfr`, then open in
# JDK Mission Control -> Automated Analysis / Live Objects.
if (-not $NoJfr) {
  $wanted += @(
    ("-XX:StartFlightRecording=name=leak,settings=profile,maxsize=512m,dumponexit=true," +
     "filename=$DumpDir\leak.jfr," +
     "jdk.OldObjectSample#enabled=true,jdk.OldObjectSample#stackTrace=true," +
     "jdk.OldObjectSample#cutoff=0 ms")
    '-XX:FlightRecorderOptions=stackdepth=128'
  )
}

# Replace any pre-existing copy of each flag rather than appending a duplicate.
$kept = $current | Where-Object {
  $arg = $_
  -not ($arg -match '^-XX:\+?HeapDumpOnOutOfMemoryError' -or
        $arg -match '^-XX:HeapDumpPath='                 -or
        $arg -match '^-XX:\+?ExitOnOutOfMemoryError'     -or
        $arg -match '^-XX:StartFlightRecording'          -or
        $arg -match '^-XX:FlightRecorderOptions'         -or
        $arg -match '^-Xlog:gc')
}
$new = @($kept) + $wanted

Write-Host "`n=== Proposed Options ==="
$new | ForEach-Object { Write-Host "    $_" }

# --- path checks -------------------------------------------------------------
# The GC log dir must already exist. If the guess is wrong we want to know now,
# rather than quietly creating a new folder nobody ever looks in.
$gcLogDirOk = Test-Path -LiteralPath $GcLogDir
Write-Host "`n=== Paths ==="
Write-Host ("  Heap dumps : {0}" -f $DumpDir)
Write-Host ("  GC log     : {0}\gc.log" -f $GcLogDir)
if ($gcLogDirOk) {
  $siblings = @(Get-ChildItem -LiteralPath $GcLogDir -Filter 'catalina*.log' -ErrorAction SilentlyContinue).Count
  Write-Host ("               exists, {0} catalina*.log sibling(s) present" -f $siblings)
  if ($siblings -eq 0) {
    Write-Host "               WARNING: no catalina*.log here - is this really the live Tomcat log dir?"
  }
} else {
  Write-Host "               DOES NOT EXIST - pass the correct one with -GcLogDir '<path>'"
}

# A heap dump can be as large as the live heap, so budget Xmx plus headroom.
# Read Xmx from the service config rather than assuming 4 GB - it may have been
# changed. Fall back to any -Xmx in Options if the DWORD is unset.
$xmxMb = 0
if ($props.Xmx) { $xmxMb = [int]$props.Xmx }
elseif (($current -join ' ') -match '-Xmx(\d+)([mMgG])') {
  $xmxMb = if ($Matches[2] -match '[gG]') { [int]$Matches[1] * 1024 } else { [int]$Matches[1] }
}
$needGb = if ($xmxMb -gt 0) { [math]::Round($xmxMb / 1024, 1) } else { 4 }

Write-Host "`n=== Free space ==="
Write-Host ("  Xmx is {0} MB, so budget ~{1} GB for one heap dump." -f $xmxMb, $needGb)
$dumpVolTight = $false
foreach ($p in @($DumpDir, $GcLogDir)) {
  $q = (Split-Path $p -Qualifier) -replace ':',''
  $d = Get-PSDrive $q -ErrorAction SilentlyContinue
  if (-not $d) { Write-Host ("  {0}: drive not found ({1})" -f $q, $p); continue }
  $freeGb = [math]::Round($d.Free/1GB,1)
  $role   = if ($p -eq $DumpDir) { 'heap dumps' } else { 'GC log' }
  Write-Host ("  {0}: {1} GB free   [{2}]  {3}" -f $q, $freeGb, $role, $p)
  if ($p -eq $DumpDir -and $freeGb -lt $needGb) {
    $dumpVolTight = $true
    Write-Host ("       WARNING: less than {0} GB free. A dump could fill this volume." -f $needGb)
    if ($q -eq 'C') {
      Write-Host "       This is the system drive - filling it would take the whole box down."
    }
    Write-Host "       Point -DumpDir at a volume with more room."
  }
}
Write-Host "  The GC log is capped at 20 x 20 MB, so ~0.5 GB worst case."

if (-not $Apply) {
  Write-Host "`nDRY RUN - nothing written. Re-run with -Apply to commit."
  return
}

if (-not $gcLogDirOk) {
  throw "GC log directory does not exist: $GcLogDir`nRe-run with -GcLogDir pointing at the real Tomcat logs directory on this VM."
}
if ($dumpVolTight) {
  throw ("Not enough free space on the -DumpDir volume for a $needGb GB heap dump.`n" +
         "Point -DumpDir at a roomier volume, or free space first. Refusing to arm a " +
         "dump that could fill the disk.")
}

# --- apply -------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $DumpDir | Out-Null

$backup = Join-Path $DumpDir ("procrun-Options-backup-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$current | Out-File -FilePath $backup -Encoding utf8
Write-Host "`nPrevious Options backed up to: $backup"

Set-ItemProperty -Path $javaKey -Name 'Options' -Value $new -Type MultiString
Write-Host "Written."

Write-Host "`nVerify:"
(Get-ItemProperty -Path $javaKey).Options | ForEach-Object { Write-Host "    $_" }

Write-Host ""
Write-Host "NOT YET ACTIVE. The flags load only on JVM start. Restart the service"
Write-Host "when you are ready, in a window you choose:"
Write-Host "    Restart-Service '$ServiceName'"
Write-Host ""
Write-Host "To roll back: Set-ItemProperty -Path '$javaKey' -Name Options -Type MultiString -Value (Get-Content '$backup')"
