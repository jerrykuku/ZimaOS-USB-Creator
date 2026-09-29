#!/usr/bin/env python3
"""Check Qt TS catalog coverage and formatting without third-party packages."""

import argparse
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET


PLACEHOLDER = re.compile(r"%(?:L?\d+|Ln|n)")
FILE_PATTERN = re.compile(r"\*\.[A-Za-z0-9]+")
TECHNICAL_TOKEN = re.compile(
    r"\b(?:1-Wire|I2C|SPI|UART|OTP|JTAG|FAT32|MBR|GPT|SHA256|PEM|RSA|"
    r"IPv4|IPv6|F_NOCACHE|O_DIRECT|authorized_keys|config\.txt|boot\.img|boot\.sig|F2)\b"
)


class Markup(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.tags = Counter()
        self.links = Counter()
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        self.tags[("start", tag)] += 1
        for name, value in attrs:
            if name in ("href", "src"):
                self.links[(name, value)] += 1

    def handle_endtag(self, tag):
        self.tags[("end", tag)] += 1

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag != "br":
            self.handle_endtag(tag)


def read_catalog(path):
    root = ET.parse(path).getroot()
    entries = {}
    errors = []
    if not root.get("language"):
        errors.append("missing catalog language")
    for context in root.findall("context"):
        for message in context.findall("message"):
            source = message.findtext("source", "")
            key = (context.findtext("name", ""), source,
                   message.findtext("comment", ""), message.get("numerus", "no"))
            label = f"{key[0]}: {source[:90]!r}"
            if key in entries:
                errors.append(f"{label}: duplicate message")
            entries[key] = message
            translation = message.find("translation")
            if translation is None or translation.get("type") in ("unfinished", "obsolete", "vanished"):
                errors.append(f"{label}: missing, unfinished or obsolete translation")
                continue
            forms = translation.findall("numerusform") if message.get("numerus") == "yes" else [translation]
            if not forms:
                errors.append(f"{label}: missing plural forms")
            for form in forms:
                target = "".join(form.itertext())
                if not target.strip():
                    errors.append(f"{label}: empty translation")
                    continue
                if Counter(PLACEHOLDER.findall(source)) != Counter(PLACEHOLDER.findall(target)):
                    errors.append(f"{label}: placeholders differ")
                if Counter(FILE_PATTERN.findall(source)) != Counter(FILE_PATTERN.findall(target)):
                    errors.append(f"{label}: file extensions differ")
                # A non-breaking hyphen is valid typography for names like 1-Wire.
                technical_target = target.replace("\u2011", "-")
                for token in set(TECHNICAL_TOKEN.findall(source)):
                    if source.count(token) != technical_target.count(token):
                        errors.append(f"{label}: technical identifier {token} differs")
                original, localized = Markup(source), Markup(target)
                if original.tags != localized.tags or original.links != localized.links:
                    errors.append(f"{label}: markup or links differ")
                for expression in (r"^\s*", r"\s*$"):
                    if re.search(expression, source).group() != re.search(expression, target).group():
                        errors.append(f"{label}: surrounding whitespace differs")
                        break
                if source.count("\n") != target.count("\n"):
                    errors.append(f"{label}: line breaks differ")
                for brand in ("ZimaOS USB Creator", "ZimaOS", "IceWhaleTech"):
                    if brand in source and source.count(brand) != target.count(brand):
                        errors.append(f"{label}: {brand} differs")
    return entries, errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path,
                        default=Path(__file__).resolve().parents[1] / "src" / "i18n")
    args = parser.parse_args()
    paths = sorted(args.directory.glob("*.ts"))
    reference = args.directory / "rpi-imager_en.ts"
    if reference not in paths:
        parser.error("English reference catalog not found")
    reference_keys = set(read_catalog(reference)[0])
    failures = 0
    for path in paths:
        try:
            entries, errors = read_catalog(path)
        except ET.ParseError as error:
            print(f"{path.name}: invalid XML: {error}", file=sys.stderr)
            failures += 1
            continue
        keys = set(entries)
        for key in sorted(reference_keys - keys):
            errors.append(f"{key[0]}: {key[1][:90]!r}: missing source message")
        for key in sorted(keys - reference_keys):
            errors.append(f"{key[0]}: {key[1][:90]!r}: unused source message")
        for error in errors:
            print(f"{path.name}: {error}", file=sys.stderr)
        failures += len(errors)
        print(f"{path.name}: {len(entries)} messages, {len(errors)} errors")
    print(f"Checked {len(paths)} catalogs; {failures} errors.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
