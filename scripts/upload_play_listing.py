#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "google-api-python-client>=2.100",
#   "google-auth>=2.20",
#   "google-auth-httplib2>=0.2",
#   "httplib2>=0.22",
# ]
# ///
"""Upload the Google Play store listing text and graphics.

Reads store/play/listing-<language>.md (app name, short and full description)
and store/play/graphics/ (feature-graphic.png, phone-1.png ... phone-N.png),
then replaces the listing and those images in one edit:

    ./scripts/upload_play_listing.py --show      # print what Play has now
    ./scripts/upload_play_listing.py --dry-run   # upload + validate, then discard
    ./scripts/upload_play_listing.py             # publish

Phone screenshots and the feature graphic on Play are replaced as a whole; other
image types (icon, tablet screenshots, ...) are left alone. Regenerate the
graphics with store/play/source/render.sh.

Auth is the same service account as scripts/upload_android_play.py; it needs
the "Manage store presence" permission in Play Console.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

PACKAGE_NAME = "parkour.spot"
REPO_ROOT = Path(__file__).resolve().parent.parent
STORE_DIR = REPO_ROOT / "store/play"
GRAPHICS_DIR = STORE_DIR / "graphics"
DEFAULT_KEY = REPO_ROOT / "play-service-account.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
LIMITS = {"title": 30, "shortDescription": 80, "fullDescription": 4000}
SECTIONS = {
    "App name": "title",
    "Short description": "shortDescription",
    "Full description": "fullDescription",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--language", default="en-US")
    parser.add_argument(
        "--key",
        type=Path,
        default=Path(os.environ.get("PLAY_SERVICE_ACCOUNT_JSON", DEFAULT_KEY)),
        help="Service account JSON key (default: $PLAY_SERVICE_ACCOUNT_JSON "
        "or play-service-account.json)",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--show", action="store_true", help="Print the current listing and exit"
    )
    mode.add_argument(
        "--dry-run",
        action="store_true",
        help="Upload and validate the edit, then discard it",
    )
    return parser.parse_args()


def read_listing(language: str) -> dict[str, str]:
    path = STORE_DIR / f"listing-{language}.md"
    if not path.is_file():
        sys.exit(f"❌ {path} not found")
    listing: dict[str, str] = {}
    for block in re.split(r"^## ", path.read_text(encoding="utf-8"), flags=re.M)[1:]:
        heading, _, body = block.partition("\n")
        name = re.sub(r"\s*\(.*\)\s*$", "", heading).strip()
        if name in SECTIONS:
            listing[SECTIONS[name]] = body.strip()
    missing = set(SECTIONS.values()) - listing.keys()
    if missing:
        sys.exit(f"❌ {path.name} is missing sections: {', '.join(sorted(missing))}")
    for field, limit in LIMITS.items():
        if len(listing[field]) > limit:
            sys.exit(f"❌ {field} is {len(listing[field])} characters, max {limit}")
    return listing


def phone_screenshots() -> list[Path]:
    shots = sorted(
        GRAPHICS_DIR.glob("phone-*.png"),
        key=lambda p: int(re.search(r"(\d+)", p.stem).group(1)),
    )
    if not 2 <= len(shots) <= 8:
        sys.exit(f"❌ Play needs 2 to 8 phone screenshots, found {len(shots)}")
    return shots


def main() -> None:
    args = parse_args()
    if not args.key.is_file():
        sys.exit(
            f"❌ Service account key not found: {args.key}\n"
            "   Set PLAY_SERVICE_ACCOUNT_JSON or pass --key."
        )

    listing = read_listing(args.language)
    shots = phone_screenshots()
    feature = GRAPHICS_DIR / "feature-graphic.png"
    if not feature.is_file():
        sys.exit(f"❌ {feature} not found")

    credentials = service_account.Credentials.from_service_account_file(
        str(args.key), scopes=SCOPES
    )
    edits = build(
        "androidpublisher", "v3", credentials=credentials, cache_discovery=False
    ).edits()
    edit_id = edits.insert(packageName=PACKAGE_NAME, body={}).execute()["id"]
    common = {"packageName": PACKAGE_NAME, "editId": edit_id}

    def discard_edit() -> None:
        try:
            edits.delete(**common).execute()
        except HttpError:
            pass

    try:
        details = edits.details().get(**common).execute()
        print(f"Default language on Play: {details.get('defaultLanguage')}")
        current = edits.listings().list(**common).execute().get("listings", [])
        for item in current:
            print(f"\n[{item['language']}] {item.get('title', '')}")
            print(f"  short: {item.get('shortDescription', '')}")
            full = item.get("fullDescription", "")
            print(f"  full:  {len(full)} characters")
        if not current:
            print("No store listings yet.")
        for image_type in ("featureGraphic", "phoneScreenshots"):
            images = (
                edits.images()
                .list(**common, language=args.language, imageType=image_type)
                .execute()
                .get("images", [])
            )
            print(f"{args.language} {image_type}: {len(images)} image(s)")

        if args.show:
            discard_edit()
            return

        print(f"\n📝 Updating {args.language} listing text...")
        edits.listings().update(
            **common, language=args.language, body={"language": args.language, **listing}
        ).execute()

        uploads = [("featureGraphic", [feature]), ("phoneScreenshots", shots)]
        for image_type, files in uploads:
            edits.images().deleteall(
                **common, language=args.language, imageType=image_type
            ).execute()
            for path in files:
                print(f"🖼  {image_type}: {path.name}", flush=True)
                edits.images().upload(
                    **common,
                    language=args.language,
                    imageType=image_type,
                    media_body=MediaFileUpload(str(path), mimetype="image/png"),
                ).execute()

        edits.validate(**common).execute()
        if args.dry_run:
            print("✅ Edit is valid. Dry run: discarding it, nothing was published.")
            discard_edit()
            return
        edits.commit(**common).execute()
    except HttpError as error:
        discard_edit()
        print(f"❌ Google Play rejected the edit: {error.reason or error}", file=sys.stderr)
        if os.environ.get("PLAY_DEBUG"):
            print(error.content.decode(errors="replace"), file=sys.stderr)
        if error.status_code in (401, 403):
            print(
                "   Check that the service account has the \"Manage store "
                "presence\" permission for Parkour.Spot in Play Console.",
                file=sys.stderr,
            )
        sys.exit(1)
    except BaseException:
        discard_edit()
        raise

    print(f"🎉 Published the {args.language} store listing and graphics.")


if __name__ == "__main__":
    main()
