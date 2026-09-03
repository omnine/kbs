# heap-sample.ps1 - run ON nano190013 as Administrator.
#
# Differential leak loop for the DualShield Tomcat JVM.
# Takes a forced-GC heap reading + class histogram every $IntervalMin minutes and
# writes one CSV row per sample plus one histogram file per sample.
#
# Red condition: live-set (heap used immediately after a full GC) grows
# monotonically across samples while the box is idle. A healthy JVM returns to a
# flat baseline after every full GC; a leaking one steps up and never comes back.
#
# Usage:
# Output defaults to this script's own folder, so normally no paths are needed:
#   powershell -ExecutionPolicy Bypass -File heap-sample.ps1 -IntervalMin 15
#
# The DualShield JVM is hosted in-process by procrun, so it does NOT appear in
# `jcmd -l`. The script finds its pid via the service control manager instead.
# Attach needs SeDebugPrivilege or the service's own account, so normally:
#   psexec -s powershell -ExecutionPolicy Bypass -File heap-sample.ps1 -IntervalMin 15

param(
  # Defaults to the folder this script lives in, so the whole heapdiag folder can
  # be dropped on any drive (C:\temp\heapdiag, D:\heapdiag, ...) and just work.
  [string]$OutDir      = $PSScriptRoot,
  [int]   $IntervalMin = 15,
  [int]   $TopClasses  = 40,
  # Skip auto-discovery and attach to this pid. Use when `jcmd -l` shows the
  # JVM but the name match below does not pick it, or shows nothing useful.
  [int]   $PidTarget   = 0,
  # Full path to a JDK 25 jcmd.exe. The DualShield install is JRE-only and has
  # none; see the guidance printed if this cannot be resolved.
  [string]$JcmdPath    = ''
)

$ErrorActionPreference = 'Stop'

# --- locate jcmd -------------------------------------------------------------
# The DualShield install ships a JRE-only image, which has no jcmd.exe. jcmd has
# to come from a full JDK placed alongside; it attaches to the running service
# JVM over the HotSpot attach mechanism and needs no change to the service.
$jcmdCandidates = @(
  $JcmdPath
  (Join-Path $PSScriptRoot 'jdk25\bin\jcmd.exe')   # JDK copied next to this script
  'C:\temp\heapdiag\jdk25\bin\jcmd.exe'
  'D:\heapdiag\jdk25\bin\jcmd.exe'
  'C:\Program Files\Zulu\zulu-25\bin\jcmd.exe'
  'C:\Program Files\Deepnet DualShield\jdk\bin\jcmd.exe'
  'C:\Program Files\Deepnet DualShield\jre\bin\jcmd.exe'
) | Where-Object { $_ }

$jcmd = $jcmdCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $jcmd) {
  $jcmd = (Get-Command jcmd.exe -ErrorAction SilentlyContinue).Source
}
if (-not $jcmd) {
  Write-Host "jcmd.exe not found. Looked in:"
  $jcmdCandidates | ForEach-Object { Write-Host "  $_" }
  Write-Host ""
  Write-Host "The bundled 'C:\Program Files\Deepnet DualShield\jre' is a JRE-only image,"
  Write-Host "so it has no jcmd. Copy a full JDK 25 onto this VM - no install, no PATH"
  Write-Host "change, and the DualShield service is not touched:"
  Write-Host ""
  Write-Host "  1. On the dev box, copy the whole tree (~379 MB):"
  Write-Host "       C:\Program Files\Zulu\zulu-25   ->   $PSScriptRoot\jdk25"
  Write-Host "     That build is Zulu25.36+15-CA (25.0.4+7-LTS) - the same build as this"
  Write-Host "     VM's JRE, so attach is guaranteed compatible."
  Write-Host "  2. Re-run this script. It picks up $PSScriptRoot\jdk25\bin\jcmd.exe"
  Write-Host "     automatically, or pass -JcmdPath '<path to jcmd.exe>'."
  throw "jcmd.exe not found - see the guidance above."
}
Write-Host "jcmd: $jcmd"

