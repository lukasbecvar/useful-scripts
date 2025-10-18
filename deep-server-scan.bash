#!/usr/bin/env bash
# USAGE: sudo bash deep-server-scan.bash [--yes] [--udp] <target>

set -o errexit
set -o nounset
set -o pipefail

# -----------------------
# configuration / defaults
# -----------------------
OUTDIR="./scans"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
AUTO_YES="${AUTO_YES:-0}"
RUN_UDP="${RUN_UDP:-0}"
SKIP_PERMISSION="${SKIP_PERMISSION:-0}"

# -----------------------
# colors for terminal
# -----------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

section() { printf "\n${BOLD}${YELLOW}== %s ==${RESET}\n" "$1"; }
status_ok() { printf "${GREEN}✔ %s${RESET}\n" "$1"; }
status_warn() { printf "${YELLOW}⚠ %s${RESET}\n" "$1"; }
status_err() { printf "${RED}✖ %s${RESET}\n" "$1"; }
info() { printf "${CYAN}→ %s${RESET}\n" "$1"; }

# -----------------------
# argument parsing
# -----------------------
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y)
            AUTO_YES=1
            shift
            ;;
        --udp)
            RUN_UDP=1
            shift
            ;;
        --skip-permission)
            SKIP_PERMISSION=1
            shift
            ;;
        --help|-h)
            cat <<'USAGE'
Usage: sudo ./deep-server-scan.sh [--yes] [--udp] <target>

Options:
  --yes, -y           non-interactive: assume "yes" for prompts (install optional tools, etc.)
  --udp               also run an UDP top-port scan (slow)
  --skip-permission   skip interactive permission token prompt (DANGEROUS; internal usage)
  --help, -h          show this help
