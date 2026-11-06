#!/usr/bin/env bash
# Prepares the isolated standalone Python runtime and tools for NxNative Launcher
#
# Target directory structure:
#   <Resources>/python/bin/python3
#   <Resources>/python/lib/...
#   <Resources>/tools/bin/{zstd, glslangValidator, spirv-cross, xcodegen}
#   <Resources>/tools/share/xcodegen
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEST_RES="${1:-$REPO_ROOT/gui/Resources}"
WORK_DIR="${2:-/tmp/nxnative-bundle-cache}"

PYTHON_VERSION="3.13.18"
PYTHON_RELEASE="20261026"
PYTHON_SHA256="e5af2fde6a937a0e0c795a0c595c4efb70578d57463a2657c819992b9b9acbac"
PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/$PYTHON_RELEASE/cpython-$PYTHON_VERSION+$PYTHON_RELEASE-aarch64-apple-darwin-install_only.tar.gz"

XCODEGEN_VERSION="2.46.0"
XCODEGEN_SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"
XCODEGEN_URL="https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip"

ZSTD_VERSION="1.5.7"
ZSTD_SHA256="37d7284556b20954e56e1ca85b80226768902e2edabd3b649e9e72c0c9012ee3"
ZSTD_URL="https://github.com/facebook/zstd/archive/refs/tags/v$ZSTD_VERSION.tar.gz"

GLSLANG_VERSION="16.6.0"
GLSLANG_SHA256="9c09b901149c729df745057dafa815278aaa101b84d2b6e14f16a42de52f97f2"
GLSLANG_URL="https://github.com/KhronosGroup/glslang/archive/refs/tags/$GLSLANG_VERSION.tar.gz"

SPIRV_CROSS_TAG="vulkan-sdk-1.4.363.0"
SPIRV_CROSS_SHA256="f708982e88b763ef5b0394ed468fc2c3628f68cdab89f2e7a946cd628c04e721"
SPIRV_CROSS_URL="https://github.com/KhronosGroup/SPIRV-Cross/archive/refs/tags/$SPIRV_CROSS_TAG.tar.gz"

mkdir -p "$DEST_RES" "$WORK_DIR/dl"
DEST_RES="$(cd "$DEST_RES" && pwd)"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"
JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
export MACOSX_DEPLOYMENT_TARGET=13.0

fetch() {
    local url="$1"
    local expected_sha="$2"
    local file="$WORK_DIR/dl/$(basename "$url")"
    if [ ! -f "$file" ]; then
        echo "--> Downloading: $url" >&2
        curl -fsSL --retry 3 -o "$file.part" "$url"
        mv "$file.part" "$file"
    fi
    local actual_sha
    actual_sha=$(shasum -a 256 "$file" | cut -c1-64)
    if [ "$actual_sha" != "$expected_sha" ]; then
        echo "[ERROR] SHA256 mismatch for $(basename "$file"): expected $expected_sha, got $actual_sha" >&2
        rm -f "$file"
        exit 1
    fi
    echo "$file"
}

unpack() {
    local tarball="$1"
    local dest="$2"
    rm -rf "$dest"
    mkdir -p "$dest"
    tar -xzf "$tarball" -C "$dest" --strip-components=1
}

echo "=========================================="
echo "NxNative Bundled Tools & Runtime Generator"
echo "Target Resources: $DEST_RES"
echo "Cache Work Dir:   $WORK_DIR"
echo "=========================================="

TOOLS_BIN="$DEST_RES/tools/bin"
TOOLS_SHARE="$DEST_RES/tools/share"
mkdir -p "$TOOLS_BIN" "$TOOLS_SHARE"

