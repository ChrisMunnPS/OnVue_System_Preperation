<#
.SYNOPSIS
    OnVUE Exam Preparation Assistant - WPF GUI
.DESCRIPTION
    Prepares a Windows system for a Pearson VUE OnVUE online-proctored exam:
    scans for interfering processes/services, checks VPN status, clears temp
    files, verifies network connectivity, and flags high-risk software that
    will cause exam termination if detected. All closes/stops are opt-in via
    checkboxes rather than all-or-nothing.
.NOTES
    Version:  1.2.0
    Run as Administrator for full functionality (required to stop/start services).
    Use the "Relaunch as Admin" button if you started it without elevation.
    See the "About" tab in the app for a changelog of fixes vs. the original
    console script this replaces.
#>

#Requires -Version 5.1

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms   # SaveFileDialog, Application.DoEvents

# ============================================================================
# SHARED STATE
# ============================================================================
$Global:syncHash = [hashtable]::Synchronized(@{
    Window          = $null
    IsAdmin         = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
    StoppedServices = New-Object System.Collections.Generic.List[string]
    ClosedProcesses = New-Object System.Collections.Generic.List[string]
})

# ============================================================================
# PROCESS / SERVICE DEFINITIONS
# ============================================================================
# NOTE on this list vs. the original script: "edge", "hyper-v", "vscode",
# "sublimetext" and "amdrelive" were never real process names (the actual
# binaries are msedge.exe, vmms.exe/vmcompute.exe, Code.exe, sublime_text.exe),
# so those checks silently matched nothing before. Corrected below on a
# best-effort basis - exact binary names can still vary by install/version.

$script:CriticalProcesses = @(
    'vmware', 'vmware-vmx', 'vmware-hostd', 'virtualbox', 'vboxheadless', 'vboxsvc', 'vmnetdhcp',
    'vmms', 'vmcompute', 'docker', 'dockerdesktop', 'com.docker.backend',
    'obs64', 'obs32', 'xsplit.core', 'streamlabs obs', 'bandicam', 'camtasia', 'snagit32', 'snagiteditor', 'fraps',
    'teamviewer', 'anydesk', 'winvnc', 'tvnserver', 'vncviewer',
    'chromeremotedesktophost', 'parsecd', 'srserver', 'srfeature',
    'wireshark', 'fiddler', 'charles', 'burpsuite',
    'tailscale-ipn', 'tailscaled', 'usblcd',
    'claude', 'claude-cowork'
)

$script:StandardProcesses = @(
    'chrome', 'firefox', 'msedge', 'opera', 'brave',
    'teams', 'skype', 'discord', 'slack', 'zoom', 'webexmta',
    'whatsapp', 'telegram', 'signal',
    'spotify', 'itunes', 'vlc',
    'steam', 'epicgameslauncher', 'origin', 'battle.net',
    'notepad++', 'code', 'sublime_text',
    'dropbox', 'googledrivesync', 'onedrive',
    'nordvpn', 'expressvpn', 'openvpn-gui'
)

$script:OfficeProcesses = @('winword', 'excel', 'powerpnt', 'outlook')

# vmnetdhcp / tailscale-ipn / tailscaled / usblcd / claude / claude-cowork were added
# after OnVUE's own pre-launch check explicitly blocked on them ("The issues below
# could prevent exam launch"), so they're treated as High-Risk, not just Critical.
$script:HighRiskProcesses = @(
    'vmware', 'vmware-vmx', 'virtualbox', 'vboxheadless', 'vmms', 'vmcompute', 'docker', 'dockerdesktop', 'vmnetdhcp',
    'obs64', 'obs32', 'bandicam', 'camtasia', 'snagit32', 'fraps',
    'teamviewer', 'anydesk', 'winvnc', 'tvnserver', 'chromeremotedesktophost', 'parsecd',
    'wireshark', 'fiddler', 'charles', 'burpsuite',
    'tailscale-ipn', 'tailscaled', 'usblcd',
    'claude', 'claude-cowork'
)

# NOTE: the original list also had OneDrive*, Dropbox*, Steam*, Zoom* here.
# None of those ship as Windows services - they're processes only - so
# Get-Service silently matched nothing for them. The real "stop" action for
# those already happens via the process list above; removed here to avoid
# implying a stop action is happening when it isn't.
$script:ServicesToStop = @(
    'TeamViewer*', 'AnyDesk*', 'VNC*', 'tvnserver',
    'VMware*', 'VMnetDHCP', 'VMUSBArbService', 'VirtualBox*', 'com.docker.service', 'Docker*',
    'NordVPN*', 'ExpressVPN*', 'OpenVPN*', 'EaseUS*',
    'Tailscale*', 'usblcd', 'cowork-svc'
)

