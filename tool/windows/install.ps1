# Installs Shnayim Mikrah on Windows: it downloads the newest release's
# installer (an MSI) from GitHub, checks it against the release's SHA-256
# sums, and installs it for this Windows account alone, without
# administrator rights. In PowerShell:
#
#   Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/Shnayim-Mikrah-V-Echad-Targum/app/main/tool/windows/install.ps1 | iex
#
# Run that way, through iex, it takes no parameters; its options are
# environment variables:
#
#   SM_TAG=vX.Y.Z   install that release, not the newest
#   SM_MSI=<path>   install this MSI instead of downloading one (for testing);
#                   it is checked against SM_SHA256, if that is set
#   SM_SHA256=<hex> the SHA-256 that SM_MSI must have
#   SM_WAIT_PID=<n> first wait, up to 60 seconds, for this process to exit
#                   (the app's own updater passes its process id)
#   SM_NO_LAUNCH=1  don't start the app afterwards
#   SM_QUIET=1      install with no window at all (msiexec /qn)
#
# For example, to install a release that isn't the newest:
#
#   $env:SM_TAG = 'v0.0.1'; irm https://raw.githubusercontent.com/Shnayim-Mikrah-V-Echad-Targum/app/main/tool/windows/install.ps1 | iex
#
# The app goes into %LOCALAPPDATA%\Programs\Shnayim Mikrah. The reader's
# settings, progress and notes, in %APPDATA%\Shnayim Mikrah, are never
# touched. Each step is logged to %LOCALAPPDATA%\Shnayim Mikrah\install.log.
#
# It runs in Windows PowerShell 5.1 and PowerShell 7, so it is plain ASCII
# and uses nothing newer than 5.1 has. docs/RELEASE.md (Windows) describes
# how it is tested; test/app/windows_installer_test.dart pins it.

