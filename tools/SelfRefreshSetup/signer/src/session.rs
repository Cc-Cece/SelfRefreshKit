use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};

use plist::Value;
use rootcause::prelude::*;
use sha2::{Digest, Sha256};

use crate::text::t;

const MAGIC: &[u8] = b"SRKS1";
const ENTROPY: &[u8] = b"SelfRefreshSetup.session.v1";
const UI_FORBIDDEN: u32 = 0x1;

pub struct SessionRecord {
    pub apple_id: String,
    pub server: String,
    pub state_sha256: String,
    pub spd: plist::Dictionary,
}

pub fn canon_server(url: &str) -> String {
    url.trim().trim_end_matches('/').to_string()
}

pub fn ordered_servers(preferred: &str, remembered: Option<&str>, builtins: &[&str]) -> Vec<String> {
    let mut urls = Vec::new();
    push_unique(&mut urls, preferred);
    if let Some(saved) = remembered {
        push_unique(&mut urls, saved);
    }
    for url in builtins {
        push_unique(&mut urls, url);
    }
    urls
}

fn push_unique(urls: &mut Vec<String>, raw: &str) {
    let trimmed = canon_server(raw);
    if trimmed.is_empty() || urls.iter().any(|have| have == &trimmed) {
        return;
    }
    urls.push(trimmed);
}

pub fn should_clear_anisette(attempt: u32, state_existed: bool, mismatch: bool) -> bool {
    attempt == 0 && state_existed && mismatch
}

pub fn session_matches_state(saved_hash: &str, current_hash: Option<&str>) -> bool {
    match current_hash {
        Some(current) if !saved_hash.is_empty() => saved_hash.eq_ignore_ascii_case(current),
        _ => false,
    }
}

pub fn is_transport_error(text: &str) -> bool {
    let lower = text.to_ascii_lowercase();
    [
        "timed out",
        "timeout",
        "dns",
        "connection refused",
        "connection reset",
        "network is unreachable",
        "failed to connect",
        "error trying to connect",
        "could not resolve",
        "temporarily unavailable",
    ]
    .iter()
    .any(|needle| lower.contains(needle))
}

pub fn encode_session(record: &SessionRecord) -> Result<Vec<u8>, Report> {
    let mut spd_bytes = Vec::new();
    plist::to_writer_binary(&mut spd_bytes, &Value::Dictionary(record.spd.clone()))
        .context(t("sessionSaveFailed"))?;
    let mut out = Vec::new();
    out.extend_from_slice(MAGIC);
    write_blob(&mut out, record.apple_id.as_bytes());
    write_blob(&mut out, record.server.as_bytes());
    write_blob(&mut out, record.state_sha256.as_bytes());
    write_blob(&mut out, &spd_bytes);
    Ok(out)
}

pub fn decode_session(bytes: &[u8]) -> Result<SessionRecord, Report> {
    if bytes.len() < MAGIC.len() || &bytes[..MAGIC.len()] != MAGIC {
        bail!("{}", t("sessionSaveFailed"));
    }
    let mut rest = &bytes[MAGIC.len()..];
    let apple_id = String::from_utf8(read_blob(&mut rest)?).context(t("sessionSaveFailed"))?;
    let server = String::from_utf8(read_blob(&mut rest)?).context(t("sessionSaveFailed"))?;
    let state_sha256 = String::from_utf8(read_blob(&mut rest)?).context(t("sessionSaveFailed"))?;
    let spd_bytes = read_blob(&mut rest)?;
    if !rest.is_empty() {
        bail!("{}", t("sessionSaveFailed"));
    }
    let value: Value = plist::from_bytes(&spd_bytes).context(t("sessionSaveFailed"))?;
    let Value::Dictionary(spd) = value else {
        bail!("{}", t("sessionSaveFailed"));
    };
    Ok(SessionRecord {
        apple_id,
        server,
        state_sha256,
        spd,
    })
}

fn write_blob(out: &mut Vec<u8>, bytes: &[u8]) {
    let len = u32::try_from(bytes.len()).unwrap_or(u32::MAX);
    out.extend_from_slice(&len.to_le_bytes());
    out.extend_from_slice(&bytes[..len as usize]);
}

fn read_blob(input: &mut &[u8]) -> Result<Vec<u8>, Report> {
    if input.len() < 4 {
        bail!("{}", t("sessionSaveFailed"));
    }
    let mut len_bytes = [0u8; 4];
    len_bytes.copy_from_slice(&input[..4]);
    *input = &input[4..];
    let len = u32::from_le_bytes(len_bytes) as usize;
    if input.len() < len {
        bail!("{}", t("sessionSaveFailed"));
    }
    let blob = input[..len].to_vec();
    *input = &input[len..];
    Ok(blob)
}

