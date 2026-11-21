"""Pinned tools for the museum's Linux Quest build."""

import hashlib
import os
import platform
import shutil
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory
from zipfile import ZipFile


GODOT_VERSION = "4.7.2"
GODOT_RELEASE = f"https://github.com/godotengine/godot-builds/releases/download/{GODOT_VERSION}-stable"
EDITOR_ZIP = f"Godot_v{GODOT_VERSION}-stable_linux.x86_64.zip"
TEMPLATES = f"Godot_v{GODOT_VERSION}-stable_export_templates.tpz"
VENDORS_VERSION = "5.2.0-stable"
VENDORS_URL = f"https://github.com/GodotVR/godot_openxr_vendors/releases/download/{VENDORS_VERSION}/godotopenxrvendorsaddon.zip"
SDK_TOOLS_URL = "https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"
API = "36"
BUILD_TOOLS = "36.1.0"


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def download(cache, url, checksum):
    directory = cache / "downloads"
    directory.mkdir(exist_ok=True)
    destination = directory / url.rsplit("/", 1)[1]
    if destination.is_file() and sha256(destination) == checksum:
        return destination
    print(f"Downloading {destination.name}", flush=True)
    with TemporaryDirectory(dir=directory) as tmp:
        part = Path(tmp) / destination.name
        subprocess.run(["curl", "--fail", "--location", "--retry", "3", "--silent", "--show-error",
                        "--output", part, url], check=True)
        if sha256(part) != checksum:
            raise ValueError(f"SHA-256 mismatch for {destination.name}")
        part.replace(destination)
    return destination


def extract_file(archive, member, destination, mode=0o644):
    destination.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=destination.parent) as tmp:
        part = Path(tmp) / destination.name
        with ZipFile(archive) as zipped, zipped.open(member) as src, part.open("wb") as out:
            shutil.copyfileobj(src, out)
        part.chmod(mode)
        part.replace(destination)


def godot_tools(cache):
    editor = Path(os.environ.get("GODOT", cache / "bin" / f"godot-{GODOT_VERSION}"))
    if "GODOT" not in os.environ and not editor.is_file():
        if (platform.system(), platform.machine()) != ("Linux", "x86_64"):
            raise ValueError(f"Set GODOT to your native Godot {GODOT_VERSION} executable.")
        source = download(cache, f"{GODOT_RELEASE}/{EDITOR_ZIP}",
                          "cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4")
        extract_file(source, EDITOR_ZIP.removesuffix(".zip"), editor, 0o755)
    version = subprocess.check_output([editor, "--version"], text=True).strip()
    if not version.startswith(f"{GODOT_VERSION}.stable."):
        raise ValueError(f"Expected Godot {GODOT_VERSION}.stable, found {version}")

    templates = cache / "godot-data/godot/export_templates" / f"{GODOT_VERSION}.stable"
    if not (templates / "android_source.zip").is_file():
        source = download(cache, f"{GODOT_RELEASE}/{TEMPLATES}",
                          "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011")
        extract_file(source, "templates/version.txt", templates / "version.txt")
        extract_file(source, "templates/android_source.zip", templates / "android_source.zip")
    vendor = download(cache, VENDORS_URL, "2a3958fff0de2dbdc4f1a036b5e4cfcea12ae7e45f8deebf4b45e5e9718c4e35")
    return editor, vendor


def java_home():
    candidates = []
    if os.environ.get("JAVA_HOME"):
        candidates.append(Path(os.environ["JAVA_HOME"]))
    candidates.extend(sorted(Path("/usr/lib/jvm").glob("java-17-openjdk*")))
    if shutil.which("javac"):
        candidates.append(Path(shutil.which("javac")).resolve().parents[1])
    if shutil.which("flatpak"):
        extension = subprocess.run(["flatpak", "info", "--show-location",
                                    "org.freedesktop.Sdk.Extension.openjdk17//25.08"],
                                   capture_output=True, text=True)
        if extension.returncode == 0:
            candidates.append(Path(extension.stdout.strip()) / "files/jvm/openjdk-17")
    for candidate in candidates:
        javac = candidate / "bin/javac"
        if javac.is_file() and subprocess.check_output([javac, "-version"], text=True).startswith("javac 17"):
            return candidate.resolve()
    raise ValueError("Install OpenJDK 17 (openjdk-17-jdk on Kubuntu) or set JAVA_HOME to that JDK.")


def sdk_path(cache):
    configured = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if configured:
        return Path(configured).expanduser().resolve()
    installed = Path.home() / "Android/Sdk"
    return installed if installed.is_dir() else cache / "sdk"


def ensure_android_sdk(cache, sdk, env):
    required = {
        "platform-tools": sdk / "platform-tools/adb",
        f"platforms;android-{API}": sdk / f"platforms/android-{API}/android.jar",
        f"build-tools;{BUILD_TOOLS}": sdk / "build-tools" / BUILD_TOOLS / "apksigner",
    }
    missing = [name for name, path in required.items() if not path.is_file()]
    if not missing:
        return
    manager = sdk / "cmdline-tools/latest/bin/sdkmanager"
    if not manager.is_file():
        tools = cache / "command-line-19"
        manager = tools / "cmdline-tools/bin/sdkmanager"
        if not manager.is_file():
            archive = download(cache, SDK_TOOLS_URL, "7ec965280a073311c339e571cd5de778b9975026cfcbe79f2b1cdcb1e15317ee")
            with TemporaryDirectory(dir=cache) as tmp:
                unpacked = Path(tmp) / "unpacked"
                subprocess.run(["unzip", "-q", archive, "-d", unpacked], check=True)
                unpacked.rename(tools)
    sdk.mkdir(parents=True, exist_ok=True)
    subprocess.run([manager, f"--sdk_root={sdk}", *missing], env=env, check=True)
    if any(not path.is_file() for path in required.values()):
        raise ValueError("Android SDK setup is incomplete. Run ./build_apk and finish the SDK Manager prompt.")


def install_vendor(archive, project):
    prefix = "asset/addons/godotopenxrvendors/"
    destination = project / "addons/godotopenxrvendors"
    # Always use one complete, pinned plugin, including its hidden native libraries.
    if destination.exists():
        shutil.rmtree(destination)
    with ZipFile(archive) as source:
        for member in source.infolist():
            if member.filename.startswith(prefix) and not member.is_dir():
                path = destination / member.filename.removeprefix(prefix)
                path.parent.mkdir(parents=True, exist_ok=True)
                with source.open(member) as src, path.open("wb") as out:
                    shutil.copyfileobj(src, out)