USAGE
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# ensure at least one positional arg (target)
if [[ ${#ARGS[@]} -lt 1 ]]; then
    echo "Usage: $0 [--yes] [--udp] <target>"
    exit 1
fi

TARGET_RAW="${ARGS[0]}"

# -----------------------
# utilities
# -----------------------
detect_pkgmgr() {
    if command -v apt-get >/dev/null 2>&1; then echo "apt"; return; fi
    if command -v dnf >/dev/null 2>&1; then echo "dnf"; return; fi
    if command -v yum >/dev/null 2>&1; then echo "yum"; return; fi
    if command -v pacman >/dev/null 2>&1; then echo "pacman"; return; fi
    if command -v zypper >/dev/null 2>&1; then echo "zypper"; return; fi
    echo ""
}

is_installed() {
    local tool="$1"
    if command -v "${tool}" >/dev/null 2>&1; then
        return 0
    fi

    local candidates=("$HOME/.local/bin/${tool}" "/usr/local/bin/${tool}" "/usr/bin/${tool}" "/bin/${tool}")
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        candidates+=("/home/${SUDO_USER}/.local/bin/${tool}" "/home/${SUDO_USER}/go/bin/${tool}" "/home/${SUDO_USER}/.cargo/bin/${tool}")
    fi

    if command -v go >/dev/null 2>&1; then
        local gopath
        gopath="$(go env GOPATH 2>/dev/null || true)"
        [[ -n "${gopath:-}" ]] && candidates+=("${gopath}/bin/${tool}")
    fi

    for p in "${candidates[@]}"; do
        [[ -x "${p}" ]] && return 0
    done
    return 1
}

# -----------------------
# sanitize target and prepare log filenames
# -----------------------
# remove scheme and path, keep host or IP only
normalize_target() {
    # remove scheme
    local t="${TARGET_RAW#http://}"
    t="${t#https://}"
    # strip everything after first slash
    t="${t%%/*}"
    # remove trailing colon/port in filename but keep in TARGET if needed
    if [[ -z "${t}" ]]; then
        echo "ERROR: Empty target after normalization" >&2
        exit 1
    fi
    # safe string for filenames
    SAFE_TARGET="$(printf '%s' "${t}" | sed 's/[^A-Za-z0-9._-]/-/g')"
    mkdir -p "${OUTDIR}/${SAFE_TARGET}-${TIMESTAMP}"
    LOGFILE="${OUTDIR}/${SAFE_TARGET}-${TIMESTAMP}/${SAFE_TARGET}.log"
    NMAP_BASE="${OUTDIR}/${SAFE_TARGET}-${TIMESTAMP}/${SAFE_TARGET}"
}

# -----------------------
# permission check (interactive)
# -----------------------
require_permissions() {
    if [[ "${SKIP_PERMISSION}" == "1" || "${AUTO_YES}" == "1" ]]; then
        info "Permission prompt skipped (SKIP_PERMISSION or AUTO_YES set)."
        return 0
    fi

    echo -e "${BOLD}>>> IMPORTANT: You must have explicit permission to scan the target.${RESET}"
    echo -e "${BOLD}>>> Type I_HAVE_PERMISSION to continue:${RESET}"
    read -r token
    if [[ "$token" != "I_HAVE_PERMISSION" ]]; then
        echo "Permission token not provided. Exiting."
        exit 1
    fi
}

# -----------------------
# ensure script runs under bash and with root privileges
# -----------------------
ensure_bash_and_root() {
    if [ -z "${BASH_VERSION:-}" ]; then
        printf "INFO: Re-execing under bash for full compatibility...\n" >&2
        exec bash "$0" "$@"
    fi

    if [[ "${EUID:-0}" -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            printf "INFO: Not running as root. Re-execing with sudo...\n" >&2
            exec sudo bash "$0" "$@"
        else
            printf "ERROR: Script requires root privileges or sudo. Exiting.\n" >&2
            exit 1
        fi
    fi
}

# -----------------------
# spinner wrapper that logs output
# -----------------------
run_with_spinner() {
    if [[ "$#" -lt 1 ]]; then
        echo "Usage: run_with_spinner <cmd> [args...]" >&2
        return 2
    fi

    # start command in background, redirect stdout/stderr to logfile
    "${@}" >> "${LOGFILE}" 2>&1 &
    local cmd_pid=$!

    local spinchars=( '|' '/' '-' '\' )
    local delay=0.08
    local i=0

    # show spinner on stderr only
    while kill -0 "${cmd_pid}" 2>/dev/null; do
        local idx=$(( i % ${#spinchars[@]} ))
        local c="${spinchars[$idx]}"
        printf "\r${YELLOW}[%s]${RESET} working... " "${c}" >&2
        sleep "${delay}"
        ((i++))
    done

    # wait returns exit code, but do not exit the whole script on non-zero
    wait "${cmd_pid}" || true
    printf "\r\033[K" >&2
}

# -----------------------
# tool checks & optional installs
# -----------------------
ensure_tools() {
    local required=(nmap curl traceroute)
    local missing=()
    for t in "${required[@]}"; do
        if ! is_installed "${t}"; then
            missing+=("${t}")
        fi
    done

    if ((${#missing[@]} > 0)); then
        status_err "Missing required tools: ${missing[*]}"
        echo "Install on Debian/Ubuntu (example):"
        echo "  apt update && apt install -y ${missing[*]}"
        exit 2
    fi

    status_ok "Required tools OK"
}

install_optional_tools() {
    local optional=(whatweb nikto gobuster whois nc)
    local missing=()
    for t in "${optional[@]}"; do
        if ! is_installed "${t}"; then
            missing+=("${t}")
        fi
    done

    if ((${#missing[@]} == 0)); then
        status_ok "Optional tools already present"
        return 0
    fi

    echo "Missing optional tools: ${missing[*]}"
    if [[ "${AUTO_YES}" == "1" ]]; then
        ans="Y"
    else
        read -rp "Do you want to attempt automatic install now? [Y/n]: " ans
        ans="${ans:-Y}"
    fi

    if [[ ! "${ans^^}" =~ ^(Y|YES)$ ]]; then
        echo "Skipping automatic install of optional tools."
        return 0
    fi

    local pkgmgr
    pkgmgr="$(detect_pkgmgr)"
    if [[ -z "${pkgmgr}" ]]; then
        status_warn "No supported package manager found. Install: ${missing[*]}"
        return 1
    fi

    info "Detected package manager: ${pkgmgr}. Attempting best-effort installs..."
    for t in "${missing[@]}"; do
        case "${t}" in
            whatweb|nikto|whois|nc)
                if [[ "${pkgmgr}" == "apt" ]]; then
                    apt-get update -y || true
                    apt-get install -y "${t}" || echo "apt failed for ${t}"
                elif [[ "${pkgmgr}" == "dnf" || "${pkgmgr}" == "yum" ]]; then
                    ${pkgmgr} install -y "${t}" || echo "${pkgmgr} failed for ${t}"
                elif [[ "${pkgmgr}" == "pacman" ]]; then
                    pacman -Sy --noconfirm "${t}" || echo "pacman failed for ${t}"
                else
                    echo "Package manager ${pkgmgr} not handled for ${t}"
                fi
            ;;
            gobuster)
                if [[ "${pkgmgr}" == "apt" ]]; then
                    apt-get update -y || true
                    if apt-get install -y gobuster 2>/dev/null; then
                        info "gobuster installed via apt"
                    else
                        if command -v go >/dev/null 2>&1; then
                            info "Installing gobuster via go"
                            if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
                                sudo -u "${SUDO_USER}" bash -lc 'export GOPATH="$(go env GOPATH 2>/dev/null || echo $HOME/go)"; go install github.com/OJ/gobuster/v3@latest' || echo "go install failed for gobuster"
                            else
                                export GOPATH="$(go env GOPATH 2>/dev/null || echo $HOME/go)"
                                go install github.com/OJ/gobuster/v3@latest || echo "go install failed for gobuster"
                            fi
                        else
                            echo "go not found; cannot install gobuster automatically."
                        fi
                    fi
                else
                    if command -v go >/dev/null 2>&1; then
                        info "Installing gobuster via go"
                        if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
                            sudo -u "${SUDO_USER}" bash -lc 'export GOPATH="$(go env GOPATH 2>/dev/null || echo $HOME/go)"; go install github.com/OJ/gobuster/v3@latest' || echo "go install failed for gobuster"
                        else
                            export GOPATH="$(go env GOPATH 2>/dev/null || echo $HOME/go)"
                            go install github.com/OJ/gobuster/v3@latest || echo "go install failed for gobuster"
                        fi
                    else
                        echo "gobuster not available via ${pkgmgr} and go not installed; please install manually."
                    fi
                fi
            ;;
            *)
                echo "No automatic installer for ${t}; install manually."
            ;;
        esac
    done

    # brief re-check
    sleep 1
    local still_missing=()
    for t in "${missing[@]}"; do
        if ! is_installed "${t}"; then
            still_missing+=("${t}")
        fi
    done

    if ((${#still_missing[@]} > 0)); then
        status_warn "Still missing after attempts: ${still_missing[*]}"
    else
        status_ok "Optional tools installed / found"
    fi
}

# -----------------------
# signal handling and cleanup
# -----------------------

# normal cleanup (called only on EXIT)
cleanup() {
    info "Cleaning up background jobs and finalizing logs..."
    jobs -p | xargs -r kill 2>/dev/null || true
    echo "Partial logs are in: ${LOGFILE}"
}

# handle Ctrl+C or termination signal
handle_interrupt() {
    echo -e "\n${RED}✖ Interrupted by user (Ctrl+C).${RESET}"
    # kill all background jobs (spinner, nmap, nc, etc.)
    jobs -p | xargs -r kill 2>/dev/null || true
    # write to logfile too
    echo "[!] Scan interrupted at $(date '+%Y-%m-%d %H:%M:%S')" >> "${LOGFILE}" 2>&1
    echo "Partial logs are in: ${LOGFILE}"
    exit 130  # standard exit code for SIGINT
}

# set traps
trap cleanup EXIT
trap handle_interrupt INT TERM

# -----------------------
# scanning functions
# -----------------------
basic_checks() {
    section "BASIC CHECKS"
    info "pinging target (4 ICMP packets)..."
    run_with_spinner ping -c 4 "${TARGET_RAW}" || true
    status_ok "Ping done (results in logfile)"

    info "DNS resolve..."
    if command -v dig >/dev/null 2>&1; then
        run_with_spinner dig +short "${TARGET_RAW}" || true
        status_ok "DNS resolved (dig)"
    else
        run_with_spinner host "${TARGET_RAW}" || true
        status_ok "DNS resolved (host)"
    fi
}

nmap_deep_scan() {
    section "NMAP DEEP TCP SCAN"
    info "running full TCP scan (nmap -p- -sS -sV -O -T4)"
    # produce grepable output and XML for structured parsing
    run_with_spinner nmap -p- -sS -sV -O -T4 --reason -oG "${NMAP_BASE}.gnmap" -oX "${NMAP_BASE}.xml" "${TARGET_RAW}" || true
    status_ok "Nmap full TCP scan complete"

    info "running top-10000 ports scan"
    run_with_spinner nmap -sS -sV -T4 --top-ports 10000 -oG "${NMAP_BASE}.top1000.gnmap" "${TARGET_RAW}" || true
    status_ok "Nmap top-10000 scan complete"
}

nmap_udp_scan() {
    if [[ "${RUN_UDP}" == "1" ]]; then
        section "NMAP UDP SCAN"
        info "running UDP top-200 (slow, lots of false positives possible)"
        run_with_spinner nmap -sU --top-ports 200 -T3 -oG "${NMAP_BASE}.udp.gnmap" "${TARGET_RAW}" || true
        status_ok "Nmap UDP scan complete"
    else
        info "UDP scan skipped (enable with --udp)"
    fi
}

web_checks() {
    section "WEB CHECKS"
    info "fetching HTTP/HTTPS headers with curl"
    run_with_spinner curl -sS -I --max-time 15 "http://${TARGET_RAW}" || true
    run_with_spinner curl -sS -I --max-time 15 "https://${TARGET_RAW}" || true
    status_ok "curl headers captured"

    if is_installed whatweb; then
        info "running whatweb (passive fingerprint)"
        run_with_spinner whatweb -v -a 3 "http://${TARGET_RAW}" || true
        run_with_spinner whatweb -v -a 3 "https://${TARGET_RAW}" || true
        status_ok "whatweb results saved"
    fi

    if is_installed nikto; then
        info "running nikto (vulnerabilities scan)"
        run_with_spinner nikto -host "http://${TARGET_RAW}" || true
        run_with_spinner nikto -host "https://${TARGET_RAW}" || true
        status_ok "nikto results saved"
    fi
}

traceroute_and_rdns() {
    section "NETWORK PATH"
    info "traceroute (numeric mode)"
    run_with_spinner traceroute -n "${TARGET_RAW}" || true
    status_ok "traceroute done"

    info "reverse DNS lookup"
    if command -v dig >/dev/null 2>&1; then
        run_with_spinner dig -x "${TARGET_RAW}" +short || true
        status_ok "reverse DNS done"
    else
        run_with_spinner host "${TARGET_RAW}" || true
        status_ok "reverse DNS done"
    fi
}

aux_checks() {
    section "AUX CHECKS"
    info "banner grab attempts on common ports using netcat (faster and cleaner)"
    local ports=(22 25 80 443 3306 5432)
    for p in "${ports[@]}"; do
        # use timeout and netcat; store result in logfile
        if command -v nc >/dev/null 2>&1; then
            ( printf "=== BANNER port %s ===\n" "${p}"; timeout 3 bash -c "echo | nc -w 2 ${TARGET_RAW} ${p}" ) >> "${LOGFILE}" 2>&1 || true
        else
            # fallback: simple TCP connect (may not return banner)
            timeout 3 bash -c "echo > /dev/tcp/${TARGET_RAW}/${p}" >> "${LOGFILE}" 2>&1 || true
        fi
    done
    status_ok "banner grab attempts logged"

    info "whois / network owner info"
    if is_installed whois; then
        {
            echo "=== WHOIS (raw) for ${TARGET_RAW} ==="
            whois "${TARGET_RAW}" || true
            echo "=== END WHOIS ==="
        } >> "${LOGFILE}" 2>&1
        status_ok "whois captured"
    elif command -v curl >/dev/null 2>&1; then
        {
            echo "=== NETWORK INFO (ipinfo.io) for ${TARGET_RAW} ==="
            curl -s --max-time 10 "https://ipinfo.io/${TARGET_RAW}/json" || true
            echo "=== END NETWORK INFO ==="
        } >> "${LOGFILE}" 2>&1
        status_warn "whois not installed — used ipinfo.io fallback"
    else
        status_warn "whois and curl both missing — cannot fetch network info"
    fi
}

# -----------------------
# final summary printed to stdout
# -----------------------
final_results() {
    section "FINAL RESULTS"
    echo "Scan target: ${TARGET_RAW}"
    echo "Scan time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    echo -e "${BOLD}Open TCP ports (parsed from grepable nmap output):${RESET}"
    if [[ -f "${NMAP_BASE}.gnmap" ]]; then
        # parse gnmap: lines like "Host: 1.2.3.4 ()  Ports: 22/open/tcp//ssh//..."
        awk -F'Ports: ' '{print $2}' "${NMAP_BASE}.gnmap" 2>/dev/null | sed 's/, /\n/g' | grep -E '^[0-9]+' | sed -n '1,200p' || echo "(none found)"
    else
        echo "(nmap grepable output missing)"
    fi

    echo
    echo -e "${BOLD}HTTP headers (sample):${RESET}"
    grep -E "^HTTP/|^Server:|^Content-Type:|^Date:|^ETag:|^Last-Modified:" "${LOGFILE}" | sed -n '1,40p' || echo "(none)"

    echo
    echo -e "${BOLD}Traceroute (first hops):${RESET}"
    grep -E "^[[:space:]]*[0-9]+[[:space:]]" "${LOGFILE}" | sed -n '1,12p' || echo "(none)"

    echo
    echo -e "${BOLD}Whois / network summary:${RESET}"

    if grep -q "WHOIS (raw)" "${LOGFILE}" 2>/dev/null; then
        # Extract key fields only (Org, NetName, Country, Address, Abuse contact)
        awk '
            /WHOIS \(raw\)/ {show=1; next}
            /END WHOIS/ {show=0}
            show && /^(org-name|OrgName|OrgAbuseEmail|netname|NetName|descr|address|country|Country)/ {
                # normalize field name to first column and trim spaces
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
                print " - " $0
            }
        ' "${LOGFILE}" | head -n 10

    elif grep -q "NETWORK INFO (ipinfo.io)" "${LOGFILE}" 2>/dev/null; then
        # Simplify ipinfo.io JSON output
        grep -A10 '"ip":' "${LOGFILE}" | awk -F'"' '
            /"ip":/ {print " - IP: " $4}
            /"hostname":/ {print " - Hostname: " $4}
            /"org":/ {print " - Org: " $4}
            /"country":/ {print " - Country: " $4}
            /"region":/ {print " - Region: " $4}
            /"city":/ {print " - City: " $4}
        ' | head -n 10
    else
        echo "(no whois or network info captured)"
    fi

    echo
    echo -e "${BOLD}${GREEN}FINAL: All raw output saved in:${RESET} ${LOGFILE}"
    echo "Extra nmap files (gnmap/xml): ${NMAP_BASE}.*"
}

# -----------------------
# main flow
# -----------------------
ensure_bash_and_root
normalize_target
require_permissions

# create logfile and header
info "Results log: ${LOGFILE}" 
: > "${LOGFILE}"
printf "=== scan started: %s target=%s ===\n\n" "$(date '+%Y-%m-%d %H:%M:%S')" "${TARGET_RAW}" >> "${LOGFILE}"

ensure_tools
install_optional_tools

# run scans
basic_checks
nmap_deep_scan
nmap_udp_scan
web_checks
traceroute_and_rdns
aux_checks

# print final results
final_results