# ============================================================================
# XAML
# ============================================================================
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="OnVUE Exam Preparation Assistant" Height="780" Width="1150"
        WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" Background="#F3F3F3">
    <Grid Margin="12">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="190"/>
        </Grid.RowDefinitions>

        <!-- HEADER -->
        <Border Grid.Row="0" Background="White" BorderBrush="#DDDDDD" BorderThickness="1" CornerRadius="4" Padding="14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <TextBlock Text="OnVUE Exam Preparation Assistant" FontSize="20" FontWeight="Bold"/>
                    <Border x:Name="borderAdminStatus" Background="#EEEEEE" CornerRadius="3" Padding="8,4" Margin="0,8,0,0" HorizontalAlignment="Left">
                        <TextBlock x:Name="txtAdminStatus" Text="Checking privileges..." FontSize="12"/>
                    </Border>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Button x:Name="btnRelaunchAdmin" Content="Relaunch as Admin" Padding="14,8" Margin="0,0,8,0" Background="#FFF4CE" Visibility="Collapsed"/>
                    <Button x:Name="btnFullPrep" Content="Run Full Preparation" Padding="14,8" Margin="0,0,8,0" FontWeight="Bold"/>
                    <Button x:Name="btnExit" Content="Exit" Padding="14,8"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- TABS -->
        <TabControl Grid.Row="1" x:Name="tabMain" Margin="0,10,0,10">

            <TabItem Header="Pre-Flight">
                <StackPanel Margin="16">
                    <TextBlock TextWrapping="Wrap" Margin="0,0,0,12"
                        Text="Scans your system without making any changes. Run this first - it also populates the Processes and Services tabs so you can review before closing anything."/>
                    <Button x:Name="btnRunPreFlight" Content="Run Pre-Flight Check" HorizontalAlignment="Left" Padding="14,8"/>
                    <Grid Margin="0,20,0,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Border Grid.Column="0" x:Name="borderPfCritical" Margin="4" Padding="10" CornerRadius="4" Background="#EEEEEE">
                            <StackPanel>
                                <TextBlock Text="Critical Processes" FontWeight="Bold"/>
                                <TextBlock x:Name="txtPfCritical" Text="Not scanned"/>
                            </StackPanel>
                        </Border>
                        <Border Grid.Column="1" x:Name="borderPfStandard" Margin="4" Padding="10" CornerRadius="4" Background="#EEEEEE">
                            <StackPanel>
                                <TextBlock Text="Other Processes" FontWeight="Bold"/>
                                <TextBlock x:Name="txtPfStandard" Text="Not scanned"/>
                            </StackPanel>
                        </Border>
                        <Border Grid.Column="2" x:Name="borderPfServices" Margin="4" Padding="10" CornerRadius="4" Background="#EEEEEE">
                            <StackPanel>
                                <TextBlock Text="Services" FontWeight="Bold"/>
                                <TextBlock x:Name="txtPfServices" Text="Not scanned"/>
                            </StackPanel>
                        </Border>
                        <Border Grid.Column="3" x:Name="borderPfVpn" Margin="4" Padding="10" CornerRadius="4" Background="#EEEEEE">
                            <StackPanel>
                                <TextBlock Text="VPN" FontWeight="Bold"/>
                                <TextBlock x:Name="txtPfVpn" Text="Not checked"/>
                            </StackPanel>
                        </Border>
                    </Grid>
                </StackPanel>
            </TabItem>

            <TabItem Header="Processes">
                <DockPanel Margin="16">
                    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,10">
                        <Button x:Name="btnScanProcesses" Content="Scan" Padding="12,6" Margin="0,0,8,0"/>
                        <Button x:Name="btnSelectAllCritical" Content="Select All Critical" Padding="12,6" Margin="0,0,8,0"/>
                        <Button x:Name="btnSelectNoneProcesses" Content="Select None" Padding="12,6" Margin="0,0,8,0"/>
                        <Button x:Name="btnCloseSelectedProcesses" Content="Close Selected" Padding="12,6" Margin="0,0,16,0" Background="#FDECEA"/>
                        <CheckBox x:Name="chkIncludeOffice" Content="Pre-select Office apps (Word/Excel/PowerPoint/Outlook)" VerticalAlignment="Center"/>
                    </StackPanel>
                    <ListView x:Name="lvProcesses">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Width="40">
                                    <GridViewColumn.CellTemplate>
                                        <DataTemplate>
                                            <CheckBox IsChecked="{Binding IsSelected, Mode=TwoWay}" HorizontalAlignment="Center"/>
                                        </DataTemplate>
                                    </GridViewColumn.CellTemplate>
                                </GridViewColumn>
                                <GridViewColumn Header="Process" Width="200" DisplayMemberBinding="{Binding Name}"/>
                                <GridViewColumn Header="Category" Width="110" DisplayMemberBinding="{Binding Category}"/>
                                <GridViewColumn Header="Running Instances" Width="140" DisplayMemberBinding="{Binding InstanceCount}"/>
                                <GridViewColumn Header="Note" Width="330" DisplayMemberBinding="{Binding Note}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                </DockPanel>
            </TabItem>

            <TabItem Header="Services">
                <DockPanel Margin="16">
                    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,6">
                        <Button x:Name="btnScanServices" Content="Scan" Padding="12,6" Margin="0,0,8,0"/>
                        <Button x:Name="btnSelectAllServices" Content="Select All" Padding="12,6" Margin="0,0,8,0"/>
                        <Button x:Name="btnStopSelectedServices" Content="Stop Selected" Padding="12,6" Margin="0,0,8,0" Background="#FDECEA"/>
                    </StackPanel>
                    <TextBlock DockPanel.Dock="Top" Margin="0,0,0,10" TextWrapping="Wrap" Foreground="#666666"
                        Text="Requires Administrator. Anything stopped here can be restarted from the Summary tab."/>
                    <ListView x:Name="lvServices">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Width="40">
                                    <GridViewColumn.CellTemplate>
                                        <DataTemplate>
                                            <CheckBox IsChecked="{Binding IsSelected, Mode=TwoWay}" HorizontalAlignment="Center"/>
                                        </DataTemplate>
                                    </GridViewColumn.CellTemplate>
                                </GridViewColumn>
                                <GridViewColumn Header="Service Name" Width="180" DisplayMemberBinding="{Binding Name}"/>
                                <GridViewColumn Header="Display Name" Width="330" DisplayMemberBinding="{Binding DisplayName}"/>
                                <GridViewColumn Header="Status" Width="110" DisplayMemberBinding="{Binding Status}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                </DockPanel>
            </TabItem>

            <TabItem Header="Optimize &amp; VPN">
                <StackPanel Margin="16">
                    <Border Padding="12" Margin="0,0,0,12" Background="#EEEEEE" CornerRadius="4">
                        <StackPanel>
                            <TextBlock Text="VPN Check" FontWeight="Bold"/>
                            <TextBlock x:Name="txtVpnStatus" Text="Not checked" Margin="0,4,0,8" TextWrapping="Wrap"/>
                            <Button x:Name="btnCheckVpn" Content="Check VPN Status" HorizontalAlignment="Left" Padding="12,6"/>
                        </StackPanel>
                    </Border>
                    <Border Padding="12" Margin="0,0,0,12" Background="#EEEEEE" CornerRadius="4">
                        <StackPanel>
                            <TextBlock Text="Temporary Files" FontWeight="Bold"/>
                            <TextBlock x:Name="txtTempStatus" Text="Not cleared" Margin="0,4,0,8" TextWrapping="Wrap"/>
                            <Button x:Name="btnClearTemp" Content="Clear Temp Files" HorizontalAlignment="Left" Padding="12,6"/>
                        </StackPanel>
                    </Border>
                    <Border Padding="12" Margin="0,0,0,12" Background="#EEEEEE" CornerRadius="4">
                        <StackPanel>
                            <TextBlock Text="Network Connectivity" FontWeight="Bold"/>
                            <TextBlock x:Name="txtNetworkStatus" Text="Not checked" Margin="0,4,0,8" TextWrapping="Wrap"/>
                            <Button x:Name="btnCheckNetwork" Content="Check Network" HorizontalAlignment="Left" Padding="12,6"/>
                        </StackPanel>
                    </Border>
                    <Border Padding="12" Background="#EEEEEE" CornerRadius="4">
                        <StackPanel>
                            <TextBlock Text="Notifications (Focus Assist)" FontWeight="Bold"/>
                            <TextBlock TextWrapping="Wrap" Margin="0,4,0,8" Foreground="#666666"
                                Text="Windows doesn't expose a supported way to toggle Focus Assist from a script (the old registry trick is undocumented and breaks across versions). This opens the real settings page instead - turn on Do Not Disturb or Alarms Only before your exam."/>
                            <Button x:Name="btnOpenFocusAssist" Content="Open Focus Assist Settings" HorizontalAlignment="Left" Padding="12,6"/>
                        </StackPanel>
                    </Border>
                </StackPanel>
            </TabItem>

            <TabItem Header="High-Risk Scan">
                <DockPanel Margin="16">
                    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,10">
                        <Button x:Name="btnScanHighRisk" Content="Scan for High-Risk Software" Padding="12,6"/>
                    </StackPanel>
                    <Border x:Name="borderHighRiskBanner" DockPanel.Dock="Top" Visibility="Collapsed" Background="#FDECEA" Padding="10" Margin="0,0,0,10" CornerRadius="4">
                        <TextBlock x:Name="txtHighRiskBanner" Foreground="#B3261E" FontWeight="Bold" TextWrapping="Wrap"/>
                    </Border>
                    <ListView x:Name="lvHighRisk">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Process" Width="260" DisplayMemberBinding="{Binding Name}"/>
                                <GridViewColumn Header="Running Instances" Width="160" DisplayMemberBinding="{Binding InstanceCount}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                </DockPanel>
            </TabItem>

            <TabItem Header="Summary &amp; Export">
                <StackPanel Margin="16">
                    <TextBlock Text="Session Summary" FontSize="16" FontWeight="Bold" Margin="0,0,0,10"/>
                    <TextBlock x:Name="txtSummaryProcesses" Text="Processes closed this session: 0"/>
                    <TextBlock x:Name="txtSummaryServices" Text="Services stopped this session: 0" Margin="0,4,0,0"/>
                    <StackPanel Orientation="Horizontal" Margin="0,16,0,20">
                        <Button x:Name="btnRestoreServices" Content="Restore Stopped Services" Padding="12,6" Margin="0,0,8,0"/>
                        <Button x:Name="btnExportReport" Content="Export Report..." Padding="12,6"/>
                    </StackPanel>

                    <TextBlock Text="Live System Checks" FontWeight="Bold" Margin="0,0,0,8"/>
                    <Button x:Name="btnRunSystemChecks" Content="Run System Checks" HorizontalAlignment="Left" Padding="12,6" Margin="0,0,0,10"/>
                    <Grid Margin="0,0,0,20">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Border Grid.Column="0" x:Name="borderMonitors" Margin="4" Padding="10" CornerRadius="4" Background="#EEEEEE">
                            <StackPanel>
                                <TextBlock Text="Monitors" FontWeight="Bold"/>
                                <TextBlock x:Name="txtMonitors" Text="Not checked" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                        <Border Grid.Column="1" x:Name="borderWebcam" Margin="4" Padding="10" CornerRadius="4" Background="#EEEEEE">
                            <StackPanel>
                                <TextBlock Text="Webcam" FontWeight="Bold"/>
                                <TextBlock x:Name="txtWebcam" Text="Not checked" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                        <Border Grid.Column="2" x:Name="borderMicrophone" Margin="4" Padding="10" CornerRadius="4" Background="#EEEEEE">
                            <StackPanel>
                                <TextBlock Text="Microphone" FontWeight="Bold"/>
                                <TextBlock x:Name="txtMicrophone" Text="Not checked" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                    </Grid>
                    <TextBlock Margin="0,0,0,20" TextWrapping="Wrap" FontStyle="Italic" Foreground="#666666" FontSize="11"
                        Text="Webcam/microphone detection is name- and device-class-based (no direct hardware test), so treat a &quot;not detected&quot; result as a prompt to double-check manually, not a definitive answer."/>

                    <TextBlock Text="Final Checklist Before Starting Your Exam" FontWeight="Bold" Margin="0,0,0,8"/>
                    <ItemsControl>
                        <TextBlock Text="- All browser windows closed"/>
                        <TextBlock Text="- Communication apps closed (Teams, Slack, Discord, etc.)"/>
                        <TextBlock Text="- VPN disconnected"/>
                        <TextBlock Text="- Screen sharing/recording software closed"/>
                        <TextBlock Text="- Virtual machines shut down"/>
                        <TextBlock Text="- Antivirus real-time scanning paused (if required by your exam)"/>
                        <TextBlock Text="- Second monitor disconnected (if required)"/>
                        <TextBlock Text="- Room well-lit and clear of prohibited items"/>
                        <TextBlock Text="- Mobile phone out of reach"/>
                        <TextBlock Text="- Stable internet connection verified"/>
                    </ItemsControl>
                </StackPanel>
            </TabItem>

            <TabItem Header="About">
                <StackPanel Margin="16">
                    <TextBlock Text="OnVUE Exam Preparation Assistant" FontSize="16" FontWeight="Bold"/>
                    <TextBlock Text="Version 1.2.0" Margin="0,2,0,12" Foreground="#666666"/>
                    <TextBlock Text="Changelog" FontWeight="Bold" Margin="0,0,0,6"/>
                    <TextBlock TextWrapping="Wrap" Text="1.2.0 - Added vmnetdhcp (VMware DHCP Service), Tailscale, usblcd, and Claude/Cowork (cowork-svc) to the Critical and High-Risk lists, based on an actual OnVUE pre-launch block."/>
                    <TextBlock TextWrapping="Wrap" Margin="0,0,0,10" Text="1.1.0 - Added live system checks (monitor count, webcam, microphone) to the Summary tab, and a &quot;Relaunch as Admin&quot; button for self-elevation."/>
                    <TextBlock TextWrapping="Wrap" Margin="0,0,0,10" Text="1.0.0 - WPF GUI rewrite of the original console script. Fixes vs. the original:"/>
                    <ItemsControl Margin="12,6,0,0">
                        <TextBlock TextWrapping="Wrap" Text="- Fixed VPN adapter detection - the original had an operator-precedence bug (-or/-and) that could false-positive on any VPN-named adapter regardless of status"/>
                        <TextBlock TextWrapping="Wrap" Text="- Replaced the no-op &quot;Focus Assist&quot; step (it printed success without changing anything) with a link to the real Windows settings page"/>
                        <TextBlock TextWrapping="Wrap" Text="- Office apps (Word/Excel/PowerPoint/Outlook) split into their own category with an explicit confirmation before closing"/>
                        <TextBlock TextWrapping="Wrap" Text="- Removed OneDrive*/Dropbox*/Steam*/Zoom* from the services-to-stop list - none of these register as Windows services, so those entries never matched anything"/>
                        <TextBlock TextWrapping="Wrap" Text="- Corrected several process names (msedge, sublime_text, Code, vmms/vmcompute for Hyper-V)"/>
                        <TextBlock TextWrapping="Wrap" Text="- Every close/stop action is opt-in via checkboxes instead of all-or-nothing"/>
                        <TextBlock TextWrapping="Wrap" Text="- Added a text report export and a check for unrestored services on exit"/>
                    </ItemsControl>
                    <TextBlock Margin="0,16,0,0" TextWrapping="Wrap" Foreground="#666666"
                        Text="Run as Administrator for full functionality (required to stop/start services)."/>
                </StackPanel>
            </TabItem>

        </TabControl>

        <!-- LOG -->
        <Border Grid.Row="2" BorderBrush="#CCCCCC" BorderThickness="1" Background="#1E1E1E" CornerRadius="4">
            <Grid Margin="6">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="0,0,0,4">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="0" Text="Activity Log" Foreground="White" FontWeight="Bold"/>
                    <Button Grid.Column="1" x:Name="btnClearLog" Content="Clear" Padding="8,2"/>
                </Grid>
                <TextBox Grid.Row="1" x:Name="txtLog" Background="#1E1E1E" Foreground="#D4D4D4"
                         FontFamily="Consolas" FontSize="12" IsReadOnly="True" TextWrapping="NoWrap"
                         VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" BorderThickness="0"/>
            </Grid>
        </Border>
    </Grid>
