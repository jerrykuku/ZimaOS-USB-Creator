# Unified Windows build channel for ZimaOS USB Creator.
# Run from a Developer PowerShell or PowerShell 7:
#   .\build-windows.ps1 install
#   .\build-windows.ps1 dev -QtRoot "$env:LOCALAPPDATA\Qt\6.10.3\mingw_64" -MingwRoot "$env:LOCALAPPDATA\Qt\Tools\mingw1310_64"
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('install', 'dev', 'build', 'release', 'clean')]
    [string]$Action,

    [string]$QtRoot = $env:Qt6_ROOT,
    [string]$MingwRoot = $env:MINGW64_ROOT,
    [string]$QtInstallRoot = $env:QT_INSTALL_ROOT,
    [string]$QtVersion = '6.10.3',
    [string]$QtArch = 'win64_mingw',
    [string]$MingwTool = 'tools_mingw1310',
    [string]$BuildDir,
    [int]$Jobs = 0,
    [switch]$WithQt,
    [switch]$Cli,
    # Development mirrors macOS: launch the built application unless this is
    # explicitly disabled for CI or build-only workflows. Kept -Run below as
    # a harmless compatibility alias for existing commands.
    [switch]$Run,
    [switch]$NoRun,
    # Build a distributable installer without Authenticode signing. The
    # default release path remains signed and still requires a certificate.
    [switch]$Unsigned,
    [string]$SigningCertificateThumbprint
)

$ErrorActionPreference = 'Stop'

