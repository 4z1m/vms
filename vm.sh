#!/bin/bash
# =====================================================================
#   Invis Cloud — Multi-VM Manager
#   Powered by 4z1m
# =====================================================================
set -euo pipefail

# ---------------------------------------------------------------------
#  Colors
# ---------------------------------------------------------------------
readonly C_RESET=$'\033[0m'
readonly C_BOLD=$'\033[1m'
readonly C_DIM=$'\033[2m'
readonly C_RED=$'\033[1;31m'
readonly C_GRN=$'\033[1;32m'
readonly C_YEL=$'\033[1;33m'
readonly C_BLU=$'\033[1;34m'
readonly C_MAG=$'\033[1;35m'
readonly C_CYN=$'\033[1;36m'
readonly C_WHT=$'\033[1;37m'
readonly C_GREY=$'\033[0;90m'

readonly APP_NAME="Invis Cloud"
readonly APP_AUTHOR="4z1m"

# Animation toggle (set to false to disable all animations)
ANIMATIONS=true

# ---------------------------------------------------------------------
#  Paths
# ---------------------------------------------------------------------
VM_DIR="${VM_DIR:-$PWD/vms}"
BASE_DIR="$VM_DIR/base"
KEY_DIR="$VM_DIR/keys"
mkdir -p "$VM_DIR" "$BASE_DIR" "$KEY_DIR"
chmod 700 "$KEY_DIR" 2>/dev/null || true

TMP_RUN="$(mktemp -d)"
trap 'rm -rf "$TMP_RUN"' EXIT

# ---------------------------------------------------------------------
#  Animation primitives
# ---------------------------------------------------------------------

# Typewriter effect: typewriter "text" [delay_ms]
typewriter() {
    local text="$1" delay=${2:-20}
    if [[ "$ANIMATIONS" != true ]]; then echo "$text"; return; fi
    local i
    for ((i=0; i<${#text}; i++)); do
        printf '%s' "${text:$i:1}"
        sleep "0.0$(( (delay < 10) ? delay : 9 ))" 2>/dev/null || sleep 0.02
    done
    echo
}

# Spinner with configurable label
SPIN_PID=""
spin_start() {
    local msg="$1"
    SPIN_MSG="$msg"
    if [[ "$ANIMATIONS" != true ]]; then
        printf '%s ' "${C_BLU}◆${C_RESET} $msg"
        return
    fi
    (
        local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        while true; do
            for f in "${frames[@]}"; do
                printf '\r%s %s %s' "${C_CYN}${f}${C_RESET}" "${C_BLU}${SPIN_MSG}${C_RESET}" "${C_GREY}...${C_RESET}"
                sleep 0.08
            done
        done
    ) &
    SPIN_PID=$!
}
spin_stop() {
    local rc=${1:-0}
    if [[ -n "$SPIN_PID" ]]; then
        kill "$SPIN_PID" 2>/dev/null || true
        wait "$SPIN_PID" 2>/dev/null || true
        SPIN_PID=""
    fi
    if [[ "$ANIMATIONS" == true ]]; then
        if [[ $rc -eq 0 ]]; then
            printf '\r%s %s %s\n' "${C_GRN}✔${C_RESET}" "$SPIN_MSG" "${C_GREY}... done${C_RESET}"
        else
            printf '\r%s %s %s\n' "${C_RED}✖${C_RESET}" "$SPIN_MSG" "${C_GREY}... failed${C_RESET}"
        fi
    else
        printf '%s\n' "$([[ $rc -eq 0 ]] && echo 'done' || echo 'failed')"
    fi
}

# Animated progress bar: progress_bar "label" <percent>
progress_bar() {
    local label="$1" pct="$2"
    local width=30
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    if [[ "$ANIMATIONS" != true ]]; then
        printf '%s: %d%%\n' "$label" "$pct"
        return
    fi
    printf '\r%s %s' "${C_BLU}${label}${C_RESET}" \
        "$(printf '%s' "${C_GRN}$(printf '█%.0s' $(seq 1 $filled 2>/dev/null))${C_GREY}$(printf '░%.0s' $(seq 1 $empty 2>/dev/null))${C_RESET}")"
    printf ' %d%%' "$pct"
}

# Countdown timer
countdown() {
    local n="$1" label="${2:-starting}"
    if [[ "$ANIMATIONS" != true ]]; then return; fi
    local i
    for ((i=n; i>0; i--)); do
        printf '\r%s %s %s %ds   ' "${C_YEL}◷${C_RESET}" "$label" "${C_GREY}in${C_RESET}" "$i"
        sleep 1
    done
    printf '\r%s %s %s\n' "${C_GRN}✔${C_RESET}" "$label" "${C_GREY}now!${C_RESET}"
}

# Fade-in effect for lines
fade_in() {
    local text="$1"
    if [[ "$ANIMATIONS" != true ]]; then printf '%s\n' "$text"; return; fi
    local shades=("${C_GREY}" "${C_GREY}" "${C_DIM}" "${C_WHT}")
    for s in "${shades[@]}"; do
        printf '\r%s%s%s' "$s" "$text" "${C_RESET}"
        sleep 0.06
    done
    echo
}

# Matrix rain effect (short, at VM boot)
matrix_rain() {
    if [[ "$ANIMATIONS" != true ]]; then return; fi
    local w=60
    local chars=('0' '1' '#' '@' '%' '&' '$' '?' '!' '=' '+' '*' 'x')
    local lines=6
    local l
    for ((l=0; l<lines; l++)); do
        local line=""
        local c
        for ((c=0; c<w; c++)); do
            line+="${chars[$((RANDOM % ${#chars[@]}))]}"
        done
        printf '%s%s%s\n' "${C_GRN}${C_DIM}" "$line" "${C_RESET}"
        sleep 0.05
    done
}

# Blinking status
blink_text() {
    local text="$1" times="${2:-3}"
    if [[ "$ANIMATIONS" != true ]]; then printf '%s\n' "$text"; return; fi
    local i
    for ((i=0; i<times; i++)); do
        printf '\r%s%s%s' "${C_GRN}${C_BOLD}" "$text" "${C_RESET}"
        sleep 0.2
        printf '\r%s%s%s' "${C_DIM}" "$text" "${C_RESET}"
        sleep 0.2
    done
    printf '\r%s%s%s\n' "${C_GRN}${C_BOLD}" "$text" "${C_RESET}"
}

# ---------------------------------------------------------------------
#  UI helpers
# ---------------------------------------------------------------------
hr() {
    printf '%s\n' "${C_GREY}$(printf '─%.0s' $(seq 1 72))${C_RESET}"
}

print_status() {
    local type=$1; shift
    local msg="$*"
    case $type in
        INFO)    printf '%s\n' "${C_BLU}◆ INFO${C_RESET}    $msg" ;;
        WARN)    printf '%s\n' "${C_YEL}▲ WARN${C_RESET}    $msg" ;;
        ERROR)   printf '%s\n' "${C_RED}✖ ERROR${C_RESET}   $msg" ;;
        SUCCESS) printf '%s\n' "${C_GRN}✔ SUCCESS${C_RESET} $msg" ;;
        STEP)    printf '%s\n' "${C_MAG}▸${C_RESET} $msg" ;;
    esac
}

