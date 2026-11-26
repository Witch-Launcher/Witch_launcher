#!/usr/bin/env python3
import argparse
import base64
import getpass
import hashlib
import json
import os
import pathlib
import re
import stat
import sys
import zipfile

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{1,63}$")
VERSION_RE = re.compile(r"^[0-9]+(\.[0-9]+){0,3}([-+][0-9A-Za-z.-]+)?$")
LICENSES = {
    "MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC", "MPL-2.0",
    "GPL-2.0-only", "GPL-2.0-or-later", "GPL-3.0-only", "GPL-3.0-or-later",
    "LGPL-2.1-only", "LGPL-2.1-or-later", "LGPL-3.0-only", "LGPL-3.0-or-later",
    "AGPL-3.0-only", "AGPL-3.0-or-later", "EPL-2.0", "CC0-1.0", "Unlicense", "Zlib",
}
RESERVED = {"checksums.json", "witch-plugin.sig"}
MAX_PACKAGE_BYTES = 32 * 1024 * 1024
MAX_EXTRACTED_BYTES = 128 * 1024 * 1024
MAX_FILES = 2048


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def safe_relative(value, label):
    if not isinstance(value, str) or not value:
        fail(f"{label} must be a relative path")
    if value.startswith("/") or "\\" in value:
        fail(f"{label} must be a safe relative path")
    path = pathlib.PurePosixPath(value)
    if any(part in ("", ".", "..") for part in path.parts):
        fail(f"{label} must be a safe relative path")
    return value


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def public_key_base64(key):
    if isinstance(key, ec.EllipticCurvePrivateKey):
        key = key.public_key()
    raw = key.public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
    return base64.b64encode(raw).decode("ascii")


def key_id_for(key, prefix="dev"):
    if isinstance(key, ec.EllipticCurvePrivateKey):
        key = key.public_key()
    raw = key.public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
    return f"{prefix}-{sha256_bytes(raw)[:16]}"


def valid_http_url(value):
    if not isinstance(value, str) or not value:
        return False
    return value.startswith("https://") or value.startswith("http://")


def validate_manifest(manifest):
    if not isinstance(manifest, dict):
        fail("witch-plugin.json must contain a JSON object")
    plugin_id = manifest.get("id")
    name = manifest.get("name")
    version = manifest.get("version")
    license_name = manifest.get("license")
    source = manifest.get("source")
    api = manifest.get("api")
    if not isinstance(plugin_id, str) or not ID_RE.match(plugin_id):
        fail("id must use lowercase letters, numbers, dot, underscore or dash")
    if not isinstance(name, str) or not name.strip():
        fail("name is required")
    if not isinstance(version, str) or not VERSION_RE.match(version):
        fail("version must look like 1.0.0")
    if license_name not in LICENSES:
        fail("license must be an OSI/SPDX open-source license")
    if not valid_http_url(source):
        fail("source must be an http(s) source-code URL")
    if api != 1:
        fail("api must be 1")

    entrypoints = manifest.get("entrypoints", {})
    if entrypoints is not None and not isinstance(entrypoints, dict):
        fail("entrypoints must be an object")
    for key, value in (entrypoints or {}).items():
        safe_relative(value, f"entrypoints.{key}")

    for key in ("icon", "banner"):
        if key in manifest:
            safe_relative(manifest[key], key)

    ui = manifest.get("ui")
    if ui is not None and not isinstance(ui, (str, dict)):
        fail("ui must be a path or an object")
    if isinstance(ui, str):
        safe_relative(ui, "ui")
    if isinstance(ui, dict) and "theme" in ui:
        safe_relative(ui["theme"], "ui.theme")

    settings = manifest.get("settings")
    if settings is not None and not isinstance(settings, list):
        fail("settings must be an array")
    for index, item in enumerate(settings or []):
        if not isinstance(item, dict) or not isinstance(item.get("key"), str) or not isinstance(item.get("type"), str):
            fail(f"settings[{index}] needs key and type")
        if item["type"] not in {"switch", "text", "slider", "picker"}:
            fail(f"settings[{index}].type is not supported")
    return plugin_id, version, entrypoints or {}, ui


