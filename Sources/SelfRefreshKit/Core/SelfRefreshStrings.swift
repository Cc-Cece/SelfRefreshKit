import Foundation

/// Standardized localization keys for `SelfRefreshKit`.
/// All 7 supported languages (`en`, `zh-Hans`, `yue-Hant-HK`, `ja`, `de`, `fr`, `ko`)
/// provide 100% coverage of these keys in both `.lproj/Localizable.strings` and the in-memory table.
public enum SelfRefreshL10nKey: String, CaseIterable, Sendable {
    // MARK: - Navigation & Common
    case navTitle = "srk.nav.title"
    case commonOK = "srk.common.ok"
    case commonDone = "srk.common.done"
    case commonClose = "srk.common.close"
    case commonCancel = "srk.common.cancel"
    case commonSave = "srk.common.save"
    case commonContinueDanger = "srk.common.continue_danger"
    case commonResetDefault = "srk.common.reset_default"
    case commonDownloadAndInstall = "srk.common.download_install"
    case commonPresent = "srk.common.present"
    case commonNone = "srk.common.none"
    case commonRecommended = "srk.common.recommended"

    // MARK: - Main Page: Current Status
    case statusHeader = "srk.status.header"
    case statusProfileValidity = "srk.status.profile_validity"
    case statusRefreshNow = "srk.status.refresh_now"
    case statusProcessing = "srk.status.processing"
    case statusSetupRequiredBadge = "srk.status.setup_required"
    case statusReadyBadge = "srk.status.ready"
    case statusExpiredBadge = "srk.status.expired"
    case statusNoEmbeddedProfile = "srk.status.no_profile"

    // MARK: - Main Page: Secondary Navigation Entries
    case navSectionHeader = "srk.nav.section_header"
    case navRequiredTitle = "srk.nav.required.title"
    case navHealthTitle = "srk.nav.health.title"
    case navOptionalTitle = "srk.nav.optional.title"
    case navOptionalSubtitle = "srk.nav.optional.subtitle"

    // MARK: - Main Page: Language & About Section
    case aboutSectionHeader = "srk.about.section_header"
    case aboutLanguagePicker = "srk.about.language_picker"
    case aboutFollowHost = "srk.about.follow_host"

    // MARK: - Secondary Page 1: Required Setup
    case requiredSectionHeader = "srk.required.section_header"
    case requiredStep1Title = "srk.required.step1.title"
    case requiredStep1Done = "srk.required.step1.done"
    case requiredStep1Pending = "srk.required.step1.pending"
    case requiredStep2Title = "srk.required.step2.title"
    case requiredStep2Done = "srk.required.step2.done"
    case requiredStep2Pending = "srk.required.step2.pending"
    case requiredStep3Title = "srk.required.step3.title"
    case requiredStep3SubDone = "srk.required.step3.sub_done"
    case requiredStep3SubPending = "srk.required.step3.sub_pending"
    case requiredStep3BadgePending = "srk.required.step3.badge_pending"
    case requiredTunnelTitle = "srk.required.tunnel.title"
    case requiredTunnelConnected = "srk.required.tunnel.connected"
    case requiredTunnelDisconnected = "srk.required.tunnel.disconnected"

    // MARK: - Secondary Page 2: Health Check
    case healthRunButton = "srk.health.run_button"
    case healthAllHealthy = "srk.health.all_healthy"
    case healthNeedsAttention = "srk.health.needs_attention"
    case healthFooter = "srk.health.footer"
    case healthItemPairingTitle = "srk.health.item.pairing.title"
    case healthItemPairingMissing = "srk.health.item.pairing.missing"
    case healthItemTunnelConnected = "srk.health.item.tunnel.connected"
    case healthItemTunnelDisconnected = "srk.health.item.tunnel.disconnected"
    case healthItemAnisetteInvalid = "srk.health.item.anisette.invalid"
    case healthItemAccountTitle = "srk.health.item.account.title"
    case healthItemAccountMissing = "srk.health.item.account.missing"
    case healthItemProfileTakenOver = "srk.health.item.profile.taken_over"
    case healthItemProfilePending = "srk.health.item.profile.pending"

    // MARK: - Secondary Page 3: Optional Actions (Shortcuts, VPN, Cloud OTA, Direct IPA URL)
    case optionalShortcutSectionHeader = "srk.optional.shortcut.header"
    case optionalShortcutConfigureButton = "srk.optional.shortcut.configure"
    case optionalShortcutFooter = "srk.optional.shortcut.footer"
    case optionalEnvSectionHeader = "srk.optional.env.header"
    case optionalPreferredVPN = "srk.optional.env.preferred_vpn"
    case optionalUpdateSectionHeader = "srk.optional.update.header"
    case optionalCheckOTA = "srk.optional.update.check_ota"
    case optionalConfigureOTASource = "srk.optional.update.configure_source"
    case optionalOTADangerTitle = "srk.optional.update.danger_title"
    case optionalOTADangerMessage = "srk.optional.update.danger_message"
    case optionalOTAInputTitle = "srk.optional.update.input_title"
    case optionalOTAInputMessage = "srk.optional.update.input_message"
    case optionalDirectIPAButton = "srk.optional.update.direct_ipa_button"
    case optionalDirectIPATitle = "srk.optional.update.direct_ipa_title"
    case optionalDirectIPAMessage = "srk.optional.update.direct_ipa_message"
    case optionalLocalIPAButton = "srk.optional.update.local_ipa_button"

    // MARK: - Sheets: Pairing Detail
    case pairingSheetTitle = "srk.pairing.sheet_title"
    case pairingDetailsSection = "srk.pairing.details_section"
    case pairingExportButton = "srk.pairing.export_button"
    case pairingReimportButton = "srk.pairing.reimport_button"

    // MARK: - Sheets: Apple ID Authentication
    case accountSheetTitle = "srk.account.sheet_title"
    case accountSessionSection = "srk.account.session_section"
    case accountSignOutButton = "srk.account.sign_out_button"
    case accountLoginSection = "srk.account.login_section"
    case accountLoginFooter = "srk.account.login_footer"
    case accountPasswordPlaceholder = "srk.account.password"
    case accountToggle2FA = "srk.account.toggle_2fa"
    case account2FAPlaceholder = "srk.account.2fa_placeholder"
    case accountPresetServer = "srk.account.preset_server"
    case accountAutoSelectAnisette = "srk.account.auto_anisette"
    case accountAuthenticating = "srk.account.authenticating"
    case accountSubmitButton = "srk.account.submit_button"

    // MARK: - Sheets: Shortcuts Guide
    case shortcutGuideSection = "srk.shortcut.guide_section"
    case shortcutStep1 = "srk.shortcut.step1"
    case shortcutStep2 = "srk.shortcut.step2"
    case shortcutStep3 = "srk.shortcut.step3"
    case shortcutStep4 = "srk.shortcut.step4"
    case shortcutGetICloudButton = "srk.shortcut.get_icloud_button"
    case shortcutViewDocsButton = "srk.shortcut.view_docs_button"
    case shortcutOpenAppButton = "srk.shortcut.open_app_button"

    // MARK: - Sheets: About SelfRefreshKit
    case aboutSheetTitle = "srk.about.sheet_title"
    case aboutInfoSection = "srk.about.info_section"
    case aboutEngineMuxer = "srk.about.engine_muxer"
    case aboutEngineSigning = "srk.about.engine_signing"
    case aboutPreferredTunnel = "srk.about.preferred_tunnel"
    case aboutLicense = "srk.about.license"
    case aboutRepository = "srk.about.repository"
    case aboutSummary = "srk.about.summary"

    // MARK: - AppIntents (Apple Shortcuts Multi-Language)
    case intentRefreshTitle = "srk.intent.refresh.title"
    case intentRefreshDescription = "srk.intent.refresh.description"
    case intentRefreshResult = "srk.intent.refresh.result"

    // MARK: - Feedback Notices & Errors
    case noticePairingImportedTitle = "srk.notice.pairing_imported.title"
    case noticePairingFailedTitle = "srk.notice.pairing_failed.title"
    case noticeAuthSuccessTitle = "srk.notice.auth_success.title"
    case noticeAuthFailedTitle = "srk.notice.auth_failed.title"
    case noticeSignedOutTitle = "srk.notice.signed_out.title"
    case noticeSignedOutMessage = "srk.notice.signed_out.message"
    case noticeFastestServerTitle = "srk.notice.fastest_server.title"
    case noticeRefreshSuccessTitle = "srk.notice.refresh_success.title"
    case noticeRefreshSuccessMessage = "srk.notice.refresh_success.message"
    case noticeRefreshFailedTitle = "srk.notice.refresh_failed.title"
    case noticeTakeoverSuccessTitle = "srk.notice.takeover_success.title"
    case noticeTakeoverSuccessMessage = "srk.notice.takeover_success.message"
    case noticeTunnelConnectedTitle = "srk.notice.tunnel_connected.title"
    case noticeTunnelDisconnectedTitle = "srk.notice.tunnel_disconnected.title"
    case noticeMissingCredentialsTitle = "srk.notice.missing_credentials.title"
    case noticeFileReadFailedTitle = "srk.notice.file_read_failed.title"
    case noticeOTASourceUpdatedTitle = "srk.notice.ota_source_updated.title"
    case noticeInvalidURLTitle = "srk.notice.invalid_url.title"
    case noticeInvalidURLMessage = "srk.notice.invalid_url.message"
}

/// Standard localization engine for `SelfRefreshKit` supporting 7 languages:
/// - English (`en`, default & fallback)
/// - Simplified Chinese (`zh-Hans`)
/// - Cantonese / Traditional HK (`yue-Hant-HK`)
/// - Japanese (`ja`)
/// - German (`de`)
/// - French (`fr`)
/// - Korean (`ko`)
public enum SelfRefreshStrings {
    /// Returns the localized string for a `SelfRefreshL10nKey`.
    public static func tr(
        _ key: SelfRefreshL10nKey,
        preferredLanguage: SelfRefreshLanguage = .followHost,
        hostLanguageIdentifier: String? = nil
    ) -> String {
        translate(key.rawValue, preferredLanguage: preferredLanguage, hostLanguageIdentifier: hostLanguageIdentifier)
    }

