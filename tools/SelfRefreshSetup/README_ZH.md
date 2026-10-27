<div align="center">

<img src="Assets/SelfRefreshKit.png" width="96" height="96" alt="SelfRefreshKit Setup" />

# SelfRefreshKit Setup

用于 SelfRefreshKit 应用首次安装与配对文件注入的 Windows 工具。

[![Platform: Windows](https://img.shields.io/badge/Platform-Windows_x64-blue?logo=windows&logoColor=white)](https://microsoft.com/windows)
[![Runtime: .NET 10](https://img.shields.io/badge/.NET-10.0_Desktop-512BD4?logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/download/dotnet/10.0)
[![Release](https://img.shields.io/github/v/release/Cc-Cece/SelfRefreshKit?color=007AFF&logo=github)](https://github.com/Cc-Cece/SelfRefreshKit/releases)

<p align="center">
  <a href="README.md">English</a> | <b>简体中文</b>
</p>

</div>

---

一个单窗口工具，用于给集成 SelfRefreshKit 的任意应用进行首次安装和配对。它从 IPA 中读取 Bundle ID，不绑定某一个特定宿主。

日常的 7 天续签仍在手机上完成，本工具不代替 LocalDevVPN。

> [!NOTE]
> 命令均在仓库根目录执行。

## 便携版

GitHub Releases 中的 `SelfRefreshKit.exe` 为单文件程序。自带签名引擎和精简的 Python 运行库，不需要单独安装 Rust 或 Python。

**运行要求**：
- [.NET 10 桌面运行时](https://dotnet.microsoft.com/download/dotnet/10.0)（Windows Desktop Runtime，或已安装 .NET 10 SDK）
- 安装 iTunes 或 Microsoft Store 的「Apple 设备」（提供驱动）
- 数据线连接 iPhone
- 手机保持解锁、信任此电脑，并已开启开发者模式

## 使用方法

1. 用数据线连接 iPhone，若弹出「信任此电脑」请点击信任。
2. 打开程序，点击**「选择 IPA」**。
3. 未签名的包需填写 Apple ID 与密码，点击**「保存」**。账号信息经 Windows DPAPI 加密保存在 `%LOCALAPPDATA%\SelfRefreshSetup\accounts.json`，不会保存明文密码，也不会输出到日志。Anisette 可留空，留空时默认使用内置地址。
4. 点击**「刷新」**，在设备列表中选中该 iPhone。
5. 点击主按钮（已签名包显示「安装并写入配对」，未签名包显示「签名、安装并写入配对」）。
6. Apple 要求验证码时，窗口下方会出现输入框，输入受信任设备上的验证码后提交。
7. 日志输出配对文件已写入且无报错即完成安装。配对文件写入在 App 的 `Documents/SelfRefreshKit/pairing.mobiledevicepairing`。

> [!NOTE]
> 
> - iOS 17.4 及以上写入 RPPairing 配对；低于 iOS 17.4 时写入 Lockdown 配对。

### 辅助功能

- **另存未签名副本**：仅生成打开了 `UIFileSharingEnabled` 与 `LSSupportsOpeningDocumentsInPlace` 的未签名包供第三方工具安装，不执行安装。
- **导出配对文件**：选中 iPhone 后，将配对文件另存到指定位置备用，不执行签名或安装。

## 安装之后

1. 在手机上彻底划掉该 App 并重新打开，以读取写入的配对文件。
3. 打开 LocalDevVPN（或 StosVPN / WireGuard），点击立即续签。

## 从源码编译

**编译环境**：
- Windows
- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- Rust（`cargo`）
- 本地 Python 3.11

签名程序基于 [isideload](https://github.com/nab138/isideload)（提交 `065e852`，MIT）。

在仓库根目录执行：

```powershell
powershell -File tools/SelfRefreshSetup/publish.ps1
```

输出文件为 `tools/SelfRefreshSetup/dist/SelfRefreshKit.exe`。

本地开发与调试命令：

```powershell
py -3.11 -m pip install pymobiledevice3==11.45.0
dotnet build tools/SelfRefreshSetup/SelfRefreshSetup.csproj
```
