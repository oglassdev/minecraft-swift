#!/usr/bin/env python3
"""Convert imported Beta audio into formats supported by the Apple app targets."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--resources",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "Apple/Resources/Vanilla",
    )
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    root = args.resources.resolve()
    manifest = json.loads((root / "sounds.json").read_text())
    effects = {name for files in manifest["effects"].values() for name in files}
    music = set(manifest["music"])
    records = {name for files in manifest["records"].values() for name in files}
    paths = {}

    for name in sorted(effects | music | records):
        original = Path(name)
        if original.is_absolute() or ".." in original.parts:
            raise ValueError(f"Unsafe asset path: {name}")
        extension = ".caf" if name in effects else ".m4a"
        paths[name] = str(Path("apple-audio") / original.with_suffix(extension))
        if not (root / name).is_file():
            raise FileNotFoundError(f"Missing imported audio: {name}")

    def convert(name):
        source = root / name
        destination = root / paths[name]
        if not args.force and destination.is_file() and destination.stat().st_mtime >= source.stat().st_mtime:
            return False
        if not args.ffmpeg:
            raise RuntimeError("ffmpeg is needed once at import time; install it or pass --ffmpeg.")
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = destination.with_name(destination.stem + ".tmp" + destination.suffix)
        command = [args.ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source), "-vn", "-map_metadata", "-1", "-ar", "44100"]
        if name in effects:
            command += ["-ac", "1", "-c:a", "pcm_s16le"]
        else:
            command += ["-c:a", "aac", "-b:a", "160k"]
        try:
            subprocess.run(command + [str(temporary)], check=True, capture_output=True)
            temporary.replace(destination)
        except subprocess.CalledProcessError as error:
            temporary.unlink(missing_ok=True)
            raise RuntimeError(f"Could not convert {name}: {error.stderr.decode(errors='replace')}") from error
        return True

    with ThreadPoolExecutor(max_workers=max(1, min(args.jobs, 16))) as pool:
        converted = sum(pool.map(convert, sorted(paths)))
    apple_manifest = {
        "effects": {event: [paths[name] for name in files] for event, files in manifest["effects"].items()},
        "music": [paths[name] for name in manifest["music"]],
        "records": {event: [paths[name] for name in files] for event, files in manifest["records"].items()},
    }
    (root / "sounds-apple.json").write_text(json.dumps(apple_manifest, indent=2) + "\n")
    print(f"Apple audio ready: {len(effects)} effect files, {len(music)} music tracks, {len(records)} records; {converted} converted, {len(paths) - converted} reused.")


if __name__ == "__main__":
    main()
