"""Keep the four language catalogs complete and format-safe."""

import json
import re
import unittest
from pathlib import Path


class LocalizationTests(unittest.TestCase):
    def test_every_string_has_all_languages_and_matching_placeholders(self) -> None:
        root = Path(__file__).resolve().parents[2]
        path = root / "ios-app/AmbientSpace/Resources/Localizable.xcstrings"
        catalog = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(catalog["sourceLanguage"], "en")
        for key, entry in catalog["strings"].items():
            with self.subTest(key=key):
                localizations = entry["localizations"]
                self.assertEqual(set(localizations), {"en", "nl", "fr", "de"})
                placeholders = sorted(re.findall(r"%(?:lld|@)", key))
                for language, value in localizations.items():
                    text = value["stringUnit"]["value"]
                    self.assertTrue(text.strip(), language)
                    self.assertEqual(sorted(re.findall(r"%(?:lld|@)", text)), placeholders)


if __name__ == "__main__":
    unittest.main()
