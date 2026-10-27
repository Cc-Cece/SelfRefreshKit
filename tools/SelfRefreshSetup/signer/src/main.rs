use std::fs::{self, File};
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::SystemTime;

use apple_codesign_quick::ProvisioningProfile;
use isideload::SideloadError;
use isideload::anisette::AnisetteProvider;
use isideload::anisette::remote_v3::RemoteV3AnisetteProvider;
use isideload::auth::apple_account::{
    AppleAccount, TwoFactorCallbackParams, TwoFactorCallbackResponse,
};
use isideload::dev::app_ids::{AppIdsApi, Profile};
use isideload::dev::certificates::DevelopmentCertificate;
use isideload::dev::developer_session::DeveloperSession;
use isideload::dev::devices::DevicesApi;
use isideload::dev::teams::{DeveloperTeam, TeamsApi};
use isideload::sideload::application::{Application, SpecialApp};
use isideload::sideload::builder::{ExtensionsBehavior, MaxCertsBehavior};
use isideload::sideload::cert_identity::CertificateIdentity;
use isideload::sideload::sign;
use isideload::util::fs_storage::FsStorage;
use isideload::util::storage::InMemoryStorage;
use plist::{Dictionary, Value};
use rootcause::prelude::*;
use serde::Deserialize;
use serde_json::json;
use zip::CompressionMethod;
use zip::write::SimpleFileOptions;
use zip::ZipWriter;

mod text;
use text::{t, tf};

const SERVERS: &[&str] = &[
    "https://ani.sidestore.io",
    "https://ani.sidestore.app",
    "https://new.ani.sidestore.io",
    "https://ani.jkcoxson.com",
    "https://mac-ani.jkcoxson.com",
];

static SECRET: Mutex<String> = Mutex::new(String::new());

#[derive(Deserialize)]
struct SignRequest {
    apple_id: String,
    password: String,
    ipa: String,
    udid: String,
    #[serde(default)]
    device_name: String,
    #[serde(default)]
    anisette: String,
    #[serde(default)]
    out: String,
}

