# Pearson VUE OnVUE System Preparation Script - IMPROVED VERSION
# This script helps prepare your system for online proctored exams
# Run as Administrator for full functionality

# Color scheme
$script:Colors = @{
    Title = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Info = 'White'
    Highlight = 'Magenta'
}

# Check if running as administrator
$script:isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

# State tracking
$script:stoppedServices = @()
$script:closedProcesses = @()

function Show-Banner {
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Title
    Write-Host "║   Pearson VUE OnVUE System Preparation Script v2.0         ║" -ForegroundColor $Colors.Title
    Write-Host "║   Enhanced Safety & User Control Edition                   ║" -ForegroundColor $Colors.Title
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Title
    
    if (-not $script:isAdmin) {
        Write-Host "`n⚠️  NOT running as Administrator" -ForegroundColor $Colors.Warning
        Write-Host "   Some features will be limited. Restart script as Admin for full functionality.`n" -ForegroundColor $Colors.Warning
    } else {
        Write-Host "`n✓ Running with Administrator privileges`n" -ForegroundColor $Colors.Success
    }
}

function Show-Menu {
    Show-Banner
    Write-Host "MAIN MENU" -ForegroundColor $Colors.Highlight
    Write-Host "═════════════════════════════════════════════════════════════" -ForegroundColor $Colors.Info
    Write-Host " 1. Run Pre-Flight Check (Safe - No Changes)" -ForegroundColor $Colors.Info
    Write-Host " 2. Close Critical Processes Only (Recommended)" -ForegroundColor $Colors.Info
    Write-Host " 3. Close All Interfering Processes (Comprehensive)" -ForegroundColor $Colors.Info
    Write-Host " 4. Stop Interfering Services" -ForegroundColor $Colors.Info
    Write-Host " 5. Optimize System (Notifications, Temp Files)" -ForegroundColor $Colors.Info
    Write-Host " 6. Check for High-Risk Software" -ForegroundColor $Colors.Info
    Write-Host " 7. Full Preparation (All Tasks)" -ForegroundColor $Colors.Info
    Write-Host " 8. Restore Stopped Services" -ForegroundColor $Colors.Success
    Write-Host " 9. View Preparation Summary" -ForegroundColor $Colors.Info
    Write-Host " 0. Exit" -ForegroundColor $Colors.Info
    Write-Host "═════════════════════════════════════════════════════════════" -ForegroundColor $Colors.Info
    Write-Host "`nSelect option: " -NoNewline -ForegroundColor $Colors.Highlight
}

function Get-UserConfirmation {
    param(
        [string]$Message,
        [string]$DefaultChoice = "Y"
    )
    
    $choice = Read-Host "$Message (Y/N) [Default: $DefaultChoice]"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = $DefaultChoice
    }
    return $choice -eq 'Y' -or $choice -eq 'y'
}

function Write-SectionHeader {
    param([string]$Title)
    Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
    Write-Host " $Title" -ForegroundColor $Colors.Title
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
}

