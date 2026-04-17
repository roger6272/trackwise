#!/bin/bash

# =============================================================================
# Firmware Publish Script for Trackwise
# =============================================================================
# Usage: ./scripts/publish_firmware.sh <bin_file> <version>
#        [--channel beta|release] [--min-app-version X.Y.Z]
#        [--changelog "text"] [--min-firmware-version X.Y.Z]
#
# This script:
# 1. Validates the firmware binary and version string
# 2. Computes a SHA256 hash of the binary
# 3. Generates a latest.json metadata file ready for Firebase Storage upload
# 4. Prints upload instructions
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Defaults
CHANNEL="release"
MIN_APP_VERSION="1.0.0"
CHANGELOG=""
MIN_FIRMWARE_VERSION=""

# --- Usage -------------------------------------------------------------------

usage() {
    echo "Usage: ./scripts/publish_firmware.sh <bin_file> <version> [options]"
    echo ""
    echo "Arguments:"
    echo "  bin_file    Path to the .bin firmware file"
    echo "  version     Firmware version in X.Y.Z format (e.g. 1.2.3)"
    echo ""
    echo "Options:"
    echo "  --channel beta|release         OTA channel (default: release)"
    echo "  --min-app-version X.Y.Z       Minimum app version required (default: 1.0.0)"
    echo "  --changelog \"text\"             Changelog text for this release"
    echo "  --min-firmware-version X.Y.Z   Minimum firmware version that can OTA to this"
    echo ""
    echo "Examples:"
    echo "  ./scripts/publish_firmware.sh build/trackwise.bin 1.2.0"
    echo "  ./scripts/publish_firmware.sh build/trackwise.bin 1.2.0 --channel beta"
    echo "  ./scripts/publish_firmware.sh build/trackwise.bin 1.2.0 --changelog \"Bug fixes\""
    exit 1
}

# --- Validation helpers ------------------------------------------------------

validate_version() {
    local version="$1"
    local label="$2"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid ${label} format '${version}'. Expected X.Y.Z (e.g. 1.2.3)${NC}"
        exit 1
    fi
}

# --- Parse arguments ---------------------------------------------------------

if [ $# -lt 2 ]; then
    usage
fi

BIN_FILE="$1"
VERSION="$2"
shift 2

while [ $# -gt 0 ]; do
    case "$1" in
        --channel)
            [ $# -lt 2 ] && { echo -e "${RED}Error: --channel requires a value${NC}"; exit 1; }
            CHANNEL="$2"
            if [[ "$CHANNEL" != "beta" && "$CHANNEL" != "release" ]]; then
                echo -e "${RED}Error: --channel must be 'beta' or 'release'${NC}"
                exit 1
            fi
            shift 2
            ;;
        --min-app-version)
            [ $# -lt 2 ] && { echo -e "${RED}Error: --min-app-version requires a value${NC}"; exit 1; }
            MIN_APP_VERSION="$2"
            shift 2
            ;;
        --changelog)
            [ $# -lt 2 ] && { echo -e "${RED}Error: --changelog requires a value${NC}"; exit 1; }
            CHANGELOG="$2"
            shift 2
            ;;
        --min-firmware-version)
            [ $# -lt 2 ] && { echo -e "${RED}Error: --min-firmware-version requires a value${NC}"; exit 1; }
            MIN_FIRMWARE_VERSION="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Error: Unknown option '$1'${NC}"
            usage
            ;;
    esac
done

# --- Validate inputs ---------------------------------------------------------

if [ ! -f "$BIN_FILE" ]; then
    echo -e "${RED}Error: File not found: ${BIN_FILE}${NC}"
    exit 1
fi

validate_version "$VERSION" "version"
validate_version "$MIN_APP_VERSION" "min-app-version"

if [ -n "$MIN_FIRMWARE_VERSION" ]; then
    validate_version "$MIN_FIRMWARE_VERSION" "min-firmware-version"
fi

# --- Compute SHA256 ----------------------------------------------------------

if command -v sha256sum &> /dev/null; then
    SHA256=$(sha256sum "$BIN_FILE" | awk '{print $1}')
elif command -v shasum &> /dev/null; then
    SHA256=$(shasum -a 256 "$BIN_FILE" | awk '{print $1}')
else
    echo -e "${RED}Error: Neither sha256sum nor shasum found. Cannot compute hash.${NC}"
    exit 1
fi

# --- Generate latest.json ---------------------------------------------------

STORAGE_PATH="firmware/${CHANNEL}/bins/trackwise_${VERSION}.bin"
RELEASED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OUTPUT_DIR="$(dirname "$BIN_FILE")"
OUTPUT_FILE="${OUTPUT_DIR}/latest.json"

# Build JSON (using printf to avoid dependency on jq)
cat > "$OUTPUT_FILE" << EOF
{
  "version": "${VERSION}",
  "file_path": "${STORAGE_PATH}",
  "sha256": "${SHA256}",
  "min_app_version": "${MIN_APP_VERSION}",
  "changelog": "${CHANGELOG}",
  "released_at": "${RELEASED_AT}"
}
EOF

echo -e "${GREEN}=== Firmware Publish Package Ready ===${NC}"
echo ""
echo -e "Channel:          ${CHANNEL}"
echo -e "Version:          ${VERSION}"
echo -e "Binary:           ${BIN_FILE}"
echo -e "SHA256:           ${SHA256}"
echo -e "Min app version:  ${MIN_APP_VERSION}"
if [ -n "$MIN_FIRMWARE_VERSION" ]; then
    echo -e "Min FW version:   ${MIN_FIRMWARE_VERSION}"
fi
if [ -n "$CHANGELOG" ]; then
    echo -e "Changelog:        ${CHANGELOG}"
fi
echo -e "Released at:      ${RELEASED_AT}"
echo -e "Metadata:         ${OUTPUT_FILE}"
echo ""
echo -e "${YELLOW}=== Upload Instructions ===${NC}"
echo ""
echo "Upload via Firebase Console (console.firebase.google.com > Storage):"
echo ""
echo "  1. Upload the binary to:    firmware/${CHANNEL}/bins/"
echo "     File: ${BIN_FILE}"
echo ""
echo "  2. Upload the metadata to:  firmware/${CHANNEL}/"
echo "     File: ${OUTPUT_FILE}"
if [ -n "$MIN_FIRMWARE_VERSION" ]; then
    echo ""
    echo "  3. Update Remote Config min_firmware_version to ${MIN_FIRMWARE_VERSION}"
    echo "     (Firebase Console > Remote Config)"
fi
echo ""
echo -e "${GREEN}Done.${NC}"