& {
  $ErrorActionPreference = 'Stop'
  # Windows PowerShell 5.1 draws a progress bar so slowly that it slows the
  # download itself.
  $ProgressPreference = 'SilentlyContinue'

  $Repository = 'Shnayim-Mikrah-V-Echad-Targum/app'
  $ReleasesApi = "https://api.github.com/repos/$Repository/releases?per_page=20"
  $TagApi = "https://api.github.com/repos/$Repository/releases/tags/"
  $ReleasesPage = "https://github.com/$Repository/releases"
  # The only hosts it talks to, on every redirect: GitHub's API, and
  # GitHub's release downloads with the hosts they redirect to.
  $ApiHosts = @('api.github.com')
  $DownloadHosts = @('github.com', 'objects.githubusercontent.com', 'release-assets.githubusercontent.com')
  $UserAgent = 'ShnayimMikrah-Installer'

  $InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\Shnayim Mikrah'
  $AppExe = Join-Path $InstallDir 'shnayim_mikrah.exe'
  $StateDir = Join-Path $env:LOCALAPPDATA 'Shnayim Mikrah'
  $LogPath = Join-Path $StateDir 'install.log'
  $MsiLogPath = Join-Path $StateDir 'msiexec.log'

  # Started by the app's updater, which has closed the app for this.
  $FromUpdater = [bool]$env:SM_WAIT_PID

  function Write-Log([string]$Message) {
    try {
      if (-not (Test-Path -LiteralPath $StateDir)) {
        New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
      }
      $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
      Add-Content -LiteralPath $LogPath -Value "$stamp  $Message" -Encoding UTF8
    } catch {
      # The log never stops the install.
    }
  }

  function Write-Step([string]$Message) {
    Write-Host $Message
    Write-Log $Message
  }

  # Stops the install, with a message for the reader.
  function Stop-Install([string]$Message) {
    throw $Message
  }

  function Assert-Host([Uri]$Uri, [string[]]$Hosts) {
    if ($Uri.Scheme -ne 'https' -or $Hosts -notcontains $Uri.Host.ToLowerInvariant()) {
      Stop-Install "Refusing to download from $($Uri.Scheme)://$($Uri.Host)/: only HTTPS from $($Hosts -join ', ') is allowed."
    }
  }

  # The response that a failed .NET request carried, if any.
  function Get-ErrorResponse($ErrorRecord) {
    $exception = $ErrorRecord.Exception
    while ($exception) {
      if ($exception.PSObject.Properties['Response'] -and $exception.Response) {
        return $exception.Response
      }
      $exception = $exception.InnerException
    }
    $null
  }

  # Follows a download's redirects one at a time, checking each host, and
  # returns the address the file itself is at. Invoke-WebRequest would follow
  # them without showing where they lead.
  function Resolve-Download([string]$Url, [string[]]$Hosts) {
    $uri = [Uri]$Url
    for ($hop = 0; $hop -lt 10; $hop++) {
      Assert-Host $uri $Hosts
      $request = [Net.WebRequest]::Create($uri)
      $request.Method = 'GET'
      $request.AllowAutoRedirect = $false
      $request.UserAgent = $UserAgent
      $request.Timeout = 60000
      $response = $null
      try {
        try {
          $response = $request.GetResponse()
        } catch {
          $response = Get-ErrorResponse $_
          if (-not $response) {
            Stop-Install "Couldn't reach $($uri.Host): $($_.Exception.Message)"
          }
        }
        $status = [int]$response.StatusCode
        if ($status -ge 300 -and $status -lt 400) {
          $location = $response.Headers['Location']
          if (-not $location) {
            Stop-Install "$($uri.Host) redirected without saying where to."
          }
          $uri = New-Object Uri ($uri, $location)
          Write-Log "Redirected to $($uri.Scheme)://$($uri.Host)$($uri.AbsolutePath)"
          continue
        }
        if ($status -ne 200) {
          Stop-Install "$($uri.Host) answered HTTP $status for $($uri.AbsolutePath)."
        }
        return $uri
      } finally {
        # Aborting first closes the connection without downloading the rest.
        $request.Abort()
        if ($response) {
          try {
            $response.Close()
          } catch {
          }
        }
      }
    }
    Stop-Install "Too many redirects from $Url."
  }

  function Save-Download([string]$Url, [string]$Path) {
    $final = Resolve-Download $Url $DownloadHosts
    Invoke-WebRequest -Uri $final -OutFile $Path -UseBasicParsing -MaximumRedirection 0 -UserAgent $UserAgent -ErrorAction Stop
  }

  function Get-Json([string]$Url) {
    Assert-Host ([Uri]$Url) $ApiHosts
    $headers = @{ 'X-GitHub-Api-Version' = '2022-11-28' }
    try {
      $response = Invoke-WebRequest -Uri $Url -Headers $headers -UseBasicParsing -MaximumRedirection 0 -UserAgent $UserAgent -ErrorAction Stop
    } catch {
      $failed = Get-ErrorResponse $_
      $status = 0
      if ($failed) {
        $status = [int]$failed.StatusCode
      }
      if ($status -eq 403 -or $status -eq 429) {
        Stop-Install ("GitHub has had too many requests from this network for now (it allows 60 an hour). " +
          "Try again in an hour, or download the installer from $ReleasesPage")
      }
      if ($status -eq 404) {
        return $null
      }
      Stop-Install "Couldn't reach GitHub ($Url): $($_.Exception.Message)"
    }
    $response.Content | ConvertFrom-Json
  }

  function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  }

  # The SHA-256 that SHA256SUMS.txt (sha256sum's format) gives for a file.
  function Get-ListedSha256([string]$SumsPath, [string]$Name) {
    foreach ($line in [IO.File]::ReadAllLines($SumsPath)) {
      if ($line -match '^\s*([0-9A-Fa-f]{64}) [ *](.+?)\s*$' -and $Matches[2] -eq $Name) {
        return $Matches[1].ToLowerInvariant()
      }
    }
    $null
  }

  # Compares a file with the API's digest for it ("sha256:<hex>"), if given.
  function Assert-Digest([string]$Path, $Asset, [string]$Actual) {
    $digest = $null
    if ($Asset.PSObject.Properties['digest']) {
      $digest = [string]$Asset.digest
    }
    if (-not $digest) {
      Write-Log "GitHub gives no digest for $($Asset.name)."
      return
    }
    if ($digest -notmatch '^sha256:([0-9A-Fa-f]{64})$') {
      Write-Log "GitHub's digest for $($Asset.name) isn't SHA-256 ($digest); not compared."
      return
    }
    if ($Matches[1].ToLowerInvariant() -ne $Actual) {
      Stop-Install ("$($Asset.name) doesn't match the SHA-256 that GitHub lists for it, so nothing was installed. " +
        "Expected $($Matches[1].ToLowerInvariant()), got $Actual.")
    }
    Write-Log "$($Asset.name) matches GitHub's digest."
  }

  function Get-TagVersion([string]$Tag) {
    if ($Tag -match '^v(\d+)\.(\d+)\.(\d+)$') {
      return [version]('{0}.{1}.{2}' -f $Matches[1], $Matches[2], $Matches[3])
    }
    $null
  }

  function Find-Asset($Release, [string]$Name) {
    foreach ($asset in @($Release.assets)) {
      if ($asset.name -eq $Name) {
        return $asset
      }
    }
    $null
  }

  # The release to install: SM_TAG's, or the newest published release, a
  # pre-release or not (never a draft), that has the Windows installer.
  function Find-Release {
    if ($env:SM_TAG) {
      $tag = $env:SM_TAG.Trim()
      if (-not (Get-TagVersion $tag)) {
        Stop-Install "SM_TAG must be a release tag such as v0.0.1, not '$tag'."
      }
      Write-Step "Looking for Shnayim Mikrah $tag..."
      $release = Get-Json ($TagApi + $tag)
      if (-not $release -or $release.draft) {
        Stop-Install "There is no published release $tag. The releases are at $ReleasesPage"
      }
      $version = Get-TagVersion $tag
      $msi = Find-Asset $release "ShnayimMikrah-$version-windows-x64.msi"
      if (-not $msi) {
        Stop-Install "Release $tag has no Windows installer (ShnayimMikrah-$version-windows-x64.msi)."
      }
      return New-Object PSObject -Property @{ Release = $release; Version = $version; Msi = $msi }
    }

    Write-Step 'Looking for the newest release of Shnayim Mikrah...'
    $releases = Get-Json $ReleasesApi
    $best = $null
    foreach ($release in @($releases)) {
      if ($release.draft) {
        continue
      }
      $version = Get-TagVersion ([string]$release.tag_name)
      if (-not $version) {
        continue
      }
      $msi = Find-Asset $release "ShnayimMikrah-$version-windows-x64.msi"
      if (-not $msi) {
        continue
      }
      if (-not $best -or $version -gt $best.Version) {
        $best = New-Object PSObject -Property @{ Release = $release; Version = $version; Msi = $msi }
      }
    }
    if (-not $best) {
      Stop-Install "No release has a Windows installer yet. The releases are at $ReleasesPage"
    }
    $best
  }

  # The app's processes in this Windows session (not another user's).
  function Get-AppProcess {
    $session = [Diagnostics.Process]::GetCurrentProcess().SessionId
    @(Get-Process -Name 'shnayim_mikrah' -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $session })
  }

  # Waits for the app to close: the updater's process first, then any other
  # copy that is open, since Windows can't replace the files of a running app.
  function Wait-ForApp {
    if ($env:SM_WAIT_PID) {
      $id = 0
      if (-not [int]::TryParse($env:SM_WAIT_PID.Trim(), [ref]$id)) {
        Stop-Install "SM_WAIT_PID must be a process id, not '$($env:SM_WAIT_PID)'."
      }
      $process = Get-Process -Id $id -ErrorAction SilentlyContinue
      if ($process -and $process.ProcessName -eq 'shnayim_mikrah') {
        Write-Step 'Waiting for Shnayim Mikrah to close...'
        if (-not $process.WaitForExit(60000)) {
          Stop-Install 'Shnayim Mikrah did not close within 60 seconds, so nothing was installed. Close it, then try again.'
        }
      } elseif ($process) {
        Write-Log "Process $id is $($process.ProcessName), not the app; not waiting for it."
      }
    }
    if ((Get-AppProcess).Count -gt 0) {
      Write-Step 'Shnayim Mikrah is open. Please close it to continue (this waits up to 2 minutes).'
      $deadline = (Get-Date).AddMinutes(2)
      while ((Get-AppProcess).Count -gt 0) {
        if ((Get-Date) -gt $deadline) {
          Stop-Install 'Shnayim Mikrah is still open, so nothing was installed. Close it, then try again.'
        }
        Start-Sleep -Seconds 1
      }
    }
  }

  function Install-Msi([string]$MsiPath) {
    Wait-ForApp
    Unblock-File -LiteralPath $MsiPath
    $ui = '/passive'
    if ($env:SM_QUIET -eq '1') {
      $ui = '/qn'
    }
    Write-Step 'Installing for this Windows account (no administrator rights needed)...'
    $arguments = "/i `"$MsiPath`" $ui /norestart /l*v `"$MsiLogPath`""
    Write-Log "msiexec $arguments"
    $msiexec = Join-Path $env:SystemRoot 'System32\msiexec.exe'
    $process = Start-Process -FilePath $msiexec -ArgumentList $arguments -PassThru
    # Reading the handle now keeps the exit code readable once it ends.
    $null = $process.Handle
    $process.WaitForExit()
    $code = $process.ExitCode
    Write-Log "msiexec exited with $code."
    switch ($code) {
      0 { return }
      3010 {
        Write-Step 'Windows asks for a restart to finish, at your convenience.'
        return
      }
      1602 { Stop-Install 'The installation was cancelled.' }
      1618 { Stop-Install 'Another installation is running. Wait for it to finish, then try again.' }
      1603 {
        Stop-Install ("Windows Installer couldn't finish (error 1603). If a newer version of Shnayim Mikrah is installed, " +
          "uninstall it first in Settings > Apps > Installed apps. The details are in $MsiLogPath")
      }
      default { Stop-Install "Windows Installer stopped with error $code. The details are in $MsiLogPath" }
    }
  }

  function Start-App {
    if ($env:SM_NO_LAUNCH -eq '1') {
      return
    }
    if (-not (Test-Path -LiteralPath $AppExe)) {
      Stop-Install "The install finished, but $AppExe isn't there."
    }
    Write-Step 'Starting Shnayim Mikrah...'
    Start-Process -FilePath $AppExe -WorkingDirectory $InstallDir
  }

  # --- Main ---

  $work = $null
  try {
    if ($env:OS -ne 'Windows_NT' -or -not $env:LOCALAPPDATA) {
      Stop-Install "This installer is for Windows. The other ways to get Shnayim Mikrah are at $ReleasesPage"
    }
    if (-not [Environment]::Is64BitOperatingSystem) {
      Stop-Install 'Shnayim Mikrah needs 64-bit Windows 10 or 11.'
    }
    if ((Test-Path -LiteralPath $LogPath) -and (Get-Item -LiteralPath $LogPath).Length -gt 1MB) {
      Move-Item -LiteralPath $LogPath -Destination "$LogPath.old" -Force
    }
    Write-Host ''
    Write-Host 'Shnayim Mikrah installer'
    Write-Log "Started in PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))."

    # TLS 1.2 or later: Windows PowerShell 5.1 may offer only TLS 1.0 and
    # 1.1, which GitHub refuses. (The system default, 0, already has 1.2.)
    $protocols = [Net.ServicePointManager]::SecurityProtocol
    if ([int]$protocols -ne 0) {
      [Net.ServicePointManager]::SecurityProtocol = $protocols -bor [Net.SecurityProtocolType]::Tls12
    }

    $label = 'Shnayim Mikrah'
    if ($env:SM_MSI) {
      # A local MSI, for testing: no download.
      if (-not (Test-Path -LiteralPath $env:SM_MSI -PathType Leaf)) {
        Stop-Install "SM_MSI names no file: $($env:SM_MSI)"
      }
      $msiPath = (Resolve-Path -LiteralPath $env:SM_MSI).ProviderPath
      Write-Step "Installing the local file $msiPath (SM_MSI)."
      if ($env:SM_SHA256) {
        $expected = $env:SM_SHA256.Trim().ToLowerInvariant()
        if ($expected -notmatch '^[0-9a-f]{64}$') {
          Stop-Install 'SM_SHA256 must be 64 hexadecimal digits.'
        }
        Write-Step 'Checking the file...'
        $actual = Get-Sha256 $msiPath
        if ($actual -ne $expected) {
          Stop-Install "$msiPath doesn't match SM_SHA256, so nothing was installed. Expected $expected, got $actual."
        }
        Write-Log 'The file matches SM_SHA256.'
      } else {
        Write-Step 'Not checking its SHA-256 (SM_SHA256 is not set).'
      }
    } else {
      $found = Find-Release
      $tag = [string]$found.Release.tag_name
      $kind = 'release'
      if ($found.Release.prerelease) {
        $kind = 'preview'
      }
      $label = "Shnayim Mikrah $($found.Version)"
      Write-Step "Found $label ($kind, $tag)."
      $sums = Find-Asset $found.Release 'SHA256SUMS.txt'
      if (-not $sums) {
        Stop-Install "Release $tag has no SHA256SUMS.txt to check the installer against, so nothing was installed."
      }

      $work = Join-Path $env:TEMP ('ShnayimMikrah-' + [guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Force -Path $work | Out-Null
      $msiPath = Join-Path $work $found.Msi.name
      $sumsPath = Join-Path $work 'SHA256SUMS.txt'

      $megabytes = '{0:N1}' -f ($found.Msi.size / 1MB)
      Write-Step "Downloading the installer ($megabytes MB)..."
      Save-Download $found.Msi.browser_download_url $msiPath
      Save-Download $sums.browser_download_url $sumsPath

      Write-Step 'Checking the download...'
      Assert-Digest $sumsPath $sums (Get-Sha256 $sumsPath)
      $expected = Get-ListedSha256 $sumsPath $found.Msi.name
      if (-not $expected) {
        Stop-Install "SHA256SUMS.txt doesn't list $($found.Msi.name), so nothing was installed."
      }
      $actual = Get-Sha256 $msiPath
      if ($actual -ne $expected) {
        Stop-Install ("The download doesn't match SHA256SUMS.txt, so nothing was installed. " +
          "Expected $expected, got $actual. Try again; if it happens again, report it at $ReleasesPage")
      }
      Assert-Digest $msiPath $found.Msi $actual
      Write-Step 'The download is intact.'
    }

    Install-Msi $msiPath
    Write-Step "$label is installed. It is in the Start menu."
    Start-App
    Write-Log 'Done.'
  } catch {
    $reason = $_.Exception.Message
    Write-Log "FAILED: $reason"
    Write-Host ''
    if ($FromUpdater) {
      Write-Host "Shnayim Mikrah wasn't updated: $reason" -ForegroundColor Red
      Write-Host "The steps are logged in $LogPath"
      # The updater closed the app for this: open it again, as it was. (A
      # failed install leaves the old version in place.)
      if ($env:SM_NO_LAUNCH -ne '1' -and (Test-Path -LiteralPath $AppExe)) {
        try {
          Start-Process -FilePath $AppExe -WorkingDirectory $InstallDir
        } catch {
          Write-Log "Couldn't start the app again: $($_.Exception.Message)"
        }
      }
      # This window closes when the script ends: leave time to read it.
      Write-Host 'This window closes in 20 seconds.'
      Start-Sleep -Seconds 20
    } else {
      Write-Host "The steps are logged in $LogPath"
    }
    # Through iex, the error shows in red and the window stays open; run as
    # a file (powershell -File), the exit code is 1.
    throw "Shnayim Mikrah was not installed: $reason"
  } finally {
    if ($work -and (Test-Path -LiteralPath $work)) {
      Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
