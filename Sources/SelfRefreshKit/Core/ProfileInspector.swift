import Foundation
import CryptoKit

/// Offline parser for iOS `embedded.mobileprovision` (CMS-signed Property List).
public enum ProfileInspector {
    /// Inspects the host app's `Bundle.main` (or a specified bundle URL) for `embedded.mobileprovision`.
    public static func inspectEmbeddedProfile(in bundleURL: URL = Bundle.main.bundleURL) -> ProvisioningProfileMetadata? {
        let profileURL = bundleURL.appendingPathComponent("embedded.mobileprovision")
        guard let data = try? Data(contentsOf: profileURL) else {
            return nil
        }
        return try? parseMobileProvisionData(data)
    }

    /// Extracts the XML plist payload from raw `.mobileprovision` CMS data and parses metadata.
    public static func parseMobileProvisionData(_ data: Data) throws -> ProvisioningProfileMetadata {
        guard let xmlData = extractPlistXMLData(from: data) else {
            throw SelfRefreshError.invalidProvisioningProfile
        }
        guard let plist = try PropertyListSerialization.propertyList(from: xmlData, options: [], format: nil) as? [String: Any] else {
            throw SelfRefreshError.invalidProvisioningProfile
        }

        let uuid = plist["UUID"] as? String ?? ""
        let name = plist["Name"] as? String ?? ""
        let appIDName = plist["AppIDName"] as? String ?? name
        let teamName = plist["TeamName"] as? String ?? ""
        let teamIdentifiers = plist["TeamIdentifier"] as? [String] ?? []
        let teamIdentifier = teamIdentifiers.first ?? ""
        let creationDate = plist["CreationDate"] as? Date ?? Date.distantPast
        let expirationDate = plist["ExpirationDate"] as? Date ?? Date.distantPast

        var bundleIdentifier = ""
        if let entitlements = plist["Entitlements"] as? [String: Any],
           let appIdentifier = entitlements["application-identifier"] as? String {
            let prefix = teamIdentifier.isEmpty ? "" : "\(teamIdentifier)."
            if !prefix.isEmpty && appIdentifier.hasPrefix(prefix) {
                bundleIdentifier = String(appIdentifier.dropFirst(prefix.count))
            } else {
                bundleIdentifier = appIdentifier
            }
        }

        var fingerprints: [String] = []
        if let certDataList = plist["DeveloperCertificates"] as? [Data] {
            for cert in certDataList {
                let digest = Insecure.SHA1.hash(data: cert)
                let hex = digest.map { String(format: "%02X", $0) }.joined()
                fingerprints.append(hex)
            }
        }

        guard !uuid.isEmpty, expirationDate != Date.distantPast else {
            throw SelfRefreshError.invalidProvisioningProfile
        }

        return ProvisioningProfileMetadata(
            uuid: uuid,
            name: name,
            appIDName: appIDName,
            bundleIdentifier: bundleIdentifier,
            teamIdentifier: teamIdentifier,
            teamName: teamName,
            creationDate: creationDate,
            expirationDate: expirationDate,
            certificateSHA1Fingerprints: fingerprints
        )
    }

    /// Scans raw CMS bytes for `<?xml` ... `</plist>`.
    public static func extractPlistXMLData(from cmsData: Data) -> Data? {
        let startMarker = Data("<?xml".utf8)
        let endMarker = Data("</plist>".utf8)
        guard let startRange = cmsData.range(of: startMarker),
              let endRange = cmsData.range(of: endMarker, in: startRange.lowerBound..<cmsData.endIndex) else {
            return nil
        }
        return cmsData.subdata(in: startRange.lowerBound..<endRange.upperBound)
    }
}
