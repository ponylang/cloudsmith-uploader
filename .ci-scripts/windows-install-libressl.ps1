#
# Downloads pre-built LibreSSL static libraries for the current Windows
# architecture and places them in lib/windows-<arch>/.
#
# This script is called by the "Update vendored LibreSSL" workflow.
#
# Environment:
#   LIBRESSL_VERSION  LibreSSL version to download (default: 3.9.1)
#

$version = if ($env:LIBRESSL_VERSION) { $env:LIBRESSL_VERSION } else { "3.9.1" }

$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
if ($arch -ieq "X64") { $zipArch = "x64"; $libDir = "windows-x86-64" }
elseif ($arch -ieq "Arm64") { $zipArch = "ARM64"; $libDir = "windows-arm64" }
else { throw "Unsupported architecture: $arch" }

$zipName = "libressl_v${version}_windows_${zipArch}.zip"
$url = "https://github.com/libressl/portable/releases/download/v${version}/${zipName}"

$tempDir = Join-Path $env:TEMP "libressl"
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

Write-Host "Downloading LibreSSL ${version} for ${zipArch}..."
Invoke-WebRequest $url -OutFile "$tempDir\$zipName"
Expand-Archive -Force -Path "$tempDir\$zipName" -DestinationPath "$tempDir\libressl"

$repoRoot = Split-Path $PSScriptRoot
$destDir = Join-Path $repoRoot "lib\$libDir"
if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

Write-Host "Copying static libraries to $destDir..."
Copy-Item -Force "$tempDir\libressl\lib\ssl.lib" "$destDir\ssl.lib"
Copy-Item -Force "$tempDir\libressl\lib\crypto.lib" "$destDir\crypto.lib"
Copy-Item -Force "$tempDir\libressl\lib\tls.lib" "$destDir\tls.lib"

Write-Host "Done."
Get-ChildItem $destDir | Format-Table Name, Length
