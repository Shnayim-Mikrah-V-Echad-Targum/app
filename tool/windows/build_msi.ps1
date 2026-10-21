<#
.SYNOPSIS
Builds the Windows installer, a per-user MSI, from the Flutter release folder.

.DESCRIPTION
Packages every file of the release folder (the executable, its DLLs with the
Visual C++ runtime, and data\) with the WiX source in tool\windows\msi, into
ShnayimMikrah-X.Y.Z-windows-x64.msi, which installs into
%LOCALAPPDATA%\Programs\Shnayim Mikrah without administrator rights.

It uses WiX 5.0.2. If a wix of that version isn't on the PATH, it installs
one with the .NET SDK into build\tools, leaving any other WiX alone. It then
checks the MSI with Windows Installer's validation (ICEs), prints the MSI's
path and writes it to the pipeline. On any problem it stops with an error.

Runs in Windows PowerShell 5.1 and PowerShell 7, on a PC with the .NET SDK
and on GitHub's windows-latest. docs/RELEASE.md (Windows) has the details.

.PARAMETER ReleaseDir
The Flutter release folder. Defaults to build\windows\x64\runner\Release.

.PARAMETER Version
The installer's version, X.Y.Z (a leading v is dropped). Defaults to the
version name in pubspec.yaml.

.PARAMETER Out
Where to write the MSI. Defaults to
build\windows\msi\ShnayimMikrah-X.Y.Z-windows-x64.msi.

.PARAMETER SkipValidation
Skips the ICE validation, for a PC whose Windows Installer can't run it.

.EXAMPLE
flutter build windows --release
powershell -ExecutionPolicy Bypass -File tool\windows\build_msi.ps1 -Version 0.0.1
#>
[CmdletBinding()]
param(
  [string]$ReleaseDir,
  [string]$Version,
  [string]$Out,
  [switch]$SkipValidation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

# The WiX Toolset release this is built with. 5.0.2 is the last before the
# Open Source Maintenance Fee's EULA (v6), which v7 also makes the command
# line accept.
$WixVersion = '5.0.2'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Fail([string]$Message) {
  throw "build_msi: $Message"
}

function Join-Parts([string[]]$Parts) {
  [IO.Path]::Combine($Parts)
}

# The version wix --version reports, without its +commit suffix.
function Get-WixVersion([string]$Exe) {
  $text = (& $Exe --version | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) {
    return ''
  }
  ($text -split '\+')[0].Trim()
}

# --- The inputs ---

if (-not $ReleaseDir) {
  $ReleaseDir = Join-Parts $RepoRoot, 'build', 'windows', 'x64', 'runner', 'Release'
}
if (-not (Test-Path -LiteralPath $ReleaseDir -PathType Container)) {
  Fail "there is no release folder at $ReleaseDir. Run flutter build windows --release first, or pass -ReleaseDir."
}
$ReleaseDir = (Resolve-Path -LiteralPath $ReleaseDir).ProviderPath.TrimEnd('\', '/')

if (-not $Version) {
  $pubspec = Join-Parts $RepoRoot, 'pubspec.yaml'
  foreach ($line in [IO.File]::ReadAllLines($pubspec)) {
    if ($line -match '^version:\s*(\d+\.\d+\.\d+)') {
      $Version = $Matches[1]
      break
    }
  }
  if (-not $Version) {
    Fail "pubspec.yaml has no version: X.Y.Z line; pass -Version."
  }
}
$Version = $Version.Trim()
if ($Version.StartsWith('v')) {
  $Version = $Version.Substring(1)
}
if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
  Fail "-Version must be X.Y.Z, such as 0.0.1, not '$Version'."
}
# Windows Installer compares major.minor.build, at most 255.255.65535.
if ([int]$Matches[1] -gt 255 -or [int]$Matches[2] -gt 255 -or [int]$Matches[3] -gt 65535) {
  Fail "Windows Installer versions go up to 255.255.65535, not $Version."
}

if (-not $Out) {
  $Out = Join-Parts $RepoRoot, 'build', 'windows', 'msi', "ShnayimMikrah-$Version-windows-x64.msi"
}
$Out = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Out))
if ([IO.Path]::GetExtension($Out) -ne '.msi') {
  Fail "-Out must name an .msi file, not $Out."
}