#[derive(Deserialize)]
struct CodeReply {
    #[serde(default)]
    code: String,
    #[serde(default)]
    abort: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum FailureClass {
    AuthStop,
    AnisetteRetry,
    ServerRetry,
}

#[tokio::main]
async fn main() {
    init_tracing();
    prepare_runtime();
    let code = match dispatch().await {
        Ok(()) => 0,
        Err(err) => {
            emit_json(&json!({
                "event": "error",
                "message": public_error(&err),
            }));
            1
        }
    };
    std::process::exit(code);
}

fn init_tracing() {
    let _ = tracing_subscriber::fmt()
        .with_writer(io::stderr)
        .with_max_level(tracing::Level::WARN)
        .with_ansi(false)
        .with_target(false)
        .try_init();
}

fn prepare_runtime() {
    let _ = rustls::crypto::ring::default_provider().install_default();
    if let Err(err) = isideload::init() {
        emit_log(&tf("initReportFailed", &[("error", &public_error(&err))]));
    }
}

async fn dispatch() -> Result<(), Report> {
    let command = std::env::args().nth(1);
    match command.as_deref() {
        Some("probe") => probe().await,
        Some("sign") => sign_command().await,
        _ => bail!("{}", t("usage")),
    }
}

async fn probe() -> Result<(), Report> {
    let mut accepted = 0u32;
    for url in server_list("") {
        match fetch_client_info(&url).await {
            Ok(info) => {
                let ok = accepted_client_info(&info.client_info, &info.user_agent);
                if ok {
                    accepted += 1;
                }
                emit_json(&json!({
                    "event": "server",
                    "url": url,
                    "accepted": ok,
                    "client_info": info.client_info,
                    "user_agent": info.user_agent,
                }));
            }
            Err(err) => {
                emit_json(&json!({
                    "event": "server",
                    "url": url,
                    "accepted": false,
                    "message": public_error(&err),
                }));
            }
        }
    }
    if accepted == 0 {
        bail!("{}", t("noAnisette"));
    }
    emit_json(&json!({"event": "ok", "accepted": accepted}));
    Ok(())
}

async fn sign_command() -> Result<(), Report> {
    let request = read_request()?;
    if let Ok(mut secret) = SECRET.lock() {
        *secret = request.password.clone();
    }
    let apple_id = request.apple_id.trim().to_string();
    let password = request.password;
    let udid = request.udid.trim().to_string();
    let ipa = PathBuf::from(request.ipa.trim());
    if apple_id.is_empty() || password.is_empty() {
        bail!("{}", t("needAppleId"));
    }
    if udid.is_empty() {
        bail!("{}", t("needUdid"));
    }
    if !ipa.is_file() {
        bail!("{}", t("ipaMissing"));
    }
    let anisette = request.anisette.trim();
    if !anisette.is_empty() && !acceptable_anisette(anisette) {
        bail!("{}", t("anisetteScheme"));
    }
    let device_name = clean_device_name(&request.device_name);
    let out = output_path(&request.out, &ipa);

    let storage_dir = signer_dir();
    fs::create_dir_all(&storage_dir).context(t("storageDirFailed"))?;

    emit_log(&t("loggingIn"));
    let mut account = login(&apple_id, &password, &server_list(anisette), &storage_dir).await?;
    let mut session = DeveloperSession::from_account(&mut account)
        .await
        .context(t("portalFailed"))?;
    let teams = session.list_teams().await.context(t("teamsFailed"))?;
    let team = teams
        .into_iter()
        .next()
        .ok_or_else(|| report!("{}", t("noTeam")))?;
    let team_name = team.name.clone().unwrap_or_else(|| team.team_id.clone());
    emit_log(&tf("usingTeam", &[("name", &team_name), ("id", &team.team_id)]));

    session
        .ensure_device_registered(&team, &device_name, &udid, None)
        .await
        .context(t("registerDeviceFailed"))?;
    emit_log(&t("deviceRegistered"));

    let storage = FsStorage::new(storage_dir);
    let revoked_once = Arc::new(AtomicBool::new(false));
    let identity = CertificateIdentity::retrieve(
        "SelfRefreshSetup",
        &apple_id,
        &mut session,
        &team,
        &storage,
        &MaxCertsBehavior::Prompt(move |certs: Vec<DevelopmentCertificate>| {
            let revoked_once = revoked_once.clone();
            async move { revoke_oldest_once(certs, revoked_once).await }
        }),
    )
    .await
    .context(t("certFailed"))?;
    emit_log(&t("gotCert"));

    let mut app = Application::new(ipa).context(t("openIpaFailed"))?;
    let original = app.main_bundle_id().context(t("noBundleInIpa"))?;
    let chosen = choose_bundle_id(&mut session, &team, &original).await?;
    if chosen != original {
        app.update_bundle_id(&original, &chosen)
            .context(t("changeBundleFailed"))?;
        emit_log(&tf(
            "bundleChanged",
            &[("chosen", chosen.as_str()), ("original", original.as_str())],
        ));
    }

    app.bundle.app_info.insert(
        "UIFileSharingEnabled".to_string(),
        Value::Boolean(true),
    );
    app.bundle.app_info.insert(
        "LSSupportsOpeningDocumentsInPlace".to_string(),
        Value::Boolean(true),
    );

    let app_ids = match app
        .register_app_ids(&ExtensionsBehavior::RegisterAll, &mut session, &team)
        .await
    {
        Ok(ids) => ids,
        Err(err) if is_app_id_limit_report(&err) => bail!("{}", t("appIdLimit")),
        Err(err) => return Err(err.context(t("extensionAppIdFailed")).into()),
    };
    let main_app_id = app_ids
        .iter()
        .find(|id| id.identifier == chosen)
        .cloned()
        .ok_or_else(|| report!("{}", tf("mainAppIdMissing", &[("id", chosen.as_str())])))?;

    emit_log(&t("downloadingProfile"));
    let main_profile = session
        .download_team_provisioning_profile(&team, &main_app_id, None)
        .await
        .context(t("profileFailed"))?;
    let mut profiles = extension_profiles(&mut session, &team, &app_ids, &chosen).await?;

    app.bundle.write_info().context(t("writeInfoFailed"))?;
    for ext in app.bundle.app_extensions_mut() {
        ext.write_info().context(t("writeExtInfoFailed"))?;
    }
    for framework in app.bundle.frameworks_mut() {
        framework
            .write_info()
            .context(t("writeFrameworkInfoFailed"))?;
    }

    emit_log(&t("signing"));
    let app_dir = app.bundle.bundle_dir.clone();
    let signed = sign::sign(
        &mut app,
        &identity,
        &main_profile,
        &mut profiles,
        &None::<SpecialApp>,
        &team,
        Some(no_progress),
    )
    .await
    .context(t("signFailed"));
    if let Err(err) = signed {
        cleanup_extract(&app_dir);
        return Err(err.into());
    }
    if let Err(err) = verify_signed_bundle(&app_dir, &chosen) {
        cleanup_extract(&app_dir);
        return Err(err);
    }
    emit_log(&t("packaging"));
    let zipped = zip_app(&app_dir, &out);
    cleanup_extract(&app_dir);
    zipped.context(t("packageFailed"))?;

    emit_json(&json!({
        "event": "ok",
        "ipa": out.display().to_string(),
        "bundle_id": chosen,
        "original_bundle_id": original,
        "file_sharing": true,
    }));
    Ok(())
}

async fn no_progress(_fraction: f32) {}

fn read_request() -> Result<SignRequest, Report> {
    let mut line = String::new();
    io::stdin()
        .read_line(&mut line)
        .context(t("readRequestFailed"))?;
    if line.trim().is_empty() {
        bail!("{}", t("emptyRequest"));
    }
    Ok(serde_json::from_str(&line).context(t("requestNotJson"))?)
}

fn server_list(preferred: &str) -> Vec<String> {
    let mut urls = Vec::new();
    if !preferred.is_empty() {
        urls.push(preferred.trim_end_matches('/').to_string());
    }
    for url in SERVERS {
        let trimmed = url.trim_end_matches('/').to_string();
        if !urls.iter().any(|have| have == &trimmed) {
            urls.push(trimmed);
        }
    }
    urls
}

fn acceptable_anisette(url: &str) -> bool {
    let lower = url.to_ascii_lowercase();
    lower.starts_with("https://") || lower.starts_with("http://")
}

fn accepted_client_info(client_info: &str, user_agent: &str) -> bool {
    let client = client_info.trim();
    let agent = user_agent.trim();
    if client.is_empty() || agent.is_empty() {
        return false;
    }
    let blob = format!("{client}\n{agent}").to_ascii_lowercase();
    !blob.contains("xcode") && !blob.contains("com.apple.dt.xcode")
}

fn select_existing(original: &str, team_id: &str, existing: &[String]) -> Option<String> {
    if existing.iter().any(|id| id == original) {
        return Some(original.to_string());
    }
    let scoped = format!("{original}.{team_id}");
    if existing.iter().any(|id| id == &scoped) {
        return Some(scoped);
    }
    None
}

async fn fetch_client_info(url: &str) -> Result<isideload::anisette::AnisetteClientInfo, Report> {
    let provider = RemoteV3AnisetteProvider::new(
        url,
        Box::new(InMemoryStorage::new()),
        "0".to_string(),
    )
    .context(t("anisetteConnectFailed"))?;
    Ok(provider
        .get_client_info()
        .await
        .context(t("anisetteInfoFailed"))?)
}

async fn login(
    email: &str,
    password: &str,
    urls: &[String],
    storage_dir: &Path,
) -> Result<AppleAccount, Report> {
    let mut last_error: Option<Report> = None;
    let mut saw_server = false;
    for url in urls {
        let info = match fetch_client_info(url).await {
            Ok(info) => info,
            Err(err) => {
                emit_log(&tf("serverNoResponse", &[("url", url.as_str())]));
                last_error = Some(err);
                continue;
            }
        };
        if !accepted_client_info(&info.client_info, &info.user_agent) {
            emit_log(&tf("serverIdentitySkipped", &[("url", url.as_str())]));
            continue;
        }
        saw_server = true;
        emit_log(&tf("usingAnisette", &[("url", url.as_str())]));
        for attempt in 0..2 {
            let asked = Arc::new(AtomicBool::new(false));
            match login_once(email, password, url, storage_dir, asked.clone()).await {
                Ok(account) => return Ok(account),
                Err(err) => {
                    if asked.load(Ordering::SeqCst) || failure_class(&err) == FailureClass::AuthStop
                    {
                        return Err(err.into());
                    }
                    let existed = state_exists(storage_dir);
                    if attempt == 0
                        && existed
                        && failure_class(&err) == FailureClass::AnisetteRetry
                    {
                        clear_state(storage_dir);
                        emit_log(&t("stateCleared"));
                        last_error = Some(err);
                        continue;
                    }
                    clear_state(storage_dir);
                    emit_log(&tf("serverLoginFailed", &[("url", url.as_str())]));
                    last_error = Some(err);
                    break;
                }
            }
        }
    }
    if !saw_server {
        bail!("{}", t("noAnisette"));
    }
    Err(last_error.unwrap_or_else(|| report!("{}", t("loginFailed"))))
}

async fn login_once(
    email: &str,
    password: &str,
    url: &str,
    storage_dir: &Path,
    asked: Arc<AtomicBool>,
) -> Result<AppleAccount, Report> {
    let sms_sent = Arc::new(AtomicBool::new(false));
    let unknown_sent = Arc::new(AtomicBool::new(false));
    let provider = RemoteV3AnisetteProvider::new(
        url,
        Box::new(FsStorage::new(storage_dir.to_path_buf())),
        "0".to_string(),
    )?;
    Ok(AppleAccount::builder(email)
        .anisette_provider(provider)
        .login(password, move |params: TwoFactorCallbackParams| {
            let asked = asked.clone();
            let sms_sent = sms_sent.clone();
            let unknown_sent = unknown_sent.clone();
            async move { on_two_factor(params, asked, sms_sent, unknown_sent).await }
        })
        .await
        .context(t("loginAppleFailed"))?)
}

async fn on_two_factor(
    params: TwoFactorCallbackParams,
    asked: Arc<AtomicBool>,
    sms_sent: Arc<AtomicBool>,
    unknown_sent: Arc<AtomicBool>,
) -> Result<TwoFactorCallbackResponse, Report> {
    asked.store(true, Ordering::SeqCst);
    if params.sms && !sms_sent.swap(true, Ordering::SeqCst) {
        emit_log(&t("smsToTrusted"));
        return Ok(TwoFactorCallbackResponse::SendToDevices);
    }
    if params.unknown {
        if !unknown_sent.swap(true, Ordering::SeqCst) {
            emit_log(&t("unknownToTrusted"));
            return Ok(TwoFactorCallbackResponse::SendToDevices);
        }
        bail!("{}", t("twoFactorUnclearStop"));
    }

    let mut message = if params.sms { t("smsCode") } else { t("trustedCode") };
    if let Some(err) = params.last_error.as_deref() {
        let err = err.replace(['\n', '\r'], " ");
        if !err.trim().is_empty() {
            message = tf("codeRejected", &[("message", &message), ("err", &err)]);
        }
    }
    emit_json(&json!({
        "event": "need_2fa",
        "channel": "trusted",
        "message": message,
    }));

    let line = tokio::task::spawn_blocking(|| {
        let mut line = String::new();
        io::stdin().read_line(&mut line)?;
        Ok::<String, io::Error>(line)
    })
    .await
    .context(t("waitCodeFailed"))?
    .context(t("readCodeFailed"))?;

    let reply: CodeReply = match serde_json::from_str(&line) {
        Ok(reply) => reply,
        Err(_) => return Ok(TwoFactorCallbackResponse::Abort),
    };
    let code = reply.code.trim();
    if reply.abort || code.is_empty() {
        return Ok(TwoFactorCallbackResponse::Abort);
    }
    Ok(TwoFactorCallbackResponse::SubmitCode(code.to_string()))
}

async fn revoke_oldest_once(
    certs: Vec<DevelopmentCertificate>,
    revoked_once: Arc<AtomicBool>,
) -> Result<Option<Vec<String>>, Report> {
    if revoked_once.swap(true, Ordering::SeqCst) {
        emit_log(&t("certLimitAlready"));
        return Ok(None);
    }
    let oldest = certs.into_iter().filter(|cert| cert.serial_number.is_some()).min_by_key(expiration_time);
    let Some(cert) = oldest else {
        emit_log(&t("certLimitNone"));
        return Ok(None);
    };
    let machine = cert.machine_name.unwrap_or_else(|| t("unknownDevice"));
    emit_log(&tf("certLimitRevoke", &[("machine", machine.as_str())]));
    Ok(cert.serial_number.map(|serial| vec![serial]))
}

fn expiration_time(cert: &DevelopmentCertificate) -> SystemTime {
    cert.expiration_date
        .map(SystemTime::from)
        .unwrap_or(SystemTime::UNIX_EPOCH)
}

async fn choose_bundle_id(
    session: &mut DeveloperSession,
    team: &DeveloperTeam,
    original: &str,
) -> Result<String, Report> {
    let listed = session
        .list_app_ids(team, None)
        .await
        .context(t("listAppIdsFailed"))?;
    let ids: Vec<String> = listed.app_ids.into_iter().map(|id| id.identifier).collect();
    if let Some(found) = select_existing(original, &team.team_id, &ids) {
        emit_log(&tf("reuseAppId", &[("id", found.as_str())]));
        return Ok(found);
    }
    match session
        .add_app_id(team, "SelfRefreshApp", original, None)
        .await
    {
        Ok(_) => {
            emit_log(&tf("registeredAppId", &[("id", original)]));
            Ok(original.to_string())
        }
        Err(err) => {
            if is_already_exists_report(&err) {
                emit_log(&tf("appIdExists", &[("id", original)]));
                return Ok(original.to_string());
            }
            if is_app_id_limit_report(&err) {
                bail!("{}", t("appIdLimit"));
            }
            let scoped = format!("{original}.{}", team.team_id);
            emit_log(&tf("tryScoped", &[("original", original), ("scoped", scoped.as_str())]));
            match session
                .add_app_id(team, "SelfRefreshApp", &scoped, None)
                .await
            {
                Ok(_) => {
                    emit_log(&tf("registeredAppId", &[("id", scoped.as_str())]));
                    Ok(scoped)
                }
                Err(err) => {
                    if is_already_exists_report(&err) {
                        return Ok(scoped);
                    }
                    if is_app_id_limit_report(&err) {
                        bail!("{}", t("appIdLimit"));
                    }
                    Err(err.context(t("registerAppIdFailed")).into())
                }
            }
        }
    }
}

async fn extension_profiles(
    session: &mut DeveloperSession,
    team: &DeveloperTeam,
    app_ids: &[isideload::dev::app_ids::AppId],
    main_id: &str,
) -> Result<Vec<(String, Profile, Dictionary)>, Report> {
    let mut profiles = Vec::new();
    for id in app_ids.iter().filter(|id| id.identifier != main_id) {
        let profile = session
            .download_team_provisioning_profile(team, id, None)
            .await
            .context(tf("downloadExtProfileFailed", &[("id", id.identifier.as_str())]))?;
        let parsed = ProvisioningProfile::parse(profile.encoded_profile.as_ref())
            .context(t("parseExtProfileFailed"))?;
        let entitlements = parsed.entitlements().clone();
        profiles.push((id.identifier.clone(), profile, entitlements));
    }
    Ok(profiles)
}

fn verify_signed_bundle(app_dir: &Path, bundle_id: &str) -> Result<(), Report> {
    if !app_dir.join("_CodeSignature").is_dir() {
        bail!("{}", t("noCodeSignature"));
    }
    if !app_dir.join("embedded.mobileprovision").is_file() {
        bail!("{}", t("noProvision"));
    }
    let info: Dictionary = plist::from_bytes(&fs::read(app_dir.join("Info.plist")).context(t("readSignedInfoFailed"))?)
        .context(t("parseSignedInfoFailed"))?;
    let written = info
        .get("CFBundleIdentifier")
        .and_then(Value::as_string)
        .unwrap_or("");
    if written != bundle_id {
        bail!("{}", tf("bundleMismatch", &[("written", written), ("bundle_id", bundle_id)]));
    }
    if !plist_bool(&info, "UIFileSharingEnabled") || !plist_bool(&info, "LSSupportsOpeningDocumentsInPlace") {
        bail!("{}", t("sharingNotOn"));
    }
    Ok(())
}

fn plist_bool(info: &Dictionary, key: &str) -> bool {
    matches!(info.get(key), Some(Value::Boolean(true)))
}

fn zip_app(app_dir: &Path, dest: &Path) -> Result<(), Report> {
    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent).context(t("outputDirFailed"))?;
    }
    let file = File::create(dest).context(t("writeIpaFailed"))?;
    let mut zip = ZipWriter::new(file);
    let app_name = app_dir
        .file_name()
        .ok_or_else(|| report!("{}", t("noAppName")))?
        .to_string_lossy();
    let executable = bundle_executable_name(app_dir);
    write_tree(&mut zip, app_dir, &format!("Payload/{app_name}"), app_dir, &executable)?;
    zip.finish().context(t("zipFinishFailed"))?;
    Ok(())
}

