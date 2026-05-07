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
# Script Name : Account Lockout Status
# Nickname    : AD - Lockout Status
# Description :
#   AD – Domain Account Lockout & Authentication Health
#  
#
# Author      : Rob Cooper
# Created     : 2026-03-13
# Last Updated: 2026-03-18
#
# Version     : 9.0
#
#===============================================================================

# ===============================
# CONFIGURATION
# ===============================
$LookbackMinutes  = 10
$FailureThreshold = 3

# ===============================
# INITIALIZE DATTO OUTPUT
# ===============================
$Output   = ""
$ExitCode = 0
$Alerts   = @()
$Since    = (Get-Date).AddMinutes(-$LookbackMinutes)

# ===============================
# HELPER: Filter valid domain users and system accounts
# Without the helper, we are getting bullshit results
# ===============================
function Is-ValidDomainUser {
    param ($AccountName)

    if (-not $AccountName) { return $false }

    # Exclude machine accounts
    if ($AccountName -like "*$") { return $false }

    # Exclude common system accounts
    if ($AccountName -in @(
        "SYSTEM",
        "LOCAL SERVICE",
        "NETWORK SERVICE",
        "ANONYMOUS LOGON"
    )) { return $false }

    return $true
}

# ===============================
# Explicit lockout events (4740)
# ===============================
try {
    $LockoutEvents = Get-WinEvent -FilterHashtable @{
        LogName   = 'Security'
        Id        = 4740
        StartTime = $Since
    } -ErrorAction SilentlyContinue

    foreach ($event in $LockoutEvents) {
        $Account = $event.Properties[0].Value
        if (Is-ValidDomainUser $Account) {
            $Source = $event.Properties[1].Value
            $Alerts += "4740 lockout | Account=$Account | Source=$Source"
        }
    }
} catch {}

# ===============================
# Silent lockouts (AD state)
# ===============================
try {
    Import-Module ActiveDirectory -ErrorAction Stop

    $LockedAccounts = Get-ADUser -Filter { LockedOut -eq $true } -Properties LockedOut

    foreach ($acct in $LockedAccounts) {
        if (Is-ValidDomainUser $acct.SamAccountName) {
            $Alerts += "AD locked state | Account=$($acct.SamAccountName)"
        }
    }
} catch {}


# ===============================
# FINAL DATTO RESULT
# ===============================
if ($Alerts.Count -gt 0) {
    $Output   = "ALERT: Domain account authentication issue detected | " + ($Alerts -join " || ")
    $ExitCode = 1
} else {
    $Output   = "OK: No domain account lockouts or authentication anomalies detected"
    $ExitCode = 0
}

# ===============================
# DATTO DEVICE MONITOR OUTPUT
# ===============================
Write-Output "<-Start Result->"
Write-Output "Output=$Output"
Write-Output "<-End Result->"

exit $ExitCode