# A folder that runs on a PC without the Visual C++ Redistributable
# (windows/CMakeLists.txt puts the runtime beside the executable).
$required = @(
  'shnayim_mikrah.exe',
  'flutter_windows.dll',
  'msvcp140.dll',
  'vcruntime140.dll',
  'vcruntime140_1.dll',
  (Join-Path 'data' 'icudtl.dat'),
  (Join-Path 'data' 'app.so'),
  (Join-Path 'data' 'flutter_assets')
)
foreach ($name in $required) {
  if (-not (Test-Path -LiteralPath (Join-Path $ReleaseDir $name))) {
    if ($name -like '*140*.dll') {
      Fail ("$name, part of the Visual C++ runtime, is missing from $ReleaseDir, and without it the app won't start on a PC " +
        'without the Visual C++ Redistributable. Build the MSI from a fresh flutter build windows --release, before ' +
        'tool/windows/make_msix.sh: the msix tool deletes the runtime from the folder when it packs.')
    }
    Fail "$name is missing from $ReleaseDir, which isn't a complete release build (flutter build windows --release)."
  }
}

# --- WiX ---

$wix = $null
$onPath = Get-Command wix -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($onPath) {
  $found = Get-WixVersion $onPath.Path
  if ($found -eq $WixVersion) {
    $wix = $onPath.Path
  } else {
    Write-Host "Found WiX $found at $($onPath.Path); using WiX $WixVersion instead."
  }
}
if (-not $wix) {
  $toolDir = Join-Parts $RepoRoot, 'build', 'tools', "wix-$WixVersion"
  $toolExe = Join-Path $toolDir 'wix.exe'
  if (-not (Test-Path -LiteralPath $toolExe)) {
    $dotnet = Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $dotnet) {
      Fail ("WiX $WixVersion is installed with the .NET SDK, which isn't on the PATH. Install the .NET SDK " +
        '(https://dotnet.microsoft.com/download), open a new PowerShell, and run this again.')
    }
    Write-Host "Installing WiX $WixVersion into $toolDir..."
    & $dotnet.Path tool install wix --version $WixVersion --tool-path $toolDir | Out-Host
    if ($LASTEXITCODE -ne 0) {
      Fail "dotnet tool install wix --version $WixVersion failed (exit code $LASTEXITCODE)."
    }
  }
  $found = Get-WixVersion $toolExe
  if ($found -ne $WixVersion) {
    Fail "$toolExe reports WiX '$found', not $WixVersion. Delete $toolDir and run this again."
  }
  $wix = $toolExe
}
Write-Host "WiX $WixVersion`: $wix"

# --- Files.wxs: every file of the release folder ---