    /// Translates a semantic key (`srk.*`) or legacy key using:
    /// 1. Manual language override (`preferredLanguage != .followHost`)
    /// 2. Host app language (`hostLanguageIdentifier`) or system language
    /// 3. Fallback to `.english` (`en`)
    public static func translate(
        _ key: String,
        preferredLanguage: SelfRefreshLanguage = .followHost,
        hostLanguageIdentifier: String? = nil
    ) -> String {
        let resolved: SelfRefreshLanguage
        if preferredLanguage != .followHost {
            resolved = preferredLanguage
        } else {
            let candidate = hostLanguageIdentifier ?? Locale.preferredLanguages.first ?? "en"
            resolved = SelfRefreshLanguage.resolveConcrete(from: candidate)
        }

        let canonicalKey = legacyKeyAliases[key] ?? key

        // 1. Try loading from the standard `.lproj/Localizable.strings` resource bundle if present
        #if SWIFT_PACKAGE
        if let lprojPath = Bundle.module.path(forResource: resolved.rawValue, ofType: "lproj"),
           let langBundle = Bundle(path: lprojPath) {
            let localized = langBundle.localizedString(forKey: canonicalKey, value: "__SRK_MISSING__", table: "Localizable")
            if localized != "__SRK_MISSING__" {
                return localized
            }
        }
        #endif

        // 2. Fallback to compiled 7-language dictionary (100% key parity with .lproj files)
        let table = table(for: resolved)
        if let value = table[canonicalKey] {
            return value
        }
        if let fallback = english[canonicalKey] {
            return fallback
        }
        return key
    }

    public static func translate(_ key: String, localeIdentifier: String) -> String {
        translate(key, preferredLanguage: .followHost, hostLanguageIdentifier: localeIdentifier)
    }

    public static func table(for language: SelfRefreshLanguage) -> [String: String] {
        switch language {
        case .simplifiedChinese: return simplifiedChinese
        case .english, .followHost: return english
        case .cantonese: return cantonese
        case .japanese: return japanese
        case .german: return german
        case .french: return french
        case .korean: return korean
        }
    }

    /// Backward-compatible aliases so existing tests or callers using Chinese literals still resolve cleanly.
    private static let legacyKeyAliases: [String: String] = [
        "当前状态": SelfRefreshL10nKey.statusHeader.rawValue,
        "签名与自动续期": SelfRefreshL10nKey.navTitle.rawValue,
        "描述文件有效期": SelfRefreshL10nKey.statusProfileValidity.rawValue,
        "立即续签": SelfRefreshL10nKey.statusRefreshNow.rawValue,
        "必需操作": SelfRefreshL10nKey.navRequiredTitle.rawValue,
        "健康状态检查": SelfRefreshL10nKey.navHealthTitle.rawValue,
        "可选操作": SelfRefreshL10nKey.navOptionalTitle.rawValue,
        "关于组件": SelfRefreshL10nKey.aboutSectionHeader.rawValue,
        "关于 SelfRefreshKit": SelfRefreshL10nKey.aboutSheetTitle.rawValue
    ]

    // MARK: - 1. English (en - Default & Fallback)
    public static let english: [String: String] = [
        "srk.nav.title": "Signing & Auto-Refresh",
        "srk.common.ok": "OK",
        "srk.common.done": "Done",
        "srk.common.close": "Close",
        "srk.common.cancel": "Cancel",
        "srk.common.save": "Save",
        "srk.common.continue_danger": "I Understand the Risk, Continue",
        "srk.common.reset_default": "Restore Default Source",
        "srk.common.download_install": "Download & Install",
        "srk.common.present": "Present",
        "srk.common.none": "None",
        "srk.common.recommended": "Recommended",

        "srk.status.header": "Current Status",
        "srk.status.profile_validity": "Profile Validity",
        "srk.status.refresh_now": "Refresh Now",
        "srk.status.processing": "Processing…",
        "srk.status.setup_required": "Setup Required",
        "srk.status.ready": "Ready",
        "srk.status.expired": "Expired",
        "srk.status.no_profile": "No Embedded Profile Detected",

        "srk.nav.section_header": "Configuration & Diagnostics",
        "srk.nav.required.title": "Required Setup",
        "srk.nav.health.title": "Health Status Check",
        "srk.nav.optional.title": "Optional Actions",
        "srk.nav.optional.subtitle": "Automation & Updates",

        "srk.about.section_header": "About Component",
        "srk.about.language_picker": "Component Language",
        "srk.about.follow_host": "Follow Host App / System",

        "srk.required.section_header": "Required Setup (Complete 3 Steps)",
        "srk.required.step1.title": "1. Import Device Pairing File",
        "srk.required.step1.done": "Completed",
        "srk.required.step1.pending": "Incomplete · Tap to Import",
        "srk.required.step2.title": "2. Sign In to Apple Developer",
        "srk.required.step2.done": "Authenticated",
        "srk.required.step2.pending": "Incomplete · Tap to Sign In",
        "srk.required.step3.title": "3. Initial Local Signing Takeover",
        "srk.required.step3.sub_done": "Local Keychain certificate active",
        "srk.required.step3.sub_pending": "Select unsigned app IPA to complete initial takeover",
        "srk.required.step3.badge_pending": "Pending",
        "srk.required.tunnel.title": "Loopback Tunnel",
        "srk.required.tunnel.connected": "Connected",
        "srk.required.tunnel.disconnected": "Disconnected · Tap to Open",

        "srk.health.run_button": "Run Comprehensive Health Check",
        "srk.health.all_healthy": "All Healthy",
        "srk.health.needs_attention": "Needs Attention",
        "srk.health.footer": "Verifies pairing file integrity, 10.7.0.1 loopback interface, Anisette V3 latency, and Apple developer session.",
        "srk.health.item.pairing.title": "Device Pairing File",
        "srk.health.item.pairing.missing": "No valid .mobiledevicepairing / .plist imported",
        "srk.health.item.tunnel.connected": "10.7.0.1 loopback interface active",
        "srk.health.item.tunnel.disconnected": "10.7.0.1 tunnel not detected (enable VPN before refreshing)",
        "srk.health.item.anisette.invalid": "Invalid Anisette URL format",
        "srk.health.item.account.title": "Apple Developer Session",
        "srk.health.item.account.missing": "Apple ID sign-in not completed yet",
        "srk.health.item.profile.taken_over": "Local certificate active",
        "srk.health.item.profile.pending": "Pending initial IPA takeover",

        "srk.optional.shortcut.header": "Shortcuts & Automation",
        "srk.optional.shortcut.configure": "Configure Background Auto-Refresh Shortcut",
        "srk.optional.shortcut.footer": "The built-in Shortcut action runs silently in the background without opening the app.",
        "srk.optional.env.header": "Environment",
        "srk.optional.env.preferred_vpn": "Preferred Tunnel App",
        "srk.optional.update.header": "Updates & Resigning",
        "srk.optional.update.check_ota": "Check Cloud Update & Self-Upgrade",
        "srk.optional.update.configure_source": "Cloud Update Repository",
        "srk.optional.update.danger_title": "Security Warning: Change Update Source?",
        "srk.optional.update.danger_message": "Changing the cloud update repository may install untrusted IPA builds, posing security risks to your account and data. Only proceed if you fully trust the target repository.",
        "srk.optional.update.input_title": "Set GitHub Update Repository",
        "srk.optional.update.input_message": "Enter repository in 'owner/repo' format (e.g. Cc-Cece/PicHarbor-iOS):",
        "srk.optional.update.direct_ipa_button": "Download & Install from Direct IPA URL",
        "srk.optional.update.direct_ipa_title": "Direct IPA URL Download",
        "srk.optional.update.direct_ipa_message": "Paste a direct HTTP/HTTPS link to an unsigned .ipa file to download, resign, and install on device:",
        "srk.optional.update.local_ipa_button": "Resign & Install Local IPA",

        "srk.pairing.sheet_title": "Device Pairing File",
        "srk.pairing.details_section": "Pairing File Details",
        "srk.pairing.export_button": "Export / Backup Pairing File",
        "srk.pairing.reimport_button": "Import Another Pairing File",

        "srk.account.sheet_title": "Apple ID Authentication",
        "srk.account.session_section": "Authenticated Developer Session",
        "srk.account.sign_out_button": "Sign Out & Clear Credentials",
        "srk.account.login_section": "Apple Developer Sign-In",
        "srk.account.login_footer": "Signs in via Anisette V3, retrieves your Team ID and session token, and stores them in Keychain.",
        "srk.account.password": "Password",
        "srk.account.toggle_2fa": "Enter Two-Factor (2FA) Code",
        "srk.account.2fa_placeholder": "6-digit 2FA verification code",
        "srk.account.preset_server": "Preset Server",
        "srk.account.auto_anisette": "Auto-Select Fastest Anisette Server",
        "srk.account.authenticating": "Authenticating with Apple…",
        "srk.account.submit_button": "Sign In & Save Developer Session",

        "srk.shortcut.guide_section": "Background Automation Steps",
        "srk.shortcut.step1": "1. Open the Apple Shortcuts app, go to Automation, and create a Time of Day trigger (e.g., 04:00 AM daily, select 'Run Immediately').",
        "srk.shortcut.step2": "2. Add action: Connect LocalDevVPN, then add 'Wait 2 seconds'.",
        "srk.shortcut.step3": "3. Add action: Search for this app and select 'Refresh App Provisioning Profile' (runs silently in background).",
        "srk.shortcut.step4": "4. Add action: Wait 5 seconds, then Disconnect LocalDevVPN.",
        "srk.shortcut.get_icloud_button": "Get Ready-to-Use iCloud Shortcut",
        "srk.shortcut.view_docs_button": "View Shortcuts Documentation on GitHub",
        "srk.shortcut.open_app_button": "Open Apple Shortcuts App",

        "srk.about.sheet_title": "About SelfRefreshKit",
        "srk.about.info_section": "Component Info",
        "srk.about.engine_muxer": "Muxer Engine",
        "srk.about.engine_signing": "Signing Engine",
        "srk.about.preferred_tunnel": "Preferred Tunnel",
        "srk.about.license": "Open Source License",
        "srk.about.repository": "GitHub Repository",
        "srk.about.summary": "Lightweight on-device provisioning profile refresher and OTA updater for iOS apps. Built for LocalDevVPN and compatible with StosVPN and WireGuard.",

        "srk.intent.refresh.title": "Refresh App Provisioning Profile",
        "srk.intent.refresh.description": "Silently refreshes the 7-day provisioning profile in the background via LocalDevVPN without opening the app.",
        "srk.intent.refresh.result": "Provisioning profile refreshed for another 7 days.",

        "srk.notice.pairing_imported.title": "Pairing File Imported",
        "srk.notice.pairing_failed.title": "Pairing File Import Failed",
        "srk.notice.auth_success.title": "Apple ID Authenticated",
        "srk.notice.auth_failed.title": "Apple ID Authentication Failed",
        "srk.notice.signed_out.title": "Signed Out",
        "srk.notice.signed_out.message": "Saved Apple ID developer credentials have been cleared.",
        "srk.notice.fastest_server.title": "Switched to Fastest Server",
        "srk.notice.refresh_success.title": "Refresh Succeeded",
        "srk.notice.refresh_success.message": "Provisioning profile refreshed for another 7 days.",
        "srk.notice.refresh_failed.title": "Refresh Failed",
        "srk.notice.takeover_success.title": "Signing Takeover Complete",
        "srk.notice.takeover_success.message": "Local signing takeover complete. Future refreshes only take 1 second.",
        "srk.notice.tunnel_connected.title": "Loopback Tunnel Connected",
        "srk.notice.tunnel_disconnected.title": "Loopback Tunnel Disconnected",
        "srk.notice.missing_credentials.title": "Missing Account Credentials",
        "srk.notice.file_read_failed.title": "File Read Failed",
        "srk.notice.ota_source_updated.title": "Cloud Update Source Updated",
        "srk.notice.invalid_url.title": "Invalid URL",
        "srk.notice.invalid_url.message": "Please enter a valid HTTP/HTTPS link to an .ipa file."
    ]

