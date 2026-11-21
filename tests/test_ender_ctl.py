#!/usr/bin/env python3
"""Unit tests for the Ender-OS ender-ctl management CLI."""

from __future__ import annotations

import contextlib
import importlib.machinery
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENDER_CTL_PATH = ROOT / "system_files" / "shared" / "usr" / "bin" / "ender-ctl"
SHARED_SHARE_DIR = ROOT / "system_files" / "shared" / "usr" / "share" / "ender-os"


def load_ender_ctl():
    loader = importlib.machinery.SourceFileLoader("ender_ctl", str(ENDER_CTL_PATH))
    spec = importlib.util.spec_from_loader("ender_ctl", loader)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules["ender_ctl"] = module
    loader.exec_module(module)
    return module


ender_ctl = load_ender_ctl()


class EnderCtlTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.commands: list[list[str]] = []
        self.flatpak_apps: set[str] = set()
        self.tools = {
            "powerprofilesctl": "/usr/bin/powerprofilesctl",
            "scxctl": "/usr/bin/scxctl",
            "distrobox": "/usr/bin/distrobox",
            "flatpak": "/usr/bin/flatpak",
            "bootc": "/usr/bin/bootc",
            "podman": "/usr/bin/podman",
            "gamescope": "/usr/bin/gamescope",
            "mangohud": "/usr/bin/mangohud",
            "vulkaninfo": "/usr/bin/vulkaninfo",
            "sudo": "/usr/bin/sudo",
        }
        self.os_release = self.home / "os-release"
        self.os_release.write_text(
            'PRETTY_NAME="Ender-OS 45 (Hyprland • AMD / Intel Mesa)"\nOSTREE_VERSION="45.20261121"\n',
            encoding="utf-8",
        )
        self.ctx = ender_ctl.AppContext(
            home=self.home,
            share_dir=SHARED_SHARE_DIR,
            os_release_path=self.os_release,
            runner=self._fake_runner,
            which=lambda name: self.tools.get(name),
            is_root=lambda: False,
        )

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _fake_runner(self, cmd, capture=True):
        cmd_list = list(cmd)
        self.commands.append(cmd_list)
        if cmd_list[:2] == ["bootc", "status"]:
            return ender_ctl.CommandResult(returncode=0, stdout='{"spec":{"image":{"image":"ghcr.io/enderkingtr/ender-os-hyprland:latest"}}}')
        if cmd_list[:2] == ["flatpak", "info"] and len(cmd_list) >= 3:
            installed = cmd_list[2] in self.flatpak_apps
            return ender_ctl.CommandResult(returncode=0 if installed else 1, stdout="")
        return ender_ctl.CommandResult(returncode=0, stdout="")

    def _run_cli(self, *argv: str) -> tuple[int, str, str]:
        out = io.StringIO()
        err = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = ender_ctl.main(argv, ctx=self.ctx)
        return rc, out.getvalue(), err.getvalue()

    def test_theme_list_set_and_invalid(self) -> None:
        rc, out, _ = self._run_cli("theme", "list", "--plain")
        self.assertEqual(rc, 0)
        self.assertEqual(set(out.strip().splitlines()), {"ender-obsidian", "ender-nordic", "ender-crimson"})

        rc, _, _ = self._run_cli("theme", "set", "ender-nordic")
        self.assertEqual(rc, 0)

        rc, out, _ = self._run_cli("theme", "current")
        self.assertEqual(rc, 0)
        self.assertEqual(out.strip(), "ender-nordic")
        self.assertTrue((self.ctx.current_theme_link / "theme.json").is_file())

        rc, _, err = self._run_cli("theme", "set", "nonexistent-theme")
        self.assertEqual(rc, 2)
        self.assertIn("Unknown theme", err)

    def test_profile_set_toggle_and_invalid(self) -> None:
        rc, out, _ = self._run_cli("profile", "show", "--short")
        self.assertEqual(rc, 0)
        self.assertEqual(out.strip(), "balanced")

        rc, _, _ = self._run_cli("profile", "set", "gaming")
        self.assertEqual(rc, 0)
        self.assertIn(["powerprofilesctl", "set", "performance"], self.commands)
        self.assertIn(["scxctl", "switch", "--sched", "scx_lavd"], self.commands)

        rc, out, _ = self._run_cli("profile", "toggle-gaming")
        self.assertEqual(rc, 0)
        self.assertIn("balanced", out)

        rc, _, err = self._run_cli("profile", "set", "turbo-invalid")
        self.assertEqual(rc, 2)
        self.assertIn("Unknown profile", err)

    def test_devbox_list_create_dry_run_and_invalid(self) -> None:
        rc, out, _ = self._run_cli("devbox", "list", "--json")
        self.assertEqual(rc, 0)
        data = json.loads(out)
        self.assertIn("rust", data["stacks"])
        self.assertIn("cpp", data["stacks"])

        rc, out, _ = self._run_cli("devbox", "create", "rust", "--dry-run")
        self.assertEqual(rc, 0)
        self.assertIn("distrobox create --yes --name ender-rust", out)
        self.assertIn("distrobox-export", out)

        rc, _, err = self._run_cli("devbox", "create", "cobol")
        self.assertEqual(rc, 2)
        self.assertIn("Unknown stack", err)

    def test_gaming_check_and_setup_dry_run(self) -> None:
        rc, out, _ = self._run_cli("gaming", "check", "--json")
        self.assertEqual(rc, 0)
        checks = json.loads(out)
        self.assertFalse(checks["steam"])
        self.assertTrue(checks["gamescope"])
        self.assertTrue(checks["mangohud"])

        self.flatpak_apps.add("com.valvesoftware.Steam")
        rc, out, _ = self._run_cli("gaming", "check", "--json")
        self.assertEqual(rc, 0)
        checks_after = json.loads(out)
        self.assertTrue(checks_after["steam"])

        rc, out, _ = self._run_cli("gaming", "setup", "--group", "gaming", "--dry-run")
        self.assertEqual(rc, 0)
        self.assertIn("flatpak install -y --noninteractive flathub", out)
        self.assertIn("net.davidotek.pupgui2", out)

    def test_switch_update_rollback_dry_run(self) -> None:
        rc, out, _ = self._run_cli("switch", "plasma-nvidia", "--dry-run")
        self.assertEqual(rc, 0)
        self.assertIn("sudo bootc switch ghcr.io/enderkingtr/ender-os-plasma-nvidia:latest", out)

        rc, out, _ = self._run_cli("update", "--dry-run")
        self.assertEqual(rc, 0)
        self.assertIn("sudo bootc upgrade", out)

        rc, out, _ = self._run_cli("rollback", "--dry-run")
        self.assertEqual(rc, 0)
        self.assertIn("sudo bootc rollback", out)

        rc, _, err = self._run_cli("switch", "gnome")
        self.assertEqual(rc, 2)
        self.assertIn("Unknown edition", err)

    def test_status_and_doctor_json(self) -> None:
        rc, out, _ = self._run_cli("status", "--json")
        self.assertEqual(rc, 0)
        status = json.loads(out)
        self.assertEqual(status["profile"], "balanced")
        self.assertEqual(status["theme"], "ender-obsidian")
        self.assertTrue(status["bootc_available"])

        rc, out, _ = self._run_cli("doctor", "--json")
        self.assertEqual(rc, 0)
        doctor = json.loads(out)
        self.assertTrue(doctor["healthy"])
        self.assertGreaterEqual(len(doctor["checks"]), 8)

    def test_init_self_heals_missing_user_defaults(self) -> None:
        self.assertFalse(self.ctx.profile_file.exists())
        self.assertFalse(self.ctx.theme_file.exists())
        self.assertFalse(self.ctx.current_theme_link.exists())

        rc, _, _ = self._run_cli("init")
        self.assertEqual(rc, 0)
        self.assertEqual(self.ctx.profile_file.read_text(encoding="utf-8").strip(), "balanced")
        self.assertEqual(self.ctx.theme_file.read_text(encoding="utf-8").strip(), "ender-obsidian")
        self.assertTrue((self.ctx.current_theme_link / "theme.json").is_file())


if __name__ == "__main__":
    unittest.main()
