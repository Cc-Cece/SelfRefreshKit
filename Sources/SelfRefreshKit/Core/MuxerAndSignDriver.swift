import Foundation
import Network
#if canImport(Darwin)
import Darwin
#endif

#if canImport(SideSign)
import SideSign
import AnisetteKit
#endif

#if canImport(IDevice)
import IDevice
#endif

/// Propagates whether the current signing call can wait for a user-entered Apple 2FA code.
enum SelfRefreshAuthContext {
    @TaskLocal static var interactiveTwoFactor = true
}

/// Default driver that implements:
/// 1. Device pairing file inspection (supporting both iOS 17+ RPPairing plist and standard Lockdown plist).
/// 2. Loopback VPN interface and TCP port probing (probes `10.7.0.1` on port 49152 for iOS 17+ RPPairing and 62078 for Lockdown).
/// 3. Anisette V3 server probing and failover across official and mirror endpoints.
/// 4. Apple ID SRP authentication and 2FA handling via SideStore's `SideSign`.
/// 5. Real on-device 1-second profile installation (`misagent_install`) and full IPA resign/self-install via `SideSign` + `IDevice`.
public struct DefaultSelfRefreshDriver: SelfRefreshBackendDriver {
    public var driverName: String {
        #if canImport(SideSign) && canImport(IDevice)
        return "SideSign + IDevice (Native Engine)"
        #else
        return "Signing Engine Unavailable"
        #endif
    }

    public init() {}

    /// Tests whether the local loopback tunnel (`10.7.0.1` used by LocalDevVPN / StosVPN / WireGuard) is active.
    /// Probes both port 62078 (lockdown) and port 49152 (iOS 17+ remote pairing).
    public func testLoopbackTunnel(host: String = "10.7.0.1", port: UInt16 = 62078) async -> Bool {
        if Self.hasLoopbackTunnelInterface(matchingPrefix: "10.7.0.") {
            return true
        }
        let primaryProbe = await Self.probeTCP(host: host, port: port, timeoutSeconds: 0.8)
        if primaryProbe { return true }
        if port != 49152 {
            return await Self.probeTCP(host: host, port: 49152, timeoutSeconds: 0.8)
        }
        return false
    }

    /// Parses and validates a `.mobiledevicepairing` or `pairingFile.plist` (supports both XML and Binary plist formats,
    /// as well as iOS 17+ `rppairing` and legacy `lockdown` schemas).
    public func inspectPairingFile(data: Data) throws -> PairingFileInspection {
        guard !data.isEmpty,
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw SelfRefreshError.invalidPairingFile("不是有效的 Plist 格式（请确认由 idevice_pair 生成）")
        }

        let hasLockdownCert = plist["DeviceCertificate"] != nil && plist["HostCertificate"] != nil && plist["HostPrivateKey"] != nil
        let hasRPPairing = plist["public_key"] != nil && plist["private_key"] != nil && (plist["identifier"] != nil || plist["UDID"] != nil)

        guard hasLockdownCert || hasRPPairing else {
            throw SelfRefreshError.invalidPairingFile("缺少配对密钥（需包含 DeviceCertificate 或 public_key/private_key）")
        }

        let udid = (plist["UDID"] as? String)
            ?? (plist["identifier"] as? String)
            ?? "Unknown-UDID"
        let wifiMAC = (plist["WiFiMACAddress"] as? String) ?? "N/A"
        let hostID = (plist["HostID"] as? String) ?? "N/A"
        let systemBUID = (plist["SystemBUID"] as? String) ?? "N/A"
        let hasEscrow = plist["EscrowBag"] != nil