    // MARK: - 2. Simplified Chinese (zh-Hans)
    public static let simplifiedChinese: [String: String] = [
        "srk.nav.title": "签名与自动续期",
        "srk.common.ok": "好",
        "srk.common.done": "完成",
        "srk.common.close": "关闭",
        "srk.common.cancel": "取消",
        "srk.common.save": "保存",
        "srk.common.continue_danger": "了解风险，继续修改",
        "srk.common.reset_default": "恢复默认更新源",
        "srk.common.download_install": "下载并重签安装",
        "srk.common.present": "包含",
        "srk.common.none": "无",
        "srk.common.recommended": "推荐",

        "srk.status.header": "当前状态",
        "srk.status.profile_validity": "描述文件有效期",
        "srk.status.refresh_now": "立即续签",
        "srk.status.processing": "正在处理…",
        "srk.status.setup_required": "待配置",
        "srk.status.ready": "已就绪",
        "srk.status.expired": "已过期",
        "srk.status.no_profile": "未检测到内置描述文件",

        "srk.nav.section_header": "功能与检查",
        "srk.nav.required.title": "必需操作",
        "srk.nav.health.title": "健康状态检查",
        "srk.nav.optional.title": "可选操作",
        "srk.nav.optional.subtitle": "自动化与版本更新",

        "srk.about.section_header": "关于组件",
        "srk.about.language_picker": "组件语言",
        "srk.about.follow_host": "跟随宿主应用 / 系统",

        "srk.required.section_header": "必需操作（完成 3 步后即可无限续签）",
        "srk.required.step1.title": "1. 导入设备配对文件",
        "srk.required.step1.done": "已完成",
        "srk.required.step1.pending": "未完成 · 点击导入",
        "srk.required.step2.title": "2. 登录 Apple 开发者账号",
        "srk.required.step2.done": "已认证",
        "srk.required.step2.pending": "未完成 · 点击登录",
        "srk.required.step3.title": "3. 首次本机签名接管",
        "srk.required.step3.sub_done": "本机钥匙串证书已接管",
        "srk.required.step3.sub_pending": "选择本应用未签名 IPA 完成首次覆盖安装",
        "srk.required.step3.badge_pending": "待接管",
        "srk.required.tunnel.title": "本地回环隧道",
        "srk.required.tunnel.connected": "已连接",
        "srk.required.tunnel.disconnected": "未连接 · 点击开启",

        "srk.health.run_button": "运行全面健康状态检查",
        "srk.health.all_healthy": "全部正常",
        "srk.health.needs_attention": "存在提醒",
        "srk.health.footer": "自动实测配对文件、10.7.0.1 本地回环网卡、Anisette V3 节点延迟及 Apple 开发者会话状态。",
        "srk.health.item.pairing.title": "设备配对文件",
        "srk.health.item.pairing.missing": "未导入有效的 .mobiledevicepairing / .plist 文件",
        "srk.health.item.tunnel.connected": "10.7.0.1 虚拟网卡已连通",
        "srk.health.item.tunnel.disconnected": "未检测到 10.7.0.1 隧道（刷新前需开启 VPN）",
        "srk.health.item.anisette.invalid": "Anisette URL 格式无效",
        "srk.health.item.account.title": "Apple 开发者凭证",
        "srk.health.item.account.missing": "尚未完成 Apple ID 登录认证",
        "srk.health.item.profile.taken_over": "本机证书已接管",
        "srk.health.item.profile.pending": "待首次 IPA 接管",

        "srk.optional.shortcut.header": "快捷指令与自动化",
        "srk.optional.shortcut.configure": "配置「自动续签」快捷指令",
        "srk.optional.shortcut.footer": "内置快捷指令动作支持纯后台静默运行，不会自动跳转到前台。",
        "srk.optional.env.header": "环境配置",
        "srk.optional.env.preferred_vpn": "首选隧道应用",
        "srk.optional.update.header": "版本更新与重签",
        "srk.optional.update.check_ota": "检查云端更新并自签名升级",
        "srk.optional.update.configure_source": "云端更新源",
        "srk.optional.update.danger_title": "高危操作：确认修改云端更新源？",
        "srk.optional.update.danger_message": "修改云端更新仓库可能导致下载并安装非官方构建的 IPA，存在账号与数据安全风险。请确认你完全信任目标仓库。",
        "srk.optional.update.input_title": "配置 GitHub 云端更新仓库",
        "srk.optional.update.input_message": "请输入 owner/repo 格式的仓库地址（例如 Cc-Cece/PicHarbor-iOS）：",
        "srk.optional.update.direct_ipa_button": "输入 IPA 直链下载并重签安装",
        "srk.optional.update.direct_ipa_title": "输入 IPA 下载直链",
        "srk.optional.update.direct_ipa_message": "请输入 http:// 或 https:// 开头的未签名 IPA 下载直链：",
        "srk.optional.update.local_ipa_button": "选择本地 IPA 重签安装",

        "srk.pairing.sheet_title": "设备配对文件",
        "srk.pairing.details_section": "配对文件详情",
        "srk.pairing.export_button": "导出/备份当前配对文件",
        "srk.pairing.reimport_button": "重新导入其他配对文件",

        "srk.account.sheet_title": "Apple ID 登录与认证",
        "srk.account.session_section": "已认证开发者会话",
        "srk.account.sign_out_button": "退出并清除当前凭证",
        "srk.account.login_section": "登录 Apple 开发者中心",
        "srk.account.login_footer": "连接 Anisette V3 并获取开发者 Team ID 与会话凭证，加密保存在本机钥匙串。",
        "srk.account.password": "密码",
        "srk.account.toggle_2fa": "需要输入双重认证（2FA）验证码",
        "srk.account.2fa_placeholder": "6 位数字双重认证验证码",
        "srk.account.preset_server": "推荐节点",
        "srk.account.auto_anisette": "自动测速选择最快 Anisette 节点",
        "srk.account.authenticating": "正在连接 Apple 认证服务…",
        "srk.account.submit_button": "登录并保存开发者凭证",

        "srk.shortcut.guide_section": "自动化配置步骤（纯后台运行）",
        "srk.shortcut.step1": "1. 打开系统「快捷指令」应用，切换到「自动化」标签页并创建特定时间（如每天 04:00，选择「立即运行」）。",
        "srk.shortcut.step2": "2. 添加动作：连接 LocalDevVPN，并添加「等待 2 秒」。",
        "srk.shortcut.step3": "3. 添加动作：搜索本应用并选择「Refresh App Provisioning Profile」（纯后台静默刷新，不跳转前台）。",
        "srk.shortcut.step4": "4. 添加动作：等待 5 秒后断开 LocalDevVPN。",
        "srk.shortcut.get_icloud_button": "一键获取预设快捷指令 (iCloud)",
        "srk.shortcut.view_docs_button": "查看 GitHub 快捷指令配置文档 (#Shortcuts)",
        "srk.shortcut.open_app_button": "打开系统「快捷指令」应用",

        "srk.about.sheet_title": "关于 SelfRefreshKit",
        "srk.about.info_section": "组件信息",
        "srk.about.engine_muxer": "通信引擎",
        "srk.about.engine_signing": "签名引擎",
        "srk.about.preferred_tunnel": "首选隧道",
        "srk.about.license": "开源许可证",
        "srk.about.repository": "开源仓库",
        "srk.about.summary": "轻量级 iOS 应用内置自续签与云端 OTA 通用组件库。默认推荐配合 LocalDevVPN 使用，兼容 StosVPN 与 WireGuard。",

        "srk.intent.refresh.title": "刷新应用签名描述文件",
        "srk.intent.refresh.description": "在后台通过 LocalDevVPN 静默刷新 7 天应用签名描述文件，无需打开应用。",
        "srk.intent.refresh.result": "描述文件已刷新，有效期已重置为 7 天。",

        "srk.notice.pairing_imported.title": "配对文件导入成功",
        "srk.notice.pairing_failed.title": "配对文件导入失败",
        "srk.notice.auth_success.title": "Apple ID 认证成功",
        "srk.notice.auth_failed.title": "Apple ID 认证失败",
        "srk.notice.signed_out.title": "已退出账号",
        "srk.notice.signed_out.message": "已清除本机保存的 Apple ID 会话凭证。",
        "srk.notice.fastest_server.title": "已切换最快节点",
        "srk.notice.refresh_success.title": "刷新成功",
        "srk.notice.refresh_success.message": "描述文件已刷新，有效期已重置为 7 天。",
        "srk.notice.refresh_failed.title": "刷新失败",
        "srk.notice.takeover_success.title": "签名接管完成",
        "srk.notice.takeover_success.message": "已完成本机签名接管与覆盖安装。后续只需 1 秒刷新描述文件。",
        "srk.notice.tunnel_connected.title": "本地隧道已连通",
        "srk.notice.tunnel_disconnected.title": "未开启本地隧道",
        "srk.notice.missing_credentials.title": "缺少账号凭证",
        "srk.notice.file_read_failed.title": "文件读取失败",
        "srk.notice.ota_source_updated.title": "云端更新源已更新",
        "srk.notice.invalid_url.title": "链接格式无效",
        "srk.notice.invalid_url.message": "请输入以 http:// 或 https:// 开头的有效 IPA 下载链接。"
    ]