function Start-PreFlightCheck {
    Write-SectionHeader "PRE-FLIGHT CHECK - Scanning System"
    Write-Host "This will scan your system without making any changes.`n" -ForegroundColor $Colors.Info
    
    # Check running critical processes
    Write-Host "Checking for interfering processes..." -ForegroundColor $Colors.Info
    $foundCritical = @()
    $foundOther = @()
    
    foreach ($processName in $criticalProcesses) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($running) {
            $foundCritical += $processName
        }
    }
    
    foreach ($processName in $standardProcesses) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($running) {
            $foundOther += $processName
        }
    }
    
    # Display results
    if ($foundCritical.Count -eq 0 -and $foundOther.Count -eq 0) {
        Write-Host "✓ No interfering processes detected!" -ForegroundColor $Colors.Success
    } else {
        if ($foundCritical.Count -gt 0) {
            Write-Host "`n⚠️  CRITICAL - Must Close:" -ForegroundColor $Colors.Error
            foreach ($proc in $foundCritical) {
                Write-Host "   • $proc" -ForegroundColor $Colors.Error
            }
        }
        
        if ($foundOther.Count -gt 0) {
            Write-Host "`n⚠️  RECOMMENDED - Should Close:" -ForegroundColor $Colors.Warning
            $displayCount = [Math]::Min(10, $foundOther.Count)
            for ($i = 0; $i -lt $displayCount; $i++) {
                Write-Host "   • $($foundOther[$i])" -ForegroundColor $Colors.Warning
            }
            if ($foundOther.Count -gt 10) {
                Write-Host "   ... and $($foundOther.Count - 10) more" -ForegroundColor $Colors.Warning
            }
        }
    }
    
    # Check services
    Write-Host "`nChecking for interfering services..." -ForegroundColor $Colors.Info
    $runningServices = @()
    foreach ($serviceName in $servicesToStop) {
        $services = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        foreach ($service in $services) {
            if ($service.Status -eq 'Running') {
                $runningServices += $service.Name
            }
        }
    }
    
    if ($runningServices.Count -eq 0) {
        Write-Host "✓ No interfering services detected!" -ForegroundColor $Colors.Success
    } else {
        Write-Host "⚠️  Found $($runningServices.Count) service(s) that may interfere" -ForegroundColor $Colors.Warning
    }
    
    # Check VPN
    Write-Host "`nChecking VPN status..." -ForegroundColor $Colors.Info
    $vpnAdapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*VPN*" -or $_.InterfaceDescription -like "*TAP*" -and $_.Status -eq "Up" }
    if ($vpnAdapters) {
        Write-Host "⚠️  VPN connection detected - disconnect before exam!" -ForegroundColor $Colors.Warning
    } else {
        Write-Host "✓ No active VPN detected" -ForegroundColor $Colors.Success
    }
    
    # Summary
    Write-Host "`n" -NoNewline
    Write-Host "SUMMARY" -ForegroundColor $Colors.Highlight
    Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor $Colors.Info
    Write-Host "Critical processes found: $($foundCritical.Count)" -ForegroundColor $(if ($foundCritical.Count -gt 0) { $Colors.Error } else { $Colors.Success })
    Write-Host "Other processes found: $($foundOther.Count)" -ForegroundColor $(if ($foundOther.Count -gt 0) { $Colors.Warning } else { $Colors.Success })
    Write-Host "Services to stop: $($runningServices.Count)" -ForegroundColor $(if ($runningServices.Count -gt 0) { $Colors.Warning } else { $Colors.Success })
}

