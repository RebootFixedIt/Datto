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
#----------------------------------------------------------------
# Athena Tray App Monitor for Datto (Active Users via Explorer.exe)
#----------------------------------------------------------------
$processName = 'ADM.TrayApp.exe'
$pathMatch   = '\AppData\Local\athenahealth, Inc\3.1.4.0\modules\CoreModule\ADM.TrayApp.exe'

# Initialize output variables
$Output = ""
$ExitCode = 0

# Get active console users by checking for Explorer.exe processes
$explorerProcs = Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'"

$activeUsers = @()
foreach ($proc in $explorerProcs) {
    try {
        $owner = ($proc | Invoke-CimMethod -MethodName GetOwner).User
        if ($owner) { $activeUsers += $owner }
    } catch {
        # Ignore processes where owner can't be retrieved
    }
}

$activeUsers = $activeUsers | Sort-Object -Unique

if ($activeUsers.Count -eq 0) {
    $Output = "OK: No active console users, tray app not expected"
    $ExitCode = 0
} else {
    # Check if ADM.TrayApp.exe is running
    $procTray = Get-CimInstance Win32_Process | Where-Object {
        $_.Name -eq $processName -and $_.ExecutablePath -like "*$pathMatch"
    }

    if ($procTray) {
        $Output = "OK: Active console user(s) ($($activeUsers -join ', ')) logged in and ADM.TrayApp.exe running"
        $ExitCode = 0
    } else {
        $Output = "ALERT: Active console user(s) ($($activeUsers -join ', ')) logged in but ADM.TrayApp.exe not running"
        $ExitCode = 1
    }
}

# Output in Datto device monitor format
Write-Output "<-Start Result->"
Write-Output "Output=$Output"
Write-Output "<-End Result->"

exit $ExitCode