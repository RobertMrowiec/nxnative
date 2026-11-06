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
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "1.9.6")
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
    # Clean up older releases so ONLY the latest version is kept on GitLab
    echo "==> Cleaning up older releases on GitLab (keeping only $TAG_NAME)..."
    OLD_RELEASES=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" "$GITLAB_URL/api/v4/projects/$GITLAB_PROJECT/releases" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    target = sys.argv[1]
    for r in data:
        tag = r.get("tag_name", "")
        if tag and tag != target:
            print(tag)
except Exception:
    pass
' "$TAG_NAME")

    for old_tag in $OLD_RELEASES; do
        echo "   -> Removing older release $old_tag from GitLab..."
        curl -s -X DELETE --header "PRIVATE-TOKEN: $TOKEN" "$GITLAB_URL/api/v4/projects/$GITLAB_PROJECT/releases/$old_tag" > /dev/null || true
    done

    # Also clean up older generic packages from GitLab Package Registry
    OLD_PKG_IDS=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" "$GITLAB_URL/api/v4/projects/$GITLAB_PROJECT/packages" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    target_ver = sys.argv[1]
    for p in data:
        if p.get("version") != target_ver and p.get("id"):
            print(p["id"])
except Exception:
    pass
' "$VERSION")

    for pkg_id in $OLD_PKG_IDS; do
        echo "   -> Removing older package ID $pkg_id from GitLab Package Registry..."
        curl -s -X DELETE --header "PRIVATE-TOKEN: $TOKEN" "$GITLAB_URL/api/v4/projects/$GITLAB_PROJECT/packages/$pkg_id" > /dev/null || true
    done

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
  "ref": "main",
  "description": "### 🚀 NxNative Launcher $TAG_NAME - Official Release\n\nOfficial native Apple Silicon build for macOS 13+ (Ventura, Sonoma, Sequoia, Tahoe).\n\n- **Package**: \`$DMG_NAME\` ($DMG_SIZE)\n- **Direct Download**: [$DMG_NAME]($DIRECT_DOWNLOAD_URL)\n\n---\n\n### 🌟 Highlights & Fixes in $TAG_NAME\n\n- **🗡️ The Legend of Zelda: Ocarina of Time (\`0400486024DEC000\` - Switch 2) Native macOS Port Support**: Complete profile (\`v0\` & \`v131072\`), NVN2 task/mesh shader translation to Apple Metal, Ampere \`F2IP\`/\`LDSM\` and float-add atomic shader fixes, NDVE compute movie scaling, parallel AV1 (\`dav1d\`) decoding, \`pool_skip_retired\` scene transition memory optimization, Kokiri Forest GPU heightmap preservation, and SDK 22 Ocarina note-playing service stubs.\n- **📦 Bundled \`zbic\` Module for SDK 22+ Switch 2 Games**: Pre-bundled \`zbic\` in the isolated standalone Python runtime and added prerequisite verification so ZBIC-compressed NSO segments (\`ExeFS/main\`) unpack out of the box without errors.\n- **🎮 144+ Verified Native macOS & iOS Games Catalog**: Full visual gallery in \`README.md\` and \`SUPPORTED_GAMES.md\` showcasing 10 Nintendo Switch 2 games (*Zelda: Ocarina of Time*, *Donkey Kong Bananza*, *Splatoon Raiders*, *Fire Emblem Fortune's Weave*, *Pokémon Pokopia*, *Hyrule Warriors: Age of Imprisonment*, *Mario Kart World*, *Mario Tennis Fever*, *Yoshi and the Mysterious Book*, *Star Fox*) and 134+ Nintendo Switch 1 games.\n- **⚡ Zero-Hang Invariant**: Guaranteed 6-second watchdog protection, bounded subprocess timeouts, and unblocked main thread execution.\n\n---\n\n### ⚖️ Game Preservation Notice (\"for those who come after\")\n\nThis project is strictly for software preservation, interoperability (DMCA 1201(f)), and educational research. No copyrighted game copies, ROMs, keys, or proprietary firmwares are distributed.",
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

        POST_RESP=$(curl -s -w "\n%{http_code}" -X POST \
            --header "PRIVATE-TOKEN: $TOKEN" \
            --header "Content-Type: application/json" \
            --data "$RELEASE_PAYLOAD" \
            "$RELEASE_API")
        POST_CODE=$(echo "$POST_RESP" | tail -n1)
        if [ "$POST_CODE" = "409" ]; then
            echo "==> Release $TAG_NAME already exists, updating via PUT..."
            curl -s -X PUT \
                --header "PRIVATE-TOKEN: $TOKEN" \
                --header "Content-Type: application/json" \
                --data "$RELEASE_PAYLOAD" \
                "$RELEASE_API/$TAG_NAME" > /dev/null || true
        fi

        echo "✅ Release $TAG_NAME published/updated on GitLab!"
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
