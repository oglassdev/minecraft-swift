#!/usr/bin/env python3
"""Import verified vanilla resources locally without adding game files to Git."""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys
import time
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parent.parent
VERSION = "b1.7.3"
VERSION_METADATA_SHA1 = "44f6969326bd45aa00dcd3c4ca3a7c05ebb24c04"
CLIENT_SHA1 = "43db9b498cb67058d2e12d394e6507722e71bb45"
VERSION_MANIFEST = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
ASSET_CDN = "https://resources.download.minecraft.net"
BETA_SOUND_EVENTS = frozenset("""
    ambient.cave.cave ambient.weather.rain ambient.weather.thunder fire.fire fire.ignite liquid.water
    mob.chicken mob.chickenhurt mob.chickenplop mob.cow mob.cowhurt mob.creeper mob.creeperdeath
    mob.ghast.charge mob.ghast.death mob.ghast.fireball mob.ghast.moan mob.ghast.scream
    mob.pig mob.pigdeath mob.sheep mob.skeleton mob.skeletonhurt mob.slime mob.slimeattack
    mob.spider mob.spiderdeath mob.wolf.bark mob.wolf.death mob.wolf.growl mob.wolf.hurt
    mob.wolf.panting mob.wolf.shake mob.wolf.whine mob.zombie mob.zombiedeath mob.zombiehurt
    mob.zombiepig.zpig mob.zombiepig.zpigangry mob.zombiepig.zpigdeath mob.zombiepig.zpighurt
    note.harp note.bassattack note.bd note.snare note.hat portal.portal portal.travel portal.trigger
    random.bow random.click random.door_close random.door_open random.drr random.explode
    random.fizz random.fuse random.glass random.hurt random.pop random.splash
    step.cloth step.grass step.gravel step.sand step.snow step.stone step.wood
    tile.piston.in tile.piston.out
""".split())


