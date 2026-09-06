<#
.SYNOPSIS
    PentagonSetup - one-command Windows debloat + privacy setup.

.DESCRIPTION
    Runs, in order:
      1.  Win11Debloat (latest)   - default mode, silent
      2.  Winutil (latest)        - your saved config (winutil-config.json)
      2b. Windows Update 'Recommended' profile (clean-room implementation)
      2c. Cloudflare DNS + DoH on every active adapter
      2d. Ultimate Performance power plan (skipped on battery systems)
      3.  O&O ShutUp10++          - your settings (ooshutup10.cfg), silent

    Remote runs (irm ... | iex) fully clean up after themselves on success:
    the download cache and logs are deleted - nothing is left behind.
    A failed run keeps its logs for debugging.

.EXAMPLE
    irm https://raw.githubusercontent.com/PentagonXen/PentagonSetup/main/pentagon-setup.ps1 | iex
.EXAMPLE
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/PentagonXen/PentagonSetup/main/pentagon-setup.ps1))) -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipDebloat,
    [switch]$SkipWinutil,
    [switch]$SkipUpdateProfile,
    [switch]$SkipDns,
    [switch]$SkipPowerPlan,
    [switch]$SkipShutup,
    [switch]$KeepCache,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$RepoRaw           = 'https://raw.githubusercontent.com/PentagonXen/PentagonSetup/main'
$script:Results    = [ordered]@{}
$script:HadFailure = $false

