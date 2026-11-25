param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$NoElevate,
    [switch]$SkipChromeTabs,
    [switch]$SkipAppLaunches,
    [switch]$DeferChatGPTInstall,
    [string]$InstallRoot = "C:\Tools",
    [string]$SoftwareIds = "",
    [string]$LaunchAppIds = "",
    [string]$BrowserTabIds = "",
    [ValidateSet("Desktop", "Web", "None")][string]$ChatGPTMode = "Desktop"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = "C:\Tools"
}
$InstallRoot = $InstallRoot.Trim()
if ($InstallRoot -match '["\r\n]') {
    throw "Invalid InstallRoot path: contains disallowed characters."
}
if ($InstallRoot.Length -gt 3) {
    $InstallRoot = $InstallRoot.TrimEnd('\', '/')
}

$Script:AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:BaseDir = Split-Path -Parent $Script:AppDir
$Script:ResourceDir = Join-Path $Script:BaseDir "resource"
$Script:ConfigPath = Join-Path $Script:AppDir "config\software.json"
$Script:LogDir = Join-Path $Script:AppDir "logs"
$Script:MainLog = Join-Path $Script:LogDir "install.log"
$Script:Results = New-Object System.Collections.Generic.List[object]
$Script:GitInstallJob = $null
$Script:SelectedSoftwareIds = @()
$Script:SelectedLaunchAppIds = @()
$Script:SelectedBrowserTabIds = @()

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "DRYRUN")][string]$Level = "INFO"
    )

    if (-not (Test-Path -LiteralPath $Script:LogDir)) {
        New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null
    }

    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -LiteralPath $Script:MainLog -Value $line -Encoding UTF8
    Write-Host $line
}

function Add-Result {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Message
    )

    $Script:Results.Add([pscustomobject]@{
        Name = $Name
        Status = $Status
        Message = $Message
    }) | Out-Null
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-IdList {
    param(
        [string]$RawValue,
        [string[]]$DefaultIds
    )

    if ([string]::IsNullOrWhiteSpace($RawValue)) {
        return @($DefaultIds)
    }

    if ($RawValue.Trim().ToUpperInvariant() -eq "NONE") {
        return @()
    }

    return @(
        $RawValue.Split(",") |
            ForEach-Object { $_.Trim().ToLowerInvariant() } |
            Where-Object { $_ -ne "" }
    )
}

function Initialize-Selections {
    $config = Get-ConfiguredSoftware
    $defaultSoftware = @($config.software | Where-Object { $_.defaultSelected -eq $true } | ForEach-Object { $_.id })
    if ($defaultSoftware.Count -eq 0) {
        $defaultSoftware = @("7zip", "godot", "node", "git", "sourcetree", "vscode", "codex", "chatgpt")
    }

    $defaultLaunchApps = @($config.software | Where-Object { $_.defaultLaunch -eq $true } | ForEach-Object { $_.id })
    if ($defaultLaunchApps.Count -eq 0) {
        $defaultLaunchApps = @("godot", "sourcetree", "vscode", "chatgpt")
    }

    $defaultBrowserTabs = @()
    if ($config.browserTabs) {
        $defaultBrowserTabs = @($config.browserTabs | Where-Object { $_.defaultSelected -eq $true } | ForEach-Object { $_.id })
    }
    if ($defaultBrowserTabs.Count -eq 0) {
        $defaultBrowserTabs = @("github", "teams", "discord")
    }

    $Script:SelectedSoftwareIds = Resolve-IdList -RawValue $SoftwareIds -DefaultIds $defaultSoftware
    $Script:SelectedLaunchAppIds = Resolve-IdList -RawValue $LaunchAppIds -DefaultIds $defaultLaunchApps
    $Script:SelectedBrowserTabIds = Resolve-IdList -RawValue $BrowserTabIds -DefaultIds $defaultBrowserTabs
}

function Test-SoftwareSelected {
    param([Parameter(Mandatory = $true)][string]$Id)
    return $Script:SelectedSoftwareIds -contains $Id.ToLowerInvariant()
}

function Test-LaunchSelected {
    param([Parameter(Mandatory = $true)][string]$Id)
    return $Script:SelectedLaunchAppIds -contains $Id.ToLowerInvariant()
}

function Test-NeedsElevation {
    $adminIds = @("7zip", "godot", "node", "git", "sourcetree", "unity", "steam")
    foreach ($id in $adminIds) {
        if (Test-SoftwareSelected -Id $id) {
            return $true
        }
    }
    return $false
}

