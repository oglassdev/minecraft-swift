#!/usr/bin/env python3
"""Prepare an ignored, exact-version Java reference for behavior comparisons."""

from __future__ import annotations

import csv
import hashlib
import json
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
from import_assets import ROOT, client_archive, load_version, read_url, write_if_changed


MAPPINGS_COMMIT = "36d1f9628bc2532f827d2aab94da6a58251d1860"
DECOMPILER_VERSION = "1.12.0"
DECOMPILER_SHA256 = "1dfcfe974395734fa467ce620661c7623d05ba83670de0529b1fbd63ff548b9d"


def main() -> None:
    cache = ROOT / ".build/reference"
    archive = client_archive(cache, load_version(cache))
    for name in ("classes.csv", "fields.csv", "methods.csv"):
        url = f"https://raw.githubusercontent.com/ModificationStation/1.7.3-LTS/{MAPPINGS_COMMIT}/conf/b1.7.3/{name}"
        write_if_changed(cache / name, read_url(url))

    decompiler = cache / f"vineflower-{DECOMPILER_VERSION}.jar"
    if not decompiler.exists() or hashlib.sha256(decompiler.read_bytes()).hexdigest() != DECOMPILER_SHA256:
        data = read_url(
            f"https://github.com/Vineflower/vineflower/releases/download/{DECOMPILER_VERSION}/vineflower-{DECOMPILER_VERSION}.jar"
        )
        if hashlib.sha256(data).hexdigest() != DECOMPILER_SHA256:
            raise ValueError("Vineflower SHA256 verification failed")
        write_if_changed(decompiler, data)

    java = shutil.which("java")
    if java is None:
        raise RuntimeError("A Java 17+ runtime is required for the reference decompiler")
    source = cache / "decompiled"
    marker = source / ".complete"
    if not marker.exists():
        source.mkdir(parents=True, exist_ok=True)
        with (cache / "decompile.log").open("w") as log:
            subprocess.run([java, "-jar", str(decompiler), "-log=WARN", str(archive), str(source)],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        marker.write_text(DECOMPILER_VERSION + "\n")

    names = {}
    with (cache / "classes.csv").open(newline="") as mapping_file:
        for row in csv.DictReader(mapping_file):
            original = source / (row["notch"] + ".java")
            if row["side"] != "0" or not original.exists():
                continue
            destination = cache / "named" / (row["name"] + ".java")
            write_if_changed(destination, original.read_bytes())
            names[row["name"]] = str(original.relative_to(cache))
    write_if_changed(cache / "client-classes.json", (json.dumps(names, indent=2, sort_keys=True) + "\n").encode())
    print(f"Prepared {len(names)} client classes at {source} and named reading copies at {cache / 'named'}")
    print("The named copies retain obfuscated declarations and are for reading, not recompilation.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Reference preparation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