    // MARK: - 3. Cantonese / Traditional Chinese HK (yue-Hant-HK)
    public static let cantonese: [String: String] = [
        "srk.nav.title": "簽名與自動續期",
        "srk.common.ok": "好",
        "srk.common.done": "完成",
        "srk.common.close": "關閉",
        "srk.common.cancel": "取消",
        "srk.common.save": "儲存",
        "srk.common.continue_danger": "明白風險，繼續修改",
        "srk.common.reset_default": "恢復預設更新源",
        "srk.common.download_install": "下載並重簽安裝",
        "srk.common.present": "包含",
        "srk.common.none": "無",
        "srk.common.recommended": "推薦",

        "srk.status.header": "目前狀態",
        "srk.status.profile_validity": "描述檔有效期",
        "srk.status.refresh_now": "立即續簽",
        "srk.status.processing": "正在處理…",
        "srk.status.setup_required": "待設定",
        "srk.status.ready": "已就緒",
        "srk.status.expired": "已過期",
        "srk.status.no_profile": "未偵測到內置描述檔",

        "srk.nav.section_header": "功能與檢查",
        "srk.nav.required.title": "必需操作",
        "srk.nav.health.title": "健康狀態檢查",
        "srk.nav.optional.title": "可選操作",
        "srk.nav.optional.subtitle": "自動化與版本更新",

        "srk.about.section_header": "關於組件",
        "srk.about.language_picker": "組件語言",
        "srk.about.follow_host": "跟隨宿主應用 / 系統",

        "srk.required.section_header": "必需操作（完成 3 步後即可無限續簽）",
        "srk.required.step1.title": "1. 匯入裝置配對檔案",
        "srk.required.step1.done": "已完成",
        "srk.required.step1.pending": "未完成 · 點擊匯入",
        "srk.required.step2.title": "2. 登入 Apple 開發者帳戶",
        "srk.required.step2.done": "已認證",
        "srk.required.step2.pending": "未完成 · 點擊登入",
        "srk.required.step3.title": "3. 首次本機簽名接管",
        "srk.required.step3.sub_done": "本機鑰匙圈證書已接管",
        "srk.required.step3.sub_pending": "選取本應用未簽名 IPA 完成首次覆蓋安裝",
        "srk.required.step3.badge_pending": "待接管",
        "srk.required.tunnel.title": "本地迴環隧道",
        "srk.required.tunnel.connected": "已連接",
        "srk.required.tunnel.disconnected": "未連接 · 點擊開啟",

        "srk.health.run_button": "執行全面健康狀態檢查",
        "srk.health.all_healthy": "全部正常",
        "srk.health.needs_attention": "存在提醒",
        "srk.health.footer": "自動實測配對檔案、10.7.0.1 本地迴環網卡、Anisette V3 節點延遲及 Apple 開發者工作階段狀態。",
        "srk.health.item.pairing.title": "裝置配對檔案",
        "srk.health.item.pairing.missing": "未匯入有效嘅 .mobiledevicepairing / .plist 檔案",
        "srk.health.item.tunnel.connected": "10.7.0.1 虛擬網卡已連通",
        "srk.health.item.tunnel.disconnected": "未偵測到 10.7.0.1 隧道（續簽前需開啟 VPN）",
        "srk.health.item.anisette.invalid": "Anisette URL 格式無效",
        "srk.health.item.account.title": "Apple 開發者憑據",
        "srk.health.item.account.missing": "尚未完成 Apple ID 登入認證",
        "srk.health.item.profile.taken_over": "本機證書已接管",
        "srk.health.item.profile.pending": "待首次 IPA 接管",

        "srk.optional.shortcut.header": "捷徑與自動化",
        "srk.optional.shortcut.configure": "設定「自動續簽」背景捷徑",
        "srk.optional.shortcut.footer": "內置捷徑動作支援純背景靜默執行，唔會自動跳轉到前台。",
        "srk.optional.env.header": "環境配置",
        "srk.optional.env.preferred_vpn": "首選隧道應用",
        "srk.optional.update.header": "版本更新與重簽",
        "srk.optional.update.check_ota": "檢查雲端更新並自簽名升級",
        "srk.optional.update.configure_source": "雲端更新源",
        "srk.optional.update.danger_title": "高危操作：確認修改雲端更新源？",
        "srk.optional.update.danger_message": "修改雲端更新倉庫可能會安裝非官方構建嘅 IPA，存在帳戶同資料安全風險。請確認你完全信任目標倉庫。",
        "srk.optional.update.input_title": "設定 GitHub 雲端更新倉庫",
        "srk.optional.update.input_message": "請輸入 owner/repo 格式嘅倉庫地址（例如 Cc-Cece/PicHarbor-iOS）：",
        "srk.optional.update.direct_ipa_button": "輸入 IPA 直鏈下載並重簽安裝",
        "srk.optional.update.direct_ipa_title": "輸入 IPA 下載直鏈",
        "srk.optional.update.direct_ipa_message": "請輸入 http:// 或 https:// 開頭嘅未簽名 IPA 下載直鏈：",
        "srk.optional.update.local_ipa_button": "選取本機 IPA 重簽安裝",

        "srk.pairing.sheet_title": "裝置配對檔案",
        "srk.pairing.details_section": "配對檔案詳情",
        "srk.pairing.export_button": "匯出/備份目前配對檔案",
        "srk.pairing.reimport_button": "重新匯入其他配對檔案",

        "srk.account.sheet_title": "Apple ID 登入與認證",
        "srk.account.session_section": "已認證開發者工作階段",
        "srk.account.sign_out_button": "登出並清除目前憑據",
        "srk.account.login_section": "登入 Apple 開發者中心",
        "srk.account.login_footer": "連接 Anisette V3 並獲取開發者 Team ID 與工作階段憑據，加密儲存喺本機鑰匙圈。",
        "srk.account.password": "密碼",
        "srk.account.toggle_2fa": "需要輸入雙重認證（2FA）驗證碼",
        "srk.account.2fa_placeholder": "6 位數字雙重認證驗證碼",
        "srk.account.preset_server": "推薦節點",
        "srk.account.auto_anisette": "自動測速選取最快 Anisette 節點",
        "srk.account.authenticating": "正在連接 Apple 認證服務…",
        "srk.account.submit_button": "登入並儲存開發者憑據",

        "srk.shortcut.guide_section": "自動化設定步驟（純背景執行）",
        "srk.shortcut.step1": "1. 打開系統「捷徑」應用，切換到「自動化」分頁並建立特定時間（例如每日 04:00，揀「立即執行」）。",
        "srk.shortcut.step2": "2. 新增動作：連接 LocalDevVPN，並加入「等待 2 秒」。",
        "srk.shortcut.step3": "3. 新增動作：搜尋本應用並選取「Refresh App Provisioning Profile」（純背景靜默刷新，唔跳轉前台）。",
        "srk.shortcut.step4": "4. 新增動作：等待 5 秒後中斷連接 LocalDevVPN。",
        "srk.shortcut.get_icloud_button": "一鍵獲取預設捷徑 (iCloud)",
        "srk.shortcut.view_docs_button": "查看 GitHub 捷徑設定教學 (#Shortcuts)",
        "srk.shortcut.open_app_button": "打開系統「捷徑」應用",

        "srk.about.sheet_title": "關於 SelfRefreshKit",
        "srk.about.info_section": "組件資訊",
        "srk.about.engine_muxer": "通訊引擎",
        "srk.about.engine_signing": "簽名引擎",
        "srk.about.preferred_tunnel": "首選隧道",
        "srk.about.license": "開源許可證",
        "srk.about.repository": "開源倉庫",
        "srk.about.summary": "輕量級 iOS 應用內置自續簽與雲端 OTA 通用組件庫。預設推薦配合 LocalDevVPN 使用，兼容 StosVPN 與 WireGuard。",

        "srk.intent.refresh.title": "刷新應用簽名描述檔",
        "srk.intent.refresh.description": "喺背景透過 LocalDevVPN 靜默刷新 7 日應用簽名描述檔，無需打開應用。",
        "srk.intent.refresh.result": "描述檔已刷新，有效期已重設為 7 日。",

        "srk.notice.pairing_imported.title": "配對檔案匯入成功",
        "srk.notice.pairing_failed.title": "配對檔案匯入失敗",
        "srk.notice.auth_success.title": "Apple ID 認證成功",
        "srk.notice.auth_failed.title": "Apple ID 認證失敗",
        "srk.notice.signed_out.title": "已登出帳戶",
        "srk.notice.signed_out.message": "已清除本機儲存嘅 Apple ID 憑據。",
        "srk.notice.fastest_server.title": "已切換最快節點",
        "srk.notice.refresh_success.title": "續簽成功",
        "srk.notice.refresh_success.message": "描述檔已刷新，有效期已重設為 7 日。",
        "srk.notice.refresh_failed.title": "續簽失敗",
        "srk.notice.takeover_success.title": "簽名接管完成",
        "srk.notice.takeover_success.message": "已完成本機簽名接管與覆蓋安裝。後續只需 1 秒刷新描述檔。",
        "srk.notice.tunnel_connected.title": "本地隧道已連通",
        "srk.notice.tunnel_disconnected.title": "未開啟本地隧道",
        "srk.notice.missing_credentials.title": "缺少帳戶憑據",
        "srk.notice.file_read_failed.title": "檔案讀取失敗",
        "srk.notice.ota_source_updated.title": "雲端更新源已更新",
        "srk.notice.invalid_url.title": "連結格式無效",
        "srk.notice.invalid_url.message": "請輸入以 http:// 或 https:// 開頭嘅有效 IPA 下載連結。"
    ]