# A PowerShell process keeps the PATH it inherited when it was started.  This
# is commonly stale after `winget install` (CMake/Ninja update the User or
# Machine environment, but the current shell does not see those changes).
# Merge the registered Windows PATH values into this process before checking
# for build tools, so `install` followed by `build` works in one shell too.
function Refresh-ProcessPath {
    $entries = @($env:Path -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    foreach ($scope in @('User', 'Machine')) {
        $registered = [Environment]::GetEnvironmentVariable('Path', $scope)
        foreach ($entry in @($registered -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            if (-not (Test-Path -LiteralPath $entry -PathType Container)) { continue }
            if (-not ($entries | Where-Object { $_.TrimEnd('\') -ieq $entry.TrimEnd('\') })) {
                $entries += $entry
            }
        }
    }
    $env:Path = $entries -join ';'
}

Refresh-ProcessPath

# Markdown may escape underscores as `\_`; accept those values when copied from
# documentation, and keep compatibility with the old aqt names used here.
$QtArch = $QtArch -replace '\\_', '_'
$MingwTool = $MingwTool -replace '\\_', '_'
if ($QtArch -eq 'win64_mingw1310_64') { $QtArch = 'win64_mingw' }
if ($MingwTool -eq 'tools_mingw1310_64') { $MingwTool = 'tools_mingw1310' }
if ([string]::IsNullOrWhiteSpace($BuildDir)) { $BuildDir = Join-Path $PSScriptRoot 'build-windows' }
if ([string]::IsNullOrWhiteSpace($QtInstallRoot)) {
    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($localAppData)) { $localAppData = $env:USERPROFILE }
    $QtInstallRoot = Join-Path $localAppData 'Qt'
}
if ([string]::IsNullOrWhiteSpace($QtRoot)) {
    $QtRoot = Join-Path $QtInstallRoot "$QtVersion\mingw_64"
}
if ([string]::IsNullOrWhiteSpace($MingwRoot)) {
    $MingwRoot = Join-Path $QtInstallRoot 'Tools\mingw1310_64'
}

function Fail([string]$Message) {
    throw "build-windows: $Message"
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { Fail 'this channel must run on Windows.' }

function Require-Command([string]$Name, [string]$Hint) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Fail "$Name is required. $Hint"
    }
}

function Install-Prerequisites {
    Require-Command winget 'Install App Installer from the Microsoft Store.'
    $packages = @(
        @{ Id = 'Kitware.CMake'; Name = 'CMake' },
        @{ Id = 'Ninja-build.Ninja'; Name = 'Ninja' },
        @{ Id = 'JRSoftware.InnoSetup'; Name = 'Inno Setup' },
        @{ Id = 'Git.Git'; Name = 'Git' }
    )
    foreach ($package in $packages) {
        Write-Host "build-windows: installing $($package.Name) when absent..."
        winget install --exact --id $package.Id --accept-package-agreements --accept-source-agreements
        $packageExitCode = $LASTEXITCODE
        if ($packageExitCode -ne 0) {
            # winget returns 1 for an already-installed package with no
            # available upgrade. Continue when the package is discoverable;
            # otherwise report the actual package that failed.
            $installed = winget list --exact --id $package.Id --accept-source-agreements 2>$null
            # winget returns an array of output lines; join them before the
            # match so PowerShell does not evaluate a multi-element boolean
            # array as truthy when the package is actually present.
            $installedText = $installed -join "`n"
            if ($installedText -notmatch [regex]::Escape($package.Id)) {
                Fail "$($package.Name) installation failed (winget exit code $packageExitCode)."
            }
            Write-Host "build-windows: $($package.Name) is already installed; continuing."
        }
    }

    if ($WithQt) {
        Require-Command py 'Install Python 3, then reopen PowerShell.'
        & py -m pip install --user --upgrade aqtinstall
        if ($LASTEXITCODE -ne 0) { Fail 'aqtinstall installation failed.' }
        # Install the Qt SDK kit and its matching standalone MinGW toolchain.
        # Use -QtVersion/-QtArch/-MingwTool when the selected kit changes.
        Write-Host "build-windows: installing Qt $QtVersion ($QtArch) and $MingwTool..."
        try {
            New-Item -ItemType Directory -Path $QtInstallRoot -Force -ErrorAction Stop | Out-Null
            $writeProbe = Join-Path $QtInstallRoot ('.zimaos-write-test-{0}' -f [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType File -Path $writeProbe -Force -ErrorAction Stop | Out-Null
            Remove-Item -LiteralPath $writeProbe -Force -ErrorAction SilentlyContinue
        } catch {
            Fail "Qt installation root '$QtInstallRoot' is not writable. Pass -QtInstallRoot to a user-writable directory."
        }
        & py -m aqt install-qt windows desktop $QtVersion $QtArch --outputdir $QtInstallRoot
        if ($LASTEXITCODE -ne 0) {
            Fail "Qt kit installation failed. Verify that Qt $QtVersion with architecture '$QtArch' is available via 'py -m aqt list-qt windows desktop'."
        }
        & py -m aqt install-tool windows desktop $MingwTool --outputdir $QtInstallRoot
        if ($LASTEXITCODE -ne 0) {
            Fail "MinGW toolchain installation failed. Verify '$MingwTool' via 'py -m aqt list-tool windows desktop'."
        }
        Write-Host "build-windows: Qt installed under $QtInstallRoot. Pass -QtRoot and -MingwRoot explicitly if your installed paths differ."
    }
}

function Resolve-InnoSetup {
    # CMake needs iscc.exe during configuration. `install` installs it as a
    # prerequisite, but `release` must also work when called directly.
    function Find-InnoSetup {
        $paths = @(
            (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
            (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
            (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
        ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
        $command = Get-Command iscc.exe -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
        if ($paths.Count -gt 0) {
            # A one-item PowerShell pipeline becomes a scalar string; indexing
            # that scalar (`$paths[0]`) returns its first character. Select the
            # item through the pipeline and force the result to a full string.
            return [string]($paths | Select-Object -First 1)
        }
        return $null
    }

    $existing = Find-InnoSetup
    if ($existing) {
        $innoDir = Split-Path -Parent $existing
        $env:Path = "$innoDir;$env:Path"
        $script:InnoCompilerPath = $existing
        return $existing
    }

    Require-Command winget 'Install App Installer from the Microsoft Store, then retry release.'
    Write-Host 'build-windows: Inno Setup not found; installing it with winget...'
    & winget install --exact --id JRSoftware.InnoSetup --accept-package-agreements --accept-source-agreements
    $wingetExitCode = $LASTEXITCODE
    # winget returns 1 when the package is already installed and no upgrade is
    # available. Treat that as success if ISCC.exe is present after the call.
    $installed = Find-InnoSetup
    if (-not $installed) {
        Fail "Inno Setup installation failed (winget exit code $wingetExitCode), and ISCC.exe could not be located."
    }
    $innoDir = Split-Path -Parent $installed
    $env:Path = "$innoDir;$env:Path"
    $script:InnoCompilerPath = $installed
    return $installed
}

function Resolve-SigningCertificate {
    if ($SigningCertificateThumbprint) {
        $normalized = ($SigningCertificateThumbprint -replace '\s', '').ToUpperInvariant()
        $certificate = @(
            Get-ChildItem "Cert:\CurrentUser\My\$normalized" -ErrorAction SilentlyContinue
            Get-ChildItem "Cert:\LocalMachine\My\$normalized" -ErrorAction SilentlyContinue
        ) | Select-Object -First 1
        if (-not $certificate) { Fail "code-signing certificate was not found: $normalized" }
        if (-not $certificate.HasPrivateKey) { Fail "certificate $normalized has no accessible private key. Unlock the SafeNet token and retry." }
        $script:SigningCertificateThumbprint = $normalized
        return
    }

    $candidates = @(
        Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue
        Get-ChildItem Cert:\LocalMachine\My -CodeSigningCert -ErrorAction SilentlyContinue
    ) | Where-Object { $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date) }
    if ($candidates.Count -eq 0) {
        Fail 'no usable code-signing certificate was found in the CurrentUser or LocalMachine certificate stores. Insert and unlock the SafeNet token, or pass -Unsigned.'
    }
    if ($candidates.Count -gt 1) {
        Write-Host 'build-windows: multiple code-signing certificates found; using the first one. Pass -SigningCertificateThumbprint to select SafeNet explicitly.'
    }
    $script:SigningCertificateThumbprint = ($candidates[0].Thumbprint -replace '\s', '').ToUpperInvariant()
    Write-Host "build-windows: using signing certificate $script:SigningCertificateThumbprint ($($candidates[0].Subject))"
}

function Resolve-Toolchain {
    if (-not (Test-Path (Join-Path $QtRoot 'bin\qmake.exe'))) {
        Fail "Qt 6 was not found at '$QtRoot'. Run '.\build-windows.ps1 install -WithQt' or pass -QtRoot."
    }
    if (-not (Test-Path (Join-Path $MingwRoot 'bin\g++.exe'))) {
        Fail "MinGW was not found at '$MingwRoot'. Pass -MingwRoot for the compiler kit."
    }
    # Keep the compiler, Qt tools, and windeployqt discoverable for CMake/Ninja.
    $env:Path = "$(Join-Path $MingwRoot 'bin');$(Join-Path $QtRoot 'bin');$env:Path"
}

function Configure-And-Build([string]$BuildType, [bool]$Installer, [bool]$Signed) {
    Require-Command cmake 'Run .\build-windows.ps1 install, then reopen PowerShell so PATH is refreshed.'
    Require-Command ninja 'Run .\build-windows.ps1 install, then reopen PowerShell so PATH is refreshed.'
    Resolve-Toolchain

    $cliValue = if ($Cli) { 'ON' } else { 'OFF' }
    $installerValue = if ($Installer) { 'ON' } else { 'OFF' }
    $signedValue = if ($Signed) { 'ON' } else { 'OFF' }
    $cmakeArgs = @(
        '-S', (Join-Path $PSScriptRoot 'src'),
        '-B', $BuildDir,
        '-G', 'Ninja',
        "-DCMAKE_BUILD_TYPE=$BuildType",
        "-DQt6_ROOT=$QtRoot",
        "-DMINGW64_ROOT=$MingwRoot",
        "-DBUILD_CLI_ONLY=$cliValue",
        "-DENABLE_INNO_INSTALLER=$installerValue",
        "-DIMAGER_SIGNED_APP=$signedValue"
    )
    if ($Signed -and $SigningCertificateThumbprint) {
        $cmakeArgs += "-DIMAGER_SIGNING_CERTIFICATE=$SigningCertificateThumbprint"
    }
    if ($script:InnoCompilerPath) {
        # CMake may have cached INNO_COMPILER=NOTFOUND in an existing build
        # directory. Pass the fully-qualified path explicitly; the FILEPATH
        # type preserves spaces in per-user installation paths.
        $innoCmakePath = $script:InnoCompilerPath.Replace('\', '/')
        $cmakeArgs += "-DINNO_COMPILER:FILEPATH=$innoCmakePath"
    }
    & cmake @cmakeArgs
    if ($LASTEXITCODE -ne 0) { Fail 'CMake configuration failed.' }

    $target = if ($Installer) { 'inno_installer' } elseif ($Cli) { 'zimaos-usb-creator-cli' } else { 'zimaos-usb-creator' }
    $buildArgs = @('--build', $BuildDir, '--target', $target)
    if ($Jobs -gt 0) { $buildArgs += @('--parallel', $Jobs) }
    & cmake @buildArgs
    if ($LASTEXITCODE -ne 0) { Fail "Build target '$target' failed." }
    Write-Host "build-windows: completed target $target in $BuildDir"
    # Keep the target available to callers without returning it through the
    # success stream.  Capturing this function's output (`[void](...)` or
    # `$target = ...`) also captures native CMake/Ninja output, making a long
    # build look completely silent in PowerShell.
    $script:LastBuildTarget = $target
}

switch ($Action) {
    'install' {
        Install-Prerequisites
    }
    'clean' {
        if (Test-Path $BuildDir) {
            Remove-Item -Recurse -Force $BuildDir
            Write-Host "build-windows: removed $BuildDir"
        }
    }
    'dev' {
        Configure-And-Build 'Debug' $false $false
        $target = $script:LastBuildTarget
        if (-not $NoRun) {
            # windeployqt stages the executable and all Qt runtime DLLs under
            # deploy\. Launch the staged copy; the raw build output does not
            # have Qt6Network.dll (and the other runtime dependencies) beside it.
            $binary = Join-Path $BuildDir "deploy\$target.exe"
            if (-not (Test-Path $binary)) {
                Fail "expected deployed development binary is missing: $binary. Check that windeployqt completed successfully."
            }
            & $binary
        }
    }
    'build' {
        Configure-And-Build 'MinSizeRel' $false $false
    }
    'release' {
        if ($Cli) { Fail 'release creates the desktop installer; do not pass -Cli.' }
        if ($Unsigned -and $SigningCertificateThumbprint) {
            Fail '-Unsigned cannot be combined with -SigningCertificateThumbprint.'
        }
        $signed = -not $Unsigned
        [void](Resolve-InnoSetup)
        if ($signed) {
            Resolve-SigningCertificate
            Require-Command signtool 'Install the Windows SDK signing tools.'
        }
        Configure-And-Build 'MinSizeRel' $true $signed
        $installerDirectory = Join-Path $BuildDir 'installer'
        if (-not (Get-ChildItem $installerDirectory -Filter '*.exe' -ErrorAction SilentlyContinue)) {
            Fail "Inno Setup did not produce an installer in $installerDirectory"
        }
        $label = if ($signed) { 'signed' } else { 'unsigned' }
        Write-Host "build-windows: $label installer output: $installerDirectory"
    }
}