ask() {
    local var=$1 msg=$2 secret=${3:-}
    local val=""
    if [[ "$secret" == "secret" ]]; then
        printf '%s ' "${C_CYN}❯${C_RESET} $msg"
        IFS= read -rs val || true
        echo
    else
        printf '%s ' "${C_CYN}❯${C_RESET} $msg"
        IFS= read -r val || true
    fi
    printf -v "$var" '%s' "$val"
}

confirm() {
    local msg=$1 reply=""
    printf '%s ' "${C_YEL}?${C_RESET} $msg [y/N]:"
    IFS= read -rn1 reply || true; echo
    [[ "$reply" =~ ^[Yy]$ ]]
}

press_enter() {
    printf '%s' "${C_GREY}Press Enter to continue...${C_RESET}"
    IFS= read -r _ || true
}

# ---------------------------------------------------------------------
#  Banner (animated)
# ---------------------------------------------------------------------
banner() {
    local lines=(
"  ╔══════════════════════════════════════════════════════════╗"
"  ║                                                          ║"
"  ║            I N V I S   C L O U D   ·   V M               ║"
"  ║                                                          ║"
"  ╚══════════════════════════════════════════════════════════╝"
    )
    printf '\n'
    if [[ "$ANIMATIONS" == true ]]; then
        for line in "${lines[@]}"; do
            printf '%s\n' "${C_CYN}${C_BOLD}${line}${C_RESET}"
            sleep 0.06
        done
        printf '%s' "${C_GREY}                    powered by ${C_MAG}${C_BOLD}4z1m${C_RESET}"
        sleep 0.1
        printf '\n'
    else
        for line in "${lines[@]}"; do
            printf '%s\n' "${C_CYN}${C_BOLD}${line}${C_RESET}"
        done
        printf '%s\n' "${C_GREY}                    powered by ${C_MAG}${C_BOLD}4z1m${C_RESET}"
        printf '\n'
    fi
    printf '\n'
}