function Test-IsAdmin {
    (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# -- Dual-mode root: local project folder, or download cache for remote runs --
$IsCacheRun = ($env:PENTAGONSETUP_REMOTE -eq '1')
$RemoteBoot = (-not $PSScriptRoot)
if ($RemoteBoot) {
    $env:PENTAGONSETUP_REMOTE = '1'
    $Root = Join-Path $env:LOCALAPPDATA 'PentagonSetup'
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    Write-Host 'First stage: fetching PentagonSetup files from GitHub...'
    foreach ($f in 'pentagon-setup.ps1', 'winutil-config.json', 'ooshutup10.cfg') {
        Invoke-WebRequest -Uri "$RepoRaw/$f" -OutFile (Join-Path $Root $f) -UseBasicParsing
    }
}
else {
    $Root = $PSScriptRoot
}
$CacheRun = $IsCacheRun -or $RemoteBoot
$LogDir   = Join-Path $Root 'logs'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$Stamp    = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
Start-Transcript -Path (Join-Path $LogDir "pentagon-setup_$Stamp.log") | Out-Null

Write-Host ''
Write-Host '=== PentagonSetup ===' -ForegroundColor Cyan
Write-Host "Run mode : $(if ($RemoteBoot) { 'remote (cache: ' + $Root + ')' } else { 'local (' + $Root + ')' })"
Write-Host "Elevated : $(Test-IsAdmin)   DryRun: $DryRun"

# -- Elevation relay (skipped for -DryRun so it can be tested un-elevated) --
if (-not (Test-IsAdmin) -and -not $DryRun) {
    Stop-Transcript | Out-Null
    Write-Host 'Not elevated - relaunching with administrator rights (accept the UAC prompt)...'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Root\pentagon-setup.ps1`"")
    foreach ($k in $PSBoundParameters.Keys) { $argList += "-$k" }
    try {
        $p = Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait -PassThru
    }
    catch {
        Write-Host 'Elevation declined or failed - aborting. Nothing was changed.' -ForegroundColor Red
        if ($RemoteBoot) { return }
        exit 1
    }
    Write-Host "Setup ran in the elevated window (exit code $($p.ExitCode))."
    return
}

function Invoke-Step {
    param([string]$Name, [string]$Desc, [scriptblock]$Action)
    Write-Host ''
    Write-Host "=== [$Name] ===" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "DRYRUN - would run: $Desc" -ForegroundColor Yellow
        $script:Results[$Name] = 'DRYRUN'
        return
    }
    try {
        & $Action
        if (-not $script:Results.Contains($Name)) { $script:Results[$Name] = 'PASS' }
    }
    catch {
        $script:Results[$Name] = "FAIL - $($_.Exception.Message)"
        $script:HadFailure = $true
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-RecommendedUpdateProfile {
    # Windows Update 'Recommended' profile - original implementation.
    # The policy keys and values are Microsoft's public Windows Update policy
    # constants; no third-party source code is reproduced in this repo.
    $polRoot   = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $polAuto   = "$polRoot\AU"
    $drvSearch = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching'
    $devMeta   = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata'

    # 1. Update services: BITS and the Windows Update service on demand,
    #    the Update Orchestrator active in the background.
    $svcModes = @{ 'BITS' = 'Manual'; 'wuauserv' = 'Manual'; 'UsoSvc' = 'Automatic' }
    foreach ($name in $svcModes.Keys) {
        Set-Service -Name $name -StartupType $svcModes[$name]
    }
    Start-Service -Name UsoSvc

    # 2. Re-arm the update pipeline scheduled tasks.
    foreach ($taskPath in @('\Microsoft\Windows\InstallService\',
                            '\Microsoft\Windows\UpdateOrchestrator\',
                            '\Microsoft\Windows\UpdateAssistant\',
                            '\Microsoft\Windows\WaaSMedic\',
                            '\Microsoft\Windows\WindowsUpdate\',
                            '\Microsoft\WindowsUpdate\')) {
        Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue |
            Enable-ScheduledTask -ErrorAction SilentlyContinue
    }

    # 3. Do not offer or auto-search drivers through Windows Update.
    New-Item -Path $drvSearch -Force | Out-Null
    $driverPolicies = @{
        'DontPromptForWindowsUpdate'        = 1
        'DontSearchWindowsUpdate'          = 1
        'DriverUpdateWizardWuSearchEnabled' = 0
    }
    foreach ($key in $driverPolicies.Keys) {
        Set-ItemProperty -Path $drvSearch -Name $key -Type DWord -Value $driverPolicies[$key]
    }
    New-Item -Path $devMeta -Force | Out-Null
    Set-ItemProperty -Path $devMeta -Name 'PreventDeviceMetadataFromNetwork' -Type DWord -Value 1

    # 4. Deferral schedule: features 365 days, quality updates 4 days,
    #    drivers excluded from quality updates.
    New-Item -Path $polRoot -Force | Out-Null
    $deferrals = @{
        'ExcludeWUDriversInQualityUpdate' = 1
        'DeferFeatureUpdates'             = 1
        'DeferFeatureUpdatesPeriodInDays' = 365
        'DeferQualityUpdates'             = 1
        'DeferQualityUpdatesPeriodInDays' = 4
    }
    foreach ($key in $deferrals.Keys) {
        Set-ItemProperty -Path $polRoot -Name $key -Type DWord -Value $deferrals[$key]
    }

    # 5. Never auto-restart while a user is signed in.
    New-Item -Path $polAuto -Force | Out-Null
    $restartPolicies = @{
        'AUOptions'                     = 4
        'NoAutoRebootWithLoggedOnUsers' = 1
        'AUPowerManagement'             = 0
    }
    foreach ($key in $restartPolicies.Keys) {
        Set-ItemProperty -Path $polAuto -Name $key -Type DWord -Value $restartPolicies[$key]
    }

    # 6. Clear stale migration leftovers from the consumer-side update store.
    foreach ($key in @('BranchReadinessLevel', 'DeferFeatureUpdatesPeriodInDays', 'DeferQualityUpdatesPeriodInDays')) {
        Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name $key -ErrorAction SilentlyContinue
    }
    Remove-ItemProperty -Path $polAuto -Name 'NoAutoUpdate' -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' -Name 'DODownloadMode' -ErrorAction SilentlyContinue
}

function Set-CloudflareDns {
    $ipv4  = @('1.1.1.1', '1.0.0.1')
    $ipv6  = @('2606:4700:4700::1111', '2606:4700:4700::1001')
    $dohOk = [bool](Get-Command Add-DnsClientDohServerAddress -ErrorAction SilentlyContinue)
    if ($dohOk) {
        foreach ($ip in ($ipv4 + $ipv6)) {
            $existing = Get-DnsClientDohServerAddress -ServerAddress $ip -ErrorAction SilentlyContinue
            if ($existing) {
                Set-DnsClientDohServerAddress -ServerAddress $ip -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction Stop
            }
            else {
                Add-DnsClientDohServerAddress -ServerAddress $ip -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction Stop
            }
        }
    }
    $adapters = Get-NetAdapter | Where-Object Status -eq 'Up'
    if (-not $adapters) { throw 'No active network adapters found.' }
    foreach ($a in $adapters) {
        Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $ipv4 -ErrorAction Stop
        Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $ipv6 -ErrorAction Stop
        if ($dohOk) {
            $base = "HKLM:\System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($a.InterfaceGuid)\DohInterfaceSettings"
            foreach ($ip in $ipv4) {
                New-Item -Path "$base\Doh\$ip" -Force | Out-Null
                New-ItemProperty -Path "$base\Doh\$ip" -Name 'DohFlags' -Value 1 -PropertyType QWord -Force | Out-Null
            }
            foreach ($ip in $ipv6) {
                New-Item -Path "$base\Doh6\$ip" -Force | Out-Null
                New-ItemProperty -Path "$base\Doh6\$ip" -Name 'DohFlags' -Value 1 -PropertyType QWord -Force | Out-Null
            }
        }
        Write-Host "DNS set on adapter '$($a.Name)' ($($a.InterfaceDescription))"
    }
    if ($dohOk) { Clear-DnsClientCache }
}

function Enable-UltimatePerformancePlan {
    if (Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue) {
        if (-not $Force) {
            Write-Warning 'Battery system detected - skipping Ultimate Performance (CTT: NOT FOR LAPTOPS). Re-run with -Force to apply anyway.'
            $script:Results['Ultimate Performance power plan'] = 'SKIPPED (battery system)'
            return
        }
    }
    $guidRe   = '[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}'
    $existing = powercfg /list | Select-String 'Ultimate Performance'
    if ($existing) {
        $guid = $existing.Matches[0].Value
        Write-Host "Ultimate Performance plan already exists - activating $guid"
    }
    else {
        $dup = powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
        if ($LASTEXITCODE -ne 0) { throw 'powercfg could not duplicate the Ultimate Performance scheme.' }
        $guid = ($dup | Select-String -Pattern $guidRe).Matches[0].Value
    }
    powercfg /setactive $guid
    if ($LASTEXITCODE -ne 0) { throw 'powercfg could not activate the Ultimate Performance scheme.' }
    Write-Host "Active power plan: $guid (Ultimate Performance)"
}

# -- Steps --
if (-not $SkipDebloat) {
    Invoke-Step -Name 'Win11Debloat (default mode)' -Desc 'Win11Debloat.ps1 -RunDefaults -Silent -CreateRestorePoint (latest, fetched live)' {
        $debloat = Join-Path $Root 'Win11Debloat.ps1'
        Write-Host 'Downloading Win11Debloat (latest)...'
        $code = Invoke-RestMethod -Uri 'https://debloat.raphi.re/'
        Set-Content -Path $debloat -Value $code -Encoding UTF8
        $flags = @('-RunDefaults', '-Silent')
        if ($code -match 'CreateRestorePoint') { $flags += '-CreateRestorePoint' }
        if ($code -match 'LogPath')            { $flags += @('-LogPath', "`"$LogDir`"") }
        Write-Host ('Running: ' + ($flags -join ' '))
        $p = Start-Process powershell.exe -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$debloat`"") + $flags) -Wait -PassThru -RedirectStandardOutput (Join-Path $LogDir 'step1-debloat-out.log') -RedirectStandardError (Join-Path $LogDir 'step1-debloat-err.log')
        if ($p.ExitCode -ne 0) { throw "Win11Debloat exited with code $($p.ExitCode) (see logs)" }
    }
}

if (-not $SkipWinutil) {
    Invoke-Step -Name 'Winutil (saved config)' -Desc 'winutil.ps1 -Config winutil-config.json (latest, fetched live)' {
        $wu = Join-Path $Root 'winutil.ps1'
        Write-Host 'Downloading Winutil (latest stable)...'
        Invoke-RestMethod -Uri 'https://christitus.com/win' | Set-Content -Path $wu -Encoding UTF8
        Write-Host 'Applying winutil-config.json...'
        $p = Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$wu`"", '-Config', "`"$Root\winutil-config.json`"") -Wait -PassThru -RedirectStandardOutput (Join-Path $LogDir 'step2-winutil-out.log') -RedirectStandardError (Join-Path $LogDir 'step2-winutil-err.log')
        if ($p.ExitCode -ne 0) { throw "Winutil exited with code $($p.ExitCode) (see logs)" }
    }
}

if (-not $SkipUpdateProfile) {
    Invoke-Step -Name "Windows Update 'Recommended' profile" -Desc 'Defer feature 365d / quality 4d, no driver offers, no auto-reboot (clean-room)' {
        $edition = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
        if ($edition -like '*Home*') { Write-Warning 'Windows Home detected - update deferrals need Pro/Enterprise/Education; Windows will ignore some values.' }
        Set-RecommendedUpdateProfile
    }
}

if (-not $SkipDns) {
    Invoke-Step -Name 'Cloudflare DNS + DoH' -Desc 'Set 1.1.1.1/1.0.0.1 (+IPv6) with DoH on all active adapters' { Set-CloudflareDns }
}

if (-not $SkipPowerPlan) {
    Invoke-Step -Name 'Ultimate Performance power plan' -Desc 'powercfg: duplicate+activate Ultimate Performance (idempotent; skipped on battery)' { Enable-UltimatePerformancePlan }
}

if (-not $SkipShutup) {
    Invoke-Step -Name 'O&O ShutUp10++ (silent)' -Desc 'OOSU10.exe (fresh download, deleted after) ooshutup10.cfg /quiet' {
        $oosu = Join-Path $env:TEMP 'OOSU10.exe'
        Write-Host 'Downloading O&O ShutUp10++ (fresh copy, removed after the run)...'
        Invoke-WebRequest -Uri 'https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe' -OutFile $oosu -UseBasicParsing
        try {
            $p = Start-Process -FilePath $oosu -ArgumentList "`"$Root\ooshutup10.cfg`"", '/quiet' -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "OOSU10 exited with code $($p.ExitCode)" }
        }
        finally {
            Remove-Item -LiteralPath $oosu -Force -ErrorAction SilentlyContinue
        }
    }
}