        return PairingFileInspection(
            udid: udid,
            wifiMACAddress: wifiMAC,
            hostID: hostID,
            systemBUID: systemBUID,
            hasEscrowBag: hasEscrow,
            hasRPPairingKeys: hasRPPairing,
            importedAt: Date()
        )
    }

    /// Probes an Anisette V3 server endpoint, validates returned `X-Apple-I-MD` headers, and measures latency in ms.
    public func probeAnisetteServer(url: URL) async throws -> (headers: [String: String], latencyMs: Int) {
        let start = DispatchTime.now()
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = "GET"
        request.setValue("SelfRefreshKit/\(SelfRefreshConfiguration.kitVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsedMs = max(1, Int((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000))
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw SelfRefreshError.anisetteServerUnreachable(url.host ?? url.absoluteString)
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var headers: [String: String] = [:]
                for (k, v) in json {
                    if let s = v as? String {
                        headers[k] = s
                    }
                }
                return (headers, elapsedMs)
            }
            return ([:], elapsedMs)
        } catch let err as SelfRefreshError {
            throw err
        } catch {
            throw SelfRefreshError.anisetteServerUnreachable(url.host ?? url.absoluteString)
        }
    }

    /// Executes the Apple ID authentication workflow via `SideSign` SRP handshake with 2FA support.
    public func authenticateAppleID(
        appleID: String,
        password: String,
        twoFactorCode: String?,
        anisetteURL: URL
    ) async throws -> AppleAuthSession {
        let normalizedID = appleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedID.contains("@"), normalizedID.contains("."), !password.isEmpty else {
            throw SelfRefreshError.appleAuthenticationFailed("请输入有效的 Apple ID 邮箱与密码")
        }

        #if canImport(SideSign)
        return try await RealSideSignDriverHelper.shared.authenticateAppleID(
            appleID: normalizedID,
            password: password,
            twoFactorCode: twoFactorCode,
            primaryAnisetteURL: anisetteURL
        )
        #else
        throw SelfRefreshError.backendOperationFailed("未链接 SideSign，无法登录 Apple 开发者账号。")
        #endif
    }

    /// Refreshes the provisioning profile directly on the iOS device in ~1 second via `SideSign` + `IDevice` (misagent).
    public func refreshProvisioningProfileOnly(
        appleID: String,
        password: String,
        session: AppleAuthSession?,
        anisetteURL: URL,
        pairingData: Data,
        bundleIdentifier: String
    ) async throws -> ProvisioningProfileMetadata {
        let pairingInfo = try inspectPairingFile(data: pairingData)

        #if canImport(SideSign) && canImport(IDevice)
        return try await RealSideSignDriverHelper.shared.refreshProvisioningProfileOnly(
            appleID: appleID,
            password: password,
            session: session,
            primaryAnisetteURL: anisetteURL,
            pairingData: pairingData,
            pairingInfo: pairingInfo,
            bundleIdentifier: bundleIdentifier
        )
        #else
        throw SelfRefreshError.backendOperationFailed("未链接 SideSign 与 IDevice，无法在本机安装描述文件。")
        #endif
    }

    /// Unzips the unsigned IPA, generates developer certificates/profiles via `SideSign`, signs Mach-O binaries,
    /// and installs the app on-device via `IDevice` AFC and installation_proxy.
    public func resignAndInstallIPA(
        ipaFileURL: URL,
        appleID: String,
        password: String,
        session: AppleAuthSession?,
        anisetteURL: URL,
        pairingData: Data,
        bundleIdentifier: String
    ) async throws -> ProvisioningProfileMetadata {
        guard FileManager.default.fileExists(atPath: ipaFileURL.path) else {
            throw SelfRefreshError.missingIPAFile
        }
        let pairingInfo = try inspectPairingFile(data: pairingData)

        #if canImport(SideSign) && canImport(IDevice)
        return try await RealSideSignDriverHelper.shared.resignAndInstallIPA(
            ipaFileURL: ipaFileURL,
            appleID: appleID,
            password: password,
            session: session,
            primaryAnisetteURL: anisetteURL,
            pairingData: pairingData,
            pairingInfo: pairingInfo,
            bundleIdentifier: bundleIdentifier
        )
        #else
        throw SelfRefreshError.backendOperationFailed("未链接 SideSign 与 IDevice，无法在本机重签并安装 IPA。")
        #endif
    }

    // MARK: - Loopback Interface & Socket Helpers

    public static func hasLoopbackTunnelInterface(matchingPrefix prefix: String = "10.7.0.") -> Bool {
        #if canImport(Darwin)
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return false
        }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let interface = current.pointee
            if let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    addr,
                    socklen_t(addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                ) == 0 {
                    let ip = String(cString: hostname)
                    if ip.hasPrefix(prefix) {
                        return true
                    }
                }
            }
            ptr = interface.ifa_next
        }
        #endif
        return false
    }

    private static func probeTCP(host: String, port: UInt16, timeoutSeconds: TimeInterval) async -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let stateBox = ProbeStateBox()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if stateBox.completeOnce() {
                        connection.cancel()
                        continuation.resume(returning: true)
                    }
                case .failed, .cancelled:
                    if stateBox.completeOnce() {
                        connection.cancel()
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue.global(qos: .utility))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeoutSeconds) {
                if stateBox.completeOnce() {
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }

}

private final class ProbeStateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false

    func completeOnce() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if completed { return false }
        completed = true
        return true
    }
}

/// Apple rejects Mac, Xcode, and Android GrandSlam identities with -80045 before 2FA.
/// The Windows iTunes client info and akd user agent are the pair that still completes SRP.
enum GrandSlamClientIdentity {
    static let windowsClientInfo = "<PC> <Windows;6.2(0,0);9200> <com.apple.AuthKit/1 (com.apple.iTunes/12.12.4.1)>"
    static let akdUserAgent = "akd/1.0 CFNetwork/808.1.4"

    static func acceptedClientInfo(from serverValue: String) -> String {
        containsRejectedMarker(serverValue) ? windowsClientInfo : serverValue
    }

    static func acceptedUserAgent(from serverValue: String) -> String {
        serverValue.isEmpty || containsRejectedMarker(serverValue) ? akdUserAgent : serverValue
    }

    static func isRejectedIdentityCode(_ code: Int) -> Bool {
        code == -80045 || code == -45061
    }

    private static func containsRejectedMarker(_ value: String) -> Bool {
        ["Macintosh", "Mac OS", "macOS", "MacBook", "Xcode", "Android"].contains {
            value.localizedCaseInsensitiveContains($0)
        }
    }
}