header() {
    clear
    banner
    hr
    printf '%s\n' "${C_GREY}  VM Directory: ${C_WHT}$VM_DIR${C_RESET}"
    if [[ -w /dev/kvm ]]; then
        printf '%s\n' "${C_GREY}  Host KVM:     ${C_GRN}● available${C_RESET}"
    else
        printf '%s\n' "${C_GREY}  Host KVM:     ${C_RED}○ unavailable${C_RESET}"
    fi
    printf '%s\n' "${C_GREY}  Date:         ${C_WHT}$(date '+%Y-%m-%d %H:%M:%S')${C_RESET}"
    printf '%s\n' "${C_GREY}  Animations:   $([[ "$ANIMATIONS" == true ]] && echo "${C_GRN}on${C_RESET}" || echo "${C_GREY}off${C_RESET}")"
    hr
    echo
}

# ---------------------------------------------------------------------
#  Validation
# ---------------------------------------------------------------------
validate_input() {
    local type=$1 value=$2
    case $type in
        number)   [[ "$value" =~ ^[0-9]+$ ]] || { print_status ERROR "Must be a number"; return 1; } ;;
        size)     [[ "$value" =~ ^[0-9]+[GgMm]$ ]] || { print_status ERROR "Use size with unit (e.g. 20G, 512M)"; return 1; } ;;
        port)
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 23 ] || [ "$value" -gt 65535 ]; then
                print_status ERROR "Port must be 23–65535"; return 1
            fi ;;
        name)     [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]] || { print_status ERROR "Only letters, numbers, - and _"; return 1; } ;;
        username) [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]] || { print_status ERROR "Invalid username format"; return 1; } ;;
    esac
    return 0
}

port_in_use() {
    ss -tlnH "sport = :$1" 2>/dev/null | grep -q .
}