fn bundle_executable_name(app_dir: &Path) -> String {
    let Ok(bytes) = fs::read(app_dir.join("Info.plist")) else {
        return String::new();
    };
    let Ok(info) = plist::from_bytes::<Dictionary>(&bytes) else {
        return String::new();
    };
    info.get("CFBundleExecutable")
        .and_then(Value::as_string)
        .unwrap_or("")
        .to_string()
}

fn write_tree(
    zip: &mut ZipWriter<File>,
    dir: &Path,
    prefix: &str,
    app_root: &Path,
    executable: &str,
) -> Result<(), Report> {
    let dir_options = SimpleFileOptions::default().unix_permissions(0o755);
    zip.add_directory(format!("{prefix}/"), dir_options)
        .context(t("zipDirFailed"))?;
    let mut entries: Vec<_> = fs::read_dir(dir)
        .context(t("readSignedAppFailed"))?
        .collect::<Result<Vec<_>, _>>()
        .context(t("readSignedAppFailed"))?;
    entries.sort_by_key(|entry| entry.file_name());
    for entry in entries {
        let path = entry.path();
        let name = entry.file_name();
        let child = format!("{prefix}/{}", name.to_string_lossy());
        if path.is_dir() {
            write_tree(zip, &path, &child, app_root, executable)?;
            continue;
        }
        let mode = if executable_mode(&path, app_root, executable) {
            0o755
        } else {
            0o644
        };
        let options = SimpleFileOptions::default()
            .compression_method(CompressionMethod::Deflated)
            .unix_permissions(mode);
        zip.start_file(child, options).context(t("zipFileFailed"))?;
        let mut input = File::open(&path).context(t("readPackFileFailed"))?;
        io::copy(&mut input, zip).context(t("writeZipContentFailed"))?;
    }
    Ok(())
}