def referenced_paths(manifest):
    paths = set()
    for value in (manifest.get("entrypoints") or {}).values():
        paths.add(value)
    for key in ("icon", "banner"):
        if key in manifest:
            paths.add(manifest[key])
    ui = manifest.get("ui")
    if isinstance(ui, str):
        paths.add(ui)
    elif isinstance(ui, dict) and "theme" in ui:
        paths.add(ui["theme"])
    return paths


def collect_files(source):
    source = pathlib.Path(source)
    if not source.is_dir():
        fail(f"plugin source directory not found: {source}")
    files = {}
    total = 0
    for root, dirs, names in os.walk(source):
        dirs[:] = sorted(d for d in dirs if not d.startswith(".") and d != "__pycache__")
        for name in sorted(names):
            if name.startswith(".") or name in RESERVED:
                continue
            full = pathlib.Path(root) / name
            if full.is_symlink():
                fail(f"symbolic links are not allowed: {full}")
            if not full.is_file():
                fail(f"unsupported file: {full}")
            relative = full.relative_to(source).as_posix()
            safe_relative(relative, relative)
            files[relative] = full
            total += full.stat().st_size
            if len(files) > MAX_FILES:
                fail("plugin contains too many files")
            if total > MAX_EXTRACTED_BYTES:
                fail("plugin source is too large")
    if "witch-plugin.json" not in files:
        fail("witch-plugin.json is required at the package root")
    return files


def load_private_key(path, password):
    data = pathlib.Path(path).read_bytes()
    try:
        return serialization.load_pem_private_key(data, password=password.encode("utf-8") if password else None)
    except TypeError:
        fail("private key is encrypted; pass --key-password or set WITCH_PLUGIN_KEY_PASSWORD")
    except ValueError as error:
        fail(f"cannot read private key: {error}")


def generate_key(path, password, key_id):
    target = pathlib.Path(path)
    if target.exists():
        fail(f"refusing to overwrite existing key: {target}")
    target.parent.mkdir(parents=True, exist_ok=True)
    key = ec.generate_private_key(ec.SECP256R1())
    encryption = serialization.BestAvailableEncryption(password.encode("utf-8")) if password else serialization.NoEncryption()
    target.write_bytes(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, encryption))
    os.chmod(target, 0o600)
    identifier = key_id or key_id_for(key)
    public = public_key_base64(key)
    print(f"private_key={target}")
    print(f"key_id={identifier}")
    print(f"public_key={public}")
    print("Store the private key offline. Add public_key to the plugin registry submission.")


