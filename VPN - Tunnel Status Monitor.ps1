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
# Script Name : VPN Tunnel Check
# Nickname    : None
# Description :
#   Performs a check of internal host and external gateway
#  
#
# Author      : Rob Cooper
# Created     : 2026-03-13
# Last Updated: 2026-03-14
#
# Version     : 8.0
#
#===============================================================================

# Datto RMM Component Variables
$InternalIP = "$env:InternalIP"
$ExternalIP = "$env:ExternalIP"
$TunnelName = "$env:TunnelName"

# Initialize output variables
$Output = ""
$ExitCode = 0

# Optional Tunnel Name
if (![string]::IsNullOrWhiteSpace($TunnelName) -and $TunnelName -notmatch "\$\{") {
    $TunnelPrefix = "Tunnel:$TunnelName | "
}
else {
    $TunnelPrefix = ""
}

# Validate InternalIP
if ([string]::IsNullOrWhiteSpace($InternalIP) -or $InternalIP -match "\$\{") {

    $Output = "ERROR | VPN Monitor Misconfigured | InternalIP variable missing | Action: Edit component monitor and define InternalIP"
    $ExitCode = 1
}
else {

    # Wake tunnel (helps with idle IPSec tunnels)
    Test-Connection -ComputerName $InternalIP -Count 1 -Quiet -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Seconds 2

    $InternalPing = [bool](Test-Connection -ComputerName $InternalIP -Count 2 -Quiet -ErrorAction SilentlyContinue)

    if ($InternalPing) {

        $Output = "OK | VPN Tunnel Healthy | $TunnelPrefix" + "Internal:$InternalIP reachable"
        $ExitCode = 0

    }
    else {

        if (![string]::IsNullOrWhiteSpace($ExternalIP) -and $ExternalIP -notmatch "\$\{") {

            $ExternalPing = [bool](Test-Connection -ComputerName $ExternalIP -Count 2 -Quiet -ErrorAction SilentlyContinue)

            if ($ExternalPing) {

                $Output = "ALERT | VPN Tunnel Down | $TunnelPrefix" + "Site Online | Internal:$InternalIP unreachable | Gateway:$ExternalIP reachable | Action:Check firewall VPN status / Phase1 / Phase2 / restart tunnel"
                $ExitCode = 1

            }
            else {

                $Output = "ALERT | Remote Site Offline | $TunnelPrefix" + "Gateway:$ExternalIP unreachable | Internal:$InternalIP unreachable | Action:Check ISP connectivity / firewall power / WAN IP"
                $ExitCode = 1
            }

        }
        else {

            $Output = "ALERT | VPN Tunnel Down | $TunnelPrefix" + "Internal:$InternalIP unreachable | Gateway test not configured | Action:Check firewall VPN status"
            $ExitCode = 1
        }
    }
}

# Datto device monitor output format
Write-Output "<-Start Result->"
Write-Output "Output=$Output"
Write-Output "<-End Result->"

exit $ExitCode
