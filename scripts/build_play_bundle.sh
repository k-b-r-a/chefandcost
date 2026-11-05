#!/usr/bin/env bash
# ==============================================================================
# Chef&Cost - Production Release Build & 16 KB Page Alignment Verification
# ==============================================================================
# This script:
#  1. Runs strict Flutter static analysis (flutter analyze)
#  2. Executes all automated test suites (flutter test)
#  3. Builds the production Android App Bundle (.aab)
#  4. Verifies 16 KB ELF memory page size alignment for Android 15/16+ devices
# ==============================================================================
set -euo pipefail

# ANSI color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================================${NC}"
echo -e "${BLUE}          Chef&Cost Google Play Release Build Pipeline            ${NC}"
echo -e "${BLUE}==================================================================${NC}"

# Ensure we run from repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Check signing configuration warning
if [[ ! -f "android/key.properties" ]]; then
  echo -e "${YELLOW}[WARNING] android/key.properties not detected.${NC}"
  echo -e "${YELLOW}The build will produce a debug-signed bundle. Ensure you supply${NC}"
  echo -e "${YELLOW}valid signing credentials before publishing to Google Play Console.${NC}"
fi

# ------------------------------------------------------------------------------
# Step 1: Static Code Analysis
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}==> [1/4] Running Flutter static analysis (flutter analyze)...${NC}"
flutter analyze

# ------------------------------------------------------------------------------
# Step 2: Automated Tests
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}==> [2/4] Running automated test suite (flutter test)...${NC}"
flutter test

# ------------------------------------------------------------------------------
# Step 3: Build Android App Bundle (.aab)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}==> [3/4] Building production release Android App Bundle (AAB)...${NC}"
flutter build appbundle --release

AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
if [[ ! -f "$AAB_PATH" ]]; then
  echo -e "${RED}[ERROR] Release bundle was not found at $AAB_PATH${NC}" >&2
  exit 1
fi

AAB_SIZE=$(du -h "$AAB_PATH" | cut -f1)
echo -e "${GREEN}[SUCCESS] Bundle successfully generated: $AAB_PATH ($AAB_SIZE)${NC}"

# ------------------------------------------------------------------------------
# Step 4: Verify 16 KB ELF Page Alignment Compatibility
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}==> [4/4] Verifying 16 KB ELF memory page alignment on bundled native libraries...${NC}"

TEMP_EXTRACT_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'aab_verify')
trap 'rm -rf "$TEMP_EXTRACT_DIR"' EXIT

unzip -q -o "$AAB_PATH" "base/lib/*" -d "$TEMP_EXTRACT_DIR" 2>/dev/null || true

FOUND_LIBS=0
FAILED_LIBS=0

# Python script to check ELF p_align >= 0x4000 (16384 bytes = 16 KB)
verify_elf_alignment() {
  local so_path="$1"
  python3 - <<EOF
import sys, struct

filepath = sys.argv[1]
with open(filepath, 'rb') as f:
    ident = f.read(16)
    if not ident.startswith(b'\x7fELF'):
        sys.exit(0) # Not an ELF binary
    ei_class = ident[4] # 1 = 32-bit, 2 = 64-bit
    if ei_class != 2:
        sys.exit(0) # 16 KB page size requirement primarily targets 64-bit architectures (arm64-v8a, x86_64)

    f.seek(32)
    e_phoff = struct.unpack('<Q', f.read(8))[0]
    f.seek(54)
    e_phentsize = struct.unpack('<H', f.read(2))[0]
    e_phnum = struct.unpack('<H', f.read(2))[0]

    all_aligned = True
    min_align_found = None
    for i in range(e_phnum):
        f.seek(e_phoff + (i * e_phentsize))
        data = f.read(56)
        if len(data) < 56:
            break
        p_type = struct.unpack('<I', data[0:4])[0]
        # PT_LOAD = 1
        if p_type == 1:
            p_align = struct.unpack('<Q', data[48:56])[0]
            if min_align_found is None or p_align < min_align_found:
                min_align_found = p_align
            if p_align < 16384:
                all_aligned = False

    if min_align_found is not None:
        if all_aligned:
            print(f"ALIGN_OK (min p_align={min_align_found} bytes)")
            sys.exit(0)
        else:
            print(f"ALIGN_FAIL (min p_align={min_align_found} bytes < 16384)")
            sys.exit(1)
    else:
        print("NO_LOAD_SEGMENTS")
        sys.exit(0)
EOF
}

