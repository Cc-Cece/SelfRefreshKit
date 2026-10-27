# SelfRefreshKit

<img src="Assets/SelfRefreshKit.png" width="100" height="96" alt="SelfRefreshKit">

一个窗口，给任意使用 SelfRefreshKit 的 App 做第一次安装和配对。它从 IPA 里读取 Bundle ID，不绑定某一个宿主。

每天的 7 天续签仍在手机上完成。这个窗口不代替 LocalDevVPN。

命令都在仓库根目录执行。

## 便携版

GitHub Release 里的 `SelfRefreshKit.exe` 是单个文件。复制到任意目录后直接打开。它自带签名程序和一份裁过的 Python 运行库，不需要另装 Rust 或 Python。

需要本机已安装 [.NET 10 桌面运行时](https://dotnet.microsoft.com/download/dotnet/10.0)（Windows Desktop Runtime，不是只装 ASP.NET）。已安装 .NET 10 SDK 的机器也满足。仍需要 Windows、iTunes 或 Microsoft Store 的「Apple 设备」，以及数据线。手机保持解锁，并已打开开发者模式。

推送 `v*` 标签时，GitHub Action 会编译这个文件并发布到对应的 Release。

## 从源码编译

编译机需要：

- Windows
- [.NET SDK 10](https://dotnet.microsoft.com/download)
- Rust（`cargo`）
- 能访问 GitHub 和 python.org

签名程序依赖 [isideload](https://github.com/nab138/isideload) 的提交 `065e852b2092f1386c88195ea3a6506f6b917742`（0.5.0，MIT）。编译时从 GitHub 拉取这份源码，不修改它。`archive/isideload` 只是本地临时克隆，不参与编译，也不用提交。

在仓库根目录执行：

```powershell
powershell -File tools/SelfRefreshSetup/publish.ps1
```

输出是 `tools/SelfRefreshSetup/dist/SelfRefreshKit.exe` 这一个文件。脚本会编译签名程序，准备 Python 3.11 和 pymobiledevice3 11.45.0 里实际用到的部分，再把它们和窗口打进这个 exe。窗口依赖系统里的 .NET 10 桌面运行时，不把运行时打进文件。

开发调试仍可以用本机的 Python 3.11：

```powershell
py -3.11 -m pip install pymobiledevice3==11.45.0
dotnet build tools/SelfRefreshSetup/SelfRefreshSetup.csproj
```

## 使用

1. 用数据线连接 iPhone。如果弹出「信任此电脑」，点信任。
2. 打开窗口，点「选择 IPA」。
3. 未签名的包填写 Apple ID 和密码。点「保存」后，这个账号会出现在「已保存的账号」里。列表会记住 Apple ID、密码和 Anisette，下次打开窗口会填回上次使用的账号，也可以从列表切换。开始签名时同样会记住这次使用的账号。密码留空再点「保存」时，沿用这个账号已经保存的密码。数据在 `%LOCALAPPDATA%\SelfRefreshSetup\accounts.json`。密码用 Windows 当前用户加密，文件里不是明文，也不会写入日志或命令行。验证码不保存。Anisette 可以留空，留空时使用 `https://ani.sidestore.io`。
4. 点「刷新」，在列表里选中这台 iPhone。
5. 点主按钮。已签名的包显示「安装并写入配对」，未签名的包显示「签名、安装并写入配对」。
6. Apple 要求验证码时，窗口下方会出现输入框。优先使用受信任设备上的验证码，再点「提交验证码」。
7. 日志出现配对文件已写入，并且没有报错，这一次才算完成。配对文件在该 App 的 `Documents/SelfRefreshKit/pairing.mobiledevicepairing`。

已经装过同一个 Bundle ID 时，主按钮只重写配对文件，不重复安装。签名后的 IPA 在 `%LOCALAPPDATA%\SelfRefreshSetup\signed\`。

「另存未签名副本」只生成一个打开了文件共享的未签名包，不会安装。安装仍用主按钮。已经签过名的包不会被这个按钮改写。

「导出配对文件」在选中 iPhone 后，把配对文件存到你选择的位置。它不签名、不安装，也不写入手机，用来留一份备用。iOS 17.4 及以上只导出 RPPairing。需要时把这个文件放进 App 的 `Documents/SelfRefreshKit/pairing.mobiledevicepairing`。电脑上还会留一份在 `%LOCALAPPDATA%\SelfRefreshSetup\pairing\`。

iOS 17.4 及以上只写入 RPPairing。远程配对没建成时会停止，并保留已经装上的 App。这种情况下不要拿 Lockdown 配对文件去续签。低于 iOS 17.4 时写入 Lockdown 配对。

## 装好之后

1. 把 App 完全划掉，再重新打开。它会读刚才写入的配对文件。
2. 在组件里确认「iOS 17+ RPPairing」显示为有。
3. 打开 LocalDevVPN、StosVPN 或 WireGuard，再点续签。

开发者模式、解锁和信任仍在手机上确认。没有接上 iPhone，就不能完成第一次安装。未签名的包还需要 Apple ID 和密码。

## 窗口会做的事

1. 读取 IPA 的显示名称和 Bundle ID。
2. 列出 USB 上的 iPhone。
3. 已签名的 IPA（同时有 `embedded.mobileprovision` 和 `_CodeSignature`）会安装，然后写入配对文件。
4. 未签名的 IPA：手机上还没有这个 Bundle ID 时，用窗口里的 Apple ID 签名后再安装。签名前会在宿主 Info.plist 里打开 `UIFileSharingEnabled` 和 `LSSupportsOpeningDocumentsInPlace`。
5. 已有的 App ID 会沿用。原来的标识不能新建时，才改用 `原标识.TeamID`。App ID 数量到上限时直接提示，不删除已有的。
6. 开发证书到上限时，撤销一张最早到期的，并且只撤销一次。
7. 签名如果改了 Bundle ID，配对文件写入签名后的那个 App。
