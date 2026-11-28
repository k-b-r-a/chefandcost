#!/usr/bin/env bash
# ==============================================================================
# Chef&Cost - Production Release Build & 16 KB Page Alignment Verification
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==================================================================${NC}"
echo -e "${BLUE}          Chef&Cost Google Play Release Build Pipeline            ${NC}"
echo -e "${BLUE}==================================================================${NC}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_VERSION="$(grep -E '^\s*version:' pubspec.yaml | head -n 1 | sed -E 's/^\s*version:\s*//' | tr -d '[:space:]')"
if [[ -z "$APP_VERSION" ]]; then
  echo -e "${RED}[ERROR] Could not parse version from pubspec.yaml${NC}" >&2
  exit 1
fi
echo -e "${BLUE}App Version: $APP_VERSION${NC}"

ALLOW_DEBUG="${ALLOW_DEBUG_SIGNED_RELEASE:-false}"
if [[ ! -f "android/key.properties" ]]; then
  if [[ "$ALLOW_DEBUG" == "true" ]]; then
    echo -e "${YELLOW}[WARNING] android/key.properties not detected. Using allowDebugSignedRelease=true for local R8 testing.${NC}"
  else
    echo -e "${RED}[ERROR] android/key.properties is missing. Configure android/key.properties or set ALLOW_DEBUG_SIGNED_RELEASE=true for local R8 testing.${NC}" >&2
    exit 1
  fi
fi

echo -e "\n${BLUE}==> [1/4] Running Flutter static analysis (flutter analyze)...${NC}"
flutter analyze

echo -e "\n${BLUE}==> [2/4] Running automated test suite (flutter test)...${NC}"
flutter test

echo -e "\n${BLUE}==> [3/4] Building production release Android App Bundle (AAB)...${NC}"
SYMBOLS_DIR="build/app/outputs/symbols"
rm -rf "$SYMBOLS_DIR"

BUILD_ARGS=(
  build appbundle --release
  --obfuscate
  "--split-debug-info=$SYMBOLS_DIR"
  "--dart-define=APP_VERSION=$APP_VERSION"
)
if [[ "$ALLOW_DEBUG" == "true" && ! -f "android/key.properties" ]]; then
  BUILD_ARGS+=("--android-project-arg=allowDebugSignedRelease=true")
fi

flutter "${BUILD_ARGS[@]}"

AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
if [[ ! -f "$AAB_PATH" ]]; then
  echo -e "${RED}[ERROR] Release bundle was not found at $AAB_PATH${NC}" >&2
  exit 1
fi

AAB_SIZE=$(du -h "$AAB_PATH" | cut -f1)
echo -e "${GREEN}[SUCCESS] Bundle successfully generated: $AAB_PATH ($AAB_SIZE)${NC}"

ARCHIVE_DIR="build/release-artifacts/$APP_VERSION"
mkdir -p "$ARCHIVE_DIR"
cp "$AAB_PATH" "$ARCHIVE_DIR/app-release.aab"
if [[ -f "build/app/outputs/mapping/release/mapping.txt" ]]; then
  cp "build/app/outputs/mapping/release/mapping.txt" "$ARCHIVE_DIR/mapping.txt"
fi
if [[ -d "$SYMBOLS_DIR" ]]; then
  rm -rf "$ARCHIVE_DIR/symbols"
  cp -r "$SYMBOLS_DIR" "$ARCHIVE_DIR/symbols"
fi
echo -e "${BLUE}[INFO] Archived release artifacts to $ARCHIVE_DIR${NC}"

echo -e "\n${BLUE}==> [4/4] Verifying 16 KB ELF memory page alignment on bundled native libraries...${NC}"
if ! command -v python3 &>/dev/null; then
  echo -e "${RED}[ERROR] python3 is required to verify 16 KB ELF page alignment.${NC}" >&2
  exit 1
fi

python3 - "$AAB_PATH" <<'EOF'
import sys, zipfile, struct

aab_path = sys.argv[1]
found = 0
failed = 0

with zipfile.ZipFile(aab_path, 'r') as zf:
    for name in zf.namelist():
        if not (name.startswith('base/lib/') and name.endswith('.so')):
            continue
        found += 1
        data = zf.read(name)
        if not data.startswith(b'\x7fELF') or data[4] != 2:
            print(f"  [INFO] {name} -> SKIPPED (32-bit or non-ELF)")
            continue
        e_phoff = struct.unpack('<Q', data[32:40])[0]
        e_phentsize = struct.unpack('<H', data[54:56])[0]
        e_phnum = struct.unpack('<H', data[56:58])[0]
        all_aligned = True
        min_align = None
        for i in range(e_phnum):
            off = e_phoff + i * e_phentsize
            ph = data[off:off+56]
            if len(ph) < 56:
                break
            p_type = struct.unpack('<I', ph[0:4])[0]
            if p_type == 1:
                p_align = struct.unpack('<Q', ph[48:56])[0]
                if min_align is None or p_align < min_align:
                    min_align = p_align
                if p_align < 16384:
                    all_aligned = False
        if all_aligned:
            print(f"  [PASS] {name} -> min p_align = {min_align} bytes (>= 16 KB)")
        else:
            print(f"  [FAIL] {name} -> min p_align = {min_align} bytes (< 16 KB)")
            failed += 1

if failed > 0:
    print(f"\n[ERROR] {failed} native library(ies) failed 16 KB page alignment!", file=sys.stderr)
    sys.exit(1)
print(f"\n[SUCCESS] Verified {found} native libraries; all 64-bit libraries are 16 KB page-aligned.")
EOF

echo -e "\n${GREEN}==================================================================${NC}"
echo -e "${GREEN}      Ready for Google Play Console: $ARCHIVE_DIR/app-release.aab ${NC}"
echo -e "${GREEN}==================================================================${NC}"
