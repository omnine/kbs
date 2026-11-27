<#
.SYNOPSIS
  Create (or validate) an OpenProject work package via API v3.

.DESCRIPTION
  Reads the server URL and API token from environment variables:
    OPENPROJECT_URL      e.g. https://openproject.example.com
    OPENPROJECT_API_KEY  personal API token (My account -> Access tokens -> API)

  Type, priority, status and assignee are given by NAME and resolved to IDs.

.EXAMPLE
  ./New-OpenProjectIssue.ps1 -Project my-project -Subject "Login 500" -Type Bug -Priority High

.EXAMPLE
  ./New-OpenProjectIssue.ps1 -Project my-project -List
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $Project,      # project identifier or numeric id
  [string] $Subject,
  [string] $Type = "Task",
  [string] $Description,                         # markdown
  [string] $DescriptionFile,                     # path to a markdown file (alternative to -Description)
  [string] $Priority,
  [string] $Status,
  [string] $Assignee,                            # name, login or email (partial match ok)
  [string] $StartDate,                           # yyyy-MM-dd
  [string] $DueDate,                             # yyyy-MM-dd
  [string] $EstimatedHours,
  [int]    $Parent,                              # parent work package id
  [switch] $NoNotify,
  [switch] $DryRun,                              # validate via the /form endpoint, create nothing
  [switch] $List                                 # list types, priorities, statuses, assignees and exit
)

$ErrorActionPreference = "Stop"

$base  = $env:OPENPROJECT_URL
$token = $env:OPENPROJECT_API_KEY
if (-not $base -or -not $token) {
  throw "Set OPENPROJECT_URL and OPENPROJECT_API_KEY environment variables first."
}
$base = $base.TrimEnd("/")
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("apikey:$token"))
$headers = @{ Authorization = "Basic $auth"; Accept = "application/hal+json" }
$projEnc = [Uri]::EscapeDataString($Project)

function Invoke-Op([string]$Method, [string]$Path, $Body) {
  $params = @{ Method = $Method; Uri = "$base$Path"; Headers = $headers }
  if ($null -ne $Body) {
    $params.ContentType = "application/json; charset=utf-8"
    $params.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 10))
  }
  try {
    Invoke-RestMethod @params
  } catch {
    $msg = $_.ErrorDetails.Message
    if ($msg) {
      try {
        $err = $msg | ConvertFrom-Json
        $details = @($err.message)
        if ($err._embedded.errors) { $details += $err._embedded.errors | ForEach-Object { $_.message } }
        throw "OpenProject API error ($Method $Path): $($details -join '; ')"
      } catch [System.ArgumentException] { }
      throw "OpenProject API error ($Method $Path): $msg"
    }
    throw
  }
}

function Get-Elements([string]$Path) {
  $r = Invoke-Op GET $Path $null
  @($r._embedded.elements)
}

function Resolve-ByName($Elements, [string]$Name, [string]$Kind, [string[]]$Fields = @("name")) {
  $exact = @($Elements | Where-Object { $e = $_; $Fields | Where-Object { "$($e.$_)" -ieq $Name } })
  if ($exact.Count -ge 1) { return $exact[0] }
  $partial = @($Elements | Where-Object { $e = $_; $Fields | Where-Object { "$($e.$_)" -ilike "*$Name*" } })
  if ($partial.Count -eq 1) { return $partial[0] }
  $avail = ($Elements | ForEach-Object { $_.name }) -join ", "
  if ($partial.Count -gt 1) { throw "$Kind '$Name' is ambiguous. Matches: $(($partial | ForEach-Object { $_.name }) -join ', ')" }
  throw "$Kind '$Name' not found. Available: $avail"
}

if ($List) {
  "== Types enabled in '$Project' =="
  Get-Elements "/api/v3/projects/$projEnc/types" | ForEach-Object { "  $($_.id)`t$($_.name)" }
  "== Priorities =="
  Get-Elements "/api/v3/priorities" | ForEach-Object { "  $($_.id)`t$($_.name)" }
  "== Statuses =="
  Get-Elements "/api/v3/statuses" | ForEach-Object { "  $($_.id)`t$($_.name)" }
  "== Available assignees =="
  Get-Elements "/api/v3/projects/$projEnc/available_assignees" | ForEach-Object { "  $($_.id)`t$($_.name)`t$($_.login)" }
  return
}

if (-not $Subject) { throw "-Subject is required." }

$links = @{}
$typeObj = Resolve-ByName (Get-Elements "/api/v3/projects/$projEnc/types") $Type "Type"
$links.type = @{ href = $typeObj._links.self.href }

if ($Priority) {
  $p = Resolve-ByName (Get-Elements "/api/v3/priorities") $Priority "Priority"
  $links.priority = @{ href = $p._links.self.href }
}
if ($Status) {
  $s = Resolve-ByName (Get-Elements "/api/v3/statuses") $Status "Status"
  $links.status = @{ href = $s._links.self.href }
}
if ($Assignee) {
  $a = Resolve-ByName (Get-Elements "/api/v3/projects/$projEnc/available_assignees") $Assignee "Assignee" @("name", "login", "email")
  $links.assignee = @{ href = $a._links.self.href }
}
if ($Parent) { $links.parent = @{ href = "/api/v3/work_packages/$Parent" } }

$body = @{ subject = $Subject; _links = $links }

if ($DescriptionFile) { $Description = Get-Content -Raw -Encoding UTF8 $DescriptionFile }
if ($Description)     { $body.description = @{ format = "markdown"; raw = $Description } }
if ($StartDate)       { $body.startDate = $StartDate }
if ($DueDate)         { $body.dueDate = $DueDate }
if ($EstimatedHours)  { $body.estimatedTime = "PT$($EstimatedHours)H" }

if ($DryRun) {
  $form = Invoke-Op POST "/api/v3/projects/$projEnc/work_packages/form" $body
  $errors = $form._embedded.validationErrors
  if ($errors -and ($errors.PSObject.Properties | Measure-Object).Count -gt 0) {
    "VALIDATION FAILED:"
    $errors.PSObject.Properties | ForEach-Object { "  $($_.Name): $($_.Value.message)" }
    exit 1
  }
  "VALID - nothing created. Payload:"
  $body | ConvertTo-Json -Depth 10
  return
}

$path = "/api/v3/projects/$projEnc/work_packages"
if ($NoNotify) { $path += "?notify=false" }
$wp = Invoke-Op POST $path $body

[pscustomobject]@{
  Id       = $wp.id
  Subject  = $wp.subject
  Type     = $wp._links.type.title
  Status   = $wp._links.status.title
  Priority = $wp._links.priority.title
  Assignee = $wp._links.assignee.title
  Url      = "$base/work_packages/$($wp.id)"
} | Format-List
