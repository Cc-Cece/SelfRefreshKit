import Foundation
import Security

/// Error definitions for `SelfRefreshKit`.
public enum SelfRefreshError: LocalizedError, Equatable, Sendable {
    case invalidProvisioningProfile
    case missingPairingFile
    case invalidPairingFile(String)
    case tunnelDisconnected(LoopbackVPNApp)
    case missingAppleIDCredentials
    case twoFactorCodeRequired
    case invalidTwoFactorCode
    case appleAuthenticationFailed(String)
    case invalidAnisetteURL
    case anisetteServerUnreachable(String)
    case keychainFailure(OSStatus)
    case missingIPAFile
    case otaNoReleaseFound
    case backendOperationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidProvisioningProfile:
            return "无法解析描述文件（embedded.mobileprovision）。"
        case .missingPairingFile:
            return "未导入设备配对文件（.mobiledevicepairing / .plist）。"
        case .invalidPairingFile(let detail):
            return "设备配对文件无效：\(detail)"
        case .tunnelDisconnected(let vpn):
            return "未检测到本地回环隧道，请先开启 \(vpn.displayName)。"
        case .missingAppleIDCredentials:
            return "请先登录 Apple ID 开发者账号。"
        case .twoFactorCodeRequired:
            return "需要输入 Apple ID 双重认证（2FA）6 位验证码。"
        case .invalidTwoFactorCode:
            return "请输入有效的 6 位双重认证数字验证码。"
        case .appleAuthenticationFailed(let reason):
            return "Apple ID 认证失败：\(reason)"
        case .invalidAnisetteURL:
            return "Anisette 服务器地址格式无效。"
        case .anisetteServerUnreachable(let host):
            return "无法连接 Anisette V3 服务器（\(host)）。"
        case .keychainFailure(let status):
            return "钥匙串访问失败（状态码：\(status)）。"
        case .missingIPAFile:
            return "未找到用于重签名的 IPA 文件。"
        case .otaNoReleaseFound:
            return "未在云端仓库中找到可用的未签名 IPA 构建。"
        case .backendOperationFailed(let reason):
            return reason
        }
    }
}

/// Secure Keychain storage for Apple ID credentials, authenticated developer session tokens, and certificate keys.
public enum SelfRefreshKeychain {
    private static let service = "io.github.selfrefreshkit.credentials"
    private static let sessionAccount = "__apple_auth_session_v2__"

    public static func savePassword(_ password: String, for account: String) throws {
        try saveData(Data(password.utf8), for: account)
    }

    public static func loadPassword(for account: String) throws -> String? {
        guard let data = try loadData(for: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func deletePassword(for account: String) throws {
        try deleteData(for: account)
    }

    public static func saveAuthSession(_ session: AppleAuthSession) throws {
        let data = try JSONEncoder().encode(session)
        try saveData(data, for: sessionAccount)
    }

    public static func loadAuthSession() throws -> AppleAuthSession? {
        guard let data = try loadData(for: sessionAccount) else { return nil }
        return try? JSONDecoder().decode(AppleAuthSession.self, from: data)
    }

    public static func deleteAuthSession() throws {
        try deleteData(for: sessionAccount)
    }

    private static func saveData(_ data: Data, for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SelfRefreshError.keychainFailure(addStatus)
            }
        } else if status != errSecSuccess {
            throw SelfRefreshError.keychainFailure(status)
        }
    }

    private static func loadData(for account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw SelfRefreshError.keychainFailure(status)
        }
        return data
    }

    private static func deleteData(for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SelfRefreshError.keychainFailure(status)
        }
    }
}
