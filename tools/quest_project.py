"""Stage the game files shared by the standalone Quest APK and the editor ZIP."""

import re
import shutil
from collections.abc import Iterator
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT_FILES = ("openxr_action_map.tres",)
ASSET_DIRS = ("museum", "simulation-renders", "addons")
LOCAL_SUFFIXES = {".aab", ".apk", ".gkyl", ".jks", ".keystore", ".p12", ".pck", ".zip"}
QUEST_SETTINGS = {
    "rendering": ("textures/vram_compression/import_etc2_astc",),
    "xr": ("openxr/enabled", "shaders/enabled"),
}


def quest_project(config: str) -> str:
    """Set the headset options while preserving the rest of Godot's project file."""
    missing_sections = dict(QUEST_SETTINGS)
    section = ""
    lines = []
    for line in config.splitlines():
        header = re.fullmatch(r"\[([^\]]+)\]\s*(?:;.*)?", line.strip())
        if header:
            section = header.group(1)
            lines.append(line)
            for key in missing_sections.pop(section, ()):
                lines.append(f"{key}=true")
        elif line.partition("=")[0].strip() not in QUEST_SETTINGS.get(section, ()):
            lines.append(line)
    for section, keys in missing_sections.items():
        lines.extend(("", f"[{section}]"))
        lines.extend(f"{key}=true" for key in keys)
    return "\n".join(lines) + "\n"


def local_only(name: str) -> bool:
    return (
        (name.startswith(".") and name not in {".gdignore", ".bin"})
        or name == "__pycache__"
        or Path(name).suffix.lower() in LOCAL_SUFFIXES
    )


def asset_files(path: Path, roots: tuple[Path, ...], parents: tuple[Path, ...] = ()) -> Iterator[Path]:
    if local_only(path.name):
        return
    target = path.resolve(strict=True)
    if target != path:  # A gallery directory or one of its children may be a link.
        inside = next((root for root in roots if target.is_relative_to(root)), None)
        if inside is None or any(local_only(part) for part in target.relative_to(inside).parts):
            raise ValueError(f"Asset link points outside the packaged files: {path} -> {target}")
    if target in parents:
        raise ValueError(f"Directory link cycle at {path}")
    if target.is_dir():
        for child in sorted(path.iterdir()):
            yield from asset_files(child, roots, (*parents, target))
    elif target.is_file():
        yield path


def stage_project(root: Path, destination: Path, *, editor_deploy: bool = True) -> None:
    """Copy the current runtime assets and Quest settings into an empty build directory."""
    root = root.resolve()
    gallery_games = tuple(
        game for game in sorted(root.glob("gallery-*/game"))
        if re.fullmatch(r"gallery-[1-9][0-9]*", game.parent.name) and game.is_dir()
    )
    asset_roots = tuple(root / name for name in ASSET_DIRS) + gallery_games
    destination.mkdir()
    project = root / "project.godot"
    (destination / project.name).write_text(quest_project(project.read_text(encoding="utf-8")), encoding="utf-8")
    shutil.copystat(project, destination / project.name)
    preset = root / "tools/quest_export_presets.cfg"
    config = preset.read_text(encoding="utf-8")
    if not editor_deploy:
        # A runnable editor preset polls USB and may stop the user's ADB server on exit.
        config = config.replace("\nrunnable=true\n", "\nrunnable=false\n")
    (destination / "export_presets.cfg").write_text(config, encoding="utf-8")
    shutil.copystat(preset, destination / "export_presets.cfg")
    for name in PROJECT_FILES:
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / name, target)
    for directory in asset_roots:
        if directory.name == "addons" and not directory.exists() and not directory.is_symlink():
            continue
        for path in asset_files(directory, asset_roots):
            if directory.name == "simulation-renders" and path.stat().st_size >= 100_000_000:
                raise ValueError(f"Simulation asset must be under 100 MB: {path}")
            target = destination / path.relative_to(root)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