</Window>
'@

# ============================================================================
# LOAD XAML
# ============================================================================
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$syncHash.Window = $window

$controlNames = @(
    'txtAdminStatus', 'borderAdminStatus', 'btnFullPrep', 'btnExit', 'btnRelaunchAdmin', 'tabMain',
    'btnRunPreFlight', 'txtPfCritical', 'txtPfStandard', 'txtPfServices', 'txtPfVpn',
    'borderPfCritical', 'borderPfStandard', 'borderPfServices', 'borderPfVpn',
    'btnScanProcesses', 'btnSelectAllCritical', 'btnSelectNoneProcesses', 'btnCloseSelectedProcesses', 'chkIncludeOffice', 'lvProcesses',
    'btnScanServices', 'btnSelectAllServices', 'btnStopSelectedServices', 'lvServices',
    'txtVpnStatus', 'btnCheckVpn', 'txtTempStatus', 'btnClearTemp', 'txtNetworkStatus', 'btnCheckNetwork', 'btnOpenFocusAssist',
    'btnScanHighRisk', 'borderHighRiskBanner', 'txtHighRiskBanner', 'lvHighRisk',
    'txtSummaryProcesses', 'txtSummaryServices', 'btnRestoreServices', 'btnExportReport',
    'btnRunSystemChecks', 'borderMonitors', 'txtMonitors', 'borderWebcam', 'txtWebcam', 'borderMicrophone', 'txtMicrophone',
    'btnClearLog', 'txtLog'
)
$controls = @{}
foreach ($name in $controlNames) {
    $controls[$name] = $window.FindName($name)
    if (-not $controls[$name]) { Write-Warning "Control not found in XAML: $name" }
}

