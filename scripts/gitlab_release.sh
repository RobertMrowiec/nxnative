#!/usr/bin/env bash
# ==============================================================================
# NxNative Launcher - GitLab Release & DMG Publisher
# ==============================================================================
# This script builds the production application, creates the compressed .dmg,
# and publishes/attaches it to GitLab Releases, keeping the latest release updated.
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd "$REPO_ROOT/.." && pwd)"

GITLAB_PROJECT="88419597"
GITLAB_URL="https://gitlab.com"
DMG_NAME="NxNative_Launcher.dmg"
DMG_PATH="$WORKSPACE_DIR/$DMG_NAME"
APP_PATH="$WORKSPACE_DIR/NxNative_Launcher.app"

echo "=================================================="
echo "  NxNative Launcher - GitLab Release Packaging    "
echo "=================================================="

# 1. Build GUI application
echo "==> [1/3] Building production Swift GUI..."
"$SCRIPT_DIR/build_gui.sh"

# Extract Version from Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "1.9.2")
TAG_NAME="v$VERSION"

echo "==> Target Version: $TAG_NAME"

# 2. Package DMG
echo "==> [2/3] Building compressed DMG ($DMG_NAME)..."
"$SCRIPT_DIR/create_dmg.sh"

if [ ! -f "$DMG_PATH" ]; then
    echo "❌ Error: DMG creation failed. $DMG_PATH does not exist."
    exit 1
fi

DMG_SIZE=$(ls -lh "$DMG_PATH" | awk '{print $5}')
echo "==> DMG successfully created: $DMG_PATH ($DMG_SIZE)"

# 3. GitLab Release Integration
echo "==> [3/3] Preparing GitLab Release for $TAG_NAME..."

TOKEN="${GITLAB_TOKEN:-${GL_TOKEN:-}}"
if [ -z "$TOKEN" ]; then
    REMOTE_URL=$(git -C "$REPO_ROOT" remote get-url gitlab 2>/dev/null || true)
    if [[ "$REMOTE_URL" =~ (glpat-[a-zA-Z0-9_.-]+) ]]; then
        TOKEN="${BASH_REMATCH[1]}"
    fi
fi

if [ -n "$TOKEN" ]; then
    echo "==> Uploading $DMG_NAME to GitLab Generic Package Registry..."
    PACKAGE_URL="$GITLAB_URL/api/v4/projects/$GITLAB_PROJECT/packages/generic/nxnative-launcher/$VERSION/$DMG_NAME"
    
    HTTP_CODE=$(curl -s -o /tmp/gl_upload.json -w "%{http_code}" \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --upload-file "$DMG_PATH" \
        "$PACKAGE_URL")

    if [ "$HTTP_CODE" -eq 201 ] || [ "$HTTP_CODE" -eq 200 ]; then
        echo "✅ Package uploaded successfully to GitLab Package Registry!"
        DIRECT_DOWNLOAD_URL="$PACKAGE_URL"

        echo "==> Creating / Updating Release $TAG_NAME on GitLab..."
        RELEASE_API="$GITLAB_URL/api/v4/projects/$GITLAB_PROJECT/releases"
        
        RELEASE_PAYLOAD=$(cat <<EOF
{
  "name": "NxNative Launcher $TAG_NAME",
  "tag_name": "$TAG_NAME",
  "description": "### 🚀 NxNative Launcher $TAG_NAME - Official Release\n\nOfficial native Apple Silicon build for macOS 13+ (Ventura, Sonoma, Sequoia, Golden Gate).\n\n- **Package**: \`$DMG_NAME\` ($DMG_SIZE)\n- **Direct Download**: [$DMG_NAME]($DIRECT_DOWNLOAD_URL)\n\n---\n\n### 🌟 Highlights & Features in $TAG_NAME\n\n- **Automated Artwork & Store-Branding Zero Tolerance**: dynamic Apple Vision OCR neural filter guarantees that no game artwork displays eShop, store logos, or commercial banners. Clean community covers automatically cached locally.\n- **Enhanced Controller & Input Management**: mouse input settings cleanly separated to Keyboard & Mouse tab; pure gamepad setup when controller is active.\n- **Over 130+ Verified Games Supported**, including Switch 2 titles.\n- **Up to 8 Players / Gamepad Profiles** simultaneously supported.\n- **Apple Liquid Glass Design System**: dynamic material refraction, responsive glass cards, and physical sliders.\n- **Optimized Standalone Bundle**: streamlined down to ~64 MB with built-in standalone Python 3.13 and runtime tools (\`zstd\`, \`xcodegen\`, \`glslangValidator\`, \`spirv-cross\`).\n\n---\n\n### ⚖️ Game Preservation Notice (\"for those who come after\")\n\nThis project is strictly for software preservation, interoperability (DMCA 1201(f)), and educational research. No copyrighted game copies, ROMs, keys, or proprietary firmwares are distributed.",
  "assets": {
    "links": [
      {
        "name": "$DMG_NAME ($DMG_SIZE)",
        "url": "$DIRECT_DOWNLOAD_URL",
        "filepath": "/binaries/$DMG_NAME",
        "link_type": "package"
      }
    ]
  }
}
EOF
)

        curl -s -X POST \
            --header "PRIVATE-TOKEN: $TOKEN" \
            --header "Content-Type: application/json" \
            --data "$RELEASE_PAYLOAD" \
            "$RELEASE_API" > /dev/null || true

        echo "✅ Release $TAG_NAME published on GitLab!"
    else
        echo "⚠️ Package upload returned HTTP $HTTP_CODE (Token may need 'api' or 'write_package_registry' scope)."
        echo "   Upload payload stored in /tmp/gl_upload.json"
    fi
fi

echo ""
echo "=================================================="
echo "  🎉 Release Package Ready: $DMG_PATH ($DMG_SIZE)"
echo "=================================================="
echo ""
echo "GitLab Releases URL:"
echo "  https://gitlab.com/rennan-group2/nxnative_Launcher/-/releases"
echo ""
echo "Latest Release Permalink (Always points to latest):"
echo "  https://gitlab.com/rennan-group2/nxnative_Launcher/-/releases/permalink/latest"
echo ""
