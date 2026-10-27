<div align="center">

<img src="tools/SelfRefreshSetup/Assets/SelfRefreshKit.png" width="96" height="96" alt="SelfRefreshKit" />

# SelfRefreshKit

用于 iOS 应用本机签名描述文件刷新与 OTA 更新的 Swift 库。

[![Swift](https://img.shields.io/badge/Swift-5.9+-FA7343?logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-000000?logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Release](https://img.shields.io/github/v/release/Cc-Cece/SelfRefreshKit?color=007AFF&logo=github)](https://github.com/Cc-Cece/SelfRefreshKit/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

<p align="center">
  <a href="README.md">English</a> | <b>简体中文</b>
</p>

</div>

---

SelfRefreshKit 是一个供侧载 iOS 应用集成的 SwiftUI 组件库，用于在手机本地刷新 7 天描述文件，以及通过 GitHub Releases 或直链进行 OTA 更新。

日常描述文件刷新通过本地回环 VPN（`10.7.0.1`）完成，支持 [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6744003051)、StosVPN 和 WireGuard。

> [!NOTE]
> 需要 iOS 17.0+ 和 Swift 5.9+。支持 iOS 17.4+ RPPairing。

## 功能

- **描述文件刷新**：通过回环网络直接向 `misagent` 注入 `.mobileprovision`。应用无需重启，沙盒内也不用留存 IPA 文件。
- **快捷指令后台自动化**：内置 `AppIntent`（刷新应用签名描述文件），可通过快捷指令自动化触发续签。
- **OTA 更新**：从 GitHub Releases 或指定直链下载未签名包，在手机端重签并安装更新。
- **状态与检查界面**：提供一个 SwiftUI 页面，展示证书剩余时间，并检查配对文件、回环网卡、Anisette 延迟和开发者凭据。
- **多语言**：内置英文、简体中文、繁体中文（香港）、日文、德文、法文和韩文。

## 接入步骤

> [!NOTE]
> 参考案例：https://github.com/Cc-Cece/PicHarbor-iOS/

### 1. 添加依赖

在 `Package.swift` 中引入：

```swift
dependencies: [
    .package(url: "https://github.com/Cc-Cece/SelfRefreshKit.git", from: "0.3.0")
]
```

### 2. 启动时配置

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
                githubRepository: "yourname/MyApp", // 可选：用于检测 GitHub Releases 更新
                hostLanguageProvider: { MyAppL10n.currentLanguageCode } // 可选
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

### 3. 嵌入设置页

```swift
import SwiftUI
import SelfRefreshKit

struct SettingsView: View {
    var body: some View {
        List {
            Section("签名与维护") {
                SelfRefreshSection()
            }
        }
    }
}
```

## 快捷指令自动化

1. 添加预设的 [iCloud 快捷指令](https://www.icloud.com/shortcuts/14a2c9d0bb974288a2fe45649949a6ca)
2. 或在「快捷指令」App 中创建个人自动化。
3. 添加操作：**连接 LocalDevVPN**。
4. 添加操作：选择宿主 App 的**「刷新应用签名描述文件」**。
5. 添加操作：然后**断开 LocalDevVPN**。

## 首次安装

首次安装 App 并注入配对记录需要在电脑上进行：

- **[SelfRefreshSetup](tools/SelfRefreshSetup)**：Windows 桌面工具，通过 USB 签名、安装 IPA，并将配对文件或 RPPairing 写入 App 沙盒。可直接在 [Releases](https://github.com/Cc-Cece/SelfRefreshKit/releases) 下载可执行文件。
