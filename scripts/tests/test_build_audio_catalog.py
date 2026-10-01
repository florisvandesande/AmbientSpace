from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS_DIRECTORY = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIRECTORY))

from build_audio_catalog import CatalogError, build_catalog, scan_tracks  # noqa: E402


class AudioCatalogBuilderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.source = self.root / "audio-files"
        self.destination = self.root / "bundle"
        self.source.mkdir()

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def create_track(
        self,
        folder_name: str,
        *,
        index: int = 1,
        color_start: str = "#18324A",
        color_end: str = "#6E8FA8",
    ) -> Path:
        track_directory = self.source / folder_name
        track_directory.mkdir()
        (track_directory / "audio.m4a").write_bytes(b"\x00\x00\x00\x18ftypM4A ")
        (track_directory / "cover.jpg").write_bytes(b"\xff\xd8\xff\xd9")
        (track_directory / "metadata.json").write_text(
            json.dumps(
                {
                    "index": index,
                    "title": f"Titel {index}",
                    "subtitle": "Subtitel",
                    "description": "Beschrijving",
                    "colorStart": color_start,
                    "colorEnd": color_end,
                }
            ),
            encoding="utf-8",
        )
        return track_directory

    def test_empty_source_creates_empty_catalog(self) -> None:
        catalog_path = build_catalog(self.source, self.destination)
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        self.assertEqual(catalog, {"schemaVersion": 1, "tracks": []})

    def test_tracks_are_sorted_by_index(self) -> None:
        self.create_track("laatste", index=20)
        self.create_track("eerste", index=2)
        catalog_path = build_catalog(self.source, self.destination)
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        self.assertEqual([track["id"] for track in catalog["tracks"]], ["eerste", "laatste"])

    def test_metadata_only_catalog_omits_media(self) -> None:
        self.create_track("rain", index=1)
        catalog_path = build_catalog(self.source, self.destination, metadata_only=True)
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))

        self.assertEqual(catalog["tracks"][0]["id"], "rain")
        self.assertFalse((catalog_path.parent / "rain").exists())

    def test_missing_file_is_rejected(self) -> None:
        track_directory = self.create_track("onvolledig")
        (track_directory / "cover.jpg").unlink()
        with self.assertRaisesRegex(CatalogError, "cover.jpg"):
            scan_tracks(self.source)

    def test_invalid_json_is_rejected(self) -> None:
        track_directory = self.create_track("ongeldig")
        (track_directory / "metadata.json").write_text("{", encoding="utf-8")
        with self.assertRaisesRegex(CatalogError, "invalid JSON"):
            scan_tracks(self.source)

    def test_duplicate_index_is_rejected(self) -> None:
        self.create_track("een", index=4)
        self.create_track("twee", index=4)
        with self.assertRaisesRegex(CatalogError, "Duplicate index 4"):
            scan_tracks(self.source)

    def test_invalid_hex_color_is_rejected(self) -> None:
        self.create_track("kleur", color_start="#12345")
        with self.assertRaisesRegex(CatalogError, "#RRGGBB"):
            scan_tracks(self.source)

    def test_stale_track_is_removed_from_next_build(self) -> None:
        track_directory = self.create_track("tijdelijk")
        build_catalog(self.source, self.destination)
        self.assertTrue((self.destination / "audio-files" / "tijdelijk").exists())

        for path in track_directory.iterdir():
            path.unlink()
        track_directory.rmdir()
        build_catalog(self.source, self.destination)

        self.assertFalse((self.destination / "audio-files" / "tijdelijk").exists())

    def test_output_cannot_replace_source_recordings(self) -> None:
        self.create_track("keep")
        with self.assertRaisesRegex(CatalogError, "overlap"):
            build_catalog(self.source, self.root)
        self.assertTrue((self.source / "keep" / "audio.m4a").is_file())

    def test_output_cannot_be_inside_source(self) -> None:
        with self.assertRaisesRegex(CatalogError, "overlap"):
            build_catalog(self.source, self.source / "nested")

    def test_invalid_translation_is_rejected(self) -> None:
        track = self.create_track("rain")
        path = track / "metadata.json"
        metadata = json.loads(path.read_text())
        metadata["translations"] = {"fr": {"title": "Pluie"}}
        path.write_text(json.dumps(metadata))
        with self.assertRaisesRegex(CatalogError, "translation 'fr'"):
            scan_tracks(self.source)

    def test_translations_are_included_in_catalog(self) -> None:
        track = self.create_track("rain")
        path = track / "metadata.json"
        metadata = json.loads(path.read_text())
        metadata["translations"] = {"fr": {"title": "Pluie", "subtitle": "Douce", "description": "Une averse."}}
        path.write_text(json.dumps(metadata))
        result = json.loads(build_catalog(self.source, self.destination).read_text())
        self.assertEqual(result["tracks"][0]["translations"], metadata["translations"])

    def test_empty_sf_symbol_is_treated_as_unconfigured(self) -> None:
        track = self.create_track("rain")
        path = track / "metadata.json"
        metadata = json.loads(path.read_text())
        metadata["sfSymbol"] = ""
        path.write_text(json.dumps(metadata))
        result = json.loads(build_catalog(self.source, self.destination).read_text())
        self.assertIsNone(result["tracks"][0]["sfSymbol"])

    def test_sf_symbol_is_trimmed_and_included(self) -> None:
        track = self.create_track("rain")
        path = track / "metadata.json"
        metadata = json.loads(path.read_text())
        metadata["sfSymbol"] = "  cloud.rain.fill  "
        path.write_text(json.dumps(metadata))
        result = json.loads(build_catalog(self.source, self.destination).read_text())
        self.assertEqual(result["tracks"][0]["sfSymbol"], "cloud.rain.fill")

    def test_non_string_sf_symbol_is_rejected(self) -> None:
        track = self.create_track("rain")
        path = track / "metadata.json"
        metadata = json.loads(path.read_text())
        metadata["sfSymbol"] = 42
        path.write_text(json.dumps(metadata))
        with self.assertRaisesRegex(CatalogError, "sfSymbol"):
            scan_tracks(self.source)

    def test_symlink_media_is_rejected(self) -> None:
        track = self.create_track("rain")
        (track / "cover.jpg").unlink()
        external = self.root / "external.jpg"
        external.write_bytes(b"\xff\xd8\xff\xd9")
        (track / "cover.jpg").symlink_to(external)
        with self.assertRaisesRegex(CatalogError, "symbolic links"):
            scan_tracks(self.source)


if __name__ == "__main__":
    unittest.main()