function Restart-AsAdminIfNeeded {
    if ($DryRun) {
        Write-Log "DryRun mode: continuing without administrator rights."
        return
    }

    if (-not (Test-NeedsElevation)) {
        Write-Log "No administrator-only software selected. Skipping elevation."
        return
    }

    if (Test-IsAdmin) {
        Write-Log "Running with administrator rights."
        return
    }

    if ($NoElevate) {
        Write-Log "Not running as administrator. -NoElevate was specified, so elevation is skipped." "WARN"
        return
    }

    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "`"$PSCommandPath`""
    )
    if ($Force) { $arguments += "-Force" }
    if ($InstallRoot) {
        $arguments += "-InstallRoot"
        $arguments += "`"$InstallRoot`""
    }
    if (-not [string]::IsNullOrWhiteSpace($SoftwareIds)) {
        $arguments += "-SoftwareIds"
        $arguments += "`"$SoftwareIds`""
    }
    if (-not [string]::IsNullOrWhiteSpace($LaunchAppIds)) {
        $arguments += "-LaunchAppIds"
        $arguments += "`"$LaunchAppIds`""
    }
    if (-not [string]::IsNullOrWhiteSpace($BrowserTabIds)) {
        $arguments += "-BrowserTabIds"
        $arguments += "`"$BrowserTabIds`""
    }
    $arguments += "-ChatGPTMode"
    $arguments += $ChatGPTMode
    $arguments += "-SkipChromeTabs"
    $arguments += "-SkipAppLaunches"
    $arguments += "-DeferChatGPTInstall"

    Write-Log "Restarting as administrator."
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -Verb RunAs -PassThru
    # Wait for setup itself; an installer may leave a descendant process running.
    $process.WaitForExit()
    Write-Log "Administrator setup process exit code: $($process.ExitCode)"

    if ($process.ExitCode -eq 0) {
        Write-Log "Administrator setup completed. Continuing in the original user process."
        Complete-Setup
        Show-Summary
    }

    exit $process.ExitCode
}

function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-CommandVersion {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @("--version")
    )

    try {
        $output = & $Command @Arguments 2>&1
        return ($output | Select-Object -First 1 | Out-String).Trim()
    }
    catch {
        return $null
    }
}

function Get-FileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-ConfiguredSoftware {
    if (-not (Test-Path -LiteralPath $Script:ConfigPath)) {
        throw "Config file was not found: $Script:ConfigPath"
    }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Script:ConfigPath | ConvertFrom-Json
}

function Get-SoftwareItem {
    param([Parameter(Mandatory = $true)][string]$Id)
    $config = Get-ConfiguredSoftware
    $item = $config.software | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $item) {
        throw "software.json item was not found: $Id"
    }
    return $item
}

function Resolve-ResourceFile {
    param([Parameter(Mandatory = $true)][string]$FileName)
    return Join-Path $Script:ResourceDir $FileName
}

function Find-LocalInstaller {
    param([Parameter(Mandatory = $true)]$Item)

    $candidates = @()
    if ($Item.fileName) {
        $candidates += $Item.fileName
    }
    if ($Item.alternateFileNames) {
        $candidates += @($Item.alternateFileNames)
    }

    foreach ($fileName in $candidates) {
        $path = Resolve-ResourceFile -FileName $fileName
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    return $null
}

function Test-SoftwareItemInstalled {
    param([Parameter(Mandatory = $true)]$Item)

    switch ($Item.id) {
        "godot" {
            if ($Item.destinationRelativePath) {
                $configuredPath = Join-Path $InstallRoot $Item.destinationRelativePath
                if (Test-Path -LiteralPath $configuredPath) {
                    return $configuredPath
                }
            }
            return Test-AnyPath -Paths $Item.detectPaths
        }
        "node" {
            if ((Test-CommandExists -Name "node.exe") -and (Test-CommandExists -Name "npm.cmd")) {
                return "node.exe and npm.cmd"
            }
            return $null
        }
        "git" {
            $installed = Test-AnyPath -Paths $Item.detectPaths
            if ($installed) {
                return $installed
            }

            $gitCommand = Get-Command "git.exe" -ErrorAction SilentlyContinue
            if ($gitCommand) {
                return $gitCommand.Source
            }
            return $null
        }
        "vscode" {
            $installed = Test-AnyPath -Paths $Item.detectPaths
            if ($installed) {
                return $installed
            }

            $codeCommand = Get-Command "code.cmd" -ErrorAction SilentlyContinue
            if ($codeCommand) {
                return $codeCommand.Source
            }
            return $null
        }
        "codex" {
            if (Test-CommandExists -Name "codex.cmd") {
                return "codex.cmd"
            }
            if (Test-CommandExists -Name "codex") {
                return "codex"
            }
            return $null
        }
        default {
            return Test-AnyPath -Paths $Item.detectPaths
        }
    }
}

function Assert-RequiredFiles {
    $config = Get-ConfiguredSoftware
    foreach ($item in $config.software) {
        if (-not (Test-SoftwareSelected -Id $item.id)) {
            continue
        }

        $isRequired = $false
        if ($null -ne $item.resourceRequired) {
            $isRequired = [bool]$item.resourceRequired
        }
        elseif ($item.fileName) {
            $isRequired = $true
        }

        if (-not $isRequired -or -not $item.fileName) {
            continue
        }

        $installed = Test-SoftwareItemInstalled -Item $item
        if ($installed) {
            Write-Log "Required file check skipped for $($item.name); already installed: $installed"
            continue
        }

        $path = Resolve-ResourceFile -FileName $item.fileName
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Required file was not found: resource\$($item.fileName)"
        }

        $sha = Get-FileSha256 -Path $path
        Write-Log "Required file found: resource\$($item.fileName) SHA256=$sha"

        if ($item.expectedSha256 -and $item.expectedSha256.Trim().Length -gt 0) {
            if ($sha.ToUpperInvariant() -ne $item.expectedSha256.ToUpperInvariant()) {
                throw "SHA256 mismatch: resource\$($item.fileName)"
            }
            Write-Log "SHA256 verified: resource\$($item.fileName)"
        }
    }
}

function Invoke-ExternalProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [int[]]$SuccessExitCodes = @(0)
    )

    Write-Log "Executable: $FilePath"
    Write-Log "Arguments: $($ArgumentList -join ' ')"

    if ($DryRun) {
        Write-Log "DryRun: Start-Process will not be called." "DRYRUN"
        return 0
    }

    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru
    Write-Log "Exit code: $($process.ExitCode)"

    if ($SuccessExitCodes -notcontains $process.ExitCode) {
        throw "External process failed: $FilePath ExitCode=$($process.ExitCode)"
    }

    if ($process.ExitCode -eq 3010) {
        Write-Log "Success with reboot required." "WARN"
    }

    return $process.ExitCode
}

function Test-AnyPath {
    param([string[]]$Paths)
    if (-not $Paths) {
        return $null
    }
    foreach ($path in $Paths) {
        $expanded = [Environment]::ExpandEnvironmentVariables($path)
        if (Test-Path -LiteralPath $expanded) {
            return $expanded
        }
    }
    return $null
}

function Get-GoogleChromePath {
    $chromeCommand = Get-Command "chrome.exe" -ErrorAction SilentlyContinue
    if ($chromeCommand) {
        return $chromeCommand.Source
    }

    $chromePaths = @(
        "%ProgramFiles%\Google\Chrome\Application\chrome.exe",
        "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe",
        "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
    )

    return Test-AnyPath -Paths $chromePaths
}

function Get-GodotPath {
    $item = Get-SoftwareItem -Id "godot"
    $configuredPath = Join-Path $InstallRoot $item.destinationRelativePath
    if (Test-Path -LiteralPath $configuredPath) {
        return $configuredPath
    }

    return Test-AnyPath -Paths $item.detectPaths
}

function Get-SourcetreePath {
    $item = Get-SoftwareItem -Id "sourcetree"
    return Test-AnyPath -Paths $item.detectPaths
}

function Get-VSCodePath {
    $item = Get-SoftwareItem -Id "vscode"
    $installed = Test-AnyPath -Paths $item.detectPaths
    if ($installed) {
        return $installed
    }

    $codeCommand = Get-Command "code.cmd" -ErrorAction SilentlyContinue
    if ($codeCommand) {
        return $codeCommand.Source
    }

    return $null
}

function Get-AntigravityPath {
    $item = Get-SoftwareItem -Id "antigravity"
    return Test-AnyPath -Paths $item.detectPaths
}

function Get-UnityHubPath {
    $item = Get-SoftwareItem -Id "unity"
    return Test-AnyPath -Paths $item.detectPaths
}

function Get-SteamPath {
    $item = Get-SoftwareItem -Id "steam"
    return Test-AnyPath -Paths $item.detectPaths
}

function Install-7Zip {
    $name = "7-Zip"
    $item = Get-SoftwareItem -Id "7zip"
    $installed = Test-AnyPath -Paths $item.detectPaths

    if ($installed) {
        Write-Log "$name is already installed. Skipping: $installed"
        Add-Result $name "Skipped" "Installed: $installed"
        return
    }

    $installer = Resolve-ResourceFile -FileName $item.fileName
    if ($DryRun) {
        Write-Log "DryRun: 7-Zip installer will not be called: $installer" "DRYRUN"
        Add-Result $name "DryRun" "Would install from $installer"
        return
    }

    Invoke-ExternalProcess -FilePath $installer -ArgumentList @("/S")
    Add-Result $name "Installed" "Installer executed"
}

function Install-Godot {
    $name = "Godot"
    $item = Get-SoftwareItem -Id "godot"
    $source = Resolve-ResourceFile -FileName $item.fileName
    $relative = $item.destinationRelativePath
    $destination = Join-Path $InstallRoot $relative

    if (Test-Path -LiteralPath $destination) {
        Write-Log "$name is already placed. Skipping: $destination"
        Add-Result $name "Skipped" "Exists: $destination"
        return
    }

    Write-Log "Godot source: $source"
    Write-Log "Godot destination: $destination"

    if ($DryRun) {
        Write-Log "DryRun: Godot copy will not be performed." "DRYRUN"
        Add-Result $name "DryRun" "Would copy to $destination"
        return
    }

    $destinationDir = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
    Add-Result $name "Installed" "Copied to $destination"
}

function Install-Node {
    $name = "Node.js"
    $item = Get-SoftwareItem -Id "node"
    $nodeExists = Test-CommandExists -Name "node.exe"
    $npmExists = Test-CommandExists -Name "npm.cmd"

    if ($nodeExists -and $npmExists) {
        $nodeVersion = Get-CommandVersion -Command "node.exe" -Arguments @("-v")
        $npmVersion = Get-CommandVersion -Command "npm.cmd" -Arguments @("-v")
        Write-Log "$name is already installed. Skipping: node=$nodeVersion npm=$npmVersion"
        if ($nodeVersion -and ($nodeVersion -notmatch "^v24\.")) {
            Write-Log "Node.js is not v24.x. Existing Node.js will not be removed or replaced." "WARN"
        }
        Add-Result $name "Skipped" "node=$nodeVersion npm=$npmVersion"
        return
    }

    $msi = Resolve-ResourceFile -FileName $item.fileName
    $nodeLog = Join-Path $Script:LogDir "node-install.log"
    if ($DryRun) {
        Write-Log "DryRun: Node.js MSI will not be called: $msi" "DRYRUN"
        Add-Result $name "DryRun" "Would install from $msi"
        return
    }

    Invoke-ExternalProcess -FilePath "msiexec.exe" -ArgumentList @(
        "/i",
        "`"$msi`"",
        "/qn",
        "/norestart",
        "/L*v",
        "`"$nodeLog`""
    ) -SuccessExitCodes @(0, 3010)

    $env:Path = "C:\Program Files\nodejs;$env:APPDATA\npm;$env:Path"
    Write-Log "Node.js PATH candidates were added to the current session."
    Write-Log "node version: $(Get-CommandVersion -Command 'node.exe' -Arguments @('-v'))"
    Write-Log "npm version: $(Get-CommandVersion -Command 'npm.cmd' -Arguments @('-v'))"
    Add-Result $name "Installed" "MSI executed"
}

function Start-GitInstallJob {
    $name = "Git for Windows"
    $item = Get-SoftwareItem -Id "git"
    $installer = Resolve-ResourceFile -FileName $item.fileName
    $gitLog = Join-Path $Script:LogDir "git-install.log"

    Write-Log "Starting $name install in a separate background job."

    $job = Start-Job -Name "Install-GitForWindows" -ArgumentList @(
        $name,
        $installer,
        [string[]]$item.detectPaths,
        $gitLog,
        $Script:MainLog,
        [bool]$DryRun
    ) -ScriptBlock {
        param(
            [string]$Name,
            [string]$Installer,
            [string[]]$DetectPaths,
            [string]$GitLog,
            [string]$MainLog,
            [bool]$DryRunMode
        )

        function Write-JobLog {
            param(
                [Parameter(Mandatory = $true)][string]$Message,
                [ValidateSet("INFO", "WARN", "ERROR", "DRYRUN")][string]$Level = "INFO"
            )
            $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
            Add-Content -LiteralPath $MainLog -Value $line -Encoding UTF8
            Write-Output $line
        }

        function Test-AnyJobPath {
            param([string[]]$Paths)
            foreach ($path in $Paths) {
                $expanded = [Environment]::ExpandEnvironmentVariables($path)
                if (Test-Path -LiteralPath $expanded) {
                    return $expanded
                }
            }
            return $null
        }

        try {
            $installed = Test-AnyJobPath -Paths $DetectPaths
            if (-not $installed) {
                $gitCommand = Get-Command "git.exe" -ErrorAction SilentlyContinue
                if ($gitCommand) {
                    $installed = $gitCommand.Source
                }
            }

            if ($installed) {
                Write-JobLog "$Name is already installed. Skipping: $installed"
                return [pscustomobject]@{ Name = $Name; Status = "Skipped"; Message = "Installed: $installed" }
            }

            if (-not (Test-Path -LiteralPath $Installer)) {
                throw "Git installer was not found: $Installer"
            }

            $arguments = @(
                "/VERYSILENT",
                "/NORESTART",
                "/NOCANCEL",
                "/SP-",
                "/LOG=`"$GitLog`""
            )
            Write-JobLog "Executable: $Installer"
            Write-JobLog "Arguments: $($arguments -join ' ')"

            if ($DryRunMode) {
                Write-JobLog "DryRun: Git installer will not be called." "DRYRUN"
                return [pscustomobject]@{ Name = $Name; Status = "DryRun"; Message = "Would install from $Installer" }
            }

            $process = Start-Process -FilePath $Installer -ArgumentList $arguments -Wait -PassThru
            Write-JobLog "Exit code: $($process.ExitCode)"
            if (@(0, 3010) -notcontains $process.ExitCode) {
                throw "Git installer failed: ExitCode=$($process.ExitCode)"
            }

            if ($process.ExitCode -eq 3010) {
                Write-JobLog "Success with reboot required." "WARN"
            }

            return [pscustomobject]@{ Name = $Name; Status = "Installed"; Message = "Installer executed" }
        }
        catch {
            Write-JobLog "Error: $($_.Exception.Message)" "ERROR"
            return [pscustomobject]@{ Name = $Name; Status = "Failed"; Message = $_.Exception.Message }
        }
    }

    return $job
}

