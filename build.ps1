#!/usr/bin/env pwsh
# USAGE:
# .\build.ps1 [-BuildMode <dev|release|prerelease|unittest>]
# Defaults to `dev` build mode.

param(
    [ValidateSet('dev', 'release', 'prerelease', 'unittest')]
    [string]$BuildMode = 'dev'
)

# --- Helper functions ---

function Invoke-CommandWithCheck {
    param(
        [string]$Executable,
        [string[]]$Arguments
    )
    & $Executable $Arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠ Error: Command '$Executable' failed with exit code $LASTEXITCODE." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

function Publish-DevPlugin {
    param(
        [string][Parameter(Mandatory = $true)] $NameSuffix,
        [string][Parameter(Mandatory = $true)] $DefineValue
    )

    # Clean and copy files to dev location
    if (Test-Path $buildDest) {
        Remove-Item -Path "$buildDest\*" -Recurse -Force
    }
    Copy-Item -Path "$pluginSrcDir\*" -Destination $buildDest -Recurse -Force -Container -Verbose
    Copy-Item -Path $infoTomlPath -Destination $buildDest

    # Modify info.toml in destination
    $destInfoPath = Join-Path $buildDest "info.toml"
    (Get-Content $destInfoPath) | ForEach-Object {
        $_ -replace '^(name\s*=\s*")(.*)(")', ('${1}${2}' + $NameSuffix + '"') `
           -replace '^#__DEFINES__', "defines = [""$DefineValue""]"
    } | Set-Content $destInfoPath
}

# --- Check for required commands ---

if (Get-Command 7z -ErrorAction SilentlyContinue) {
} else {
    Write-Host "⚠ Error: 7z command not found. Please install 7-Zip and ensure it's in your PATH." -ForegroundColor Red
    exit 1
}

# --- Start of build proper ---

Write-Host "🚩 Build mode: $BuildMode" -ForegroundColor Yellow

# --- Configuration ---
$pluginSrcDir = "src"
$infoTomlPath = "./info.toml"

if (-not (Test-Path $infoTomlPath)) {
    Write-Host "⚠ Error: '$infoTomlPath' not found." -ForegroundColor Red
    exit 1
}

# --- Parse info.toml ---
$infoContent = Get-Content $infoTomlPath
$pluginPrettyName = ($infoContent | Select-String -Pattern '^name\s*=' | ForEach-Object { ($_ -split '=')[1].Trim().Trim('"') })
$pluginVersion = ($infoContent | Select-String -Pattern '^version\s*=' | ForEach-Object { ($_ -split '=')[1].Trim().Trim('"') })

# --- Adjust names based on build mode ---
$suffixMap = @{
    dev        = " (Dev)"
    prerelease = " (Prerelease)"
    unittest   = " (UnitTest)"
}
if ($suffixMap.ContainsKey($BuildMode)) {
    $pluginPrettyName = "$pluginPrettyName$($suffixMap[$BuildMode])"
}


Write-Host ""
Write-Host "✅ Building: $pluginPrettyName" -ForegroundColor Green

# --- Generate file/folder names ---
# remove parens, replace spaces with dashes, and lowercase
$pluginName = $pluginPrettyName.ToLower() -replace '[(),:;''"]', '' -replace '\s+', '-'
Write-Host "✅ Output file/folder name: $pluginName" -ForegroundColor Green

$releaseName = "$pluginName-$pluginVersion.op"

# Determine plugins directory, prioritizing environment variable
if ($env:PLUGINS_DIR) {
    $pluginsDir = $env:PLUGINS_DIR
}
else {
    # Default for Windows environments
    $pluginsDir = Join-Path $env:USERPROFILE "OpenplanetNext\Plugins"
}
$buildDest = Join-Path $pluginsDir $pluginName

# --- Build Logic ---
$copyExitCode = 0
try {
    switch ($BuildMode) {
        "dev" {
            Publish-DevPlugin -NameSuffix $suffixMap.dev -DefineValue "DEV"
        }
        "prerelease" {
            Publish-DevPlugin -NameSuffix $suffixMap.prerelease -DefineValue "RELEASE"
        }
        "unittest" {
            Publish-DevPlugin -NameSuffix $suffixMap.unittest -DefineValue "UNIT_TEST"
        }
        "release" {
            # Create a temporary info.toml for release build
            $tempInfoPath = Join-Path $pluginSrcDir "info.toml"
            Copy-Item -Path $infoTomlPath -Destination $tempInfoPath
            (Get-Content $tempInfoPath) | ForEach-Object {
                $_ -replace '^#__DEFINES__', 'defines = ["RELEASE"]'
            } | Set-Content $tempInfoPath

            # Build archive
            $timestamp = Get-Date -UFormat %s
            $buildName = "$pluginName-$timestamp.zip"
            $pluginFiles = Get-ChildItem -Path "$pluginSrcDir" -Recurse | ForEach-Object { $_.FullName }
            Write-Host "⚠️ Can't get the 7z path stuff to work right, it zips the whole ./ folder atm" -ForegroundColor Yellow
            # $archiveFiles = @("./$pluginSrcDir/*", "./LICENSE", "./README.md")
            $archiveFiles = $pluginFiles + @("./LICENSE", "./README.md")
            Invoke-CommandWithCheck "7z" @("a", "-bb2", $buildName) + $archiveFiles
            Write-Host "⚠️ Can't get the 7z path stuff to work right, it zips the whole ./ folder atm" -ForegroundColor Yellow
            Copy-Item -Path $buildName -Destination $releaseName -Force
            Remove-Item $buildName
            Remove-Item $tempInfoPath # Clean up temp file

            Write-Host "`n✅ Built plugin as ./$releaseName." -ForegroundColor Green
        }
    }
}
catch {
    $copyExitCode = 1
    Write-Host "⚠ An error occurred during the build process:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# --- Post-Build ---
Write-Host ""
if ($copyExitCode -ne 0) {
    Write-Host "⚠ Error: Could not copy plugin to Openplanet directory." -ForegroundColor Red
    exit $copyExitCode
}
else {
    if ($BuildMode -in @("dev", "prerelease", "unittest")) {
        Write-Host "✅ Copied files to $buildDest" -ForegroundColor Green
        # Trigger remote build if available
        if (Get-Command tm-remote-build -ErrorAction SilentlyContinue) {
            try {
                & tm-remote-build load folder $pluginName --host 127.0.0.1 --port 30000
            }
            catch {
                Write-Host "⚠ tm-remote-build command failed to execute." -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "⚠ tm-remote-build not found, skipping remote reload." -ForegroundColor Yellow
        }
    }
    Write-Host "✅ Release file: $releaseName" -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ Done." -ForegroundColor Green
