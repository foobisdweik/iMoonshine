#!/usr/bin/env python3

import json
import os
import plistlib
import sys
import zipfile
from dataclasses import dataclass
from typing import Iterable


METADATA_SUFFIXES = (
    "Metadata.appintents/extract.actionsdata",
    "Metadata.appintents/version.json",
)


@dataclass
class AuditResult:
    target: str
    kind: str
    app_infos: list[dict]
    metadata_files: list[str]
    nlu_files: list[str]


def _read_plist_from_zip(archive: zipfile.ZipFile, name: str) -> dict | None:
    try:
        with archive.open(name) as fh:
            return plistlib.load(fh)
    except Exception:
        return None


def _read_plist_from_disk(path: str) -> dict | None:
    try:
        with open(path, "rb") as fh:
            return plistlib.load(fh)
    except Exception:
        return None


def _summarize_info(path: str, info: dict | None) -> dict:
    if not info:
        return {"path": path, "error": "unreadable"}
    keys = (
        "CFBundleIdentifier",
        "CFBundleExecutable",
        "CFBundlePackageType",
        "NSExtension",
        "NSSupportsLiveActivities",
    )
    out = {"path": path}
    for key in keys:
        if key in info:
            out[key] = info[key]
    return out


def audit_ipa(path: str) -> AuditResult:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        info_paths = []
        for name in names:
            if not name.endswith("Info.plist") or not name.startswith("Payload/"):
                continue
            if not (
                name.endswith(".app/Info.plist")
                or name.endswith(".appex/Info.plist")
            ):
                continue
            if "/Frameworks/" in name or ".bundle/" in name or ".storyboardc/" in name:
                continue
            if name.count(".app/") == 1 or ".appex/" in name:
                info_paths.append(name)
        app_infos = [
            _summarize_info(name, _read_plist_from_zip(archive, name))
            for name in sorted(info_paths)
        ]
        metadata_files = [
            name for name in names
            if any(name.endswith(suffix) for suffix in METADATA_SUFFIXES)
        ]
        nlu_files = [name for name in names if "/nlu.appintents/" in name]
    return AuditResult(
        target=path,
        kind="ipa",
        app_infos=app_infos,
        metadata_files=metadata_files,
        nlu_files=nlu_files,
    )


def audit_app(path: str) -> AuditResult:
    info_paths = []
    metadata_files = []
    nlu_files = []

    for root, _, files in os.walk(path):
        for file_name in files:
            full_path = os.path.join(root, file_name)
            rel_path = os.path.relpath(full_path, path)
            if file_name == "Info.plist" and (".appex" in rel_path or rel_path == "Info.plist"):
                info_paths.append(rel_path)
            if any(rel_path.endswith(suffix) for suffix in METADATA_SUFFIXES):
                metadata_files.append(rel_path)
            if f"{os.sep}nlu.appintents{os.sep}" in full_path:
                nlu_files.append(rel_path)

    app_infos = [
        _summarize_info(rel_path, _read_plist_from_disk(os.path.join(path, rel_path)))
        for rel_path in sorted(info_paths)
    ]
    return AuditResult(
        target=path,
        kind="app",
        app_infos=app_infos,
        metadata_files=sorted(metadata_files),
        nlu_files=sorted(nlu_files),
    )


def audit_target(path: str) -> AuditResult:
    if path.endswith(".ipa"):
        return audit_ipa(path)
    if path.endswith(".app") and os.path.isdir(path):
        return audit_app(path)
    raise SystemExit(f"Unsupported target: {path}")


def print_human(results: Iterable[AuditResult]) -> None:
    for result in results:
        print(f"Target: {result.target}")
        print(f"Kind:   {result.kind}")
        print("Info.plist summary:")
        for info in result.app_infos:
            print(f"  - {info['path']}")
            for key, value in info.items():
                if key == "path":
                    continue
                print(f"    {key}: {value}")
        print("Metadata.appintents files:")
        if result.metadata_files:
            for name in result.metadata_files:
                print(f"  - {name}")
        else:
            print("  - <none>")
        print("nlu.appintents files:")
        if result.nlu_files:
            for name in result.nlu_files:
                print(f"  - {name}")
        else:
            print("  - <none>")
        print()


def main(argv: list[str]) -> int:
    json_mode = False
    paths = []
    for arg in argv[1:]:
        if arg == "--json":
            json_mode = True
        else:
            paths.append(arg)
    if not paths:
        raise SystemExit("usage: appintents_audit.py [--json] <app-or-ipa> [...]")

    results = [audit_target(path) for path in paths]
    if json_mode:
        print(json.dumps([result.__dict__ for result in results], indent=2))
    else:
        print_human(results)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
