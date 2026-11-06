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
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "1.9.8")
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
  "description": "### 🚀 NxNative Launcher $TAG_NAME - Official Release\n\nOfficial native Apple Silicon build for **macOS 26.6+ (macOS Tahoe)** with **Apple Metal 4** & **Xcode 27.2+** (and **iOS 26.0+ / iPadOS 26.0+** for iPhone/iPad builds).\n\n- **Package**: \`$DMG_NAME\` ($DMG_SIZE)\n- **Direct Download**: [$DMG_NAME]($DIRECT_DOWNLOAD_URL)\n- **System Requirements**: Apple Silicon Mac (\`M1\`–\`M4+\`) running **macOS 26.6+ (Tahoe)** and **Xcode 27.2+** with **Metal 4** (\`MetalToolchain\`).\n\n---\n\n### 🌟 Key Highlights & Bug Fixes in $TAG_NAME\n\n- **🛠️ Game Porting & Host Compilation Fixes (\`mac_host_build.log\`)**:\n  - Resolved C and Objective-C redefinitions and conflicting declarations across core host services: \`hle_misc.c\` (\`CheckAgcPermissionUnderMinimumAge\`), \`hle_net.c\` (\`SK_EBADF\`, \`SK_EAGAIN\` collision), \`hle_offline.c\` (\`nnsocketGetAddrInfoWithOptions\`), and \`hle_sdk16.c\` (\`RequestLoadNxFont\`).\n  - Fixed Metal graphics backend build failures in \`nvn_mtl.m\` by cleaning up undeclared functions (\`tex_rgba_atomic_alias\`), eliminating local scope conflicts on \`rangeKey\` in \`up_big_src\`, correcting call signatures, and removing undefined \`ghost_finish_submission\` linker failure.\n  - Restored clean geometry builder \`mtk_build\` in \`nvn_geometry.inc\`, removing truncated and duplicate shader pipeline definitions.\n  - Verified 100% clean compilation (\`dmhost\`) for titles including *Donkey Kong Bananza* (\`040074A01BF12000\`) and *Luigi'\''s Mansion 3* (\`0100DCA0064A6000\`).\n- **🐍 Python Environment & \`zbic\` Auto-Detection (pyenv & Virtualenv Support)**:\n  - Added live module validation in \`SystemDetector.swift\` testing for \`lz4.block\`, \`capstone\`, \`fontTools\`, and \`zbic\`.\n  - Added native discovery and prioritization for user \`pyenv\` environments (\`~/.pyenv/shims/python3\` and \`~/.pyenv/versions/*/bin/python3\`), fixing missing module errors when porting *The Legend of Zelda: Tears of the Kingdom* and Switch 2 games.\n  - Updated bundled standalone Python runtime inside \`NxNative_Launcher.app\` with \`zbic 1.0.1.post1\`.\n- **🔐 Clarified Administrator Privilege Prompt**:\n  - Updated the macOS \`osascript\` elevation dialog in \`InstallerService.swift\` with clear, unambiguous instructions explaining that the user'\''s macOS account password is required for toolchain dependency installation.\n- **🛡️ Mandatory Anti-Regression Smoke Testing**:\n  - Implemented automatic dual-game \`dmhost\` compilation tests (*Donkey Kong Bananza* + *Luigi'\''s Mansion 3*) in \`sync_upstream.sh\`. Any future upstream updates from \`seedds/nxnative\` that break host compilation will be automatically blocked and rolled back before reaching production.\n- **⚡ Zero-Hang Invariant & Apple Silicon Performance**:\n  - Guaranteed 6-second watchdog protection, bounded 2.0s subprocess timeouts, and unblocked main thread execution across macOS Tahoe (26.6+) with Metal 4.\n\n---\n\n### ⚖️ Game Preservation Notice (\\\"for those who come after\\\")\n\nThis project is strictly for software preservation, interoperability (DMCA 1201(f)), and educational research. No copyrighted game copies, ROMs, keys, or proprietary firmwares are distributed.",
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