// MARK: - Native SideSign & IDevice Helper

#if canImport(SideSign)
final class RealSideSignDriverHelper: @unchecked Sendable {
    static let shared = RealSideSignDriverHelper()
    private let lock = NSLock()

    private init() {}

    func candidateAnisetteServers(primaryURL: URL) -> [URL] {
        var servers = [primaryURL]
        for preset in AnisetteServerPreset.defaults {
            if let url = URL(string: preset.url), !servers.contains(url) {
                servers.append(url)
            }
        }
        return servers
    }

    func fetchFreshAnisetteData(primaryURL: URL, reuseSavedADIBlob: Bool = true) async throws -> AnisetteData {
        let servers = candidateAnisetteServers(primaryURL: primaryURL)
        let deviceUUID = SelfRefreshKeychain.loadOrCreateAnisetteDeviceUUID()
        let savedADIBlob = reuseSavedADIBlob ? SelfRefreshKeychain.loadAnisetteADIBlob() : nil
        var requestHeaders = AnisetteRequestHeaders()
        requestHeaders.clientInfo = GrandSlamClientIdentity.windowsClientInfo
        requestHeaders.userAgent = GrandSlamClientIdentity.akdUserAgent

        let (anisetteData, newAdiBlob) = try await AnisetteDataManager.shared.fetchAnisetteDataWithFailover(
            servers: servers,
            identifier: deviceUUID,
            existingAdiBlob: savedADIBlob,
            headers: requestHeaders
        )

        if let newAdiBlob {
            try? SelfRefreshKeychain.saveAnisetteADIBlob(newAdiBlob)
        }
        return presentingAcceptedIdentity(anisetteData)
    }

    /// GrandSlam reads `customHeaders.grandSlam.userAgent`, not the anisette user agent field.
    func applyAcceptedGrandSlamIdentity() {
        var headers = DeveloperPortal.shared.customHeaders
        headers.grandSlam.userAgent = GrandSlamClientIdentity.akdUserAgent
        headers.appleAuth.userAgent = GrandSlamClientIdentity.akdUserAgent
        DeveloperPortal.shared.customHeaders = headers
    }

    func presentingAcceptedIdentity(_ data: AnisetteData) -> AnisetteData {
        var copy = data
        copy.clientInfo = GrandSlamClientIdentity.acceptedClientInfo(from: copy.clientInfo)
        copy.userAgent = GrandSlamClientIdentity.acceptedUserAgent(from: copy.userAgent)
        return copy
    }

    func signInToDeveloperPortal(
        appleID: String,
        password: String,
        twoFactorCode: String?,
        primaryAnisetteURL: URL
    ) async throws -> (session: AuthSession, anisetteData: AnisetteData) {
        applyAcceptedGrandSlamIdentity()
        let hadSavedADIBlob = SelfRefreshKeychain.loadAnisetteADIBlob() != nil
        do {
            let anisetteData = try await fetchFreshAnisetteData(primaryURL: primaryAnisetteURL)
            let authSession = try await TwoFactorAuthBridge.shared.authenticate(
                appleID: appleID,
                password: password,
                twoFactorCode: twoFactorCode,
                anisetteData: anisetteData
            )
            return (authSession, anisetteData)
        } catch {
            guard hadSavedADIBlob, isRejectedGrandSlamIdentity(error) else { throw error }
            try? SelfRefreshKeychain.deleteAnisetteADIBlob()
            AnisetteDataManager.shared.clearCache()
            let anisetteData = try await fetchFreshAnisetteData(
                primaryURL: primaryAnisetteURL,
                reuseSavedADIBlob: false
            )
            let authSession = try await TwoFactorAuthBridge.shared.authenticate(
                appleID: appleID,
                password: password,
                twoFactorCode: twoFactorCode,
                anisetteData: anisetteData
            )
            return (authSession, anisetteData)
        }
    }

    private func isRejectedGrandSlamIdentity(_ error: Error) -> Bool {
        guard let serverError = error as? ServerError,
              case .underlyingError(let code, _) = serverError else {
            return false
        }
        return GrandSlamClientIdentity.isRejectedIdentityCode(code)
    }

    func authenticateAppleID(
        appleID: String,
        password: String,
        twoFactorCode: String?,
        primaryAnisetteURL: URL
    ) async throws -> AppleAuthSession {
        let (authSession, anisetteData) = try await signInToDeveloperPortal(
            appleID: appleID,
            password: password,
            twoFactorCode: twoFactorCode,
            primaryAnisetteURL: primaryAnisetteURL
        )

        let teams = try await DeveloperPortal.shared.fetchTeams(for: authSession.account, session: authSession.session)
        let chosenTeam = teams.first(where: { $0.type == .individual || $0.type == .organization }) ?? teams.first ?? Team(
            identifier: "PERSONAL",
            name: "\(appleID) (Personal)",
            type: .free
        )

        if let sessionData = try? JSONEncoder().encode(authSession) {
            try? SelfRefreshKeychain.savePortalSessionData(sessionData)
        }

        return AppleAuthSession(
            appleID: appleID,
            teamID: chosenTeam.identifier,
            teamName: chosenTeam.name,
            sessionToken: authSession.session.authToken,
            anisetteSerial: anisetteData.serialNumber,
            authenticatedAt: Date(),
            requiresTwoFactor: false
        )
    }