function Wait-GitInstallJob {
    param([System.Management.Automation.Job]$Job)

    if (-not $Job) {
        return
    }

    Write-Log "Waiting for Git for Windows background install job."
    $jobOutput = Wait-Job -Job $Job | Receive-Job
    Remove-Job -Job $Job -Force

    $result = $jobOutput | Where-Object { $_.PSObject.Properties.Name -contains "Status" } | Select-Object -Last 1
    if (-not $result) {
        throw "Git for Windows background job did not return a result."
    }

    Add-Result $result.Name $result.Status $result.Message

    if ($result.Status -eq "Failed") {
        throw "Git for Windows install failed: $($result.Message)"
    }

    if ($result.Status -ne "DryRun") {
        $env:Path = "C:\Program Files\Git\cmd;C:\Program Files\Git\bin;$env:Path"
        Write-Log "Git PATH candidates were added to the current session."
        if (Test-CommandExists -Name "git.exe") {
            Write-Log "git version: $(Get-CommandVersion -Command 'git.exe' -Arguments @('--version'))"
        }
        else {
            Write-Log "git.exe is not available in the current session yet." "WARN"
        }
    }
}

function Install-SourcetreeEnterprise {
    $name = "Sourcetree Enterprise"
    $item = Get-SoftwareItem -Id "sourcetree"
    if ($item.fileName -notmatch '^SourcetreeEnterpriseSetup_\d+\.\d+\.\d+\.msi$') {
        throw "Sourcetree Enterprise must use a versioned SourcetreeEnterpriseSetup MSI."
    }

    $installed = Test-AnyPath -Paths $item.detectPaths

    if ($installed) {
        Write-Log "$name is already installed. Skipping: $installed"
        Add-Result $name "Skipped" "Installed: $installed"
        return
    }

    $msi = Resolve-ResourceFile -FileName $item.fileName
    $sourcetreeLog = Join-Path $Script:LogDir "sourcetree-install.log"
    if ($DryRun) {
        Write-Log "DryRun: Sourcetree Enterprise MSI will not be called: $msi" "DRYRUN"
        Add-Result $name "DryRun" "Would install from $msi with ACCEPTEULA=1"
        return
    }

    Invoke-ExternalProcess -FilePath "msiexec.exe" -ArgumentList @(
        "/i",
        "`"$msi`"",
        "ACCEPTEULA=1",
        "/qn",
        "/norestart",
        "/L*v",
        "`"$sourcetreeLog`""
    ) -SuccessExitCodes @(0, 3010)
    Add-Result $name "Installed" "MSI executed with ACCEPTEULA=1"
}

