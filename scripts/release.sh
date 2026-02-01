#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# DuckDocs Release Script
#
# Usage:
#   ./scripts/release.sh              # Full release
#   ./scripts/release.sh --draft      # Create draft release
#   ./scripts/release.sh --skip-notarize  # Skip notarization (for testing)
#   ./scripts/release.sh --local      # Build only, no GitHub upload
#
# Prerequisites:
#   1. gh CLI installed and authenticated: brew install gh && gh auth login
#   2. Notarization credentials stored:
#      xcrun notarytool store-credentials "notarytool-profile" \
#          --apple-id "your@email.com" --team-id "YOUR_TEAM_ID"
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="DuckDocs"
SCHEME="DuckDocs"
CONFIGURATION="Release"
BUILD_DIR="$PROJECT_ROOT/build"
RELEASE_DIR="$PROJECT_ROOT/release"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
TEAM_ID="MCP4D3M7XK"
ENTITLEMENTS_PATH="$PROJECT_ROOT/DuckDocs/DuckDocs.entitlements"

# Parse arguments
DRAFT_FLAG=""
SKIP_NOTARIZE=false
SKIP_SIGN=false
LOCAL_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --draft) DRAFT_FLAG="--draft"; shift ;;
        --skip-notarize) SKIP_NOTARIZE=true; shift ;;
        --skip-sign) SKIP_SIGN=true; SKIP_NOTARIZE=true; shift ;;
        --local) LOCAL_ONLY=true; shift ;;
        --help)
            echo "Usage: $0 [--draft] [--skip-notarize] [--skip-sign] [--local]"
            echo "  --draft          Create draft GitHub release"
            echo "  --skip-notarize  Skip notarization step"
            echo "  --skip-sign      Skip code signing (implies --skip-notarize)"
            echo "  --local          Build only, don't upload to GitHub"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────────────────