    func resolveActivePortalSession(
        appleID: String,
        password: String,
        primaryAnisetteURL: URL
    ) async throws -> (team: Team, session: Session) {
        applyAcceptedGrandSlamIdentity()
        let anisetteData = try await fetchFreshAnisetteData(primaryURL: primaryAnisetteURL)

        if let savedData = try? SelfRefreshKeychain.loadPortalSessionData(),
           let authSession = try? JSONDecoder().decode(AuthSession.self, from: savedData),
           authSession.session.isValid {
            var session = authSession.session
            session.anisetteData = anisetteData
            let updatedAuthSession = AuthSession(account: authSession.account, session: session)
            if let teams = try? await DeveloperPortal.shared.fetchTeams(for: updatedAuthSession.account, session: session),
               let team = teams.first(where: { $0.type == .individual || $0.type == .organization }) ?? teams.first {
                return (team, session)
            }
        }

        let (newAuth, _) = try await signInToDeveloperPortal(
            appleID: appleID,
            password: password,
            twoFactorCode: nil,
            primaryAnisetteURL: primaryAnisetteURL
        )
        if let sessionData = try? JSONEncoder().encode(newAuth) {
            try? SelfRefreshKeychain.savePortalSessionData(sessionData)
        }
        let teams = try await DeveloperPortal.shared.fetchTeams(for: newAuth.account, session: newAuth.session)
        let chosenTeam = teams.first(where: { $0.type == .individual || $0.type == .organization }) ?? teams.first ?? Team(
            identifier: "PERSONAL",
            name: "\(appleID) (Personal)",
            type: .free
        )
        return (chosenTeam, newAuth.session)
    }

    func ensureDeviceRegistered(
        udid: String,
        team: Team,
        session: Session
    ) async throws {
        guard udid != "Unknown-UDID", !udid.isEmpty else { return }
        let devices = try await DeveloperPortal.shared.fetchDevices(for: team, types: .all, session: session)
        if !devices.contains(where: { $0.identifier.caseInsensitiveCompare(udid) == .orderedSame }) {
            do {
                _ = try await DeveloperPortal.shared.registerDevice(
                    name: "iPhone",
                    identifier: udid,
                    type: .iPhone,
                    team: team,
                    session: session
                )
            } catch {
                // If device is already registered on portal, ignore
            }
        }
    }

    func ensureKeyStore(
        team: Team,
        session: Session
    ) async throws -> KeyStore {
        if let savedP12 = try? SelfRefreshKeychain.loadCertificateP12(for: team.identifier),
           let keyStore = try? KeyStore(p12Data: savedP12) {
            if let certs = try? await DeveloperPortal.shared.fetchCertificates(for: team, session: session),
               certs.contains(where: { $0.serialNumber.caseInsensitiveCompare(keyStore.certificate.serialNumber) == .orderedSame }) {
                return keyStore
            }
        }

        do {
            let keyStore = try await DeveloperPortal.shared.addCertificate(machineName: "SelfRefreshKit", type: .development, to: team, session: session)
            if let p12 = try? keyStore.exportP12() {
                try? SelfRefreshKeychain.saveCertificateP12(p12, for: team.identifier)
            }
            return keyStore
        } catch let err as DeveloperPortalError {
            if case .tooManyCertificates = err {
                let certs = try await DeveloperPortal.shared.fetchCertificates(for: team, session: session)
                if let oldest = certs.last {
                    _ = try? await DeveloperPortal.shared.revokeCertificate(oldest, for: team, session: session)
                    let keyStore = try await DeveloperPortal.shared.addCertificate(machineName: "SelfRefreshKit", type: .development, to: team, session: session)
                    if let p12 = try? keyStore.exportP12() {
                        try? SelfRefreshKeychain.saveCertificateP12(p12, for: team.identifier)
                    }
                    return keyStore
                }
            }
            throw err
        }
    }

    func ensureAppIDAndDownloadProfile(
        bundleIdentifier: String,
        team: Team,
        session: Session
    ) async throws -> ProvisioningProfile {
        let appIDs = try await DeveloperPortal.shared.fetchAppIDs(for: team, session: session)
        let scopedBundleID = "\(bundleIdentifier).\(team.identifier)"

        let matchedAppID: AppID
        if let existing = appIDs.first(where: { $0.bundleIdentifier == bundleIdentifier || $0.bundleIdentifier == scopedBundleID }) {
            matchedAppID = existing
        } else {
            do {
                matchedAppID = try await DeveloperPortal.shared.addAppID(withName: "SelfRefreshApp", bundleIdentifier: bundleIdentifier, team: team, session: session)
            } catch {
                matchedAppID = try await DeveloperPortal.shared.addAppID(withName: "SelfRefreshApp", bundleIdentifier: scopedBundleID, team: team, session: session)
            }
        }

        return try await DeveloperPortal.shared.downloadProvisioningProfile(
            for: matchedAppID,
            isTeamProfile: true,
            team: team,
            session: session
        )
    }