# ---------------------------------------------------------------------
#  Dependencies
# ---------------------------------------------------------------------
check_dependencies() {
    local deps=(qemu-system-x86_64 qemu-img wget cloud-localds ssh-keygen openssl)
    local missing=()
    for d in "${deps[@]}"; do
        command -v "$d" >/dev/null 2>&1 || missing+=("$d")
    done
    if ((${#missing[@]})); then
        print_status ERROR "Missing dependencies: ${missing[*]}"
        print_status INFO  "Debian/Ubuntu: sudo apt install qemu-system-x86 qemu-utils cloud-image-utils wget openssh-client openssl"
        exit 1
    fi
}

# ---------------------------------------------------------------------
#  VM config I/O
# ---------------------------------------------------------------------
get_vm_list() {
    find "$VM_DIR" -maxdepth 1 -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

load_vm_config() {
    local vm=$1 file="$VM_DIR/$1.conf"
    if [[ ! -f "$file" ]]; then
        print_status ERROR "Config for '$vm' not found"
        return 1
    fi
    unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
    unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED SSH_KEY KVM
    # shellcheck disable=SC1090
    source "$file"
    : "${KVM:=true}"
    return 0
}

save_vm_config() {
    local file="$VM_DIR/$VM_NAME.conf"
    cat > "$file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
KVM="$KVM"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
SSH_KEY="$SSH_KEY"
CREATED="$CREATED"
EOF
    chmod 600 "$file"
    print_status SUCCESS "Config saved"
}

# ---------------------------------------------------------------------
#  SSH key management
# ---------------------------------------------------------------------
ensure_ssh_key() {
    local vm=$1 keyfile="$KEY_DIR/$1_ed25519"
    if [[ ! -f "$keyfile" ]]; then
        ssh-keygen -t ed25519 -N "" -f "$keyfile" -C "invis-cloud-$vm" >/dev/null 2>&1
        print_status INFO "SSH keypair created: $keyfile"
    fi
    SSH_KEY="$keyfile"
    PUB_KEY="$(cat "${keyfile}.pub")"
}

# ---------------------------------------------------------------------
#  Base image cache
# ---------------------------------------------------------------------
base_image_path() {
    local name; name="$(basename "$IMG_URL")"
    echo "$BASE_DIR/$1_$name"
}

ensure_base_image() {
    local base; base="$(base_image_path "$OS_TYPE")"
    if [[ ! -f "$base" ]]; then
        spin_start "Downloading base image for $OS_TYPE"
        if ! wget -q --show-progress -O "$base.tmp" "$IMG_URL" 2>/dev/null; then
            rm -f "$base.tmp"
            spin_stop 1
            print_status ERROR "Download failed"
            return 1
        fi
        mv "$base.tmp" "$base"
        spin_stop 0
        print_status SUCCESS "Base image cached: $(basename "$base")"
    else
        print_status INFO "Using cached base image: $(basename "$base")"
    fi
    BASE_IMG="$base"
}

# ---------------------------------------------------------------------
#  KVM prompt (shared by create + edit)
# ---------------------------------------------------------------------
ask_kvm_choice() {
    local current=${1:-true}
    echo
    print_status STEP "Acceleration mode"
    printf "  ${C_CYN}1${C_RESET}) KVM acceleration  ${C_GRN}(fast — requires /dev/kvm)${C_RESET}\n"
    printf "  ${C_CYN}2${C_RESET}) Software emulation ${C_YEL}(slow — works anywhere)${C_RESET}\n"
    echo
    local dnum=1
    [[ "$current" == "false" ]] && dnum=2
    while true; do
        local in
        ask in "Choose [1-2, default=$dnum]: "
        in="${in:-$dnum}"
        case $in in
            1)
                if [[ ! -w /dev/kvm ]]; then
                    print_status WARN "/dev/kvm not available on this host — KVM will fail at boot."
                    confirm "Still use KVM?" || continue
                fi
                KVM=true; break ;;
            2) KVM=false; break ;;
            *) print_status ERROR "Enter 1 or 2" ;;
        esac
    done
    if [[ "$KVM" == "true" ]]; then
        print_status SUCCESS "Mode: KVM acceleration"
    else
        print_status SUCCESS "Mode: Software emulation"
    fi
}

# ---------------------------------------------------------------------
#  Create VM
# ---------------------------------------------------------------------
create_new_vm() {
    header
    print_status STEP "Create a new VM"
    echo

    local os_list=("${!OS_OPTIONS[@]}")
    local i=1
    for os in "${os_list[@]}"; do
        printf "  ${C_CYN}%2d)${C_RESET} %s\n" "$i" "$os"
        sleep 0.02
        ((i++))
    done
    echo

    local choice
    while true; do
        ask choice "Select OS [1-${#os_list[@]}]: "
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#os_list[@]} ]; then
            local os="${os_list[$((choice-1))]}"
            IFS='|' read -r OS_TYPE CODENAME IMG_URL DEF_HOST DEF_USER DEF_PASS <<< "${OS_OPTIONS[$os]}"
            print_status SUCCESS "Selected: $os"
            break
        fi
        print_status ERROR "Invalid selection"
    done
    echo

    while true; do
        ask VM_NAME "VM name [$DEF_HOST]: "
        VM_NAME="${VM_NAME:-$DEF_HOST}"
        if validate_input name "$VM_NAME"; then
            [[ -f "$VM_DIR/$VM_NAME.conf" ]] && print_status ERROR "VM '$VM_NAME' already exists" || break
        fi
    done

    while true; do
        ask HOSTNAME "Hostname [$VM_NAME]: "
        HOSTNAME="${HOSTNAME:-$VM_NAME}"
        validate_input name "$HOSTNAME" && break
    done

    while true; do
        ask USERNAME "Username [$DEF_USER]: "
        USERNAME="${USERNAME:-$DEF_USER}"
        validate_input username "$USERNAME" && break
    done

    while true; do
        ask PASSWORD "Password [$DEF_PASS]: " secret
        PASSWORD="${PASSWORD:-$DEF_PASS}"
        [[ -n "$PASSWORD" ]] && break || print_status ERROR "Password cannot be empty"
    done

    while true; do
        ask DISK_SIZE "Disk size [20G]: "
        DISK_SIZE="${DISK_SIZE:-20G}"
        validate_input size "$DISK_SIZE" && break
    done

    while true; do
        ask MEMORY "RAM in MB [2048]: "
        MEMORY="${MEMORY:-2048}"
        validate_input number "$MEMORY" && break
    done

    while true; do
        ask CPUS "CPUs [2]: "
        CPUS="${CPUS:-2}"
        validate_input number "$CPUS" && break
    done

    while true; do
        ask SSH_PORT "SSH port [2222]: "
        SSH_PORT="${SSH_PORT:-2222}"
        if validate_input port "$SSH_PORT"; then
            port_in_use "$SSH_PORT" && print_status ERROR "Port $SSH_PORT already in use" || break
        fi
    done

    while true; do
        ask gui_input "GUI mode? [y/N]: "
        GUI_MODE=false; gui_input="${gui_input:-n}"
        if [[ "$gui_input" =~ ^[Yy]$ ]]; then GUI_MODE=true; break
        elif [[ "$gui_input" =~ ^[Nn]$ ]]; then break
        else print_status ERROR "Please answer y or n"; fi
    done

    ask_kvm_choice true

    ask PORT_FORWARDS "Additional port forwards (e.g. 8080:80) [none]: "

    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"

    echo
    ensure_ssh_key "$VM_NAME"
    ensure_base_image || return 1

    spin_start "Creating qcow2 overlay"
    qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMG" "$IMG_FILE" >/dev/null
    qemu-img resize "$IMG_FILE" "$DISK_SIZE" >/dev/null
    spin_stop 0
    print_status SUCCESS "Disk prepared ($DISK_SIZE)"

    spin_start "Building cloud-init seed"
    cat > "$TMP_RUN/user-data" <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: true
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $(openssl passwd -6 "$PASSWORD" | tr -d '\n')
    ssh_authorized_keys:
      - $PUB_KEY
ssh_authorized_keys:
  - $PUB_KEY
package_update: false
EOF
    cat > "$TMP_RUN/meta-data" <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF
    cloud-localds "$SEED_FILE" "$TMP_RUN/user-data" "$TMP_RUN/meta-data"
    spin_stop 0

    save_vm_config
    echo
    blink_text "✓ VM '$VM_NAME' created successfully!"
    print_status INFO "SSH: ssh -i $SSH_KEY -p $SSH_PORT $USERNAME@127.0.0.1"
    echo
    press_enter
}

# ---------------------------------------------------------------------
#  Start VM
# ---------------------------------------------------------------------
start_vm() {
    local vm=$1
    load_vm_config "$vm" || return 1

    header
    print_status STEP "Starting VM: $vm"
    echo
    printf "  ${C_GREY}%-12s${C_RESET} %s\n" "SSH:" "ssh -i $SSH_KEY -p $SSH_PORT $USERNAME@127.0.0.1"
    printf "  ${C_GREY}%-12s${C_RESET} %s\n" "Password:" "$PASSWORD"
    printf "  ${C_GREY}%-12s${C_RESET} %s MB / %s CPUs / %s disk\n" "Resources:" "$MEMORY" "$CPUS" "$DISK_SIZE"
    if [[ "$KVM" == "true" ]]; then
        printf "  ${C_GREY}%-12s${C_RESET} ${C_GRN}KVM acceleration${C_RESET}\n" "Mode:"
    else
        printf "  ${C_GREY}%-12s${C_RESET} ${C_YEL}Software emulation${C_RESET}\n" "Mode:"
    fi
    echo

    [[ ! -f "$IMG_FILE" ]] && { print_status ERROR "Image missing: $IMG_FILE"; press_enter; return 1; }
    if [[ ! -f "$SEED_FILE" ]]; then
        print_status ERROR "Seed image missing — cannot start"
        press_enter; return 1
    fi

    local accel=() cpu="qemu64"
    if [[ "$KVM" == "true" ]]; then
        if [[ -w /dev/kvm ]]; then
            accel=(-enable-kvm)
            cpu="host"
            print_status SUCCESS "Using KVM acceleration"
        else
            print_status ERROR "KVM requested but /dev/kvm unavailable — start aborted."
            print_status INFO  "Edit the VM and switch to software emulation to start it."
            press_enter; return 1
        fi
    else
        print_status INFO "Using software emulation (no KVM)"
    fi

    # Animated boot sequence
    echo
    matrix_rain
    echo
    local steps=(
        "Allocating memory: ${MEMORY} MB"
        "Provisioning vCPUs: ${CPUS}"
        "Attaching disk: $(basename "$IMG_FILE")"
        "Mounting cloud-init seed"
        "Configuring network (hostfwd 127.0.0.1:${SSH_PORT} → 22)"
    )
    for step in "${steps[@]}"; do
        spin_start "$step"
        sleep 0.3
        spin_stop 0
    done
    echo
    countdown 2 "Booting QEMU"

    local qemu=(
        qemu-system-x86_64
        "${accel[@]}"
        -m "$MEMORY" -smp "$CPUS" -cpu "$cpu"
        -drive "file=$IMG_FILE,format=qcow2,if=virtio,cache=writeback"
        -drive "file=$SEED_FILE,format=raw,if=virtio,readonly=on"
        -boot order=c
        -device virtio-net-pci,netdev=n0
        -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22"
        -device virtio-balloon-pci
        -object rng-random,filename=/dev/urandom,id=rng0
        -device virtio-rng-pci,rng=rng0
    )

    if [[ -n "${PORT_FORWARDS:-}" ]]; then
        IFS=',' read -ra fwds <<< "$PORT_FORWARDS"
        local idx=1
        for fwd in "${fwds[@]}"; do
            IFS=':' read -r hp gp <<< "$fwd"
            qemu+=(-device "virtio-net-pci,netdev=n$idx")
            qemu+=(-netdev "user,id=n$idx,hostfwd=tcp:127.0.0.1:$hp-:$gp")
            ((idx++))
        done
    fi

    if [[ "$GUI_MODE" == true ]]; then
        qemu+=(-vga virtio -display gtk,gl=on)
    else
        qemu+=(-nographic -serial mon:stdio)
    fi

    print_status INFO "QEMU launching... (Ctrl-A X to exit)"
    echo
    "${qemu[@]}" || true
    echo
    blink_text "▣ VM $vm shut down" 2
    press_enter
}

# ---------------------------------------------------------------------
#  Stop / Delete / Info
# ---------------------------------------------------------------------
is_vm_running() {
    pgrep -f "qemu-system-x86_64.*$1" >/dev/null
}

stop_vm() {
    local vm=$1
    load_vm_config "$vm" || return
    header
    if is_vm_running "$IMG_FILE"; then
        spin_start "Stopping $vm"
        pkill -f "qemu-system-x86_64.*$IMG_FILE" 2>/dev/null || true
        sleep 2
        if is_vm_running "$IMG_FILE"; then
            pkill -9 -f "qemu-system-x86_64.*$IMG_FILE" 2>/dev/null || true
        fi
        spin_stop 0
        blink_text "■ VM $vm stopped" 2
    else
        print_status INFO "VM $vm is not running"
    fi
    press_enter
}

delete_vm() {
    local vm=$1
    load_vm_config "$vm" || return
    header
    print_status WARN "This will permanently delete '$vm' and all data!"
    if confirm "Delete VM '$vm'?"; then
        spin_start "Deleting VM files"
        rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm.conf"
        spin_stop 0
        blink_text "✗ VM '$vm' deleted" 2
    else
        print_status INFO "Cancelled"
    fi
    press_enter
}

show_vm_info() {
    local vm=$1
    load_vm_config "$vm" || return
    header
    print_status STEP "VM Info: $vm"
    hr
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "OS:"         "$OS_TYPE"
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "Hostname:"   "$HOSTNAME"
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "Username:"   "$USERNAME"
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "Password:"   "$PASSWORD"
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "SSH Port:"   "$SSH_PORT"
    printf "  ${C_GREY}%-14s${C_RESET} %s MB\n" "Memory:"  "$MEMORY"
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "CPUs:"       "$CPUS"
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "Disk:"       "$DISK_SIZE"
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "GUI Mode:"   "$GUI_MODE"
    if [[ "$KVM" == "true" ]]; then
        printf "  ${C_GREY}%-14s${C_RESET} ${C_GRN}KVM acceleration${C_RESET}\n" "Accel:"
    else
        printf "  ${C_GREY}%-14s${C_RESET} ${C_YEL}Software emulation${C_RESET}\n" "Accel:"
    fi
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "Forwards:"   "${PORT_FORWARDS:-none}"
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "SSH Key:"    "$SSH_KEY"
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "Created:"    "$CREATED"
    hr
    echo
    press_enter
}

# ---------------------------------------------------------------------
#  Edit
# ---------------------------------------------------------------------
edit_vm_config() {
    local vm=$1
    load_vm_config "$vm" || return
    while true; do
        header
        print_status STEP "Edit VM: $vm"
        echo
        echo "  1) Hostname        $HOSTNAME"
        echo "  2) Username        $USERNAME"
        echo "  3) Password        ****"
        echo "  4) SSH Port        $SSH_PORT"
        echo "  5) GUI Mode        $GUI_MODE"
        echo "  6) Port Forwards   ${PORT_FORWARDS:-none}"
        echo "  7) Memory (MB)     $MEMORY"
        echo "  8) CPU Count       $CPUS"
        echo "  9) Disk Size       $DISK_SIZE"
        if [[ "$KVM" == "true" ]]; then
            echo "  A) Acceleration    KVM"
        else
            echo "  A) Acceleration    Software"
        fi
        echo "  0) Back"
        echo
        ask ec "Choice: "
        case $ec in
            1) while true; do ask v "New hostname [$HOSTNAME]: "; v="${v:-$HOSTNAME}"
                 validate_input name "$v" && { HOSTNAME="$v"; break; }; done ;;
            2) while true; do ask v "New username [$USERNAME]: "; v="${v:-$USERNAME}"
                 validate_input username "$v" && { USERNAME="$v"; break; }; done ;;
            3) while true; do ask v "New password: " secret
                 v="${v:-$PASSWORD}"; [[ -n "$v" ]] && { PASSWORD="$v"; break; }; done ;;
            4) while true; do ask v "New SSH port [$SSH_PORT]: "; v="${v:-$SSH_PORT}"
                 if validate_input port "$v"; then
                     if [[ "$v" != "$SSH_PORT" ]] && port_in_use "$v"; then
                         print_status ERROR "Port $v in use"
                     else SSH_PORT="$v"; break; fi
                 fi; done ;;
            5) while true; do ask v "GUI mode? [y/N, current=$GUI_MODE]: "
                 v="${v:-}"
                 if [[ "$v" =~ ^[Yy]$ ]]; then GUI_MODE=true; break
                 elif [[ "$v" =~ ^[Nn]$ ]]; then GUI_MODE=false; break
                 elif [[ -z "$v" ]]; then break
                 else print_status ERROR "y or n"; fi; done ;;
            6) ask v "Port forwards [${PORT_FORWARDS:-none}]: "
               PORT_FORWARDS="${v:-$PORT_FORWARDS}" ;;
            7) while true; do ask v "Memory MB [$MEMORY]: "; v="${v:-$MEMORY}"
                 validate_input number "$v" && { MEMORY="$v"; break; }; done ;;
            8) while true; do ask v "CPUs [$CPUS]: "; v="${v:-$CPUS}"
                 validate_input number "$v" && { CPUS="$v"; break; }; done ;;
            9) while true; do ask v "Disk size [$DISK_SIZE]: "; v="${v:-$DISK_SIZE}"
                 validate_input size "$v" && { DISK_SIZE="$v"; break; }; done ;;
            A|a) ask_kvm_choice "$KVM" ;;
            0) return ;;
            *) print_status ERROR "Invalid"; press_enter; continue ;;
        esac
        save_vm_config
        echo
        confirm "Continue editing?" || break
    done
}