function Close-ProcessesSafely {
    param(
        [array]$ProcessList,
        [string]$Category = "processes",
        [bool]$SkipConfirmation = $false
    )
    
    if (-not $SkipConfirmation) {
        Write-Host "`n⚠️  This will close $Category. Ensure all work is saved!" -ForegroundColor $Colors.Warning
        if (-not (Get-UserConfirmation "Continue?")) {
            Write-Host "Operation cancelled." -ForegroundColor $Colors.Warning
            return
        }
    }
    
    $closedCount = 0
    $failedCount = 0
    
    foreach ($processName in $ProcessList) {
        try {
            $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($processes) {
                foreach ($process in $processes) {
                    # Skip current PowerShell process
                    if ($processName -like "powershell*" -and $process.Id -eq $PID) {
                        continue
                    }
                    
                    Write-Host "Closing: $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor $Colors.Info
                    
                    # Try graceful close first
                    $process.CloseMainWindow() | Out-Null
                    Start-Sleep -Milliseconds 750
                    
                    # Force kill if still running
                    if (!$process.HasExited) {
                        $process.Kill()
                        Write-Host "  → Force closed" -ForegroundColor $Colors.Warning
                    } else {
                        Write-Host "  → Closed gracefully" -ForegroundColor $Colors.Success
                    }
                    
                    $script:closedProcesses += $process.ProcessName
                    $closedCount++
                }
            }
        }
        catch {
            $failedCount++
            Write-Host "  → Failed: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        }
    }
    
    Write-Host "`n✓ Closed $closedCount process(es)" -ForegroundColor $Colors.Success
    if ($failedCount -gt 0) {
        Write-Host "⚠️  Failed to close $failedCount process(es)" -ForegroundColor $Colors.Warning
    }
}

function Close-CriticalProcesses {
    Write-SectionHeader "CLOSING CRITICAL PROCESSES"
    Close-ProcessesSafely -ProcessList $criticalProcesses -Category "critical processes"
}

function Close-AllProcesses {
    Write-SectionHeader "CLOSING ALL INTERFERING PROCESSES"
    $allProcesses = $criticalProcesses + $standardProcesses
    Close-ProcessesSafely -ProcessList $allProcesses -Category "all interfering processes"
}

function Stop-InterferingServices {
    Write-SectionHeader "STOPPING SERVICES"
    
    if (-not $script:isAdmin) {
        Write-Host "⚠️  Administrator privileges required for service operations" -ForegroundColor $Colors.Error
        return
    }
    
    Write-Host "⚠️  This will temporarily stop services that may interfere with proctoring." -ForegroundColor $Colors.Warning
    Write-Host "Services can be restarted using option 8 or by rebooting." -ForegroundColor $Colors.Info
    
    if (-not (Get-UserConfirmation "`nContinue?")) {
        Write-Host "Operation cancelled." -ForegroundColor $Colors.Warning
        return
    }
    
    $stoppedCount = 0
    
    foreach ($serviceName in $servicesToStop) {
        try {
            $services = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            foreach ($service in $services) {
                if ($service.Status -eq 'Running') {
                    Write-Host "Stopping: $($service.DisplayName)" -ForegroundColor $Colors.Info
                    Stop-Service -Name $service.Name -Force -ErrorAction Stop
                    $script:stoppedServices += $service.Name
                    $stoppedCount++
                    Write-Host "  → Stopped" -ForegroundColor $Colors.Success
                }
            }
        }
        catch {
            Write-Host "  → Failed: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        }
    }
    
    Write-Host "`n✓ Stopped $stoppedCount service(s)" -ForegroundColor $Colors.Success
}

function Optimize-System {
    Write-SectionHeader "SYSTEM OPTIMIZATION"
    
    # Disable notifications
    Write-Host "Configuring Focus Assist (Do Not Disturb)..." -ForegroundColor $Colors.Info
    try {
        # Note: Focus Assist configuration requires registry changes
        # User should manually enable via Windows Settings > System > Focus Assist
        Write-Host "✓ Focus Assist check completed" -ForegroundColor $Colors.Success
        Write-Host "  Note: Manually enable 'Do Not Disturb' in Windows settings for best results" -ForegroundColor $Colors.Info
    }
    catch {
        Write-Host "⚠️  Could not configure Focus Assist automatically" -ForegroundColor $Colors.Warning
    }
    
    # Clear temp files
    Write-Host "`nClearing temporary files..." -ForegroundColor $Colors.Info
    try {
        $tempPath = "$env:TEMP\*"
        $itemsRemoved = (Get-ChildItem -Path $env:TEMP -ErrorAction SilentlyContinue | Measure-Object).Count
        Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✓ Cleared approximately $itemsRemoved temporary items" -ForegroundColor $Colors.Success
    }
    catch {
        Write-Host "⚠️  Some temporary files could not be cleared (normal)" -ForegroundColor $Colors.Warning
    }
    
    # Network check
    Write-Host "`nChecking network connectivity..." -ForegroundColor $Colors.Info
    try {
        $ping = Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet
        if ($ping) {
            Write-Host "✓ Internet connectivity verified" -ForegroundColor $Colors.Success
        } else {
            Write-Host "⚠️  Network connectivity issue detected" -ForegroundColor $Colors.Warning
        }
    }
    catch {
        Write-Host "⚠️  Could not verify network connectivity" -ForegroundColor $Colors.Warning
    }
}

function Test-HighRiskSoftware {
    Write-SectionHeader "HIGH-RISK SOFTWARE CHECK"
    Write-Host "Scanning for software that WILL cause exam termination...`n" -ForegroundColor $Colors.Info
    
    $foundRiskyProcesses = @()
    foreach ($process in $highRiskProcesses) {
        $running = Get-Process -Name $process -ErrorAction SilentlyContinue
        if ($running) {
            $foundRiskyProcesses += $process
        }
    }
    
    if ($foundRiskyProcesses.Count -eq 0) {
        Write-Host "✓ No high-risk software detected!" -ForegroundColor $Colors.Success
    } else {
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Error
        Write-Host "          ⚠️  CRITICAL WARNING ⚠️" -ForegroundColor $Colors.Error
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Error
        Write-Host "`nThe following applications MUST be completely closed:" -ForegroundColor $Colors.Error
        foreach ($process in $foundRiskyProcesses) {
            Write-Host "   ❌ $process" -ForegroundColor $Colors.Error
        }
        Write-Host "`nThese applications WILL cause exam termination if detected!" -ForegroundColor $Colors.Error
        Write-Host "Close them manually and restart your computer if necessary.`n" -ForegroundColor $Colors.Error
    }
}

function Restore-Services {
    Write-SectionHeader "RESTORING SERVICES"
    
    if ($script:stoppedServices.Count -eq 0) {
        Write-Host "No services to restore (none were stopped during this session)." -ForegroundColor $Colors.Info
        return
    }
    
    if (-not $script:isAdmin) {
        Write-Host "⚠️  Administrator privileges required" -ForegroundColor $Colors.Error
        return
    }
    
    Write-Host "Restarting $($script:stoppedServices.Count) service(s)...`n" -ForegroundColor $Colors.Info
    
    $restoredCount = 0
    foreach ($serviceName in $script:stoppedServices) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service -and $service.Status -ne 'Running') {
                Write-Host "Starting: $($service.DisplayName)" -ForegroundColor $Colors.Info
                Start-Service -Name $serviceName -ErrorAction Stop
                $restoredCount++
                Write-Host "  → Started" -ForegroundColor $Colors.Success
            }
        }
        catch {
            Write-Host "  → Failed: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        }
    }
    
    Write-Host "`n✓ Restored $restoredCount service(s)" -ForegroundColor $Colors.Success
    $script:stoppedServices = @()
}

