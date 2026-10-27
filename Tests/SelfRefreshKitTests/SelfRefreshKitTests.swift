import XCTest
@testable import SelfRefreshKit

final class SelfRefreshKitTests: XCTestCase {
    func testExtractAndParseCMSWrappedMobileProvision() throws {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let exp = now.addingTimeInterval(6 * 86400 + 5 * 3600)
        let formatter = ISO8601DateFormatter()
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>UUID</key>
            <string>12345678-ABCD-EF00-1122-123456789ABC</string>
            <key>Name</key>
            <string>iOS Team Provisioning Profile: com.cccece.picharbor</string>
            <key>AppIDName</key>
            <string>PicHarbor</string>
            <key>TeamName</key>
            <string>Kanbara Personal</string>
            <key>TeamIdentifier</key>
            <array><string>8X92TEAMID</string></array>
            <key>CreationDate</key>
            <date>\(formatter.string(from: now))</date>
            <key>ExpirationDate</key>
            <date>\(formatter.string(from: exp))</date>
            <key>Entitlements</key>
            <dict>
                <key>application-identifier</key>
                <string>8X92TEAMID.com.cccece.picharbor</string>
            </dict>
        </dict>
        </plist>
        """
        var cmsWrapped = Data([0x30, 0x82, 0x05, 0x00, 0x06, 0x09])
        cmsWrapped.append(Data(xml.utf8))
        cmsWrapped.append(Data([0x00, 0x00, 0xFF]))

        let parsed = try ProfileInspector.parseMobileProvisionData(cmsWrapped)
        XCTAssertEqual(parsed.uuid, "12345678-ABCD-EF00-1122-123456789ABC")
        XCTAssertEqual(parsed.bundleIdentifier, "com.cccece.picharbor")
        XCTAssertEqual(parsed.teamIdentifier, "8X92TEAMID")
        let remaining = parsed.remainingDaysAndHours(from: now)
        XCTAssertFalse(remaining.isExpired)
        XCTAssertEqual(remaining.days, 6)
        XCTAssertEqual(remaining.hours, 5)
        XCTAssertFalse(parsed.isExpiringSoon(from: now))
    }

    func testPairingFileInspectionSupportsBothXMLAndBinaryPlistWithRPPairing() throws {
        let driver = DefaultSelfRefreshDriver()
        let plistDict: [String: Any] = [
            "UDID": "00008140-00040D4C0A39801C",
            "WiFiMACAddress": "44:a7:f4:73:90:57",
            "HostID": "3128463110602747921341817620",
            "SystemBUID": "311841761246279613648121344",
            "DeviceCertificate": Data([0x01, 0x02]),
            "HostCertificate": Data([0x03, 0x04]),
            "HostPrivateKey": Data([0x05, 0x06]),
            "EscrowBag": Data([0x07]),
            "public_key": Data([0x08]),
            "private_key": Data([0x09])
        ]

        let xmlData = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
        let xmlInspection = try driver.inspectPairingFile(data: xmlData)
        XCTAssertEqual(xmlInspection.udid, "00008140-00040D4C0A39801C")
        XCTAssertEqual(xmlInspection.wifiMACAddress, "44:a7:f4:73:90:57")
        XCTAssertTrue(xmlInspection.hasEscrowBag)
        XCTAssertTrue(xmlInspection.hasRPPairingKeys)

        let binaryData = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .binary, options: 0)
        let binInspection = try driver.inspectPairingFile(data: binaryData)
        XCTAssertEqual(binInspection.udid, "00008140-00040D4C0A39801C")
        XCTAssertTrue(binInspection.hasRPPairingKeys)

        let invalidPairing = "<plist><dict><key>UDID</key><string>123</string></dict></plist>"
        XCTAssertThrowsError(try driver.validatePairingFile(xmlContent: invalidPairing))
    }

    @MainActor
    func testRequiredStepsAndFullAuthentication() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suiteName = "test.selfrefresh.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let expectedSession = AppleAuthSession(
            appleID: "test_user@icloud.com",
            teamID: "TEAMID1234",
            teamName: "Stub Team",
            sessionToken: "PORTAL-TOKEN-STUB",
            anisetteSerial: "ANISSETTE-STUB",
            authenticatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let manager = SelfRefreshManager(
            driver: StubRefreshDriver(session: expectedSession),
            defaults: defaults,
            storageDirectory: tempDir
        )

        XCTAssertEqual(manager.completedRequiredStepsCount, 0)

        let plistDict: [String: Any] = [
            "UDID": "00008140-00040D4C0A39801C",
            "WiFiMACAddress": "44:a7:f4:73:90:57",
            "DeviceCertificate": Data([0x01]),
            "HostCertificate": Data([0x02]),
            "HostPrivateKey": Data([0x03]),
            "public_key": Data([0x04]),
            "private_key": Data([0x05])
        ]
        let pairingData = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
        let info = try manager.importPairingData(pairingData)
        XCTAssertEqual(info.udid, "00008140-00040D4C0A39801C")
        XCTAssertTrue(manager.isStep1PairingCompleted)
        XCTAssertEqual(manager.activeNotice?.isError, false)

        let session = try await manager.authenticateAndSaveAccount(
            appleID: "test_user@icloud.com",
            password: "secret_password",
            twoFactorCode: "123456",
            anisetteURL: "https://ani.sidestore.io"
        )
        XCTAssertEqual(session, expectedSession)
        XCTAssertEqual(manager.authSession?.teamID, "TEAMID1234")
        XCTAssertEqual(manager.authSession?.sessionToken, "PORTAL-TOKEN-STUB")
        XCTAssertTrue(manager.isStep2AccountCompleted)
        XCTAssertFalse(manager.isAwaitingTwoFactor)

        let report = await manager.runHealthCheck()
        XCTAssertEqual(report.items.count, 4)
        XCTAssertEqual(report.items.first(where: { $0.id == "pairing" })?.status, .healthy)

        do {
            try await manager.refreshProfileOnly()
            XCTFail("Profile refresh must not succeed without a real provisioning profile")
        } catch {
            XCTAssertFalse(manager.isLocalCertificateTakenOver)
            XCTAssertNil(manager.lastRefreshDate)
        }
    }

    func testAllSevenLanguagesHave100PercentKeyParityIncludingAboutAndShortcuts() {
        let concreteLanguages: [SelfRefreshLanguage] = [
            .english,
            .simplifiedChinese,
            .cantonese,
            .japanese,
            .german,
            .french,
            .korean
        ]

        for lang in concreteLanguages {
            let table = SelfRefreshStrings.table(for: lang)
            for key in SelfRefreshL10nKey.allCases {
                let value = table[key.rawValue]
                XCTAssertNotNil(value, "Missing key '\(key.rawValue)' in language '\(lang.rawValue)'")
                XCTAssertFalse(value?.isEmpty ?? true, "Empty translation for '\(key.rawValue)' in '\(lang.rawValue)'")
            }
        }
    }

    @MainActor
    func testSevenLanguagesHostFallbackToEnglishAndManualOverride() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suiteName = "test.selfrefresh.lang.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let manager = SelfRefreshManager(defaults: defaults, storageDirectory: tempDir)

        var simulatedHostLang = "es-ES" // Unsupported language -> should fallback to English
        manager.configure(
            SelfRefreshConfiguration(
                urlScheme: "picharbor",
                hostLanguageProvider: { simulatedHostLang }
            )
        )

        XCTAssertEqual(manager.selectedLanguage, .followHost)
        XCTAssertEqual(manager.localized(.statusHeader), "Current Status")
        XCTAssertEqual(manager.localized(.statusRefreshNow), "Refresh Now")
        XCTAssertEqual(manager.localized(.aboutEngineMuxer), "Muxer Engine")

        simulatedHostLang = "zh-Hans"
        XCTAssertEqual(manager.localized(.statusHeader), "当前状态")
        XCTAssertEqual(manager.localized(.statusRefreshNow), "立即续签")
        XCTAssertEqual(manager.localized(.aboutEngineMuxer), "通信引擎")

        simulatedHostLang = "yue-HK"
        XCTAssertEqual(manager.localized(.statusHeader), "目前狀態")
        XCTAssertEqual(manager.localized(.aboutEngineMuxer), "通訊引擎")

        simulatedHostLang = "ja-JP"
        XCTAssertEqual(manager.localized(.statusHeader), "現在のステータス")
        XCTAssertEqual(manager.localized(.aboutEngineMuxer), "通信エンジン")

        simulatedHostLang = "de-DE"
        XCTAssertEqual(manager.localized(.statusHeader), "Aktueller Status")
        XCTAssertEqual(manager.localized(.aboutEngineMuxer), "Muxer-Engine")

        simulatedHostLang = "fr-FR"
        XCTAssertEqual(manager.localized(.statusHeader), "État actuel")
        XCTAssertEqual(manager.localized(.aboutEngineMuxer), "Moteur Muxer")

        simulatedHostLang = "ko-KR"
        XCTAssertEqual(manager.localized(.statusHeader), "현재 상태")
        XCTAssertEqual(manager.localized(.aboutEngineMuxer), "통신 엔진")

        // Manual override takes priority over host language
        manager.selectedLanguage = .japanese
        simulatedHostLang = "en-US"
        XCTAssertEqual(manager.localized(.statusHeader), "現在のステータス")
    }

    @MainActor
    func testConfigurableOTARepositoryAndDirectIPAURLValidation() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suiteName = "test.selfrefresh.ota.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let manager = SelfRefreshManager(defaults: defaults, storageDirectory: tempDir)

        manager.configure(
            SelfRefreshConfiguration(
                urlScheme: "picharbor",
                githubRepository: "Cc-Cece/PicHarbor-iOS"
            )
        )

        XCTAssertEqual(manager.effectiveGitHubRepository, "Cc-Cece/PicHarbor-iOS")

        manager.updateCustomGitHubRepository("CustomUser/CustomRepo")
        XCTAssertEqual(manager.effectiveGitHubRepository, "CustomUser/CustomRepo")

        manager.resetGitHubRepositoryToDefault()
        XCTAssertEqual(manager.effectiveGitHubRepository, "Cc-Cece/PicHarbor-iOS")

        do {
            try await manager.downloadAndInstallDirectIPA(urlString: "not-a-valid-url")
            XCTFail("Expected invalid URL to throw")
        } catch {
            XCTAssertEqual(manager.activeNotice?.isError, true)
        }
    }

    @MainActor
    func testOfficialURLsAndBackgroundShortcutIntent() {
        let config = SelfRefreshConfiguration(urlScheme: "picharbor")
        XCTAssertEqual(config.preferredVPN, .localDevVPN)
        XCTAssertEqual(SelfRefreshConfiguration.officialRepositoryURL.absoluteString, "https://github.com/Cc-Cece/SelfRefreshKit/")
        XCTAssertEqual(SelfRefreshConfiguration.shortcutsDocumentationURL.absoluteString, "https://github.com/Cc-Cece/SelfRefreshKit/?tab=readme-ov-file#Shortcuts")
        if #available(iOS 17.0, macOS 14.0, *) {
            XCTAssertFalse(SelfRefreshProfileIntent.openAppWhenRun)
        }
        XCTAssertGreaterThanOrEqual(AnisetteServerPreset.defaults.count, 4)
    }
}

/// Returns a fixed developer session. Profile install and resign fail instead of inventing a 7-day profile.
private struct StubRefreshDriver: SelfRefreshBackendDriver {
    let session: AppleAuthSession

    var driverName: String { "Stub Auth Driver" }

    func testLoopbackTunnel(host: String, port: UInt16) async -> Bool { true }

    func inspectPairingFile(data: Data) throws -> PairingFileInspection {
        try DefaultSelfRefreshDriver().inspectPairingFile(data: data)
    }

    func probeAnisetteServer(url: URL) async throws -> (headers: [String: String], latencyMs: Int) {
        (["X-Apple-I-MD": "stub"], 1)
    }

    func authenticateAppleID(
        appleID: String,
        password: String,
        twoFactorCode: String?,
        anisetteURL: URL
    ) async throws -> AppleAuthSession {
        session
    }

    func refreshProvisioningProfileOnly(
        appleID: String,
        password: String,
        session: AppleAuthSession?,
        anisetteURL: URL,
        pairingData: Data,
        bundleIdentifier: String
    ) async throws -> ProvisioningProfileMetadata {
        throw SelfRefreshError.backendOperationFailed("stub refresh is not a profile install")
    }

    func resignAndInstallIPA(
        ipaFileURL: URL,
        appleID: String,
        password: String,
        session: AppleAuthSession?,
        anisetteURL: URL,
        pairingData: Data,
        bundleIdentifier: String
    ) async throws -> ProvisioningProfileMetadata {
        throw SelfRefreshError.backendOperationFailed("stub resign is not an install")
    }
}