# --- locate the Tomcat JVM --------------------------------------------------
# `jcmd -l` is NOT reliable here. It enumerates JVMs by scanning hsperfdata
# files, and procrun (prunsrv.exe) hosts the JVM in-process via JNI_CreateJavaVM
# rather than launching java.exe - so the service never shows up as a Java
# launcher for -l to find, whatever account you run as.
#
# Attach BY PID works regardless: on Windows the attach mechanism injects a
# thread into the target and calls into its loaded jvm.dll, which needs neither
# hsperfdata nor a recognisable process name. So the job is just to find the
# service's process id, which the service control manager knows.
if ($PidTarget -gt 0) {
  Write-Host "Using supplied pid=$PidTarget (auto-discovery skipped)"
} else {
  # 1. Ask the SCM for the pid of any service whose binary lives in a DualShield
  #    or procrun install. This is the path that actually works for procrun.
  $svc = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
         Where-Object {
           $_.State -eq 'Running' -and $_.ProcessId -gt 0 -and
           ($_.PathName -match 'Deepnet|DualShield|prunsrv|tomcat')
         }

  if ($svc) {
    Write-Host "Candidate services (from the service control manager):"
    $svc | ForEach-Object {
      Write-Host ("  pid {0,-8} {1}  [{2}]" -f $_.ProcessId, $_.Name, $_.StartName)
    }
    # Prefer one whose jvm is the DualShield tomcat, if more than one matched.
    $pick = @($svc | Where-Object { $_.PathName -match 'DualShield' })[0]
    if (-not $pick) { $pick = @($svc)[0] }
    $PidTarget = [int]$pick.ProcessId
    Write-Host ("Selected pid={0} from service '{1}' (logon account: {2})" -f `
      $PidTarget, $pick.Name, $pick.StartName)
  }
  else {
    # 2. Fall back to jcmd -l, in case this is a plain java.exe deployment.
    $listing = & $jcmd -l 2>$null
    $line = $listing | Where-Object { $_ -match 'Bootstrap|catalina|tomcat' } | Select-Object -First 1
    if ($line) {
      $PidTarget = [int](($line -split '\s+')[0])
      Write-Host "Target JVM pid=$PidTarget  ($line)"
    }
    else {
      Write-Host "No DualShield/procrun service found, and jcmd -l returned:"
      $listing | ForEach-Object { Write-Host "  $_" }
      Write-Host ""
      Write-Host "Find the service process id by hand and pass it in:"
      Write-Host "    Get-CimInstance Win32_Service | Where-Object State -eq Running |"
      Write-Host "      Select-Object Name, ProcessId, StartName, PathName | Format-List"
      Write-Host "  then:"
      Write-Host ("    psexec -s powershell -ExecutionPolicy Bypass -File {0}\heap-sample.ps1 -PidTarget <pid>" -f $PSScriptRoot)
      throw "Could not identify the Tomcat JVM - see the guidance above."
    }
  }
}

# Sanity-check the attach actually works before committing to a long loop.
# VM.version prints e.g. "OpenJDK 64-Bit Server VM version 25.0.4+7-LTS" then
# "JDK 25.0.4" - note there is no literal "JVM" in that output.
$probe = & $jcmd $PidTarget VM.version 2>&1 | Out-String
if ($probe -notmatch 'VM version|\bJDK\b|HotSpot|OpenJDK|Zulu') {
  Write-Host "Attach probe to pid $PidTarget failed. jcmd said:"
  Write-Host $probe
  Write-Host "Things to check, in order:"
  Write-Host "  1. Identity. Attach needs the same account as the target, or SeDebugPrivilege."
  Write-Host "     Run under SYSTEM:  psexec -s powershell -ExecutionPolicy Bypass -File $PSScriptRoot\heap-sample.ps1"
  Write-Host "     If the service's logon account printed above is NOT LocalSystem, run as that"
  Write-Host "     account instead:   psexec -u <account> -p <pw> powershell ..."
  Write-Host "  2. Wrong pid. procrun may run a separate monitor process; confirm the pid you"
  Write-Host "     picked is the one hosting jvm.dll:"
  Write-Host "       Get-Process -Id $PidTarget -Module | Where-Object ModuleName -eq 'jvm.dll'"
  Write-Host "  3. Attach disabled. If the service Options contain -XX:+DisableAttachMechanism,"
  Write-Host "     no attach can work and the JFR route is the only option - see"
  Write-Host "     enable-heapdump.ps1, which needs nothing installed on the VM."
  throw "Attach to pid $PidTarget failed - see the guidance above."
}
Write-Host "Attach OK."

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$csv = Join-Path $OutDir 'heap-samples.csv'
if (-not (Test-Path $csv)) {
  'timestamp,uptime_s,heap_used_mb,heap_committed_mb,heap_max_mb,threads,loaded_classes' |
    Out-File -FilePath $csv -Encoding utf8
}

function Get-HeapUsedMb {
  # G1 on JDK 25 prints exactly:
  #   garbage-first heap   total reserved 524288K, committed 367616K, used 241245K [0x...]
  # Note "total reserved" - matching on a bare 'total' misses committed entirely.
  $info = & $jcmd $PidTarget GC.heap_info 2>$null | Out-String
  $used      = if ($info -match 'used\s+(\d+)K')      { [int]$Matches[1] / 1024 } else { -1 }
  $committed = if ($info -match 'committed\s+(\d+)K') { [int]$Matches[1] / 1024 } else { -1 }
  $max       = if ($info -match 'reserved\s+(\d+)K')  { [int]$Matches[1] / 1024 } else { -1 }
  [pscustomobject]@{ Used = [math]::Round($used); Committed = [math]::Round($committed); Max = [math]::Round($max); Raw = $info }
}

while ($true) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

  # Force a full GC first: we want the LIVE SET, not floating garbage.
  # Without this, normal allocation noise swamps a slow leak.
  & $jcmd $PidTarget GC.run           2>$null | Out-Null
  Start-Sleep -Seconds 5
  & $jcmd $PidTarget GC.run           2>$null | Out-Null
  Start-Sleep -Seconds 5

  $heap = Get-HeapUsedMb

  $vm      = & $jcmd $PidTarget VM.uptime      2>$null | Out-String
  $uptime  = if ($vm -match '([\d.]+)\s*s') { [math]::Round([double]$Matches[1]) } else { -1 }
  $threads = (& $jcmd $PidTarget Thread.print 2>$null | Select-String -Pattern '^"' ).Count
  $classes = (& $jcmd $PidTarget VM.class_hierarchy 2>$null | Measure-Object -Line).Lines

  "$stamp,$uptime,$($heap.Used),$($heap.Committed),$($heap.Max),$threads,$classes" |
    Out-File -FilePath $csv -Append -Encoding utf8

  # Full histogram, kept per-sample so it can be diffed later.
  #
  # Do NOT discard stderr here. GC.class_histogram walks the whole heap and can
  # fail or time out on a large one, and swallowing the error leaves an empty
  # file that only shows up as a blank diff hours later. Merge stderr into the
  # file and check the result looks like a histogram.
  $histFile = Join-Path $OutDir "hist-$stamp.txt"
  & $jcmd $PidTarget GC.class_histogram 2>&1 | Out-File -FilePath $histFile -Encoding utf8

  $histLines = @(Get-Content $histFile -ErrorAction SilentlyContinue)
  $dataRows  = @($histLines | Where-Object { $_ -match '^\s*\d+:\s+\d+\s+\d+\s+\S' }).Count
  if ($dataRows -lt 10) {
    Write-Host "   WARNING: histogram has only $dataRows data row(s) - it is unusable."
    Write-Host "   Raw jcmd output was:"
    $histLines | Select-Object -First 15 | ForEach-Object { Write-Host "     $_" }
    Write-Host "   Retrying once with parallelism disabled..."
    $tmp = Join-Path $OutDir "hist-$stamp.retry.txt"
    # -parallel=1 uses a single thread for the heap walk. Same live-object
    # semantics as the default, just less resource pressure - a plausible fix if
    # the parallel inspection is what struggles on this heap.
    #
    # Deliberately NOT -all=true: that would include unreachable objects, which
    # is the wrong question for a leak and would not be comparable with the
    # other samples in the diff.
    & $jcmd $PidTarget GC.class_histogram -parallel=1 2>&1 | Out-File -FilePath $tmp -Encoding utf8
    $retryRows = @(Get-Content $tmp -ErrorAction SilentlyContinue |
                   Where-Object { $_ -match '^\s*\d+:\s+\d+\s+\d+\s+\S' }).Count
    Write-Host "   Retry produced $retryRows data row(s) -> $tmp"
    if ($retryRows -ge 10) {
      Move-Item -Force $tmp $histFile
      $histLines = @(Get-Content $histFile)
      $dataRows  = $retryRows
      Write-Host "   Retry succeeded; using it."
    }
  }

  Write-Host ("[{0}] live-set {1} MB / committed {2} MB / max {3} MB  threads={4}" -f `
    $stamp, $heap.Used, $heap.Committed, $heap.Max, $threads)
  Write-Host ("   histogram -> {0}  ({1} classes)" -f $histFile, $dataRows)
  if ($dataRows -gt 0) {
    Write-Host "   top $TopClasses by bytes:"
    # Filter to real data rows rather than skipping a fixed number of header
    # lines, so a changed header or a warning line cannot blank out the display.
    $histLines | Where-Object { $_ -match '^\s*\d+:\s+\d+\s+\d+\s+\S' } |
      Select-Object -First $TopClasses | ForEach-Object { Write-Host "     $_" }
  }

  Start-Sleep -Seconds ($IntervalMin * 60)
}
