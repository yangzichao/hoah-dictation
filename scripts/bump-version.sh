#!/bin/bash

# HoAh Version Bump Script
# Usage: ./scripts/bump-version.sh <version>
# Example: ./scripts/bump-version.sh 3.1.2

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if version argument is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Version number required${NC}"
    echo "Usage: $0 <version>"
    echo "Example: $0 3.1.2"
    exit 1
fi

VERSION=$1

# Validate version format (X.Y.Z)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid version format${NC}"
    echo "Version must be in format X.Y.Z (e.g., 3.1.2)"
    exit 1
fi

# Calculate internal version number (XYZ -> X*100 + Y*10 + Z)
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"
VERSION_NUMBER=$((MAJOR * 100 + MINOR * 10 + PATCH))

echo -e "${GREEN}Updating version to $VERSION (internal: $VERSION_NUMBER)...${NC}"
echo ""

# Get project root directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# File 1: Update Config/Info.plist
echo "📝 Updating Config/Info.plist..."
if [ -f "Config/Info.plist" ]; then
    # Update CFBundleShortVersionString
    sed -i '' "/<key>CFBundleShortVersionString<\/key>/,/<string>/ s|<string>[^<]*</string>|<string>$VERSION</string>|" Config/Info.plist
    # Update CFBundleVersion
    sed -i '' "/<key>CFBundleVersion<\/key>/,/<string>/ s|<string>[^<]*</string>|<string>$VERSION_NUMBER</string>|" Config/Info.plist
    echo -e "${GREEN}✅ Config/Info.plist updated${NC}"
else
    echo -e "${RED}❌ Config/Info.plist not found${NC}"
    exit 1
fi

# File 2: Update HoAh.xcodeproj/project.pbxproj
echo "📝 Updating HoAh.xcodeproj/project.pbxproj..."
if [ -f "HoAh.xcodeproj/project.pbxproj" ]; then
    sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/g" HoAh.xcodeproj/project.pbxproj
    sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $VERSION_NUMBER;/g" HoAh.xcodeproj/project.pbxproj
    echo -e "${GREEN}✅ project.pbxproj updated${NC}"
else
    echo -e "${RED}❌ HoAh.xcodeproj/project.pbxproj not found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Version updated successfully!${NC}"
echo ""
echo -e "${YELLOW}⚠️  Manual steps required:${NC}"
echo ""
echo "1. Update appcast.xml:"
echo "   - Add new <item> entry at the top of <channel>"
echo "   - Set sparkle:version to $VERSION_NUMBER"
echo "   - Set sparkle:shortVersionString to $VERSION"
echo "   - Update download URL to v$VERSION"
echo ""
echo "2. Update RELEASE_NOTES.md (optional)"
echo ""
echo "3. Commit and push:"
echo "   git add Config/Info.plist HoAh.xcodeproj/project.pbxproj appcast.xml"
echo "   git commit -m 'Bump version to $VERSION'"
echo "   git push origin main"
echo ""
echo "4. Create and push tag:"
echo "   git tag -a v$VERSION -m 'Release version $VERSION'"
echo "   git push origin v$VERSION"
echo ""
echo -e "${GREEN}This will trigger automatic build and release!${NC}"