# ---------------------------------------------------------------------
#  Resize disk
# ---------------------------------------------------------------------
resize_vm_disk() {
    local vm=$1
    load_vm_config "$vm" || return
    header
    print_status STEP "Resize disk: $vm (current: $DISK_SIZE)"
    while true; do
        ask nd "New size (e.g. 50G): "
        validate_input size "$nd" || continue
        if [[ "$nd" == "$DISK_SIZE" ]]; then
            print_status INFO "Same as current"; press_enter; return
        fi
        local cu=${DISK_SIZE%[GgMm]} nu=${nd%[GgMm]}
        local cuu=${DISK_SIZE: -1} nuu=${nd: -1}
        [[ "$cuu" =~ [Gg] ]] && cu=$((cu*1024))
        [[ "$nuu" =~ [Gg] ]] && nu=$((nu*1024))
        if [[ $nu -lt $cu ]]; then
            print_status WARN "Shrinking is not recommended!"
            confirm "Continue anyway?" || { print_status INFO "Cancelled"; press_enter; return; }
        fi
        spin_start "Resizing disk to $nd"
        if qemu-img resize "$IMG_FILE" "$nd" >/dev/null 2>&1; then
            spin_stop 0
            DISK_SIZE="$nd"; save_vm_config
            blink_text "✔ Resized to $nd" 2
        else
            spin_stop 1
            print_status ERROR "Resize failed"
        fi
        press_enter; return
    done
}