def read_url(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "MinecraftSwift-LocalImporter/1"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read()
        except OSError:
            if attempt == 2:
                raise
            time.sleep(attempt + 1)
    raise AssertionError("unreachable")


def digest(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def download_verified(url: str, destination: Path, sha1: str, size: int | None = None) -> bytes:
    if destination.is_file():
        cached = destination.read_bytes()
        if digest(cached) == sha1 and (size is None or len(cached) == size):
            return cached
    data = read_url(url)
    if digest(data) != sha1 or (size is not None and len(data) != size):
        raise ValueError(f"Checksum or size mismatch for {url}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".download")
    temporary.write_bytes(data)
    temporary.replace(destination)
    return data


def load_version(cache: Path) -> dict:
    cached_path = cache / f"{VERSION}.json"
    cached = cached_path.read_bytes() if cached_path.is_file() else b""
    if digest(cached) == VERSION_METADATA_SHA1:
        metadata = json.loads(cached)
    else:
        manifest = json.loads(read_url(VERSION_MANIFEST))
        entry = next(version for version in manifest["versions"] if version["id"] == VERSION)
        if entry["sha1"] != VERSION_METADATA_SHA1:
            raise ValueError("Official version metadata changed; revalidate the pinned reference before updating")
        metadata = json.loads(download_verified(entry["url"], cached_path, VERSION_METADATA_SHA1))
    if metadata["id"] != VERSION or metadata["downloads"]["client"]["sha1"] != CLIENT_SHA1:
        raise ValueError("Version metadata does not match the pinned Beta 1.7.3 client")
    return metadata


def client_archive(cache: Path, metadata: dict) -> Path:
    client = metadata["downloads"]["client"]
    destination = cache / f"{VERSION}.jar"
    download_verified(client["url"], destination, CLIENT_SHA1, client["size"])
    return destination


def safe_path(name: str) -> Path:
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or "\\" in name:
        raise ValueError(f"Unsafe asset path: {name}")
    return Path(*path.parts)


def write_if_changed(destination: Path, data: bytes) -> None:
    if destination.is_file() and destination.read_bytes() == data:
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)


def extract_client(archive: Path, output: Path) -> dict[str, dict]:
    files = {}
    with zipfile.ZipFile(archive) as client:
        for entry in client.infolist():
            if entry.is_dir() or PurePosixPath(entry.filename).suffix not in {".png", ".txt", ".lang"}:
                continue
            data = client.read(entry)
            write_if_changed(output / safe_path(entry.filename), data)
            files[entry.filename] = {"sha1": digest(data), "size": len(data), "source": "client"}
    return files


def import_legacy_assets(cache: Path, output: Path, metadata: dict, workers: int) -> dict[str, dict]:
    info = metadata["assetIndex"]
    index = json.loads(download_verified(info["url"], cache / f"{info['id']}.json", info["sha1"], info["size"]))
    objects = index["objects"]
    unique = {entry["hash"]: entry for entry in objects.values()}

    def fetch(item: tuple[str, dict]) -> None:
        sha1, entry = item
        download_verified(
            f"{ASSET_CDN}/{sha1[:2]}/{sha1}", cache / "objects" / sha1[:2] / sha1,
            sha1, entry["size"],
        )

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        for completed, _ in enumerate(pool.map(fetch, unique.items()), 1):
            if completed % 100 == 0 or completed == len(unique):
                print(f"Verified {completed}/{len(unique)} legacy asset objects", flush=True)
    files = {}
    for name, entry in sorted(objects.items()):
        data = (cache / "objects" / entry["hash"][:2] / entry["hash"]).read_bytes()
        write_if_changed(output / safe_path(name), data)
        files[name] = {"sha1": entry["hash"], "size": entry["size"], "source": info["id"]}
    return files


def sound_manifest(files: dict[str, dict]) -> dict:
    effects: dict[str, list[str]] = {}
    music = []
    records: dict[str, list[str]] = {}
    for name in sorted(files):
        path = PurePosixPath(name)
        if path.suffix != ".ogg":
            continue
        directory, _, relative = name.partition("/")
        key = str(PurePosixPath(relative).with_suffix("")).replace("/", ".")
        if directory in {"sound", "newsound"}:
            key = re.sub(r"\d+$", "", key)
            effects.setdefault(key, []).append(name)
        elif directory in {"music", "newmusic"}:
            music.append(name)
        elif directory == "streaming":
            records.setdefault(key, []).append(name)
    return {
        "effects": {key: paths for key, paths in effects.items() if key in BETA_SOUND_EVENTS},
        "music": music,
        "records": records,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "Apple/Resources/Vanilla")
    parser.add_argument("--cache", type=Path, default=ROOT / ".build/reference")
    parser.add_argument("--textures-only", action="store_true", help="Skip the shared legacy resource index")
    parser.add_argument("--workers", type=int, choices=range(1, 17), default=8, metavar="1..16")
    arguments = parser.parse_args()
    output = arguments.output.resolve()
    metadata = load_version(arguments.cache)
    archive = client_archive(arguments.cache, metadata)
    files = extract_client(archive, output)
    client_count = len(files)
    if not arguments.textures_only:
        legacy = import_legacy_assets(arguments.cache, output, metadata, arguments.workers)
        duplicates = set(files) & set(legacy)
        if duplicates:
            raise ValueError(f"Client and legacy resource paths overlap: {sorted(duplicates)}")
        files.update(legacy)
    manifest = {
        "version": VERSION,
        "clientSHA1": CLIENT_SHA1,
        "assetIndex": None if arguments.textures_only else metadata["assetIndex"],
        "note": "Client PNGs are exact Beta 1.7.3. The official pre-1.6 resource index is shared across legacy versions.",
        "files": files,
    }
    write_if_changed(output / "asset-manifest.json", (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode())
    sounds = sound_manifest(files)
    write_if_changed(output / "sounds.json", (json.dumps(sounds, indent=2, sort_keys=True) + "\n").encode())
    print(f"Imported {client_count} client resources and {len(files) - client_count} legacy resources into {output}")
    print(f"Mapped {len(sounds['effects'])} sound events, {len(sounds['music'])} music tracks, and {len(sounds['records'])} records")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"Asset import failed: {error}", file=sys.stderr)
        raise SystemExit(1)
