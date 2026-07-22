param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$NoElevate,
    [switch]$SkipChromeTabs,
    [switch]$SkipAppLaunches,
    [string]$InstallRoot = "C:\Tools"
)

$ErrorActionPreference = "Stop"

$Script:BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:ResourceDir = Join-Path $Script:BaseDir "resource"
$Script:ConfigPath = Join-Path $Script:BaseDir "config\software.json"
$Script:LogDir = Join-Path $Script:BaseDir "logs"
$Script:MainLog = Join-Path $Script:LogDir "install.log"
$Script:Results = New-Object System.Collections.Generic.List[object]
$Script:GitInstallJob = $null

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

function Restart-AsAdminIfNeeded {
    if ($DryRun) {
        Write-Log "DryRun mode: continuing without administrator rights."
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
    $arguments += "-SkipChromeTabs"
    $arguments += "-SkipAppLaunches"

    Write-Log "Restarting as administrator."
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -Verb RunAs -Wait -PassThru
    Write-Log "Administrator setup process exit code: $($process.ExitCode)"

    if ($process.ExitCode -eq 0) {
        Write-Log "Administrator setup completed. Opening apps and Chrome tabs from the original user process."
        Open-InstalledApps
        Open-ChromeTabs
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
        if (-not $item.fileName) {
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
    if ($item.fileName -ne "SourcetreeEnterpriseSetup_3.4.30.msi") {
        throw "Sourcetree Enterprise must use SourcetreeEnterpriseSetup_3.4.30.msi."
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
    $installCommand = 'npm i -g @openai/codex 1>> "' + $codexLog + '" 2>>&1'
    if ($DryRun) {
        Write-Log "DryRun: Codex CLI npm install will not be called." "DRYRUN"
        Write-Log "DryRun command: $installCommand" "DRYRUN"
        Add-Result $name "DryRun" "Would run npm i -g @openai/codex"
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

function Open-InstalledApps {
    $targets = @(
        [pscustomobject]@{ Name = "Godot"; Path = Get-GodotPath },
        [pscustomobject]@{ Name = "Sourcetree Enterprise"; Path = Get-SourcetreePath },
        [pscustomobject]@{ Name = "Visual Studio Code"; Path = Get-VSCodePath }
    )

    foreach ($target in $targets) {
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

        try {
            $workingDirectory = Split-Path -Parent $target.Path
            $shell = New-Object -ComObject Shell.Application
            $shell.ShellExecute($target.Path, "", $workingDirectory, "open", 1)
            Write-Log "$($target.Name) was launched through Windows Shell."
            Add-Result $resultName "Opened" $target.Path
        }
        catch {
            Write-Log "Shell launch failed for $($target.Name). Falling back to Start-Process: $($_.Exception.Message)" "WARN"
            Start-Process -FilePath $target.Path -WorkingDirectory (Split-Path -Parent $target.Path) -WindowStyle Normal
            Add-Result $resultName "Opened" $target.Path
        }
    }
}

function Open-ChromeTabs {
    $name = "Google Chrome tabs"
    $urls = @(
        "https://chatgpt.com/ja-JP/",
        "https://github.co.jp/",
        "https://www.microsoft.com/ja-jp/microsoft-teams/log-in",
        "https://discord.com/"
    )

    $chromePath = Get-GoogleChromePath
    Write-Log "Chrome URLs: $($urls -join ', ')"

    if (-not $chromePath) {
        Write-Log "Google Chrome was not found. Browser tabs were not opened." "WARN"
        Add-Result $name "Skipped" "Chrome not found"
        return
    }

    Write-Log "Google Chrome path: $chromePath"
    $chromeArguments = @("--new-window") + $urls
    $chromeArgumentString = $chromeArguments -join " "
    Write-Log "Chrome arguments: $chromeArgumentString"

    if ($DryRun) {
        Write-Log "DryRun: Chrome tabs will not be opened." "DRYRUN"
        Add-Result $name "DryRun" "Would open $($urls.Count) tabs in a new Chrome window"
        return
    }

    try {
        $shell = New-Object -ComObject Shell.Application
        $shell.ShellExecute($chromePath, $chromeArgumentString, (Split-Path -Parent $chromePath), "open", 1)
        Write-Log "Chrome was launched through Windows Shell."
    }
    catch {
        Write-Log "Shell launch failed. Falling back to Start-Process: $($_.Exception.Message)" "WARN"
        Start-Process -FilePath $chromePath -ArgumentList $chromeArgumentString -WindowStyle Normal
    }
    Add-Result $name "Opened" "$($urls.Count) tabs in a new Chrome window"
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
    if ($Force) {
        Write-Log "-Force was specified. Existing software is still skipped when detected."
    }
}

try {
    Set-Location -LiteralPath $Script:BaseDir
    Initialize-Log
    Restart-AsAdminIfNeeded
    Assert-RequiredFiles
    $Script:GitInstallJob = Start-GitInstallJob
    Install-7Zip
    Install-Godot
    Install-Node
    Install-CodexCli
    Set-UserExecutionPolicy
    Wait-GitInstallJob -Job $Script:GitInstallJob
    $Script:GitInstallJob = $null
    Install-SourcetreeEnterprise
    Install-VSCode
    if ($SkipAppLaunches) {
        Write-Log "Installed apps will be opened by the original user process after elevation completes."
        Add-Result "Installed apps launch" "Deferred" "Original user process will open apps"
    }
    else {
        Open-InstalledApps
    }

    if ($SkipChromeTabs) {
        Write-Log "Chrome tabs will be opened by the original user process after elevation completes."
        Add-Result "Google Chrome tabs" "Deferred" "Original user process will open tabs"
    }
    else {
        Open-ChromeTabs
    }
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
