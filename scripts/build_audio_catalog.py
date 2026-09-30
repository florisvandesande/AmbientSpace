#!/usr/bin/env python3
"""Validate bundled ambience tracks and build the app's audio catalog."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional, Sequence


HEX_COLOR_PATTERN = re.compile(r"^#[0-9A-Fa-f]{6}$")
REQUIRED_FILES = ("audio.m4a", "cover.jpg", "metadata.json")
REQUIRED_TEXT_FIELDS = ("title", "subtitle", "description")
SUPPORTED_TRANSLATION_LANGUAGES = {"nl", "en", "fr", "de", "es", "it", "pt-BR"}


class CatalogError(ValueError):
    """Raised when a track folder does not match the documented contract."""


@dataclass(frozen=True)
class TrackMetadata:
    """Validated metadata used to create one catalog entry."""

    folder_name: str
    index: int
    title: str
    subtitle: str
    description: str
    color_start: str
    color_end: str
    sf_symbol: Optional[str] = None
    translations: dict[str, dict[str, str]] = field(default_factory=dict)

    def as_catalog_entry(self) -> dict[str, Any]:
        return {
            "id": self.folder_name,
            "index": self.index,
            "title": self.title,
            "subtitle": self.subtitle,
            "description": self.description,
            "colorStart": self.color_start.upper(),
            "colorEnd": self.color_end.upper(),
            "audioPath": f"audio-files/{self.folder_name}/audio.m4a",
            "coverPath": f"audio-files/{self.folder_name}/cover.jpg",
            "sfSymbol": self.sf_symbol,
            "translations": self.translations,
        }


def parse_arguments(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate audio-files and copy a generated catalog into an app bundle."
    )
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    return parser.parse_args(argv)


def read_json_object(path: Path) -> dict[str, Any]:
    try:
        raw_value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise CatalogError(
            f"{path}: invalid JSON at line {error.lineno}, column {error.colno}: "
            f"{error.msg}."
        ) from error
    except (OSError, UnicodeError) as error:
        raise CatalogError(f"{path}: could not be read: {error}.") from error

    if not isinstance(raw_value, dict):
        raise CatalogError(f"{path}: the top-level JSON value must be an object.")
    return raw_value


def validate_file_signatures(track_directory: Path) -> None:
    audio_path = track_directory / "audio.m4a"
    cover_path = track_directory / "cover.jpg"

    try:
        # Read only the signature, not potentially hundreds of megabytes of audio.
        with audio_path.open("rb") as audio_file:
            audio_header = audio_file.read(16)
        with cover_path.open("rb") as cover_file:
            cover_header = cover_file.read(3)
    except OSError as error:
        raise CatalogError(
            f"{track_directory}: one of the media files could not be read: {error}."
        ) from error

    if len(audio_header) < 8 or audio_header[4:8] != b"ftyp":
        raise CatalogError(
            f"{audio_path}: the file does not look like an M4A/MP4 audio file."
        )
    if cover_header != b"\xff\xd8\xff":
        raise CatalogError(f"{cover_path}: the file does not look like a JPEG image.")


def validate_track(track_directory: Path) -> TrackMetadata:
    if track_directory.is_symlink() or any(
        (track_directory / filename).is_symlink() for filename in REQUIRED_FILES
    ):
        raise CatalogError(f"{track_directory}: symbolic links are not supported.")
    missing_files = [
        filename for filename in REQUIRED_FILES if not (track_directory / filename).is_file()
    ]
    if missing_files:
        missing_list = ", ".join(missing_files)
        raise CatalogError(f"{track_directory}: missing required file(s): {missing_list}.")

    raw_metadata = read_json_object(track_directory / "metadata.json")
    raw_index = raw_metadata.get("index")
    if isinstance(raw_index, bool) or not isinstance(raw_index, int) or raw_index < 1:
        raise CatalogError(
            f"{track_directory / 'metadata.json'}: 'index' must be a positive integer."
        )

    text_values: dict[str, str] = {}
    for field_name in REQUIRED_TEXT_FIELDS:
        raw_value = raw_metadata.get(field_name)
        if not isinstance(raw_value, str) or not raw_value.strip():
            raise CatalogError(
                f"{track_directory / 'metadata.json'}: '{field_name}' must be a "
                "non-empty string."
            )
        text_values[field_name] = raw_value.strip()

    color_values: dict[str, str] = {}
    for field_name in ("colorStart", "colorEnd"):
        raw_value = raw_metadata.get(field_name)
        if not isinstance(raw_value, str) or not HEX_COLOR_PATTERN.fullmatch(raw_value):
            raise CatalogError(
                f"{track_directory / 'metadata.json'}: '{field_name}' must use "
                "the #RRGGBB format."
            )
        color_values[field_name] = raw_value

    raw_sf_symbol = raw_metadata.get("sfSymbol")
    if raw_sf_symbol is not None and not isinstance(raw_sf_symbol, str):
        raise CatalogError(
            f"{track_directory / 'metadata.json'}: 'sfSymbol' must be a string or null."
        )
    sf_symbol = raw_sf_symbol.strip() if isinstance(raw_sf_symbol, str) else None

    validate_file_signatures(track_directory)

    translations = raw_metadata.get("translations", {})
    if not isinstance(translations, dict):
        raise CatalogError(f"{track_directory / 'metadata.json'}: 'translations' must be an object.")
    for language, translation in translations.items():
        if language not in SUPPORTED_TRANSLATION_LANGUAGES:
            raise CatalogError(f"{track_directory / 'metadata.json'}: unsupported translation language '{language}'.")
        if not isinstance(translation, dict) or any(
            not isinstance(translation.get(key), str) or not translation[key].strip()
            for key in REQUIRED_TEXT_FIELDS
        ):
            raise CatalogError(f"{track_directory / 'metadata.json'}: translation '{language}' needs title, subtitle and description.")

    return TrackMetadata(
        folder_name=track_directory.name,
        index=raw_index,
        title=text_values["title"],
        subtitle=text_values["subtitle"],
        description=text_values["description"],
        color_start=color_values["colorStart"],
        color_end=color_values["colorEnd"],
        sf_symbol=sf_symbol or None,
        translations={
            language: {key: text[key].strip() for key in REQUIRED_TEXT_FIELDS}
            for language, text in translations.items()
        },
    )


def scan_tracks(source: Path) -> list[TrackMetadata]:
    if not source.is_dir():
        raise CatalogError(
            f"{source}: audio source folder is missing. Create it before building."
        )

    track_directories = sorted(
        path
        for path in source.iterdir()
        if path.is_dir() and not path.name.startswith(".")
    )
    tracks = [validate_track(path) for path in track_directories]

    indexes: dict[int, str] = {}
    for track in tracks:
        previous_folder = indexes.get(track.index)
        if previous_folder is not None:
            raise CatalogError(
                f"{source / track.folder_name / 'metadata.json'}: Duplicate index {track.index}: both '{previous_folder}' and "
                f"'{track.folder_name}' use this value."
            )
        indexes[track.index] = track.folder_name

    return sorted(tracks, key=lambda track: track.index)


def build_catalog(source: Path, destination: Path) -> Path:
    source = source.resolve()
    destination = destination.resolve()
    final_audio_directory = destination / "audio-files"
    resolved_output = final_audio_directory.resolve()
    # Never allow an output path to replace source recordings or an ancestor.
    if (final_audio_directory.is_symlink() or resolved_output == source
            or source in resolved_output.parents or resolved_output in source.parents):
        raise CatalogError(f"{final_audio_directory}: output must not overlap the source audio folder or be a symbolic link.")
    tracks = scan_tracks(source)
    destination.mkdir(parents=True, exist_ok=True)
    temporary_directory = Path(tempfile.mkdtemp(prefix=".audio-files-", dir=destination))

    try:
        for track in tracks:
            source_track = source / track.folder_name
            output_track = temporary_directory / track.folder_name
            output_track.mkdir(parents=True)
            for filename in REQUIRED_FILES:
                shutil.copy2(source_track / filename, output_track / filename)

        catalog = {
            "schemaVersion": 1,
            "tracks": [track.as_catalog_entry() for track in tracks],
        }
        catalog_path = temporary_directory / "catalog.json"
        catalog_path.write_text(
            json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

        if final_audio_directory.exists():
            shutil.rmtree(final_audio_directory)
        temporary_directory.replace(final_audio_directory)
        return final_audio_directory / "catalog.json"
    except Exception:
        shutil.rmtree(temporary_directory, ignore_errors=True)
        raise


def main(argv: Sequence[str] | None = None) -> int:
    arguments = parse_arguments(argv)
    try:
        catalog_path = build_catalog(arguments.source.resolve(), arguments.destination.resolve())
    except CatalogError as error:
        print(f"error: Audio catalog validation failed: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"error: Audio catalog could not be built: {error}", file=sys.stderr)
        return 1

    print(f"Audio catalog built at {catalog_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
