"""Tests for fusepb/scripts/extract_release_notes.py."""

import pathlib
import sys
import textwrap

import pytest

SCRIPTS_DIR = pathlib.Path(__file__).parent.parent
sys.path.insert(0, str(SCRIPTS_DIR))

from extract_release_notes import main  # noqa: E402


CHANGELOG_MULTI = textwrap.dedent("""\
    # Fuse for macOS changelog

    ## What's new in Fuse for macOS 1.6.0

    - Added Sparkle auto-update support
    - Updated libspectrum to 1.6.2

    ## What's new in Fuse for macOS 1.5.0

    - Initial Apple Silicon build
    - Fixed memory leak in preview provider
""")

CHANGELOG_SINGLE = textwrap.dedent("""\
    # Fuse for macOS changelog

    ## What's new in Fuse for macOS 1.6.0

    - Added Sparkle auto-update support
""")


def run_main(args, monkeypatch):
    """Run main() with the given sys.argv list and return the exit code."""
    monkeypatch.setattr(sys, "argv", ["extract_release_notes.py"] + args)
    return main()


class TestExtractReleaseNotes:
    def test_extracts_correct_version_section(self, tmp_path, monkeypatch):
        input_path = tmp_path / "changelog.md"
        output_path = tmp_path / "1.6.0.md"
        input_path.write_text(CHANGELOG_MULTI, encoding="utf-8")

        rc = run_main(
            ["--input", str(input_path), "--version", "1.6.0", "--output", str(output_path)],
            monkeypatch,
        )

        assert rc == 0
        output = output_path.read_text(encoding="utf-8")
        assert "## What's new in Fuse for macOS 1.6.0" in output
        assert "Added Sparkle auto-update support" in output
        assert "Updated libspectrum to 1.6.2" in output

    def test_does_not_include_next_version_section(self, tmp_path, monkeypatch):
        input_path = tmp_path / "changelog.md"
        output_path = tmp_path / "1.6.0.md"
        input_path.write_text(CHANGELOG_MULTI, encoding="utf-8")

        rc = run_main(
            ["--input", str(input_path), "--version", "1.6.0", "--output", str(output_path)],
            monkeypatch,
        )

        assert rc == 0
        output = output_path.read_text(encoding="utf-8")
        assert "1.5.0" not in output
        assert "Initial Apple Silicon build" not in output

    def test_extracts_older_version_section(self, tmp_path, monkeypatch):
        input_path = tmp_path / "changelog.md"
        output_path = tmp_path / "1.5.0.md"
        input_path.write_text(CHANGELOG_MULTI, encoding="utf-8")

        rc = run_main(
            ["--input", str(input_path), "--version", "1.5.0", "--output", str(output_path)],
            monkeypatch,
        )

        assert rc == 0
        output = output_path.read_text(encoding="utf-8")
        assert "## What's new in Fuse for macOS 1.5.0" in output
        assert "Initial Apple Silicon build" in output
        assert "1.6.0" not in output

    def test_single_version_changelog(self, tmp_path, monkeypatch):
        input_path = tmp_path / "changelog.md"
        output_path = tmp_path / "1.6.0.md"
        input_path.write_text(CHANGELOG_SINGLE, encoding="utf-8")

        rc = run_main(
            ["--input", str(input_path), "--version", "1.6.0", "--output", str(output_path)],
            monkeypatch,
        )

        assert rc == 0
        output = output_path.read_text(encoding="utf-8")
        assert "## What's new in Fuse for macOS 1.6.0" in output
        assert "Added Sparkle auto-update support" in output

    def test_output_ends_with_newline(self, tmp_path, monkeypatch):
        input_path = tmp_path / "changelog.md"
        output_path = tmp_path / "1.6.0.md"
        input_path.write_text(CHANGELOG_MULTI, encoding="utf-8")

        run_main(
            ["--input", str(input_path), "--version", "1.6.0", "--output", str(output_path)],
            monkeypatch,
        )

        output = output_path.read_text(encoding="utf-8")
        assert output.endswith("\n")

    def test_creates_output_parent_dirs(self, tmp_path, monkeypatch):
        input_path = tmp_path / "changelog.md"
        output_path = tmp_path / "subdir" / "nested" / "1.6.0.md"
        input_path.write_text(CHANGELOG_MULTI, encoding="utf-8")

        rc = run_main(
            ["--input", str(input_path), "--version", "1.6.0", "--output", str(output_path)],
            monkeypatch,
        )

        assert rc == 0
        assert output_path.exists()

    def test_missing_version_returns_error(self, tmp_path, monkeypatch):
        input_path = tmp_path / "changelog.md"
        output_path = tmp_path / "9.9.9.md"
        input_path.write_text(CHANGELOG_MULTI, encoding="utf-8")

        rc = run_main(
            ["--input", str(input_path), "--version", "9.9.9", "--output", str(output_path)],
            monkeypatch,
        )

        assert rc != 0

    def test_missing_input_file_returns_error(self, tmp_path, monkeypatch):
        input_path = tmp_path / "nonexistent.md"
        output_path = tmp_path / "out.md"

        rc = run_main(
            ["--input", str(input_path), "--version", "1.6.0", "--output", str(output_path)],
            monkeypatch,
        )

        assert rc != 0