    // MARK: - 4. Japanese (ja)
    public static let japanese: [String: String] = [
        "srk.nav.title": "署名と自動更新",
        "srk.common.ok": "OK",
        "srk.common.done": "完了",
        "srk.common.close": "閉じる",
        "srk.common.cancel": "キャンセル",
        "srk.common.save": "保存",
        "srk.common.continue_danger": "リスクを理解して変更する",
        "srk.common.reset_default": "デフォルトに戻す",
        "srk.common.download_install": "ダウンロードしてインストール",
        "srk.common.present": "あり",
        "srk.common.none": "なし",
        "srk.common.recommended": "推奨",

        "srk.status.header": "現在のステータス",
        "srk.status.profile_validity": "プロファイル有効期限",
        "srk.status.refresh_now": "今すぐ更新",
        "srk.status.processing": "処理中…",
        "srk.status.setup_required": "未設定",
        "srk.status.ready": "準備完了",
        "srk.status.expired": "期限切れ",
        "srk.status.no_profile": "内蔵プロファイル未検出",

        "srk.nav.section_header": "設定と診断",
        "srk.nav.required.title": "必須設定",
        "srk.nav.health.title": "ヘルスチェック（診断）",
        "srk.nav.optional.title": "オプション操作",
        "srk.nav.optional.subtitle": "自動化・アップデート",

        "srk.about.section_header": "コンポーネント情報",
        "srk.about.language_picker": "表示言語 (Language)",
        "srk.about.follow_host": "ホストアプリ / システムに従う",

        "srk.required.section_header": "必須設定（3ステップ完了で自動更新が可能）",
        "srk.required.step1.title": "1. ペアリングファイルの読み込み",
        "srk.required.step1.done": "完了",
        "srk.required.step1.pending": "未完了 · タップして選択",
        "srk.required.step2.title": "2. Apple 開発者アカウント登録",
        "srk.required.step2.done": "認証済み",
        "srk.required.step2.pending": "未完了 · タップしてログイン",
        "srk.required.step3.title": "3. 初回ローカル署名引き継ぎ",
        "srk.required.step3.sub_done": "端末キーチェーン証明書が有効",
        "srk.required.step3.sub_pending": "未署名IPAを選択して初回上書きインストール",
        "srk.required.step3.badge_pending": "未完了",
        "srk.required.tunnel.title": "ループバック VPN",
        "srk.required.tunnel.connected": "接続済み",
        "srk.required.tunnel.disconnected": "未接続 · タップして起動",

        "srk.health.run_button": "総合ヘルスチェックを実行",
        "srk.health.all_healthy": "すべて正常",
        "srk.health.needs_attention": "要確認",
        "srk.health.footer": "ペアリングファイル、10.7.0.1 ループバック通信、Anisette V3 遅延、Apple 開発者セッションを診断します。",
        "srk.health.item.pairing.title": "デバイスペアリングファイル",
        "srk.health.item.pairing.missing": "有効な .mobiledevicepairing / .plist が未インポートです",
        "srk.health.item.tunnel.connected": "10.7.0.1 仮想インターフェース接続済み",
        "srk.health.item.tunnel.disconnected": "10.7.0.1 トンネル未検出（更新前に VPN を有効化してください）",
        "srk.health.item.anisette.invalid": "Anisette URL の形式が無効です",
        "srk.health.item.account.title": "Apple 開発者セッション",
        "srk.health.item.account.missing": "Apple ID 認証がまだ完了していません",
        "srk.health.item.profile.taken_over": "端末証明書引き継ぎ済み",
        "srk.health.item.profile.pending": "初回 IPA 引き継ぎ待ち",

        "srk.optional.shortcut.header": "ショートカットと自動化",
        "srk.optional.shortcut.configure": "バックグラウンド自動更新ショートカット設定",
        "srk.optional.shortcut.footer": "内蔵ショートカットアクションはアプリを開かずにバックグラウンドで静かに実行されます。",
        "srk.optional.env.header": "環境設定",
        "srk.optional.env.preferred_vpn": "優先 VPN アプリ",
        "srk.optional.update.header": "アップデートと再署名",
        "srk.optional.update.check_ota": "クラウド更新を確認して自己署名アップデート",
        "srk.optional.update.configure_source": "クラウド更新リポジトリ",
        "srk.optional.update.danger_title": "警告：更新元リポジトリを変更しますか？",
        "srk.optional.update.danger_message": "クラウド更新元を変更すると、非公式の IPA がインストールされセキュリティリスクが生じる可能性があります。信頼できるリポジトリのみを指定してください。",
        "srk.optional.update.input_title": "GitHub 更新リポジトリの設定",
        "srk.optional.update.input_message": "owner/repo 形式でリポジトリを入力してください（例: Cc-Cece/PicHarbor-iOS）：",
        "srk.optional.update.direct_ipa_button": "IPA 直リンクを入力してダウンロード・署名",
        "srk.optional.update.direct_ipa_title": "IPA 直リンクの入力",
        "srk.optional.update.direct_ipa_message": "未署名 .ipa ファイルの http:// または https:// 直接リンクを入力してください：",
        "srk.optional.update.local_ipa_button": "ローカル IPA を選択して再署名インストール",

        "srk.pairing.sheet_title": "デバイスペアリングファイル",
        "srk.pairing.details_section": "ペアリングファイル詳細",
        "srk.pairing.export_button": "現在のペアリングファイルを書き出す",
        "srk.pairing.reimport_button": "別のペアリングファイルを読み込む",

        "srk.account.sheet_title": "Apple ID ログインと認証",
        "srk.account.session_section": "認証済み開発者セッション",
        "srk.account.sign_out_button": "ログアウトして認証情報を削除",
        "srk.account.login_section": "Apple Developer ログイン",
        "srk.account.login_footer": "Anisette V3 経由で Team ID とセッショントークンを取得し、キーチェーンに暗号化保存します。",
        "srk.account.password": "パスワード",
        "srk.account.toggle_2fa": "2ファクタ認証（2FA）コードを入力",
        "srk.account.2fa_placeholder": "6桁の確認コード",
        "srk.account.preset_server": "推奨ノード",
        "srk.account.auto_anisette": "最速の Anisette ノードを自動選択",
        "srk.account.authenticating": "Apple 認証サーバーに接続中…",
        "srk.account.submit_button": "ログインして認証情報を保存",

        "srk.shortcut.guide_section": "バックグラウンド自動化手順",
        "srk.shortcut.step1": "1. 「ショートカット」アプリの「オートメーション」タブで時刻トリガー（例：毎日 04:00、「すぐに実行」）を作成します。",
        "srk.shortcut.step2": "2. アクション追加：LocalDevVPN を接続し、「2秒待機」を追加します。",
        "srk.shortcut.step3": "3. アクション追加：このアプリを検索し「Refresh App Provisioning Profile」を選択します。",
        "srk.shortcut.step4": "4. アクション追加：5秒待機後、LocalDevVPN を切断します。",
        "srk.shortcut.get_icloud_button": "定義済みショートカットを入手 (iCloud)",
        "srk.shortcut.view_docs_button": "GitHub でショートカット設定ガイドを見る (#Shortcuts)",
        "srk.shortcut.open_app_button": "「ショートカット」アプリを開く",

        "srk.about.sheet_title": "SelfRefreshKit について",
        "srk.about.info_section": "コンポーネント情報",
        "srk.about.engine_muxer": "通信エンジン",
        "srk.about.engine_signing": "署名エンジン",
        "srk.about.preferred_tunnel": "優先トンネル",
        "srk.about.license": "オープンソースライセンス",
        "srk.about.repository": "GitHub リポジトリ",
        "srk.about.summary": "iOS アプリ内蔵型の軽量プロファイル自動更新＆クラウド OTA コンポーネント。LocalDevVPN 推奨、StosVPN・WireGuard 対応。",

        "srk.intent.refresh.title": "アプリのプロファイルを更新",
        "srk.intent.refresh.description": "アプリを開かずに LocalDevVPN 経由でバックグラウンドで7日間プロファイルを更新します。",
        "srk.intent.refresh.result": "プロファイルが更新され、有効期限が7日間にリセットされました。",

        "srk.notice.pairing_imported.title": "ペアリングファイル読込完了",
        "srk.notice.pairing_failed.title": "ペアリングファイル読込失敗",
        "srk.notice.auth_success.title": "Apple ID 認証成功",
        "srk.notice.auth_failed.title": "Apple ID 認証失敗",
        "srk.notice.signed_out.title": "ログアウト完了",
        "srk.notice.signed_out.message": "保存されていた Apple ID 認証情報を消去しました。",
        "srk.notice.fastest_server.title": "最速ノードに切り替えました",
        "srk.notice.refresh_success.title": "更新成功",
        "srk.notice.refresh_success.message": "プロファイルが更新され、有効期限が7日間にリセットされました。",
        "srk.notice.refresh_failed.title": "更新失敗",
        "srk.notice.takeover_success.title": "署名引き継ぎ完了",
        "srk.notice.takeover_success.message": "ローカル署名引き継ぎが完了しました。今後は1秒で更新できます。",
        "srk.notice.tunnel_connected.title": "ループバック VPN 接続済み",
        "srk.notice.tunnel_disconnected.title": "ループバック VPN 未接続",
        "srk.notice.missing_credentials.title": "アカウント情報未設定",
        "srk.notice.file_read_failed.title": "ファイル読み込み失敗",
        "srk.notice.ota_source_updated.title": "更新元リポジトリを変更しました",
        "srk.notice.invalid_url.title": "無効な URL",
        "srk.notice.invalid_url.message": "http:// または https:// で始まる有効な IPA リンクを入力してください。"
    ]

