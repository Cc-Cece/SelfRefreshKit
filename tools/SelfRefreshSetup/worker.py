"""First-install helper for any SelfRefreshKit host.

Reads the bundle id from the IPA. It does not know PicHarbor or any other app.
An unsigned IPA is signed with selfrefresh-sign before install. Success means the
pairing file is on the device at
Documents/SelfRefreshKit/pairing.mobiledevicepairing.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import plistlib
import subprocess
import sys
import threading
import zipfile
from pathlib import Path
from typing import Any

from i18n import t

DROP_DIR = "SelfRefreshKit"
DROP_NAME = "pairing.mobiledevicepairing"
DROP_RELATIVE = f"{DROP_DIR}/{DROP_NAME}"


def log(message: str) -> None:
    print("LOG " + message, file=sys.stderr, flush=True)


def emit(payload: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def explain(exc: BaseException) -> str:
    try:
        from pymobiledevice3.exceptions import (
            AppNotInstalledError,
            ConnectionFailedToUsbmuxdError,
            PairingDialogResponsePendingError,
            PasswordRequiredError,
            UserDeniedPairingError,
        )
    except Exception:
        text = str(exc).strip() or exc.__class__.__name__
        return text

    if isinstance(exc, ConnectionFailedToUsbmuxdError):
        return t("usbmux")
    if isinstance(exc, PasswordRequiredError):
        return t("unlock")
    if isinstance(exc, UserDeniedPairingError):
        return t("trustDenied")
    if isinstance(exc, PairingDialogResponsePendingError):
        return t("trustTimeout")
    if isinstance(exc, AppNotInstalledError):
        return t("appMissing")
    text = str(exc).strip() or exc.__class__.__name__
    return text


def version_at_least(version: str, minimum: tuple[int, int]) -> bool:
    parts: list[int] = []
    for piece in version.split("."):
        digits = ""
        for char in piece:
            if char.isdigit():
                digits += char
            else:
                break
        if not digits:
            break
        parts.append(int(digits))
    while len(parts) < 2:
        parts.append(0)
    return (parts[0], parts[1]) >= minimum


def host_info_plist_name(names: list[str]) -> str:
    matches = [name for name in names if name.count("/") == 2 and name.startswith("Payload/") and name.endswith(".app/Info.plist")]
    if not matches:
        raise RuntimeError(t("noInfoPlist"))
    return sorted(matches, key=len)[0]


def inspect_ipa(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise RuntimeError(t("ipaNotFound", path=path))
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        info_name = host_info_plist_name(names)
        info = plistlib.loads(archive.read(info_name))
        prefix = info_name[: -len("Info.plist")]
        has_provision = (prefix + "embedded.mobileprovision") in names
        has_signature = any(name.startswith(prefix + "_CodeSignature/") for name in names)
    bundle_id = str(info.get("CFBundleIdentifier") or "").strip()
    if not bundle_id:
        raise RuntimeError(t("noBundleId"))
    display = str(info.get("CFBundleDisplayName") or info.get("CFBundleName") or bundle_id)
    file_sharing = bool(info.get("UIFileSharingEnabled")) and bool(info.get("LSSupportsOpeningDocumentsInPlace"))
    installable = has_provision and has_signature
    return {
        "ok": True,
        "bundle_id": bundle_id,
        "display_name": display,
        "signed": installable,
        "installable": installable,
        "has_provision": has_provision,
        "has_signature": has_signature,
        "file_sharing": file_sharing,
        "info_plist": info_name,
    }


def prepare_file_sharing(src: Path, dest: Path) -> dict[str, Any]:
    info = inspect_ipa(src)
    if info["has_provision"] or info["has_signature"]:
        raise RuntimeError(t("prepareSigned"))
    dest.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(src) as archive:
        plist = plistlib.loads(archive.read(info["info_plist"]))
        plist["UIFileSharingEnabled"] = True
        plist["LSSupportsOpeningDocumentsInPlace"] = True
        replacement = plistlib.dumps(plist, fmt=plistlib.FMT_XML)
        with zipfile.ZipFile(dest, "w") as output:
            for item in archive.infolist():
                data = replacement if item.filename == info["info_plist"] else archive.read(item.filename)
                output.writestr(item, data)
    prepared = inspect_ipa(dest)
    if not prepared["file_sharing"] or prepared["installable"]:
        raise RuntimeError(t("prepareBad"))
    return {
        "ok": True,
        "status": "prepared",
        "output": str(dest),
        "message": t("prepareOk"),
        **{key: prepared[key] for key in ("bundle_id", "display_name", "file_sharing", "installable")},
    }


def redact(text: str, secret: str) -> str:
    if secret:
        return text.replace(secret, "******")
    return text


def find_signer() -> Path | None:
    env = os.environ.get("SELFREFRESH_SIGNER", "").strip()
    here = Path(__file__).resolve().parent
    candidates = []
    if env:
        candidates.append(Path(env))
    candidates.append(here / "selfrefresh-sign.exe")
    candidates.append(here / "signer" / "target" / "release" / "selfrefresh-sign.exe")
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return None


def sign_ipa(ipa: Path, udid: str, device_name: str) -> dict[str, Any]:
    exe = find_signer()
    if exe is None:
        raise RuntimeError(t("signerMissing"))
    apple_id = os.environ.get("SELFREFRESH_APPLE_ID", "").strip()
    password = os.environ.get("SELFREFRESH_APPLE_PASSWORD", "")
    anisette = os.environ.get("SELFREFRESH_ANISETTE", "").strip()
    if not apple_id or not password:
        raise RuntimeError(t("needCredentialsQuiet"))
    out_dir = Path(os.environ.get("LOCALAPPDATA") or Path.home()) / "SelfRefreshSetup" / "signed"
    out_dir.mkdir(parents=True, exist_ok=True)
    dest = out_dir / f"{ipa.stem}.signed.ipa"
    request = {
        "apple_id": apple_id,
        "password": password,
        "ipa": str(ipa),
        "udid": udid,
        "device_name": device_name,
        "anisette": anisette,
        "out": str(dest),
    }
    proc = subprocess.Popen(
        [str(exe), "sign"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.stdin is None or proc.stdout is None or proc.stderr is None:
        raise RuntimeError(t("signerStartFailed"))
    proc.stdin.write(json.dumps(request, ensure_ascii=False) + "\n")
    proc.stdin.flush()

    def pump_err() -> None:
        assert proc.stderr is not None
        for line in proc.stderr:
            text = redact(line, password).strip()
            if text:
                log(text)

    thread = threading.Thread(target=pump_err, daemon=True)
    thread.start()
    signed: dict[str, Any] | None = None
    error: str | None = None
    while True:
        line = proc.stdout.readline()
        if not line:
            break
        text = line.strip()
        if not text:
            continue
        try:
            event = json.loads(text)
        except json.JSONDecodeError:
            log(redact(text, password))
            continue
        kind = event.get("event")
        if kind == "log":
            log(redact(str(event.get("message") or ""), password))
        elif kind == "need_2fa":
            message = redact(str(event.get("message") or t("trustedCode")), password)
            message = " ".join(message.split())
            print("PROMPT_2FA " + message, file=sys.stderr, flush=True)
            reply = sys.stdin.readline()
            if not reply:
                reply = '{"abort":true}\n'
            proc.stdin.write(reply if reply.endswith("\n") else reply + "\n")
            proc.stdin.flush()
        elif kind == "ok":
            signed = event
        elif kind == "error":
            error = redact(str(event.get("message") or t("signFailed")), password)
    code = proc.wait()
    thread.join(timeout=2)
    try:
        proc.stdin.close()
    except Exception:
        pass
    if error:
        raise RuntimeError(error)
    if code != 0 or not isinstance(signed, dict) or not signed.get("ipa"):
        raise RuntimeError(t("signIncomplete"))
    log(t("signedAt", path=signed["ipa"]))
    return signed


def save_local_pairing(data: bytes, udid: str) -> Path:
    import os

    root = Path(os.environ.get("LOCALAPPDATA") or Path.home()) / "SelfRefreshSetup" / "pairing"
    root.mkdir(parents=True, exist_ok=True)
    safe = "".join(char for char in udid if char.isalnum() or char == "-") or "device"
    path = root / f"{safe}.mobiledevicepairing"
    path.write_bytes(data)
    return path


def remote_pairing_proof_matches(session: Any, proof: bytes) -> bool:
    """Accept the device proof under both srptools 1.x and 2.0.

    pymobiledevice3 11.45.0 passes proof.hex().encode(). srptools 2.0 treats
    bytes as the raw proof and str as hex, so that call never matches.
    """
    if not isinstance(proof, (bytes, bytearray)) or not proof:
        return False
    raw = bytes(proof)
    candidates: list[Any] = [raw, raw.hex()]
    hex_bytes = raw.hex().encode()
    if hex_bytes != raw:
        candidates.append(hex_bytes)
    for candidate in candidates:
        try:
            if session.verify_proof(candidate):
                return True
        except Exception:
            continue
    return False


def install_remote_pairing_proof_fix() -> None:
    import binascii
    import platform

    from pymobiledevice3.remote import tunnel_service as tunnel

    protocol = tunnel.RemotePairingProtocol
    if getattr(protocol, "_selfrefresh_proof_fix", False):
        return

    async def _verify_proof(self: Any) -> None:
        assert self.srp_context is not None
        client_public = binascii.unhexlify(self.srp_context.public)
        client_session_key_proof = binascii.unhexlify(self.srp_context.key_proof)
        tlv = tunnel.PairingDataComponentTLVBuf.build([
            tunnel.PairingDataComponentTLV8(tunnel.PairingDataComponentType.STATE, b"\x03"),
            tunnel.PairingDataComponentTLV8(tunnel.PairingDataComponentType.PUBLIC_KEY, client_public[:255]),
            tunnel.PairingDataComponentTLV8(tunnel.PairingDataComponentType.PUBLIC_KEY, client_public[255:]),
            tunnel.PairingDataComponentTLV8(tunnel.PairingDataComponentType.PROOF, client_session_key_proof),
        ])
        response = await self._send_receive_pairing_data({
            "data": tlv,
            "kind": "setupManualPairing",
            "sendingHost": platform.node(),
            "startNewSession": False,
        })
        data = self.decode_tlv(tunnel.PairingDataComponentTLVBuf.parse(response))
        if tunnel.PairingDataComponentType.ERROR in data:
            describer = getattr(tunnel, "_describe_pairing_error", None)
            detail = describer(data) if describer else t("rpRejected")
            raise RuntimeError(detail if isinstance(detail, str) and detail else t("rpRejected"))
        proof = data.get(tunnel.PairingDataComponentType.PROOF)
        if not isinstance(proof, (bytes, bytearray)) or not remote_pairing_proof_matches(self.srp_context, proof):
            raise RuntimeError(t("rpProof"))

    protocol._verify_proof = _verify_proof  # type: ignore[method-assign]
    protocol._selfrefresh_proof_fix = True


def export_remote_pairing(record: dict[str, Any], udid: str, wifi_mac: str | None) -> bytes:
    from pymobiledevice3.pair_records import generate_host_id

    public_key = record.get("public_key")
    private_key = record.get("private_key")
    if not isinstance(public_key, (bytes, bytearray)) or len(public_key) != 32:
        raise RuntimeError(t("rpPublic"))
    if not isinstance(private_key, (bytes, bytearray)) or len(private_key) != 32:
        raise RuntimeError(t("rpPrivate"))
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

    signing_key = Ed25519PrivateKey.from_private_bytes(bytes(private_key))
    derived = signing_key.public_key().public_bytes_raw()
    if derived != bytes(public_key):
        raise RuntimeError(t("rpMismatch"))
    # Pair-setup signed this exact host id. A fresh call can differ once a saved record replaces it.
    identifier = record.get("identifier")
    if not isinstance(identifier, str) or not identifier.strip():
        identifier = generate_host_id()
    exported: dict[str, Any] = {
        "public_key": bytes(public_key),
        "private_key": bytes(private_key),
        "identifier": identifier,
        "UDID": udid,
    }
    peer_irk = record.get("peer_alt_irk")
    if isinstance(peer_irk, (bytes, bytearray)) and len(peer_irk) == 16:
        exported["alt_irk"] = bytes(peer_irk)
    if wifi_mac:
        exported["WiFiMACAddress"] = wifi_mac
    return plistlib.dumps(exported, fmt=plistlib.FMT_XML)


async def connect(udid: str, autopair: bool):
    from pymobiledevice3.lockdown import create_using_usbmux

    log(t("connecting"))
    return await create_using_usbmux(
        serial=udid,
        autopair=autopair,
        connection_type="USB",
        pair_timeout=180,
    )


async def create_remote_pairing(lockdown) -> dict[str, Any]:
    from pymobiledevice3.exceptions import RemotePairingCompletedError
    from pymobiledevice3.remote.tunnel_service import RemotePairingLockdownService

    install_remote_pairing_proof_fix()
    service = await RemotePairingLockdownService.create(lockdown)
    try:
        try:
            await service.connect(autopair=True)
        except RemotePairingCompletedError:
            log(t("remoteDone"))
        identifier = service.identifier
        record = service.pair_record
    finally:
        await service.close()
    if not isinstance(record, dict):
        raise RuntimeError(t("rpNoRecord"))
    record = dict(record)
    if isinstance(identifier, str) and identifier.strip():
        record["identifier"] = identifier
    return record


async def build_pairing(lockdown) -> tuple[bytes, str, str | None]:
    ios = lockdown.product_version or ""
    udid = lockdown.udid or ""
    wifi_mac = getattr(lockdown, "wifi_mac_address", None)
    warning = None
    if version_at_least(ios, (17, 4)):
        record = await create_remote_pairing(lockdown)
        log(t("gotRp"))
        return export_remote_pairing(record, udid, wifi_mac), "rppairing", None
    record = lockdown.pair_record
    if not record:
        await lockdown.pair(timeout=180)
        record = lockdown.pair_record
    if not isinstance(record, dict):
        raise RuntimeError(t("noLockdown"))
    exported = dict(record)
    if udid:
        exported["UDID"] = udid
    log(t("gotLockdown"))
    return plistlib.dumps(exported, fmt=plistlib.FMT_XML), "lockdown", warning


async def ensure_dir(afc, path: str) -> None:
    current = ""
    for part in path.split("/"):
        if not part:
            continue
        current = f"{current}/{part}" if current else part
        try:
            await afc.makedirs(current)
        except Exception:
            pass


async def push_pairing(lockdown, bundle_id: str, data: bytes) -> str:
    from pymobiledevice3.services.house_arrest import HouseArrestService

    attempts: list[str] = []
    try:
        async with await HouseArrestService.create(lockdown, bundle_id, documents_only=False) as house:
            await ensure_dir(house, f"Documents/{DROP_DIR}")
            await house.set_file_contents(f"Documents/{DROP_RELATIVE}", data)
        return "container"
    except Exception as exc:
        attempts.append(t("attemptContainer", error=explain(exc)))
        log(t("pushContainerFailed"))
    try:
        async with await HouseArrestService.create(lockdown, bundle_id, documents_only=True) as house:
            await ensure_dir(house, DROP_DIR)
            await house.set_file_contents(DROP_RELATIVE, data)
        return "documents"
    except Exception as exc:
        attempts.append(t("attemptDocuments", error=explain(exc)))
    detail = " ".join(attempts)
    raise RuntimeError(t("pushFailed", detail=detail))


async def app_installed(lockdown, bundle_id: str) -> bool:
    from pymobiledevice3.services.installation_proxy import InstallationProxyService

    async with InstallationProxyService(lockdown) as proxy:
        apps = await proxy.get_apps(application_type="Any", bundle_identifiers=[bundle_id])
    return bundle_id in apps


async def install_ipa(lockdown, ipa: Path) -> None:
    from pymobiledevice3.services.installation_proxy import InstallationProxyService

    log(t("installStart"))

    def handler(percent: float, *_args: Any) -> None:
        log(t("installProgress", percent=int(percent)))

    async with InstallationProxyService(lockdown) as proxy:
        await proxy.install_from_local(ipa, developer=True, handler=handler)
    log(t("installDone"))


async def list_devices() -> dict[str, Any]:
    from pymobiledevice3.exceptions import (
        ConnectionFailedToUsbmuxdError,
        NotPairedError,
        PasswordRequiredError,
    )
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.usbmux import list_devices as list_mux_devices

    try:
        found = await list_mux_devices()
    except ConnectionFailedToUsbmuxdError as exc:
        return {"ok": False, "message": explain(exc), "devices": []}
    usb = [device for device in found if device.is_usb]
    chosen = usb or list(found)
    devices: list[dict[str, Any]] = []
    for device in chosen:
        row: dict[str, Any] = {
            "udid": device.serial,
            "connection": device.connection_type,
            "name": None,
            "ios": None,
            "paired": False,
            "error": None,
        }
        try:
            lockdown = await create_using_usbmux(
                serial=device.serial,
                autopair=False,
                connection_type=device.connection_type,
            )
            try:
                row["name"] = lockdown.all_values.get("DeviceName") or lockdown.display_name
                row["ios"] = lockdown.product_version
                row["paired"] = bool(lockdown.paired)
            finally:
                await lockdown.close()
        except NotPairedError:
            row["error"] = t("notTrustedYet")
        except PasswordRequiredError:
            row["error"] = t("unlockShort")
        except Exception as exc:
            row["error"] = explain(exc)
        devices.append(row)
    return {"ok": True, "devices": devices}


async def run_setup(ipa: Path, udid: str) -> dict[str, Any]:
    info = inspect_ipa(ipa)
    log(f"{info['display_name']} · {info['bundle_id']}")
    if info["installable"]:
        log(t("ipaSignedPlan"))
    else:
        log(t("ipaUnsignedPlan"))
    lockdown = None
    try:
        lockdown = await connect(udid, autopair=True)
        device_name = lockdown.all_values.get("DeviceName") or lockdown.display_name or "iPhone"
        ios = lockdown.product_version or ""
        log(t("connected", name=device_name, ios=ios))
        installed_now = False
        signed_output = None
        original_bundle = info["bundle_id"]
        base = {
            "bundle_id": info["bundle_id"],
            "display_name": info["display_name"],
            "signed": info["installable"],
            "installable": info["installable"],
            "file_sharing": info["file_sharing"],
            "device_name": device_name,
            "ios_version": ios,
            "udid": lockdown.udid or udid,
        }
        if info["installable"]:
            await install_ipa(lockdown, ipa)
            installed_now = True
            await lockdown.close()
            lockdown = await connect(udid, autopair=True)
        else:
            present = await app_installed(lockdown, info["bundle_id"])
            if present:
                log(t("alreadyInstalled"))
            else:
                await lockdown.close()
                lockdown = None
                log(t("signingStart"))
                signed = sign_ipa(ipa, base["udid"], str(device_name))
                signed_path = Path(str(signed["ipa"]))
                signed_output = str(signed_path)
                signed_info = inspect_ipa(signed_path)
                if not signed_info["installable"] or not signed_info["file_sharing"]:
                    raise RuntimeError(t("signedIncomplete"))
                if signed_info["bundle_id"] != original_bundle:
                    log(t("bundleChanged", chosen=signed_info["bundle_id"], original=original_bundle))
                info = signed_info
                base["bundle_id"] = info["bundle_id"]
                base["display_name"] = info["display_name"]
                base["signed"] = True
                base["installable"] = True
                base["file_sharing"] = info["file_sharing"]
                lockdown = await connect(udid, autopair=True)
                await install_ipa(lockdown, signed_path)
                installed_now = True
                await lockdown.close()
                lockdown = await connect(udid, autopair=True)
        data, kind, warning = await build_pairing(lockdown)
        saved = save_local_pairing(data, base["udid"])
        log(t("pairingSavedLog", path=saved))
        try:
            method = await push_pairing(lockdown, info["bundle_id"], data)
        except Exception as exc:
            return {
                "ok": False,
                "status": "installed_push_failed" if installed_now else "push_failed",
                "message": explain(exc),
                "pairing_kind": kind,
                "pairing_saved": str(saved),
                "output": signed_output,
                "warning": warning,
                **base,
            }
        message = t("pushedOk")
        if kind == "lockdown":
            message += " " + t("lockdownNote")
        if warning:
            message = warning + " " + message
        if not info["file_sharing"] and method == "documents":
            message += " " + t("documentsNote")
        elif not info["file_sharing"]:
            message += " " + t("noSharingNote")
        return {
            "ok": True,
            "status": "installed_and_pushed" if installed_now else "pushed",
            "message": message,
            "pairing_kind": kind,
            "pairing_saved": str(saved),
            "push_method": method,
            "output": signed_output,
            "warning": warning,
            **base,
        }
    finally:
        if lockdown is not None:
            await lockdown.close()


async def export_pairing(udid: str, dest: Path) -> dict[str, Any]:
    """Write a pairing file the user can keep. This does not install or push."""
    lockdown = None
    try:
        lockdown = await connect(udid, autopair=True)
        device_name = lockdown.all_values.get("DeviceName") or lockdown.display_name or "iPhone"
        ios = lockdown.product_version or ""
        log(t("connected", name=device_name, ios=ios))
        data, kind, warning = await build_pairing(lockdown)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        saved = save_local_pairing(data, lockdown.udid or udid)
        log(t("exportedLog", path=dest))
        message = t("exportedOk")
        if kind == "lockdown":
            message += " " + t("lockdownNote")
        return {
            "ok": True,
            "status": "exported",
            "message": message,
            "pairing_kind": kind,
            "pairing_saved": str(saved),
            "output": str(dest),
            "warning": warning,
            "device_name": device_name,
            "ios_version": ios,
            "udid": lockdown.udid or udid,
        }
    finally:
        if lockdown is not None:
            await lockdown.close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="SelfRefresh first install")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("devices")
    inspect = sub.add_parser("inspect")
    inspect.add_argument("--ipa", required=True)
    prepare = sub.add_parser("prepare")
    prepare.add_argument("--ipa", required=True)
    prepare.add_argument("--out")
    run = sub.add_parser("run")
    run.add_argument("--ipa", required=True)
    run.add_argument("--udid", required=True)
    export = sub.add_parser("export")
    export.add_argument("--udid", required=True)
    export.add_argument("--out", required=True)
    return parser


def main(argv: list[str]) -> int:
    logging.getLogger().setLevel(logging.ERROR)
    args = build_parser().parse_args(argv)
    try:
        if args.command == "devices":
            emit(asyncio.run(list_devices()))
            return 0
        if args.command == "inspect":
            emit(inspect_ipa(Path(args.ipa)))
            return 0
        if args.command == "prepare":
            src = Path(args.ipa)
            dest = Path(args.out) if args.out else src.with_name(src.stem + ".filesharing.ipa")
            emit(prepare_file_sharing(src, dest))
            return 0
        if args.command == "run":
            emit(asyncio.run(run_setup(Path(args.ipa), args.udid)))
            return 0
        if args.command == "export":
            emit(asyncio.run(export_pairing(args.udid, Path(args.out))))
            return 0
    except Exception as exc:
        emit({"ok": False, "status": "failed", "message": explain(exc)})
        return 1
    emit({"ok": False, "status": "failed", "message": t("unknownCommand")})
    return 1


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    raise SystemExit(main(sys.argv[1:]))