pub fn state_sha256(dir: &Path) -> Option<String> {
    let path = dir.join("anisette_state");
    let bytes = fs::read(path).ok()?;
    if bytes.is_empty() {
        return None;
    }
    Some(hex_sha256(&bytes))
}

pub fn hex_sha256(bytes: &[u8]) -> String {
    let digest = Sha256::digest(bytes);
    digest.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn sessions_dir(dir: &Path) -> PathBuf {
    dir.join("sessions")
}

fn session_path(dir: &Path, apple_id: &str) -> PathBuf {
    sessions_dir(dir).join(format!("{}.bin", hex_sha256(apple_id.trim().to_ascii_lowercase().as_bytes())))
}

pub fn remembered_server_path(dir: &Path) -> PathBuf {
    dir.join("last_anisette.txt")
}

pub fn read_remembered_server(dir: &Path) -> Option<String> {
    let text = fs::read_to_string(remembered_server_path(dir)).ok()?;
    let server = canon_server(&text);
    if server.is_empty() {
        None
    } else {
        Some(server)
    }
}

pub fn write_remembered_server(dir: &Path, server: &str) -> Result<(), Report> {
    let server = canon_server(server);
    if server.is_empty() {
        return Ok(());
    }
    fs::create_dir_all(dir).context(t("storageDirFailed"))?;
    fs::write(remembered_server_path(dir), server).context(t("sessionSaveFailed"))?;
    Ok(())
}

pub fn save_session(dir: &Path, record: &SessionRecord) -> Result<(), Report> {
    let plain = encode_session(record)?;
    let protected = protect(&plain).context(t("sessionSaveFailed"))?;
    let path = session_path(dir, &record.apple_id);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).context(t("storageDirFailed"))?;
    }
    let tmp = path.with_extension("bin.tmp");
    {
        let mut file = File::create(&tmp).context(t("sessionSaveFailed"))?;
        file.write_all(&protected).context(t("sessionSaveFailed"))?;
        file.sync_all().ok();
    }
    fs::rename(&tmp, &path).context(t("sessionSaveFailed"))?;
    Ok(())
}

pub fn load_session(dir: &Path, apple_id: &str) -> Result<Option<SessionRecord>, Report> {
    let path = session_path(dir, apple_id);
    let protected = match fs::read(&path) {
        Ok(bytes) if !bytes.is_empty() => bytes,
        _ => return Ok(None),
    };
    let plain = match unprotect(&protected) {
        Ok(bytes) => bytes,
        Err(_) => return Ok(None),
    };
    let record = match decode_session(&plain) {
        Ok(record) => record,
        Err(_) => return Ok(None),
    };
    if !record.apple_id.eq_ignore_ascii_case(apple_id.trim()) {
        return Ok(None);
    }
    Ok(Some(record))
}

pub fn discard_sessions(dir: &Path) {
    let _ = fs::remove_dir_all(sessions_dir(dir));
}

#[cfg(windows)]
fn protect(plain: &[u8]) -> Result<Vec<u8>, Report> {
    crypt(plain, true)
}

#[cfg(windows)]
fn unprotect(protected: &[u8]) -> Result<Vec<u8>, Report> {
    crypt(protected, false)
}

#[cfg(not(windows))]
fn protect(_plain: &[u8]) -> Result<Vec<u8>, Report> {
    bail!("{}", t("sessionSaveFailed"))
}

#[cfg(not(windows))]
fn unprotect(_protected: &[u8]) -> Result<Vec<u8>, Report> {
    bail!("{}", t("sessionSaveFailed"))
}

#[cfg(windows)]
fn crypt(input: &[u8], protect_data: bool) -> Result<Vec<u8>, Report> {
    let mut data_in = CryptDataBlob {
        cb_data: u32::try_from(input.len()).unwrap_or(u32::MAX),
        pb_data: input.as_ptr() as *mut u8,
    };
    let mut entropy = CryptDataBlob {
        cb_data: ENTROPY.len() as u32,
        pb_data: ENTROPY.as_ptr() as *mut u8,
    };
    let mut data_out = CryptDataBlob {
        cb_data: 0,
        pb_data: std::ptr::null_mut(),
    };
    let ok = unsafe {
        if protect_data {
            CryptProtectData(
                &mut data_in,
                std::ptr::null(),
                &mut entropy,
                std::ptr::null_mut(),
                std::ptr::null_mut(),
                UI_FORBIDDEN,
                &mut data_out,
            )
        } else {
            CryptUnprotectData(
                &mut data_in,
                std::ptr::null_mut(),
                &mut entropy,
                std::ptr::null_mut(),
                std::ptr::null_mut(),
                UI_FORBIDDEN,
                &mut data_out,
            )
        }
    };
    if ok == 0 || data_out.pb_data.is_null() {
        bail!("{}", t("sessionSaveFailed"));
    }
    let bytes = unsafe { std::slice::from_raw_parts(data_out.pb_data, data_out.cb_data as usize) }.to_vec();
    unsafe {
        LocalFree(data_out.pb_data as *mut core::ffi::c_void);
    }
    Ok(bytes)
}

