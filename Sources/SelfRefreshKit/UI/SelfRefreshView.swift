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
                Label(manager.localized(.navTitle), systemImage: "checkmark.seal")
                Spacer()
                Text(manager.summaryBadgeText)
                    .font(.subheadline)
                    .foregroundStyle(badgeColor)
            }
        }
        .accessibilityIdentifier("settings.selfRefresh")
        .selfRefreshTwoFactorPrompt()
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
/// **Language Switcher**, and **About Component** on the main screen.
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

            // Main Section 1: Current Status (Minimal: Profile Validity + Refresh Now)
            Section {
                LabeledContent(manager.localized(.statusProfileValidity), value: expirationStatusText)

                if manager.isRefreshing {
                    HStack {
                        ProgressView()
                        Text(manager.statusMessage.isEmpty ? manager.localized(.statusProcessing) : manager.statusMessage)
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
                        Text(manager.localized(.statusRefreshNow))
                            .fontWeight(.medium)
                    }
                    .accessibilityIdentifier("selfRefresh.primaryAction")
                } else {
                    NavigationLink {
                        SelfRefreshRequiredSetupView()
                    } label: {
                        Label(manager.localized(.navRequiredTitle), systemImage: "checklist")
                            .foregroundStyle(.blue)
                            .fontWeight(.medium)
                    }
                    .accessibilityIdentifier("selfRefresh.primaryAction")
                }
            } header: {
                Text(manager.localized(.statusHeader))
            }

            // Main Section 2: Secondary Subpages (Required Setup, Health Check, Optional Actions)
            Section(manager.localized(.navSectionHeader)) {
                NavigationLink {
                    SelfRefreshRequiredSetupView()
                } label: {
                    HStack {
                        Label(manager.localized(.navRequiredTitle), systemImage: "checkmark.shield")
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
                        Label(manager.localized(.navHealthTitle), systemImage: "stethoscope")
                        Spacer()
                        if let report = manager.healthReport {
                            Text(report.isAllHealthy ? manager.localized(.healthAllHealthy) : manager.localized(.healthNeedsAttention))
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
                        Label(manager.localized(.navOptionalTitle), systemImage: "slider.horizontal.3")
                        Spacer()
                        Text(manager.localized(.navOptionalSubtitle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("selfRefresh.navOptional")
            }

            // Main Section 3: Built-in Multi-Language Switcher + About Component
            Section(manager.localized(.aboutSectionHeader)) {
                Picker(manager.localized(.aboutLanguagePicker), selection: $manager.selectedLanguage) {
                    ForEach(SelfRefreshLanguage.allCases) { lang in
                        Text(lang == .followHost ? manager.localized(.aboutFollowHost) : lang.displayName)
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
            }
        }
        .navigationTitle(manager.localized(.navTitle))
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
            Button(manager.localized(.commonOK), role: .cancel) {}
        } message: {
            Text(manager.activeNotice?.message ?? "")
        }
        .sheet(isPresented: $showAboutSheet) {
            NavigationStack {
                SelfRefreshAboutSheet()
            }
        }
        .selfRefreshTwoFactorPrompt()
    }

    private var expirationStatusText: String {
        guard let meta = manager.profileMetadata else {
            return manager.localized(.statusNoEmbeddedProfile)
        }
        let info = meta.remainingDaysAndHours()
        if info.isExpired {
            return manager.localized(.statusExpiredBadge)
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
                            Text(manager.localized(.requiredStep1Title))
                                .foregroundStyle(.primary)
                            if let info = manager.pairingInspection {
                                Text("UDID: \(info.udid)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(manager.isStep1PairingCompleted ? manager.localized(.requiredStep1Done) : manager.localized(.requiredStep1Pending))
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
                            Text(manager.localized(.requiredStep2Title))
                                .foregroundStyle(.primary)
                            if let session = manager.authSession {
                                Text("\(session.appleID) · Team: \(session.teamID)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(manager.isStep2AccountCompleted ? manager.localized(.requiredStep2Done) : manager.localized(.requiredStep2Pending))
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
                            Text(manager.localized(.requiredStep3Title))
                                .foregroundStyle(.primary)
                            Text(
                                manager.isStep3TakeoverCompleted
                                    ? manager.localized(.requiredStep3SubDone)
                                    : manager.localized(.requiredStep3SubPending)
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }
                        Spacer()
                        Text(manager.isStep3TakeoverCompleted ? manager.localized(.requiredStep1Done) : manager.localized(.requiredStep3BadgePending))
                            .font(.subheadline)
                            .foregroundStyle(manager.isStep3TakeoverCompleted ? .green : .blue)
                    }
                }
                .accessibilityIdentifier("selfRefresh.takeoverRow")
            } header: {
                Text(manager.localized(.requiredSectionHeader))
            }

            Section {
                Button {
                    Task {
                        let connected = await manager.checkTunnelConnection()
                        if !connected {
                            manager.openPreferredVPNApp()
                        } else {
                            manager.postNotice(
                                title: manager.localized(.noticeTunnelConnectedTitle),
                                message: "\(manager.selectedVPN.displayName) (10.7.0.1)"
                            )
                            showFeedbackAlert = true
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: manager.isTunnelConnected ? "network.badge.shield.half.filled" : "exclamationmark.shield")
                            .foregroundStyle(manager.isTunnelConnected ? .green : .blue)
                        Text("\(manager.localized(.requiredTunnelTitle)) (\(manager.selectedVPN.displayName))")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(
                            manager.isTunnelConnected
                                ? manager.localized(.requiredTunnelConnected)
                                : manager.localized(.requiredTunnelDisconnected)
                        )
                        .font(.subheadline)
                        .foregroundStyle(manager.isTunnelConnected ? .green : .blue)
                    }
                }
                .accessibilityIdentifier("selfRefresh.tunnelRow")
            }
        }
        .navigationTitle(manager.localized(.navRequiredTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert(
            manager.activeNotice?.title ?? "SelfRefreshKit",
            isPresented: $showFeedbackAlert
        ) {
            Button(manager.localized(.commonOK), role: .cancel) {}
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
        .selfRefreshTwoFactorPrompt()
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
                    title: manager.localized(.noticeFileReadFailedTitle),
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
                        Label(manager.localized(.healthRunButton), systemImage: "stethoscope")
                        Spacer()
                        if manager.isCheckingHealth {
                            ProgressView()
                        } else if let report = manager.healthReport {
                            Text(report.isAllHealthy ? manager.localized(.healthAllHealthy) : manager.localized(.healthNeedsAttention))
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
                Text(manager.localized(.navHealthTitle))
            } footer: {
                Text(manager.localized(.healthFooter))
            }
        }
        .navigationTitle(manager.localized(.navHealthTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            _ = await manager.runHealthCheck()
        }
    }
}

// MARK: - Secondary Page 3: Optional Actions (Shortcuts, VPN Preference, Configurable OTA, Direct IPA URL & Local Resign)

public struct SelfRefreshOptionalActionsView: View {
    @ObservedObject private var manager = SelfRefreshManager.shared
    @State private var showShortcutGuide = false
    @State private var isFileImporterPresented = false
    @State private var showFeedbackAlert = false
    @State private var showOTADangerConfirmAlert = false
    @State private var showOTASourceInputAlert = false
    @State private var customOTARepoInput = ""
    @State private var showDirectIPAInputAlert = false
    @State private var directIPAURLInput = ""

    public init() {}

    public var body: some View {
        Form {
            Section {
                Button(manager.localized(.optionalShortcutConfigureButton)) {
                    showShortcutGuide = true
                }
                .accessibilityIdentifier("selfRefresh.shortcutGuide")
            } header: {
                Text(manager.localized(.optionalShortcutSectionHeader))
            } footer: {
                Text(manager.localized(.optionalShortcutFooter))
            }

            Section(manager.localized(.optionalEnvSectionHeader)) {
                Picker(manager.localized(.optionalPreferredVPN), selection: $manager.selectedVPN) {
                    ForEach(LoopbackVPNApp.allCases) { vpn in
                        Text(vpn == .localDevVPN ? "\(vpn.displayName) (\(manager.localized(.commonRecommended)))" : vpn.displayName)
                            .tag(vpn)
                    }
                }
                .accessibilityIdentifier("selfRefresh.vpnPicker")
            }

            Section(manager.localized(.optionalUpdateSectionHeader)) {
                if manager.effectiveGitHubRepository != nil {
                    Button {
                        Task {
                            do {
                                let (_, ipaURL) = try await manager.checkGitHubOTAUpdate()
                                try await manager.downloadAndInstallOTA(from: ipaURL)
                            } catch {
                                manager.postNotice(
                                    title: manager.localized(.noticeRefreshFailedTitle),
                                    message: manager.localized(error.localizedDescription),
                                    isError: true
                                )
                            }
                            showFeedbackAlert = true
                        }
                    } label: {
                        HStack {
                            Text(manager.localized(.optionalCheckOTA))
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

                // Configurable Cloud Update Source (with 2-step High-Risk Confirmation)
                Button {
                    customOTARepoInput = manager.effectiveGitHubRepository ?? ""
                    showOTADangerConfirmAlert = true
                } label: {
                    HStack {
                        Text(manager.localized(.optionalConfigureOTASource))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(manager.effectiveGitHubRepository ?? manager.localized(.commonNone))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .accessibilityIdentifier("selfRefresh.configureOTASource")

                // Direct IPA URL Download & Resign
                Button(manager.localized(.optionalDirectIPAButton)) {
                    directIPAURLInput = ""
                    showDirectIPAInputAlert = true
                }
                .disabled(manager.isRefreshing)
                .accessibilityIdentifier("selfRefresh.directIPA")

                // Local IPA File Resign
                Button(manager.localized(.optionalLocalIPAButton)) {
                    isFileImporterPresented = true
                }
                .disabled(manager.isRefreshing)
                .accessibilityIdentifier("selfRefresh.localIPA")
            }
        }
        .navigationTitle(manager.localized(.navOptionalTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert(
            manager.activeNotice?.title ?? "SelfRefreshKit",
            isPresented: $showFeedbackAlert
        ) {
            Button(manager.localized(.commonOK), role: .cancel) {}
        } message: {
            Text(manager.activeNotice?.message ?? "")
        }
        // Step 1: High-Risk Warning Confirmation before changing OTA Repository
        .alert(
            manager.localized(.optionalOTADangerTitle),
            isPresented: $showOTADangerConfirmAlert
        ) {
            Button(manager.localized(.commonCancel), role: .cancel) {}
            Button(manager.localized(.commonContinueDanger), role: .destructive) {
                showOTASourceInputAlert = true
            }
        } message: {
            Text(manager.localized(.optionalOTADangerMessage))
        }
        // Step 2: Input New GitHub OTA Repository
        .alert(
            manager.localized(.optionalOTAInputTitle),
            isPresented: $showOTASourceInputAlert
        ) {
            TextField("owner/repo", text: $customOTARepoInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(manager.localized(.commonSave)) {
                manager.updateCustomGitHubRepository(customOTARepoInput)
                showFeedbackAlert = true
            }
            if manager.customGitHubRepository != nil {
                Button(manager.localized(.commonResetDefault)) {
                    manager.resetGitHubRepositoryToDefault()
                    showFeedbackAlert = true
                }
            }
            Button(manager.localized(.commonCancel), role: .cancel) {}
        } message: {
            Text(manager.localized(.optionalOTAInputMessage))
        }
        // Direct IPA Link Dialog
        .alert(
            manager.localized(.optionalDirectIPATitle),
            isPresented: $showDirectIPAInputAlert
        ) {
            TextField("https://example.com/app.ipa", text: $directIPAURLInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(manager.localized(.commonDownloadAndInstall)) {
                let urlToDownload = directIPAURLInput
                Task {
                    do {
                        try await manager.downloadAndInstallDirectIPA(urlString: urlToDownload)
                    } catch {
                        // Notice posted by manager
                    }
                    showFeedbackAlert = true
                }
            }
            Button(manager.localized(.commonCancel), role: .cancel) {}
        } message: {
            Text(manager.localized(.optionalDirectIPAMessage))
        }
        .sheet(isPresented: $showShortcutGuide) {
            NavigationStack {
                SelfRefreshShortcutGuideSheet()
            }
        }
        .selfRefreshTwoFactorPrompt()
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
                Section(manager.localized(.pairingDetailsSection)) {
                    LabeledContent("UDID", value: info.udid)
                    LabeledContent("Wi-Fi MAC", value: info.wifiMACAddress)
                    LabeledContent("Host ID", value: info.hostID)
                    LabeledContent("System BUID", value: info.systemBUID)
                    LabeledContent("EscrowBag", value: info.hasEscrowBag ? manager.localized(.commonPresent) : manager.localized(.commonNone))
                    LabeledContent("iOS 17+ RPPairing", value: info.hasRPPairingKeys ? manager.localized(.commonPresent) : manager.localized(.commonNone))
                }

                Section {
                    if FileManager.default.fileExists(atPath: manager.pairingFileURL.path) {
                        ShareLink(item: manager.pairingFileURL) {
                            Label(manager.localized(.pairingExportButton), systemImage: "square.and.arrow.up")
                        }
                    }
                    Button(manager.localized(.pairingReimportButton)) {
                        onReimport()
                    }
                }
            }
        }
        .navigationTitle(manager.localized(.pairingSheetTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(manager.localized(.commonDone)) { dismiss() }
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
                Section(manager.localized(.accountSessionSection)) {
                    LabeledContent("Apple ID", value: session.appleID)
                    LabeledContent("Team ID", value: session.teamID)
                    LabeledContent("Session Token", value: String(session.sessionToken.prefix(14)) + "…")
                    Button(manager.localized(.accountSignOutButton), role: .destructive) {
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
                SecureField(manager.localized(.accountPasswordPlaceholder), text: $password)
                    .accessibilityIdentifier("selfRefresh.passwordField")

                Toggle(manager.localized(.accountToggle2FA), isOn: $showTwoFactorField)
                if showTwoFactorField {
                    TextField(manager.localized(.account2FAPlaceholder), text: $twoFactorCode)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityIdentifier("selfRefresh.twoFactorField")
                }
            } header: {
                Text(manager.localized(.accountLoginSection))
            } footer: {
                Text(manager.localized(.accountLoginFooter))
            }

            Section {
                Picker(manager.localized(.accountPresetServer), selection: $anisetteURL) {
                    ForEach(AnisetteServerPreset.defaults) { preset in
                        Text(preset.name).tag(preset.url)
                    }
                }
                TextField("https://ani.sidestore.io", text: $anisetteURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("selfRefresh.anisetteField")

                Button(manager.localized(.accountAutoSelectAnisette)) {
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
                            Text(manager.localized(.accountAuthenticating))
                        } else {
                            Text(manager.localized(.accountSubmitButton))
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(manager.isAuthenticating)
                .accessibilityIdentifier("selfRefresh.saveAccount")
            }
        }
        .navigationTitle(manager.localized(.accountSheetTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(manager.localized(.commonClose)) { dismiss() }
            }
        }
        .onAppear {
            appleID = manager.appleID
            anisetteURL = manager.anisetteURLString
            if let existing = try? SelfRefreshKeychain.loadPassword(for: manager.appleID) {
                password = existing
            }
        }
        .selfRefreshTwoFactorPrompt()
    }
}

private struct SelfRefreshShortcutGuideSheet: View {
    @ObservedObject private var manager = SelfRefreshManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(manager.localized(.shortcutGuideSection)) {
                Text(manager.localized(.shortcutStep1))
                Text(manager.localized(.shortcutStep2))
                Text(manager.localized(.shortcutStep3))
                Text(manager.localized(.shortcutStep4))
            }

            Section {
                Link(destination: SelfRefreshConfiguration.shortcutsDocumentationURL) {
                    Label(manager.localized(.shortcutViewDocsButton), systemImage: "book.pages")
                }

                Button {
                    #if canImport(UIKit)
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                    #endif
                } label: {
                    Label(manager.localized(.shortcutOpenAppButton), systemImage: "bolt.horizontal.circle")
                }
            }
        }
        .navigationTitle(manager.localized(.optionalShortcutSectionHeader))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(manager.localized(.commonDone)) { dismiss() }
            }
        }
    }
}

private struct SelfRefreshAboutSheet: View {
    @ObservedObject private var manager = SelfRefreshManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(manager.localized(.aboutInfoSection)) {
                LabeledContent("SelfRefreshKit", value: "v\(SelfRefreshConfiguration.kitVersion)")
                LabeledContent(manager.localized(.aboutEngineMuxer), value: SelfRefreshConfiguration.minimuxerEngineVersion)
                LabeledContent(manager.localized(.aboutEngineSigning), value: SelfRefreshConfiguration.altSignEngineVersion)
                LabeledContent(manager.localized(.aboutPreferredTunnel), value: manager.selectedVPN.displayName)
                LabeledContent(manager.localized(.aboutLicense), value: "MIT License")
                Link(destination: SelfRefreshConfiguration.officialRepositoryURL) {
                    HStack {
                        Text(manager.localized(.aboutRepository))
                        Spacer()
                        Text("https://github.com/Cc-Cece/SelfRefreshKit/")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Text(manager.localized(.aboutSummary))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(manager.localized(.aboutSheetTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(manager.localized(.commonDone)) { dismiss() }
            }
        }
    }
}

// MARK: - Apple 2FA prompt (login and refresh share one waiting sheet)

private enum TwoFactorPromptStack {
    private static var ids: [UUID] = []

    static func push(_ id: UUID) {
        guard !ids.contains(id) else { return }
        ids.append(id)
    }

    static func pop(_ id: UUID) {
        ids.removeAll { $0 == id }
    }

    static func isTop(_ id: UUID) -> Bool {
        ids.last == id
    }
}

private struct TwoFactorPromptModifier: ViewModifier {
    @ObservedObject private var manager = SelfRefreshManager.shared
    @State private var promptID = UUID()
    @State private var isAttached = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                TwoFactorPromptStack.push(promptID)
                isAttached = true
            }
            .onDisappear {
                TwoFactorPromptStack.pop(promptID)
                isAttached = false
            }
            .sheet(
                isPresented: Binding(
                    get: {
                        isAttached && manager.isAwaitingTwoFactor && TwoFactorPromptStack.isTop(promptID)
                    },
                    set: { presented in
                        if !presented, manager.isAwaitingTwoFactor, TwoFactorPromptStack.isTop(promptID) {
                            manager.cancelTwoFactorEntry()
                        }
                    }
                )
            ) {
                SelfRefreshTwoFactorSheet()
            }
    }
}

private extension View {
    func selfRefreshTwoFactorPrompt() -> some View {
        modifier(TwoFactorPromptModifier())
    }
}

/// Shown while SideSign waits for a code. Submit stays enabled during `isAuthenticating`.
private struct SelfRefreshTwoFactorSheet: View {
    @ObservedObject private var manager = SelfRefreshManager.shared
    @State private var code = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(manager.localized(.accountToggle2FA))
                    TextField(manager.localized(.account2FAPlaceholder), text: $code)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .textContentType(.oneTimeCode)
                        .accessibilityIdentifier("selfRefresh.twoFactorPromptField")
                        .onChange(of: code) { newValue in
                            let digits = String(newValue.filter(\.isNumber).prefix(6))
                            if digits != newValue {
                                code = digits
                            }
                        }
                }
                Section {
                    Button {
                        manager.submitTwoFactorCode(code)
                    } label: {
                        HStack {
                            Spacer()
                            Text(manager.localized(.accountSubmitButton))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(code.filter(\.isNumber).count != 6)
                    .accessibilityIdentifier("selfRefresh.twoFactorPromptSubmit")
                }
            }
            .navigationTitle(manager.localized(.accountToggle2FA))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(manager.localized(.commonCancel)) {
                        manager.cancelTwoFactorEntry()
                    }
                    .accessibilityIdentifier("selfRefresh.twoFactorPromptCancel")
                }
            }
        }
        .interactiveDismissDisabled(true)
    }
}
