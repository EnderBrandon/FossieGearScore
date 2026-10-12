"""Build an installable ZIP from the addon's TOC and media files."""

import argparse
from pathlib import Path, PurePosixPath
import re
import zipfile


def package_addon(output=None):
    root = Path(__file__).resolve().parents[1]
    addon = root / "FossieGearScore"
    toc = addon / "FossieGearScore.toc"
    toc_text = toc.read_text(encoding="utf-8")
    version = re.search(r"^## Version:\s*(\d+\.\d+\.\d+)\s*$", toc_text, re.M)
    if not version:
        raise ValueError("The TOC must specify a version.")
    version = version.group(1)
    code_version = re.search(r'NS.VERSION\s*=\s*"([^"]+)"', (addon / "Weights.lua").read_text())
    if not code_version or code_version.group(1) != version:
        raise ValueError("The code and TOC versions must match.")

    files = {toc}
    for line in toc_text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        relative = PurePosixPath(line.replace("\\", "/"))
        source = (addon / relative).resolve()
        if not source.is_relative_to(addon.resolve()) or not source.is_file():
            raise ValueError(f"Missing or invalid TOC file: {line}")
        files.add(source)
    files.update(p for p in (addon / "Media").rglob("*") if p.is_file()
                 and p.suffix.lower() in {".tga", ".blp", ".png", ".jpg", ".jpeg", ".ogg", ".mp3", ".wav"})

    output = Path(output) if output else root / "releases" / f"FossieGS-{version}.zip"
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(".zip.tmp")
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for source in sorted(files):
                name = source.relative_to(root).as_posix()
                info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                archive.writestr(info, source.read_bytes(), compresslevel=9)
        with zipfile.ZipFile(temporary) as archive:
            names = archive.namelist()
            if archive.testzip() or any("readme" in Path(name).name.lower() for name in names):
                raise ValueError("Package validation failed.")
            if len(names) != len(files) or any(not name.startswith("FossieGearScore/") for name in names):
                raise ValueError("Package layout is invalid.")
        temporary.replace(output)
    finally:
        temporary.unlink(missing_ok=True)
    return output, len(files)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Optional output ZIP path.")
    args = parser.parse_args()
    output, count = package_addon(args.output)
    print(f"Built {output} ({count} runtime files; no README or tests).")
