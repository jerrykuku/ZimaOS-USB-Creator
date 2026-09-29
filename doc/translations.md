# Maintaining translations

The desktop application loads all `src/i18n/rpi-imager_*.ts` catalogs through
their compiled `.qm` resources. Keep every supported locale in sync with the
source. The embedded build intentionally excludes locales whose fonts are not
packaged there.

## Update and check

From the repository root, with an existing Qt build directory:

```sh
cmake --build build --target zimaos-usb-creator_lupdate
python3 tools/check_translations.py
cmake --build build --target zimaos-usb-creator
```

The update target uses `-no-obsolete`: it removes messages no longer referenced
by source code, including superseded dialog text. Conditional pages still count
as active source and must retain their translations. Do not remove catalogs just
because a language has fewer users.

Fill new entries and remove `type="unfinished"` only after checking the result.
The validation script checks locale coverage, duplicate and obsolete entries,
empty translations, Qt placeholders, file extensions, technical identifiers,
rich-text markup and links, line breaks, surrounding whitespace, and product
names. It uses only the Python standard library. These checks do not replace
linguistic review.

## Translation rules

- Keep `ZimaOS`, `ZimaOS USB Creator` and `IceWhaleTech` unchanged.
- Preserve `%1`, `%2`, `%n` and other Qt parameters. They may move within a
  sentence, but must not be omitted or duplicated.
- Preserve HTML tags, links, file filters, technical identifiers and paragraph
  breaks. Translate the surrounding explanation.
- Use storage-device terminology where the operation also supports hard disks
  and memory cards. Image-file descriptions must not imply `.img` is the only
  supported format.
- Keep irreversible erasure, system-drive and security warnings explicit.
- Separate translated display labels from configuration values. For example,
  serial-port options use translated `text` and stable `value` roles.
- Use `qsTr()` for QML text and `tr()` for C++ text. Use `qsTranslate()` when
  deliberately sharing another component's translation context.

The September 2026 completion pass preserves existing translations, reuses
matching translations from the upstream Raspberry Pi Imager catalogs, and uses
local machine translation to assist with remaining non-Chinese gaps. Simplified
Chinese additions were edited directly; Traditional Chinese gaps were adapted
from them with Taiwan terminology. Review important wording with native speakers
when preparing releases, especially in catalogs that previously had few
translations.