fn executable_mode(path: &Path, app_root: &Path, executable: &str) -> bool {
    let Some(name) = path.file_name().and_then(|name| name.to_str()) else {
        return false;
    };
    if name == "PkgInfo" {
        return false;
    }
    if !executable.is_empty() && name == executable && path.parent() == Some(app_root) {
        return true;
    }
    match path.extension().and_then(|ext| ext.to_str()) {
        None => true,
        Some("dylib") => true,
        _ => false,
    }
}

fn cleanup_extract(app_dir: &Path) {
    let Some(payload) = app_dir.parent() else {
        return;
    };
    if payload.file_name().and_then(|name| name.to_str()) != Some("Payload") {
        return;
    }
    let Some(root) = payload.parent() else {
        return;
    };
    let Some(name) = root.file_name().and_then(|name| name.to_str()) else {
        return;
    };
    if name.ends_with("_extracted") {
        let _ = fs::remove_dir_all(root);
    }
}

fn signer_dir() -> PathBuf {
    let base = std::env::var("LOCALAPPDATA")
        .unwrap_or_else(|_| std::env::temp_dir().to_string_lossy().into_owned());
    PathBuf::from(base).join("SelfRefreshSetup").join("signer")
}

fn output_path(requested: &str, ipa: &Path) -> PathBuf {
    let requested = requested.trim();
    if !requested.is_empty() {
        return PathBuf::from(requested);
    }
    let stem = ipa
        .file_stem()
        .and_then(|name| name.to_str())
        .unwrap_or("app");
    let base = std::env::var("LOCALAPPDATA")
        .unwrap_or_else(|_| std::env::temp_dir().to_string_lossy().into_owned());
    PathBuf::from(base)
        .join("SelfRefreshSetup")
        .join("signed")
        .join(format!("{stem}.signed.ipa"))
}

