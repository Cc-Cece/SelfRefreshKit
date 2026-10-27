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
            <string>12345678-ABCD-EF00-1122-334455667788</string>
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
        XCTAssertEqual(parsed.uuid, "12345678-ABCD-EF00-1122-334455667788")
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
    func testRequiredStepsAndWizardStateAndFullAuthentication() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suiteName = "test.selfrefresh.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let manager = SelfRefreshManager(defaults: defaults, storageDirectory: tempDir)

        XCTAssertEqual(manager.completedRequiredStepsCount, 0)
        XCTAssertTrue(manager.shouldAutoPresentSetupWizard)

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
        XCTAssertEqual(session.appleID, "test_user@icloud.com")
        XCTAssertFalse(session.teamID.isEmpty)
        XCTAssertTrue(manager.isStep2AccountCompleted)

        let report = await manager.runHealthCheck()
        XCTAssertEqual(report.items.count, 4)
        XCTAssertEqual(report.items.first(where: { $0.id == "pairing" })?.status, .healthy)
    }

    @MainActor
    func testDefaultVPNIsLocalDevVPNAndCompatibleWithOthers() {
        let config = SelfRefreshConfiguration(urlScheme: "picharbor")
        XCTAssertEqual(config.preferredVPN, .localDevVPN)
        XCTAssertEqual(config.refreshWakeupURLString, "picharbor://refresh")
        XCTAssertGreaterThanOrEqual(AnisetteServerPreset.defaults.count, 4)
    }
}
