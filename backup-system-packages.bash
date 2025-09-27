#!/usr/bin/env bash

# script for a complete backup of system software packages and configurations for quick installation on a new system, even in an offline environment

# ------------------------
# bash check
# ------------------------
if [ -z "$BASH_VERSION" ]; then
    echo "\033[1;31m[ERR]\033[0m This script must be run with bash, not sh or dash."
    exit 1
fi

# paths to backup
declare -A BACKUP_PATHS=(
    ["/etc"]="etc"
    ["/opt"]="opt"
    ["/var/www"]="www"
    ["/services"]="services"
    ["/var/lib/mysql"]="mysql"
    ["/usr/share/applications"]="usr/share/applications"
)

# files/folders to exclude from /home and /root
EXCLUDES=(
    "Downloads" "data" ".cache" ".bash_history" ".apport-ignore.xml" ".xsession-errors"
    ".gtkrc-2.0" ".wget-hsts" ".dbclient" ".xinputrc" ".minikube" ".minecraft"
    ".jdks" ".kube" ".npm" ".pki" ".rnd" ".ssr" ".m2" ".nvm" ".thunderbird"
    ".pam_environment" ".python_history" ".audacity-data" ".Xauthority"
    ".dotnet" ".spotdl" ".gradle" ".siege" ".rpmdb" ".cargo" ".java"
    ".anydesk" ".android" ".mozilla" ".openjfx" ".lesshst" ".docker"
    ".config/google-chrome" ".config/discord" ".config/Code"
)
RSYNC_EXCLUDES=""
for pattern in "${EXCLUDES[@]}"; do
    RSYNC_EXCLUDES+="--exclude=$pattern "
done

# bash color codes
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BLUE="\033[1;34m"
NC="\033[0m" # reset

# output helper
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }

# ------------------------
# root check
# ------------------------
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root."
    exit 1
fi
ok "Running as root."

# debian based check
if ! command -v apt >/dev/null 2>&1; then
    err "This system does not appear to be Debian-based (apt not found)."
    exit 1
fi
ok "Debian-based system detected."

# rsync check
if ! command -v rsync >/dev/null 2>&1; then
    err "rsync not found. Please install it with: apt install rsync"
    exit 1
fi

# ------------------------
# create backup directory
# ------------------------
BACKUP_DIR="$(pwd)/system-backup"

# remove old backup directory if it exists
if [ -d "$BACKUP_DIR" ]; then
    warn "Backup directory $BACKUP_DIR already exists. Removing it..."
    rm -rf "$BACKUP_DIR"
    ok "Old backup directory removed."
fi

mkdir -p "$BACKUP_DIR/deb-packages"
mkdir -p "$BACKUP_DIR/data"
mkdir -p "$BACKUP_DIR/data/userdata"
info "Backup directory created at $BACKUP_DIR"

# ------------------------
# backup package list & deb files
# ------------------------
info "Backing up package list and .deb files..."
dpkg --get-selections > "$BACKUP_DIR/deb-packages/package-list.txt"
apt-mark showmanual > "$BACKUP_DIR/deb-packages/manual-packages.txt"

mkdir -p "$BACKUP_DIR/deb-packages/files"

info "Downloading deb files (skipping packages that cannot be downloaded)..."
for pkg in $(dpkg --get-selections | grep -v deinstall | awk '{print $1}'); do
    # use pushd to temporarily switch directory
    pushd "$BACKUP_DIR/deb-packages/files" >/dev/null
    apt-get download "$pkg" 2>/dev/null || warn "Package $pkg could not be downloaded, skipping..."
    popd >/dev/null
done
ok "Packages list and available debs saved."

# ------------------------
# backup standard paths from BACKUP_PATHS array
# ------------------------
for SRC in "${!BACKUP_PATHS[@]}"; do
    DEST="${BACKUP_PATHS[$SRC]}"
    if [ -d "$SRC" ]; then
        info "Backing up $SRC..."
        mkdir -p "$BACKUP_DIR/data/$DEST"
        rsync -a "$SRC/" "$BACKUP_DIR/data/$DEST/"
        ok "$SRC backed up to data/$DEST"
    else
        warn "Source path $SRC does not exist. Skipping..."
    fi
done

# ------------------------
# backup /root as userdata
# ------------------------
if [ -d /root ]; then
    info "Backing up /root (excluding cache/history files)..."
    mkdir -p "$BACKUP_DIR/data/userdata/root"
    rsync -a $RSYNC_EXCLUDES /root/ "$BACKUP_DIR/data/userdata/root/"
    ok "/root backed up as userdata"
fi

# ------------------------
# backup /home user data
# ------------------------
for userdir in /home/*; do
    if [ -d "$userdir" ]; then
        username=$(basename "$userdir")
        info "Backing up home for user: $username (excluding VirtualBox VMs and cache/history files)..."
        mkdir -p "$BACKUP_DIR/data/userdata/$username"
        rsync -a --exclude='VirtualBox VMs' $RSYNC_EXCLUDES "$userdir/" "$BACKUP_DIR/data/userdata/$username/"
        ok "Backed up home for user: $username"
    fi
done

# ------------------------
# create README with system info
# ------------------------
info "Creating README file with backup info..."
{
    echo "====================================="
    echo "System Backup Report"
    echo "====================================="
    echo "Date:       $(date)"
    echo "Hostname:   $(hostname)"
    echo "Distro:     $(lsb_release -d 2>/dev/null | cut -f2- || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
    echo "Kernel:     $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Username:   $(logname 2>/dev/null || echo 'root')"
    echo
    echo "Backup directory: $BACKUP_DIR"
    echo "Total packages installed: $(dpkg -l | grep '^ii' | wc -l)"
    echo "Manual packages count: $(wc -l < "$BACKUP_DIR/deb-packages/manual-packages.txt")"
    echo
    echo "Extra files:"
    echo " - deb-packages/package-list.txt"
    echo " - deb-packages/manual-packages.txt"
    echo
    echo "====================================="
    echo "End of Report"
    echo "====================================="
} > "$BACKUP_DIR/README.MD"

ok "README file created at $BACKUP_DIR/README.MD"

# ------------------------
# verification of backup
# ------------------------
info "Verifying backup..."

# check main dirs
dirs_to_check=(
    "$BACKUP_DIR/deb-packages"
    "$BACKUP_DIR/data"
    "$BACKUP_DIR/data/userdata"
)

all_ok=true
for d in "${dirs_to_check[@]}"; do
    if [ ! -d "$d" ] || [ -z "$(ls -A "$d")" ]; then
        warn "Directory $d is missing or empty!"
        all_ok=false
    else
        ok "Directory $d exists and is not empty."
    fi
done

# check if at least some deb files exist
deb_count=$(find "$BACKUP_DIR/deb-packages/files" -type f -name "*.deb" | wc -l)
if [ "$deb_count" -eq 0 ]; then
    warn "No .deb files were downloaded!"
    all_ok=false
else
    ok "$deb_count .deb files downloaded."
fi

# final status
if [ "$all_ok" = true ]; then
    ok "Backup verification passed. Everything looks good!"
    echo -e "Your backup is located at: ${YELLOW}$BACKUP_DIR${NC}"
else
    warn "Backup verification found some issues. Check the warnings above."
fi
