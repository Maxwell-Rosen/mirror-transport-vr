"""Build the optional source project ZIP for the Godot editor on Quest 3."""

from pathlib import Path
from tempfile import TemporaryDirectory
from zipfile import ZIP_DEFLATED, ZipFile

from quest_project import ROOT, stage_project


def build(root: Path) -> Path:
    output = root / "exports/MirrorTransport-Quest-Project.zip"
    output.parent.mkdir(exist_ok=True)
    with TemporaryDirectory(dir=output.parent) as staging:
        draft = Path(staging) / output.name
        project = Path(staging) / "project"
        stage_project(root, project)
        with ZipFile(draft, "x", compression=ZIP_DEFLATED, strict_timestamps=False) as archive:
            for path in sorted(project.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(project))
        with ZipFile(draft) as archive:
            damaged = archive.testzip()
            if damaged:
                raise ValueError(f"ZIP integrity check failed for {damaged}")
        draft.replace(output)
    return output


if __name__ == "__main__":
    archive = build(ROOT)
    print(f"{archive} ({archive.stat().st_size / 1_000_000:.2f} MB)")