# What the MSIX packaging (tool/windows/make_msix.sh and the msix tool) may
# leave in the folder, and the linker's by-products, are not the app.
function Test-Excluded([string]$Relative, [bool]$IsFile) {
  $parts = $Relative.Split('\')
  if ($parts.Length -gt 1 -and ($parts[0] -eq 'Images' -or $parts[0] -eq 'Strings')) {
    return $true
  }
  $name = $parts[$parts.Length - 1]
  if ($IsFile -and $parts.Length -eq 1) {
    if ($name -eq 'AppxManifest.xml' -or $name -match '^resources(\..+)?\.pri$' -or
      $name -match '\.(msix|msixbundle|appinstaller|appx)$' -or
      $name -eq 'installCertificate.ps1' -or $name -eq 'InstallTestCertificate.exe' -or $name -eq 'test_certificate.pfx') {
      return $true
    }
  }
  $IsFile -and $name -match '\.(pdb|ilk|exp|lib)$'
}

$sha1 = [Security.Cryptography.SHA1]::Create()

# A stable id for a relative path: the same path gets the same id in every
# build. Windows paths ignore case, and so do the ids.
function Get-PathHash([string]$Relative) {
  $bytes = $sha1.ComputeHash([Text.Encoding]::UTF8.GetBytes($Relative.ToLowerInvariant()))
  -join ($bytes | ForEach-Object { $_.ToString('x2') })
}

# A stable component guid for a folder (a name-based, version 5 guid).
function Get-ComponentGuid([string]$Relative) {
  $hash = $sha1.ComputeHash([Text.Encoding]::UTF8.GetBytes('ShnayimMikrah.Msi.Component:' + $Relative.ToLowerInvariant()))
  $bytes = New-Object byte[] 16
  [Array]::Copy($hash, $bytes, 16)
  $bytes[7] = ($bytes[7] -band 0x0F) -bor 0x50
  $bytes[8] = ($bytes[8] -band 0x3F) -bor 0x80
  (New-Object Guid (, $bytes)).ToString('B').ToUpperInvariant()
}

function Get-DirectoryId([string]$Relative) {
  if ($Relative -eq '') {
    return 'InstallFolder'
  }
  'dir_' + (Get-PathHash $Relative)
}

# Each file's path below the release folder, with backslashes.
$filesByFolder = @{}
$excluded = New-Object System.Collections.Generic.List[string]
$count = 0
foreach ($file in (Get-ChildItem -LiteralPath $ReleaseDir -Recurse -File)) {
  $relative = $file.FullName.Substring($ReleaseDir.Length + 1).Replace('/', '\')
  if (Test-Excluded $relative $true) {
    $excluded.Add($relative)
    continue
  }
  if ($file.Name.Contains('$(') -or $file.Name.Contains('!(')) {
    Fail "WiX would read $relative's name as a variable; rename it."
  }
  $folder = ''
  $slash = $relative.LastIndexOf('\')
  if ($slash -ge 0) {
    $folder = $relative.Substring(0, $slash)
  }
  if (-not $filesByFolder.ContainsKey($folder)) {
    $filesByFolder[$folder] = New-Object System.Collections.Generic.List[object]
  }
  $filesByFolder[$folder].Add($file)
  $count++
}
if ($count -eq 0) {
  Fail "$ReleaseDir has no files."
}

# Every folder that holds a file, with the folders above it.
$folders = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
[void]$folders.Add('')
foreach ($folder in @($filesByFolder.Keys)) {
  $path = $folder
  while ($path -ne '') {
    [void]$folders.Add($path)
    $slash = $path.LastIndexOf('\')
    if ($slash -ge 0) {
      $path = $path.Substring(0, $slash)
    } else {
      $path = ''
    }
  }
}
$sortedFolders = [string[]]@($folders)
[Array]::Sort($sortedFolders, [StringComparer]::OrdinalIgnoreCase)

function Get-Children([string]$Parent) {
  foreach ($folder in $sortedFolders) {
    if ($folder -eq '') {
      continue
    }
    $slash = $folder.LastIndexOf('\')
    $up = ''
    if ($slash -ge 0) {
      $up = $folder.Substring(0, $slash)
    }
    if ($up -eq $Parent) {
      $folder
    }
  }
}

function Write-Folders($Writer, [string]$Parent) {
  foreach ($child in @(Get-Children $Parent)) {
    $Writer.WriteStartElement('Directory', $ns)
    $Writer.WriteAttributeString('Id', (Get-DirectoryId $child))
    $Writer.WriteAttributeString('Name', $child.Substring($child.LastIndexOf('\') + 1))
    Write-Folders $Writer $child
    $Writer.WriteEndElement()
  }
}

$work = Join-Parts $RepoRoot, 'build', 'windows', 'msi', 'obj'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$filesWxs = Join-Path $work 'Files.wxs'

$ns = 'http://wixtoolset.org/schemas/v4/wxs'
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Indent = $true
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)
$writer = [System.Xml.XmlWriter]::Create($filesWxs, $settings)
try {
  $writer.WriteStartDocument()
  $writer.WriteComment(' Written by tool/windows/build_msi.ps1 from the release folder; not to be edited. ')
  $writer.WriteStartElement('Wix', $ns)
  $writer.WriteStartElement('Fragment', $ns)

  $writer.WriteStartElement('DirectoryRef', $ns)
  $writer.WriteAttributeString('Id', 'InstallFolder')
  Write-Folders $writer ''
  $writer.WriteEndElement()

  # One component for each folder: its files, its removal on uninstall, and
  # a value in HKCU as its key path, as a per-user install needs.
  $writer.WriteStartElement('ComponentGroup', $ns)
  $writer.WriteAttributeString('Id', 'AppFiles')
  foreach ($folder in $sortedFolders) {
    $hash = Get-PathHash ('component:' + $folder)
    $componentId = 'cmp_' + $hash
    $directoryId = Get-DirectoryId $folder
    $writer.WriteStartElement('Component', $ns)
    $writer.WriteAttributeString('Id', $componentId)
    $writer.WriteAttributeString('Directory', $directoryId)
    $writer.WriteAttributeString('Guid', (Get-ComponentGuid $folder))

    $writer.WriteStartElement('RegistryValue', $ns)
    $writer.WriteAttributeString('Root', 'HKCU')
    $writer.WriteAttributeString('Key', 'Software\ShnayimMikrah\Installer\Components')
    $writer.WriteAttributeString('Name', $componentId)
    $writer.WriteAttributeString('Type', 'integer')
    $writer.WriteAttributeString('Value', '1')
    $writer.WriteAttributeString('KeyPath', 'yes')
    $writer.WriteEndElement()

    $writer.WriteStartElement('RemoveFolder', $ns)
    $writer.WriteAttributeString('Id', 'rmf_' + $hash)
    $writer.WriteAttributeString('Directory', $directoryId)
    $writer.WriteAttributeString('On', 'uninstall')
    $writer.WriteEndElement()

    if ($filesByFolder.ContainsKey($folder)) {
      $inFolder = @($filesByFolder[$folder] | Sort-Object -Property Name)
      foreach ($file in $inFolder) {
        $relative = $file.FullName.Substring($ReleaseDir.Length + 1).Replace('/', '\')
        $writer.WriteStartElement('File', $ns)
        $writer.WriteAttributeString('Id', 'fil_' + (Get-PathHash $relative))
        $writer.WriteAttributeString('Name', $file.Name)
        $writer.WriteAttributeString('Source', $file.FullName)
        $writer.WriteEndElement()
      }
    }
    $writer.WriteEndElement()
  }
  $writer.WriteEndElement()

  $writer.WriteEndElement()
  $writer.WriteEndElement()
  $writer.WriteEndDocument()
} finally {
  $writer.Close()
}
Write-Host "Packaging $count files from $ReleaseDir."
foreach ($relative in $excluded) {
  Write-Host "  Left out $relative (not part of the app)."
}

# --- Build and check ---

$mainWxs = Join-Parts $PSScriptRoot, 'msi', 'ShnayimMikrah.wxs'
$icon = Join-Parts $RepoRoot, 'windows', 'runner', 'resources', 'app_icon.ico'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
if (Test-Path -LiteralPath $Out) {
  Remove-Item -LiteralPath $Out -Force
}

& $wix build -arch x64 -d "ProductVersion=$Version" -d "AppIcon=$icon" -intermediatefolder $work -pdbtype none -o $Out $mainWxs $filesWxs | Out-Host
if ($LASTEXITCODE -ne 0) {
  Fail "wix build failed (exit code $LASTEXITCODE); its errors are above."
}
if (-not (Test-Path -LiteralPath $Out -PathType Leaf)) {
  Fail "wix build reported success but wrote no $Out."
}

if ($SkipValidation) {
  Write-Host 'Skipping the ICE validation (-SkipValidation).'
} else {
  & $wix msi validate $Out | Out-Host
  if ($LASTEXITCODE -ne 0) {
    Fail "Windows Installer's validation (ICEs) found errors in $Out (exit code $LASTEXITCODE); they are above."
  }
}

$size = (Get-Item -LiteralPath $Out).Length / 1MB
Write-Host ('Built {0} ({1:N1} MB), Shnayim Mikrah {2}.' -f $Out, $size, $Version)
Write-Output $Out
