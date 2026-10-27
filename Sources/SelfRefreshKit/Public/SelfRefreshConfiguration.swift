import Foundation

/// Supported built-in languages for `SelfRefreshKit`.
/// Priority:
/// 1. Manual user override in `SelfRefreshKit` UI (if not `.followHost`)
/// 2. Host application language / system preferred language
/// 3. Fallback to `.english`
public enum SelfRefreshLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case followHost = "host"
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case cantonese = "yue-Hant-HK"
    case japanese = "ja"
    case german = "de"
    case french = "fr"
    case korean = "ko"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .followHost: return "Auto (Host / System)"
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        case .cantonese: return "粵語 / 繁體中文"
        case .japanese: return "日本語"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .korean: return "한국어"
        }
    }

    /// Resolves a locale/language identifier string into one of the 7 concrete languages, falling back to `.english`.
    public static func resolveConcrete(from identifier: String) -> SelfRefreshLanguage {
        let lower = identifier.lowercased().replacingOccurrences(of: "_", with: "-")
        if lower.hasPrefix("yue") || lower.hasPrefix("zh-hant") || lower.hasPrefix("zh-hk") || lower.hasPrefix("zh-tw") || lower.hasPrefix("zh-mo") {
            return .cantonese
        }
        if lower.hasPrefix("zh") {
            return .simplifiedChinese
        }
        if lower.hasPrefix("ja") {
            return .japanese
        }
        if lower.hasPrefix("de") {
            return .german
        }
        if lower.hasPrefix("fr") {
            return .french
        }
        if lower.hasPrefix("ko") {
            return .korean
        }
        if lower.hasPrefix("en") {
            return .english
        }
        return .english
    }
}

/// Supported loopback VPN applications for local lockdownd communication (`10.7.0.1`).
/// Defaults to `.localDevVPN` while remaining compatible with `.stosVPN` and `.wireGuard`.
public enum LoopbackVPNApp: String, CaseIterable, Codable, Identifiable, Sendable {
    case localDevVPN = "LocalDevVPN"
    case stosVPN = "StosVPN"
    case wireGuard = "WireGuard"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .localDevVPN: return "LocalDevVPN"
        case .stosVPN: return "StosVPN"
        case .wireGuard: return "WireGuard"
        }
    }

    public var urlScheme: URL? {
        switch self {
        case .localDevVPN: return URL(string: "localdevvpn://")
        case .stosVPN: return URL(string: "stosvpn://")
        case .wireGuard: return URL(string: "wireguard://")
        }
    }

    public var appStoreURL: URL? {
        switch self {
        case .localDevVPN: return URL(string: "https://apps.apple.com/app/localdevvpn/id6744003051")
        case .stosVPN: return URL(string: "https://apps.apple.com/app/stosvpn/id6744003051")
        case .wireGuard: return URL(string: "https://apps.apple.com/app/wireguard/id1441195209")
        }
    }
}

/// Official and community Anisette V3 server presets with automatic latency check and fallback support.
public struct AnisetteServerPreset: Identifiable, Equatable, Sendable {
    public var id: String { url }
    public let name: String
    public let url: String

    public init(name: String, url: String) {
        self.name = name
        self.url = url
    }

    public static let defaults: [AnisetteServerPreset] = [
        AnisetteServerPreset(name: "SideStore Official (.io)", url: "https://ani.sidestore.io"),
        AnisetteServerPreset(name: "SideStore Official (.app)", url: "https://ani.sidestore.app"),
        AnisetteServerPreset(name: "SideStore Official (.zip)", url: "https://ani.sidestore.zip"),
        AnisetteServerPreset(name: "SideStore New V3", url: "https://new.ani.sidestore.io"),
        AnisetteServerPreset(name: "jkcoxson Community", url: "https://ani.jkcoxson.com"),
        AnisetteServerPreset(name: "nythepegasus Community", url: "https://ani.npeg.us")
    ]
}