def build_package(source, private_key_path, key_id, output, password):
    files = collect_files(source)
    manifest_bytes = files["witch-plugin.json"].read_bytes()
    try:
        manifest = json.loads(manifest_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"witch-plugin.json is invalid: {error}")
    plugin_id, version, _, _ = validate_manifest(manifest)
    refs = referenced_paths(manifest)
    missing = [path for path in refs if path not in files]
    if missing:
        fail(f"manifest references missing files: {', '.join(sorted(missing))}")

    key = load_private_key(private_key_path, password)
    if not isinstance(key, ec.EllipticCurvePrivateKey) or key.curve.name != "secp256r1":
        fail("private key must be an ECDSA P-256 key")

    checksums = {relative: sha256_file(path) for relative, path in sorted(files.items())}
    checksums_bytes = (json.dumps(checksums, indent=2, sort_keys=True) + "\n").encode("utf-8")
    signature = key.sign(checksums_bytes, ec.ECDSA(hashes.SHA256()))
    signature_document = {
        "algorithm": "ES256",
        "keyId": key_id or key_id_for(key),
        "publicKey": public_key_base64(key),
        "signature": base64.b64encode(signature).decode("ascii"),
    }
    signature_bytes = (json.dumps(signature_document, indent=2, sort_keys=True) + "\n").encode("utf-8")

    output = pathlib.Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        ordered = ["witch-plugin.json"] + sorted(path for path in files if path != "witch-plugin.json")
        for relative in ordered:
            info = zipfile.ZipInfo(relative, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            with archive.open(info, "w") as handle:
                handle.write(files[relative].read_bytes())
        for name, data in (("checksums.json", checksums_bytes), ("witch-plugin.sig", signature_bytes)):
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            archive.writestr(info, data)

    if output.stat().st_size > MAX_PACKAGE_BYTES:
        output.unlink()
        fail("package is larger than 32 MB")
    artifact = sha256_file(output)
    print(f"package={output}")
    print(f"plugin={plugin_id}")
    print(f"version={version}")
    print(f"checksums_sha256={sha256_bytes(checksums_bytes)}")
    print(f"artifact_sha256={artifact}")
    print(f"public_key={signature_document['publicKey']}")
    print(f"key_id={signature_document['keyId']}")


def verify_package(path):
    package = pathlib.Path(path)
    try:
        archive = zipfile.ZipFile(package, "r")
    except (OSError, zipfile.BadZipFile) as error:
        fail(f"cannot open package: {error}")
    with archive:
        names = [name for name in archive.namelist() if not name.endswith("/")]
        if len(names) != len(set(names)):
            fail("package contains duplicate entries")
        for name in names:
            safe_relative(name, name)
            info = archive.getinfo(name)
            mode = info.external_attr >> 16
            if stat.S_ISLNK(mode):
                fail(f"symbolic links are not allowed: {name}")
        required = {"witch-plugin.json", "checksums.json", "witch-plugin.sig"}
        missing = required.difference(names)
        if missing:
            fail(f"package is missing: {', '.join(sorted(missing))}")
        manifest = json.loads(archive.read("witch-plugin.json").decode("utf-8"))
        validate_manifest(manifest)
        checksums_bytes = archive.read("checksums.json")
        checksums = json.loads(checksums_bytes.decode("utf-8"))
        if not isinstance(checksums, dict) or "witch-plugin.json" not in checksums:
            fail("checksums.json must cover witch-plugin.json")
        signature_document = json.loads(archive.read("witch-plugin.sig").decode("utf-8"))
        if signature_document.get("algorithm") != "ES256":
            fail("signature algorithm must be ES256")
        public_raw = base64.b64decode(signature_document.get("publicKey", ""), validate=True)
        if len(public_raw) != 65 or public_raw[0] != 4:
            fail("public key must be a 65-byte P-256 point")
        public_key = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), public_raw)
        signature = base64.b64decode(signature_document.get("signature", ""), validate=True)
        try:
            public_key.verify(signature, checksums_bytes, ec.ECDSA(hashes.SHA256()))
        except Exception as error:
            fail(f"signature verification failed: {error}")
        allowed = set(checksums) | RESERVED
        for name in names:
            if name not in allowed:
                fail(f"file is not covered by checksums.json: {name}")
        for name, expected in checksums.items():
            if name not in names:
                fail(f"checksums.json references missing file: {name}")
            if not isinstance(expected, str) or not re.match(r"^[a-f0-9]{64}$", expected):
                fail(f"invalid checksum for {name}")
            actual = sha256_bytes(archive.read(name))
            if actual != expected:
                fail(f"checksum mismatch: {name}")
    print(f"verified={package}")
    print(f"plugin={manifest['id']}")
    print(f"version={manifest['version']}")
    print(f"artifact_sha256={sha256_file(package)}")
    print(f"key_id={signature_document.get('keyId', '')}")


def main():
    parser = argparse.ArgumentParser(description="Pack and sign Witch .plgw plugin packages")
    parser.add_argument("--source", help="plugin source directory")
    parser.add_argument("--private-key", help="P-256 private key PEM")
    parser.add_argument("--key-password", default=os.environ.get("WITCH_PLUGIN_KEY_PASSWORD", ""))
    parser.add_argument("--key-id", default="", help="publisher key id")
    parser.add_argument("--out", help="output .plgw path")
    parser.add_argument("--verify", help="verify an existing .plgw package")
    parser.add_argument("--generate-key", help="generate a P-256 private key at this path")
    args = parser.parse_args()

    if args.generate_key:
        generate_key(args.generate_key, args.key_password, args.key_id)
        return
    if args.verify:
        verify_package(args.verify)
        return
    if not args.source or not args.private_key:
        parser.error("--source and --private-key are required to build a package")
    output = args.out
    if not output:
        files = collect_files(args.source)
        manifest = json.loads(files["witch-plugin.json"].read_text("utf-8"))
        output = f"{manifest.get('id', 'plugin')}-{manifest.get('version', '0.0.0')}.plgw"
    build_package(args.source, args.private_key, args.key_id, output, args.key_password)


if __name__ == "__main__":
    main()