# -- Summary --
Write-Host ''
Write-Host '=== SUMMARY ===' -ForegroundColor Cyan
foreach ($k in $script:Results.Keys) { Write-Host ("  {0,-42} {1}" -f $k, $script:Results[$k]) }
try { Stop-Transcript | Out-Null } catch { }

# -- Self-cleanup (remote runs leave nothing behind on success) --
Set-Location $env:SystemRoot
if ($script:HadFailure) {
    Write-Host ''
    Write-Host "One or more steps FAILED - logs kept for debugging: $LogDir" -ForegroundColor Red
    if ($RemoteBoot) { return }
    exit 1
}
Remove-Item -LiteralPath (Join-Path $env:LOCALAPPDATA 'winutil') -Recurse -Force -ErrorAction SilentlyContinue
if ($CacheRun) {
    if ($KeepCache) {
        Write-Host ''
        Write-Host "KeepCache set - cache kept at: $Root" -ForegroundColor Yellow
    }
    else {
        Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $Root) { Write-Warning "Could not fully remove cache: $Root" }
        else {
            Write-Host ''
            Write-Host 'Self-cleanup complete - nothing was left behind.' -ForegroundColor Green
        }
    }
}
else {
    Write-Host ''
    Write-Host "Local project folder kept (it is the source of truth): $Root"
}
if ($RemoteBoot) { return }
exit 0