    #if canImport(IDevice)
    func refreshProvisioningProfileOnly(
        appleID: String,
        password: String,
        session: AppleAuthSession?,
        primaryAnisetteURL: URL,
        pairingData: Data,
        pairingInfo: PairingFileInspection,
        bundleIdentifier: String
    ) async throws -> ProvisioningProfileMetadata {
        let (team, portalSession) = try await resolveActivePortalSession(
            appleID: appleID,
            password: password,
            primaryAnisetteURL: primaryAnisetteURL
        )

        try await ensureDeviceRegistered(udid: pairingInfo.udid, team: team, session: portalSession)
        _ = try await ensureKeyStore(team: team, session: portalSession)

        let profile = try await ensureAppIDAndDownloadProfile(
            bundleIdentifier: bundleIdentifier,
            team: team,
            session: portalSession
        )

        try await IdeviceTunnelBridge.shared.installProvisioningProfile(
            profileData: profile.data,
            pairingData: pairingData,
            hasRPPairing: pairingInfo.hasRPPairingKeys
        )

        return ProvisioningProfileMetadata(
            uuid: profile.uuid.uuidString,
            name: profile.name,
            appIDName: profile.bundleIdentifier,
            bundleIdentifier: profile.bundleIdentifier,
            teamIdentifier: profile.teamIdentifier,
            teamName: profile.teamName,
            creationDate: profile.creationDate,
            expirationDate: profile.expirationDate,
            certificateSHA1Fingerprints: []
        )
    }

    func resignAndInstallIPA(
        ipaFileURL: URL,
        appleID: String,
        password: String,
        session: AppleAuthSession?,
        primaryAnisetteURL: URL,
        pairingData: Data,
        pairingInfo: PairingFileInspection,
        bundleIdentifier: String
    ) async throws -> ProvisioningProfileMetadata {
        let (team, portalSession) = try await resolveActivePortalSession(
            appleID: appleID,
            password: password,
            primaryAnisetteURL: primaryAnisetteURL
        )

        try await ensureDeviceRegistered(udid: pairingInfo.udid, team: team, session: portalSession)
        let keyStore = try await ensureKeyStore(team: team, session: portalSession)

        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("SelfRefreshWork-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        let appBundleURL = try FileManager.default.unzipAppBundle(at: ipaFileURL, to: workDir)
        guard let appBundle = AppBundle(fileURL: appBundleURL) else {
            throw SelfRefreshError.invalidProvisioningProfile
        }

        var profilesToSign: [ProvisioningProfile] = []
        let mainProfile = try await ensureAppIDAndDownloadProfile(
            bundleIdentifier: bundleIdentifier,
            team: team,
            session: portalSession
        )
        profilesToSign.append(mainProfile)

        for ext in appBundle.appExtensions {
            if let extProfile = try? await ensureAppIDAndDownloadProfile(
                bundleIdentifier: ext.bundleIdentifier,
                team: team,
                session: portalSession
            ) {
                profilesToSign.append(extProfile)
            }
        }

        let signer = AppBundleSigner(team: team, keyStore: keyStore)
        try await signer.signApp(at: appBundleURL, provisioningProfiles: profilesToSign)

        let signedIPA = try FileManager.default.zipAppBundle(at: appBundleURL)
        try await IdeviceTunnelBridge.shared.installSignedIPA(
            ipaFileURL: signedIPA,
            pairingData: pairingData,
            hasRPPairing: pairingInfo.hasRPPairingKeys
        )

        return ProvisioningProfileMetadata(
            uuid: mainProfile.uuid.uuidString,
            name: mainProfile.name,
            appIDName: mainProfile.bundleIdentifier,
            bundleIdentifier: mainProfile.bundleIdentifier,
            teamIdentifier: mainProfile.teamIdentifier,
            teamName: mainProfile.teamName,
            creationDate: mainProfile.creationDate,
            expirationDate: mainProfile.expirationDate,
            certificateSHA1Fingerprints: []
        )
    }
    #endif
}

// MARK: - 2FA Authentication Coordinator

actor TwoFactorAuthBridge {
    static let shared = TwoFactorAuthBridge()

    private var waiter: CheckedContinuation<TwoFactorResponse, Error>?
    private var prefilledCode: String?
    private var prefilledUsed = false

    private init() {}

    func authenticate(
        appleID: String,
        password: String,
        twoFactorCode: String?,
        anisetteData: AnisetteData
    ) async throws -> AuthSession {
        prefilledCode = twoFactorCode?.filter(\.isNumber)
        prefilledUsed = false
        let interactive = SelfRefreshAuthContext.interactiveTwoFactor
        return try await DeveloperPortal.shared.authenticate(
            appleID: appleID,
            password: password,
            anisetteData: anisetteData,
            xcodeVersion: "16.2",
            verificationHandler: { [weak self] request in
                guard let self else { return .cancel }
                return try await self.handleTwoFactorRequest(request: request, interactive: interactive)
            }
        )
    }

    func submitVerificationCode(_ code: String) {
        guard let waiter else { return }
        self.waiter = nil
        waiter.resume(returning: .verificationCode(code))
    }

    func cancelWaiting() {
        guard let waiter else { return }
        self.waiter = nil
        waiter.resume(returning: .cancel)
    }

    private func handleTwoFactorRequest(
        request: TwoFactorRequest,
        interactive: Bool
    ) async throws -> TwoFactorResponse {
        switch request {
        case .selectDeliveryMethod(let preferredMode, let phoneNumbers):
            if preferredMode == .trustedDevice || phoneNumbers.isEmpty {
                return .requestTrustedDevice
            }
            return .requestSMS(phoneID: phoneNumbers.first?.id ?? "1")

        case .trustedDevice(let error), .sms(_, _, let error), .voice(_, _, let error):
            if error != nil {
                prefilledUsed = true
                if !interactive {
                    throw SelfRefreshError.invalidTwoFactorCode
                }
                return try await waitForUserCode()
            }
            if let code = takePrefilledCode() {
                return .verificationCode(code)
            }
            if !interactive {
                throw SelfRefreshError.twoFactorCodeRequired
            }
            return try await waitForUserCode()
        }
    }

    private func takePrefilledCode() -> String? {
        guard !prefilledUsed, let code = prefilledCode, code.count == 6 else { return nil }
        prefilledUsed = true
        return code
    }

    private func waitForUserCode() async throws -> TwoFactorResponse {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TwoFactorResponse, Error>) in
                if let existing = self.waiter {
                    existing.resume(returning: .cancel)
                }
                self.waiter = continuation
                Task { @MainActor in
                    SelfRefreshManager.shared.beginTwoFactorChallenge()
                }
            }
        } onCancel: {
            Task { await self.cancelWaiting() }
        }
    }
}
#endif

