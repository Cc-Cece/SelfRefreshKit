# SelfRefreshKit

**SelfRefreshKit** 是一个轻量级、纯原生 SwiftUI 风格的 iOS 应用内置自续签与云端 OTA 更新通用组件库（MIT 开源）。

它剥离了 SideStore 臃肿的应用商店与多源管理代码，只保留最核心的**「7 天描述文件极速无感刷新」**与**「首次证书夺权 / 云端未签名 IPA 自签名 OTA 升级」**能力。默认推荐配合 App Store 免费的 **[LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6744003051)** 使用，同时无缝兼容 **StosVPN** 与 **WireGuard**。

---

## 核心特性

1. **100% iOS 原生极简 UI (`Form` + `.insetGrouped`)**
   - 提供一行式设置入口组件 `SelfRefreshSection()` 与完整管理页 `SelfRefreshView()`，零违和感融入任何宿主 App 的设置页面。
2. **双模式续签引擎**
   - **日常 1 秒极速模式 (`refreshProfileOnly`)**：仅更新 ~15KB 的 `.mobileprovision` 描述文件并注入系统 `misagent` 服务，**App 不闪退、平时无需在沙盒常备双倍体积的 `.ipa` 母本**。
   - **完整重签模式 (`resignAndInstall`)**：一鱼两吃，既用于首次从电脑（如 Windows Sideloadly）安装后的手机端证书夺权，也用于拉取 GitHub Actions 构建的未签名 `.ipa` 完成免数据线自我 OTA 升级。
3. **默认推荐 `LocalDevVPN`（兼容其它）**
   - 底层通过检测虚拟网卡 `10.7.0.1` 与本地 `lockdownd` 握手，天然兼容 `LocalDevVPN`、`StosVPN` 与 `WireGuard`。
4. **内置快捷指令集 (`AppIntents` & URL Scheme)**
   - 内置 iOS 原生 `SelfRefreshProfileIntent` 及自定义唤醒链接（如 `myapp://refresh`），用户可在系统「快捷指令 -> 自动化」中定时串联：`开启 LocalDevVPN ➔ 刷新应用签名 ➔ 断开 VPN`。
5. **内置组件关于与版本标识**
   - 页面底部内置紧凑的「关于组件」区块，清晰展示当前 `SelfRefreshKit` 版本与底层 `minimuxer` / `AltSign` 引擎版本。

---

## 快速接入（仅需 2 步）

### 1. 在宿主 App 启动时初始化配置

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
                githubRepository: "yourname/MyApp" // 可选：开启云端 OTA 自签名升级
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // 支持快捷指令 myapp://refresh 唤醒自动续签
                    SelfRefreshManager.shared.handleOpenURL(url)
                }
        }
    }
}
```

### 2. 在宿主 App 的设置页嵌入入口

```swift
import SwiftUI
import SelfRefreshKit

struct SettingsView: View {
    var body: some View {
        List {
            Section("开发者与签名维护") {
                SelfRefreshSection()
            }
        }
    }
}
```

---

## 开源许可 (License)

本项目基于 **MIT License** 开源，详见 [LICENSE](LICENSE)。