$script:ProcessItems  = New-Object System.Collections.ObjectModel.ObservableCollection[object]
$script:ServiceItems  = New-Object System.Collections.ObjectModel.ObservableCollection[object]
$script:HighRiskItems = New-Object System.Collections.ObjectModel.ObservableCollection[object]
$controls.lvProcesses.ItemsSource = $script:ProcessItems
$controls.lvServices.ItemsSource  = $script:ServiceItems
$controls.lvHighRisk.ItemsSource  = $script:HighRiskItems

# ============================================================================
# HELPERS
# ============================================================================
function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')][string]$Level = 'Info'
    )
    $prefix = @{ Info = '[INFO]'; Success = '[ OK ]'; Warning = '[WARN]'; Error = '[FAIL]' }[$Level]
    $line = "{0}  {1} {2}`r`n" -f (Get-Date -Format 'HH:mm:ss'), $prefix, $Message
    $controls.txtLog.AppendText($line)
    $controls.txtLog.ScrollToEnd()
}

function Set-StatusBadge {
    param($Border, [ValidateSet('Success', 'Warning', 'Error', 'Neutral')][string]$Level)
    $colors = @{
        Success = @{ Bg = '#DFF6DD'; Fg = '#0F7B0F' }
        Warning = @{ Bg = '#FFF4CE'; Fg = '#8A6D00' }
        Error   = @{ Bg = '#FDECEA'; Fg = '#B3261E' }
        Neutral = @{ Bg = '#EEEEEE'; Fg = '#333333' }
    }
    $c = $colors[$Level]
    $conv = New-Object System.Windows.Media.BrushConverter
    $Border.Background = $conv.ConvertFromString($c.Bg)
    if ($Border.Child -is [System.Windows.Controls.StackPanel]) {
        foreach ($child in $Border.Child.Children) {
            if ($child -is [System.Windows.Controls.TextBlock]) { $child.Foreground = $conv.ConvertFromString($c.Fg) }
        }
    }
}

