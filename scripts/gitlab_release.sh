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
  "description": "### 🚀 NxNative Launcher $TAG_NAME - Official Release\\n\\nOfficial native Apple Silicon build for **macOS 26.6+ (macOS Tahoe)** with **Apple Metal 4** & **Xcode 27.2+** (and **iOS 26.0+ / iPadOS 26.0+** for iPhone/iPad builds).\\n\\n- **Package**: \`$DMG_NAME\` ($DMG_SIZE)\\n- **Direct Download**: [$DMG_NAME]($DIRECT_DOWNLOAD_URL)\\n- **System Requirements**: Apple Silicon Mac (\`M1\`–\`M4+\`) running **macOS 26.6+ (Tahoe)** and **Xcode 27.2+** with **Metal 4** (\`MetalToolchain\`).\\n\\n---\\n\\n### 🌟 Destaques & Otimizações em $TAG_NAME\\n\\n- **🗡️ The Legend of Zelda: Ocarina of Time (Switch 2 · \`0400486024DEC000\`)**:\\n  - **Vídeos e Cutscenes a 60 FPS**: Bypass automático da rede neural NDVE (\`0x3b5f524\`) em favor do reprodutor nativo 1080p, eliminando a queda pesada de 47.5ms/frame (20 fps) nas introduções e história.\\n  - **Pacing de 60 FPS no Motor**: Integração de patch \`frame_step\` (\`0x3b4f074\`) no controlador interno de vsync, garantindo 60 FPS fluidos em velocidade normal 1.0x (sem aceleração 2x).\\n  - **MetalFX Spatial Nativo**: Substituição do upscaler de compute pesado pelo MetalFX nativo do macOS Tahoe (Metal 4), economizando banda e GPU.\\n  - **Gerenciamento de Memória para Macs 16 GB**: Ativação de compressão lossy em render targets de cor (\`rt_lossy\`), descarte imediato de páginas de memória guest de texturas após upload (\`DM_TEX_RELEASE=2\`) e supressão de texturas retiradas (\`pool_skip_retired\`).\\n  - **Overlays de Resolução Automáticos**: Geração automática de presets de resolução dinâmica (\`romfs_overlay\` para docked, handheld e potato) embutidos no pacote \`.app\` sem comandos manuais.\\n  - **Isolamento Estrito**: Todas as otimizações específicas são aplicadas exclusivamente ao Title ID \`0400486024DEC000\`, preservando 100% de estabilidade para todos os demais jogos.\\n\\n- **🚀 NxNative Launcher GUI & Sistema**:\\n  - **Nova Aba de Atualizações em Configurações**: Acompanhamento de versões, changelog detalhado e atualização em 1 clique direto pela interface.\\n  - **Injeção Inteligente de Ambiente**: Preserva chaves de configuração personalizadas no \`env.txt\` sem sobrescrever parâmetros do motor.\\n  - **Watchdog Zero-Hang Mandatório**: Proteção ativa contra travamentos na inicialização de jogos com timeouts rígidos em subprocessos.\\n\\n---\\n\\n### 📖 Instruções para Usuários\\n\\n#### 🆕 Para quem vai portar pela primeira vez (Novo Port):\\n1. Abra o **NxNative Launcher** e vá na aba **Portar Jogo**.\\n2. Selecione a pasta com os NSPs de *The Legend of Zelda: Ocarina of Time*.\\n3. Inicie a conversão. O launcher aplicará automaticamente todos os patches de 60 FPS, compilará o motor gráfico \`dmhost\` e gerará o \`romfs_overlay\` sem necessidade de comandos no terminal.\\n\\n#### 🔄 Para quem já portou o jogo anteriormente (.app existente):\\n1. Como os pacotes \`.app\` no macOS são autossuficientes e guardam sua própria cópia do motor \`dmhost\` e binários compilados, para receber as cutscenes em 60 FPS e o novo motor gráfico basta clicar em **Portar novamente** na pasta do jogo.\\n2. Caso tenha mantido a pasta \`0400486024DEC000_build\`, o launcher reaproveita todo o cache de shaders e a re-geração do \`.app\` leva apenas **1 a 2 minutos**!\\n\\n---\\n\\n### ⚖️ Game Preservation Notice (\\\"for those who come after\\\")\\n\\nThis project is strictly for software preservation, interoperability (DMCA 1201(f)), and educational research. No copyrighted game copies, ROMs, keys, or proprietary firmwares are distributed.",
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
