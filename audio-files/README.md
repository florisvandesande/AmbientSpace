# Adding sounds

Every Xcode build scans the direct subfolders of `audio-files/`. Each subfolder represents one recording. Its folder name is the stable internal identifier; avoid renaming it after release.

## 1. Create a folder

Use a short descriptive name, such as `summer-storm`. Add these three files:

```text
audio-files/
├── README.md
└── summer-storm/
    ├── audio.m4a
    ├── cover.jpg
    └── metadata.json
```

Use an M4A recording, preferably AAC, at least twelve seconds long. Use a square JPEG cover, preferably at least 1024 × 1024 pixels. Only use recordings and images that you have permission to bundle and redistribute.

No sample media is generated for you. An empty source folder produces a valid empty catalog.

All contents of `audio-files/` except this README are ignored by Git. Your local recordings, covers, and metadata still enter local app builds, but are not included in ordinary commits or a source checkout. This also applies to new folders. Do not use `git add --force` to bypass that protection. `.gitignore` does not remove files that were already committed.

To verify a new folder is excluded, run `git check-ignore -v audio-files/summer-storm/audio.m4a` from the repository root. It should show the `/audio-files/*` rule.

## 2. Fill in metadata.json

Copy this example, choosing an unused positive `index`:

```json
{
  "index": 1,
  "title": "Zomerstorm",
  "subtitle": "Regen met verre donder",
  "description": "Een rustige zomerse regenbui met langzaam bewegende donder.",
  "colorStart": "#18324A",
  "colorEnd": "#6E8FA8",
  "sfSymbol": "",
  "translations": {
    "en": {
      "title": "Summer storm",
      "subtitle": "Rain with distant thunder",
      "description": "A gentle summer shower with slowly rolling thunder."
    },
    "fr": {
      "title": "Orage d’été",
      "subtitle": "Pluie et tonnerre au loin",
      "description": "Une douce averse d’été accompagnée de tonnerre lointain."
    },
    "de": {
      "title": "Sommergewitter",
      "subtitle": "Regen mit fernem Donner",
      "description": "Ein ruhiger sommerlicher Regenschauer mit langsam rollendem Donner."
    }
  }
}
```

- `index` determines the list order. It must be a unique positive integer; gaps are allowed.
- `title`, `subtitle`, and `description` must be non-empty strings. Existing recordings use Dutch as the original language.
- Colors must contain exactly six hexadecimal digits after `#`.
- `sfSymbol` is optional. Use an exact SF Symbols name such as `cloud.rain.fill`, or leave it as an empty string while choosing an icon. The app then keeps showing the normal Play button. A valid symbol replaces Play in the library, appears in system playback artwork, and represents the sound in its Live Activity and configured system control. Once playback starts, the library button always changes to Pause.
- `translations` is optional. Each supplied language needs all three text fields. Supported keys are `nl`, `en`, `fr`, `de`, `es`, `it`, and `pt-BR`.
- Missing translations fall back to the original fields; existing metadata needs no migration.
- Titles and descriptions are plain text, not Markdown or HTML.
- The app, foreground media controls, system actions, and Live Activity use the same translated recording metadata.

See the [SF Symbols overview](../README.md#suggested-weather-and-nature-symbols) for suggested names and rendered examples. Availability varies by iOS version; verify each chosen name on the oldest supported iOS release.

## 3. Validate safely

From the repository root:

```bash
python3 scripts/build_audio_catalog.py \
  --source audio-files \
  --destination /tmp/ambientspace-audio-check
```

Expected success output ends with `audio-files/catalog.json`. A failure names the affected folder or metadata file. Resolve it before building.

The destination is a disposable **output directory**, not the source directory. The script replaces only its `audio-files/` subfolder on each successful build. It rejects overlapping source/output paths and symbolic links to avoid accidentally copying external files or deleting source recordings.

Validation checks required files, JSON, text, translations, unique indexes, color formats, and basic media signatures. It does not fully decode media or check cover dimensions. Check the JPEG visually and listen to the recording; the audio engine checks the twelve-second minimum when playback starts.

## 4. Build again

Build or deploy the app again. The always-run Xcode build phase copies the three files per track and generates an index-sorted `catalog.json` with `schemaVersion: 1`.

Do not edit the generated catalog. Remove a source folder to omit a recording from the next build; old bundled copies are removed automatically. Other files in a track folder are not copied to the app.

## Media files

The app looks for .m4a audio files. Please convert other types to this format before building the app. If you need to trim the beginning or the end of the file, please consider using [Trimmer](https://github.com/florisvandesande/Trimmer), my **lossless audio trimmer for macOS**.