function Set-ActionButtonsEnabled {
    param([bool]$Enabled)
    foreach ($name in @('btnFullPrep', 'btnCloseSelectedProcesses', 'btnStopSelectedServices', 'btnScanProcesses', 'btnScanServices', 'btnRunPreFlight', 'btnRestoreServices', 'btnClearTemp')) {
        if ($controls[$name]) { $controls[$name].IsEnabled = $Enabled }
    }
}

function Update-SummaryTab {
    $controls.txtSummaryProcesses.Text = "Processes closed this session: $($syncHash.ClosedProcesses.Count)"
    $controls.txtSummaryServices.Text  = "Services stopped this session: $($syncHash.StoppedServices.Count)"
}

function Invoke-SystemChecks {
    Write-Log 'Running system checks (monitors, webcam, microphone)...'

    # Monitors - reliable, via WinForms
    try {
        $monitorCount = [System.Windows.Forms.Screen]::AllScreens.Count
        $controls.txtMonitors.Text = "$monitorCount display(s) detected."
        if ($monitorCount -gt 1) {
            Set-StatusBadge -Border $controls.borderMonitors -Level Warning
            $controls.txtMonitors.Text += ' Disconnect extras if your exam requires a single monitor.'
            Write-Log "$monitorCount monitor(s) detected." -Level Warning
        } else {
            Set-StatusBadge -Border $controls.borderMonitors -Level Success
            Write-Log "$monitorCount monitor(s) detected." -Level Success
        }
    } catch {
        $controls.txtMonitors.Text = 'Could not check.'
        Set-StatusBadge -Border $controls.borderMonitors -Level Warning
        Write-Log "Monitor check failed: $($_.Exception.Message)" -Level Error
    }

    # Webcam - device-class and name based (no direct hardware probe, so this is
    # a best-effort signal, not a guarantee a working camera is present)
    try {
        $camDevices = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop | Where-Object {
            $_.PNPClass -in @('Camera', 'Image') -or $_.Name -match 'camera|webcam'
        }
        if ($camDevices) {
            $controls.txtWebcam.Text = "Detected: $((($camDevices | Select-Object -First 1 -ExpandProperty Name)))"
            Set-StatusBadge -Border $controls.borderWebcam -Level Success
            Write-Log "Webcam detected: $($camDevices[0].Name)" -Level Success
        } else {
            $controls.txtWebcam.Text = 'No webcam detected.'
            Set-StatusBadge -Border $controls.borderWebcam -Level Error
            Write-Log 'No webcam detected.' -Level Warning
        }
    } catch {
        $controls.txtWebcam.Text = 'Could not check.'
        Set-StatusBadge -Border $controls.borderWebcam -Level Warning
        Write-Log "Webcam check failed: $($_.Exception.Message)" -Level Error
    }

    # Microphone - same caveat as webcam; matches audio-endpoint devices whose
    # name contains "Microphone", which misses unusually-named hardware
    try {
        $micDevices = Get-CimInstance -ClassName Win32_PnPEntity -Filter "PNPClass='AudioEndpoint'" -ErrorAction Stop |
            Where-Object { $_.Name -match 'Microphone|Mic ' }
        if ($micDevices) {
            $controls.txtMicrophone.Text = "Detected: $((($micDevices | Select-Object -First 1 -ExpandProperty Name)))"
            Set-StatusBadge -Border $controls.borderMicrophone -Level Success
            Write-Log "Microphone detected: $($micDevices[0].Name)" -Level Success
        } else {
            $controls.txtMicrophone.Text = 'No microphone detected.'
            Set-StatusBadge -Border $controls.borderMicrophone -Level Error
            Write-Log 'No microphone detected.' -Level Warning
        }
    } catch {
        $controls.txtMicrophone.Text = 'Could not check.'
        Set-StatusBadge -Border $controls.borderMicrophone -Level Warning
        Write-Log "Microphone check failed: $($_.Exception.Message)" -Level Error
    }
}

function Invoke-SelfElevate {
    if ($syncHash.IsAdmin) { return }
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        [System.Windows.MessageBox]::Show(
            'Could not determine this script''s file path to relaunch automatically. Right-click the .ps1 file and choose "Run with PowerShell as Administrator" instead.',
            'Relaunch Failed', 'OK', 'Warning') | Out-Null
        return
    }
    try {
        Write-Log 'Relaunching as Administrator...' -Level Info
        Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"") -Verb RunAs -ErrorAction Stop
        $window.Close()
    } catch {
        if ($_.Exception.Message -match 'cancel') {
            Write-Log 'Elevation cancelled (UAC prompt declined).' -Level Warning
        } else {
            Write-Log "Failed to relaunch as Administrator: $($_.Exception.Message)" -Level Error
            [System.Windows.MessageBox]::Show("Could not relaunch as Administrator: $($_.Exception.Message)", 'Relaunch Failed', 'OK', 'Error') | Out-Null
        }
    }
}