fn clean_device_name(name: &str) -> String {
    let cleaned: String = name
        .chars()
        .filter(|ch| !ch.is_control())
        .take(50)
        .collect();
    let trimmed = cleaned.trim();
    if trimmed.is_empty() {
        "iPhone".to_string()
    } else {
        trimmed.to_string()
    }
}

fn state_path(dir: &Path) -> PathBuf {
    dir.join("anisette_state")
}

fn state_exists(dir: &Path) -> bool {
    fs::metadata(state_path(dir))
        .map(|meta| meta.len() > 0)
        .unwrap_or(false)
}

fn clear_state(dir: &Path) {
    let _ = fs::remove_file(state_path(dir));
}

fn failure_class(report: &Report) -> FailureClass {
    let text = report_text(report);
    if is_anisette_mismatch(&text) {
        return FailureClass::AnisetteRetry;
    }
    let auth = report.iter_reports().any(|node| {
        node.downcast_current_context::<SideloadError>()
            .is_some_and(|err| matches!(err, SideloadError::AuthWithMessage(_, _)))
    });
    if auth || is_auth_text(&text) {
        FailureClass::AuthStop
    } else {
        FailureClass::ServerRetry
    }
}

fn is_anisette_mismatch(text: &str) -> bool {
    let lower = text.to_ascii_lowercase();
    lower.contains("-80045")
        || lower.contains("-45061")
        || lower.contains("503")
        || lower.contains("temporarily unavailable")
        || lower.contains("invalid response format")
}

