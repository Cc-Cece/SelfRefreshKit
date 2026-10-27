# SelfRefreshKit

[English](README.md) | **简体中文**

**SelfRefreshKit** 是一个轻量级、纯原生 SwiftUI 风格的 iOS 应用内置自续签与云端 OTA 更新通用组件库（[https://github.com/Cc-Cece/SelfRefreshKit/](https://github.com/Cc-Cece/SelfRefreshKit/)，MIT 开源）。

它剥离了 SideStore 臃肿的应用商店与多源管理代码，只保留最核心的**「7 天描述文件极速无感刷新」**与**「首次证书夺权 / 云端未签名 IPA 自签名 OTA 升级」**能力。默认推荐配合 App Store 免费的 **[LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6744003051)** 使用，同时无缝兼容 **StosVPN** 与 **WireGuard**。

---

## 核心特性

1. **清爽分层原生 UI (`Form` + `.insetGrouped`)**
   - **主页面 (`SelfRefreshView`)**：仅保留「当前状态（描述文件有效期 + 立即续签）」、二级功能导航入口、「组件语言切换」与「关于组件」。
   - **二级页面**：
     - **必需操作 (`SelfRefreshRequiredSetupView`)**：3 步式引导清单（1. 导入设备配对文件、2. 登录 Apple 开发者账号并加密保存会话凭证、3. 首次本机签名接管）。
     - **健康状态检查 (`SelfRefreshHealthCheckView`)**：一键实测配对文件与 RPPairing 密钥、`10.7.0.1` 本地回环网卡、Anisette V3 节点延迟及 Apple 开发者会话状态。
     - **可选操作 (`SelfRefreshOptionalActionsView`)**：后台快捷指令自动化、首选 VPN 切换、可配置的云端更新源（带二次高危安全确认）、输入 IPA 直链下载重签对话框、以及选择本地 IPA 重签安装。
2. **标准 7 国语言资源体系 (`.lproj/Localizable.strings` + `SelfRefreshL10nKey`)**
   - 原生内置：**英语 (`en`)、简体中文 (`zh-Hans`)、粤语 (`yue-Hant-HK`)、日语 (`ja`)、德语 (`de`)、法语 (`fr`)、韩语 (`ko`)**。
   - **优先级策略**：用户手动选择语言 $\rightarrow$ 跟随宿主 App 语言 (`hostLanguageProvider`) $\rightarrow$ 未匹配时自动回退至 **英文 (`en`)**。
3. **双模式续签引擎**
   - **日常 1 秒极速模式 (`refreshProfileOnly`)**：仅更新 ~15KB 的 `.mobileprovision` 描述文件并注入系统 `misagent` 服务，**App 不闪退、平时无需在沙盒常备双倍体积的 `.ipa` 母本**。
   - **完整重签模式 (`resignAndInstall`)**：既用于首次从电脑（如 Windows Sideloadly）安装后的手机端证书夺权，也用于拉取 GitHub Actions 构建的未签名 `.ipa` 或任意 `.ipa` 直链完成免数据线自我升级。

---

## Shortcuts

`SelfRefreshKit` 内置了原生后台快捷指令动作（`SelfRefreshProfileIntent`，设置 `openAppWhenRun = false`，并通过标准 `.lproj` 资源包支持 7 国语言标题展示，默认英文 **`Refresh App Provisioning Profile`** / 中文 **「刷新应用签名描述文件」**）。在自动化触发时**纯后台静默运行，不会自动跳转或打断前台应用**。

[![一键获取自动续签快捷指令](https://img.shields.io/badge/_快捷指令-一键获取自动续签快捷指令-007AFF?style=for-the-badge)](https://www.icloud.com/shortcuts/7f3fabf7fa234031bd1d22249bc7f84a)

### 自动化后台续签配置步骤

1. 点击上方按钮直接获取官方预设的 **[自动续签 iCloud 快捷指令](https://www.icloud.com/shortcuts/7f3fabf7fa234031bd1d22249bc7f84a)**，或者打开系统「快捷指令」App，切换到「自动化」标签页并创建特定时间触发器（如每天 `04:00`，勾选「立即运行」）。
2. 添加动作：**连接 LocalDevVPN**，并添加 **「等待 2 秒」**。
3. 添加动作：搜索本应用并选择 **「刷新应用签名描述文件 / Refresh App Provisioning Profile」**（纯后台静默刷新）。
4. 添加动作：**等待 5 秒**后 **断开 LocalDevVPN**。

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
                githubRepository: "yourname/MyApp", // 可选：开启云端 OTA 自签名升级默认仓库
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
