# SelfRefreshKit

**SelfRefreshKit** 是一个轻量级、纯原生 SwiftUI 风格的 iOS 应用内置自续签与云端 OTA 更新通用组件库（[https://github.com/Cc-Cece/SelfRefreshKit/](https://github.com/Cc-Cece/SelfRefreshKit/)，MIT 开源）。

它剥离了 SideStore 臃肿的应用商店与多源管理代码，只保留最核心的**「7 天描述文件极速无感刷新」**与**「首次证书夺权 / 云端未签名 IPA 自签名 OTA 升级」**能力。默认推荐配合 App Store 免费的 **[LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6744003051)** 使用，同时无缝兼容 **StosVPN** 与 **WireGuard**。

---

## 核心特性

1. **清爽分层原生 UI (`Form` + `.insetGrouped`)**
   - **主页面**：仅保留「当前状态」、二级功能入口与「关于组件」（含官方仓库 [https://github.com/Cc-Cece/SelfRefreshKit/](https://github.com/Cc-Cece/SelfRefreshKit/)）。
   - **二级页面**：将「必需操作（3 步）」、「健康状态检查（4 项诊断）」与「可选操作（静默续签、云端 OTA、快捷指令自动化）」独立拆分至二级页面，层次清晰。
2. **内置 7 国语言与宿主自适应**
   - 原生内置：**简体中文 (`zh-Hans`)、English (`en`)、粤语 (`yue-Hant-HK`)、日本語 (`ja`)、Deutsch (`de`)、Français (`fr`)、한국어 (`ko`)**。
   - 优先级：**优先跟随宿主 App 语言**，若宿主语言不在列表内则**自动回退至英文 (`en`)**，同时支持用户在页面内手动切换组件语言。
3. **纯后台快捷指令 (`Refresh App Provisioning Profile`)**
   - 内置 iOS 原生 `SelfRefreshProfileIntent`（默认英文动作名 **`Refresh App Provisioning Profile`**，设置 `openAppWhenRun = false`），在系统「快捷指令 -> 自动化」中触发时**纯后台静默运行，不自动跳转或打断前台使用**。
4. **双模式续签引擎**
   - **日常 1 秒极速模式 (`refreshProfileOnly`)**：仅更新 ~15KB 的 `.mobileprovision` 描述文件并注入系统 `misagent` 服务，**App 不闪退、平时无需在沙盒常备双倍体积的 `.ipa` 母本**。
   - **完整重签模式 (`resignAndInstall`)**：既用于首次从电脑（如 Windows Sideloadly）安装后的手机端证书夺权，也用于拉取 GitHub Actions 构建的未签名 `.ipa` 完成免数据线自我 OTA 升级。

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
                githubRepository: "yourname/MyApp", // 可选：开启云端 OTA 自签名升级
                hostLanguageProvider: { MyAppL10n.currentLanguageCode } // 可选：实时跟随宿主语言，未匹配回退英文
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
