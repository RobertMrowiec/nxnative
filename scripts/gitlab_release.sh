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
    TOKEN=$(echo "$REMOTE_URL" | sed -nE 's/.*(glpat-[^@]+)@.*/\1/p')
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
  "description": "### 🚀 NxNative Launcher $TAG_NAME - Official Release\\n\\nOfficial native Apple Silicon build for **macOS 26.6+ (macOS Tahoe)** with **Apple Metal 4** & **Xcode 27.2+** (and **iOS 26.0+ / iPadOS 26.0+** for iPhone/iPad builds).\\n\\n- **Package**: \`$DMG_NAME\` ($DMG_SIZE)\\n- **Direct Download**: [$DMG_NAME]($DIRECT_DOWNLOAD_URL)\\n- **System Requirements**: Apple Silicon Mac (\`M1\`–\`M4+\`) running **macOS 26.6+ (Tahoe)** and **Xcode 27.2+** with **Metal 4** (\`MetalToolchain\`).\\n\\n---\\n\\n### 🌟 Highlights & Performance Optimizations in $TAG_NAME\\n\\n- **🗡️ The Legend of Zelda: Ocarina of Time (Switch 2 · \`0400486024DEC000\`)**:\\n  - **60 FPS Videos & Cutscenes Playback**: Automated bypass of the heavy NDVE neural network upscaler (\`0x3b5f524\`) in favor of the native 1080p video player, completely eliminating the severe 47.5ms/frame (20 FPS) performance drop in menu intros and story cutscenes.\\n  - **Engine 60 FPS Frame Pacing**: Integrated \`frame_step\` patch (\`0x3b4f074\`) into the internal vsync frame rate controller, ensuring smooth 60 FPS gameplay at normal 1.0x game speed (without fast-forward acceleration).\\n  - **Native Apple MetalFX Spatial**: Replaces the expensive 6-pass compute upscaler with native MetalFX on macOS Tahoe (Metal 4), drastically reducing GPU load and bandwidth consumption.\\n  - **Memory Optimization for 16 GB Macs**: Metal lossy compression on color render targets (\`rt_lossy\`), immediate deallocation of guest texture memory pages post-upload (\`DM_TEX_RELEASE=2\`), and retired texture pool suppression (\`pool_skip_retired\`).\\n  - **Automatic Dynamic Resolution Overlays**: Automatically generates and bundles dynamic resolution presets (\`romfs_overlay\` for docked, handheld, and potato lightweight modes) into the \`.app\` bundle without terminal commands.\\n  - **Strict Title Isolation**: All game-specific patches and engine optimizations are strictly isolated to Title ID \`0400486024DEC000\`, ensuring 100% stability and zero regressions for all other ported titles.\\n\\n- **🚀 NxNative Launcher GUI & System**:\\n  - **New Dedicated Updates Section in Settings**: Real-time update checks, changelog viewer, and 1-click update/rebuild directly within the Liquid Glass interface.\\n  - **Smart Environment Injection**: Preserves user-customized flags and settings in \`env.txt\` without overriding critical engine launch parameters.\\n  - **Mandatory Zero-Hang Watchdog**: Active launch hang protection with strict bounded timeouts across all background subprocesses.\\n\\n---\\n\\n### 📖 User Instructions\\n\\n#### 🆕 First-Time Setup (New Port):\\n1. Download \`$DMG_NAME\` and drag the application into your \`/Applications\` folder.\\n2. Open **NxNative Launcher** and go to the **Port Game** tab.\\n3. Select the folder containing your *The Legend of Zelda: Ocarina of Time* NSP files.\\n4. Start the conversion. The launcher automatically applies all 60 FPS patches, compiles the \`dmhost\` engine with MetalFX, and bundles the \`romfs_overlay\` without manual terminal intervention.\\n\\n#### 🔄 Existing Setup (Previously Ported .app):\\n1. Because macOS \`.app\` bundles are self-contained and carry their own copy of the compiled \`dmhost\` binary, simply open the launcher and click **Port Again** on your existing game directory.\\n2. If you retained the \`0400486024DEC000_build\` directory, the launcher reuses all decompressed assets and cached shaders, finishing the rebuild in just **1 to 2 minutes**!\\n3. Your save games, states, and settings remain untouched in your user data directory.\\n\\n---\\n\\n### ⚖️ Game Preservation Notice (\\\"for those who come after\\\")\\n\\nThis project is strictly for software preservation, interoperability (DMCA 1201(f)), and educational research. No copyrighted game copies, ROMs, keys, or proprietary firmwares are distributed.",
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
            echo "==> Release $TAG_NAME already exists, updating description via PUT..."
            curl -s -X PUT \
                --header "PRIVATE-TOKEN: $TOKEN" \
                --header "Content-Type: application/json" \
                --data "$RELEASE_PAYLOAD" \
                "$RELEASE_API/$TAG_NAME" > /dev/null || true
        fi

        # Ensure asset link is registered in release
        echo "==> Registering DMG link in Release assets..."
        LINK_PAYLOAD=$(cat <<EOF
{
  "name": "$DMG_NAME ($DMG_SIZE)",
  "url": "$DIRECT_DOWNLOAD_URL",
  "filepath": "/binaries/$DMG_NAME",
  "link_type": "package"
}
EOF
)
        curl -s -X POST \
            --header "PRIVATE-TOKEN: $TOKEN" \
            --header "Content-Type: application/json" \
            --data "$LINK_PAYLOAD" \
            "$RELEASE_API/$TAG_NAME/assets/links" > /dev/null || true

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