# ============================================================================
# SCAN FUNCTIONS
# ============================================================================
function Invoke-ProcessScan {
    Write-Log 'Scanning for interfering processes...'
    $script:ProcessItems.Clear()
    $includeOfficePreselect = $controls.chkIncludeOffice.IsChecked -eq $true

    $groups = @(
        @{ List = $script:CriticalProcesses; Category = 'Critical'; DefaultSelected = $true; Note = 'Will very likely interfere with proctoring' }
        @{ List = $script:StandardProcesses; Category = 'Standard'; DefaultSelected = $false; Note = 'Recommended to close' }
        @{ List = $script:OfficeProcesses; Category = 'Office'; DefaultSelected = $includeOfficePreselect; Note = 'Only close if it conflicts with your exam' }
    )

    $totalFound = 0
    foreach ($group in $groups) {
        foreach ($procName in $group.List) {
            $running = Get-Process -Name $procName -ErrorAction SilentlyContinue
            if ($running) {
                $totalFound++
                $script:ProcessItems.Add([PSCustomObject]@{
                    IsSelected    = $group.DefaultSelected
                    Name          = $procName
                    Category      = $group.Category
                    InstanceCount = ($running | Measure-Object).Count
                    Note          = $group.Note
                })
            }
        }
    }

    if ($totalFound -eq 0) {
        Write-Log 'No interfering processes detected.' -Level Success
    } else {
        Write-Log "Found $totalFound interfering process type(s). Review and select which to close." -Level Warning
    }
    return $totalFound
}

function Invoke-ServiceScan {
    Write-Log 'Scanning for interfering services...'
    $script:ServiceItems.Clear()
    $found = 0
    foreach ($pattern in $script:ServicesToStop) {
        $services = Get-Service -Name $pattern -ErrorAction SilentlyContinue
        foreach ($svc in $services) {
            if ($svc.Status -eq 'Running') {
                $found++
                $script:ServiceItems.Add([PSCustomObject]@{
                    IsSelected  = $true
                    Name        = $svc.Name
                    DisplayName = $svc.DisplayName
                    Status      = $svc.Status.ToString()
                })
            }
        }
    }
    if ($found -eq 0) {
        Write-Log 'No interfering services detected.' -Level Success
    } else {
        Write-Log "Found $found running service(s) that may interfere." -Level Warning
    }
    return $found
}

function Invoke-VpnCheck {
    Write-Log 'Checking VPN status...'
    try {
        # Fixed: original was "-like *VPN* -or -like *TAP* -and Status -eq Up", which
        # (due to -and binding tighter than -or) matched ANY VPN-named adapter
        # regardless of status. Parenthesized correctly below.
        $vpnAdapters = Get-NetAdapter -ErrorAction Stop | Where-Object {
            ($_.InterfaceDescription -like '*VPN*' -or $_.InterfaceDescription -like '*TAP*') -and $_.Status -eq 'Up'
        }
    } catch {
        Write-Log "Could not query network adapters: $($_.Exception.Message)" -Level Error
        $controls.txtVpnStatus.Text = 'Could not check (see log).'
        $controls.txtPfVpn.Text = 'Check failed'
        Set-StatusBadge -Border $controls.borderPfVpn -Level Warning
        return
    }

    if ($vpnAdapters) {
        $names = ($vpnAdapters | Select-Object -ExpandProperty Name) -join ', '
        $controls.txtVpnStatus.Text = "Active VPN/TAP adapter detected: $names - disconnect before your exam."
        $controls.txtPfVpn.Text = 'VPN active'
        Set-StatusBadge -Border $controls.borderPfVpn -Level Warning
        Write-Log "VPN adapter(s) up: $names" -Level Warning
    } else {
        $controls.txtVpnStatus.Text = 'No active VPN detected.'
        $controls.txtPfVpn.Text = 'Clear'
        Set-StatusBadge -Border $controls.borderPfVpn -Level Success
        Write-Log 'No active VPN detected.' -Level Success
    }
}

function Invoke-HighRiskScan {
    Write-Log 'Scanning for high-risk software...'
    $script:HighRiskItems.Clear()
    $found = 0
    foreach ($procName in $script:HighRiskProcesses) {
        $running = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($running) {
            $found++
            $script:HighRiskItems.Add([PSCustomObject]@{
                Name          = $procName
                InstanceCount = ($running | Measure-Object).Count
            })
        }
    }
    if ($found -eq 0) {
        $controls.borderHighRiskBanner.Visibility = 'Collapsed'
        Write-Log 'No high-risk software detected.' -Level Success
    } else {
        $controls.txtHighRiskBanner.Text = "$found high-risk application(s) detected. These WILL cause exam termination if not fully closed."
        $controls.borderHighRiskBanner.Visibility = 'Visible'
        Write-Log "$found high-risk application(s) detected!" -Level Error
    }
    return $found
}

function Invoke-PreFlightScan {
    Write-Log '=== Running Pre-Flight Check ===' -Level Info
    Invoke-ProcessScan | Out-Null
    $critCount = ($script:ProcessItems | Where-Object Category -eq 'Critical').Count
    $stdCount  = ($script:ProcessItems | Where-Object Category -eq 'Standard').Count
    $svcCount  = Invoke-ServiceScan
    Invoke-VpnCheck
    Invoke-HighRiskScan | Out-Null

    $controls.txtPfCritical.Text = "$critCount found"
    Set-StatusBadge -Border $controls.borderPfCritical -Level $(if ($critCount -gt 0) { 'Error' } else { 'Success' })
    $controls.txtPfStandard.Text = "$stdCount found"
    Set-StatusBadge -Border $controls.borderPfStandard -Level $(if ($stdCount -gt 0) { 'Warning' } else { 'Success' })
    $controls.txtPfServices.Text = "$svcCount found"
    Set-StatusBadge -Border $controls.borderPfServices -Level $(if ($svcCount -gt 0) { 'Warning' } else { 'Success' })

    Write-Log '=== Pre-Flight Check Complete ===' -Level Info
}

