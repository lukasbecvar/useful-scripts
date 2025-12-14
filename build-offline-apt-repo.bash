#!/usr/bin/env bash
set -euo pipefail

# ============================================
# COLOR DEFINITIONS
# ============================================
RED="\e[31m"
CYAN="\e[36m"
GREEN="\e[32m"
YELLOW="\e[33m"
MAGENTA="\e[35m"
RESET="\e[0m"

# ============================================
# CONFIG
# ============================================
PACKAGE_LIST="./packages-lists/0-ultimate-packages-list.txt"
ARCHES=("i386" "amd64" "arm64" "armhf")
REPO_ROOT="offline-repo"
DIST="stable"
SECTION="main"
POOL_DIR="$REPO_ROOT/pool/$SECTION"

# ============================================
# HELPER FUNCTIONS
# ============================================
get_deb_filename() {
    local pkg="$1"
    local arch="$2"
    apt-cache show "${pkg}:${arch}" 2>/dev/null \
        | awk '/^Filename:/ {print $2; exit}' \
        | sed 's#.*/##'
}

# ============================================
# ENV CHECK
# ============================================
echo -e "${CYAN}=== OFFLINE APT REPOSITORY BUILDER ===${RESET}"

for cmd in apt-get apt-cache dpkg-scanpackages; do
    if ! command -v "$cmd" >/dev/null; then
        echo -e "${RED}[ERR] Missing required command: $cmd${RESET}"
        exit 1
    fi
done

if [[ ! -f "$PACKAGE_LIST" ]]; then
    echo -e "${RED}[ERR] Package list '$PACKAGE_LIST' not found${RESET}"
    exit 1
fi

PKG_TOTAL=$(grep -vc '^\s*$\|^\s*#' "$PACKAGE_LIST")
echo -e "${GREEN}[+] Loaded $PKG_TOTAL packages${RESET}"

# ============================================
# PREPARE STRUCTURE
# ============================================
echo -e "${CYAN}[1/6] Preparing repository structure...${RESET}"

mkdir -p "$POOL_DIR"

for ARCH in "${ARCHES[@]}"; do
    mkdir -p "$REPO_ROOT/dists/$DIST/$SECTION/binary-$ARCH"
done

# ============================================
# DOWNLOAD PACKAGES
# ============================================
echo -e "${CYAN}[2/6] Downloading packages...${RESET}"

COUNTER=0

while read -r PKG; do
    [[ -z "$PKG" || "$PKG" =~ ^# ]] && continue
    COUNTER=$((COUNTER + 1))

    echo -e "\n${MAGENTA}==> [$COUNTER/$PKG_TOTAL] $PKG${RESET}"

    for ARCH in "${ARCHES[@]}"; do
        echo -e "${YELLOW}    → $ARCH${RESET}"

        DEB_NAME=$(get_deb_filename "$PKG" "$ARCH" || true)

        if [[ -z "$DEB_NAME" ]]; then
            echo -e "${RED}       No candidate${RESET}"
            continue
        fi

        if [[ -f "$POOL_DIR/$DEB_NAME" ]]; then
            echo -e "${GREEN}       Cached${RESET}"
            continue
        fi

        echo -e "${CYAN}       Downloading $DEB_NAME${RESET}"
        if apt-get download "${PKG}:${ARCH}" >/dev/null 2>&1; then
            mv ./*.deb "$POOL_DIR/" 2>/dev/null || true
        else
            echo -e "${RED}       Download failed${RESET}"
        fi
    done
done < "$PACKAGE_LIST"

echo -e "\n${GREEN}[✓] Download complete${RESET}"

# ============================================
# BUILD PACKAGES INDEX
# ============================================
echo -e "${CYAN}[3/6] Building Packages indexes...${RESET}"

for ARCH in "${ARCHES[@]}"; do
    echo -e "${YELLOW}    → binary-$ARCH${RESET}"
    (
        cd "$REPO_ROOT"
        dpkg-scanpackages -a "$ARCH" "pool/$SECTION" \
            > "dists/$DIST/$SECTION/binary-$ARCH/Packages"
    )
    gzip -kf "$REPO_ROOT/dists/$DIST/$SECTION/binary-$ARCH/Packages"
done

# ============================================
# BUILD RELEASE / INRELEASE
# ============================================
echo -e "${CYAN}[4/6] Generating Release metadata...${RESET}"

pushd "$REPO_ROOT" >/dev/null
REL="dists/$DIST/Release"

cat > "$REL" <<EOF
Origin: Offline Repo
Label: Offline Repo
Suite: $DIST
Codename: $DIST
Version: 1.0
Date: $(date -Ru)
Architectures: ${ARCHES[*]}
Components: $SECTION
Description: Lukáš Offline APT Repository
EOF

echo "MD5Sum:" >> "$REL"
for f in dists/$DIST/$SECTION/binary-*/Packages; do
    HASH=$(md5sum "$f" | cut -d' ' -f1)
    SIZE=$(stat -c%s "$f")
    echo " $HASH $SIZE ${f#dists/$DIST/}" >> "$REL"
done

echo "SHA256:" >> "$REL"
for f in dists/$DIST/$SECTION/binary-*/Packages; do
    HASH=$(sha256sum "$f" | cut -d' ' -f1)
    SIZE=$(stat -c%s "$f")
    echo " $HASH $SIZE ${f#dists/$DIST/}" >> "$REL"
done

cp "$REL" "dists/$DIST/InRelease"
popd >/dev/null

# ============================================
# PERMISSIONS
# ============================================
echo -e "${CYAN}[5/6] Fixing permissions...${RESET}"
chmod -R a+rX "$REPO_ROOT"

# ============================================
# VALIDATION
# ============================================
echo -e "${CYAN}[6/6] Validating repository...${RESET}"
VALID_FAIL=0

if grep -R "^Filename: .*offline-repo" "$REPO_ROOT/dists"; then
    echo -e "${RED}[ERR] Invalid Filename paths detected${RESET}"
    VALID_FAIL=1
else
    echo -e "${GREEN}[OK] Filename paths valid${RESET}"
fi

for ARCH in "${ARCHES[@]}"; do
    PKG_FILE="$REPO_ROOT/dists/$DIST/$SECTION/binary-$ARCH/Packages"
    [[ -s "$PKG_FILE" ]] || {
        echo -e "${YELLOW}[WARN] No packages for $ARCH${RESET}"
        continue
    }
done

if [[ "$VALID_FAIL" -eq 0 ]]; then
    echo -e "${GREEN}
===============================================
[✓] REPOSITORY READY – APT WILL WORK
===============================================
${RESET}"
else
    echo -e "${RED}
===============================================
[✗] REPOSITORY BROKEN
===============================================
${RESET}"
    exit 1
fi

# ============================================
# FINAL INFO
# ============================================
echo -e "${CYAN}Add this to offline machine:${RESET}"
echo -e "${YELLOW}deb [trusted=yes] file:/ABSOLUTE-PATH/$REPO_ROOT $DIST $SECTION${RESET}"
echo -e "${CYAN}Then run:${RESET}"
echo -e "${YELLOW}apt update && apt install <package>${RESET}"