# ---------------------------------------------------------------------
#  Performance
# ---------------------------------------------------------------------
show_vm_performance() {
    local vm=$1
    load_vm_config "$vm" || return
    header
    print_status STEP "Performance: $vm"
    hr
    if is_vm_running "$IMG_FILE"; then
        local pid
        pid=$(pgrep -f "qemu-system-x86_64.*$IMG_FILE" | head -1)
        if [[ -n "$pid" ]]; then
            printf "  ${C_GREY}%-14s${C_RESET} %s\n" "QEMU PID:" "$pid"
            ps -p "$pid" -o %cpu,%mem,rss --no-headers | awk '{printf "  \033[0;90m%-14s\033[0m CPU %s%%  MEM %s%%  RSS %.1f MB\n","Usage:",$1,$2,$3/1024}'
        fi
    else
        print_status INFO "VM not running"
        printf "  ${C_GREY}Memory:%s MB    CPUs:%s    Disk:%s\n" "$MEMORY" "$CPUS" "$DISK_SIZE"
    fi
    hr
    press_enter
}

# ---------------------------------------------------------------------
#  VM picker
# ---------------------------------------------------------------------
pick_vm() {
    local prompt=$1
    local vms=($(get_vm_list))
    local n=${#vms[@]}
    ((n == 0)) && { print_status ERROR "No VMs found"; press_enter; return 1; }
    ask num "$prompt [1-$n]: "
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$n" ]; then
        echo "${vms[$((num-1))]}"
        return 0
    fi
    print_status ERROR "Invalid selection"
    return 1
}

# ---------------------------------------------------------------------
#  Main menu
# ---------------------------------------------------------------------
main_menu() {
    while true; do
        local vms=($(get_vm_list))
        local count=${#vms[@]}
        header

        if ((count > 0)); then
            printf '  %s %-20s %-12s %-7s %-10s %s\n' \
                "${C_GREY}#${C_RESET}" "${C_GREY}NAME${C_RESET}" \
                "${C_GREY}STATUS${C_RESET}" "${C_GREY}PORT${C_RESET}" \
                "${C_GREY}ACCEL${C_RESET}" "${C_GREY}OS${C_RESET}"
            hr
            local i=1
            for vm in "${vms[@]}"; do
                local status port os kvm accel
                if is_vm_running "$VM_DIR/$vm.img"; then
                    status="${C_GRN}● running${C_RESET}"
                else
                    status="${C_GREY}○ stopped${C_RESET}"
                fi
                port="$(grep -m1 '^SSH_PORT=' "$VM_DIR/$vm.conf" | cut -d= -f2 | tr -d '"')"
                os="$(grep -m1 '^OS_TYPE=' "$VM_DIR/$vm.conf" | cut -d= -f2 | tr -d '"')"
                kvm="$(grep -m1 '^KVM=' "$VM_DIR/$vm.conf" | cut -d= -f2 | tr -d '"')"
                [[ -z "$kvm" ]] && kvm="true"
                if [[ "$kvm" == "true" ]]; then
                    accel="${C_GRN}KVM${C_RESET}"
                else
                    accel="${C_YEL}SW${C_RESET}"
                fi
                printf '  %-2s %-20s %-22b %-7s %-20b %s\n' \
                    "$i)" "$vm" "$status" "$port" "$accel" "$os"
                sleep 0.03
                ((i++))
            done
            hr
        else
            print_status INFO "No VMs yet — create one to begin."
            echo
        fi

        echo "  ${C_BOLD}Menu${C_RESET}"
        echo "  ${C_CYN}1${C_RESET}) Create new VM"
        if ((count > 0)); then
            echo "  ${C_CYN}2${C_RESET}) Start VM"
            echo "  ${C_CYN}3${C_RESET}) Stop VM"
            echo "  ${C_CYN}4${C_RESET}) Show VM info"
            echo "  ${C_CYN}5${C_RESET}) Edit VM configuration"
            echo "  ${C_CYN}6${C_RESET}) Delete VM"
            echo "  ${C_CYN}7${C_RESET}) Resize VM disk"
            echo "  ${C_CYN}8${C_RESET}) Show VM performance"
        fi
        echo "  ${C_CYN}T${C_RESET}) Toggle animations ($([[ "$ANIMATIONS" == true ]] && echo "${C_GRN}ON${C_RESET}" || echo "${C_GREY}OFF${C_RESET}"))"
        echo "  ${C_CYN}0${C_RESET}) Exit"
        echo

        local choice
        ask choice "Select option: "

        case $choice in
            1) create_new_vm ;;
            2) ((count > 0)) && { local vm; vm=$(pick_vm "VM to start")   && start_vm "$vm"; } ;;
            3) ((count > 0)) && { local vm; vm=$(pick_vm "VM to stop")    && stop_vm  "$vm"; } ;;
            4) ((count > 0)) && { local vm; vm=$(pick_vm "VM to inspect") && show_vm_info "$vm"; } ;;
            5) ((count > 0)) && { local vm; vm=$(pick_vm "VM to edit")    && edit_vm_config "$vm"; } ;;
            6) ((count > 0)) && { local vm; vm=$(pick_vm "VM to delete")  && delete_vm "$vm"; } ;;
            7) ((count > 0)) && { local vm; vm=$(pick_vm "VM to resize")  && resize_vm_disk "$vm"; } ;;
            8) ((count > 0)) && { local vm; vm=$(pick_vm "VM to inspect") && show_vm_performance "$vm"; } ;;
            T|t)
                if [[ "$ANIMATIONS" == true ]]; then ANIMATIONS=false; else ANIMATIONS=true; fi
                ;;
            0) print_status INFO "Goodbye from Invis Cloud · 4z1m"; exit 0 ;;
            *) print_status ERROR "Invalid option"; sleep 1 ;;
        esac
    done
}

# ---------------------------------------------------------------------
#  Supported OS catalogue
# ---------------------------------------------------------------------
declare -A OS_OPTIONS=(
    ["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["Debian 11"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"
    ["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"
    ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"
    ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
)

# ---------------------------------------------------------------------
#  Entry
# ---------------------------------------------------------------------
check_dependencies
main_menu