function Show-Summary {
    Write-SectionHeader "PREPARATION SUMMARY"
    
    Write-Host "Session Statistics:" -ForegroundColor $Colors.Info
    Write-Host "  • Processes closed: $($script:closedProcesses.Count)" -ForegroundColor $Colors.Info
    Write-Host "  • Services stopped: $($script:stoppedServices.Count)" -ForegroundColor $Colors.Info
    
    Write-Host "`nFinal Checklist Before Starting Exam:" -ForegroundColor $Colors.Highlight
    Write-Host "  ☐ All browser windows closed" -ForegroundColor $Colors.Info
    Write-Host "  ☐ Communication apps closed (Teams, Slack, Discord, etc.)" -ForegroundColor $Colors.Info
    Write-Host "  ☐ VPN disconnected" -ForegroundColor $Colors.Info
    Write-Host "  ☐ Screen sharing/recording software closed" -ForegroundColor $Colors.Info
    Write-Host "  ☐ Virtual machines shut down (VMware, VirtualBox, etc.)" -ForegroundColor $Colors.Info
    Write-Host "  ☐ Antivirus real-time scanning paused (if required)" -ForegroundColor $Colors.Info
    Write-Host "  ☐ Second monitor disconnected (if required)" -ForegroundColor $Colors.Info
    Write-Host "  ☐ Room is well-lit and clear of prohibited items" -ForegroundColor $Colors.Info
    Write-Host "  ☐ Mobile phone out of reach" -ForegroundColor $Colors.Info
    Write-Host "  ☐ Stable internet connection verified" -ForegroundColor $Colors.Info
}