# 1. Standalone CPython Runtime
echo "==> Configuring Standalone CPython $PYTHON_VERSION"
if [ ! -x "$DEST_RES/python/bin/python3" ]; then
    PY_TAR=$(fetch "$PYTHON_URL" "$PYTHON_SHA256")
    rm -rf "$WORK_DIR/python-extract" "$DEST_RES/python"
    mkdir -p "$WORK_DIR/python-extract"
    tar -xzf "$PY_TAR" -C "$WORK_DIR/python-extract"
    mv "$WORK_DIR/python-extract/python" "$DEST_RES/python"
    rm -rf "$WORK_DIR/python-extract"

    PY_BIN="$DEST_RES/python/bin/python3"
    echo "==> Installing pre-compiled binary wheels into standalone Python..."
    "$PY_BIN" -I -m pip install --disable-pip-version-check --no-warn-script-location --only-binary :all: \
        -r "$SCRIPT_DIR/bundled-python-requirements.txt"

    # Remove absolute path shebangs in bin/
    for script_file in "$DEST_RES/python/bin/"*; do
        if [ -f "$script_file" ] && [ ! -L "$script_file" ]; then
            if head -c 2 "$script_file" | grep -q '#!' && grep -q "$DEST_RES" "$script_file"; then
                rm -f "$script_file"
            fi
        fi
    done

    # Strip unused libraries (tests, idle, tkinter, pip, development headers) to reduce bundle size
    PY_LIB_SITE="$DEST_RES/python/lib/python${PYTHON_VERSION%.*}"
    rm -rf "$PY_LIB_SITE/test" "$PY_LIB_SITE/idlelib" "$PY_LIB_SITE/turtledemo" "$PY_LIB_SITE/tkinter" \
           "$PY_LIB_SITE/lib-dynload/_tkinter"*.so "$DEST_RES/python/lib/libtcl"* "$DEST_RES/python/lib/libtk"* \
           "$DEST_RES/python/lib/itcl"* "$DEST_RES/python/lib/thread"* "$DEST_RES/python/lib/pkgconfig" \
           "$PY_LIB_SITE/site-packages/pip"* "$PY_LIB_SITE/ensurepip" "$DEST_RES/python/include" \
           "$DEST_RES/python/share/man" 2>/dev/null || true
    find "$DEST_RES/python" -type d -name tests -path '*site-packages*' -prune -exec rm -rf {} + 2>/dev/null || true
    find "$DEST_RES/python" -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

    echo "==> Verifying standalone Python packages..."
    "$PY_BIN" -I -c "import lz4.block, capstone, fontTools, nsz, zbic, ssl, sqlite3, zlib, lzma, bz2; print('All core modules OK')"
else
    echo "--> Standalone Python already prepared at $DEST_RES/python"
fi

# 2. XcodeGen
echo "==> Preparing XcodeGen $XCODEGEN_VERSION"
if [ ! -x "$TOOLS_BIN/xcodegen" ]; then
    XCG_ZIP=$(fetch "$XCODEGEN_URL" "$XCODEGEN_SHA256")
    rm -rf "$WORK_DIR/xcodegen-extract"
    mkdir -p "$WORK_DIR/xcodegen-extract"
    ditto -x -k "$XCG_ZIP" "$WORK_DIR/xcodegen-extract"
    XCG_BIN=$(find "$WORK_DIR/xcodegen-extract" -name xcodegen -type f -perm -u+x -path '*/bin/*' | head -1)
    if [ -n "$XCG_BIN" ]; then
        XCG_ROOT=$(dirname "$(dirname "$XCG_BIN")")
        cp "$XCG_BIN" "$TOOLS_BIN/xcodegen"
        chmod +x "$TOOLS_BIN/xcodegen"
        if [ -d "$XCG_ROOT/share/xcodegen" ]; then
            cp -R "$XCG_ROOT/share/xcodegen" "$TOOLS_SHARE/"
        fi
    fi
    rm -rf "$WORK_DIR/xcodegen-extract"
fi

# 3. zstd (Static binary)
echo "==> Preparing zstd $ZSTD_VERSION"
if [ ! -x "$TOOLS_BIN/zstd" ]; then
    if [ -f "$WORK_DIR/zstd-bin/zstd" ]; then
        cp "$WORK_DIR/zstd-bin/zstd" "$TOOLS_BIN/zstd"
    else
        ZSTD_TAR=$(fetch "$ZSTD_URL" "$ZSTD_SHA256")
        unpack "$ZSTD_TAR" "$WORK_DIR/zstd-src"
        make -C "$WORK_DIR/zstd-src/programs" -j "$JOBS" zstd HAVE_ZLIB=0 HAVE_LZMA=0 HAVE_LZ4=0 >/dev/null 2>&1
        mkdir -p "$WORK_DIR/zstd-bin"
        cp "$WORK_DIR/zstd-src/programs/zstd" "$WORK_DIR/zstd-bin/zstd"
        cp "$WORK_DIR/zstd-bin/zstd" "$TOOLS_BIN/zstd"
    fi
    chmod +x "$TOOLS_BIN/zstd"
