# ==============================
# Stationeers Mod Bootstrap
# Author: Tonzallis
# Version: 1.0.0
# ==============================

$ErrorActionPreference = "Stop"

# ==============================
# Helpers
# ==============================

function Pause-OnExit {
    Write-Host ""
    Write-Host "Press Enter to exit..."
    Read-Host
}

function Get-LatestReleaseInfo {
    param ($repo)

    $apiUrl = "https://api.github.com/repos/$repo/releases/latest"
    return Invoke-RestMethod -Uri $apiUrl
}

function Needs-Update {
    param (
        $versionFile,
        $latestVersion
    )

    if (!(Test-Path $versionFile)) {
        return $true
    }

    $localVersion = Get-Content $versionFile

    return ($localVersion -ne $latestVersion)
}

# ==============================
# Steam Game Detection
# ==============================

function Find-SteamGamePath {

    param ($appId)

    Write-Host "Searching for Steam..."

    try {
        $steamPath = (
            Get-ItemProperty `
            "HKCU:\Software\Valve\Steam"
        ).SteamPath
    }
    catch {
        $steamPath = "${env:ProgramFiles(x86)}\Steam"
    }

    if (!(Test-Path $steamPath)) {
        Write-Host "Steam not found."
        return $null
    }

    Write-Host "Steam found at:"
    Write-Host $steamPath

    $libraryFile = Join-Path `
        $steamPath `
        "steamapps\libraryfolders.vdf"

    if (!(Test-Path $libraryFile)) {
        Write-Host "libraryfolders.vdf not found."
        return $null
    }

    Write-Host "Reading libraries..."

    $content = Get-Content $libraryFile

    $libraries = @()

    foreach ($line in $content) {

        if ($line -match '"path"\s+"(.+)"') {

            $path = $matches[1] -replace "\\\\", "\"
            $libraries += $path
        }
    }

    $libraries += $steamPath

    foreach ($lib in $libraries) {

        $manifest = Join-Path `
            $lib `
            "steamapps\appmanifest_$appId.acf"

        if (Test-Path $manifest) {

            Write-Host "Game manifest found:"
            Write-Host $manifest

            $gamePath = Join-Path `
                $lib `
                "steamapps\common\Stationeers"

            if (Test-Path $gamePath) {

                Write-Host "Game found:"
                Write-Host $gamePath

                return $gamePath
            }
        }
    }

    return $null
}

# ==============================
# MAIN
# ==============================

try {

    Write-Host ""
    Write-Host "Stationeers Mod Bootstrap"
    Write-Host "========================="

    # =========================
    # Find Game
    # =========================

    $gamePath = Find-SteamGamePath "544550"

    if ($null -eq $gamePath) {

        Write-Host ""
        Write-Host "Enter Stationeers path manually:"

        $gamePath = Read-Host

        if (!(Test-Path $gamePath)) {

            Write-Host "Invalid path."
            Pause-OnExit
            exit
        }
    }

    # =========================
    # Setup temp
    # =========================

    $tempPath = "$env:TEMP\stationeers_setup"

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $tempPath | Out-Null

    # =========================
    # BepInEx
    # =========================

    Write-Host ""
    Write-Host "Checking BepInEx..."

    $release = Get-LatestReleaseInfo "BepInEx/BepInEx"
    $latestVersion = $release.tag_name

    $versionFile = Join-Path `
        $gamePath `
        "BepInEx\version.txt"

    if (Needs-Update $versionFile $latestVersion) {

        Write-Host "Updating BepInEx to $latestVersion"

        $asset = $release.assets |
            Where-Object {
                $_.name -like "BepInEx_win_x64*.zip"
            } |
            Select-Object -First 1

        $zipPath = "$tempPath\bepinex.zip"

        Invoke-WebRequest `
            -Uri $asset.browser_download_url `
            -OutFile $zipPath

        Expand-Archive `
            -Path $zipPath `
            -DestinationPath $gamePath `
            -Force

        Set-Content `
            -Path $versionFile `
            -Value $latestVersion

    }
    else {

        Write-Host "BepInEx is up to date"

    }

    # =========================
    # Plugins folder
    # =========================

    $pluginsPath = Join-Path `
        $gamePath `
        "BepInEx\plugins"

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $pluginsPath | Out-Null

    # =========================
    # LaunchPad
    # =========================

    Write-Host ""
    Write-Host "Checking LaunchPad..."

    $release = Get-LatestReleaseInfo `
        "StationeersLaunchPad/StationeersLaunchPad"

    $latestVersion = $release.tag_name

    $versionFile = Join-Path `
        $pluginsPath `
        "LaunchPad.version.txt"

    if (Needs-Update $versionFile $latestVersion) {

        Write-Host "Updating LaunchPad to $latestVersion"

        $asset = $release.assets |
            Where-Object {
                $_.name -like "*.zip"
            } |
            Select-Object -First 1

        $zipPath = "$tempPath\launchpad.zip"

        Invoke-WebRequest `
            -Uri $asset.browser_download_url `
            -OutFile $zipPath

        Expand-Archive `
            -Path $zipPath `
            -DestinationPath $pluginsPath `
            -Force

        Set-Content `
            -Path $versionFile `
            -Value $latestVersion

    }
    else {

        Write-Host "LaunchPad is up to date"

    }

    # =========================
    # Cleanup
    # =========================

    Remove-Item `
        $tempPath `
        -Recurse `
        -Force

    Write-Host ""
    Write-Host "Installation complete."

}
catch {

    Write-Host ""
    Write-Host "ERROR:"
    Write-Host $_

}

Pause-OnExit