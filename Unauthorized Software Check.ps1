<#
  _____                         __  __ _____ _______ 
 |  __ \                       |  \/  |_   _|__   __|
 | |__) |   _ _ __ ___   __ _  | \  / | | |    | |   
 |  ___/ | | | '_ ` _ \ / _` | | |\/| | | |    | |   
 | |   | |_| | | | | | | (_| | | |  | |_| |_   | |   
 |_|    \__,_|_| |_| |_|\__,_| |_|  |_|_____|  |_|  

        Puma Managed IT | Automation & Operations
#>

#===============================================================================
# Script Name : Check For Unauthorized Software
# Nickname    : Security - Unauthorized Software
# Description :
#   Detects unauthorized remote access / RMM tools
#   Supports global + client specific exclusions 
#
# Author      : Rob Cooper 
# Updated     : 2026-03-25
# Version     : 1.5
#===============================================================================

# ===============================
# CONFIGURATION
# ===============================

# Software to detect (partial match)
$WatchList = @(
    "TeamViewer",
    "AnyDesk",
    "ScreenConnect",
    "LogMeIn",
    "Domotz",
    "RustDesk",
    "NinjaRMM",
    "UltraViewer",
    "Liongard",
    "N-Able",
    "Network Detective",
    "Kaseya",
    "Zoho Assist"
)

# Global exclusions (your standard stack)
$Exclusions = @(
    "Your",
    "Orgs",
    "Tool",
    "Stack",
    "Goes",
    "In this",
    "Location"
)

# ===============================
# CLIENT-SPECIFIC EXCLUSIONS
# Datto Variable Name: ClientExclusions
# ===============================
$ClientExclusionsRaw = "$env:AppExclusions"
$ClientExclusions = @()

if (![string]::IsNullOrWhiteSpace($ClientExclusionsRaw) -and $ClientExclusionsRaw -notmatch "\$\{") {
    $ClientExclusions = $ClientExclusionsRaw -split "[,`n]" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" }
}

# Combine exclusions safely
$AllExclusions = $Exclusions + $ClientExclusions

# ===============================
# INITIALIZE DATTO OUTPUT
# ===============================
$Output   = ""
$ExitCode = 0
$Alerts   = @()

# ===============================
# GET INSTALLED SOFTWARE
# ===============================
$InstalledSoftware = @()
$Paths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($Path in $Paths) {
    try {
        $InstalledSoftware += Get-ItemProperty $Path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object -ExpandProperty DisplayName
    } catch {}
}

# ===============================
# DETECTION LOGIC
# ===============================
foreach ($App in $InstalledSoftware) {
    if (-not $App) { continue }

    # Skip approved software (global + client)
    $IsExcluded = $false
    foreach ($Exclude in $AllExclusions) {
        if ($App -like "*$Exclude*") {
            $IsExcluded = $true
            break
        }
    }
    if ($IsExcluded) { continue }

    # Check against watchlist
    foreach ($Watch in $WatchList) {
        if ($App -like "*$Watch*") {
            $Alerts += $App
        }
    }
}

# ===============================
# FINAL DATTO RESULT
# ===============================
if ($Alerts.Count -gt 0) {
    $UniqueAlerts = $Alerts | Sort-Object -Unique
    $Output = "ALERT: Unauthorized software detected --> " + ($UniqueAlerts -join " || ")
    $ExitCode = 1
} else {
    $Output = "OK: No unauthorized software detected"
    $ExitCode = 0
}

# ===============================
# DATTO DEVICE MONITOR OUTPUT
# ===============================
Write-Output "<-Start Result->"
Write-Output "Output=$Output"
Write-Output "<-End Result->"

exit $ExitCode