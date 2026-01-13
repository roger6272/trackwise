#!/bin/bash

# =============================================================================
# Version Bump Script for Trackwise
# =============================================================================
# Usage: ./scripts/bump_version.sh [major|minor|patch]
#
# This script:
# 1. Reads current version from pubspec.yaml
# 2. Increments the specified version component
# 3. Increments the build number
# 4. Updates pubspec.yaml
# 5. Creates a git commit and tag
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the project root
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}Error: pubspec.yaml not found. Run this script from the project root.${NC}"
    exit 1
fi

# Get current version from pubspec.yaml
CURRENT_LINE=$(grep "^version:" pubspec.yaml)
CURRENT_VERSION=$(echo "$CURRENT_LINE" | sed 's/version: //' | sed 's/+.*//')
CURRENT_BUILD=$(echo "$CURRENT_LINE" | sed 's/.*+//')

# Parse version components
MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)

echo -e "${YELLOW}Current version: ${CURRENT_VERSION}+${CURRENT_BUILD}${NC}"

# Determine new version based on argument
case "$1" in
    major)
        NEW_MAJOR=$((MAJOR + 1))
        NEW_VERSION="${NEW_MAJOR}.0.0"
        ;;
    minor)
        NEW_MINOR=$((MINOR + 1))
        NEW_VERSION="${MAJOR}.${NEW_MINOR}.0"
        ;;
    patch)
        NEW_PATCH=$((PATCH + 1))
        NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
        ;;
    *)
        echo -e "${RED}Usage: ./scripts/bump_version.sh [major|minor|patch]${NC}"
        echo ""
        echo "  major  - Increment major version (1.0.0 -> 2.0.0)"
        echo "  minor  - Increment minor version (1.0.0 -> 1.1.0)"
        echo "  patch  - Increment patch version (1.0.0 -> 1.0.1)"
        echo ""
        echo "Current version: ${CURRENT_VERSION}+${CURRENT_BUILD}"
        exit 1
        ;;
esac

# Increment build number
NEW_BUILD=$((CURRENT_BUILD + 1))

echo -e "${GREEN}New version: ${NEW_VERSION}+${NEW_BUILD}${NC}"

# Confirm with user
read -p "Proceed with version bump? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Update pubspec.yaml
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^version: .*/version: ${NEW_VERSION}+${NEW_BUILD}/" pubspec.yaml
else
    # Linux/Windows (Git Bash)
    sed -i "s/^version: .*/version: ${NEW_VERSION}+${NEW_BUILD}/" pubspec.yaml
fi

echo -e "${GREEN}Updated pubspec.yaml${NC}"

# Check if there are uncommitted changes besides pubspec.yaml
if [ -n "$(git status --porcelain | grep -v pubspec.yaml)" ]; then
    echo -e "${YELLOW}Warning: You have uncommitted changes. Consider committing them first.${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Reverting pubspec.yaml..."
        git checkout pubspec.yaml
        exit 0
    fi
fi

# Git operations
git add pubspec.yaml
git commit -m "chore: bump version to ${NEW_VERSION}"

echo -e "${GREEN}Created commit${NC}"

# Create annotated tag
git tag -a "v${NEW_VERSION}" -m "Release ${NEW_VERSION}

Changes in this release:
- See CHANGELOG.md for details"

echo -e "${GREEN}Created tag v${NEW_VERSION}${NC}"

# Summary
echo ""
echo -e "${GREEN}=== Version Bump Complete ===${NC}"
echo -e "Version: ${NEW_VERSION}+${NEW_BUILD}"
echo -e "Tag: v${NEW_VERSION}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Update CHANGELOG.md with release notes"
echo "  2. Push changes: git push origin master"
echo "  3. Push tag: git push origin v${NEW_VERSION}"
echo "  4. Or push both: git push && git push --tags"
