#!/bin/bash

# ============================================
# COLOR DEFINITIONS
# ============================================
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
CYAN="\e[36m"
MAGENTA="\e[35m"
RESET="\e[0m"

# ============================================
# CONFIG
# ============================================
PACKAGE_LIST="deb_packages.txt"
ARCHES=("i386" "amd64" "arm64" "armhf")
REPO_ROOT="offline-repo"
SECTION="main"
DIST="stable"

POOL_DIR="$REPO_ROOT/pool/$SECTION"

# ============================================
# HELPER FUNCTIONS
# ============================================

# get .deb file name for package+arch using apt-cache
get_deb_filename() {
    local pkg="$1"
    local arch="$2"
    # use apt-cache show to get Filename field and strip directory path
    apt-cache show "${pkg}:${arch}" 2>/dev/null \
      | awk '/^Filename:/ {print $2; exit}' \
      | sed 's#.*/##'
}

# ============================================
# CHECK ENVIRONMENT
# ============================================
echo -e "${CYAN}=== OFFLINE APT MIRROR BUILDER ===${RESET}"

if ! command -v dpkg-scanpackages >/dev/null; then
    echo -e "${RED}[ERR] dpkg-scanpackages (dpkg-dev) is missing. Install with: sudo apt install dpkg-dev${RESET}"
    exit 1
fi

if ! command -v apt-get >/dev/null; then
    echo -e "${RED}[ERR] apt-get not found.${RESET}"
    exit 1
fi

if ! command -v apt-cache >/dev/null; then
    echo -e "${RED}[ERR] apt-cache not found.${RESET}"
    exit 1
fi

if [[ ! -f "$PACKAGE_LIST" ]]; then
    echo -e "${RED}[ERR] Package list '$PACKAGE_LIST' not found in current directory.${RESET}"
    exit 1
fi

PKG_TOTAL=$(wc -l < "$PACKAGE_LIST")
echo -e "${GREEN}[+] Loaded $PKG_TOTAL packages from $PACKAGE_LIST${RESET}"

# ============================================
# PREPARE REPOSITORY TREE
# ============================================
echo -e "${CYAN}[1/6] Preparing repository structure...${RESET}"

mkdir -p "$POOL_DIR"
mkdir -p "$REPO_ROOT/dists/$DIST/$SECTION"

for ARCH in "${ARCHES[@]}"; do
    mkdir -p "$REPO_ROOT/dists/$DIST/$SECTION/binary-$ARCH"
done

# ============================================
# DOWNLOAD PHASE (INCREMENTAL)
# ============================================
echo -e "${CYAN}[2/6] Downloading missing packages...${RESET}"

COUNTER=0

while read PKG; do
    # skip empty lines
    [[ -z "$PKG" ]] && continue
    COUNTER=$((COUNTER + 1))

    echo -e "\n${MAGENTA}==> [$COUNTER/$PKG_TOTAL] Package: $PKG${RESET}"

    for ARCH in "${ARCHES[@]}"; do
        echo -e "${YELLOW}    → Checking $PKG ($ARCH)...${RESET}"

        # resolve .deb file name from apt-cache (no download)
        DEB_NAME=$(get_deb_filename "$PKG" "$ARCH")

        if [[ -z "$DEB_NAME" ]]; then
            echo -e "${RED}       No candidate .deb for $PKG:$ARCH (skipping)${RESET}"
            continue
        fi

        # if this version already exists in pool, skip download
        if [[ -f "$POOL_DIR/$DEB_NAME" ]]; then
            echo -e "${GREEN}       Already cached: $DEB_NAME (SKIP)${RESET}"
            continue
        fi

        echo -e "${CYAN}       Downloading new version: $DEB_NAME${RESET}"
        # perform download into current dir, then move .deb file(s) into pool
        if apt-get download "${PKG}:${ARCH}" 2>/dev/null; then
            mv ./*.deb "$POOL_DIR/" 2>/dev/null
        else
            echo -e "${RED}       Download failed for $PKG:$ARCH${RESET}"
        fi
    done

done < "$PACKAGE_LIST"

echo -e "\n${GREEN}[✓] Download phase complete${RESET}"

# ============================================
# REBUILD PACKAGES INDEXES
# ============================================
echo -e "${CYAN}[3/6] Rebuilding Packages / Packages.gz...${RESET}"

for ARCH in "${ARCHES[@]}"; do
    TARGET_DIR="$REPO_ROOT/dists/$DIST/$SECTION/binary-$ARCH"
    echo -e "${YELLOW}    → Building index for ARCH: $ARCH${RESET}"

    dpkg-scanpackages -a "$ARCH" "$POOL_DIR" > "$TARGET_DIR/Packages"
    gzip -9 < "$TARGET_DIR/Packages" > "$TARGET_DIR/Packages.gz"
done

# ============================================
# GENERATE Release + InRelease (unsigned)
# ============================================
echo -e "${CYAN}[4/6] Generating Release and InRelease...${RESET}"

# work inside REPO_ROOT so relative paths in Release make sense
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

# append hash sections
echo "MD5Sum:" >> "$REL"
for f in dists/$DIST/$SECTION/binary-*/Packages; do
    if [[ -f "$f" ]]; then
        HASH=$(md5sum "$f" | cut -d" " -f1)
        SIZE=$(stat -c%s "$f")
        echo " $HASH $SIZE $f" >> "$REL"
    fi