#[cfg(windows)]
#[repr(C)]
struct CryptDataBlob {
    cb_data: u32,
    pb_data: *mut u8,
}

#[cfg(windows)]
#[link(name = "crypt32")]
unsafe extern "system" {
    fn CryptProtectData(
        data_in: *mut CryptDataBlob,
        description: *const u16,
        entropy: *mut CryptDataBlob,
        reserved: *mut core::ffi::c_void,
        prompt: *mut core::ffi::c_void,
        flags: u32,
        data_out: *mut CryptDataBlob,
    ) -> i32;
    fn CryptUnprotectData(
        data_in: *mut CryptDataBlob,
        description: *mut *mut u16,
        entropy: *mut CryptDataBlob,
        reserved: *mut core::ffi::c_void,
        prompt: *mut core::ffi::c_void,
        flags: u32,
        data_out: *mut CryptDataBlob,
    ) -> i32;
}

#[cfg(windows)]
#[link(name = "kernel32")]
unsafe extern "system" {
    fn LocalFree(memory: *mut core::ffi::c_void) -> *mut core::ffi::c_void;
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> SessionRecord {
        let mut spd = plist::Dictionary::new();
        spd.insert("adsid".to_string(), Value::String("ADS".to_string()));
        spd.insert("GsIdmsToken".to_string(), Value::String("token".to_string()));
        SessionRecord {
            apple_id: "Person@example.com".to_string(),
            server: "https://ani.example.test".to_string(),
            state_sha256: "abc".to_string(),
            spd,
        }
    }

    #[test]
    fn server_order_puts_typed_url_ahead_of_the_remembered_one() {
        let urls = ordered_servers(
            "https://typed.example/v1/",
            Some("https://saved.example"),
            &["https://saved.example", "https://builtin.example"],
        );
        assert_eq!(
            urls,
            vec![
                "https://typed.example/v1".to_string(),
                "https://saved.example".to_string(),
                "https://builtin.example".to_string(),
            ]
        );
    }

    #[test]
    fn empty_preference_uses_the_remembered_server_first() {
        let urls = ordered_servers("", Some("https://saved.example/"), &["https://builtin.example"]);
        assert_eq!(
            urls,
            vec![
                "https://saved.example".to_string(),
                "https://builtin.example".to_string(),
            ]
        );
    }

    #[test]
    fn anisette_state_is_cleared_only_for_a_mismatch_retry() {
        assert!(should_clear_anisette(0, true, true));
        assert!(!should_clear_anisette(0, true, false));
        assert!(!should_clear_anisette(1, true, true));
        assert!(!should_clear_anisette(0, false, true));
    }

    #[test]
    fn session_requires_the_same_anisette_machine() {
        assert!(session_matches_state("abc", Some("ABC")));
        assert!(!session_matches_state("abc", Some("def")));
        assert!(!session_matches_state("abc", None));
        assert!(!session_matches_state("", Some("abc")));
    }

    #[test]
    fn session_record_roundtrip() {
        let record = sample();
        let encoded = encode_session(&record).expect("encode");
        let decoded = decode_session(&encoded).expect("decode");
        assert_eq!(decoded.apple_id, record.apple_id);
        assert_eq!(decoded.server, record.server);
        assert_eq!(decoded.state_sha256, record.state_sha256);
        assert_eq!(decoded.spd.get("adsid").and_then(Value::as_string), Some("ADS"));
    }

    #[cfg(windows)]
    #[test]
    fn protected_session_roundtrip_uses_the_current_user() {
        let dir = std::env::temp_dir().join(format!("srk-session-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).expect("dir");
        let record = sample();
        save_session(&dir, &record).expect("save");
        let loaded = load_session(&dir, "person@example.com").expect("load").expect("present");
        assert_eq!(loaded.server, record.server);
        assert_eq!(loaded.spd.get("GsIdmsToken").and_then(Value::as_string), Some("token"));
        let _ = fs::remove_dir_all(&dir);
    }
}