fn is_auth_text(text: &str) -> bool {
    let lower = text.to_ascii_lowercase();
    lower.contains("password")
        || lower.contains("locked")
        || lower.contains("no 2fa")
        || lower.contains("verification code")
        || text.contains("验证码")
        || text.contains("驗證碼")
        || text.contains("確認コード")
}

fn is_app_id_limit_report(report: &Report) -> bool {
    let code = report.iter_reports().find_map(|node| {
        node.downcast_current_context::<SideloadError>().and_then(|err| match err {
            SideloadError::DeveloperError(code, _) => Some(*code),
            _ => None,
        })
    });
    code == Some(37) || is_app_id_limit(&report_text(report))
}

fn is_app_id_limit(text: &str) -> bool {
    let lower = text.to_ascii_lowercase();
    lower.contains("developer error 37")
        || lower.contains("not enough available app id")
        || (lower.contains("maximum") && lower.contains("app id"))
}

fn is_already_exists_report(report: &Report) -> bool {
    if is_app_id_limit_report(report) {
        return false;
    }
    let lower = report_text(report).to_ascii_lowercase();
    lower.contains("already exists")
        || lower.contains("already registered")
        || lower.contains("duplicate")
}

fn report_text(report: &Report) -> String {
    format!("{report}\n{report:?}")
}

