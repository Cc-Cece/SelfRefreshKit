import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppIntents)
import AppIntents
#endif

/// Central state, setup checklist, health checker, and operation coordinator for `SelfRefreshKit`.
@MainActor
public final class SelfRefreshManager: ObservableObject {
    public static let shared = SelfRefreshManager()

    public struct FeedbackNotice: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public let title: String
        public let message: String
        public let isError: Bool
    }

    @Published public private(set) var configuration = SelfRefreshConfiguration()
    @Published public private(set) var profileMetadata: ProvisioningProfileMetadata?
    @Published public private(set) var pairingInspection: PairingFileInspection?
    @Published public private(set) var authSession: AppleAuthSession?
    @Published public private(set) var isLocalCertificateTakenOver: Bool = false
    @Published public private(set) var isTunnelConnected: Bool = false
    @Published public var appleID: String = ""
    @Published public var anisetteURLString: String = "https://ani.sidestore.io" {
        didSet {
            defaults.set(anisetteURLString, forKey: Keys.anisetteURL)
        }
    }
    @Published public var selectedVPN: LoopbackVPNApp = .localDevVPN {
        didSet {
            defaults.set(selectedVPN.rawValue, forKey: Keys.selectedVPN)
        }
    }
    @Published public var selectedLanguage: SelfRefreshLanguage = .followHost {
        didSet {
            defaults.set(selectedLanguage.rawValue, forKey: Keys.selectedLanguage)
        }
    }
    @Published public var isSetupGuideSkipped: Bool = false {
        didSet {
            defaults.set(isSetupGuideSkipped, forKey: Keys.setupGuideSkipped)
        }
    }

    @Published public private(set) var isRefreshing: Bool = false
    @Published public private(set) var isAuthenticating: Bool = false
    @Published public private(set) var isCheckingHealth: Bool = false
    @Published public private(set) var healthReport: HealthCheckReport?
    @Published public private(set) var lastRefreshDate: Date?
    @Published public var statusMessage: String = ""
    @Published public var lastError: String = ""
    @Published public var activeNotice: FeedbackNotice?
    @Published public private(set) var latestOTATag: String?
    @Published public private(set) var latestOTADownloadURL: URL?

    private var driver: SelfRefreshBackendDriver
    private let defaults: UserDefaults
    private let storageDirectory: URL

    private enum Keys {
        static let appleID = "selfrefreshkit.appleID"
        static let anisetteURL = "selfrefreshkit.anisetteURL"
        static let selectedVPN = "selfrefreshkit.selectedVPN"
        static let selectedLanguage = "selfrefreshkit.selectedLanguage"
        static let takenOver = "selfrefreshkit.takenOver"
        static let lastRefreshDate = "selfrefreshkit.lastRefreshDate"
        static let cachedExpirationDate = "selfrefreshkit.cachedExpirationDate"
        static let setupGuideSkipped = "selfrefreshkit.setupGuideSkipped"
    }

    public init(
        driver: SelfRefreshBackendDriver = DefaultSelfRefreshDriver(),
        defaults: UserDefaults = .standard,
        storageDirectory: URL? = nil
    ) {
        self.driver = driver
        self.defaults = defaults
        let baseDir = storageDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SelfRefreshKit", isDirectory: true)
        self.storageDirectory = baseDir
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        self.appleID = defaults.string(forKey: Keys.appleID) ?? ""
        self.anisetteURLString = defaults.string(forKey: Keys.anisetteURL) ?? "https://ani.sidestore.io"
        if let rawVPN = defaults.string(forKey: Keys.selectedVPN),
           let vpn = LoopbackVPNApp(rawValue: rawVPN) {
            self.selectedVPN = vpn
        }
        if let rawLang = defaults.string(forKey: Keys.selectedLanguage),
           let lang = SelfRefreshLanguage(rawValue: rawLang) {
            self.selectedLanguage = lang
        }
        self.isLocalCertificateTakenOver = defaults.bool(forKey: Keys.takenOver)
        self.lastRefreshDate = defaults.object(forKey: Keys.lastRefreshDate) as? Date
        self.isSetupGuideSkipped = defaults.bool(forKey: Keys.setupGuideSkipped)
        self.authSession = try? SelfRefreshKeychain.loadAuthSession()
        if let session = self.authSession, self.appleID.isEmpty {
            self.appleID = session.appleID
        }

        reloadEmbeddedProfile()
        loadExistingPairingFileIfPresent()
    }

    /// Configures `SelfRefreshKit` on app startup.
    public func configure(_ config: SelfRefreshConfiguration, customDriver: SelfRefreshBackendDriver? = nil) {
        self.configuration = config
        if let customDriver {
            self.driver = customDriver
        }
        if defaults.string(forKey: Keys.selectedVPN) == nil {
            self.selectedVPN = config.preferredVPN
        }
        if defaults.string(forKey: Keys.anisetteURL) == nil {
            self.anisetteURLString = config.defaultAnisetteURL
        }
        reloadEmbeddedProfile()
        loadExistingPairingFileIfPresent()
    }

    /// Translates a user-facing string according to:
    /// 1. User's manual language choice in `SelfRefreshKit` (if not `.followHost`)
    /// 2. Host app's language provider or system preferred language (with `.english` fallback)
    public func localized(_ key: String) -> String {
        if selectedLanguage == .followHost, let localizer = configuration.localizer {
            let result = localizer(key)
            if result != key {
                return result
            }
        }
        let hostIdentifier = configuration.hostLanguageProvider?() ?? Locale.preferredLanguages.first
        return SelfRefreshStrings.translate(
            key,
            preferredLanguage: selectedLanguage,
            hostLanguageIdentifier: hostIdentifier
        )
    }

    public var pairingFileURL: URL {
        storageDirectory.appendingPathComponent("pairing.mobiledevicepairing")
    }

    public var pairedDeviceIdentifier: String? {
        pairingInspection?.udid
    }

    // MARK: - Required Setup Checklist Status (3 Mandatory Steps)

    /// Step 1: Device Pairing File Imported & Validated
    public var isStep1PairingCompleted: Bool {
        pairingInspection != nil
    }

    /// Step 2: Apple ID Authenticated & Developer Session Token Persisted
    public var isStep2AccountCompleted: Bool {
        authSession != nil && hasSavedCredentials
    }

    /// Step 3: Local Certificate Takeover Completed
    public var isStep3TakeoverCompleted: Bool {
        isLocalCertificateTakenOver
    }

    /// Number of completed mandatory setup steps (0...3).
    public var completedRequiredStepsCount: Int {
        [isStep1PairingCompleted, isStep2AccountCompleted, isStep3TakeoverCompleted].filter { $0 }.count
    }

    /// True when all 3 mandatory setup items are completed.
    public var isAllRequiredSetupCompleted: Bool {
        completedRequiredStepsCount == 3
    }

    /// Should present the interactive Setup Wizard automatically when entering `SelfRefreshView`.
    public var shouldAutoPresentSetupWizard: Bool {
        !isAllRequiredSetupCompleted && !isSetupGuideSkipped
    }

    public var hasSavedCredentials: Bool {
        guard !appleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let saved = try? SelfRefreshKeychain.loadPassword(for: appleID)
        return (saved?.isEmpty == false)
    }

    // MARK: - Haptic & Alert Feedback

    public func postNotice(title: String, message: String, isError: Bool = false) {
        self.activeNotice = FeedbackNotice(title: title, message: message, isError: isError)
        if isError {
            self.lastError = message
        } else {
            self.lastError = ""
            self.statusMessage = message
        }
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(isError ? .error : .success)
        #endif
    }

    // MARK: - Step 1: Pairing File Import (Supports XML & Binary Plist + Detailed Feedback)

    public func reloadEmbeddedProfile(in bundleURL: URL = Bundle.main.bundleURL) {
        if let parsed = ProfileInspector.inspectEmbeddedProfile(in: bundleURL) {
            self.profileMetadata = parsed
            defaults.set(parsed.expirationDate, forKey: Keys.cachedExpirationDate)
        } else if let cachedExp = defaults.object(forKey: Keys.cachedExpirationDate) as? Date {
            let bundleID = Bundle.main.bundleIdentifier ?? "com.app.sideloaded"
            self.profileMetadata = ProvisioningProfileMetadata(
                uuid: "CACHED-PROFILE",
                name: bundleID,
                appIDName: bundleID,
                bundleIdentifier: bundleID,
                teamIdentifier: authSession?.teamID ?? "PERSONAL",
                teamName: appleID.isEmpty ? "Personal Team" : appleID,
                creationDate: lastRefreshDate ?? Date(),
                expirationDate: cachedExp
            )
        }
    }

    public func loadExistingPairingFileIfPresent() {
        guard FileManager.default.fileExists(atPath: pairingFileURL.path),
              let data = try? Data(contentsOf: pairingFileURL),
              let inspection = try? driver.inspectPairingFile(data: data) else {
            return
        }
        self.pairingInspection = inspection
    }

    @discardableResult
    public func importPairingFile(from sourceURL: URL) throws -> PairingFileInspection {
        let data = try Self.readSecurityScopedData(from: sourceURL)
        return try importPairingData(data)
    }

    public static func readSecurityScopedData(from sourceURL: URL) throws -> Data {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }
        var coordinatorError: NSError?
        var readResult: Result<Data, Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinatorError) { coordinatedURL in
            do {
                readResult = .success(try Data(contentsOf: coordinatedURL))
            } catch {
                readResult = .failure(error)
            }
        }
        if let result = readResult {
            return try result.get()
        }
        if let coordinatorError {
            throw coordinatorError
        }
        return try Data(contentsOf: sourceURL)
    }

    public static func copySecurityScopedFileToTemp(from sourceURL: URL) throws -> URL {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Picked-\(UUID().uuidString)-\(sourceURL.lastPathComponent)")
        try? FileManager.default.removeItem(at: tempURL)

        var coordinatorError: NSError?
        var copyError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinatorError) { coordinatedURL in
            do {
                try FileManager.default.copyItem(at: coordinatedURL, to: tempURL)
            } catch {
                copyError = error
            }
        }
        if let copyError {
            throw copyError
        }
        if let coordinatorError {
            throw coordinatorError
        }
        return tempURL
    }

    @discardableResult
    public func importPairingData(_ data: Data) throws -> PairingFileInspection {
        do {
            let inspection = try driver.inspectPairingFile(data: data)
            try data.write(to: pairingFileURL, options: .atomic)
            self.pairingInspection = inspection
            let rpBadge = inspection.hasRPPairingKeys ? " (含 iOS 17+ RPPairing 密钥)" : ""
            postNotice(
                title: localized("配对文件导入成功"),
                message: "UDID: \(inspection.udid)\nWiFi MAC: \(inspection.wifiMACAddress)\(rpBadge)",
                isError: false
            )
            return inspection
        } catch {
            postNotice(
                title: localized("配对文件导入失败"),
                message: error.localizedDescription,
                isError: true
            )
            throw error
        }
    }

    public func importPairingXMLContent(_ xmlContent: String) throws {
        guard let data = xmlContent.data(using: .utf8) else {
            throw SelfRefreshError.invalidPairingFile("UTF-8 编码无效")
        }
        _ = try importPairingData(data)
    }

    // MARK: - Step 2: Full Apple ID Login & Session Persistence (with 2FA Support)

    @discardableResult
    public func authenticateAndSaveAccount(
        appleID: String,
        password: String,
        twoFactorCode: String? = nil,
        anisetteURL: String
    ) async throws -> AppleAuthSession {
        isAuthenticating = true
        defer { isAuthenticating = false }

        let trimmedID = appleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = anisetteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty, !password.isEmpty else {
            let err = SelfRefreshError.missingAppleIDCredentials
            postNotice(title: localized("登录失败"), message: localized(err.localizedDescription), isError: true)
            throw err
        }
        guard let parsedURL = URL(string: trimmedURL),
              let scheme = parsedURL.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            let err = SelfRefreshError.invalidAnisetteURL
            postNotice(title: localized("登录失败"), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        do {
            let session = try await driver.authenticateAppleID(
                appleID: trimmedID,
                password: password,
                twoFactorCode: twoFactorCode,
                anisetteURL: parsedURL
            )
            try SelfRefreshKeychain.savePassword(password, for: trimmedID)
            try SelfRefreshKeychain.saveAuthSession(session)

            self.appleID = trimmedID
            self.anisetteURLString = trimmedURL
            self.authSession = session
            defaults.set(trimmedID, forKey: Keys.appleID)
            defaults.set(trimmedURL, forKey: Keys.anisetteURL)

            postNotice(
                title: localized("Apple ID 认证成功"),
                message: "\(trimmedID)\nTeam ID: \(session.teamID) · 会话凭证已保存到本机钥匙串",
                isError: false
            )
            return session
        } catch {
            postNotice(
                title: localized("Apple ID 认证失败"),
                message: error.localizedDescription,
                isError: true
            )
            throw error
        }
    }

    public func signOutAppleID() {
        if !appleID.isEmpty {
            try? SelfRefreshKeychain.deletePassword(for: appleID)
        }
        try? SelfRefreshKeychain.deleteAuthSession()
        self.authSession = nil
        self.appleID = ""
        defaults.removeObject(forKey: Keys.appleID)
        postNotice(title: localized("已退出账号"), message: localized("已清除本机保存的 Apple ID 会话凭证。"))
    }

    // MARK: - Loopback VPN & 4-Point Health Check

    @discardableResult
    public func checkTunnelConnection() async -> Bool {
        let connected = await driver.testLoopbackTunnel(host: "10.7.0.1", port: 62078)
        self.isTunnelConnected = connected
        return connected
    }

    public func openPreferredVPNApp() {
        #if canImport(UIKit)
        if let schemeURL = selectedVPN.urlScheme, UIApplication.shared.canOpenURL(schemeURL) {
            UIApplication.shared.open(schemeURL)
        } else if let storeURL = selectedVPN.appStoreURL {
            UIApplication.shared.open(storeURL)
        }
        #endif
    }

    /// Runs a comprehensive 4-point Health Check across Pairing File, Loopback VPN, Anisette V3 Server, and Apple Session.
    @discardableResult
    public func runHealthCheck() async -> HealthCheckReport {
        isCheckingHealth = true
        defer { isCheckingHealth = false }

        var items: [HealthCheckReport.ItemResult] = []

        // 1. Pairing File Health
        if let info = pairingInspection {
            let detail = "UDID: \(info.udid)" + (info.hasRPPairingKeys ? " · RPPairing 就绪" : "")
            items.append(.init(
                id: "pairing",
                title: localized("设备配对文件"),
                status: .healthy,
                detail: detail
            ))
        } else {
            items.append(.init(
                id: "pairing",
                title: localized("设备配对文件"),
                status: .failed,
                detail: localized("未导入有效的 .mobiledevicepairing / .plist 文件")
            ))
        }

        // 2. Loopback VPN Tunnel Health
        let tunnelOK = await checkTunnelConnection()
        items.append(.init(
            id: "tunnel",
            title: "\(localized("本地回环隧道")) (\(selectedVPN.displayName))",
            status: tunnelOK ? .healthy : .warning,
            detail: tunnelOK
                ? "10.7.0.1 虚拟网卡已连通"
                : localized("未检测到 10.7.0.1 隧道（刷新前需开启 VPN）")
        ))

        // 3. Anisette V3 Server Health & Latency
        if let url = URL(string: anisetteURLString) {
            do {
                let probe = try await driver.probeAnisetteServer(url: url)
                let hasHeaders = probe.headers["X-Apple-I-MD"] != nil || !probe.headers.isEmpty
                items.append(.init(
                    id: "anisette",
                    title: "Anisette V3 (\(url.host ?? anisetteURLString))",
                    status: .healthy,
                    detail: hasHeaders ? "V3 认证头正常 (\(probe.latencyMs) ms)" : "连接正常 (\(probe.latencyMs) ms)",
                    latencyMs: probe.latencyMs
                ))
            } catch {
                items.append(.init(
                    id: "anisette",
                    title: "Anisette V3",
                    status: .warning,
                    detail: error.localizedDescription
                ))
            }
        } else {
            items.append(.init(
                id: "anisette",
                title: "Anisette V3",
                status: .failed,
                detail: localized("Anisette URL 格式无效")
            ))
        }

        // 4. Apple Developer Session & Profile Health
        if let session = authSession, hasSavedCredentials {
            let profileInfo: String
            if let meta = profileMetadata {
                let rem = meta.remainingDaysAndHours()
                profileInfo = rem.isExpired ? localized("描述文件已过期") : "剩余 \(rem.days)d \(rem.hours)h"
            } else {
                profileInfo = isLocalCertificateTakenOver ? localized("本机证书已接管") : localized("待首次 IPA 接管")
            }
            items.append(.init(
                id: "account",
                title: localized("Apple 开发者凭证"),
                status: isLocalCertificateTakenOver ? .healthy : .warning,
                detail: "Team: \(session.teamID) · \(profileInfo)"
            ))
        } else {
            items.append(.init(
                id: "account",
                title: localized("Apple 开发者凭证"),
                status: .failed,
                detail: localized("尚未完成 Apple ID 登录认证")
            ))
        }

        let report = HealthCheckReport(checkedAt: Date(), items: items)
        self.healthReport = report
        return report
    }

    /// Automatically tests all preset Anisette V3 servers and switches to the fastest reachable one.
    @discardableResult
    public func selectFastestAnisetteServer() async -> String {
        var bestURL = anisetteURLString
        var bestLatency = Int.max
        for preset in AnisetteServerPreset.defaults {
            guard let url = URL(string: preset.url) else { continue }
            if let result = try? await driver.probeAnisetteServer(url: url), result.latencyMs < bestLatency {
                bestLatency = result.latencyMs
                bestURL = preset.url
            }
        }
        self.anisetteURLString = bestURL
        if bestLatency < Int.max {
            postNotice(
                title: localized("已切换最快节点"),
                message: "\(bestURL) (\(bestLatency) ms)",
                isError: false
            )
        }
        return bestURL
    }

    // MARK: - Mode A: 1-Second Profile-Only Refresh (No Crash / No IPA Needed)

    public func refreshProfileOnly() async throws {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = ""
        statusMessage = localized("正在刷新描述文件…")
        defer { isRefreshing = false }

        #if canImport(UIKit)
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "SelfRefreshKit.ProfileRefresh") {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        defer {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        }
        #endif

        guard FileManager.default.fileExists(atPath: pairingFileURL.path),
              let pairingData = try? Data(contentsOf: pairingFileURL) else {
            let err = SelfRefreshError.missingPairingFile
            postNotice(title: localized("刷新失败"), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        let tunnelReady = await checkTunnelConnection()
        guard tunnelReady else {
            let err = SelfRefreshError.tunnelDisconnected(selectedVPN)
            postNotice(title: localized("未开启本地隧道"), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        let trimmedID = appleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty,
              let password = try SelfRefreshKeychain.loadPassword(for: trimmedID),
              !password.isEmpty else {
            let err = SelfRefreshError.missingAppleIDCredentials
            postNotice(title: localized("缺少账号凭证"), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        guard let anisetteURL = URL(string: anisetteURLString) else {
            let err = SelfRefreshError.invalidAnisetteURL
            postNotice(title: localized("配置错误"), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.cccece.picharbor"
        let updatedProfile = try await driver.refreshProvisioningProfileOnly(
            appleID: trimmedID,
            password: password,
            session: authSession,
            anisetteURL: anisetteURL,
            pairingData: pairingData,
            bundleIdentifier: bundleID
        )

        self.profileMetadata = updatedProfile
        let now = Date()
        self.lastRefreshDate = now
        defaults.set(now, forKey: Keys.lastRefreshDate)
        defaults.set(updatedProfile.expirationDate, forKey: Keys.cachedExpirationDate)
        postNotice(
            title: localized("刷新成功"),
            message: localized("描述文件已刷新，有效期已重置为 7 天。"),
            isError: false
        )
    }

    // MARK: - Mode B: Full IPA Resign & Self-Install (Initial Takeover & Cloud OTA Update)

    public func resignAndInstall(ipaURL: URL) async throws {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = ""
        statusMessage = localized("正在本地重签名并覆盖安装…")
        defer { isRefreshing = false }

        let accessed = ipaURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { ipaURL.stopAccessingSecurityScopedResource() }
        }

        guard FileManager.default.fileExists(atPath: pairingFileURL.path),
              let pairingData = try? Data(contentsOf: pairingFileURL) else {
            let err = SelfRefreshError.missingPairingFile
            postNotice(title: localized("重签安装失败"), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        let tunnelReady = await checkTunnelConnection()
        guard tunnelReady else {
            let err = SelfRefreshError.tunnelDisconnected(selectedVPN)
            postNotice(title: localized("未开启本地隧道"), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        let trimmedID = appleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty,
              let password = try SelfRefreshKeychain.loadPassword(for: trimmedID),
              !password.isEmpty else {
            let err = SelfRefreshError.missingAppleIDCredentials
            postNotice(title: localized("缺少账号凭证"), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        guard let anisetteURL = URL(string: anisetteURLString) else {
            let err = SelfRefreshError.invalidAnisetteURL
            postNotice(title: localized("配置错误"), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.cccece.picharbor"
        let updatedProfile = try await driver.resignAndInstallIPA(
            ipaFileURL: ipaURL,
            appleID: trimmedID,
            password: password,
            session: authSession,
            anisetteURL: anisetteURL,
            pairingData: pairingData,
            bundleIdentifier: bundleID
        )

        self.profileMetadata = updatedProfile
        self.isLocalCertificateTakenOver = true
        let now = Date()
        self.lastRefreshDate = now
        defaults.set(true, forKey: Keys.takenOver)
        defaults.set(now, forKey: Keys.lastRefreshDate)
        defaults.set(updatedProfile.expirationDate, forKey: Keys.cachedExpirationDate)
        postNotice(
            title: localized("签名接管完成"),
            message: localized("已完成本机签名接管与覆盖安装。后续只需 1 秒刷新描述文件。"),
            isError: false
        )
    }

    // MARK: - Cloud OTA Check (GitHub Releases)

    public func checkGitHubOTAUpdate() async throws -> (tag: String, ipaURL: URL) {
        guard let repo = configuration.githubRepository, !repo.isEmpty,
              let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            throw SelfRefreshError.otaNoReleaseFound
        }
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]] else {
            throw SelfRefreshError.otaNoReleaseFound
        }

        for asset in assets {
            if let name = asset["name"] as? String, name.lowercased().hasSuffix(".ipa"),
               let urlString = asset["browser_download_url"] as? String,
               let downloadURL = URL(string: urlString) {
                self.latestOTATag = tag
                self.latestOTADownloadURL = downloadURL
                return (tag, downloadURL)
            }
        }
        throw SelfRefreshError.otaNoReleaseFound
    }

    public func downloadAndInstallOTA(from remoteIPAURL: URL) async throws {
        statusMessage = localized("正在下载云端未签名 IPA…")
        let (tempURL, response) = try await URLSession.shared.download(from: remoteIPAURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SelfRefreshError.otaNoReleaseFound
        }
        let targetURL = FileManager.default.temporaryDirectory.appendingPathComponent("OTAUpdate-\(UUID().uuidString).ipa")
        try? FileManager.default.removeItem(at: targetURL)
        try FileManager.default.moveItem(at: tempURL, to: targetURL)
        defer { try? FileManager.default.removeItem(at: targetURL) }
        try await resignAndInstall(ipaURL: targetURL)
    }

    // MARK: - URL Scheme Automation Handler (`myapp://refresh`)

    @discardableResult
    public func handleOpenURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == configuration.urlScheme.lowercased() else {
            return false
        }
        let host = url.host?.lowercased() ?? ""
        if host == "refresh" || url.path.lowercased().contains("refresh") {
            Task {
                try? await refreshProfileOnly()
            }
            return true
        }
        return false
    }

    // MARK: - Summary Text Helper for Host Settings Row

    public var summaryBadgeText: String {
        if !isAllRequiredSetupCompleted {
            return "\(localized("待配置")) (\(completedRequiredStepsCount)/3)"
        }
        guard let meta = profileMetadata else {
            return localized("已就绪")
        }
        let remaining = meta.remainingDaysAndHours()
        if remaining.isExpired {
            return localized("已过期")
        }
        return "\(remaining.days)d \(remaining.hours)h"
    }
}

#if canImport(AppIntents)
/// Built-in background iOS Shortcuts `AppIntent` (English default, `openAppWhenRun = false` so it runs silently in the background without opening the app).
@available(iOS 17.0, macOS 14.0, *)
public struct SelfRefreshProfileIntent: AppIntent {
    public static var title: LocalizedStringResource = "Refresh App Provisioning Profile"
    public static var description = IntentDescription("Silently refreshes the 7-day provisioning profile in the background via LocalDevVPN without opening the app.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try await SelfRefreshManager.shared.refreshProfileOnly()
        return .result(dialog: "Provisioning profile refreshed for another 7 days.")
    }
}
#endif
