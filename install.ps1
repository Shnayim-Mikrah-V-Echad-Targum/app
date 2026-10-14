# install.ps1 — Install or update Shnayim Mikrah from GitHub Releases
# Usage (one-liner):
#   Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/Shnayim-Mikrah-V-Echad-Targum/app/main/install.ps1 | iex
# (or point at this file on the v0.0.1-prelease-prep branch / a release asset)

$ErrorActionPreference = "Stop"
$repo = "Shnayim-Mikrah-V-Echad-Targum/app"
$api = "https://api.github.com/repos/$repo/releases/latest"

Write-Host "Checking for latest release of Shnayim Mikrah..."
try {
  $release = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "ShnayimMikrah-Installer" }
} catch {
  Write-Error "Could not reach GitHub Releases API. Check your internet connection."
  exit 1
}

$asset = $release.assets | Where-Object { $_.name -like "*.msix" } | Select-Object -First 1

if (-not $asset) {
  Write-Error "No .msix asset found in the latest release ($($release.tag_name))."
  exit 1
}

$msixPath = Join-Path $env:TEMP $asset.name
Write-Host "Downloading $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB)..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msixPath

Write-Host "Installing..."
Add-AppxPackage -Path $msixPath -ForceApplicationShutdown

Write-Host "Done. Shnayim Mikrah is installed/updated."
Remove-Item $msixPath -ErrorAction SilentlyContinue
