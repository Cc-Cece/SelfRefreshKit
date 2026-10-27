# SelfRefreshKit

**English** | [简体中文](README_ZH.md)

**SelfRefreshKit** is a lightweight, native SwiftUI on-device provisioning profile auto-refresh and cloud OTA self-upgrade library for sideloaded iOS applications ([https://github.com/Cc-Cece/SelfRefreshKit/](https://github.com/Cc-Cece/SelfRefreshKit/), MIT License).

It strips away bloated app-store and multi-source management overhead, focusing purely on **1-second seamless 7-day provisioning profile refresh** and **on-device IPA resigning / cloud OTA self-upgrades**. Designed to work out-of-the-box with the free **[LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6744003051)** on the App Store, while remaining fully compatible with **StosVPN** and **WireGuard**.

---

## Key Features

1. **Clean Two-Tier Native iOS UI (`Form` + `.insetGrouped`)**
   - **Main Screen (`SelfRefreshView`)**: Displays only **Current Status** (`Profile Validity` + `Refresh Now`), navigation entries to secondary pages, **Component Language Picker**, and **About Component**.
   - **Secondary Pages**:
     - **Required Setup (`SelfRefreshRequiredSetupView`)**: 3-step onboarding checklist (Import Device Pairing File, Apple Developer Authentication with 2FA & Keychain session persistence, and Initial Local Signing Takeover).
     - **Health Status Check (`SelfRefreshHealthCheckView`)**: 4-point live diagnostics (Pairing File + RPPairing keys, `10.7.0.1` Loopback VPN interface, Anisette V3 server latency, and Apple Developer session).
     - **Optional Actions (`SelfRefreshOptionalActionsView`)**: Background Shortcuts automation, preferred VPN selector, configurable GitHub Releases OTA self-upgrade (with 2-step security confirmation), direct `.ipa` URL download & install dialog, and local `.ipa` resigning.
2. **Standard 7-Language Localization (`.lproj/Localizable.strings` + `SelfRefreshL10nKey`)**
   - Built-in support for **English (`en`), Simplified Chinese (`zh-Hans`), Cantonese / Traditional HK (`yue-Hant-HK`), Japanese (`ja`), German (`de`), French (`fr`), and Korean (`ko`)**.
   - **Resolution Priority**: Manual user selection $\rightarrow$ Host app language (`hostLanguageProvider`) $\rightarrow$ Automatic fallback to **English (`en`)**.
3. **Dual-Mode Signing Engine**
   - **1-Second Profile-Only Mode (`refreshProfileOnly`)**: Updates only the ~15 KB `.mobileprovision` file via `misagent` without restarting the app or keeping a duplicate `.ipa` in sandbox storage.
   - **Full Resign & Install Mode (`resignAndInstall`)**: Used once for initial local certificate takeover after computer sideloading, and anytime for cable-free cloud OTA updates or direct `.ipa` URL installations.

---

## Shortcuts

`SelfRefreshKit` includes a built-in background `AppIntent` (**`Refresh App Provisioning Profile`**) with `openAppWhenRun = false` and localized `.lproj` titles across all 7 supported languages. When triggered by Apple Shortcuts, it refreshes your 7-day provisioning profile **silently in the background without opening or switching to the app**.

[![Get Auto-Refresh Shortcut](https://img.shields.io/badge/_Shortcuts-Get_Auto--Refresh_Shortcut-007AFF?style=for-the-badge)](https://www.icloud.com/shortcuts/7f3fabf7fa234031bd1d22249bc7f84a)

### Automated Background Setup Steps

1. Tap the button above to add the official **[Auto-Refresh iCloud Shortcut](https://www.icloud.com/shortcuts/7f3fabf7fa234031bd1d22249bc7f84a)**, or create a new Personal Automation in the system **Shortcuts** app (**Automation** tab $\rightarrow$ **Time of Day**, e.g. `04:00 AM` daily, select **Run Immediately**).
2. Add action: **Connect LocalDevVPN**, followed by **Wait 2 seconds**.
3. Add action: Search for your host app and select **Refresh App Provisioning Profile** (runs silently in background).
4. Add action: **Wait 5 seconds**, then **Disconnect LocalDevVPN**.

---

## Quick Integration (2 Steps)

### 1. Configure on App Startup

```swift
import SwiftUI
import SelfRefreshKit

@main
struct MyApp: App {
    init() {
        SelfRefreshManager.shared.configure(
            SelfRefreshConfiguration(
                urlScheme: "myapp",
                preferredVPN: .localDevVPN,
                githubRepository: "yourname/MyApp", // Optional: enables GitHub Releases OTA self-upgrade
                hostLanguageProvider: { MyAppL10n.currentLanguageCode } // Optional: follows host app language, falls back to English
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Embed in Host Settings Screen

```swift
import SwiftUI
import SelfRefreshKit

struct SettingsView: View {
    var body: some View {
        List {
            Section("Signing & Maintenance") {
                SelfRefreshSection()
            }
        }
    }
}
```

---

## License

Released under the **MIT License**. See [LICENSE](LICENSE) for details.