function Install-VSCode {
    $name = "Visual Studio Code"
    $item = Get-SoftwareItem -Id "vscode"
    $installed = Test-AnyPath -Paths $item.detectPaths

    if (-not $installed -and (Test-CommandExists -Name "code.cmd")) {
        $installed = "code.cmd"
    }

    if ($installed) {
        Write-Log "$name is already installed. Skipping: $installed"
        Add-Result $name "Skipped" "Installed: $installed"
        return
    }

    $installer = Resolve-ResourceFile -FileName $item.fileName
    $vscodeLog = Join-Path $Script:LogDir "vscode-install.log"
    if ($DryRun) {
        Write-Log "DryRun: Visual Studio Code installer will not be called: $installer" "DRYRUN"
        Add-Result $name "DryRun" "Would install from $installer"
        return
    }

    Invoke-ExternalProcess -FilePath $installer -ArgumentList @(
        "/VERYSILENT",
        "/NORESTART",
        "/MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,addtopath",
        "/LOG=`"$vscodeLog`""
    )
    Add-Result $name "Installed" "Installer executed"
}

function Install-WingetOrLocalApp {
    param(
        [Parameter(Mandatory = $true)][string]$Id
    )

    $item = Get-SoftwareItem -Id $Id
    $name = $item.name
    $installed = Test-AnyPath -Paths $item.detectPaths

    if ($installed) {
        Write-Log "$name is already installed. Skipping: $installed"
        Add-Result $name "Skipped" "Installed: $installed"
        return
    }

    $localInstaller = Find-LocalInstaller -Item $item
    if ($localInstaller) {
        $silentArgs = @("/S")
        if ($item.silentArgs -and $item.silentArgs.Count -gt 0) {
            $silentArgs = @($item.silentArgs)
        }

        if ($DryRun) {
            Write-Log "DryRun: $name local installer will not be called: $localInstaller ($($silentArgs -join ' '))" "DRYRUN"
            Add-Result $name "DryRun" "Would install from local file $localInstaller"
            return
        }

        Invoke-ExternalProcess -FilePath $localInstaller -ArgumentList $silentArgs -SuccessExitCodes @(0, 3010)
        Add-Result $name "Installed" "Installed from local file $localInstaller"
        return
    }

    if (-not $item.wingetId) {
        throw "$name installer was not found in resource\ and no wingetId is configured."
    }

    $arguments = @(
        "install", "--id", $item.wingetId, "--exact",
        "--accept-package-agreements", "--accept-source-agreements",
        "--silent", "--disable-interactivity"
    )
    if ($DryRun) {
        Write-Log "DryRun: winget.exe $($arguments -join ' ')" "DRYRUN"
        Add-Result $name "DryRun" "Would download and install via winget ($($item.wingetId))"
        return
    }

    $winget = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "$name requires winget.exe (or a local installer in resource\). Install App Installer from Microsoft Store or download from $($item.downloadUrl)."
    }

    try {
        Invoke-ExternalProcess -FilePath $winget.Source -ArgumentList $arguments -SuccessExitCodes @(0, 3010) | Out-Null
    }
    catch {
        throw "$name installation via winget failed. You can also download manually from $($item.downloadUrl). $($_.Exception.Message)"
    }

    Add-Result $name "Installed" "Installed via winget ($($item.wingetId))"
}

function Set-UserExecutionPolicy {
    $name = "PowerShell ExecutionPolicy"
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser

    if ($currentPolicy -eq "RemoteSigned") {
        Write-Log "ExecutionPolicy is already configured. Skipping: $currentPolicy"
        Add-Result $name "Skipped" "CurrentUser=$currentPolicy"
        return
    }

    Write-Log "Setting ExecutionPolicy CurrentUser to RemoteSigned. Current value: $currentPolicy"
    if ($DryRun) {
        Write-Log "DryRun: Set-ExecutionPolicy will not be called." "DRYRUN"
        Add-Result $name "DryRun" "Would set RemoteSigned"
        return
    }

    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        $newPolicy = Get-ExecutionPolicy -Scope CurrentUser
        Write-Log "ExecutionPolicy after change: $newPolicy"
        Add-Result $name "Configured" "CurrentUser=$newPolicy"
    }
    catch {
        $newPolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($newPolicy -eq "RemoteSigned") {
            Write-Log "ExecutionPolicy was updated to RemoteSigned, but the effective policy is overridden by a higher-precedence scope. Continuing." "WARN"
            Add-Result $name "Configured" "CurrentUser=$newPolicy; effective policy overridden"
            return
        }

        Write-Log "ExecutionPolicy could not be changed. Continuing because this setup was launched with -ExecutionPolicy Bypass." "WARN"
        Write-Log "ExecutionPolicy error: $($_.Exception.Message)" "WARN"
        Add-Result $name "Skipped" "ExecutionPolicy change blocked"
    }
}

function Install-CodexCli {
    $name = "OpenAI Codex CLI"

    if ((Test-CommandExists -Name "codex.cmd") -or (Test-CommandExists -Name "codex")) {
        $version = Get-CommandVersion -Command "codex" -Arguments @("--version")
        Write-Log "$name is already installed. Skipping: $version"
        Add-Result $name "Skipped" $version
        return
    }

    $env:Path = "C:\Program Files\nodejs;$env:APPDATA\npm;$env:Path"

    $nodeAvailable = Test-CommandExists -Name "node.exe"
    $npmAvailable = Test-CommandExists -Name "npm.cmd"

    if ($DryRun -and (-not $nodeAvailable -or -not $npmAvailable)) {
        Write-Log "DryRun: node.exe or npm.cmd is not currently available. Planned Codex npm command will still be shown." "WARN"
    }
    elseif (-not $nodeAvailable) {
        throw "Codex CLI precheck failed: node.exe was not found."
    }
    elseif (-not $npmAvailable) {
        throw "Codex CLI precheck failed: npm.cmd was not found."
    }

    $codexLog = Join-Path $Script:LogDir "codex-install.log"
    $installCommand = 'npm i -g @openai/codex@latest 1>> "' + $codexLog + '" 2>>&1'
    if ($DryRun) {
        Write-Log "DryRun: Codex CLI npm install will not be called." "DRYRUN"
        Write-Log "DryRun command: $installCommand" "DRYRUN"
        Add-Result $name "DryRun" "Would run npm i -g @openai/codex@latest"
        return
    }

    try {
        Invoke-ExternalProcess -FilePath "cmd.exe" -ArgumentList @("/c", $installCommand)
    }
    catch {
        Write-Log "Codex CLI install failed. Retrying once with optional dependencies." "WARN"
        $retryCommand = 'npm i -g @openai/codex@latest --include=optional 1>> "' + $codexLog + '" 2>>&1'
        Invoke-ExternalProcess -FilePath "cmd.exe" -ArgumentList @("/c", $retryCommand)
    }

    $versionCommand = 'codex --version 1>> "' + $codexLog + '" 2>>&1'
    Invoke-ExternalProcess -FilePath "cmd.exe" -ArgumentList @("/c", $versionCommand)
    $version = Get-CommandVersion -Command "codex" -Arguments @("--version")
    Write-Log "codex version: $version"
    Add-Result $name "Installed" $version
}

function Get-ChatGPTPackage {
    $item = Get-SoftwareItem -Id "chatgpt"
    return Get-AppxPackage -Name $item.packageName -ErrorAction Stop | Select-Object -First 1
}

function Install-ChatGPTDesktop {
    $item = Get-SoftwareItem -Id "chatgpt"
    $name = "ChatGPT Desktop"
    $installed = Get-ChatGPTPackage
    if ($installed) {
        Write-Log "$name is already installed. Skipping: $($installed.PackageFullName)"
        Add-Result $name "Skipped" $installed.PackageFullName
        return
    }

    $arguments = @(
        "install", "--id", $item.storeId, "--exact", "--source", "msstore",
        "--accept-package-agreements", "--accept-source-agreements", "--silent",
        "--disable-interactivity"
    )
    if ($DryRun) {
        Write-Log "DryRun: winget.exe $($arguments -join ' ')" "DRYRUN"
        Add-Result $name "DryRun" "Would download and install from Microsoft Store"
        return
    }

    $winget = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "ChatGPT Desktop requires winget.exe. Install or update App Installer from Microsoft Store, then run setup again."
    }

    try {
        Invoke-ExternalProcess -FilePath $winget.Source -ArgumentList $arguments | Out-Null
    }
    catch {
        throw "ChatGPT Desktop installation failed. Check your network, Microsoft Store access, and winget diagnostic logs. $($_.Exception.Message)"
    }
    if (-not (Get-ChatGPTPackage)) {
        throw "ChatGPT Desktop was not registered for the current user after winget completed. Check Microsoft Store and run setup again."
    }
    Add-Result $name "Installed" "Downloaded and installed from Microsoft Store"
}

function Open-ChatGPTDesktop {
    $name = "ChatGPT Desktop launch"
    if ($DryRun) {
        Write-Log "DryRun: ChatGPT Desktop will be opened after installation." "DRYRUN"
        Add-Result $name "DryRun" "Would open ChatGPT Desktop"
        return
    }

    $package = Get-ChatGPTPackage
    if (-not $package) {
        throw "ChatGPT Desktop launch failed: app is not installed for the current user."
    }
    $manifest = Get-AppxPackageManifest -Package $package.PackageFullName -ErrorAction Stop
    $application = $manifest.Package.Applications.Application | Select-Object -First 1
    if (-not $application.Id) {
        throw "ChatGPT Desktop launch failed: application ID was not found in the package manifest."
    }
    $target = "shell:AppsFolder\$($package.PackageFamilyName)!$($application.Id)"
    Write-Log "ChatGPT Desktop launch target: $target"
    Start-Process -FilePath "$env:WINDIR\explorer.exe" -ArgumentList $target -WindowStyle Normal
    Add-Result $name "LaunchRequested" $target
}

function Start-DesktopApplication {
    param([string]$FilePath, [string]$Arguments)

    $workingDirectory = Split-Path -Parent $FilePath
    if (Test-IsAdmin) {
        try {
            $shell = New-Object -ComObject Shell.Application
            $shell.ShellExecute($FilePath, $Arguments, $workingDirectory, "open", 1)
            return
        }
        catch {
            Write-Log "Windows Shell launch failed for ${FilePath}: $($_.Exception.Message). Trying Start-Process." "WARN"
        }
    }

    $options = @{
        FilePath = $FilePath
        WorkingDirectory = $workingDirectory
        WindowStyle = "Normal"
    }
    if ($Arguments) { $options.ArgumentList = $Arguments }
    Start-Process @options
}

function Invoke-SetupStep {
    param([string]$Name, [scriptblock]$Action)

    try {
        & $Action
    }
    catch {
        $message = $_.Exception.Message
        Write-Log "${Name}: $message" "ERROR"
        Add-Result $Name "Failed" $message
    }
}

function Open-InstalledApps {
    $allTargets = @(
        [pscustomobject]@{ Id = "godot"; Name = "Godot"; Path = Get-GodotPath },
        [pscustomobject]@{ Id = "sourcetree"; Name = "Sourcetree Enterprise"; Path = Get-SourcetreePath },
        [pscustomobject]@{ Id = "vscode"; Name = "Visual Studio Code"; Path = Get-VSCodePath },
        [pscustomobject]@{ Id = "antigravity"; Name = "Google Antigravity"; Path = Get-AntigravityPath },
        [pscustomobject]@{ Id = "unity"; Name = "Unity Hub"; Path = Get-UnityHubPath },
        [pscustomobject]@{ Id = "steam"; Name = "Steam"; Path = Get-SteamPath }
    )

    foreach ($target in $allTargets) {
        if (-not (Test-LaunchSelected -Id $target.Id)) {
            continue
        }

        $resultName = "$($target.Name) launch"

        if (-not $target.Path) {
            Write-Log "$($target.Name) executable was not found. App was not opened." "WARN"
            Add-Result $resultName "Skipped" "Executable not found"
            continue
        }

        Write-Log "$($target.Name) executable: $($target.Path)"

        if ($DryRun) {
            Write-Log "DryRun: $($target.Name) will not be opened." "DRYRUN"
            Add-Result $resultName "DryRun" "Would open $($target.Path)"
            continue
        }

        Invoke-SetupStep $resultName {
            Start-DesktopApplication -FilePath $target.Path
            Add-Result $resultName "LaunchRequested" $target.Path
        }
    }
}

function Open-ChromeTabs {
    $name = "Google Chrome tabs"
    $config = Get-ConfiguredSoftware
    $urls = New-Object System.Collections.Generic.List[string]

    if ($config.browserTabs) {
        foreach ($tab in $config.browserTabs) {
            if ($Script:SelectedBrowserTabIds -contains $tab.id.ToLowerInvariant()) {
                $urls.Add($tab.url) | Out-Null
            }
        }
    }
    else {
        foreach ($fallbackUrl in @(
            "https://github.co.jp/",
            "https://www.microsoft.com/ja-jp/microsoft-teams/log-in",
            "https://discord.com/"
        )) {
            $urls.Add($fallbackUrl) | Out-Null
        }
    }

    if ((Test-SoftwareSelected -Id "chatgpt") -and ($ChatGPTMode -eq "Web")) {
        $chatgptItem = Get-SoftwareItem -Id "chatgpt"
        $webUrl = if ($chatgptItem.webUrl) { $chatgptItem.webUrl } else { "https://chatgpt.com/" }
        if (-not $urls.Contains($webUrl)) {
            $urls.Add($webUrl) | Out-Null
        }
    }

    if ($urls.Count -eq 0) {
        Write-Log "No browser tabs selected. Skipping browser launch."
        Add-Result $name "Skipped" "No browser tabs selected"
        return
    }

    $chromePath = Get-GoogleChromePath
    Write-Log "Browser URLs: $($urls -join ', ')"

    if (-not $chromePath) {
        if ((Test-SoftwareSelected -Id "chatgpt") -and ($ChatGPTMode -eq "Web")) {
            Write-Log "Google Chrome was not found. Opening URLs with the default browser." "WARN"
            if ($DryRun) {
                Write-Log "DryRun: Default browser URLs will not be opened." "DRYRUN"
                Add-Result $name "DryRun" "Would open $($urls.Count) URLs in default browser"
                return
            }
            foreach ($u in $urls) {
                Start-Process $u
            }
            Add-Result $name "LaunchRequested" "$($urls.Count) URLs in default browser"
            return
        }

        Write-Log "Google Chrome was not found. Browser tabs were not opened." "WARN"
        Add-Result $name "Skipped" "Chrome not found"
        return
    }

    Write-Log "Google Chrome path: $chromePath"
    $chromeArguments = @("--new-window", "--start-maximized") + @($urls)
    $chromeArgumentString = $chromeArguments -join " "
    Write-Log "Chrome arguments: $chromeArgumentString"

    if ($DryRun) {
        Write-Log "DryRun: Chrome tabs will not be opened." "DRYRUN"
        Add-Result $name "DryRun" "Would open $($urls.Count) tabs in a new Chrome window"
        return
    }

    Start-DesktopApplication -FilePath $chromePath -Arguments $chromeArgumentString
    Add-Result $name "LaunchRequested" "$($urls.Count) tabs in a new Chrome window"
}

function Complete-Setup {
    Write-Log "Finishing setup in session $([Diagnostics.Process]::GetCurrentProcess().SessionId), interactive: $([Environment]::UserInteractive), administrator: $(Test-IsAdmin). SkipAppLaunches: $SkipAppLaunches SkipChromeTabs: $SkipChromeTabs ChatGPTMode: $ChatGPTMode"

    if ($DeferChatGPTInstall) {
        if ((Test-SoftwareSelected -Id "chatgpt") -and ($ChatGPTMode -eq "Desktop")) {
            Write-Log "ChatGPT Desktop installation is deferred to the original user process."
            Add-Result "ChatGPT Desktop" "Deferred" "Original user process will install the app"
        }
        if (Test-SoftwareSelected -Id "antigravity") {
            Write-Log "Google Antigravity installation is deferred to the original user process."
            Add-Result "Google Antigravity (x64/Win)" "Deferred" "Original user process will install the app"
        }
    }
    else {
        if (Test-SoftwareSelected -Id "antigravity") {
            Invoke-SetupStep "Google Antigravity installation" { Install-WingetOrLocalApp -Id "antigravity" }
        }

        if (Test-SoftwareSelected -Id "chatgpt") {
            if ($ChatGPTMode -eq "Desktop") {
                Invoke-SetupStep "ChatGPT Desktop installation" { Install-ChatGPTDesktop }
            }
            elseif ($ChatGPTMode -eq "Web") {
                Write-Log "ChatGPT Web mode selected. Desktop app installation skipped; Web version will be opened in browser."
                Add-Result "ChatGPT" "Skipped" "Web mode selected (https://chatgpt.com/)"
            }
            else {
                Write-Log "ChatGPTMode is None. Skipping ChatGPT."
                Add-Result "ChatGPT" "Skipped" "Mode=None"
            }
        }
    }

    if (-not $SkipAppLaunches) {
        Invoke-SetupStep "Installed apps launch" { Open-InstalledApps }
        if ((Test-SoftwareSelected -Id "chatgpt") -and ($ChatGPTMode -eq "Desktop") -and (Test-LaunchSelected -Id "chatgpt")) {
            if (-not ($Script:Results | Where-Object { $_.Name -eq "ChatGPT Desktop installation" -and $_.Status -eq "Failed" })) {
                Invoke-SetupStep "ChatGPT Desktop launch" { Open-ChatGPTDesktop }
            }
        }
    }

    if (-not $SkipChromeTabs) {
        Invoke-SetupStep "Google Chrome tabs" { Open-ChromeTabs }
    }

    if ($Script:Results.Status -contains "Failed") {
        throw "One or more setup or launch steps failed. See the individual errors in install.log."
    }
}

function Show-Summary {
    Write-Log "Setup results:"
    foreach ($result in $Script:Results) {
        Write-Log ("- {0}: {1} ({2})" -f $result.Name, $result.Status, $result.Message)
    }
}

function Initialize-Log {
    New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null
    "==== install_all.ps1 start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====" | Set-Content -LiteralPath $Script:MainLog -Encoding UTF8
    try {
        $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption
    }
    catch {
        $osInfo = [Environment]::OSVersion.VersionString
    }

    Write-Log "User: $([Environment]::UserName)"
    Write-Log "Administrator: $(Test-IsAdmin)"
    Write-Log "Base directory: $Script:BaseDir"
    Write-Log "Resource directory: $Script:ResourceDir"
    Write-Log "OS: $osInfo"
    Write-Log "PowerShell: $($PSVersionTable.PSVersion)"
    Write-Log "DryRun: $DryRun Force: $Force NoElevate: $NoElevate SkipChromeTabs: $SkipChromeTabs SkipAppLaunches: $SkipAppLaunches InstallRoot: $InstallRoot"
    Write-Log "SelectedSoftware: $($Script:SelectedSoftwareIds -join ', ')"
    Write-Log "SelectedLaunchApps: $($Script:SelectedLaunchAppIds -join ', ')"
    Write-Log "SelectedBrowserTabs: $($Script:SelectedBrowserTabIds -join ', ')"
    Write-Log "ChatGPTMode: $ChatGPTMode"
    if ($Force) {
        Write-Log "-Force was specified. Existing software is still skipped when detected."
    }
}

try {
    Set-Location -LiteralPath $Script:BaseDir
    Initialize-Selections
    Initialize-Log
    Restart-AsAdminIfNeeded
    Assert-RequiredFiles

    if (Test-SoftwareSelected -Id "git") {
        $Script:GitInstallJob = Start-GitInstallJob
    }
    if (Test-SoftwareSelected -Id "7zip") {
        Install-7Zip
    }
    if (Test-SoftwareSelected -Id "godot") {
        Install-Godot
    }
    if (Test-SoftwareSelected -Id "node") {
        Install-Node
    }
    if (Test-SoftwareSelected -Id "codex") {
        Install-CodexCli
    }
    if ((Test-SoftwareSelected -Id "node") -or (Test-SoftwareSelected -Id "codex")) {
        Set-UserExecutionPolicy
    }
    if ($Script:GitInstallJob) {
        Wait-GitInstallJob -Job $Script:GitInstallJob
        $Script:GitInstallJob = $null
    }
    if (Test-SoftwareSelected -Id "sourcetree") {
        Install-SourcetreeEnterprise
    }
    if (Test-SoftwareSelected -Id "vscode") {
        Install-VSCode
    }
    if (Test-SoftwareSelected -Id "unity") {
        Install-WingetOrLocalApp -Id "unity"
    }
    if (Test-SoftwareSelected -Id "steam") {
        Install-WingetOrLocalApp -Id "steam"
    }

    Complete-Setup
    Show-Summary
    Write-Log "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    exit 0
}
catch {
    if ($Script:GitInstallJob -and $Script:GitInstallJob.State -in @("Running", "NotStarted")) {
        Write-Log "Waiting for Git for Windows background install job before exiting after an error." "WARN"
        try {
            Wait-GitInstallJob -Job $Script:GitInstallJob
            $Script:GitInstallJob = $null
        }
        catch {
            Write-Log "Git background install also failed: $($_.Exception.Message)" "ERROR"
        }
    }
    Write-Log "Error: $($_.Exception.Message)" "ERROR"
    Write-Log "Details: $($_ | Out-String)" "ERROR"
    Show-Summary
    exit 1
}
