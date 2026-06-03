#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ios/MuhomorGovorunIOS.xcodeproj"
EXPORT_OPTIONS="$ROOT_DIR/ios/ExportOptions-AppStoreUpload.plist"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/archives/ShromSpeak-1.0.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/app-store-upload}"

: "${ASC_KEY_PATH:?Set ASC_KEY_PATH to the downloaded App Store Connect .p8 key path}"
: "${ASC_KEY_ID:?Set ASC_KEY_ID to the App Store Connect key ID}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID to the App Store Connect issuer ID}"

if [[ ! -f "$ASC_KEY_PATH" ]]; then
  echo "ASC_KEY_PATH does not exist: $ASC_KEY_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme MuhomorGovorunIOS \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  clean archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
