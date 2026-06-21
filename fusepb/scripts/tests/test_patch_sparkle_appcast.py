"""Tests for fusepb/scripts/patch_sparkle_appcast.py."""

import pathlib
import sys
import textwrap
import xml.etree.ElementTree as ET

import pytest

SCRIPTS_DIR = pathlib.Path(__file__).parent.parent
sys.path.insert(0, str(SCRIPTS_DIR))

from patch_sparkle_appcast import main  # noqa: E402


SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"

APPCAST_TEMPLATE = textwrap.dedent("""\
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:sparkle="{ns}">
      <channel>
        <item>
          <sparkle:shortVersionString>1.6.0</sparkle:shortVersionString>
          <sparkle:releaseNotesLink>https://example.com/placeholder</sparkle:releaseNotesLink>
          <enclosure url="https://example.com/old.zip"
                     sparkle:version="42"
                     length="12345"
                     type="application/octet-stream"/>
        </item>
      </channel>
    </rss>
""").format(ns=SPARKLE_NS)

APPCAST_NO_VERSION = textwrap.dedent("""\
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:sparkle="{ns}">
      <channel>
        <item>
          <sparkle:releaseNotesLink>https://example.com/placeholder</sparkle:releaseNotesLink>
          <enclosure url="https://example.com/old.zip"/>
        </item>
      </channel>
    </rss>
""").format(ns=SPARKLE_NS)

APPCAST_FALLBACK_VERSION = textwrap.dedent("""\
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:sparkle="{ns}">
      <channel>
        <item>
          <sparkle:version>43</sparkle:version>
          <sparkle:releaseNotesLink>https://example.com/placeholder</sparkle:releaseNotesLink>
          <enclosure url="https://example.com/old.zip"/>
        </item>
      </channel>
    </rss>
""").format(ns=SPARKLE_NS)


def run_main(args, monkeypatch):
    """Run main() with the given sys.argv list and return the exit code."""
    monkeypatch.setattr(sys, "argv", ["patch_sparkle_appcast.py"] + args)
    return main()


def read_appcast(path):
    return ET.parse(path).getroot()


class TestPatchSparkleAppcast:
    def test_patches_release_notes_url(self, tmp_path, monkeypatch):
        appcast_path = tmp_path / "appcast.xml"
        appcast_path.write_text(APPCAST_TEMPLATE, encoding="utf-8")

        rc = run_main(
            [
                "--appcast", str(appcast_path),
                "--release-notes-url-prefix", "https://fmeunier.github.io/fuse-for-macos/release-notes/",
            ],
            monkeypatch,
        )

        assert rc == 0
        root = read_appcast(appcast_path)
        notes_tag = f"{{{SPARKLE_NS}}}releaseNotesLink"
        notes_node = root.find(f"./channel/item/{notes_tag}")
        assert notes_node is not None
        assert notes_node.text == "https://fmeunier.github.io/fuse-for-macos/release-notes/1.6.0.md"

    def test_patches_enclosure_url(self, tmp_path, monkeypatch):
        appcast_path = tmp_path / "appcast.xml"
        appcast_path.write_text(APPCAST_TEMPLATE, encoding="utf-8")

        rc = run_main(
            [
                "--appcast", str(appcast_path),
                "--enclosure-url", "https://github.com/fmeunier/fuse-for-macos/releases/download/v1.6.0/Fuse.zip",
            ],
            monkeypatch,
        )

        assert rc == 0
        root = read_appcast(appcast_path)
        enclosure = root.find("./channel/item/enclosure")
        assert enclosure is not None
        assert enclosure.get("url") == "https://github.com/fmeunier/fuse-for-macos/releases/download/v1.6.0/Fuse.zip"

    def test_patches_both_release_notes_and_enclosure(self, tmp_path, monkeypatch):
        appcast_path = tmp_path / "appcast.xml"
        appcast_path.write_text(APPCAST_TEMPLATE, encoding="utf-8")

        rc = run_main(
            [
                "--appcast", str(appcast_path),
                "--release-notes-url-prefix", "https://example.com/notes/",
                "--enclosure-url", "https://example.com/Fuse.zip",
            ],
            monkeypatch,
        )

        assert rc == 0
        root = read_appcast(appcast_path)
        notes_tag = f"{{{SPARKLE_NS}}}releaseNotesLink"
        notes_node = root.find(f"./channel/item/{notes_tag}")
        enclosure = root.find("./channel/item/enclosure")
        assert notes_node.text == "https://example.com/notes/1.6.0.md"
        assert enclosure.get("url") == "https://example.com/Fuse.zip"

    def test_uses_fallback_version_tag(self, tmp_path, monkeypatch):
        appcast_path = tmp_path / "appcast.xml"
        appcast_path.write_text(APPCAST_FALLBACK_VERSION, encoding="utf-8")

        rc = run_main(
            [
                "--appcast", str(appcast_path),
                "--release-notes-url-prefix", "https://example.com/notes/",
            ],
            monkeypatch,
        )

        assert rc == 0
        root = read_appcast(appcast_path)
        notes_tag = f"{{{SPARKLE_NS}}}releaseNotesLink"
        notes_node = root.find(f"./channel/item/{notes_tag}")
        assert notes_node.text == "https://example.com/notes/43.md"

    def test_missing_both_args_returns_error(self, tmp_path, monkeypatch):
        appcast_path = tmp_path / "appcast.xml"
        appcast_path.write_text(APPCAST_TEMPLATE, encoding="utf-8")

        rc = run_main(["--appcast", str(appcast_path)], monkeypatch)

        assert rc != 0

    def test_missing_version_tag_returns_error(self, tmp_path, monkeypatch):
        appcast_path = tmp_path / "appcast.xml"
        appcast_path.write_text(APPCAST_NO_VERSION, encoding="utf-8")

        rc = run_main(
            [
                "--appcast", str(appcast_path),
                "--release-notes-url-prefix", "https://example.com/notes/",
            ],
            monkeypatch,
        )

        assert rc != 0

    def test_missing_appcast_file_returns_error(self, tmp_path, monkeypatch):
        rc = run_main(
            [
                "--appcast", str(tmp_path / "nonexistent.xml"),
                "--enclosure-url", "https://example.com/Fuse.zip",
            ],
            monkeypatch,
        )

        assert rc != 0