# ============================================================================
# ACTION FUNCTIONS
# ============================================================================
function Close-SelectedProcesses {
    $selected = $script:ProcessItems | Where-Object { $_.IsSelected }
    if (-not $selected) {
        [System.Windows.MessageBox]::Show('No processes selected.', 'Nothing to do', 'OK', 'Information') | Out-Null
        return
    }
    $officeSelected = $selected | Where-Object Category -eq 'Office'
    if ($officeSelected) {
        $msg = "You've selected Office application(s) to close: $(($officeSelected.Name) -join ', '). Any unsaved work in these apps will be lost if they don't close gracefully. Continue?"
        $result = [System.Windows.MessageBox]::Show($msg, 'Confirm Closing Office Apps', 'YesNo', 'Warning')
        if ($result -ne 'Yes') { Write-Log 'Cancelled closing Office apps.' -Level Warning; return }
    }

    Set-ActionButtonsEnabled $false
    try {
        $closedCount = 0
        foreach ($item in $selected) {
            $processes = Get-Process -Name $item.Name -ErrorAction SilentlyContinue
            foreach ($process in $processes) {
                if ($item.Name -like 'powershell*' -and $process.Id -eq $PID) { continue }
                try {
                    Write-Log "Closing $($process.ProcessName) (PID $($process.Id))..."
                    if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
                        [void]$process.CloseMainWindow()
                        $waited = 0
                        while (-not $process.HasExited -and $waited -lt 750) {
                            Start-Sleep -Milliseconds 100
                            $waited += 100
                            [System.Windows.Forms.Application]::DoEvents()
                        }
                    }
                    if (-not $process.HasExited) {
                        $process.Kill()
                        Write-Log "  -> Force closed $($process.ProcessName)" -Level Warning
                    } else {
                        Write-Log "  -> Closed $($process.ProcessName)" -Level Success
                    }
                    $syncHash.ClosedProcesses.Add($process.ProcessName)
                    $closedCount++
                } catch {
                    Write-Log "  -> Failed to close $($process.ProcessName): $($_.Exception.Message)" -Level Error
                }
                [System.Windows.Forms.Application]::DoEvents()
            }
        }
        Write-Log "Closed $closedCount process instance(s)." -Level Success
        Update-SummaryTab
        Invoke-ProcessScan | Out-Null
    } finally {
        Set-ActionButtonsEnabled $true
    }
}

