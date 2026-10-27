"""UI strings for the setup window, worker, and signer.

Languages: en, zh-CN, zh-HK, zh-TW, ja. Unknown languages use English.
"""

from __future__ import annotations

import ctypes
import json
import os
import sys
from functools import lru_cache
from pathlib import Path

LANGS = ("en", "zh-CN", "zh-HK", "zh-TW", "ja")


def detect_system() -> str:
    try:
        langid = ctypes.windll.kernel32.GetUserDefaultUILanguage() & 0xFFFF
    except Exception:
        return "en"
    if langid in (0x0C04, 0x1404):
        return "zh-HK"
    if langid == 0x0404:
        return "zh-TW"
    primary = langid & 0x3FF
    if primary == 0x04:
        return "zh-CN"
    if primary == 0x11:
        return "ja"
    return "en"


def saved_lang() -> str | None:
    root = os.environ.get("LOCALAPPDATA", "").strip()
    if not root:
        return None
    path = Path(root) / "SelfRefreshSetup" / "language.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, UnicodeError):
        return None
    raw = ""
    if isinstance(data, dict):
        value = data.get("lang", data.get("Lang", ""))
        raw = value.strip() if isinstance(value, str) else ""
    for lang in LANGS:
        if raw.lower() == lang.lower():
            return lang
    return None


def current_lang() -> str:
    raw = os.environ.get("SELFREFRESH_LANG", "").strip()
    if raw:
        for lang in LANGS:
            if raw.lower() == lang.lower():
                return lang
        return "en"
    return saved_lang() or detect_system()


@lru_cache(maxsize=1)
def catalog() -> dict:
    path = Path(__file__).with_name("i18n.json")
    return json.loads(path.read_text(encoding="utf-8"))


os.environ["SELFREFRESH_LANG"] = current_lang()


def t(key: str, **kwargs: object) -> str:
    entry = catalog().get(key) or {}
    text = entry.get(current_lang()) or entry.get("en") or key
    for name, value in kwargs.items():
        text = text.replace("{" + name + "}", str(value))
    return text


def problems() -> list[str]:
    found: list[str] = []
    data = catalog()
    tokens = (
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
    )
    for key, entry in data.items():
        if not isinstance(entry, dict):
            found.append(f"{key} is not an object")
            continue
        english = entry.get("en") or ""
        if not english:
            found.append(f"{key} missing en")
        for lang in LANGS:
            text = entry.get(lang) or ""
            if not text:
                found.append(f"{key} missing {lang}")
                continue
            for token in tokens:
                if token in english and token not in text:
                    found.append(f"{key} {lang} missing {token}")
    return found


if __name__ == "__main__":
    issues = problems()
    if issues:
        print("\n".join(issues))
        sys.exit(1)
    print(f"{len(catalog())} keys, lang {current_lang()}")
