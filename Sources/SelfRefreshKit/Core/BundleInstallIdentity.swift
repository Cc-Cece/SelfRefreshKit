import Foundation

/// Aligns an unpacked `.app` / `.appex` with the provisioning profile that will sign it.
///
/// `installd` accepts a developer install only when `CFBundleIdentifier` equals the
/// bundle id inside the profile's `application-identifier`. SideSign signs with the
/// profile it is given and does not rewrite `Info.plist`.
enum BundleInstallIdentity {
    static func mappedIdentifier(_ original: String, oldMain: String, newMain: String) -> String {
        let original = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldMain = oldMain.trimmingCharacters(in: .whitespacesAndNewlines)
        let newMain = newMain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty, !newMain.isEmpty else { return original }
        if original == oldMain || oldMain.isEmpty {
            return original == oldMain ? newMain : original
        }
        let prefix = oldMain + "."
        if original.hasPrefix(prefix) {
            return newMain + String(original.dropFirst(oldMain.count))
        }
        let leaf = original.split(separator: ".").last.map(String.init) ?? "extension"
        guard !leaf.isEmpty else { return "\(newMain).extension" }
        return "\(newMain).\(leaf)"
    }

    /// Rewrites `CFBundleIdentifier` to `targetID` and replaces exact copies of the old ids.
    static func align(
        bundleURL: URL,
        from currentID: String,
        to targetID: String,
        oldMain: String,
        newMain: String
    ) throws {
        let currentID = currentID.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetID = targetID.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldMain = oldMain.trimmingCharacters(in: .whitespacesAndNewlines)
        let newMain = newMain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetID.isEmpty, !targetID.contains("*") else {
            throw SelfRefreshError.backendOperationFailed("描述文件没有可用的明确 Bundle ID，安装已中止。")
        }
        if currentID == targetID, (oldMain == newMain || oldMain.isEmpty) {
            return
        }

        let infoURL = bundleURL.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: infoURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw SelfRefreshError.backendOperationFailed("无法读取 \(bundleURL.lastPathComponent) 的 Info.plist。")
        }

        var replacements: [String: String] = [:]
        if !currentID.isEmpty, currentID != targetID {
            replacements[currentID] = targetID
        }
        if !oldMain.isEmpty, oldMain != newMain {
            replacements[oldMain] = newMain
        }
        if !replacements.isEmpty {
            plist = rewrite(plist, replacements: replacements) as? [String: Any] ?? plist
        }
        plist["CFBundleIdentifier"] = targetID

        let out = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try out.write(to: infoURL, options: .atomic)
    }

    static func bundleIdentifier(at bundleURL: URL) throws -> String {
        let infoURL = bundleURL.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: infoURL)
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let identifier = plist["CFBundleIdentifier"] as? String else {
            throw SelfRefreshError.backendOperationFailed("无法读取 \(bundleURL.lastPathComponent) 的 Bundle ID。")
        }
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SelfRefreshError.backendOperationFailed("\(bundleURL.lastPathComponent) 的 Bundle ID 为空。")
        }
        return trimmed
    }

    /// An empty device list means the profile is not limited to registered devices.
    static func profileCoversDevice(deviceIDs: [String], udid: String) -> Bool {
        if deviceIDs.isEmpty { return true }
        let needle = normalizeUDID(udid)
        guard !needle.isEmpty else { return false }
        return deviceIDs.contains { normalizeUDID($0) == needle }
    }

    private static func normalizeUDID(_ raw: String) -> String {
        raw.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private static func rewrite(_ value: Any, replacements: [String: String]) -> Any {
        if let string = value as? String, let mapped = replacements[string] {
            return mapped
        }
        if let array = value as? [Any] {
            return array.map { rewrite($0, replacements: replacements) }
        }
        if let dictionary = value as? [String: Any] {
            var rewritten: [String: Any] = [:]
            for (key, nested) in dictionary {
                rewritten[key] = rewrite(nested, replacements: replacements)
            }
            return rewritten
        }
        return value
    }
}