function Stop-SelectedServices {
    if (-not $syncHash.IsAdmin) {
        [System.Windows.MessageBox]::Show('Stopping services requires running this tool as Administrator.', 'Administrator Required', 'OK', 'Warning') | Out-Null
        return
    }
    $selected = $script:ServiceItems | Where-Object { $_.IsSelected }
    if (-not $selected) {
        [System.Windows.MessageBox]::Show('No services selected.', 'Nothing to do', 'OK', 'Information') | Out-Null
        return
    }
    Set-ActionButtonsEnabled $false
    try {
        $stoppedCount = 0
        foreach ($item in $selected) {
            try {
                Write-Log "Stopping service $($item.DisplayName)..."
                Stop-Service -Name $item.Name -Force -ErrorAction Stop
                $syncHash.StoppedServices.Add($item.Name)
                $stoppedCount++
                Write-Log "  -> Stopped $($item.DisplayName)" -Level Success
            } catch {
                Write-Log "  -> Failed to stop $($item.DisplayName): $($_.Exception.Message)" -Level Error
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
        Write-Log "Stopped $stoppedCount service(s)." -Level Success
        Update-SummaryTab
        Invoke-ServiceScan | Out-Null
    } finally {
        Set-ActionButtonsEnabled $true
    }
}

function Restore-StoppedServices {
    if ($syncHash.StoppedServices.Count -eq 0) {
        Write-Log 'No services to restore this session.' -Level Info
        return
    }
    if (-not $syncHash.IsAdmin) {
        [System.Windows.MessageBox]::Show('Restoring services requires running this tool as Administrator.', 'Administrator Required', 'OK', 'Warning') | Out-Null
        return
    }
    Set-ActionButtonsEnabled $false
    try {
        $restored = 0
        foreach ($name in @($syncHash.StoppedServices)) {
            try {
                $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
                if ($svc -and $svc.Status -ne 'Running') {
                    Write-Log "Starting $($svc.DisplayName)..."
                    Start-Service -Name $name -ErrorAction Stop
                    Write-Log "  -> Started $($svc.DisplayName)" -Level Success
                    $restored++
                }
            } catch {
                Write-Log "  -> Failed to start $($name): $($_.Exception.Message)" -Level Error
            }
        }
        $syncHash.StoppedServices.Clear()
        Write-Log "Restored $restored service(s)." -Level Success
        Update-SummaryTab
    } finally {
        Set-ActionButtonsEnabled $true
    }
}

function Clear-TempFiles {
    Write-Log 'Clearing temporary files...'
    try {
        $items = Get-ChildItem -Path $env:TEMP -ErrorAction SilentlyContinue
        $count = ($items | Measure-Object).Count
        $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $controls.txtTempStatus.Text = "Cleared approximately $count item(s) from $env:TEMP."
        Write-Log "Cleared approximately $count temp item(s)." -Level Success
    } catch {
        $controls.txtTempStatus.Text = 'Some temporary files could not be cleared (normal for files still in use).'
        Write-Log "Temp clear finished with some items skipped: $($_.Exception.Message)" -Level Warning
    }
}

function Test-NetworkConnectivity {
    Write-Log 'Checking network connectivity...'
    try {
        $ok = Test-Connection -ComputerName '8.8.8.8' -Count 2 -Quiet -ErrorAction Stop
    } catch {
        $ok = $false
    }
    if ($ok) {
        $controls.txtNetworkStatus.Text = 'Internet connectivity verified.'
        Write-Log 'Internet connectivity verified.' -Level Success
    } else {
        $controls.txtNetworkStatus.Text = 'Could not verify internet connectivity.'
        Write-Log 'Could not verify internet connectivity.' -Level Warning
    }
}

function Open-FocusAssistSettings {
    try {
        Start-Process 'ms-settings:quiethours' -ErrorAction Stop
        Write-Log 'Opened Focus Assist settings.' -Level Info
    } catch {
        Write-Log "Could not open Focus Assist settings automatically: $($_.Exception.Message)" -Level Warning
    }
}

function Export-SessionReport {
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = 'Text file (*.txt)|*.txt|All files (*.*)|*.*'
    $dialog.FileName = "OnVUE-Prep-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('OnVUE Exam Preparation - Session Report')
    [void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("Administrator session: $($syncHash.IsAdmin)")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Processes closed ($($syncHash.ClosedProcesses.Count)):")
    if ($syncHash.ClosedProcesses.Count -gt 0) {
        $syncHash.ClosedProcesses | Group-Object | ForEach-Object { [void]$sb.AppendLine("  - $($_.Name) x$($_.Count)") }
    } else { [void]$sb.AppendLine('  (none)') }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Services stopped, not yet restored ($($syncHash.StoppedServices.Count)):")
    if ($syncHash.StoppedServices.Count -gt 0) {
        $syncHash.StoppedServices | ForEach-Object { [void]$sb.AppendLine("  - $_") }
    } else { [void]$sb.AppendLine('  (none)') }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('Activity Log:')
    [void]$sb.AppendLine($controls.txtLog.Text)

    try {
        Set-Content -Path $dialog.FileName -Value $sb.ToString() -Encoding UTF8
        Write-Log "Report exported to $($dialog.FileName)" -Level Success
    } catch {
        Write-Log "Failed to export report: $($_.Exception.Message)" -Level Error
    }
}

function Start-FullPreparation {
    $result = [System.Windows.MessageBox]::Show(
        "This will scan your system, then close all detected Critical and High-Risk processes and stop all detected interfering services. Office apps are only closed if you've enabled that option in the Processes tab. Make sure all your work is saved. Continue?",
        'Confirm Full Preparation', 'YesNo', 'Warning')
    if ($result -ne 'Yes') { Write-Log 'Full preparation cancelled.' -Level Warning; return }

    Write-Log '=== Starting Full Preparation ===' -Level Info
    Invoke-PreFlightScan

    foreach ($item in $script:ProcessItems) {
        if ($item.Category -eq 'Critical') { $item.IsSelected = $true }
    }
    $controls.lvProcesses.Items.Refresh()
    Close-SelectedProcesses

    foreach ($item in $script:ServiceItems) { $item.IsSelected = $true }
    $controls.lvServices.Items.Refresh()
    Stop-SelectedServices

    Clear-TempFiles
    Test-NetworkConnectivity
    Invoke-HighRiskScan | Out-Null
    Invoke-SystemChecks

    Write-Log '=== Full Preparation Complete - review the Summary tab ===' -Level Success
    $controls.tabMain.SelectedIndex = 5
}

# ============================================================================
# EVENT WIRING
# ============================================================================
$controls.btnRunPreFlight.Add_Click({ Invoke-PreFlightScan })
$controls.btnScanProcesses.Add_Click({ Invoke-ProcessScan | Out-Null })
$controls.btnSelectAllCritical.Add_Click({
    foreach ($item in $script:ProcessItems) { $item.IsSelected = ($item.Category -eq 'Critical') }
    $controls.lvProcesses.Items.Refresh()
})
$controls.btnSelectNoneProcesses.Add_Click({
    foreach ($item in $script:ProcessItems) { $item.IsSelected = $false }
    $controls.lvProcesses.Items.Refresh()
})
$controls.btnCloseSelectedProcesses.Add_Click({ Close-SelectedProcesses })

$controls.btnScanServices.Add_Click({ Invoke-ServiceScan | Out-Null })
$controls.btnSelectAllServices.Add_Click({
    foreach ($item in $script:ServiceItems) { $item.IsSelected = $true }
    $controls.lvServices.Items.Refresh()
})
$controls.btnStopSelectedServices.Add_Click({ Stop-SelectedServices })

$controls.btnCheckVpn.Add_Click({ Invoke-VpnCheck })
$controls.btnClearTemp.Add_Click({ Clear-TempFiles })
$controls.btnCheckNetwork.Add_Click({ Test-NetworkConnectivity })
$controls.btnOpenFocusAssist.Add_Click({ Open-FocusAssistSettings })

$controls.btnScanHighRisk.Add_Click({ Invoke-HighRiskScan | Out-Null })

$controls.btnRestoreServices.Add_Click({ Restore-StoppedServices })
$controls.btnExportReport.Add_Click({ Export-SessionReport })
$controls.btnRunSystemChecks.Add_Click({ Invoke-SystemChecks })

$controls.btnClearLog.Add_Click({ $controls.txtLog.Clear() })
$controls.btnFullPrep.Add_Click({ Start-FullPreparation })
$controls.btnExit.Add_Click({ $window.Close() })
$controls.btnRelaunchAdmin.Add_Click({ Invoke-SelfElevate })

$window.Add_Closing({
    if ($syncHash.StoppedServices.Count -gt 0) {
        $result = [System.Windows.MessageBox]::Show(
            "$($syncHash.StoppedServices.Count) service(s) stopped by this tool have not been restored. Exit anyway?",
            'Unrestored Services', 'YesNo', 'Warning')
        if ($result -ne 'Yes') { $_.Cancel = $true }
    }
})

# ============================================================================
# INITIAL STATE
# ============================================================================
if ($syncHash.IsAdmin) {
    $controls.txtAdminStatus.Text = 'Running with Administrator privileges - full functionality available.'
    Set-StatusBadge -Border $controls.borderAdminStatus -Level Success
    $controls.btnRelaunchAdmin.Visibility = 'Collapsed'
} else {
    $controls.txtAdminStatus.Text = 'Not running as Administrator - service stop/start is unavailable. Click "Relaunch as Admin" for full functionality.'
    Set-StatusBadge -Border $controls.borderAdminStatus -Level Warning
    $controls.btnRelaunchAdmin.Visibility = 'Visible'
}
Write-Log 'OnVUE Exam Preparation Assistant started.' -Level Info
if ($syncHash.IsAdmin) {
    Write-Log 'Running with Administrator privileges.' -Level Success
} else {
    Write-Log 'Not running as Administrator - service stop/start will be unavailable.' -Level Warning
}

[void]$window.ShowDialog()