/// Detailed inspection summary of an imported `.mobiledevicepairing` / `pairingFile.plist`.
public struct PairingFileInspection: Equatable, Codable, Sendable {
    public var udid: String
    public var wifiMACAddress: String
    public var hostID: String
    public var systemBUID: String
    public var hasEscrowBag: Bool
    public var hasRPPairingKeys: Bool
    public var importedAt: Date

    public init(
        udid: String,
        wifiMACAddress: String,
        hostID: String,
        systemBUID: String,
        hasEscrowBag: Bool,
        hasRPPairingKeys: Bool,
        importedAt: Date = Date()
    ) {
        self.udid = udid
        self.wifiMACAddress = wifiMACAddress
        self.hostID = hostID
        self.systemBUID = systemBUID
        self.hasEscrowBag = hasEscrowBag
        self.hasRPPairingKeys = hasRPPairingKeys
        self.importedAt = importedAt
    }
}

/// Persistent authenticated Apple Developer session saved in Keychain after completing full login (and 2FA).
public struct AppleAuthSession: Equatable, Codable, Sendable {
    public var appleID: String
    public var teamID: String
    public var teamName: String
    public var sessionToken: String
    public var anisetteSerial: String
    public var authenticatedAt: Date
    public var requiresTwoFactor: Bool

    public init(
        appleID: String,
        teamID: String,
        teamName: String,
        sessionToken: String,
        anisetteSerial: String,
        authenticatedAt: Date = Date(),
        requiresTwoFactor: Bool = false
    ) {
        self.appleID = appleID
        self.teamID = teamID
        self.teamName = teamName
        self.sessionToken = sessionToken
        self.anisetteSerial = anisetteSerial
        self.authenticatedAt = authenticatedAt
        self.requiresTwoFactor = requiresTwoFactor
    }
}

/// Result of the comprehensive 4-point Health Check.
public struct HealthCheckReport: Equatable, Sendable {
    public enum ItemStatus: String, Equatable, Sendable {
        case healthy
        case warning
        case failed
    }

    public struct ItemResult: Identifiable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var status: ItemStatus
        public var detail: String
        public var latencyMs: Int?

        public init(id: String, title: String, status: ItemStatus, detail: String, latencyMs: Int? = nil) {
            self.id = id
            self.title = title
            self.status = status
            self.detail = detail
            self.latencyMs = latencyMs
        }
    }

    public var checkedAt: Date
    public var items: [ItemResult]

    public var isAllHealthy: Bool {
        items.allSatisfy { $0.status == .healthy }
    }

    public init(checkedAt: Date = Date(), items: [ItemResult]) {
        self.checkedAt = checkedAt
        self.items = items
    }
}

/// Configuration for `SelfRefreshKit`.
public struct SelfRefreshConfiguration: Sendable {
    public static let kitVersion = "0.3.0"
    public static let minimuxerEngineVersion = "minimuxer-bridge 0.4.x"
    public static let altSignEngineVersion = "SideSign/AltSign 1.6.x"
    public static let officialRepositoryURL = URL(string: "https://github.com/Cc-Cece/SelfRefreshKit/")!

    /// Custom URL scheme registered by the host application (kept for backward compatibility).
    public var urlScheme: String
    /// Default preferred loopback VPN app (`.localDevVPN`).
    public var preferredVPN: LoopbackVPNApp
    /// Default Anisette V3 server endpoint.
    public var defaultAnisetteURL: String
    /// Optional GitHub repository slug (e.g. `"Cc-Cece/PicHarbor-iOS"`) for one-tap OTA update checks.
    public var githubRepository: String?
    /// Background task identifier suffix or full identifier if the host registers background refresh.
    public var backgroundTaskIdentifier: String?
    /// Optional provider returning the host application's current language code (e.g. `"zh-Hans"`, `"en"`, `"yue-Hant-HK"`).
    public var hostLanguageProvider: (@Sendable () -> String)?
    /// Optional custom localization function injected by the host app.
    public var localizer: (@Sendable (String) -> String)?

