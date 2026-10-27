"""Checks for the signed IPA cache. Run: python test_signed_cache.py"""

from __future__ import annotations

import os
import plistlib
import tempfile
import unittest
import zipfile
from datetime import datetime, timezone
from pathlib import Path

import worker


def make_ipa(
    path: Path,
    expires: datetime,
    devices: list[str] | None,
    sharing: bool = True,
) -> None:
    info: dict[str, object] = {
        "CFBundleIdentifier": "com.example.app",
        "CFBundleDisplayName": "Example",
        "CFBundleName": "Example",
    }
    if sharing:
        info["UIFileSharingEnabled"] = True
        info["LSSupportsOpeningDocumentsInPlace"] = True
    profile: dict[str, object] = {"ExpirationDate": expires}
    if devices is not None:
        profile["ProvisionedDevices"] = devices
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("Payload/App.app/Info.plist", plistlib.dumps(info, fmt=plistlib.FMT_XML))
        archive.writestr(
            "Payload/App.app/embedded.mobileprovision",
            b"CMS" + plistlib.dumps(profile, fmt=plistlib.FMT_XML),
        )
        archive.writestr("Payload/App.app/_CodeSignature/CodeResources", b"signed")


class SignedCacheTests(unittest.TestCase):
    def setUp(self) -> None:
        self._old = os.environ.get("LOCALAPPDATA")
        self.tmp = tempfile.TemporaryDirectory()
        os.environ["LOCALAPPDATA"] = self.tmp.name

    def tearDown(self) -> None:
        if self._old is None:
            os.environ.pop("LOCALAPPDATA", None)
        else:
            os.environ["LOCALAPPDATA"] = self._old
        self.tmp.cleanup()

    def test_udid_ignores_dashes_and_case(self) -> None:
        now = datetime(2026, 10, 27, tzinfo=timezone.utc)
        profile = {
            "ExpirationDate": datetime(2026, 11, 3),
            "ProvisionedDevices": ["AB-CD-EF-01"],
        }
        self.assertTrue(worker.provision_covers_device(profile, "ab-cd-ef-01", now))
        self.assertFalse(worker.provision_covers_device(profile, "other", now))

    def test_empty_or_expired_profile_is_not_reusable(self) -> None:
        now = datetime(2026, 10, 27, tzinfo=timezone.utc)
        self.assertFalse(
            worker.provision_covers_device(
                {"ExpirationDate": datetime(2026, 10, 27), "ProvisionedDevices": ["ABCDEF01"]},
                "ABCDEF01",
                now,
            )
        )
        self.assertFalse(
            worker.provision_covers_device(
                {"ExpirationDate": datetime(2099, 1, 1), "ProvisionedDevices": []},
                "ABCDEF01",
                now,
            )
        )
        self.assertFalse(
            worker.provision_covers_device({"ExpirationDate": datetime(2099, 1, 1)}, "ABCDEF01", now)
        )
        self.assertFalse(
            worker.provision_covers_device({"ProvisionedDevices": ["ABCDEF01"]}, "ABCDEF01", now)
        )

    def test_lookup_reuses_only_the_same_account_and_device(self) -> None:
        ipa = Path(self.tmp.name) / "one.signed.ipa"
        make_ipa(ipa, datetime(2099, 1, 1), ["AB-CD-EF-01"])
        worker.remember_signed_pair("input", ipa, "ab-cd-ef-01", "Person@Example.com", "TEAM")
        hit, stale = worker.lookup_signed_cache("input", "AB-CD-EF-01", "person@example.com")
        self.assertEqual(hit, ipa)
        self.assertFalse(stale)
        other_user, other_stale = worker.lookup_signed_cache("input", "AB-CD-EF-01", "other@example.com")
        self.assertIsNone(other_user)
        self.assertFalse(other_stale)
        other_device, device_stale = worker.lookup_signed_cache("input", "ffff", "person@example.com")
        self.assertIsNone(other_device)
        self.assertFalse(device_stale)

    def test_expired_empty_and_tampered_files_are_stale(self) -> None:
        root = worker.signed_store_dir()
        expired = root / "expired.signed.ipa"
        make_ipa(expired, datetime(2000, 1, 1), ["ABCDEF01"])
        worker.remember_signed_pair("expired", expired, "ABCDEF01", "a@b.c", "TEAM")
        path, stale = worker.lookup_signed_cache("expired", "ABCDEF01", "a@b.c")
        self.assertIsNone(path)
        self.assertTrue(stale)

        empty = root / "empty.signed.ipa"
        make_ipa(empty, datetime(2099, 1, 1), [])
        worker.remember_signed_pair("empty", empty, "ABCDEF01", "a@b.c", "TEAM")
        path, stale = worker.lookup_signed_cache("empty", "ABCDEF01", "a@b.c")
        self.assertIsNone(path)
        self.assertTrue(stale)

        good = root / "good.signed.ipa"
        make_ipa(good, datetime(2099, 1, 1), ["ABCDEF01"])
        worker.remember_signed_pair("good", good, "ABCDEF01", "a@b.c", "TEAM")
        with good.open("ab") as handle:
            handle.write(b"x")
        path, stale = worker.lookup_signed_cache("good", "ABCDEF01", "a@b.c")
        self.assertIsNone(path)
        self.assertTrue(stale)

    def test_eleventh_pair_drops_the_oldest_file(self) -> None:
        root = worker.signed_store_dir()
        root.mkdir(parents=True, exist_ok=True)
        paths = []
        for index in range(11):
            path = root / f"{index}.signed.ipa"
            path.write_bytes(f"signed-{index}".encode())
            paths.append(path)
            worker.remember_signed_pair(f"sha-{index}", path, "ABCDEF01", "a@b.c", "TEAM")
        pairs = worker.read_signed_index()
        self.assertEqual(len(pairs), 10)
        self.assertFalse(paths[0].exists())
        self.assertTrue(paths[10].exists())
        self.assertEqual(pairs[0]["input_sha"], "sha-10")

    def test_same_key_replaces_the_old_file(self) -> None:
        root = worker.signed_store_dir()
        root.mkdir(parents=True, exist_ok=True)
        first = root / "first.signed.ipa"
        second = root / "second.signed.ipa"
        first.write_bytes(b"one")
        second.write_bytes(b"two")
        worker.remember_signed_pair("same", first, "ABCDEF01", "a@b.c", "TEAM")
        worker.remember_signed_pair("same", second, "ab-cd-ef-01", "A@B.C", "TEAM2")
        pairs = worker.read_signed_index()
        self.assertEqual(len(pairs), 1)
        self.assertEqual(pairs[0]["path"], str(second))
        self.assertEqual(pairs[0]["signed_sha"], worker.sha256_file(second))
        self.assertEqual(pairs[0]["team_id"], "TEAM2")
        self.assertFalse(first.exists())
        self.assertTrue(second.exists())

    def test_rewriting_the_same_file_keeps_it(self) -> None:
        root = worker.signed_store_dir()
        root.mkdir(parents=True, exist_ok=True)
        path = root / "same.signed.ipa"
        path.write_bytes(b"one")
        worker.remember_signed_pair("same", path, "ABCDEF01", "a@b.c", "TEAM")
        path.write_bytes(b"two")
        worker.remember_signed_pair("same", path, "ABCDEF01", "a@b.c", "TEAM")
        self.assertTrue(path.is_file())
        self.assertEqual(len(worker.read_signed_index()), 1)
        self.assertEqual(worker.read_signed_index()[0]["signed_sha"], worker.sha256_file(path))

    def test_corrupt_index_is_empty(self) -> None:
        root = worker.signed_store_dir()
        root.mkdir(parents=True, exist_ok=True)
        (root / "index.json").write_text("{", encoding="utf-8")
        self.assertEqual(worker.read_signed_index(), [])

    def test_unsigned_source_is_not_copied(self) -> None:
        source = Path(self.tmp.name) / "PicHarbor.ipa"
        source.write_bytes(b"unsigned")
        signed = worker.signed_store_dir() / "out.signed.ipa"
        signed.parent.mkdir(parents=True, exist_ok=True)
        signed.write_bytes(b"signed")
        worker.remember_signed_pair(worker.sha256_file(source), signed, "ABCDEF01", "a@b.c", "TEAM")
        stored = [item["path"] for item in worker.read_signed_index()]
        self.assertEqual(stored, [str(signed)])
        self.assertTrue(source.is_file())
        self.assertEqual(list(worker.signed_store_dir().glob("*.ipa")), [signed])

    def test_cache_name_ignores_the_ipa_file_name(self) -> None:
        name = worker.signed_cache_name("abc", "AB-CD", "Person@Example.com")
        self.assertEqual(name, worker.signed_cache_name("abc", "ab-cd", "person@example.com"))
        self.assertTrue(name.startswith("abc."))
        self.assertNotIn("PicHarbor", name)

    def test_reusable_requires_a_signature_and_file_sharing(self) -> None:
        path = Path(self.tmp.name) / "app.ipa"
        make_ipa(path, datetime(2099, 1, 1), ["ABCDEF01"])
        self.assertTrue(worker.signed_ipa_reusable(path))
        bare = Path(self.tmp.name) / "bare.ipa"
        make_ipa(bare, datetime(2099, 1, 1), ["ABCDEF01"], sharing=False)
        self.assertFalse(worker.signed_ipa_reusable(bare))


if __name__ == "__main__":
    unittest.main()
