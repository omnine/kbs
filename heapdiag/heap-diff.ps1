# heap-diff.ps1 - run anywhere the D:\heapdiag output has been copied.
#
# Diffs two GC.class_histogram files produced by heap-sample.ps1 and prints the
# classes that grew the most between them. The leaking type is normally at the
# top of this list with a large, near-linear delta.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File heap-diff.ps1 `
#       -Before D:\heapdiag\hist-20260902-100000.txt `
#       -After  D:\heapdiag\hist-20260902-160000.txt

param(
  [Parameter(Mandatory)][string]$Before,
  [Parameter(Mandatory)][string]$After,
  [int]$Top = 30
)

$ErrorActionPreference = 'Stop'

function Read-Histogram([string]$Path) {
  $map = @{}
  foreach ($line in Get-Content $Path) {
    # jcmd format:  "   1:      123456     7891011  java.lang.String"
    if ($line -match '^\s*\d+:\s+(\d+)\s+(\d+)\s+(\S+)') {
      $map[$Matches[3]] = [pscustomobject]@{
        Instances = [long]$Matches[1]
        Bytes     = [long]$Matches[2]
      }
    }
  }
  return $map
}

$b = Read-Histogram $Before
$a = Read-Histogram $After

$rows = foreach ($cls in $a.Keys) {
  $bBytes = if ($b.ContainsKey($cls)) { $b[$cls].Bytes }     else { 0 }
  $bInst  = if ($b.ContainsKey($cls)) { $b[$cls].Instances } else { 0 }
  [pscustomobject]@{
    Class        = $cls
    DeltaBytes   = $a[$cls].Bytes - $bBytes
    DeltaMB      = [math]::Round(($a[$cls].Bytes - $bBytes) / 1MB, 2)
    DeltaInst    = $a[$cls].Instances - $bInst
    AfterMB      = [math]::Round($a[$cls].Bytes / 1MB, 2)
  }
}

Write-Host "=== Top $Top growers: $(Split-Path $Before -Leaf) -> $(Split-Path $After -Leaf) ==="
$rows | Sort-Object DeltaBytes -Descending | Select-Object -First $Top |
  Format-Table Class, DeltaMB, DeltaInst, AfterMB -AutoSize

Write-Host ""
Write-Host "=== Total heap delta ==="
$totalB = ($b.Values | Measure-Object -Property Bytes -Sum).Sum
$totalA = ($a.Values | Measure-Object -Property Bytes -Sum).Sum
Write-Host ("  before {0} MB -> after {1} MB  (delta {2} MB)" -f `
  [math]::Round($totalB/1MB), [math]::Round($totalA/1MB), [math]::Round(($totalA-$totalB)/1MB))