// MARK: - IDevice C-FFI Tunnel Bridge

#if canImport(IDevice)
final class IdeviceTunnelBridge: @unchecked Sendable {
    static let shared = IdeviceTunnelBridge()
    private let ffiQueue = DispatchQueue(label: "io.github.selfrefreshkit.idevice.ffi", qos: .userInitiated)

    private init() {}

    private func withSockaddr<R>(ip: String, port: UInt16, _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> R) throws -> R {
        var addr = sockaddr_in()
        #if canImport(Darwin)
        addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        #endif
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else {
            throw SelfRefreshError.backendOperationFailed("Invalid IPv4 address: \(ip)")
        }
        return try withUnsafePointer(to: &addr) { ptr in
            try ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                try body(sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }

    /// `idevice_sockaddr` is an opaque FFI type, distinct from `sockaddr`.
    private func withDeviceAddress<R>(
        ip: String,
        port: UInt16,
        _ body: (UnsafePointer<idevice_sockaddr>, idevice_socklen_t) throws -> R
    ) throws -> R {
        try withSockaddr(ip: ip, port: port) { sockaddrPtr, len in
            try sockaddrPtr.withMemoryRebound(to: idevice_sockaddr.self, capacity: 1) { rebound in
                try body(rebound, idevice_socklen_t(len))
            }
        }
    }

    func installProvisioningProfile(
        profileData: Data,
        pairingData: Data,
        hasRPPairing: Bool
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ffiQueue.async {
                do {
                    if hasRPPairing {
                        try self.installProfileRPPairing(profileData: profileData, pairingData: pairingData)
                    } else {
                        try self.installProfileLockdown(profileData: profileData, pairingData: pairingData)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func installProfileRPPairing(profileData: Data, pairingData: Data) throws {
        var pairingFile: OpaquePointer? = nil
        let parseErr = pairingData.withUnsafeBytes { buf in
            rp_pairing_file_from_bytes(buf.baseAddress?.assumingMemoryBound(to: UInt8.self), UInt(pairingData.count), &pairingFile)
        }
        guard parseErr == nil, let rpf = pairingFile else {
            throw SelfRefreshError.invalidPairingFile("Failed to parse RPPairing bytes")
        }
        defer { rp_pairing_file_free(rpf) }

        var adapter: OpaquePointer? = nil
        var handshake: OpaquePointer? = nil
        let tunnelErr = try withDeviceAddress(ip: "10.7.0.1", port: 49152) { address, len in
            tunnel_create_rppairing_with_options(
                address,
                len,
                "SelfRefreshKit",
                rpf,
                false,
                nil,
                nil,
                &adapter,
                &handshake
            )
        }
        if let tunnelErr {
            idevice_error_free(tunnelErr)
            throw SelfRefreshError.tunnelDisconnected(.localDevVPN)
        }
        defer {
            if let handshake { rsd_handshake_free(handshake) }
            if let adapter { adapter_free(adapter) }
        }

        var client: OpaquePointer? = nil
        let connectErr = misagent_connect_rsd(adapter, handshake, &client)
        if let connectErr {
            idevice_error_free(connectErr)
            throw SelfRefreshError.backendOperationFailed("Failed to connect to misagent service")
        }
        guard let misClient = client else {
            throw SelfRefreshError.backendOperationFailed("misagent client is nil")
        }
        defer { misagent_client_free(misClient) }

        try profileData.withUnsafeBytes { buf in
            guard let ptr = buf.baseAddress?.assumingMemoryBound(to: UInt8.self), !profileData.isEmpty else {
                throw SelfRefreshError.backendOperationFailed("描述文件数据为空。")
            }
            let installErr = misagent_install(misClient, ptr, profileData.count)
            if let installErr {
                idevice_error_free(installErr)
                throw SelfRefreshError.backendOperationFailed("misagent_install returned an error")
            }
        }
    }

    private func installProfileLockdown(profileData: Data, pairingData: Data) throws {
        var pairingFile: OpaquePointer? = nil
        let parseErr = pairingData.withUnsafeBytes { buf in
            idevice_pairing_file_from_bytes(buf.baseAddress?.assumingMemoryBound(to: UInt8.self), UInt(pairingData.count), &pairingFile)
        }
        guard parseErr == nil, let pf = pairingFile else {
            throw SelfRefreshError.invalidPairingFile("Failed to parse Lockdown pairing bytes")
        }
        var pairingConsumed = false
        defer {
            if !pairingConsumed {
                idevice_pairing_file_free(pf)
            }
        }

        var provider: OpaquePointer? = nil
        let provErr = try withDeviceAddress(ip: "10.7.0.1", port: 62078) { address, _ in
            idevice_tcp_provider_new(address, pf, "SelfRefreshKit", &provider)
        }
        if provErr == nil {
            pairingConsumed = true
        }
        if let provErr {
            idevice_error_free(provErr)
            throw SelfRefreshError.tunnelDisconnected(.localDevVPN)
        }
        guard let tcpProvider = provider else {
            throw SelfRefreshError.tunnelDisconnected(.localDevVPN)
        }
        defer { idevice_provider_free(tcpProvider) }

        var client: OpaquePointer? = nil
        let connectErr = misagent_connect(tcpProvider, &client)
        if let connectErr {
            idevice_error_free(connectErr)
            throw SelfRefreshError.backendOperationFailed("Failed to connect to misagent lockdown service")
        }
        guard let misClient = client else {
            throw SelfRefreshError.backendOperationFailed("misagent client is nil")
        }
        defer { misagent_client_free(misClient) }

        try profileData.withUnsafeBytes { buf in
            guard let ptr = buf.baseAddress?.assumingMemoryBound(to: UInt8.self), !profileData.isEmpty else {
                throw SelfRefreshError.backendOperationFailed("描述文件数据为空。")
            }
            let installErr = misagent_install(misClient, ptr, profileData.count)
            if let installErr {
                idevice_error_free(installErr)
                throw SelfRefreshError.backendOperationFailed("misagent_install returned an error")
            }
        }
    }

    func installSignedIPA(
        ipaFileURL: URL,
        pairingData: Data,
        hasRPPairing: Bool
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ffiQueue.async {
                do {
                    if hasRPPairing {
                        try self.installIPARPPairing(ipaFileURL: ipaFileURL, pairingData: pairingData)
                    } else {
                        try self.installIPALockdown(ipaFileURL: ipaFileURL, pairingData: pairingData)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Writes one signed `.ipa` to `PublicStaging/` so `installation_proxy` can install it.
    private func uploadIPAViaAFC(client: OpaquePointer, ipaFileURL: URL) throws -> String {
        if let mkdirErr = "PublicStaging".withCString({ afc_make_directory(client, $0) }) {
            idevice_error_free(mkdirErr)
        }
        let remotePath = "PublicStaging/\(ipaFileURL.lastPathComponent)"
        var fileHandle: OpaquePointer? = nil
        let openErr = remotePath.withCString { pathPtr in
            // AfcWr = 4: O_RDWR | O_CREAT | O_TRUNC
            afc_file_open(client, pathPtr, AfcFopenMode(rawValue: 4), &fileHandle)
        }
        if let openErr {
            idevice_error_free(openErr)
            throw SelfRefreshError.backendOperationFailed("afc_file_open failed: \(remotePath)")
        }
        guard let handle = fileHandle else {
            throw SelfRefreshError.backendOperationFailed("AFC file handle is nil")
        }
        defer {
            if let closeErr = afc_file_close(handle) {
                idevice_error_free(closeErr)
            }
        }

        let fileData = try Data(contentsOf: ipaFileURL, options: .alwaysMapped)
        guard !fileData.isEmpty else {
            throw SelfRefreshError.backendOperationFailed("Signed IPA is empty")
        }
        try fileData.withUnsafeBytes { buf in
            guard let ptr = buf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw SelfRefreshError.backendOperationFailed("Signed IPA is empty")
            }
            let writeErr = afc_file_write(handle, ptr, fileData.count)
            if let writeErr {
                idevice_error_free(writeErr)
                throw SelfRefreshError.backendOperationFailed("afc_file_write failed: \(remotePath)")
            }
        }
        return remotePath
    }

    private func installDeveloperPackage(client: OpaquePointer, remotePath: String) throws {
        let options = plist_new_dict()
        defer { plist_free(options) }
        plist_dict_set_item(options, "PackageType", plist_new_string("Developer"))
        let installErr = remotePath.withCString { pathPtr in
            installation_proxy_install(client, pathPtr, options)
        }
        if let installErr {
            idevice_error_free(installErr)
            throw SelfRefreshError.backendOperationFailed("installation_proxy_install failed")
        }
    }

    private func installIPARPPairing(ipaFileURL: URL, pairingData: Data) throws {
        var pairingFile: OpaquePointer? = nil
        let parseErr = pairingData.withUnsafeBytes { buf in
            rp_pairing_file_from_bytes(buf.baseAddress?.assumingMemoryBound(to: UInt8.self), UInt(pairingData.count), &pairingFile)
        }
        guard parseErr == nil, let rpf = pairingFile else {
            throw SelfRefreshError.invalidPairingFile("Failed to parse RPPairing bytes")
        }
        defer { rp_pairing_file_free(rpf) }

        var adapter: OpaquePointer? = nil
        var handshake: OpaquePointer? = nil
        let tunnelErr = try withDeviceAddress(ip: "10.7.0.1", port: 49152) { address, len in
            tunnel_create_rppairing_with_options(
                address,
                len,
                "SelfRefreshKit",
                rpf,
                false,
                nil,
                nil,
                &adapter,
                &handshake
            )
        }
        if let tunnelErr {
            idevice_error_free(tunnelErr)
            throw SelfRefreshError.tunnelDisconnected(.localDevVPN)
        }
        defer {
            if let handshake { rsd_handshake_free(handshake) }
            if let adapter { adapter_free(adapter) }
        }

        var afcClient: OpaquePointer? = nil
        let afcErr = afc_client_connect_rsd(adapter, handshake, &afcClient)
        if let afcErr {
            idevice_error_free(afcErr)
            throw SelfRefreshError.backendOperationFailed("Failed to connect to AFC service")
        }
        guard let afc = afcClient else {
            throw SelfRefreshError.backendOperationFailed("AFC client is nil")
        }
        defer { afc_client_free(afc) }

        let remotePath = try uploadIPAViaAFC(client: afc, ipaFileURL: ipaFileURL)

        var instClient: OpaquePointer? = nil
        let instErr = installation_proxy_connect_rsd(adapter, handshake, &instClient)
        if let instErr {
            idevice_error_free(instErr)
            throw SelfRefreshError.backendOperationFailed("Failed to connect to installation_proxy service")
        }
        guard let inst = instClient else {
            throw SelfRefreshError.backendOperationFailed("installation_proxy client is nil")
        }
        defer { installation_proxy_client_free(inst) }

        try installDeveloperPackage(client: inst, remotePath: remotePath)
    }

    private func installIPALockdown(ipaFileURL: URL, pairingData: Data) throws {
        var pairingFile: OpaquePointer? = nil
        let parseErr = pairingData.withUnsafeBytes { buf in
            idevice_pairing_file_from_bytes(buf.baseAddress?.assumingMemoryBound(to: UInt8.self), UInt(pairingData.count), &pairingFile)
        }
        guard parseErr == nil, let pf = pairingFile else {
            throw SelfRefreshError.invalidPairingFile("Failed to parse Lockdown pairing bytes")
        }
        var pairingConsumed = false
        defer {
            if !pairingConsumed {
                idevice_pairing_file_free(pf)
            }
        }

        var provider: OpaquePointer? = nil
        let provErr = try withDeviceAddress(ip: "10.7.0.1", port: 62078) { address, _ in
            idevice_tcp_provider_new(address, pf, "SelfRefreshKit", &provider)
        }
        if provErr == nil {
            pairingConsumed = true
        }
        if let provErr {
            idevice_error_free(provErr)
            throw SelfRefreshError.tunnelDisconnected(.localDevVPN)
        }
        guard let tcpProvider = provider else {
            throw SelfRefreshError.tunnelDisconnected(.localDevVPN)
        }
        defer { idevice_provider_free(tcpProvider) }

        var afcClient: OpaquePointer? = nil
        let afcErr = afc_client_connect(tcpProvider, &afcClient)
        if let afcErr {
            idevice_error_free(afcErr)
            throw SelfRefreshError.backendOperationFailed("Failed to connect to AFC lockdown service")
        }
        guard let afc = afcClient else {
            throw SelfRefreshError.backendOperationFailed("AFC client is nil")
        }
        defer { afc_client_free(afc) }

        let remotePath = try uploadIPAViaAFC(client: afc, ipaFileURL: ipaFileURL)

        var instClient: OpaquePointer? = nil
        let instErr = installation_proxy_connect(tcpProvider, &instClient)
        if let instErr {
            idevice_error_free(instErr)
            throw SelfRefreshError.backendOperationFailed("Failed to connect to installation_proxy lockdown service")
        }
        guard let inst = instClient else {
            throw SelfRefreshError.backendOperationFailed("installation_proxy client is nil")
        }
        defer { installation_proxy_client_free(inst) }

        try installDeveloperPackage(client: inst, remotePath: remotePath)
    }
}
#endif