fn already_explained(text: &str) -> bool {
    [t("appIdLimit"), t("noCodeReceived"), t("twoFactorUnclearStop")]
        .iter()
        .any(|item| text.contains(item.as_str()))
}

fn public_error(report: &Report) -> String {
    let mut text = format!("{report}");
    if text.trim().is_empty() {
        text = format!("{report:?}");
    }
    text = redact_secret(text);
    let lower = text.to_ascii_lowercase();
    let prefix = if already_explained(&text) {
        None
    } else if is_app_id_limit(&text) {
        Some(t("appIdLimit"))
    } else if lower.contains("7460") || lower.contains("maximum number of certificates") {
        Some(t("certLimitPrefix"))
    } else if lower.contains("no 2fa") || lower.contains("abort") {
        Some(t("noCodeReceived"))
    } else if is_anisette_mismatch(&text) {
        Some(t("anisetteRejected"))
    } else {
        None
    };
    let mut combined = match prefix {
        Some(prefix) if !text.contains(prefix.as_str()) => format!("{prefix}\n{text}"),
        _ => text,
    };
    if combined.chars().count() > 1800 {
        combined = combined.chars().take(1800).collect();
    }
    combined
}

fn redact_secret(text: String) -> String {
    let secret = SECRET.lock().ok().map(|guard| guard.clone()).unwrap_or_default();
    if secret.is_empty() {
        text
    } else {
        text.replace(&secret, "******")
    }
}