fi

# 4. SPIRV-Cross (Static binary)
echo "==> Preparing SPIRV-Cross $SPIRV_CROSS_TAG"
if [ ! -x "$TOOLS_BIN/spirv-cross" ]; then
    if [ -x "/opt/homebrew/bin/spirv-cross" ] && otool -L "/opt/homebrew/bin/spirv-cross" | grep -v -E "libc\+\+|libSystem" | grep -q "dylib" || [ ! -x "/opt/homebrew/bin/spirv-cross" ]; then
        SPIRV_TAR=$(fetch "$SPIRV_CROSS_URL" "$SPIRV_CROSS_SHA256")
        unpack "$SPIRV_TAR" "$WORK_DIR/spirv-cross-src"
        cmake -S "$WORK_DIR/spirv-cross-src" -B "$WORK_DIR/spirv-cross-build" -DCMAKE_BUILD_TYPE=Release \
            -DSPIRV_CROSS_ENABLE_TESTS=OFF -DSPIRV_CROSS_SKIP_INSTALL=ON \
            -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
            -DCMAKE_EXE_LINKER_FLAGS='-Wl,-S,-x' >/dev/null 2>&1
        cmake --build "$WORK_DIR/spirv-cross-build" --target spirv-cross -j "$JOBS" >/dev/null 2>&1
        cp "$WORK_DIR/spirv-cross-build/spirv-cross" "$TOOLS_BIN/spirv-cross"
    else
        cp "/opt/homebrew/bin/spirv-cross" "$TOOLS_BIN/spirv-cross"
    fi
    chmod +x "$TOOLS_BIN/spirv-cross"
fi

# 5. glslangValidator (Standalone binary)
echo "==> Preparing glslangValidator $GLSLANG_VERSION"
if [ ! -x "$TOOLS_BIN/glslangValidator" ]; then
    if [ -f "$WORK_DIR/glslang-bin/glslangValidator" ]; then
        cp "$WORK_DIR/glslang-bin/glslangValidator" "$TOOLS_BIN/glslangValidator"
    else
        GLSLANG_TAR=$(fetch "$GLSLANG_URL" "$GLSLANG_SHA256")
        unpack "$GLSLANG_TAR" "$WORK_DIR/glslang-src"
        cmake -S "$WORK_DIR/glslang-src" -B "$WORK_DIR/glslang-build" -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS=OFF -DENABLE_OPT=OFF -DBUILD_EXTERNAL=OFF \
            -DENABLE_CTEST=OFF -DGLSLANG_TESTS=OFF -DCMAKE_OSX_ARCHITECTURES=arm64 \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 -DCMAKE_EXE_LINKER_FLAGS='-Wl,-S,-x' >/dev/null 2>&1
        cmake --build "$WORK_DIR/glslang-build" --target glslang-standalone -j "$JOBS" >/dev/null 2>&1
        mkdir -p "$WORK_DIR/glslang-bin"
        cp -L "$WORK_DIR/glslang-build/StandAlone/glslang" "$WORK_DIR/glslang-bin/glslangValidator"
        cp "$WORK_DIR/glslang-bin/glslangValidator" "$TOOLS_BIN/glslangValidator"
    fi
    chmod +x "$TOOLS_BIN/glslangValidator"
fi

# 6. Ad-hoc codesign all nested Mach-O binaries in Resources
echo "==> Signing nested binaries ad-hoc..."
find "$DEST_RES/python" "$DEST_RES/tools" -type f | while read -r bin_file; do
    if file -b "$bin_file" 2>/dev/null | grep -q 'Mach-O'; then
        codesign --force --sign - "$bin_file" 2>/dev/null || true
    fi
done

echo "==> Done! Bundled tools successfully prepared in $DEST_RES"
du -sh "$DEST_RES/python" "$DEST_RES/tools" 2>/dev/null || true
