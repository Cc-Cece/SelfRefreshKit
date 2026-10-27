import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

/// Compact native row designed to be embedded directly inside a host app's `List` or `Form` settings screen.
public struct SelfRefreshSection: View {
    @ObservedObject private var manager = SelfRefreshManager.shared

    public init() {}

    public var body: some View {
        NavigationLink {
            SelfRefreshView()
        } label: {
            HStack {
                Label(manager.localized("签名与自动续期"), systemImage: "checkmark.seal")
                Spacer()
                Text(manager.summaryBadgeText)
                    .font(.subheadline)
                    .foregroundStyle(badgeColor)
            }
        }
        .accessibilityIdentifier("settings.selfRefresh")
    }

    private var badgeColor: Color {
        if !manager.isAllRequiredSetupCompleted {
            return .blue
        }
        guard let meta = manager.profileMetadata else {
            return .secondary
        }
        if meta.remainingDaysAndHours().isExpired {
            return .red
        }
        if meta.isExpiringSoon() {
            return .orange
        }
        return .secondary
    }
}

/// Primary landing view of `SelfRefreshKit`:
/// Keeps only **Current Status**, **Secondary Page Navigation Entries** (Required Setup, Health Check, Optional Actions),
/// **Language Switcher**, and **About Component** (with GitHub Repository link) on the main screen.
public struct SelfRefreshView: View {
    @ObservedObject private var manager = SelfRefreshManager.shared
    @State private var showAboutSheet = false
    @State private var showFeedbackAlert = false

    public init() {}

