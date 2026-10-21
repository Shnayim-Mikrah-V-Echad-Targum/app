A preview of Shnayim Mikrah, for trying the app out before its first full release: reading the weekly parsha twice in Hebrew and once in Targum, on Windows, on the web and on Android. Things may still change; please tell us what you find.

## Windows 10 and 11

In PowerShell, run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/Shnayim-Mikrah-V-Echad-Targum/app/main/tool/windows/install.ps1 | iex
```

It downloads the newest release's installer, checks it against `SHA256SUMS.txt`, installs it for your Windows account (no administrator rights needed) and opens the app. The app then offers each new preview itself, under *About → Updates*.

Or download **ShnayimMikrah-{{VERSION}}-windows-x64.msi** below and open it. It isn't signed yet, so Windows may first say that it protected your PC: choose *More info*, then *Run anyway*. **ShnayimMikrah-{{VERSION}}-windows-x64.zip** is the same app as a folder, to run without installing (`shnayim_mikrah.exe`).

## On the web, phones and tablets

Open **https://shnayimmikrah.org/**. On a phone or tablet, add it to your home screen and it opens like an app, offline too: in Chrome, *Install app* or *Add to home screen* in the menu; on an iPhone or iPad, in Safari, *Share → Add to Home Screen*.

## Android

**ShnayimMikrah-{{VERSION}}-android-webapp.apk** is the web app as an Android app: it opens https://shnayimmikrah.org/ full screen, with the app's icon. Open the file on the phone, and allow your browser or file manager to install apps when Android asks.

<!-- throwaway-key -->
This preview's Android APK and later ones are signed with different keys, so a later one won't install over this one. To move to a later one: export a backup (*Settings → Your data → Export my progress*), uninstall this app, then install the new one and import the backup there (*Import progress*).
<!-- /throwaway-key -->
<!-- permanent-key -->
This APK is signed with the Android web app's permanent key, so later ones install over it. If you have a preview APK from before, which was signed with another key, export a backup from it (*Settings → Your data → Export my progress*), uninstall it, then install this one and import the backup (*Import progress*).
<!-- /permanent-key -->

## Your reading

The community is coming soon. Until then, your reading stays on the device you read on: use *Settings → Your data* and its backups to move it to another device or browser, and export a backup before you reinstall.

## Files

| File | What it is |
|---|---|
| `ShnayimMikrah-{{VERSION}}-windows-x64.msi` | The Windows installer, for your account alone |
| `ShnayimMikrah-{{VERSION}}-windows-x64.zip` | The Windows app as a folder |
| `ShnayimMikrah-{{VERSION}}-android-webapp.apk` | The Android web app |
| `install.ps1` | The Windows install script that the line above runs |
| `SHA256SUMS.txt` | Each file's SHA-256, for `sha256sum -c SHA256SUMS.txt`, or PowerShell's `Get-FileHash` |