done

echo "SHA256:" >> "$REL"
for f in dists/$DIST/$SECTION/binary-*/Packages; do
    if [[ -f "$f" ]]; then
        HASH=$(sha256sum "$f" | cut -d" " -f1)
        SIZE=$(stat -c%s "$f")
        echo " $HASH $SIZE $f" >> "$REL"
    fi
done

# InRelease – unsigned, but enough for [trusted=yes]
cp "$REL" "dists/$DIST/InRelease"

popd >/dev/null

# ============================================
# PERMISSIONS (ONLY INSIDE offline-repo/)
# ============================================
echo -e "${CYAN}[5/6] Fixing permissions on $REPO_ROOT...${RESET}"

# make all files world-readable, dirs traversable
chmod -R a+rX "$REPO_ROOT"

echo -e "${GREEN}[OK] Permissions set on $REPO_ROOT (no parent dirs touched)${RESET}"

# ============================================
# VALIDATION BLOCK
# ============================================
echo -e "${CYAN}[6/6] Running repository self-check...${RESET}"

VALID_FAIL=0

# check release file
if [[ ! -f "$REPO_ROOT/dists/$DIST/Release" ]]; then
    echo -e "${RED}[ERR] Missing Release file${RESET}"
    VALID_FAIL=1
else
    echo -e "${GREEN}[OK] Release file exists${RESET}"
fi

# validate each architecture index
for ARCH in "${ARCHES[@]}"; do
    PKG_DIR="$REPO_ROOT/dists/$DIST/$SECTION/binary-$ARCH"
    echo -e "${CYAN}    → Checking $ARCH index...${RESET}"

    if [[ ! -s "$PKG_DIR/Packages" ]]; then
        echo -e "${YELLOW}       [WARN] Empty or missing Packages for $ARCH (no packages for this arch?)${RESET}"
        continue
    fi

    if ! grep -q "^Package:" "$PKG_DIR/Packages"; then
        echo -e "${RED}       [ERR] Packages index for $ARCH has no entries${RESET}"
        VALID_FAIL=1
    else
        echo -e "${GREEN}       [OK] Packages file looks valid${RESET}"
    fi

    if [[ ! -s "$PKG_DIR/Packages.gz" ]]; then
        echo -e "${RED}       [ERR] Missing or empty Packages.gz for $ARCH${RESET}"
        VALID_FAIL=1
    else
        if ! gzip -t "$PKG_DIR/Packages.gz" 2>/dev/null; then
            echo -e "${RED}       [ERR] Corrupted Packages.gz for $ARCH${RESET}"
            VALID_FAIL=1
        else
            echo -e "${GREEN}       [OK] Packages.gz integrity OK${RESET}"
        fi
    fi
done

# final validation result
if [[ "$VALID_FAIL" -eq 0 ]]; then
    echo -e "${GREEN}
===============================================
[✓] REPOSITORY VALIDATION PASSED
Repo is ready and should work with APT.
===============================================
${RESET}"
else
    echo -e "${RED}
===============================================
[✗] REPOSITORY VALIDATION FAILED
Some parts are broken or missing – check logs above.
===============================================
${RESET}"
fi

# ============================================
# FINAL INFO
# ============================================
echo -e "${CYAN}To use this offline repo, add to /etc/apt/sources.list.d/offline.list:${RESET}"
echo -e "${YELLOW}  deb [trusted=yes] file:/$(pwd)/$REPO_ROOT $DIST $SECTION${RESET}"
echo -e "${CYAN}Then run:${RESET}"
echo -e "${YELLOW}  sudo apt update${RESET}"