    // MARK: - 5. German (de)
    public static let german: [String: String] = [
        "srk.nav.title": "Signierung & Auto-Refresh",
        "srk.common.ok": "OK",
        "srk.common.done": "Fertig",
        "srk.common.close": "Schließen",
        "srk.common.cancel": "Abbrechen",
        "srk.common.save": "Speichern",
        "srk.common.continue_danger": "Risiko verstanden, fortfahren",
        "srk.common.reset_default": "Standardquelle wiederherstellen",
        "srk.common.download_install": "Herunterladen & installieren",
        "srk.common.present": "Vorhanden",
        "srk.common.none": "Keine",
        "srk.common.recommended": "Empfohlen",

        "srk.status.header": "Aktueller Status",
        "srk.status.profile_validity": "Profil-Gültigkeit",
        "srk.status.refresh_now": "Jetzt erneuern",
        "srk.status.processing": "Verarbeitung…",
        "srk.status.setup_required": "Einrichtung nötig",
        "srk.status.ready": "Bereit",
        "srk.status.expired": "Abgelaufen",
        "srk.status.no_profile": "Kein eingebettetes Profil erkannt",

        "srk.nav.section_header": "Konfiguration & Diagnose",
        "srk.nav.required.title": "Erforderliche Einrichtung",
        "srk.nav.health.title": "Systemdiagnose (Health Check)",
        "srk.nav.optional.title": "Optionale Aktionen",
        "srk.nav.optional.subtitle": "Automatisierung & Updates",

        "srk.about.section_header": "Über Komponente",
        "srk.about.language_picker": "Komponentensprache",
        "srk.about.follow_host": "Host-App / System folgen",

        "srk.required.section_header": "Erforderliche Einrichtung (3 Schritte)",
        "srk.required.step1.title": "1. Pairing-Datei importieren",
        "srk.required.step1.done": "Abgeschlossen",
        "srk.required.step1.pending": "Offen · Zum Importieren tippen",
        "srk.required.step2.title": "2. Apple-Developer-Anmeldung",
        "srk.required.step2.done": "Authentifiziert",
        "srk.required.step2.pending": "Offen · Zum Anmelden tippen",
        "srk.required.step3.title": "3. Initiale Signaturübernahme",
        "srk.required.step3.sub_done": "Lokales Schlüsselbund-Zertifikat aktiv",
        "srk.required.step3.sub_pending": "Unsignierte IPA für Erstübernahme wählen",
        "srk.required.step3.badge_pending": "Ausstehend",
        "srk.required.tunnel.title": "Loopback-Tunnel",
        "srk.required.tunnel.connected": "Verbunden",
        "srk.required.tunnel.disconnected": "Getrennt · Tippen zum Öffnen",

        "srk.health.run_button": "Vollständigen Health-Check starten",
        "srk.health.all_healthy": "Alles OK",
        "srk.health.needs_attention": "Hinweis",
        "srk.health.footer": "Prüft Pairing-Datei, 10.7.0.1 Loopback-Netzwerk, Anisette-V3-Latenz und Apple-Entwicklersitzung.",
        "srk.health.item.pairing.title": "Geräte-Pairing-Datei",
        "srk.health.item.pairing.missing": "Keine gültige .mobiledevicepairing / .plist importiert",
        "srk.health.item.tunnel.connected": "10.7.0.1 Schnittstelle verbunden",
        "srk.health.item.tunnel.disconnected": "10.7.0.1 Tunnel nicht erkannt (vor Refresh VPN starten)",
        "srk.health.item.anisette.invalid": "Ungültiges Anisette-URL-Format",
        "srk.health.item.account.title": "Apple-Entwicklersitzung",
        "srk.health.item.account.missing": "Apple-ID-Anmeldung noch nicht abgeschlossen",
        "srk.health.item.profile.taken_over": "Lokales Zertifikat aktiv",
        "srk.health.item.profile.pending": "Initiale IPA-Übernahme ausstehend",

        "srk.optional.shortcut.header": "Kurzbefehle & Automation",
        "srk.optional.shortcut.configure": "Hintergrund-Kurzbefehl konfigurieren",
        "srk.optional.shortcut.footer": "Der integrierte Kurzbefehl läuft lautlos im Hintergrund, ohne die App zu öffnen.",
        "srk.optional.env.header": "Umgebung",
        "srk.optional.env.preferred_vpn": "Bevorzugte Tunnel-App",
        "srk.optional.update.header": "Updates & Neusignierung",
        "srk.optional.update.check_ota": "Cloud-Update prüfen & selbst aktualisieren",
        "srk.optional.update.configure_source": "Cloud-Update-Repository",
        "srk.optional.update.danger_title": "Sicherheitswarnung: Update-Quelle ändern?",
        "srk.optional.update.danger_message": "Das Ändern des Repositories kann zum Installieren nicht vertrauenswürdiger IPAs führen. Fahren Sie nur fort, wenn Sie der Quelle vollständig vertrauen.",
        "srk.optional.update.input_title": "GitHub-Repository festlegen",
        "srk.optional.update.input_message": "Repository im Format „owner/repo“ eingeben (z. B. Cc-Cece/PicHarbor-iOS):",
        "srk.optional.update.direct_ipa_button": "Direkten IPA-Link herunterladen & installieren",
        "srk.optional.update.direct_ipa_title": "Direkter IPA-Downloadlink",
        "srk.optional.update.direct_ipa_message": "Geben Sie einen direkten HTTP/HTTPS-Link zu einer unsignierten .ipa-Datei ein:",
        "srk.optional.update.local_ipa_button": "Lokale IPA neu signieren & installieren",

        "srk.pairing.sheet_title": "Geräte-Pairing-Datei",
        "srk.pairing.details_section": "Details zur Pairing-Datei",
        "srk.pairing.export_button": "Pairing-Datei exportieren / sichern",
        "srk.pairing.reimport_button": "Andere Pairing-Datei importieren",

        "srk.account.sheet_title": "Apple-ID-Authentifizierung",
        "srk.account.session_section": "Authentifizierte Entwicklersitzung",
        "srk.account.sign_out_button": "Abmelden & Zugangsdaten löschen",
        "srk.account.login_section": "Apple-Developer-Anmeldung",
        "srk.account.login_footer": "Meldet sich über Anisette V3 an und speichert Team-ID sowie Sitzungstoken sicher im Schlüsselbund.",
        "srk.account.password": "Passwort",
        "srk.account.toggle_2fa": "Zwei-Faktor-Code (2FA) eingeben",
        "srk.account.2fa_placeholder": "6-stelliger 2FA-Bestätigungscode",
        "srk.account.preset_server": "Server-Vorlage",
        "srk.account.auto_anisette": "Schnellsten Anisette-Server automatisch wählen",
        "srk.account.authenticating": "Verbindung zu Apple wird hergestellt…",
        "srk.account.submit_button": "Anmelden & Sitzung speichern",

        "srk.shortcut.guide_section": "Schritte für Hintergrund-Automation",
        "srk.shortcut.step1": "1. Öffnen Sie die App „Kurzbefehle“ -> „Automation“ und erstellen Sie eine Tageszeit-Automation („Sofort ausführen“).",
        "srk.shortcut.step2": "2. Aktion hinzufügen: LocalDevVPN verbinden, danach „2 Sekunden warten“.",
        "srk.shortcut.step3": "3. Aktion hinzufügen: Diese App suchen und „Refresh App Provisioning Profile“ wählen.",
        "srk.shortcut.step4": "4. Aktion hinzufügen: 5 Sekunden warten, dann LocalDevVPN trennen.",
        "srk.shortcut.get_icloud_button": "Fertigen iCloud-Kurzbefehl laden",
        "srk.shortcut.view_docs_button": "Kurzbefehl-Dokumentation auf GitHub (#Shortcuts)",
        "srk.shortcut.open_app_button": "App „Kurzbefehle“ öffnen",

        "srk.about.sheet_title": "Über SelfRefreshKit",
        "srk.about.info_section": "Komponenten-Info",
        "srk.about.engine_muxer": "Muxer-Engine",
        "srk.about.engine_signing": "Signatur-Engine",
        "srk.about.preferred_tunnel": "Bevorzugter Tunnel",
        "srk.about.license": "Open-Source-Lizenz",
        "srk.about.repository": "GitHub-Repository",
        "srk.about.summary": "Leichtgewichtige iOS-Komponente zur lokalen Profil-Erneuerung und für Cloud-OTA-Updates. Empfohlen mit LocalDevVPN, kompatibel mit StosVPN und WireGuard.",

        "srk.intent.refresh.title": "App-Provisioning-Profil erneuern",
        "srk.intent.refresh.description": "Erneuert das 7-Tage-Profil lautlos im Hintergrund über LocalDevVPN, ohne die App zu öffnen.",
        "srk.intent.refresh.result": "Das Provisioning-Profil wurde für weitere 7 Tage erneuert.",

        "srk.notice.pairing_imported.title": "Pairing-Datei importiert",
        "srk.notice.pairing_failed.title": "Import fehlgeschlagen",
        "srk.notice.auth_success.title": "Apple-ID authentifiziert",
        "srk.notice.auth_failed.title": "Authentifizierung fehlgeschlagen",
        "srk.notice.signed_out.title": "Abgemeldet",
        "srk.notice.signed_out.message": "Gespeicherte Apple-ID-Zugangsdaten wurden gelöscht.",
        "srk.notice.fastest_server.title": "Schnellster Server gewählt",
        "srk.notice.refresh_success.title": "Erneuerung erfolgreich",
        "srk.notice.refresh_success.message": "Das Provisioning-Profil wurde für weitere 7 Tage erneuert.",
        "srk.notice.refresh_failed.title": "Erneuerung fehlgeschlagen",
        "srk.notice.takeover_success.title": "Signaturübernahme abgeschlossen",
        "srk.notice.takeover_success.message": "Lokale Signaturübernahme abgeschlossen. Künftige Erneuerungen dauern nur 1 Sekunde.",
        "srk.notice.tunnel_connected.title": "Loopback-Tunnel verbunden",
        "srk.notice.tunnel_disconnected.title": "Loopback-Tunnel getrennt",
        "srk.notice.missing_credentials.title": "Zugangsdaten fehlen",
        "srk.notice.file_read_failed.title": "Dateilesefehler",
        "srk.notice.ota_source_updated.title": "Update-Quelle aktualisiert",
        "srk.notice.invalid_url.title": "Ungültige URL",
        "srk.notice.invalid_url.message": "Bitte geben Sie einen gültigen HTTP/HTTPS-Link zu einer .ipa-Datei ein."
    ]