    public var body: some View {
        Form {
            // Top Feedback Banner
            if let notice = manager.activeNotice {
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: notice.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(notice.isError ? .red : .green)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notice.title)
                                .font(.subheadline.bold())
                            Text(notice.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            manager.activeNotice = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }

            // Main Section 1: Current Status & 1-Second Profile Refresh
            Section {
                LabeledContent(manager.localized("描述文件有效期"), value: expirationStatusText)
                LabeledContent(
                    manager.localized("必需配置进度"),
                    value: "\(manager.completedRequiredStepsCount) / 3 \(manager.localized("已完成"))"
                )

                if manager.isRefreshing {
                    HStack {
                        ProgressView()
                        Text(manager.statusMessage.isEmpty ? manager.localized("正在处理…") : manager.statusMessage)
                            .foregroundStyle(.secondary)
                    }
                } else if manager.isAllRequiredSetupCompleted {
                    Button {
                        Task {
                            do {
                                try await manager.refreshProfileOnly()
                            } catch {
                                // Notice posted by manager
                            }
                            showFeedbackAlert = true
                        }
                    } label: {
                        Text(manager.localized("立即刷新描述文件（1 秒无感续签）"))
                            .fontWeight(.medium)
                    }
                    .accessibilityIdentifier("selfRefresh.primaryAction")
                } else {
                    NavigationLink {
                        SelfRefreshRequiredSetupView()
                    } label: {
                        Label(manager.localized("必需操作"), systemImage: "checklist")
                            .foregroundStyle(.blue)
                            .fontWeight(.medium)
                    }
                    .accessibilityIdentifier("selfRefresh.primaryAction")
                }
            } header: {
                Text(manager.localized("当前状态"))
            } footer: {
                Text(
                    manager.isAllRequiredSetupCompleted
                        ? manager.localized("仅更新描述文件，耗时约 1 秒，应用不会闪退。")
                        : manager.localized("请先进入「必需操作」完成 3 项初始配置，即可解锁 1 秒无感刷新。")
                )
            }

            // Main Section 2: Secondary Subpages (Required Setup, Health Check, Optional Actions)
            Section(manager.localized("功能与检查")) {
                NavigationLink {
                    SelfRefreshRequiredSetupView()
                } label: {
                    HStack {
                        Label(manager.localized("必需操作"), systemImage: "checkmark.shield")
                        Spacer()
                        Text("\(manager.completedRequiredStepsCount) / 3")
                            .font(.subheadline)
                            .foregroundStyle(manager.isAllRequiredSetupCompleted ? .green : .orange)
                    }
                }
                .accessibilityIdentifier("selfRefresh.navRequired")

                NavigationLink {
                    SelfRefreshHealthCheckView()
                } label: {
                    HStack {
                        Label(manager.localized("健康状态检查"), systemImage: "stethoscope")
                        Spacer()
                        if let report = manager.healthReport {
                            Text(report.isAllHealthy ? manager.localized("全部正常") : manager.localized("存在提醒"))
                                .font(.subheadline)
                                .foregroundStyle(report.isAllHealthy ? .green : .orange)
                        }
                    }
                }
                .accessibilityIdentifier("selfRefresh.navHealth")

                NavigationLink {
                    SelfRefreshOptionalActionsView()
                } label: {
                    HStack {
                        Label(manager.localized("可选操作"), systemImage: "slider.horizontal.3")
                        Spacer()
                        Text(manager.localized("自动化与版本更新"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("selfRefresh.navOptional")
            }

            // Main Section 3: Built-in Multi-Language Switcher + About Component
            Section(manager.localized("关于组件")) {
                Picker(manager.localized("组件语言"), selection: $manager.selectedLanguage) {
                    ForEach(SelfRefreshLanguage.allCases) { lang in
                        Text(lang == .followHost ? manager.localized("跟随宿主应用 / 系统") : lang.displayName)
                            .tag(lang)
                    }
                }
                .accessibilityIdentifier("selfRefresh.languagePicker")

                Button {
                    showAboutSheet = true
                } label: {
                    HStack {
                        Text("SelfRefreshKit")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("v\(SelfRefreshConfiguration.kitVersion)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("selfRefresh.aboutRow")

                Link(destination: SelfRefreshConfiguration.officialRepositoryURL) {
                    HStack {
                        Label(manager.localized("开源仓库"), systemImage: "link")
                        Spacer()
                        Text("Cc-Cece/SelfRefreshKit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("selfRefresh.repoLink")
            }
        }
        .navigationTitle(manager.localized("签名与自动续期"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            manager.reloadEmbeddedProfile()
            _ = await manager.checkTunnelConnection()
        }
        .alert(
            manager.activeNotice?.title ?? "SelfRefreshKit",
            isPresented: $showFeedbackAlert
        ) {
            Button(manager.localized("好"), role: .cancel) {}
        } message: {
            Text(manager.activeNotice?.message ?? "")
        }
        .sheet(isPresented: $showAboutSheet) {
            NavigationStack {
                SelfRefreshAboutSheet()
            }
        }
    }

    private var expirationStatusText: String {
        guard let meta = manager.profileMetadata else {
            return manager.localized("未检测到内置描述文件")
        }
        let info = meta.remainingDaysAndHours()
        if info.isExpired {
            return manager.localized("已过期")
        }
        return "\(info.days)d \(info.hours)h"
    }
}

// MARK: - Secondary Page 1: Required Setup (3 Mandatory Steps + File Importer)

public struct SelfRefreshRequiredSetupView: View {
    @ObservedObject private var manager = SelfRefreshManager.shared
    @State private var showAccountSheet = false
    @State private var showPairingDetailSheet = false
    @State private var isFileImporterPresented = false
    @State private var activeImportKind: ImportKind = .pairingFile
    @State private var showFeedbackAlert = false

    private enum ImportKind {
        case pairingFile
        case localIPA
    }

    public init() {}

    public var body: some View {
        Form {
            Section {
                // Step 1: Pairing File
                Button {
                    if manager.isStep1PairingCompleted {
                        showPairingDetailSheet = true
                    } else {
                        presentFilePicker(for: .pairingFile)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: manager.isStep1PairingCompleted ? "checkmark.circle.fill" : "1.circle.fill")
                            .foregroundStyle(manager.isStep1PairingCompleted ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(manager.localized("1. 导入设备配对文件"))
                                .foregroundStyle(.primary)
                            if let info = manager.pairingInspection {
                                Text("UDID: \(info.udid)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(manager.isStep1PairingCompleted ? manager.localized("已完成") : manager.localized("未完成 · 点击导入"))
                            .font(.subheadline)
                            .foregroundStyle(manager.isStep1PairingCompleted ? .green : .blue)
                    }
                }
                .accessibilityIdentifier("selfRefresh.pairingRow")

                // Step 2: Apple ID Full Login & Session
                Button {
                    showAccountSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: manager.isStep2AccountCompleted ? "checkmark.circle.fill" : "2.circle.fill")
                            .foregroundStyle(manager.isStep2AccountCompleted ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(manager.localized("2. 登录 Apple 开发者账号"))
                                .foregroundStyle(.primary)
                            if let session = manager.authSession {
                                Text("\(session.appleID) · Team: \(session.teamID)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(manager.isStep2AccountCompleted ? manager.localized("已认证") : manager.localized("未完成 · 点击登录"))
                            .font(.subheadline)
                            .foregroundStyle(manager.isStep2AccountCompleted ? .green : .blue)
                    }
                }
                .accessibilityIdentifier("selfRefresh.accountRow")

                // Step 3: Local Certificate Takeover
                Button {
                    presentFilePicker(for: .localIPA)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: manager.isStep3TakeoverCompleted ? "checkmark.circle.fill" : "3.circle.fill")
                            .foregroundStyle(manager.isStep3TakeoverCompleted ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(manager.localized("3. 首次本机签名接管"))
                                .foregroundStyle(.primary)
                            Text(
                                manager.isStep3TakeoverCompleted
                                    ? manager.localized("本机钥匙串证书已接管")
                                    : manager.localized("选择本应用未签名 IPA 完成首次覆盖安装")
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }
                        Spacer()
                        Text(manager.isStep3TakeoverCompleted ? manager.localized("已完成") : manager.localized("待接管"))
                            .font(.subheadline)
                            .foregroundStyle(manager.isStep3TakeoverCompleted ? .green : .blue)
                    }
                }
                .accessibilityIdentifier("selfRefresh.takeoverRow")
            } header: {
                Text(manager.localized("必需操作（完成 3 步后即可无限续签）"))
            }

            Section {
                Button {
                    Task {
                        let connected = await manager.checkTunnelConnection()
                        if !connected {
                            manager.openPreferredVPNApp()
                        } else {
                            manager.postNotice(
                                title: manager.localized("本地隧道已连通"),
                                message: "\(manager.selectedVPN.displayName) (10.7.0.1)"
                            )
                            showFeedbackAlert = true
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: manager.isTunnelConnected ? "network.badge.shield.half.filled" : "exclamationmark.shield")
                            .foregroundStyle(manager.isTunnelConnected ? .green : .blue)
                        Text("\(manager.localized("本地回环隧道")) (\(manager.selectedVPN.displayName))")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(
                            manager.isTunnelConnected
                                ? manager.localized("已连接")
                                : manager.localized("未连接 · 点击开启")
                        )
                        .font(.subheadline)
                        .foregroundStyle(manager.isTunnelConnected ? .green : .blue)
                    }
                }
                .accessibilityIdentifier("selfRefresh.tunnelRow")
            }
        }
        .navigationTitle(manager.localized("必需操作"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert(
            manager.activeNotice?.title ?? "SelfRefreshKit",
            isPresented: $showFeedbackAlert
        ) {
            Button(manager.localized("好"), role: .cancel) {}
        } message: {
            Text(manager.activeNotice?.message ?? "")
        }
        .sheet(isPresented: $showPairingDetailSheet) {
            NavigationStack {
                SelfRefreshPairingDetailSheet(
                    onReimport: {
                        showPairingDetailSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            presentFilePicker(for: .pairingFile)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showAccountSheet) {
            NavigationStack {
                SelfRefreshAccountSheet()
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                switch activeImportKind {
                case .pairingFile:
                    _ = try? manager.importPairingFile(from: url)
                    showFeedbackAlert = true
                case .localIPA:
                    Task {
                        do {
                            let localCopy = try SelfRefreshManager.copySecurityScopedFileToTemp(from: url)
                            defer { try? FileManager.default.removeItem(at: localCopy) }
                            try await manager.resignAndInstall(ipaURL: localCopy)
                        } catch {
                            // Notice posted by manager
                        }
                        showFeedbackAlert = true
                    }
                }
            case .failure(let error):
                manager.postNotice(
                    title: manager.localized("文件读取失败"),
                    message: error.localizedDescription,
                    isError: true
                )
                showFeedbackAlert = true
            }
        }
    }

    private func presentFilePicker(for kind: ImportKind) {
        activeImportKind = kind
        isFileImporterPresented = true
    }
}

// MARK: - Secondary Page 2: Health Status Check

public struct SelfRefreshHealthCheckView: View {
    @ObservedObject private var manager = SelfRefreshManager.shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                Button {
                    Task { _ = await manager.runHealthCheck() }
                } label: {
                    HStack {
                        Label(manager.localized("运行全面健康状态检查"), systemImage: "stethoscope")
                        Spacer()
                        if manager.isCheckingHealth {
                            ProgressView()
                        } else if let report = manager.healthReport {
                            Text(report.isAllHealthy ? manager.localized("全部正常") : manager.localized("存在提醒"))
                                .font(.caption)
                                .foregroundStyle(report.isAllHealthy ? .green : .orange)
                        }
                    }
                }
                .disabled(manager.isCheckingHealth)
                .accessibilityIdentifier("selfRefresh.healthCheckButton")

                if let report = manager.healthReport {
                    ForEach(report.items) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(
                                systemName: item.status == .healthy
                                    ? "checkmark.circle.fill"
                                    : item.status == .warning ? "exclamationmark.triangle.fill" : "xmark.circle.fill"
                            )
                            .foregroundStyle(
                                item.status == .healthy ? .green : item.status == .warning ? .orange : .red
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(manager.localized("健康状态检查"))
            } footer: {
                Text(manager.localized("自动实测配对文件、10.7.0.1 本地回环网卡、Anisette V3 节点延迟及 Apple 开发者会话状态。"))
            }
        }
        .navigationTitle(manager.localized("健康状态检查"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            _ = await manager.runHealthCheck()
        }
    }
}

// MARK: - Secondary Page 3: Optional Actions (Background Shortcuts, VPN Preference, OTA & Local Resign)

public struct SelfRefreshOptionalActionsView: View {
    @ObservedObject private var manager = SelfRefreshManager.shared
    @State private var showShortcutGuide = false
    @State private var isFileImporterPresented = false
    @State private var showFeedbackAlert = false

    public init() {}

    public var body: some View {
        Form {
            Section {
                Button {
                    showShortcutGuide = true
                } label: {
                    HStack {
                        Text(manager.localized("配置「自动续签」快捷指令"))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("Refresh App Provisioning Profile")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                .accessibilityIdentifier("selfRefresh.shortcutGuide")
            } header: {
                Text(manager.localized("快捷指令与自动化"))
            } footer: {
                Text(manager.localized("内置「Refresh App Provisioning Profile」快捷指令支持纯后台运行，不会自动跳转到前台。"))
            }

            Section(manager.localized("环境配置")) {
                Picker(manager.localized("首选隧道应用"), selection: $manager.selectedVPN) {
                    ForEach(LoopbackVPNApp.allCases) { vpn in
                        Text(vpn == .localDevVPN ? "\(vpn.displayName) (\(manager.localized("推荐")))" : vpn.displayName)
                            .tag(vpn)
                    }
                }
                .accessibilityIdentifier("selfRefresh.vpnPicker")
            }

            Section(manager.localized("版本更新与重签")) {
                if manager.configuration.githubRepository != nil {
                    Button {
                        Task {
                            do {
                                let (_, ipaURL) = try await manager.checkGitHubOTAUpdate()
                                try await manager.downloadAndInstallOTA(from: ipaURL)
                            } catch {
                                manager.postNotice(
                                    title: manager.localized("刷新失败"),
                                    message: manager.localized(error.localizedDescription),
                                    isError: true
                                )
                            }
                            showFeedbackAlert = true
                        }
                    } label: {
                        HStack {
                            Text(manager.localized("检查云端更新并自签名升级"))
                            Spacer()
                            if let tag = manager.latestOTATag {
                                Text(tag)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(manager.isRefreshing)
                    .accessibilityIdentifier("selfRefresh.otaUpdate")
                }

                Button(manager.localized("选择本地 IPA 重签安装")) {
                    isFileImporterPresented = true
                }
                .disabled(manager.isRefreshing)
                .accessibilityIdentifier("selfRefresh.localIPA")
            }
        }
        .navigationTitle(manager.localized("可选操作"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert(
            manager.activeNotice?.title ?? "SelfRefreshKit",
            isPresented: $showFeedbackAlert
        ) {
            Button(manager.localized("好"), role: .cancel) {}
        } message: {
            Text(manager.activeNotice?.message ?? "")
        }
        .sheet(isPresented: $showShortcutGuide) {
            NavigationStack {
                SelfRefreshShortcutGuideSheet()
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task {
                    do {
                        let localCopy = try SelfRefreshManager.copySecurityScopedFileToTemp(from: url)
                        defer { try? FileManager.default.removeItem(at: localCopy) }
                        try await manager.resignAndInstall(ipaURL: localCopy)
                    } catch {
                        // Notice posted by manager
                    }
                    showFeedbackAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Sheets (Pairing Detail, Account Auth, Background Shortcut Guide, About with GitHub Repo)

private struct SelfRefreshPairingDetailSheet: View {
    @ObservedObject private var manager = SelfRefreshManager.shared
    @Environment(\.dismiss) private var dismiss
    let onReimport: () -> Void

    var body: some View {
        Form {
            if let info = manager.pairingInspection {
                Section(manager.localized("配对文件详情")) {
                    LabeledContent("UDID", value: info.udid)
                    LabeledContent("Wi-Fi MAC", value: info.wifiMACAddress)
                    LabeledContent("Host ID", value: info.hostID)
                    LabeledContent("System BUID", value: info.systemBUID)
                    LabeledContent("EscrowBag", value: info.hasEscrowBag ? manager.localized("包含") : manager.localized("无"))
                    LabeledContent("iOS 17+ RPPairing", value: info.hasRPPairingKeys ? manager.localized("包含") : manager.localized("无"))
                }

                Section {
                    if FileManager.default.fileExists(atPath: manager.pairingFileURL.path) {
                        ShareLink(item: manager.pairingFileURL) {
                            Label(manager.localized("导出/备份当前配对文件"), systemImage: "square.and.arrow.up")
                        }
                    }
                    Button(manager.localized("重新导入其他配对文件")) {
                        onReimport()
                    }
                }
            }
        }
        .navigationTitle(manager.localized("设备配对文件"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(manager.localized("完成")) { dismiss() }
            }
        }
    }
}

private struct SelfRefreshAccountSheet: View {
    @ObservedObject private var manager = SelfRefreshManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var appleID: String = ""
    @State private var password: String = ""
    @State private var twoFactorCode: String = ""
    @State private var showTwoFactorField: Bool = false
    @State private var anisetteURL: String = ""
    @State private var errorText: String = ""

    var body: some View {
        Form {
            if let session = manager.authSession {
                Section(manager.localized("已认证开发者会话")) {
                    LabeledContent("Apple ID", value: session.appleID)
                    LabeledContent("Team ID", value: session.teamID)
                    LabeledContent("Session Token", value: String(session.sessionToken.prefix(14)) + "…")
                    Button(manager.localized("退出并清除当前凭证"), role: .destructive) {
                        manager.signOutAppleID()
                        password = ""
                    }
                }
            }

            Section {
                TextField("Apple ID (email@icloud.com)", text: $appleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("selfRefresh.appleIDField")
                SecureField(manager.localized("密码"), text: $password)
                    .accessibilityIdentifier("selfRefresh.passwordField")

                Toggle(manager.localized("需要输入双重认证（2FA）验证码"), isOn: $showTwoFactorField)
                if showTwoFactorField {
                    TextField(manager.localized("6 位数字双重认证验证码"), text: $twoFactorCode)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityIdentifier("selfRefresh.twoFactorField")
                }
            } header: {
                Text(manager.localized("登录 Apple 开发者中心"))
            } footer: {
                Text(manager.localized("点击下方「登录并保存开发者凭证」将连接 Anisette V3 并获取开发者 Team ID 与会话凭证，加密保存在本机钥匙串。"))
            }

            Section {
                Picker(manager.localized("推荐节点"), selection: $anisetteURL) {
                    ForEach(AnisetteServerPreset.defaults) { preset in
                        Text(preset.name).tag(preset.url)
                    }
                }
                TextField("https://ani.sidestore.io", text: $anisetteURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("selfRefresh.anisetteField")

                Button(manager.localized("自动测速选择最快 Anisette 节点")) {
                    Task {
                        anisetteURL = await manager.selectFastestAnisetteServer()
                    }
                }
            } header: {
                Text("Anisette V3")
            }

            if !errorText.isEmpty {
                Section {
                    Text(errorText)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task {
                        errorText = ""
                        do {
                            _ = try await manager.authenticateAndSaveAccount(
                                appleID: appleID,
                                password: password,
                                twoFactorCode: showTwoFactorField ? twoFactorCode : nil,
                                anisetteURL: anisetteURL
                            )
                            dismiss()
                        } catch {
                            errorText = manager.localized(error.localizedDescription)
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if manager.isAuthenticating {
                            ProgressView()
                            Text(manager.localized("正在连接 Apple 认证服务…"))
                        } else {
                            Text(manager.localized("登录并保存开发者凭证"))
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(manager.isAuthenticating)
                .accessibilityIdentifier("selfRefresh.saveAccount")
            }
        }
        .navigationTitle(manager.localized("Apple ID 登录与认证"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(manager.localized("关闭")) { dismiss() }
            }
        }
        .onAppear {
            appleID = manager.appleID
            anisetteURL = manager.anisetteURLString
            if let existing = try? SelfRefreshKeychain.loadPassword(for: manager.appleID) {
                password = existing
            }
        }
    }
}

private struct SelfRefreshShortcutGuideSheet: View {
    @ObservedObject private var manager = SelfRefreshManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(manager.localized("自动化配置步骤（纯后台运行）")) {
                Text(manager.localized("1. 打开系统「快捷指令」应用，切换到「自动化」标签页并创建特定时间（如每天 04:00，选择「立即运行」）。"))
                Text(manager.localized("2. 添加动作：连接 LocalDevVPN，并添加「等待 2 秒」。"))
                Text(manager.localized("3. 添加动作：搜索本应用并选择「Refresh App Provisioning Profile」（纯后台静默刷新，不跳转前台）。"))
                Text(manager.localized("4. 添加动作：等待 5 秒后断开 LocalDevVPN。"))
            }

            Section("AppIntent Action") {
                LabeledContent("Action Name", value: "Refresh App Provisioning Profile")
                LabeledContent("Background Mode", value: "openAppWhenRun = false")
                Button(manager.localized("打开系统「快捷指令」应用")) {
                    #if canImport(UIKit)
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                    #endif
                }
            }
        }
        .navigationTitle(manager.localized("快捷指令与自动化"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(manager.localized("完成")) { dismiss() }
            }
        }
    }
}

private struct SelfRefreshAboutSheet: View {
    @ObservedObject private var manager = SelfRefreshManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(manager.localized("组件信息")) {
                LabeledContent("SelfRefreshKit", value: "v\(SelfRefreshConfiguration.kitVersion)")
                LabeledContent(manager.localized("通信引擎"), value: SelfRefreshConfiguration.minimuxerEngineVersion)
                LabeledContent(manager.localized("签名引擎"), value: SelfRefreshConfiguration.altSignEngineVersion)
                LabeledContent(manager.localized("首选隧道"), value: manager.selectedVPN.displayName)
                LabeledContent(manager.localized("开源许可证"), value: "MIT License")
                Link(destination: SelfRefreshConfiguration.officialRepositoryURL) {
                    HStack {
                        Text(manager.localized("开源仓库"))
                        Spacer()
                        Text("https://github.com/Cc-Cece/SelfRefreshKit/")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Text(manager.localized("轻量级 iOS 应用内置自续签与云端 OTA 通用组件库。默认推荐配合 LocalDevVPN 使用，兼容 StosVPN 与 WireGuard。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(manager.localized("关于 SelfRefreshKit"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(manager.localized("完成")) { dismiss() }
            }
        }
    }
}
