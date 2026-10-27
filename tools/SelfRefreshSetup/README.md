<div align="center">

<img src="Assets/SelfRefreshKit.png" width="96" height="96" alt="SelfRefreshKit Setup" />

# SelfRefreshKit Setup

Windows utility for first-time installation and pairing injection of SelfRefreshKit-enabled iOS apps.

[![Platform: Windows](https://img.shields.io/badge/Platform-Windows_x64-blue?logo=windows&logoColor=white)](https://microsoft.com/windows)
[![Runtime: .NET 10](https://img.shields.io/badge/.NET-10.0_Desktop-512BD4?logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/download/dotnet/10.0)
[![Release](https://img.shields.io/github/v/release/Cc-Cece/SelfRefreshKit?color=007AFF&logo=github)](https://github.com/Cc-Cece/SelfRefreshKit/releases)

<p align="center">
  <b>English</b> | <a href="README_ZH.md">简体中文</a>
</p>

</div>

---

A single-window utility to perform the initial installation and pairing setup for any app integrating SelfRefreshKit. It reads the Bundle ID directly from the IPA file and is not tied to a specific host app.

Subsequent 7-day renewals are completed on the iPhone. This utility does not replace LocalDevVPN.

> [!NOTE]
> All commands are executed from the repository root.

## Portable Release

The `SelfRefreshKit.exe` under GitHub Releases is a single standalone file. It includes the signing engine and a trimmed Python runtime; no separate Rust or Python installation is required.

**Requirements**:
- [.NET 10 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/10.0) (Windows Desktop Runtime, or .NET 10 SDK)
- iTunes or the "Apple Devices" app from the Microsoft Store (for drivers)
- Lightning / USB-C cable
- iPhone unlocked, computer trusted, and Developer Mode enabled

## Usage

1. Connect your iPhone via USB and tap "Trust This Computer" if prompted.
2. Open the program and click **Select IPA**.
3. For unsigned packages, enter your Apple ID and password, then click **Save**. Account details are encrypted with Windows DPAPI and stored in `%LOCALAPPDATA%\SelfRefreshSetup\accounts.json`. Passwords are not saved in plain text or written to logs. The Anisette field can be left empty to use the built-in address.
4. Click **Refresh** and select the iPhone from the device list.
5. Click the main button (**Install and Write Pairing** for signed packages, or **Sign, Install and Write Pairing** for unsigned packages).
6. If Apple requests a verification code, an input box will appear at the bottom of the window. Enter the code from your trusted device and submit.
7. Setup is complete once the log shows the pairing file has been written without errors (`Documents/SelfRefreshKit/pairing.mobiledevicepairing`).

> [!NOTE]
> 
> - On iOS 17.4 and later, RPPairing credentials are written; for iOS versions below 17.4, Lockdown pairing records are written.

### Additional Actions

- **Save Unsigned Copy**: Generates an unsigned package with `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` enabled for third-party installation tools. Does not perform installation.
- **Export Pairing File**: Saves the pairing file to a chosen local directory for backup after selecting the device. Does not sign or install.

## After Installation

1. Force close the app on the iPhone and reopen it to load the newly written pairing file.
2. Open LocalDevVPN (or StosVPN / WireGuard) and tap refresh.

## Building from Source

**Build Requirements**:
- Windows
- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- Rust (`cargo`)
- Local Python 3.11

The signing engine is based on [isideload](https://github.com/nab138/isideload) (commit `065e852`, MIT).

Run from the repository root:

```powershell
powershell -File tools/SelfRefreshSetup/publish.ps1
```

The output file is `tools/SelfRefreshSetup/dist/SelfRefreshKit.exe`.

Commands for local development and debugging:

```powershell
py -3.11 -m pip install pymobiledevice3==11.45.0
dotnet build tools/SelfRefreshSetup/SelfRefreshSetup.csproj
```
