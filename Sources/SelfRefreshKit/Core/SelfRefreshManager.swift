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
    @Published public private(set) var customGitHubRepository: String? {
        didSet {
            if let repo = customGitHubRepository, !repo.isEmpty {
                defaults.set(repo, forKey: Keys.customGitHubRepo)
            } else {
                defaults.removeObject(forKey: Keys.customGitHubRepo)
            }
        }
    }
    @Published public var isSetupGuideSkipped: Bool = false {
        didSet {
            defaults.set(isSetupGuideSkipped, forKey: Keys.setupGuideSkipped)
        }
    }

    @Published public private(set) var isRefreshing: Bool = false
    @Published public private(set) var isAuthenticating: Bool = false
    /// True while SideSign is waiting for a 6-digit Apple 2FA code.
    @Published public private(set) var isAwaitingTwoFactor: Bool = false
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
        static let customGitHubRepo = "selfrefreshkit.customGitHubRepo"
        static let takenOver = "selfrefreshkit.takenOver"
        static let lastRefreshDate = "selfrefreshkit.lastRefreshDate"
        static let cachedExpirationDate = "selfrefreshkit.cachedExpirationDate"
        static let cachedProfileMetadata = "selfrefreshkit.cachedProfileMetadata"
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
        self.customGitHubRepository = defaults.string(forKey: Keys.customGitHubRepo)
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

    /// Translates a `SelfRefreshL10nKey` according to:
    /// 1. User's manual language choice in `SelfRefreshKit` (if not `.followHost`)
    /// 2. Host app's language provider or system preferred language (with `.english` fallback)
    public func localized(_ key: SelfRefreshL10nKey) -> String {
        localized(key.rawValue)
    }

    /// Translates a string key according to:
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

    /// Effective GitHub repository (`owner/repo`) used for cloud OTA checks.
    public var effectiveGitHubRepository: String? {
        if let custom = customGitHubRepository?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        if let hostDefault = configuration.githubRepository?.trimmingCharacters(in: .whitespacesAndNewlines), !hostDefault.isEmpty {
            return hostDefault
        }
        return nil
    }

    /// Updates the custom GitHub OTA repository (`owner/repo`) after the user confirms the security warning.
    public func updateCustomGitHubRepository(_ repository: String?) {
        let trimmed = repository?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty || trimmed == configuration.githubRepository {
            customGitHubRepository = nil
        } else {
            customGitHubRepository = trimmed
        }
        if let active = effectiveGitHubRepository {
            postNotice(
                title: localized(.noticeOTASourceUpdatedTitle),
                message: active,
                isError: false
            )
        }
    }

    /// Resets the GitHub OTA repository to the host application's default configuration.
    public func resetGitHubRepositoryToDefault() {
        customGitHubRepository = nil
        if let active = effectiveGitHubRepository {
            postNotice(
                title: localized(.noticeOTASourceUpdatedTitle),
                message: active,
                isError: false
            )
        }
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
        var active: ProvisioningProfileMetadata? = ProfileInspector.inspectEmbeddedProfile(in: bundleURL)
        if let data = defaults.data(forKey: Keys.cachedProfileMetadata),
           let cached = try? JSONDecoder().decode(ProvisioningProfileMetadata.self, from: data) {
            if let current = active {
                if cached.expirationDate > current.expirationDate {
                    active = cached
                }
            } else {
                active = cached
            }
        }
        if let resolved = active {
            self.profileMetadata = resolved
            defaults.set(resolved.expirationDate, forKey: Keys.cachedExpirationDate)
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
            let rpBadge = inspection.hasRPPairingKeys ? " (RPPairing)" : ""
            postNotice(
                title: localized(.noticePairingImportedTitle),
                message: "UDID: \(inspection.udid)\nWiFi MAC: \(inspection.wifiMACAddress)\(rpBadge)",
                isError: false
            )
            return inspection
        } catch {
            postNotice(
                title: localized(.noticePairingFailedTitle),
                message: error.localizedDescription,
                isError: true
            )
            throw error
        }
    }

    public func importPairingXMLContent(_ xmlContent: String) throws {
        guard let data = xmlContent.data(using: .utf8) else {
            throw SelfRefreshError.invalidPairingFile("Invalid UTF-8")
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
        try ensureExclusiveAuthOperation(noticeTitle: .noticeAuthFailedTitle)

        let trimmedID = appleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = anisetteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty, !password.isEmpty else {
            let err = SelfRefreshError.missingAppleIDCredentials
            postNotice(title: localized(.noticeAuthFailedTitle), message: localized(err.localizedDescription), isError: true)
            throw err
        }
        guard let parsedURL = URL(string: trimmedURL),
              let scheme = parsedURL.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            let err = SelfRefreshError.invalidAnisetteURL
            postNotice(title: localized(.noticeAuthFailedTitle), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        isAuthenticating = true
        defer {
            isAuthenticating = false
            clearTwoFactorWaitIfNeeded()
        }

        do {
            let session = try await SelfRefreshAuthContext.$interactiveTwoFactor.withValue(true) {
                try await driver.authenticateAppleID(
                    appleID: trimmedID,
                    password: password,
                    twoFactorCode: twoFactorCode,
                    anisetteURL: parsedURL
                )
            }
            try SelfRefreshKeychain.savePassword(password, for: trimmedID)
            try SelfRefreshKeychain.saveAuthSession(session)

            self.appleID = trimmedID
            self.anisetteURLString = trimmedURL
            self.authSession = session
            defaults.set(trimmedID, forKey: Keys.appleID)
            defaults.set(trimmedURL, forKey: Keys.anisetteURL)

            postNotice(
                title: localized(.noticeAuthSuccessTitle),
                message: "\(trimmedID)\nTeam ID: \(session.teamID)",
                isError: false
            )
            return session
        } catch {
            postNotice(
                title: localized(.noticeAuthFailedTitle),
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
        postNotice(title: localized(.noticeSignedOutTitle), message: localized(.noticeSignedOutMessage))
    }

    /// Shows the 2FA sheet. Ignored unless login or refresh is actually in flight, so a late callback cannot reopen it.
    func beginTwoFactorChallenge() {
        guard isAuthenticating || isRefreshing else { return }
        isAwaitingTwoFactor = true
    }

    /// Resumes the SideSign verification handler. The sheet stays up until the code has 6 digits.
    public func submitTwoFactorCode(_ code: String) {
        let digits = code.filter(\.isNumber)
        guard isAwaitingTwoFactor, digits.count == 6 else { return }
        isAwaitingTwoFactor = false
        #if canImport(SideSign)
        Task {
            await TwoFactorAuthBridge.shared.submitVerificationCode(digits)
        }
        #endif
    }

    /// Resumes the SideSign verification handler with `.cancel`.
    public func cancelTwoFactorEntry() {
        guard isAwaitingTwoFactor else { return }
        isAwaitingTwoFactor = false
        #if canImport(SideSign)
        Task {
            await TwoFactorAuthBridge.shared.cancelWaiting()
        }
        #endif
    }

    /// Rejects a second login or refresh. Does not clear `isAwaitingTwoFactor`, so the operation already waiting keeps its sheet.
    private func ensureExclusiveAuthOperation(noticeTitle: SelfRefreshL10nKey) throws {
        guard !isRefreshing, !isAuthenticating else {
            let err = SelfRefreshError.backendOperationFailed("已有登录或续签正在进行。")
            postNotice(title: localized(noticeTitle), message: localized(err.localizedDescription), isError: true)
            throw err
        }
    }

    private func clearTwoFactorWaitIfNeeded() {
        if isAwaitingTwoFactor {
            cancelTwoFactorEntry()
        }
    }

    private func hostBundleIdentifier() throws -> String {
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else {
            throw SelfRefreshError.backendOperationFailed("无法读取宿主 App 的 Bundle ID。")
        }
        return bundleID
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
            let detail = "UDID: \(info.udid)" + (info.hasRPPairingKeys ? " · RPPairing" : "")
            items.append(.init(
                id: "pairing",
                title: localized(.healthItemPairingTitle),
                status: .healthy,
                detail: detail
            ))
        } else {
            items.append(.init(
                id: "pairing",
                title: localized(.healthItemPairingTitle),
                status: .failed,
                detail: localized(.healthItemPairingMissing)
            ))
        }

        // 2. Loopback VPN Tunnel Health
        let tunnelOK = await checkTunnelConnection()
        items.append(.init(
            id: "tunnel",
            title: "\(localized(.requiredTunnelTitle)) (\(selectedVPN.displayName))",
            status: tunnelOK ? .healthy : .warning,
            detail: tunnelOK
                ? localized(.healthItemTunnelConnected)
                : localized(.healthItemTunnelDisconnected)
        ))

        // 3. Anisette V3 Server Health & Latency
        if let url = URL(string: anisetteURLString) {
            do {
                let probe = try await driver.probeAnisetteServer(url: url)
                items.append(.init(
                    id: "anisette",
                    title: "Anisette V3 (\(url.host ?? anisetteURLString))",
                    status: .healthy,
                    detail: "OK (\(probe.latencyMs) ms)",
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
                detail: localized(.healthItemAnisetteInvalid)
            ))
        }

        // 4. Apple Developer Session & Profile Health
        if let session = authSession, hasSavedCredentials {
            let profileInfo: String
            if let meta = profileMetadata {
                let rem = meta.remainingDaysAndHours()
                profileInfo = rem.isExpired ? localized(.statusExpiredBadge) : "\(rem.days)d \(rem.hours)h"
            } else {
                profileInfo = isLocalCertificateTakenOver ? localized(.healthItemProfileTakenOver) : localized(.healthItemProfilePending)
            }
            items.append(.init(
                id: "account",
                title: localized(.healthItemAccountTitle),
                status: isLocalCertificateTakenOver ? .healthy : .warning,
                detail: "Team: \(session.teamID) · \(profileInfo)"
            ))
        } else {
            items.append(.init(
                id: "account",
                title: localized(.healthItemAccountTitle),
                status: .failed,
                detail: localized(.healthItemAccountMissing)
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
                title: localized(.noticeFastestServerTitle),
                message: "\(bestURL) (\(bestLatency) ms)",
                isError: false
            )
        }
        return bestURL
    }

    // MARK: - Mode A: 1-Second Profile-Only Refresh (No Crash / No IPA Needed)

    /// Installs a new provisioning profile with misagent. Does not mark the local certificate as taken over.
    /// - Parameter allowInteractiveTwoFactor: Pass `false` from the background Shortcut so a missing code fails instead of waiting.
    public func refreshProfileOnly(allowInteractiveTwoFactor: Bool = true) async throws {
        try ensureExclusiveAuthOperation(noticeTitle: .noticeRefreshFailedTitle)
        isRefreshing = true
        lastError = ""
        statusMessage = localized(.statusProcessing)
        defer {
            isRefreshing = false
            clearTwoFactorWaitIfNeeded()
        }

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
            postNotice(title: localized(.noticeRefreshFailedTitle), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        let tunnelReady = await checkTunnelConnection()
        guard tunnelReady else {
            let err = SelfRefreshError.tunnelDisconnected(selectedVPN)
            postNotice(title: localized(.noticeTunnelDisconnectedTitle), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        let trimmedID = appleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty,
              let password = try SelfRefreshKeychain.loadPassword(for: trimmedID),
              !password.isEmpty else {
            let err = SelfRefreshError.missingAppleIDCredentials
            postNotice(title: localized(.noticeMissingCredentialsTitle), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        guard let anisetteURL = URL(string: anisetteURLString) else {
            let err = SelfRefreshError.invalidAnisetteURL
            postNotice(title: localized(.noticeRefreshFailedTitle), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        let updatedProfile: ProvisioningProfileMetadata
        do {
            let bundleID = try hostBundleIdentifier()
            updatedProfile = try await SelfRefreshAuthContext.$interactiveTwoFactor.withValue(allowInteractiveTwoFactor) {
                try await driver.refreshProvisioningProfileOnly(
                    appleID: trimmedID,
                    password: password,
                    session: authSession,
                    anisetteURL: anisetteURL,
                    pairingData: pairingData,
                    bundleIdentifier: bundleID
                )
            }
        } catch {
            postNotice(title: localized(.noticeRefreshFailedTitle), message: localized(error.localizedDescription), isError: true)
            throw error
        }

        self.profileMetadata = updatedProfile
        let now = Date()
        self.lastRefreshDate = now
        defaults.set(now, forKey: Keys.lastRefreshDate)
        defaults.set(updatedProfile.expirationDate, forKey: Keys.cachedExpirationDate)
        if let encoded = try? JSONEncoder().encode(updatedProfile) {
            defaults.set(encoded, forKey: Keys.cachedProfileMetadata)
        }
        postNotice(
            title: localized(.noticeRefreshSuccessTitle),
            message: localized(.noticeRefreshSuccessMessage),
            isError: false
        )
    }

    // MARK: - Mode B: Full IPA Resign & Self-Install (Initial Takeover, Cloud OTA, & Direct IPA URL)

    public func resignAndInstall(ipaURL: URL, allowInteractiveTwoFactor: Bool = true) async throws {
        try ensureExclusiveAuthOperation(noticeTitle: .noticeRefreshFailedTitle)
        isRefreshing = true
        lastError = ""
        statusMessage = localized(.statusProcessing)
        defer {
            isRefreshing = false
            clearTwoFactorWaitIfNeeded()
        }

        let accessed = ipaURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { ipaURL.stopAccessingSecurityScopedResource() }
        }

        guard FileManager.default.fileExists(atPath: pairingFileURL.path),
              let pairingData = try? Data(contentsOf: pairingFileURL) else {
            let err = SelfRefreshError.missingPairingFile
            postNotice(title: localized(.noticeRefreshFailedTitle), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        let tunnelReady = await checkTunnelConnection()
        guard tunnelReady else {
            let err = SelfRefreshError.tunnelDisconnected(selectedVPN)
            postNotice(title: localized(.noticeTunnelDisconnectedTitle), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        let trimmedID = appleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty,
              let password = try SelfRefreshKeychain.loadPassword(for: trimmedID),
              !password.isEmpty else {
            let err = SelfRefreshError.missingAppleIDCredentials
            postNotice(title: localized(.noticeMissingCredentialsTitle), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        guard let anisetteURL = URL(string: anisetteURLString) else {
            let err = SelfRefreshError.invalidAnisetteURL
            postNotice(title: localized(.noticeRefreshFailedTitle), message: localized(err.localizedDescription), isError: true)
            throw err
        }

        let updatedProfile: ProvisioningProfileMetadata
        do {
            let bundleID = try hostBundleIdentifier()
            updatedProfile = try await SelfRefreshAuthContext.$interactiveTwoFactor.withValue(allowInteractiveTwoFactor) {
                try await driver.resignAndInstallIPA(
                    ipaFileURL: ipaURL,
                    appleID: trimmedID,
                    password: password,
                    session: authSession,
                    anisetteURL: anisetteURL,
                    pairingData: pairingData,
                    bundleIdentifier: bundleID
                )
            }
        } catch {
            postNotice(title: localized(.noticeRefreshFailedTitle), message: localized(error.localizedDescription), isError: true)
            throw error
        }

        self.profileMetadata = updatedProfile
        self.isLocalCertificateTakenOver = true
        let now = Date()
        self.lastRefreshDate = now
        defaults.set(true, forKey: Keys.takenOver)
        defaults.set(now, forKey: Keys.lastRefreshDate)
        defaults.set(updatedProfile.expirationDate, forKey: Keys.cachedExpirationDate)
        if let encoded = try? JSONEncoder().encode(updatedProfile) {
            defaults.set(encoded, forKey: Keys.cachedProfileMetadata)
        }
        postNotice(
            title: localized(.noticeTakeoverSuccessTitle),
            message: localized(.noticeTakeoverSuccessMessage),
            isError: false
        )
    }

    // MARK: - Cloud OTA Check (GitHub Releases) & Direct IPA Link Download

    public func checkGitHubOTAUpdate() async throws -> (tag: String, ipaURL: URL) {
        guard let repo = effectiveGitHubRepository, !repo.isEmpty,
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
        statusMessage = localized(.statusProcessing)
        let (tempURL, response) = try await URLSession.shared.download(from: remoteIPAURL)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SelfRefreshError.otaNoReleaseFound
        }
        let targetURL = FileManager.default.temporaryDirectory.appendingPathComponent("OTAUpdate-\(UUID().uuidString).ipa")
        try? FileManager.default.removeItem(at: targetURL)
        try FileManager.default.moveItem(at: tempURL, to: targetURL)
        defer { try? FileManager.default.removeItem(at: targetURL) }
        try await resignAndInstall(ipaURL: targetURL)
    }

    /// Validates a direct HTTP/HTTPS IPA URL string, downloads the `.ipa`, and performs on-device resigning and installation.
    public func downloadAndInstallDirectIPA(urlString: String) async throws {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            postNotice(
                title: localized(.noticeInvalidURLTitle),
                message: localized(.noticeInvalidURLMessage),
                isError: true
            )
            throw SelfRefreshError.missingIPAFile
        }
        try await downloadAndInstallOTA(from: url)
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
            return "\(localized(.statusSetupRequiredBadge)) (\(completedRequiredStepsCount)/3)"
        }
        guard let meta = profileMetadata else {
            return localized(.statusReadyBadge)
        }
        let remaining = meta.remainingDaysAndHours()
        if remaining.isExpired {
            return localized(.statusExpiredBadge)
        }
        return "\(remaining.days)d \(remaining.hours)h"
    }
}

#if canImport(AppIntents)
/// Built-in background iOS Shortcuts `AppIntent`.
/// - Uses the main bundle for `LocalizedStringResource` metadata extraction as required by Xcode's `appintentsmetadataprocessor` (defaulting to `"Refresh App Provisioning Profile"`).
/// - Runs purely in the background (`openAppWhenRun = false`) without opening or jumping to the host app.
@available(iOS 17.0, macOS 14.0, *)
public struct SelfRefreshProfileIntent: AppIntent {
    public static var title: LocalizedStringResource = "Refresh App Provisioning Profile"
    public static var description = IntentDescription("Silently refreshes the 7-day provisioning profile in the background via LocalDevVPN without opening the app.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try await SelfRefreshManager.shared.refreshProfileOnly(allowInteractiveTwoFactor: false)
        let dialogText = SelfRefreshManager.shared.localized(.intentRefreshResult)
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}
#endif