    public init(
        urlScheme: String = "selfrefresh",
        preferredVPN: LoopbackVPNApp = .localDevVPN,
        defaultAnisetteURL: String = "https://ani.sidestore.io",
        githubRepository: String? = nil,
        backgroundTaskIdentifier: String? = nil,
        hostLanguageProvider: (@Sendable () -> String)? = nil,
        localizer: (@Sendable (String) -> String)? = nil
    ) {
        self.urlScheme = urlScheme
        self.preferredVPN = preferredVPN
        self.defaultAnisetteURL = defaultAnisetteURL
        self.githubRepository = githubRepository
        self.backgroundTaskIdentifier = backgroundTaskIdentifier
        self.hostLanguageProvider = hostLanguageProvider
        self.localizer = localizer
    }

    public var refreshWakeupURLString: String {
        "\(urlScheme)://refresh"
    }
}

/// Parsed information from the application's `embedded.mobileprovision` file.
public struct ProvisioningProfileMetadata: Equatable, Sendable {
    public var uuid: String
    public var name: String
    public var appIDName: String
    public var bundleIdentifier: String
    public var teamIdentifier: String
    public var teamName: String
    public var creationDate: Date
    public var expirationDate: Date
    public var certificateSHA1Fingerprints: [String]

    public init(
        uuid: String,
        name: String,
        appIDName: String,
        bundleIdentifier: String,
        teamIdentifier: String,
        teamName: String,
        creationDate: Date,
        expirationDate: Date,
        certificateSHA1Fingerprints: [String] = []
    ) {
        self.uuid = uuid
        self.name = name
        self.appIDName = appIDName
        self.bundleIdentifier = bundleIdentifier
        self.teamIdentifier = teamIdentifier
        self.teamName = teamName
        self.creationDate = creationDate
        self.expirationDate = expirationDate
        self.certificateSHA1Fingerprints = certificateSHA1Fingerprints
    }

    public func remainingTimeInterval(from now: Date = Date()) -> TimeInterval {
        expirationDate.timeIntervalSince(now)
    }

    public func remainingDaysAndHours(from now: Date = Date()) -> (days: Int, hours: Int, isExpired: Bool) {
        let interval = remainingTimeInterval(from: now)
        if interval <= 0 {
            return (0, 0, true)
        }
        let totalHours = Int(interval / 3600)
        return (totalHours / 24, totalHours % 24, false)
    }

    public func isExpiringSoon(thresholdHours: Int = 48, from now: Date = Date()) -> Bool {
        let interval = remainingTimeInterval(from: now)
        return interval <= TimeInterval(thresholdHours * 3600)
    }
}

/// Protocol allowing custom or native `AltSign` + `Minimuxer` runtime bridges to be plugged in.
public protocol SelfRefreshBackendDriver: Sendable {
    var driverName: String { get }
    func testLoopbackTunnel(host: String, port: UInt16) async -> Bool
    func inspectPairingFile(data: Data) throws -> PairingFileInspection
    func probeAnisetteServer(url: URL) async throws -> (headers: [String: String], latencyMs: Int)
    func authenticateAppleID(
        appleID: String,
        password: String,
        twoFactorCode: String?,
        anisetteURL: URL
    ) async throws -> AppleAuthSession
    func refreshProvisioningProfileOnly(
        appleID: String,
        password: String,
        session: AppleAuthSession?,
        anisetteURL: URL,
        pairingData: Data,
        bundleIdentifier: String
    ) async throws -> ProvisioningProfileMetadata
    func resignAndInstallIPA(
        ipaFileURL: URL,
        appleID: String,
        password: String,
        session: AppleAuthSession?,
        anisetteURL: URL,
        pairingData: Data,
        bundleIdentifier: String
    ) async throws -> ProvisioningProfileMetadata
}

public extension SelfRefreshBackendDriver {
    func validatePairingFile(xmlContent: String) throws -> String {
        guard let data = xmlContent.data(using: .utf8) else {
            throw SelfRefreshError.invalidPairingFile("编码格式无效")
        }
        return try inspectPairingFile(data: data).udid
    }
}