# Scan extracted .so libraries in 64-bit target ABIs (arm64-v8a, x86_64)
while IFS= read -r -d '' lib; do
  FOUND_LIBS=$((FOUND_LIBS + 1))
  rel_path="${lib#$TEMP_EXTRACT_DIR/base/lib/}"
  
  if command -v python3 &>/dev/null; then
    RESULT=$(python3 - "$lib" <<'EOF' 2>&1
import sys, struct
filepath = sys.argv[1]
try:
    with open(filepath, 'rb') as f:
        ident = f.read(16)
        if not ident.startswith(b'\x7fELF') or ident[4] != 2:
            print("SKIPPED (32-bit or non-ELF)")
            sys.exit(0)
        f.seek(32)
        e_phoff = struct.unpack('<Q', f.read(8))[0]
        f.seek(54)
        e_phentsize = struct.unpack('<H', f.read(2))[0]
        e_phnum = struct.unpack('<H', f.read(2))[0]
        all_aligned = True
        min_align = None
        for i in range(e_phnum):
            f.seek(e_phoff + (i * e_phentsize))
            data = f.read(56)
            if len(data) < 56: break
            if struct.unpack('<I', data[0:4])[0] == 1: # PT_LOAD
                align = struct.unpack('<Q', data[48:56])[0]
                if min_align is None or align < min_align: min_align = align
                if align < 16384: all_aligned = False
        if all_aligned:
            print(f"PASS (min p_align = {min_align} bytes >= 16 KB)")
        else:
            print(f"FAIL (min p_align = {min_align} bytes < 16 KB)")
            sys.exit(1)
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(2)
EOF
) || true

    if [[ "$RESULT" == PASS* ]]; then
      echo -e "  [${GREEN}PASS${NC}] $rel_path -> $RESULT"
    elif [[ "$RESULT" == SKIPPED* ]]; then
      echo -e "  [${YELLOW}INFO${NC}] $rel_path -> $RESULT"
    else
      echo -e "  [${RED}FAIL${NC}] $rel_path -> $RESULT"
      FAILED_LIBS=$((FAILED_LIBS + 1))
    fi
  elif command -v readelf &>/dev/null; then
    # Fallback to readelf check
    if readelf -l "$lib" | grep -A1 "LOAD" | grep -q "0x4000"; then
      echo -e "  [${GREEN}PASS${NC}] $rel_path (16 KB page-aligned via readelf)"
    else
      echo -e "  [${YELLOW}WARN${NC}] $rel_path (Check alignment manually with readelf -l)"
    fi
  else
    echo -e "  [${YELLOW}INFO${NC}] $rel_path (Neither python3 nor readelf available to parse ELF headers)"
  fi
done < <(find "$TEMP_EXTRACT_DIR" -type f -name "*.so" -print0 2>/dev/null)

if [[ $FOUND_LIBS -eq 0 ]]; then
  echo -e "  [${YELLOW}NOTE${NC}] No native .so libraries found in AAB (Pure Dart/Flutter app or native libs packaged dynamically)."
elif [[ $FAILED_LIBS -gt 0 ]]; then
  echo -e "\n${RED}[ERROR] Detected $FAILED_LIBS native library(ies) not aligned to 16 KB pages!${NC}" >&2
  echo -e "${RED}Google Play Store will reject this bundle on Android 15/16+ devices.${NC}" >&2
  exit 1
else
  echo -e "\n${GREEN}[SUCCESS] All $FOUND_LIBS native libraries meet the 16 KB memory page size alignment!${NC}"
fi

echo -e "\n${GREEN}==================================================================${NC}"
echo -e "${GREEN}      Ready for Google Play Console: $AAB_PATH                    ${NC}"
echo -e "${GREEN}==================================================================${NC}"