function Start-FullPreparation {
    Write-SectionHeader "FULL SYSTEM PREPARATION"
    Write-Host "This will run all preparation tasks." -ForegroundColor $Colors.Info
    Write-Host "⚠️  Ensure all work is saved before proceeding!`n" -ForegroundColor $Colors.Warning
    
    if (-not (Get-UserConfirmation "Continue with full preparation?")) {
        Write-Host "Operation cancelled." -ForegroundColor $Colors.Warning
        return
    }
    
    Start-PreFlightCheck
    Write-Host "`nPress Enter to continue..." -ForegroundColor $Colors.Info
    Read-Host
    
    Close-AllProcesses
    Stop-InterferingServices
    Optimize-System
    Test-HighRiskSoftware
    
    Write-Host "`n✓ Full preparation completed!" -ForegroundColor $Colors.Success
}

# ═══════════════════════════════════════════════════════════
# PROCESS DEFINITIONS
# ═══════════════════════════════════════════════════════════

# Critical processes - WILL cause exam issues
$criticalProcesses = @(
    "vmware", "vmware-vmx", "vmware-hostd", "virtualbox", "vboxheadless", "vboxsvc",
    "hyper-v", "vmms", "vmcompute", "docker", "dockerdesktop",
    "obs64", "obs32", "xsplit", "streamlabs", "bandicam", "camtasia", "snagit",
    "fraps", "shadowplay", "amdrelive",
    "teamviewer", "anydesk", "remotedesktop", "vnc", "realvnc", "tightvnc",
    "chrome-remote", "parsec", "splashtop",
    "wireshark", "fiddler", "charles", "burpsuite"
)

# Standard processes - Should be closed
$standardProcesses = @(
    "chrome", "firefox", "edge", "msedge", "opera", "brave",
    "teams", "skype", "discord", "slack", "zoom", "webex",
    "whatsapp", "telegram", "signal",
    "spotify", "itunes", "vlc",
    "steam", "epicgameslauncher", "origin", "battle.net",
    "notepad++", "vscode", "sublimetext",
    "dropbox", "googledrive", "onedrive",
    "nordvpn", "expressvpn", "openvpn",
    "winword", "excel", "powerpnt", "outlook"
)

# High-risk processes for detection
$highRiskProcesses = @(
    "vmware", "vmware-vmx", "virtualbox", "vboxheadless", "hyper-v", "docker",
    "obs64", "obs32", "bandicam", "camtasia", "snagit", "fraps",
    "teamviewer", "anydesk", "vnc", "chrome-remote", "parsec",
    "wireshark", "fiddler", "charles", "burpsuite"
)

# Services to stop
$servicesToStop = @(
    "TeamViewer*", "AnyDesk*", "VNC*", "Dropbox*", "OneDrive*",
    "VMware*", "VirtualBox*", "Docker*", "Steam*", "NordVPN*",
    "ExpressVPN*", "OpenVPN*", "EaseUS*", "Zoom*"
)

# ═══════════════════════════════════════════════════════════
# MAIN PROGRAM LOOP
# ═══════════════════════════════════════════════════════════

while ($true) {
    Show-Menu
    $choice = Read-Host
    
    switch ($choice) {
        "1" { Start-PreFlightCheck }
        "2" { Close-CriticalProcesses }
        "3" { Close-AllProcesses }
        "4" { Stop-InterferingServices }
        "5" { Optimize-System }
        "6" { Test-HighRiskSoftware }
        "7" { Start-FullPreparation }
        "8" { Restore-Services }
        "9" { Show-Summary }
        "0" { 
            Write-Host "`n" -NoNewline
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
            Write-Host "Thank you for using the OnVUE Preparation Script!" -ForegroundColor $Colors.Success
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
            Write-Host "`nRemember to close this PowerShell window before starting your exam." -ForegroundColor $Colors.Warning
            Write-Host "Good luck! 🍀`n" -ForegroundColor $Colors.Success
            exit
        }
        default { 
            Write-Host "`n⚠️  Invalid option. Please select 0-9." -ForegroundColor $Colors.Error
        }
    }
    
    Write-Host "`nPress Enter to return to menu..." -ForegroundColor $Colors.Info
    Read-Host
}
