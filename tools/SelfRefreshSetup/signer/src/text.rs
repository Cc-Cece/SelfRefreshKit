use serde_json::Value;
use std::sync::OnceLock;

const LANGS: [&str; 5] = ["en", "zh-CN", "zh-HK", "zh-TW", "ja"];

fn catalog() -> &'static Value {
    static CATALOG: OnceLock<Value> = OnceLock::new();
    CATALOG.get_or_init(|| {
        serde_json::from_str(include_str!("../../i18n.json")).expect("i18n.json")
    })
}

pub fn lang() -> &'static str {
    let Ok(raw) = std::env::var("SELFREFRESH_LANG") else {
        return "en";
    };
    canonical(raw.trim()).unwrap_or("en")
}

fn canonical(raw: &str) -> Option<&'static str> {
    LANGS.into_iter().find(|lang| lang.eq_ignore_ascii_case(raw))
}

pub fn phrase(language: &str, key: &str) -> String {
    let Some(entry) = catalog().get(key) else {
        return key.to_string();
    };
    let pick = |code: &str| entry.get(code).and_then(Value::as_str).filter(|text| !text.is_empty());
    pick(language)
        .or_else(|| pick("en"))
        .unwrap_or(key)
        .to_string()
}

pub fn t(key: &str) -> String {
    phrase(lang(), key)
}

pub fn tf(key: &str, args: &[(&str, &str)]) -> String {
    let mut text = t(key);
    for (name, value) in args {
        text = text.replace(&format!("{{{name}}}"), value);
    }
    text
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_language_has_the_english_text_and_placeholders() {
        let Value::Object(keys) = catalog() else {
            panic!("catalog");
        };
        let tokens = [
            "{path}",
            "{error}",
            "{name}",
            "{ios}",
            "{percent}",
            "{detail}",
            "{chosen}",
            "{original}",
            "{id}",
            "{url}",
            "{machine}",
            "{written}",
            "{bundle_id}",
            "{message}",
            "{err}",
            "{scoped}",
        ];
        for (key, entry) in keys {
            let Value::Object(langs) = entry else {
                panic!("{key}");
            };
            let english = langs.get("en").and_then(Value::as_str).unwrap_or("");
            assert!(!english.is_empty(), "{key} missing en");
            for lang in LANGS {
                let text = langs.get(lang).and_then(Value::as_str).unwrap_or("");
                assert!(!text.is_empty(), "{key} missing {lang}");
                for token in tokens {
                    if english.contains(token) {
                        assert!(text.contains(token), "{key} {lang} missing {token}");
                    }
                }
            }
        }
    }

    #[test]
    fn unknown_language_uses_english() {
        let english = phrase("en", "ready");
        assert_eq!(phrase("fr", "ready"), english);
        assert_ne!(phrase("zh-TW", "ready"), english);
        assert_ne!(phrase("zh-HK", "ready"), phrase("zh-TW", "ready"));
    }
}