    // MARK: - 6. French (fr)
    public static let french: [String: String] = [
        "srk.nav.title": "Signature et renouvellement auto",
        "srk.common.ok": "OK",
        "srk.common.done": "Terminé",
        "srk.common.close": "Fermer",
        "srk.common.cancel": "Annuler",
        "srk.common.save": "Enregistrer",
        "srk.common.continue_danger": "Je comprends le risque, continuer",
        "srk.common.reset_default": "Rétablir la source par défaut",
        "srk.common.download_install": "Télécharger et installer",
        "srk.common.present": "Présent",
        "srk.common.none": "Aucun",
        "srk.common.recommended": "Recommandé",

        "srk.status.header": "État actuel",
        "srk.status.profile_validity": "Validité du profil",
        "srk.status.refresh_now": "Renouveler maintenant",
        "srk.status.processing": "Traitement…",
        "srk.status.setup_required": "Configuration requise",
        "srk.status.ready": "Prêt",
        "srk.status.expired": "Expiré",
        "srk.status.no_profile": "Aucun profil intégré détecté",

        "srk.nav.section_header": "Configuration et diagnostic",
        "srk.nav.required.title": "Configuration requise",
        "srk.nav.health.title": "Bilan de santé (Diagnostic)",
        "srk.nav.optional.title": "Actions facultatives",
        "srk.nav.optional.subtitle": "Automatisation et mises à jour",

        "srk.about.section_header": "À propos du composant",
        "srk.about.language_picker": "Langue du composant",
        "srk.about.follow_host": "Suivre l’application / Système",

        "srk.required.section_header": "Configuration requise (3 étapes)",
        "srk.required.step1.title": "1. Importer le fichier de jumelage",
        "srk.required.step1.done": "Terminé",
        "srk.required.step1.pending": "Incomplet · Appuyer pour importer",
        "srk.required.step2.title": "2. Connexion développeur Apple",
        "srk.required.step2.done": "Authentifié",
        "srk.required.step2.pending": "Incomplet · Appuyer pour se connecter",
        "srk.required.step3.title": "3. Prise en charge locale initiale",
        "srk.required.step3.sub_done": "Certificat local du trousseau actif",
        "srk.required.step3.sub_pending": "Sélectionner l’IPA non signé pour l’installation initiale",
        "srk.required.step3.badge_pending": "En attente",
        "srk.required.tunnel.title": "Tunnel Loopback",
        "srk.required.tunnel.connected": "Connecté",
        "srk.required.tunnel.disconnected": "Déconnecté · Appuyer pour ouvrir",

        "srk.health.run_button": "Lancer le diagnostic complet",
        "srk.health.all_healthy": "Tout est normal",
        "srk.health.needs_attention": "Attention requise",
        "srk.health.footer": "Vérifie le fichier de jumelage, l’interface 10.7.0.1, la latence Anisette V3 et la session développeur Apple.",
        "srk.health.item.pairing.title": "Fichier de jumelage",
        "srk.health.item.pairing.missing": "Aucun fichier .mobiledevicepairing / .plist valide importé",
        "srk.health.item.tunnel.connected": "Interface 10.7.0.1 connectée",
        "srk.health.item.tunnel.disconnected": "Tunnel 10.7.0.1 non détecté (activez le VPN avant le renouvellement)",
        "srk.health.item.anisette.invalid": "Format d’URL Anisette invalide",
        "srk.health.item.account.title": "Session développeur Apple",
        "srk.health.item.account.missing": "Connexion identifiant Apple non terminée",
        "srk.health.item.profile.taken_over": "Certificat local actif",
        "srk.health.item.profile.pending": "En attente de la prise en charge IPA initiale",

        "srk.optional.shortcut.header": "Raccourcis et automatisation",
        "srk.optional.shortcut.configure": "Configurer le raccourci de renouvellement auto",
        "srk.optional.shortcut.footer": "L’action de raccourci intégrée s’exécute silencieusement en arrière-plan sans ouvrir l’application.",
        "srk.optional.env.header": "Environnement",
        "srk.optional.env.preferred_vpn": "Application VPN préférée",
        "srk.optional.update.header": "Mises à jour et resignature",
        "srk.optional.update.check_ota": "Vérifier la mise à jour cloud et installer",
        "srk.optional.update.configure_source": "Dépôt de mise à jour cloud",
        "srk.optional.update.danger_title": "Avertissement : Modifier la source ?",
        "srk.optional.update.danger_message": "Modifier le dépôt de mise à jour peut installer un fichier IPA non officiel et compromettre la sécurité de vos données. Continuez uniquement si vous faites confiance à ce dépôt.",
        "srk.optional.update.input_title": "Définir le dépôt GitHub",
        "srk.optional.update.input_message": "Entrez le dépôt au format « owner/repo » (ex. Cc-Cece/PicHarbor-iOS) :",
        "srk.optional.update.direct_ipa_button": "Télécharger et installer via lien direct IPA",
        "srk.optional.update.direct_ipa_title": "Lien direct IPA",
        "srk.optional.update.direct_ipa_message": "Collez un lien direct HTTP/HTTPS vers un fichier .ipa non signé :",
        "srk.optional.update.local_ipa_button": "Resigner et installer un IPA local",

        "srk.pairing.sheet_title": "Fichier de jumelage",
        "srk.pairing.details_section": "Détails du fichier de jumelage",
        "srk.pairing.export_button": "Exporter / Sauvegarder le fichier",
        "srk.pairing.reimport_button": "Importer un autre fichier de jumelage",

        "srk.account.sheet_title": "Authentification identifiant Apple",
        "srk.account.session_section": "Session développeur authentifiée",
        "srk.account.sign_out_button": "Se déconnecter et effacer les identifiants",
        "srk.account.login_section": "Connexion Apple Developer",
        "srk.account.login_footer": "Se connecte via Anisette V3, récupère votre Team ID et jeton de session, et les chiffre dans le trousseau.",
        "srk.account.password": "Mot de passe",
        "srk.account.toggle_2fa": "Saisir le code à deux facteurs (2FA)",
        "srk.account.2fa_placeholder": "Code de vérification à 6 chiffres",
        "srk.account.preset_server": "Serveur prédéfini",
        "srk.account.auto_anisette": "Sélectionner le serveur Anisette le plus rapide",
        "srk.account.authenticating": "Authentification auprès d’Apple…",
        "srk.account.submit_button": "Se connecter et enregistrer la session",

        "srk.shortcut.guide_section": "Étapes d’automatisation en arrière-plan",
        "srk.shortcut.step1": "1. Ouvrez l’app Raccourcis -> Automatisation, et créez un déclencheur horaire (« Exécuter immédiatement »).",
        "srk.shortcut.step2": "2. Ajoutez l’action : Connecter LocalDevVPN, puis « Attendre 2 secondes ».",
        "srk.shortcut.step3": "3. Ajoutez l’action : Recherchez cette app et choisissez « Refresh App Provisioning Profile ».",
        "srk.shortcut.step4": "4. Ajoutez l’action : Attendre 5 secondes, puis déconnecter LocalDevVPN.",
        "srk.shortcut.get_icloud_button": "Obtenir le raccourci iCloud prêt à l’emploi",
        "srk.shortcut.view_docs_button": "Voir la documentation sur GitHub (#Shortcuts)",
        "srk.shortcut.open_app_button": "Ouvrir l’application « Raccourcis »",

        "srk.about.sheet_title": "À propos de SelfRefreshKit",
        "srk.about.info_section": "Informations sur le composant",
        "srk.about.engine_muxer": "Moteur Muxer",
        "srk.about.engine_signing": "Moteur de signature",
        "srk.about.preferred_tunnel": "Tunnel préféré",
        "srk.about.license": "Licence Open Source",
        "srk.about.repository": "Dépôt GitHub",
        "srk.about.summary": "Composant léger de renouvellement local de profil et de mise à jour OTA pour iOS. Conçu pour LocalDevVPN et compatible avec StosVPN et WireGuard.",

        "srk.intent.refresh.title": "Actualiser le profil d’approvisionnement",
        "srk.intent.refresh.description": "Actualise silencieusement le profil de 7 jours en arrière-plan via LocalDevVPN sans ouvrir l’application.",
        "srk.intent.refresh.result": "Profil d’approvisionnement renouvelé pour 7 jours.",

        "srk.notice.pairing_imported.title": "Fichier de jumelage importé",
        "srk.notice.pairing_failed.title": "Échec de l’importation",
        "srk.notice.auth_success.title": "Identifiant Apple authentifié",
        "srk.notice.auth_failed.title": "Échec de l’authentification",
        "srk.notice.signed_out.title": "Déconnecté",
        "srk.notice.signed_out.message": "Les identifiants enregistrés ont été effacés.",
        "srk.notice.fastest_server.title": "Serveur le plus rapide sélectionné",
        "srk.notice.refresh_success.title": "Renouvellement réussi",
        "srk.notice.refresh_success.message": "Profil d’approvisionnement renouvelé pour 7 jours.",
        "srk.notice.refresh_failed.title": "Échec du renouvellement",
        "srk.notice.takeover_success.title": "Prise en charge terminée",
        "srk.notice.takeover_success.message": "Prise en charge locale terminée. Les prochains renouvellements ne prendront qu’une seconde.",
        "srk.notice.tunnel_connected.title": "Tunnel Loopback connecté",
        "srk.notice.tunnel_disconnected.title": "Tunnel Loopback déconnecté",
        "srk.notice.missing_credentials.title": "Identifiants manquants",
        "srk.notice.file_read_failed.title": "Échec de lecture du fichier",
        "srk.notice.ota_source_updated.title": "Source de mise à jour modifiée",
        "srk.notice.invalid_url.title": "URL invalide",
        "srk.notice.invalid_url.message": "Veuillez saisir un lien HTTP/HTTPS valide vers un fichier .ipa."
    ]