log_step() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}\n"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# Step 0: Get Version
# ─────────────────────────────────────────────────────────────────────────────
get_version() {
    if [[ -f "$PROJECT_ROOT/version.json" ]]; then
        VERSION=$(node -p "require('$PROJECT_ROOT/version.json').version" 2>/dev/null)
    else
        # Fallback: read from Info.plist
        VERSION=$(defaults read "$PROJECT_ROOT/DuckDocs/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
    fi
    echo -e "${CYAN}🦆 DuckDocs Release v${VERSION}${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Pre-flight Checks
# ─────────────────────────────────────────────────────────────────────────────
preflight_checks() {
    log_step "Pre-flight Checks"

    # Check for uncommitted changes
    if [[ -n $(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null) ]]; then
        log_warning "Uncommitted changes detected"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    else
        log_success "Git working directory clean"
    fi

    # Check gh CLI (only if not local)
    if [[ "$LOCAL_ONLY" == false ]]; then
        if ! command -v gh &> /dev/null; then
            log_error "GitHub CLI (gh) not found. Install with: brew install gh"
        fi
        if ! gh auth status &> /dev/null; then
            log_error "GitHub CLI not authenticated. Run: gh auth login"
        fi
        log_success "GitHub CLI authenticated"
    fi

    # Check for Developer ID certificate (skip if --skip-sign)
    if [[ "$SKIP_SIGN" == true ]]; then
        log_warning "Skipping certificate check (--skip-sign)"
        IDENTITY=""
    else
        IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | \
            awk -F'"' '/Developer ID Application/ {print $2; exit}')

        if [[ -z "$IDENTITY" ]]; then
            log_error "Developer ID Application certificate not found in Keychain"
        fi
        log_success "Found signing identity: $IDENTITY"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Clean & Build Universal App
# ─────────────────────────────────────────────────────────────────────────────
build_universal() {
    log_step "Building Universal App (arm64 + x86_64)"

    # Clean
    rm -rf "$BUILD_DIR" "$RELEASE_DIR"
    mkdir -p "$BUILD_DIR" "$RELEASE_DIR"

    # Archive with both architectures
    echo -e "${YELLOW}Archiving...${NC}"
    xcodebuild -project "$PROJECT_ROOT/$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=macOS" \
        ARCHS="arm64 x86_64" \
        ONLY_ACTIVE_ARCH=NO \
        archive \
        | xcbeautify 2>/dev/null || cat

    if [[ "$SKIP_SIGN" == true ]]; then
        # For unsigned builds, just copy from archive
        echo -e "${YELLOW}Copying app (unsigned)...${NC}"
        mkdir -p "$EXPORT_PATH"
        cp -R "$ARCHIVE_PATH/Products/Applications/$PROJECT_NAME.app" "$EXPORT_PATH/"
    else
        # Create export options plist
        cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

        # Export
        echo -e "${YELLOW}Exporting...${NC}"
        xcodebuild -exportArchive \
            -archivePath "$ARCHIVE_PATH" \
            -exportPath "$EXPORT_PATH" \
            -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
            | xcbeautify 2>/dev/null || cat
    fi

    APP_PATH="$EXPORT_PATH/$PROJECT_NAME.app"
    if [[ ! -d "$APP_PATH" ]]; then
        log_error "App not found at $APP_PATH"
    fi

    # Verify architectures
    ARCHS=$(lipo -info "$APP_PATH/Contents/MacOS/$PROJECT_NAME" 2>/dev/null || echo "unknown")
    echo -e "${CYAN}Architectures: $ARCHS${NC}"

    log_success "Build complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Notarization
# ─────────────────────────────────────────────────────────────────────────────
notarize_app() {
    if [[ "$SKIP_NOTARIZE" == true ]]; then
        log_warning "Skipping notarization (--skip-notarize)"
        return
    fi

    log_step "Notarizing App"

    APP_PATH="$EXPORT_PATH/$PROJECT_NAME.app"
    NOTARIZE_ZIP="$BUILD_DIR/$PROJECT_NAME-notarize.zip"

    # Create ZIP for notarization
    echo -e "${YELLOW}Creating ZIP for notarization...${NC}"
    ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"

    # Submit for notarization
    echo -e "${YELLOW}Submitting to Apple...${NC}"

    # Try keychain profile first, fall back to prompting
    if xcrun notarytool submit "$NOTARIZE_ZIP" \
        --keychain-profile "notarytool-profile" \
        --wait 2>/dev/null; then
        log_success "Notarization complete"
    else
        log_warning "Keychain profile not found. Using manual credentials..."
        echo "Enter Apple ID email:"
        read -r APPLE_ID
        xcrun notarytool submit "$NOTARIZE_ZIP" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --wait
    fi

    # Staple
    echo -e "${YELLOW}Stapling ticket...${NC}"
    xcrun stapler staple "$APP_PATH"

    # Cleanup
    rm -f "$NOTARIZE_ZIP"

    log_success "Notarization and stapling complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: Create Release Artifacts
# ─────────────────────────────────────────────────────────────────────────────
create_artifacts() {
    log_step "Creating Release Artifacts"

    APP_PATH="$EXPORT_PATH/$PROJECT_NAME.app"
    ZIP_NAME="$PROJECT_NAME-v${VERSION}-universal.zip"

    # Create ZIP
    echo -e "${YELLOW}Creating ZIP...${NC}"
    ditto -c -k --keepParent "$APP_PATH" "$RELEASE_DIR/$ZIP_NAME"

    # Create checksums
    cd "$RELEASE_DIR"
    shasum -a 256 "$ZIP_NAME" > checksums.txt

    # Show results
    echo -e "${CYAN}Release artifacts:${NC}"
    ls -lh "$RELEASE_DIR"

    log_success "Artifacts created"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 5: Create GitHub Release
# ─────────────────────────────────────────────────────────────────────────────
create_github_release() {
    if [[ "$LOCAL_ONLY" == true ]]; then
        log_warning "Skipping GitHub upload (--local)"
        return
    fi

    log_step "Creating GitHub Release"

    ZIP_NAME="$PROJECT_NAME-v${VERSION}-universal.zip"

    # Check if tag exists
    if git -C "$PROJECT_ROOT" rev-parse "v$VERSION" >/dev/null 2>&1; then
        log_warning "Tag v$VERSION already exists"
    else
        echo -e "${YELLOW}Creating tag v$VERSION...${NC}"
        git -C "$PROJECT_ROOT" tag "v$VERSION"
        git -C "$PROJECT_ROOT" push origin "v$VERSION"
    fi

    # Create release
    echo -e "${YELLOW}Creating GitHub release...${NC}"

    CHECKSUM=$(cat "$RELEASE_DIR/checksums.txt")

    gh release create "v$VERSION" \
        $DRAFT_FLAG \
        --repo "$(git -C "$PROJECT_ROOT" remote get-url origin)" \
        --title "DuckDocs v$VERSION" \
        --notes "## DuckDocs v$VERSION

### Installation
1. Download \`$ZIP_NAME\`
2. Unzip the file
3. Move DuckDocs.app to your Applications folder
4. Open DuckDocs from Applications

### System Requirements
- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac (Universal Binary)

### Checksums (SHA256)
\`\`\`
$CHECKSUM
\`\`\`
" \
        "$RELEASE_DIR/$ZIP_NAME" \
        "$RELEASE_DIR/checksums.txt"

    log_success "GitHub release created!"
    echo -e "${CYAN}View release: https://github.com/$(git -C "$PROJECT_ROOT" remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/releases/tag/v$VERSION${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
main() {
    cd "$PROJECT_ROOT"

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}        🦆 DuckDocs Release Script                          ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"

    get_version
    preflight_checks
    build_universal
    notarize_app
    create_artifacts
    create_github_release

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}        🎉 Release Complete!                                ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Artifacts in: ${CYAN}$RELEASE_DIR${NC}"
    echo ""
}

main
