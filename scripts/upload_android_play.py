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
"""Upload the Android App Bundle to a Google Play track.

Build first with ./scripts/build_android_production.sh, then:

    ./scripts/upload_android_play.py                      # internal testing
    ./scripts/upload_android_play.py --track alpha        # closed testing
    ./scripts/upload_android_play.py --notes "Bug fixes"  # en-US release notes
    ./scripts/upload_android_play.py --dry-run            # validate, don't publish
    ./scripts/upload_android_play.py --promote --track alpha
        # release the already-uploaded pubspec version to closed testing,
        # reusing its release notes unless --notes is given (no rebuild)

Auth: a Google Cloud service account JSON key with release access to the app in
Play Console (Users and permissions). Default location is
play-service-account.json in the repo root (gitignored); override with
PLAY_SERVICE_ACCOUNT_JSON or --key. See README "Publishing to Google Play".
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

import google_auth_httplib2
import httplib2
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

PACKAGE_NAME = "parkour.spot"
REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_AAB = REPO_ROOT / "build/app/outputs/bundle/release/app-release.aab"
DEFAULT_KEY = REPO_ROOT / "play-service-account.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
# Resumable upload in chunks (multiple of 256 KiB): a dropped connection only
# retries the current chunk, and progress can be shown on slow uplinks.
UPLOAD_CHUNK_SIZE = 8 * 1024 * 1024
UPLOAD_RETRIES = 5
# After the last chunk Play processes the whole bundle before it answers, which
# takes longer than the API client's default 60 s socket timeout.
HTTP_TIMEOUT_SECONDS = 15 * 60
TRACKS = ("internal", "alpha", "beta", "production")


def pubspec_version() -> tuple[str, int]:
    text = (REPO_ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([^\s+]+)\+(\d+)\s*$", text, re.MULTILINE)
    if not match:
        sys.exit("❌ Could not read `version: x.y.z+N` from pubspec.yaml")
    return match.group(1), int(match.group(2))


def existing_release_notes(edits, edit_id: str, version_code: int) -> list | None:
    """Release notes of a track release that already contains version_code."""
    tracks = edits.tracks().list(packageName=PACKAGE_NAME, editId=edit_id).execute()
    for track in tracks.get("tracks", []):
        for release in track.get("releases", []):
            if str(version_code) in release.get("versionCodes", []):
                if release.get("releaseNotes"):
                    return release["releaseNotes"]
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--track", choices=TRACKS, default="internal")
    parser.add_argument("--aab", type=Path, default=DEFAULT_AAB)
    parser.add_argument(
        "--key",
        type=Path,
        default=Path(os.environ.get("PLAY_SERVICE_ACCOUNT_JSON", DEFAULT_KEY)),
        help="Service account JSON key (default: $PLAY_SERVICE_ACCOUNT_JSON "
        "or play-service-account.json)",
    )
    parser.add_argument("--notes", help="Release notes (en-US)")
    parser.add_argument(
        "--status",
        choices=("completed", "draft", "inProgress"),
        default="completed",
        help="Release status. Use draft to finish the release in Play Console; "
        "inProgress needs --rollout.",
    )
    parser.add_argument(
        "--rollout",
        type=float,
        help="Staged rollout fraction for --status inProgress, e.g. 0.1",
    )
    parser.add_argument(
        "--promote",
        action="store_true",
        help="Release the pubspec version that is already on Google Play (e.g. "
        "on internal) to --track instead of uploading a bundle",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Upload and validate the edit, then discard it",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if not args.promote and not args.aab.is_file():
        sys.exit(
            f"❌ {args.aab} not found. Build it with "
            "./scripts/build_android_production.sh"
        )
    if not args.key.is_file():
        sys.exit(
            f"❌ Service account key not found: {args.key}\n"
            "   Set PLAY_SERVICE_ACCOUNT_JSON or pass --key "
            '(see README "Publishing to Google Play").'
        )
    if args.status == "inProgress" and not args.rollout:
        sys.exit("❌ --status inProgress needs --rollout (e.g. 0.1)")
    if args.rollout is not None and not 0 < args.rollout < 1:
        sys.exit("❌ --rollout must be between 0 and 1 (exclusive)")

    version_name, version_code = pubspec_version()
    if not args.promote and args.aab.stat().st_mtime < (REPO_ROOT / "pubspec.yaml").stat().st_mtime:
        print(
            "⚠️  The bundle is older than pubspec.yaml; rebuild if the version "
            "changed since the last build."
        )

    credentials = service_account.Credentials.from_service_account_file(
        str(args.key), scopes=SCOPES
    )
    base_http = httplib2.Http(timeout=HTTP_TIMEOUT_SECONDS)
    # Resumable uploads answer each chunk with 308 "Resume Incomplete", which
    # httplib2 would follow as a redirect. googleapiclient's build_http() drops
    # 308 the same way; we build our own Http for the longer timeout.
    base_http.redirect_codes = base_http.redirect_codes - {308}
    publisher = build(
        "androidpublisher",
        "v3",
        http=google_auth_httplib2.AuthorizedHttp(credentials, http=base_http),
        cache_discovery=False,
    )
    edits = publisher.edits()

    print(
        f"🚀 {'Promoting' if args.promote else 'Uploading'} {PACKAGE_NAME} "
        f"{version_name} ({version_code}) to the {args.track} track"
        f"{' [dry run]' if args.dry_run else ''}..."
    )

    edit_id = edits.insert(packageName=PACKAGE_NAME, body={}).execute()["id"]

    def discard_edit() -> None:
        try:
            edits.delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
        except HttpError:
            pass

    def abort(message: str) -> None:
        discard_edit()
        sys.exit(message)

    try:
        existing = (
            edits.bundles().list(packageName=PACKAGE_NAME, editId=edit_id).execute()
        )
        known_codes = {b["versionCode"] for b in existing.get("bundles", [])}
        notes = None
        if args.promote:
            if version_code not in known_codes:
                abort(
                    f"❌ Version code {version_code} is not on Google Play yet. "
                    "Upload it first (without --promote)."
                )
            notes = existing_release_notes(edits, edit_id, version_code)
        else:
            if version_code in known_codes:
                abort(
                    f"❌ Version code {version_code} was already uploaded. "
                    "Bump `version:` in pubspec.yaml and rebuild."
                )

            size_mb = args.aab.stat().st_size / 1024 / 1024
            print(f"📦 Uploading {args.aab.name} ({size_mb:.1f} MB)...", flush=True)
            upload = edits.bundles().upload(
                packageName=PACKAGE_NAME,
                editId=edit_id,
                media_body=MediaFileUpload(
                    str(args.aab),
                    mimetype="application/octet-stream",
                    chunksize=UPLOAD_CHUNK_SIZE,
                    resumable=True,
                ),
            )
            bundle = None
            while bundle is None:
                progress, bundle = upload.next_chunk(num_retries=UPLOAD_RETRIES)
                if progress is not None:
                    print(f"   {progress.progress():.0%}", flush=True)
            print("   Uploaded, Play processed the bundle.", flush=True)
            uploaded_code = bundle["versionCode"]
            if uploaded_code != version_code:
                abort(
                    f"❌ Bundle has version code {uploaded_code}, pubspec.yaml says "
                    f"{version_code}. Rebuild with ./scripts/build_android_production.sh"
                )

        release: dict = {
            "name": f"{version_name} ({version_code})",
            "versionCodes": [str(version_code)],
            "status": args.status,
        }
        if args.rollout is not None:
            release["userFraction"] = args.rollout
        if args.notes:
            notes = [{"language": "en-US", "text": args.notes}]
        if notes:
            release["releaseNotes"] = notes

        edits.tracks().update(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            track=args.track,
            body={"track": args.track, "releases": [release]},
        ).execute()

        if args.dry_run:
            edits.validate(packageName=PACKAGE_NAME, editId=edit_id).execute()
            print("✅ Edit is valid. Dry run: discarding it, nothing was published.")
            discard_edit()
            return

        edits.commit(packageName=PACKAGE_NAME, editId=edit_id).execute()
    except HttpError as error:
        discard_edit()
        message = error.reason or str(error)
        print(f"❌ Google Play rejected the upload: {message}", file=sys.stderr)
        if "draft app" in message.lower():
            print(
                "   The app has not been published yet, so Play only accepts "
                "draft releases. Re-run with --status draft and roll it out in "
                "Play Console.",
                file=sys.stderr,
            )
        if error.status_code in (401, 403):
            print(
                "   Check that the service account is invited in Play Console "
                "(Users and permissions) with release access to Parkour.Spot, "
                "and that the Google Play Android Developer API is enabled.",
                file=sys.stderr,
            )
        sys.exit(1)
    except BaseException:
        # Network errors, Ctrl-C, ...: don't leave an open edit behind.
        discard_edit()
        raise

    print(
        f"🎉 Released {version_name} ({version_code}) to {args.track} ({args.status})."
    )


if __name__ == "__main__":
    main()