    // MARK: - 7. Korean (ko)
    public static let korean: [String: String] = [
        "srk.nav.title": "서명 및 자동 갱신",
        "srk.common.ok": "확인",
        "srk.common.done": "완료",
        "srk.common.close": "닫기",
        "srk.common.cancel": "취소",
        "srk.common.save": "저장",
        "srk.common.continue_danger": "위험을 이해하며 계속 변경",
        "srk.common.reset_default": "기본 소스로 복원",
        "srk.common.download_install": "다운로드 및 재서명 설치",
        "srk.common.present": "포함됨",
        "srk.common.none": "없음",
        "srk.common.recommended": "권장",

        "srk.status.header": "현재 상태",
        "srk.status.profile_validity": "프로파일 유효기간",
        "srk.status.refresh_now": "지금 갱신",
        "srk.status.processing": "처리 중…",
        "srk.status.setup_required": "설정 필요",
        "srk.status.ready": "준비 완료",
        "srk.status.expired": "만료됨",
        "srk.status.no_profile": "내장 프로파일 없음",

        "srk.nav.section_header": "구성 및 진단",
        "srk.nav.required.title": "필수 설정",
        "srk.nav.health.title": "상태 점검 (Health Check)",
        "srk.nav.optional.title": "선택 작업",
        "srk.nav.optional.subtitle": "자동화 및 업데이트",

        "srk.about.section_header": "컴포넌트 정보",
        "srk.about.language_picker": "컴포넌트 언어",
        "srk.about.follow_host": "호스트 앱 / 시스템 따르기",

        "srk.required.section_header": "필수 설정 (3단계 완료 후 무제한 갱신)",
        "srk.required.step1.title": "1. 기기 페어링 파일 가져오기",
        "srk.required.step1.done": "완료됨",
        "srk.required.step1.pending": "미완료 · 탭하여 가져오기",
        "srk.required.step2.title": "2. Apple 개발자 계정 로그인",
        "srk.required.step2.done": "인증됨",
        "srk.required.step2.pending": "미완료 · 탭하여 로그인",
        "srk.required.step3.title": "3. 초기 로컬 서명 전환",
        "srk.required.step3.sub_done": "기기 키체인 인증서 활성화됨",
        "srk.required.step3.sub_pending": "미서명 IPA를 선택하여 초기 덮어쓰기 설치 완료",
        "srk.required.step3.badge_pending": "대기 중",
        "srk.required.tunnel.title": "루프백 터널",
        "srk.required.tunnel.connected": "연결됨",
        "srk.required.tunnel.disconnected": "연결 안 됨 · 탭하여 열기",

        "srk.health.run_button": "전체 상태 점검 실행",
        "srk.health.all_healthy": "모두 정상",
        "srk.health.needs_attention": "확인 필요",
        "srk.health.footer": "페어링 파일 무결성, 10.7.0.1 루프백 인터페이스, Anisette V3 지연 시간 및 Apple 개발자 세션을 점검합니다.",
        "srk.health.item.pairing.title": "기기 페어링 파일",
        "srk.health.item.pairing.missing": "유효한 .mobiledevicepairing / .plist 파일이 없습니다",
        "srk.health.item.tunnel.connected": "10.7.0.1 가상 인터페이스 연결됨",
        "srk.health.item.tunnel.disconnected": "10.7.0.1 터널 미감지 (갱신 전 VPN 켜기 필요)",
        "srk.health.item.anisette.invalid": "잘못된 Anisette URL 형식",
        "srk.health.item.account.title": "Apple 개발자 자격 증명",
        "srk.health.item.account.missing": "Apple ID 로그인이 아직 완료되지 않았습니다",
        "srk.health.item.profile.taken_over": "로컬 인증서 전환됨",
        "srk.health.item.profile.pending": "초기 IPA 전환 대기 중",

        "srk.optional.shortcut.header": "단축어 및 자동화",
        "srk.optional.shortcut.configure": "백그라운드 자동 갱신 단축어 설정",
        "srk.optional.shortcut.footer": "내장 단축어 동작은 앱을 열지 않고 백그라운드에서 조용히 실행됩니다.",
        "srk.optional.env.header": "환경 설정",
        "srk.optional.env.preferred_vpn": "선호 터널 앱",
        "srk.optional.update.header": "업데이트 및 재서명",
        "srk.optional.update.check_ota": "클라우드 업데이트 확인 및 자체 서명 업그레이드",
        "srk.optional.update.configure_source": "클라우드 업데이트 저장소",
        "srk.optional.update.danger_title": "보안 경고: 업데이트 소스를 변경하시겠습니까?",
        "srk.optional.update.danger_message": "클라우드 업데이트 저장소를 변경하면 비공식 IPA가 설치되어 계정 및 데이터 보안 위험이 발생할 수 있습니다. 대상 저장소를 완전히 신뢰하는 경우에만 계속하세요.",
        "srk.optional.update.input_title": "GitHub 업데이트 저장소 설정",
        "srk.optional.update.input_message": "'owner/repo' 형식으로 저장소를 입력하세요 (예: Cc-Cece/PicHarbor-iOS):",
        "srk.optional.update.direct_ipa_button": "IPA 직접 링크 입력하여 다운로드 및 설치",
        "srk.optional.update.direct_ipa_title": "IPA 직접 다운로드 링크",
        "srk.optional.update.direct_ipa_message": "미서명 .ipa 파일의 http:// 또는 https:// 직접 링크를 입력하세요:",
        "srk.optional.update.local_ipa_button": "로컬 IPA 선택 및 재서명 설치",

        "srk.pairing.sheet_title": "기기 페어링 파일",
        "srk.pairing.details_section": "페어링 파일 상세 정보",
        "srk.pairing.export_button": "현재 페어링 파일 내보내기 / 백업",
        "srk.pairing.reimport_button": "다른 페어링 파일 다시 가져오기",

        "srk.account.sheet_title": "Apple ID 로그인 및 인증",
        "srk.account.session_section": "인증된 개발자 세션",
        "srk.account.sign_out_button": "로그아웃 및 자격 증명 삭제",
        "srk.account.login_section": "Apple Developer 로그인",
        "srk.account.login_footer": "Anisette V3에 연결하여 개발자 Team ID 및 세션 토큰을 가져와 기기 키체인에 암호화하여 저장합니다.",
        "srk.account.password": "암호",
        "srk.account.toggle_2fa": "이중 인증(2FA) 코드 입력 필요",
        "srk.account.2fa_placeholder": "6자리 이중 인증 코드",
        "srk.account.preset_server": "추천 노드",
        "srk.account.auto_anisette": "가장 빠른 Anisette 노드 자동 선택",
        "srk.account.authenticating": "Apple 인증 서비스 연결 중…",
        "srk.account.submit_button": "로그인 및 개발자 자격 증명 저장",

        "srk.shortcut.guide_section": "백그라운드 자동화 설정 단계",
        "srk.shortcut.step1": "1. 시스템 '단축어' 앱을 열고 '자동화' 탭에서 특정 시간(예: 매일 04:00, '즉시 실행' 선택)을 생성합니다.",
        "srk.shortcut.step2": "2. 동작 추가: LocalDevVPN 연결 후 '2초 대기'를 추가합니다.",
        "srk.shortcut.step3": "3. 동작 추가: 이 앱을 검색하여 'Refresh App Provisioning Profile'을 선택합니다 (백그라운드 무음 실행).",
        "srk.shortcut.step4": "4. 동작 추가: 5초 대기 후 LocalDevVPN 연결을 해제합니다.",
        "srk.shortcut.get_icloud_button": "사전 구성된 단축어 받기 (iCloud)",
        "srk.shortcut.view_docs_button": "GitHub에서 단축어 설정 문서 보기 (#Shortcuts)",
        "srk.shortcut.open_app_button": "시스템 '단축어' 앱 열기",

        "srk.about.sheet_title": "SelfRefreshKit 정보",
        "srk.about.info_section": "컴포넌트 정보",
        "srk.about.engine_muxer": "통신 엔진",
        "srk.about.engine_signing": "서명 엔진",
        "srk.about.preferred_tunnel": "선호 터널",
        "srk.about.license": "오픈소스 라이선스",
        "srk.about.repository": "GitHub 저장소",
        "srk.about.summary": "iOS 앱 내장형 경량 프로파일 자동 갱신 및 클라우드 OTA 컴포넌트입니다. LocalDevVPN 사용을 권장하며 StosVPN 및 WireGuard와 호환됩니다.",

        "srk.intent.refresh.title": "앱 프로비저닝 프로파일 갱신",
        "srk.intent.refresh.description": "앱을 열지 않고 LocalDevVPN을 통해 백그라운드에서 7일 프로비저닝 프로파일을 조용히 갱신합니다.",
        "srk.intent.refresh.result": "프로비저닝 프로파일이 7일 연장되었습니다.",

        "srk.notice.pairing_imported.title": "페어링 파일 가져오기 성공",
        "srk.notice.pairing_failed.title": "페어링 파일 가져오기 실패",
        "srk.notice.auth_success.title": "Apple ID 인증 성공",
        "srk.notice.auth_failed.title": "Apple ID 인증 실패",
        "srk.notice.signed_out.title": "로그아웃됨",
        "srk.notice.signed_out.message": "기기에 저장된 Apple ID 자격 증명이 삭제되었습니다.",
        "srk.notice.fastest_server.title": "가장 빠른 노드로 전환됨",
        "srk.notice.refresh_success.title": "갱신 성공",
        "srk.notice.refresh_success.message": "프로비저닝 프로파일이 7일 연장되었습니다.",
        "srk.notice.refresh_failed.title": "갱신 실패",
        "srk.notice.takeover_success.title": "서명 전환 완료",
        "srk.notice.takeover_success.message": "로컬 서명 전환 및 설치가 완료되었습니다. 이후 갱신은 1초만 소요됩니다.",
        "srk.notice.tunnel_connected.title": "루프백 터널 연결됨",
        "srk.notice.tunnel_disconnected.title": "루프백 터널 연결 안 됨",
        "srk.notice.missing_credentials.title": "계정 자격 증명 누락",
        "srk.notice.file_read_failed.title": "파일 읽기 실패",
        "srk.notice.ota_source_updated.title": "클라우드 업데이트 소스 변경됨",
        "srk.notice.invalid_url.title": "잘못된 URL",
        "srk.notice.invalid_url.message": "http:// 또는 https://로 시작하는 유효한 IPA 다운로드 링크를 입력하세요."
    ]
}
