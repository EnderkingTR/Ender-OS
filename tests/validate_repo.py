#!/usr/bin/env python3
"""Static structural and syntax validation for the Ender-OS repository."""

from __future__ import annotations

import json
import py_compile
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

TEXT_SUFFIXES = {
    ".sh",
    ".py",
    ".toml",
    ".yml",
    ".yaml",
    ".json",
    ".jsonc",
    ".conf",
    ".css",
    ".rasi",
    ".just",
    ".desktop",
    ".rules",
    ".md",
    ".txt",
    ".env",
}
TEXT_NAMES = {"Containerfile", "Justfile", "LICENSE", ".gitignore", ".gitattributes", "ender-ctl", "ender-gamescope-session"}

REQUIRED_EDITIONS = ("hyprland", "hyprland-nvidia", "plasma", "plasma-nvidia")
REQUIRED_THEME_FILES = ("theme.json", "hyprland.conf", "waybar.css", "kitty.conf", "rofi.rasi")
FORBIDDEN_PATTERNS = (
    ("ublue-os/base-nvidia", "Deprecated retired NVIDIA base image"),
    ("ublue-os/kinoite-nvidia", "Deprecated retired NVIDIA base image"),
    ("solopasha/hyprland", "Abandoned Hyprland COPR repository"),
)


def strip_jsonc_comments(text: str) -> str:
    """Remove // line comments and /* */ block comments outside quoted strings."""
    out: list[str] = []
    i = 0
    in_str = False
    escape = False
    n = len(text)
    while i < n:
        ch = text[i]
        if in_str:
            out.append(ch)
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_str = False
            i += 1
            continue
        if ch == '"':
            in_str = True
            out.append(ch)
            i += 1
        elif ch == "/" and i + 1 < n and text[i + 1] == "/":
            i += 2
            while i < n and text[i] != "\n":
                i += 1
        elif ch == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def check_lf_and_forbidden(errors: list[str]) -> None:
    for path in ROOT.rglob("*"):
        if ".git" in path.parts or "__pycache__" in path.parts or not path.is_file():
            continue
        if path.suffix in TEXT_SUFFIXES or path.name in TEXT_NAMES:
            raw = path.read_bytes()
            rel = path.relative_to(ROOT)
            if b"\r\n" in raw:
                errors.append(f"CRLF line ending found in {rel}")
            text = raw.decode("utf-8", errors="strict")
            if path.suffix == ".sh":
                first_two = text.splitlines()[:2]
                has_shebang = bool(first_two and first_two[0].startswith("#!"))
                has_sc_directive = any(line.startswith("# shellcheck shell=") for line in first_two)
                if not (has_shebang or has_sc_directive):
                    errors.append(f"Shell script {rel} missing shebang or '# shellcheck shell=' directive")
            if rel.parts[0] != "docs" and rel.name != "README.md" and rel.as_posix() != "tests/validate_repo.py":
                for pattern, reason in FORBIDDEN_PATTERNS:
                    if pattern in text:
                        errors.append(f"Forbidden pattern '{pattern}' ({reason}) in {rel}")


def check_json_and_jsonc(errors: list[str]) -> None:
    for path in ROOT.rglob("*.json"):
        if ".git" in path.parts:
            continue
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"Invalid JSON in {path.relative_to(ROOT)}: {exc}")

    for path in ROOT.rglob("*.jsonc"):
        if ".git" in path.parts:
            continue
        cleaned = strip_jsonc_comments(path.read_text(encoding="utf-8"))
        try:
            json.loads(cleaned)
        except json.JSONDecodeError as exc:
            errors.append(f"Invalid JSONC in {path.relative_to(ROOT)}: {exc}")


def check_toml(errors: list[str]) -> None:
    for path in ROOT.rglob("*.toml"):
        if ".git" in path.parts:
            continue
        try:
            tomllib.loads(path.read_text(encoding="utf-8"))
        except tomllib.TOMLDecodeError as exc:
            errors.append(f"Invalid TOML in {path.relative_to(ROOT)}: {exc}")


def check_themes(errors: list[str]) -> None:
    themes_dir = ROOT / "system_files" / "shared" / "usr" / "share" / "ender-os" / "themes"
    if not themes_dir.is_dir():
        errors.append(f"Missing themes directory: {themes_dir.relative_to(ROOT)}")
        return
    dirs = [d for d in themes_dir.iterdir() if d.is_dir()]
    if len(dirs) < 3:
        errors.append(f"Expected at least 3 built-in themes, found {len(dirs)}")
    for theme_dir in dirs:
        for req in REQUIRED_THEME_FILES:
            if not (theme_dir / req).is_file():
                errors.append(f"Theme '{theme_dir.name}' missing required file '{req}'")


def check_containerfile_and_editions(errors: list[str]) -> None:
    cf = ROOT / "Containerfile"
    if not cf.is_file():
        errors.append("Missing Containerfile")
        return
    cf_text = cf.read_text(encoding="utf-8")
    lint_count = len(re.findall(r"^\s*RUN\s+bootc\s+container\s+lint\b", cf_text, re.MULTILINE))
    if lint_count < 2:
        errors.append(f"Expected 'RUN bootc container lint' in both final stages, found {lint_count}")
    if "FROM stage-common AS final-main" not in cf_text or "FROM stage-common AS final-nvidia-open" not in cf_text:
        errors.append("Containerfile missing final-main or final-nvidia-open target stage")

    for edition in REQUIRED_EDITIONS:
        iso_toml = ROOT / "disk_config" / f"iso-{edition}.toml"
        if not iso_toml.is_file():
            errors.append(f"Missing ISO kickstart config: {iso_toml.relative_to(ROOT)}")
        else:
            expected_ref = f"ghcr.io/enderkingtr/ender-os-{edition}:latest"
            if expected_ref not in iso_toml.read_text(encoding="utf-8"):
                errors.append(f"{iso_toml.relative_to(ROOT)} missing '{expected_ref}'")

    workflows_dir = ROOT / ".github" / "workflows"
    for wf_name in ("ci.yml", "build-images.yml", "build-iso.yml"):
        wf_path = workflows_dir / wf_name
        if not wf_path.is_file():
            errors.append(f"Missing workflow: {wf_path.relative_to(ROOT)}")
            continue
        wf_text = wf_path.read_text(encoding="utf-8")
        if "\t" in wf_text:
            errors.append(f"Tab indentation found in YAML workflow {wf_name}")
        if wf_name != "ci.yml":
            for edition in REQUIRED_EDITIONS:
                if edition not in wf_text:
                    errors.append(f"Workflow {wf_name} does not reference edition '{edition}'")


def check_python_syntax(errors: list[str]) -> None:
    targets = [
        ROOT / "system_files" / "shared" / "usr" / "bin" / "ender-ctl",
        ROOT / "tests" / "test_ender_ctl.py",
        ROOT / "tests" / "validate_repo.py",
    ]
    for path in targets:
        try:
            py_compile.compile(str(path), doraise=True)
        except py_compile.PyCompileError as exc:
            errors.append(f"Python syntax error in {path.relative_to(ROOT)}: {exc}")


def main() -> int:
    errors: list[str] = []
    check_lf_and_forbidden(errors)
    check_json_and_jsonc(errors)
    check_toml(errors)
    check_themes(errors)
    check_containerfile_and_editions(errors)
    check_python_syntax(errors)

    if errors:
        print("VALIDATION FAILED:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print("ALL VALIDATIONS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