fn emit_log(message: &str) {
    emit_json(&json!({"event": "log", "message": message}));
}

fn emit_json(value: &serde_json::Value) {
    let _ = writeln!(io::stdout(), "{value}");
    let _ = io::stdout().flush();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn select_existing_prefers_original() {
        let existing = vec![
            "app.example".to_string(),
            "app.example.TEAM".to_string(),
        ];
        assert_eq!(
            select_existing("app.example", "TEAM", &existing).as_deref(),
            Some("app.example")
        );
    }

    #[test]
    fn select_existing_uses_scoped_when_original_is_missing() {
        let existing = vec!["app.example.TEAM".to_string()];
        assert_eq!(
            select_existing("app.example", "TEAM", &existing).as_deref(),
            Some("app.example.TEAM")
        );
    }

    #[test]
    fn select_existing_returns_none_when_both_missing() {
        let existing = vec!["other.app".to_string()];
        assert_eq!(select_existing("app.example", "TEAM", &existing), None);
    }

    #[test]
    fn accepts_akd_identity() {
        assert!(accepted_client_info(
            "<MacBookPro13,2> <Mac OS X;13.1;22C65> <com.apple.AuthKit/1 (com.apple.akd/1.0)>",
            "akd/1.0 CFNetwork/808.1.4"
        ));
    }

    #[test]
    fn rejects_empty_or_xcode_identity() {
        assert!(!accepted_client_info("", "akd/1.0"));
        assert!(!accepted_client_info("akd", "  "));
        assert!(!accepted_client_info(
            "<Mac> <com.apple.dt.Xcode/1>",
            "akd/1.0"
        ));
        assert!(!accepted_client_info("Xcode", "akd/1.0 CFNetwork"));
        assert!(!accepted_client_info("akd", "XCODE/1.0"));
    }

    #[test]
    fn classifies_identity_mismatch_before_password_errors() {
        let mismatch: Report = report!(SideloadError::AuthWithMessage(-80045, "no".to_string())).into();
        assert_eq!(failure_class(&mismatch), FailureClass::AnisetteRetry);
        let password: Report = report!(SideloadError::AuthWithMessage(-22406, "bad password".to_string())).into();
        assert_eq!(failure_class(&password), FailureClass::AuthStop);
    }

    #[test]
    fn app_id_limit_is_code_37_and_not_an_existing_id() {
        let limit: Report = report!(SideloadError::DeveloperError(37, "maximum App ID".to_string())).into();
        assert!(is_app_id_limit_report(&limit));
        assert!(!is_already_exists_report(&limit));
        let exists: Report = report!(SideloadError::DeveloperError(9, "already exists".to_string())).into();
        assert!(is_already_exists_report(&exists));
        assert!(!is_app_id_limit_report(&exists));
    }
}
