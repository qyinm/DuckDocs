#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# DuckDocs GitHub Release Upload Script
#
# Usage:
#   ./scripts/upload-release.sh /path/to/DuckDocs.app
#   ./scripts/upload-release.sh /path/to/DuckDocs.app --draft
#
# Prerequisites:
#   - gh CLI installed and authenticated: brew install gh && gh auth login
#   - Xcode에서 이미 서명/공증된 .app 파일
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$PROJECT_ROOT/release"

# ─────────────────────────────────────────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────────────────────────────────────────
APP_PATH="$1"
DRAFT_FLAG=""

if [[ "$2" == "--draft" ]] || [[ "$1" == "--draft" ]]; then
    DRAFT_FLAG="--draft"
fi

if [[ -z "$APP_PATH" ]] || [[ "$APP_PATH" == "--draft" ]]; then
    echo -e "${YELLOW}Usage: $0 /path/to/DuckDocs.app [--draft]${NC}"
    echo ""
    echo "Example:"
    echo "  $0 ~/Desktop/DuckDocs.app"
    echo "  $0 ~/Desktop/DuckDocs.app --draft"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Validate
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}🦆 DuckDocs Release Upload${NC}"
echo ""

if [[ ! -d "$APP_PATH" ]]; then
    echo -e "${RED}❌ App not found: $APP_PATH${NC}"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) not found. Install: brew install gh${NC}"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI not authenticated. Run: gh auth login${NC}"
    exit 1
fi

echo -e "${GREEN}✅ App found: $APP_PATH${NC}"
echo -e "${GREEN}✅ GitHub CLI authenticated${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Get version
# ─────────────────────────────────────────────────────────────────────────────
if [[ -f "$PROJECT_ROOT/version.json" ]]; then
    VERSION=$(node -p "require('$PROJECT_ROOT/version.json').version" 2>/dev/null)
else
    VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
fi

echo -e "${CYAN}Version: v$VERSION${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Create ZIP
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}📦 Creating ZIP...${NC}"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

ZIP_NAME="DuckDocs-v${VERSION}-universal.zip"
ditto -c -k --keepParent "$APP_PATH" "$RELEASE_DIR/$ZIP_NAME"

# Checksum
cd "$RELEASE_DIR"
shasum -a 256 "$ZIP_NAME" > checksums.txt

echo -e "${GREEN}✅ Created: $ZIP_NAME${NC}"
echo -e "${CYAN}   Size: $(du -h "$ZIP_NAME" | cut -f1)${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Upload to GitHub
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}🚀 Creating GitHub Release...${NC}"

cd "$PROJECT_ROOT"

# Create tag if not exists
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo -e "${CYAN}Tag v$VERSION already exists${NC}"
else
    echo -e "${YELLOW}Creating tag v$VERSION...${NC}"
    git tag "v$VERSION"
    git push origin "v$VERSION"
fi

CHECKSUM=$(cat "$RELEASE_DIR/checksums.txt")

gh release create "v$VERSION" \
    $DRAFT_FLAG \
    --title "DuckDocs v$VERSION" \
    --notes "## DuckDocs v$VERSION

### Installation
1. Download \`$ZIP_NAME\`
2. Unzip the file
3. Move DuckDocs.app to your Applications folder
4. Open DuckDocs from Applications

### System Requirements
- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac

### Checksums (SHA256)
\`\`\`
$CHECKSUM
\`\`\`
" \
    "$RELEASE_DIR/$ZIP_NAME" \
    "$RELEASE_DIR/checksums.txt"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}        🎉 Release Upload Complete!                         ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
REPO_URL=$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')
echo -e "View release: ${CYAN}https://github.com/$REPO_URL/releases/tag/v$VERSION${NC}"
echo ""
