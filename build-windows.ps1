# Unified Windows build channel for ZimaOS USB Creator.
# Run from a Developer PowerShell or PowerShell 7:
#   .\build-windows.ps1 install
#   .\build-windows.ps1 dev -QtRoot C:\Qt\6.11.1\mingw_64 -MingwRoot C:\Qt\Tools\mingw1310_64
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('install', 'dev', 'build', 'release', 'clean')]
    [string]$Action,

    [string]$QtRoot = $env:Qt6_ROOT,
    [string]$MingwRoot = $env:MINGW64_ROOT,
    [string]$BuildDir,
    [int]$Jobs = 0,
    [switch]$WithQt,
    [switch]$Cli,
    [switch]$Run,
    [string]$SigningCertificateThumbprint
)

$ErrorActionPreference = 'Stop'
$QtVersion = '6.11.1'
if ([string]::IsNullOrWhiteSpace($BuildDir)) { $BuildDir = Join-Path $PSScriptRoot 'build-windows' }
if ([string]::IsNullOrWhiteSpace($QtRoot)) { $QtRoot = "C:\Qt\$QtVersion\mingw_64" }
if ([string]::IsNullOrWhiteSpace($MingwRoot)) { $MingwRoot = 'C:\Qt\Tools\mingw1310_64' }

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
    }

    if ($WithQt) {
        Require-Command py 'Install Python 3, then reopen PowerShell.'
        & py -m pip install --user --upgrade aqtinstall
        if ($LASTEXITCODE -ne 0) { Fail 'aqtinstall installation failed.' }
        # aqt installs both the Qt kit and the matching MinGW compiler kit.
        & py -m aqt install-qt windows desktop $QtVersion win64_mingw1310_64 --outputdir C:\Qt
        if ($LASTEXITCODE -ne 0) { Fail 'Qt kit installation failed.' }
        & py -m aqt install-tool windows desktop tools_mingw1310_64 --outputdir C:\Qt
        if ($LASTEXITCODE -ne 0) { Fail 'MinGW toolchain installation failed.' }
        Write-Host "build-windows: Qt installed under C:\Qt. Pass -QtRoot and -MingwRoot explicitly if your installed paths differ."
    }
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
    & cmake @cmakeArgs
    if ($LASTEXITCODE -ne 0) { Fail 'CMake configuration failed.' }

    $target = if ($Installer) { 'inno_installer' } elseif ($Cli) { 'zimaos-usb-creator-cli' } else { 'zimaos-usb-creator' }
    $buildArgs = @('--build', $BuildDir, '--target', $target)
    if ($Jobs -gt 0) { $buildArgs += @('--parallel', $Jobs) }
    & cmake @buildArgs
    if ($LASTEXITCODE -ne 0) { Fail "Build target '$target' failed." }
    Write-Host "build-windows: completed target $target in $BuildDir"
    return $target
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
        $target = Configure-And-Build 'Debug' $false $false
        if ($Run) {
            $binary = Join-Path $BuildDir "$target.exe"
            if (-not (Test-Path $binary)) { Fail "expected development binary is missing: $binary" }
            & $binary
        }
    }
    'build' {
        [void](Configure-And-Build 'MinSizeRel' $false $false)
    }
    'release' {
        if ($Cli) { Fail 'release creates the desktop installer; do not pass -Cli.' }
        if ($SigningCertificateThumbprint) {
            $certificate = Get-ChildItem "Cert:\CurrentUser\My\$SigningCertificateThumbprint" -ErrorAction SilentlyContinue
            if (-not $certificate) { Fail "code-signing certificate was not found: $SigningCertificateThumbprint" }
        } elseif (-not (Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue)) {
            Fail 'no code-signing certificate is available in Cert:\CurrentUser\My.'
        }
        Require-Command signtool 'Install the Windows SDK signing tools.'
        [void](Configure-And-Build 'MinSizeRel' $true $true)
        $installerDirectory = Join-Path $BuildDir 'installer'
        if (-not (Get-ChildItem $installerDirectory -Filter '*.exe' -ErrorAction SilentlyContinue)) {
            Fail "Inno Setup did not produce an installer in $installerDirectory"
        }
        Write-Host "build-windows: signed installer output: $installerDirectory"
    }
}
