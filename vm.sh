#!/bin/bash
# =====================================================================
#   Invis Cloud — Multi-VM Manager
#   Powered by 4z1m
# =====================================================================
set -uo pipefail

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

ANIMATIONS=true

# ---------------------------------------------------------------------
#  Paths
# ---------------------------------------------------------------------
VM_DIR="${VM_DIR:-$PWD/vms}"
BASE_DIR="$VM_DIR/base"
KEY_DIR="$VM_DIR/keys"
mkdir -p "$VM_DIR" "$BASE_DIR" "$KEY_DIR" 2>/dev/null || true
chmod 700 "$KEY_DIR" 2>/dev/null || true

TMP_RUN="$(mktemp -d)"
trap 'rm -rf "$TMP_RUN"' EXIT

# ---------------------------------------------------------------------
#  Animation primitives (all output to stderr)
# ---------------------------------------------------------------------
SPIN_PID=""
SPIN_MSG=""

spin_start() {
    SPIN_MSG="$1"
    if [[ "$ANIMATIONS" != true ]]; then
        printf '◆ %s' "$SPIN_MSG" >&2
        return
    fi
    (
        local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        while true; do
            for f in "${frames[@]}"; do
                printf '\r%s %s %s' "${C_CYN}${f}${C_RESET}" "${C_BLU}${SPIN_MSG}${C_RESET}" "${C_GREY}...${C_RESET}" >&2
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
            printf '\r%s %s %s\n' "${C_GRN}✔${C_RESET}" "$SPIN_MSG" "${C_GREY}... done${C_RESET}" >&2
        else
            printf '\r%s %s %s\n' "${C_RED}✖${C_RESET}" "$SPIN_MSG" "${C_GREY}... failed${C_RESET}" >&2
        fi
    fi
}

matrix_rain() {
    [[ "$ANIMATIONS" != true ]] && return
    local chars=('0' '1' '#' '@' '%' '&' '$' '?' '!' '=' '+' '*' 'x')
    local l c
    for ((l=0; l<4; l++)); do
        local line=""
        for ((c=0; c<60; c++)); do
            line+="${chars[$((RANDOM % ${#chars[@]}))]}"
        done
        printf '%s%s%s\n' "${C_GRN}${C_DIM}" "$line" "${C_RESET}" >&2
        sleep 0.04
    done
}

blink_text() {
    local text="$1" times="${2:-2}"
    [[ "$ANIMATIONS" != true ]] && { printf '%s\n' "$text" >&2; return; }
    local i
    for ((i=0; i<times; i++)); do
        printf '\r%s%s%s' "${C_GRN}${C_BOLD}" "$text" "${C_RESET}" >&2
        sleep 0.15
        printf '\r%s%s%s' "${C_DIM}" "$text" "${C_RESET}" >&2
        sleep 0.15
    done
    printf '\r%s%s%s\n' "${C_GRN}${C_BOLD}" "$text" "${C_RESET}" >&2
}

# ---------------------------------------------------------------------
#  UI helpers
# ---------------------------------------------------------------------
safe_clear() {
    clear 2>/dev/null || printf '\033[2J\033[H'
}

hr() {
    printf '%s\n' "${C_GREY}$(printf '─%.0s' $(seq 1 72))${C_RESET}"
}

print_status() {
    local type=$1; shift
    local msg="$*"
    case $type in
        INFO)    printf '%s\n' "${C_BLU}◆ INFO${C_RESET}    $msg" >&2 ;;
        WARN)    printf '%s\n' "${C_YEL}▲ WARN${C_RESET}    $msg" >&2 ;;
        ERROR)   printf '%s\n' "${C_RED}✖ ERROR${C_RESET}   $msg" >&2 ;;
        SUCCESS) printf '%s\n' "${C_GRN}✔ SUCCESS${C_RESET} $msg" >&2 ;;
        STEP)    printf '%s\n' "${C_MAG}▸${C_RESET} $msg" >&2 ;;
    esac
}

ask() {
    local var=$1 msg=$2 secret=${3:-}
    local val=""
    if [[ "$secret" == "secret" ]]; then
        printf '%s ' "${C_CYN}❯${C_RESET} $msg" >&2
        IFS= read -rs val || true
        echo >&2
    else
        printf '%s ' "${C_CYN}❯${C_RESET} $msg" >&2
        IFS= read -r val || true
    fi
    printf -v "$var" '%s' "$val"
}

confirm() {
    local msg=$1 reply=""
    printf '%s ' "${C_YEL}?${C_RESET} $msg [y/N]:" >&2
    IFS= read -rn1 reply || true
    echo >&2
    [[ "$reply" =~ ^[Yy]$ ]]
}

press_enter() {
    printf '%s' "${C_GREY}Press Enter to continue...${C_RESET}" >&2
    IFS= read -r _ || true
}

# ---------------------------------------------------------------------
#  Banner
# ---------------------------------------------------------------------
banner() {
    printf '\n' >&2
    printf '%s\n' "${C_CYN}${C_BOLD}  ╔══════════════════════════════════════════════════════════╗${C_RESET}" >&2
    printf '%s\n' "${C_CYN}${C_BOLD}  ║                                                          ║${C_RESET}" >&2
    printf '%s\n' "${C_CYN}${C_BOLD}  ║            I N V I S   C L O U D   ·   V M               ║${C_RESET}" >&2
    printf '%s\n' "${C_CYN}${C_BOLD}  ║                                                          ║${C_RESET}" >&2
    printf '%s\n' "${C_CYN}${C_BOLD}  ╚══════════════════════════════════════════════════════════╝${C_RESET}" >&2
    printf '%s\n' "${C_GREY}                    powered by ${C_MAG}${C_BOLD}4z1m${C_RESET}" >&2
    printf '\n' >&2
}

header() {
    safe_clear
    banner
    hr
    printf '%s\n' "${C_GREY}  VM Directory: ${C_WHT}$VM_DIR${C_RESET}"
    if [[ -w /dev/kvm ]]; then
        printf '%s\n' "${C_GREY}  Host KVM:     ${C_GRN}● available${C_RESET}"
    else
        printf '%s\n' "${C_GREY}  Host KVM:     ${C_RED}○ unavailable${C_RESET}"
    fi
    printf '%s\n' "${C_GREY}  Date:         ${C_WHT}$(date '+%Y-%m-%d %H:%M:%S')${C_RESET}"
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
        size)     [[ "$value" =~ ^[0-9]+[GgMm]$ ]] || { print_status ERROR "Use size with unit (e.g. 20G)"; return 1; } ;;
        port)
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 23 ] || [ "$value" -gt 65535 ]; then
                print_status ERROR "Port must be 23–65535"; return 1
            fi ;;
        name)     [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]] || { print_status ERROR "Only letters, numbers, - and _"; return 1; } ;;
        username) [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]] || { print_status ERROR "Invalid username"; return 1; } ;;
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
        print_status INFO  "Install: sudo apt install qemu-system-x86 qemu-utils cloud-image-utils wget openssh-client openssl"
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
    source "$file" 2>/dev/null || true
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
    chmod 600 "$file" 2>/dev/null || true
    print_status SUCCESS "Config saved"
}

# ---------------------------------------------------------------------
#  SSH key
# ---------------------------------------------------------------------
ensure_ssh_key() {
    local vm=$1 keyfile="$KEY_DIR/$1_ed25519"
    if [[ ! -f "$keyfile" ]]; then
        ssh-keygen -t ed25519 -N "" -f "$keyfile" -C "invis-cloud-$vm" >/dev/null 2>&1
        if [[ ! -f "$keyfile" ]]; then
            print_status ERROR "Failed to create SSH key"
            return 1
        fi
        print_status INFO "SSH keypair created"
    fi
    SSH_KEY="$keyfile"
    PUB_KEY="$(cat "${keyfile}.pub" 2>/dev/null || true)"
    return 0
}

# ---------------------------------------------------------------------
#  Base image cache
# ---------------------------------------------------------------------
base_image_path() {
    local name; name="$(basename "$IMG_URL")"
    echo "$BASE_DIR/$1_$name"
}

bytes_human() {
    local b=$1
    if (( b >= 1073741824 )); then awk -v b="$b" 'BEGIN{printf "%.1f GB", b/1073741824}'
    elif (( b >= 1048576 )); then awk -v b="$b" 'BEGIN{printf "%.1f MB", b/1048576}'
    elif (( b >= 1024 )); then awk -v b="$b" 'BEGIN{printf "%.1f KB", b/1024}'
    else printf '%d B' "$b"
    fi
}

ensure_base_image() {
    local base; base="$(base_image_path "$OS_TYPE")"

    if [[ -f "$base" ]]; then
        print_status INFO "Using cached base: $(basename "$base")"
        BASE_IMG="$base"
        return 0
    fi

    echo >&2
    print_status INFO "Downloading base image for $OS_TYPE"
    printf '%s\n' "${C_GREY}  URL: $IMG_URL${C_RESET}" >&2
    echo >&2

    if [[ -n "$SPIN_PID" ]]; then
        kill "$SPIN_PID" 2>/dev/null || true
        wait "$SPIN_PID" 2>/dev/null || true
        SPIN_PID=""
    fi

    if ! wget --progress=bar:force:noscroll --timeout=30 --tries=3 \
            -O "$base.tmp" "$IMG_URL" >&2 2>&1; then
        rm -f "$base.tmp"
        print_status ERROR "Download failed"
        return 1
    fi

    local size
    size=$(stat -c%s "$base.tmp" 2>/dev/null || echo 0)
    if (( size < 10000000 )); then
        print_status ERROR "Downloaded file too small — likely a 404 page"
        rm -f "$base.tmp"
        return 1
    fi

    mv "$base.tmp" "$base"
    print_status SUCCESS "Base cached: $(bytes_human "$size")"
    BASE_IMG="$base"
    return 0
}

# ---------------------------------------------------------------------
#  VM picker
# ---------------------------------------------------------------------
PICKED_VM=""
pick_vm() {
    local prompt=$1
    PICKED_VM=""
    local vms=()
    while IFS= read -r line; do
        vms+=("$line")
    done < <(get_vm_list)
    local n=${#vms[@]}
    if ((n == 0)); then
        print_status ERROR "No VMs found"
        press_enter
        return 1
    fi
    local num
    ask num "$prompt [1-$n]: "
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$n" ]; then
        PICKED_VM="${vms[$((num-1))]}"
        return 0
    fi
    print_status ERROR "Invalid selection"
    return 1
}

# ---------------------------------------------------------------------
#  Create VM
# ---------------------------------------------------------------------
create_new_vm() {
    header
    print_status STEP "Create a new VM"
    echo >&2

    local os_list=("${!OS_OPTIONS[@]}")
    local i=1
    for os in "${os_list[@]}"; do
        printf "  ${C_CYN}%2d)${C_RESET} %s\n" "$i" "$os" >&2
        ((i++))
    done
    echo >&2

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
    echo >&2

    while true; do
        ask VM_NAME "VM name [$DEF_HOST]: "
        VM_NAME="${VM_NAME:-$DEF_HOST}"
        if validate_input name "$VM_NAME"; then
            if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
                print_status ERROR "VM '$VM_NAME' already exists"
            else
                break
            fi
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
        if [[ -n "$PASSWORD" ]]; then break; fi
        print_status ERROR "Password cannot be empty"
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
            if port_in_use "$SSH_PORT"; then
                print_status ERROR "Port $SSH_PORT already in use"
            else
                break
            fi
        fi
    done

    while true; do
        ask gui_input "GUI mode? [y/N]: "
        GUI_MODE=false; gui_input="${gui_input:-n}"
        if [[ "$gui_input" =~ ^[Yy]$ ]]; then GUI_MODE=true; break
        elif [[ "$gui_input" =~ ^[Nn]$ ]]; then break
        else print_status ERROR "Please answer y or n"; fi
    done

    # KVM choice
    echo >&2
    print_status STEP "Acceleration mode"
    printf "  ${C_CYN}1${C_RESET}) KVM acceleration (fast)\n" >&2
    printf "  ${C_CYN}2${C_RESET}) Software emulation (slow)\n" >&2
    while true; do
        local kin
        ask kin "Choose [1-2, default=2]: "
        kin="${kin:-2}"
        case $kin in
            1)
                if [[ ! -w /dev/kvm ]]; then
                    print_status WARN "/dev/kvm not available"
                    confirm "Still use KVM?" && { KVM=true; break; }
                else
                    KVM=true; break
                fi ;;
            2) KVM=false; break ;;
            *) print_status ERROR "Enter 1 or 2" ;;
        esac
    done

    ask PORT_FORWARDS "Additional port forwards [none]: "

    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"

    echo >&2
    if ! ensure_ssh_key "$VM_NAME"; then press_enter; return 1; fi
    if ! ensure_base_image; then press_enter; return 1; fi

    spin_start "Creating qcow2 overlay"
    if ! qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMG" "$IMG_FILE" >/dev/null 2>&1; then
        spin_stop 1
        print_status ERROR "Failed to create disk"
        press_enter; return 1
    fi
    if ! qemu-img resize "$IMG_FILE" "$DISK_SIZE" >/dev/null 2>&1; then
        spin_stop 1
        print_status ERROR "Failed to resize disk"
        press_enter; return 1
    fi
    spin_stop 0

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
EOF
    cat > "$TMP_RUN/meta-data" <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF
    if ! cloud-localds "$SEED_FILE" "$TMP_RUN/user-data" "$TMP_RUN/meta-data" >/dev/null 2>&1; then
        spin_stop 1
        print_status ERROR "Failed to create seed"
        press_enter; return 1
    fi
    spin_stop 0

    save_vm_config
    echo >&2
    blink_text "✓ VM '$VM_NAME' created!"
    print_status INFO "SSH: ssh -i $SSH_KEY -p $SSH_PORT $USERNAME@127.0.0.1"
    echo >&2
    press_enter
    return 0
}

# ---------------------------------------------------------------------
#  Start VM
# ---------------------------------------------------------------------
start_vm() {
    local vm=$1
    if ! load_vm_config "$vm"; then press_enter; return 1; fi

    header
    print_status STEP "Starting VM: $vm"
    echo
    printf "  ${C_GREY}%-12s${C_RESET} %s\n" "SSH:" "ssh -i $SSH_KEY -p $SSH_PORT $USERNAME@127.0.0.1"
    printf "  ${C_GREY}%-12s${C_RESET} %s\n" "Password:" "$PASSWORD"
    printf "  ${C_GREY}%-12s${C_RESET} %s MB / %s CPUs / %s\n" "Resources:" "$MEMORY" "$CPUS" "$DISK_SIZE"
    echo

    if [[ ! -f "$IMG_FILE" ]]; then
        print_status ERROR "Image missing: $IMG_FILE"
        press_enter; return 1
    fi
    if [[ ! -f "$SEED_FILE" ]]; then
        print_status ERROR "Seed missing"
        press_enter; return 1
    fi

    local accel=() cpu="qemu64"
    if [[ "$KVM" == "true" ]]; then
        if [[ -w /dev/kvm ]]; then
            accel=(-enable-kvm)
            cpu="host"
            print_status SUCCESS "KVM acceleration enabled"
        else
            print_status ERROR "KVM requested but /dev/kvm unavailable"
            press_enter; return 1
        fi
    else
        print_status INFO "Software emulation mode"
    fi

    echo >&2
    matrix_rain
    echo >&2
    countdown_short 2

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

    print_status INFO "Launching QEMU... (Ctrl-A X to exit)"
    echo
    "${qemu[@]}"
    echo
    blink_text "▣ VM $vm shut down"
    press_enter
    return 0
}

countdown_short() {
    [[ "$ANIMATIONS" != true ]] && return
    local n=$1 i
    for ((i=n; i>0; i--)); do
        printf '\r%s Booting in %ds...' "${C_YEL}◷${C_RESET}" "$i" >&2
        sleep 1
    done
    printf '\r%s Booting now!   \n' "${C_GRN}✔${C_RESET}" >&2
}

# ---------------------------------------------------------------------
#  Stop VM
# ---------------------------------------------------------------------
is_vm_running() {
    local pattern="$1"
    [[ -z "$pattern" ]] && return 1
    pgrep -f "qemu-system-x86_64.*${pattern}" >/dev/null 2>&1
}

stop_vm() {
    local vm=$1
    if ! load_vm_config "$vm"; then press_enter; return 1; fi
    header
    if is_vm_running "$IMG_FILE"; then
        spin_start "Stopping $vm"
        pkill -f "qemu-system-x86_64.*$IMG_FILE" 2>/dev/null || true
        sleep 2
        if is_vm_running "$IMG_FILE"; then
            pkill -9 -f "qemu-system-x86_64.*$IMG_FILE" 2>/dev/null || true
        fi
        spin_stop 0
        blink_text "■ VM $vm stopped"
    else
        print_status INFO "VM $vm is not running"
    fi
    press_enter
    return 0
}

# ---------------------------------------------------------------------
#  Delete VM
# ---------------------------------------------------------------------
delete_vm() {
    local vm=$1
    if ! load_vm_config "$vm"; then press_enter; return 1; fi
    header
    print_status WARN "This will permanently delete '$vm'!"
    if confirm "Delete VM '$vm'?"; then
        # Stop if running
        if is_vm_running "$IMG_FILE"; then
            pkill -f "qemu-system-x86_64.*$IMG_FILE" 2>/dev/null || true
            sleep 1
        fi
        spin_start "Deleting files"
        rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm.conf" 2>/dev/null || true
        spin_stop 0
        blink_text "✗ VM '$vm' deleted"
    else
        print_status INFO "Cancelled"
    fi
    press_enter
    return 0
}

# ---------------------------------------------------------------------
#  Show VM info
# ---------------------------------------------------------------------
show_vm_info() {
    local vm=$1
    if ! load_vm_config "$vm"; then press_enter; return 1; fi
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
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "GUI:"        "$GUI_MODE"
    if [[ "$KVM" == "true" ]]; then
        printf "  ${C_GREY}%-14s${C_RESET} ${C_GRN}KVM${C_RESET}\n" "Accel:"
    else
        printf "  ${C_GREY}%-14s${C_RESET} ${C_YEL}Software${C_RESET}\n" "Accel:"
    fi
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "Forwards:"   "${PORT_FORWARDS:-none}"
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "SSH Key:"    "$SSH_KEY"
    printf "  ${C_GREY}%-14s${C_RESET} %s\n" "Created:"    "$CREATED"
    hr
    echo
    press_enter
    return 0
}

# ---------------------------------------------------------------------
#  Edit VM
# ---------------------------------------------------------------------
edit_vm_config() {
    local vm=$1
    if ! load_vm_config "$vm"; then press_enter; return 1; fi
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
            5) ask v "GUI mode? (current=$GUI_MODE) [y/N]: "
               v="${v:-}"
               if [[ "$v" =~ ^[Yy]$ ]]; then GUI_MODE=true
               elif [[ "$v" =~ ^[Nn]$ ]]; then GUI_MODE=false
               fi ;;
            6) ask v "Port forwards [${PORT_FORWARDS:-none}]: "
               PORT_FORWARDS="${v:-$PORT_FORWARDS}" ;;
            7) while true; do ask v "Memory MB [$MEMORY]: "; v="${v:-$MEMORY}"
                 validate_input number "$v" && { MEMORY="$v"; break; }; done ;;
            8) while true; do ask v "CPUs [$CPUS]: "; v="${v:-$CPUS}"
                 validate_input number "$v" && { CPUS="$v"; break; }; done ;;
            9) while true; do ask v "Disk size [$DISK_SIZE]: "; v="${v:-$DISK_SIZE}"
                 validate_input size "$v" && { DISK_SIZE="$v"; break; }; done ;;
            A|a)
                echo
                echo "  1) KVM acceleration"
                echo "  2) Software emulation"
                ask v "Choose [1-2]: "
                case $v in
                    1) if [[ -w /dev/kvm ]]; then KVM=true; else print_status WARN "/dev/kvm unavailable"; fi ;;
                    2) KVM=false ;;
                esac ;;
            0) save_vm_config; return 0 ;;
            *) print_status ERROR "Invalid"; press_enter; continue ;;
        esac
        save_vm_config
        echo
        if ! confirm "Continue editing?"; then break; fi
    done
    return 0
}

# ---------------------------------------------------------------------
#  Resize disk
# ---------------------------------------------------------------------
resize_vm_disk() {
    local vm=$1
    if ! load_vm_config "$vm"; then press_enter; return 1; fi
    header
    print_status STEP "Resize disk: $vm (current: $DISK_SIZE)"
    while true; do
        local nd
        ask nd "New size (e.g. 50G): "
        validate_input size "$nd" || continue
        if [[ "$nd" == "$DISK_SIZE" ]]; then
            print_status INFO "Same as current"
            press_enter; return 0
        fi
        local cu=${DISK_SIZE%[GgMm]} nu=${nd%[GgMm]}
        local cuu=${DISK_SIZE: -1} nuu=${nd: -1}
        [[ "$cuu" =~ [Gg] ]] && cu=$((cu*1024))
        [[ "$nuu" =~ [Gg] ]] && nu=$((nu*1024))
        if [[ $nu -lt $cu ]]; then
            print_status WARN "Shrinking not recommended!"
            if ! confirm "Continue anyway?"; then
                print_status INFO "Cancelled"
                press_enter; return 0
            fi
        fi
        spin_start "Resizing to $nd"
        if qemu-img resize "$IMG_FILE" "$nd" >/dev/null 2>&1; then
            spin_stop 0
            DISK_SIZE="$nd"
            save_vm_config
            blink_text "✔ Resized to $nd"
        else
            spin_stop 1
            print_status ERROR "Resize failed"
        fi
        press_enter
        return 0
    done
}

# ---------------------------------------------------------------------
#  Performance
# ---------------------------------------------------------------------
show_vm_performance() {
    local vm=$1
    if ! load_vm_config "$vm"; then press_enter; return 1; fi
    header
    print_status STEP "Performance: $vm"
    hr
    if is_vm_running "$IMG_FILE"; then
        local pid
        pid=$(pgrep -f "qemu-system-x86_64.*$IMG_FILE" | head -1 || true)
        if [[ -n "$pid" ]]; then
            printf "  ${C_GREY}%-14s${C_RESET} %s\n" "QEMU PID:" "$pid"
            ps -p "$pid" -o %cpu,%mem,rss --no-headers 2>/dev/null | \
                awk '{printf "  \033[0;90m%-14s\033[0m CPU %s%%  MEM %s%%  RSS %.1f MB\n","Usage:",$1,$2,$3/1024}'
        fi
    else
        print_status INFO "VM not running"
        printf "  ${C_GREY}Memory:%s MB  CPUs:%s  Disk:%s\n" "$MEMORY" "$CPUS" "$DISK_SIZE"
    fi
    hr
    press_enter
    return 0
}

# ---------------------------------------------------------------------
#  Main menu
# ---------------------------------------------------------------------
main_menu() {
    while true; do
        local vms=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && vms+=("$line")
        done < <(get_vm_list)
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
                port="$(grep -m1 '^SSH_PORT=' "$VM_DIR/$vm.conf" 2>/dev/null | cut -d= -f2 | tr -d '"')"
                os="$(grep -m1 '^OS_TYPE=' "$VM_DIR/$vm.conf" 2>/dev/null | cut -d= -f2 | tr -d '"')"
                kvm="$(grep -m1 '^KVM=' "$VM_DIR/$vm.conf" 2>/dev/null | cut -d= -f2 | tr -d '"')"
                [[ -z "$kvm" ]] && kvm="true"
                if [[ "$kvm" == "true" ]]; then
                    accel="${C_GRN}KVM${C_RESET}"
                else
                    accel="${C_YEL}SW${C_RESET}"
                fi
                printf '  %-2s %-20s %-22b %-7s %-20b %s\n' \
                    "$i)" "$vm" "$status" "$port" "$accel" "$os"
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
            2) pick_vm "VM to start"   && start_vm "$PICKED_VM" ;;
            3) pick_vm "VM to stop"    && stop_vm "$PICKED_VM" ;;
            4) pick_vm "VM to inspect" && show_vm_info "$PICKED_VM" ;;
            5) pick_vm "VM to edit"    && edit_vm_config "$PICKED_VM" ;;
            6) pick_vm "VM to delete"  && delete_vm "$PICKED_VM" ;;
            7) pick_vm "VM to resize"  && resize_vm_disk "$PICKED_VM" ;;
            8) pick_vm "VM to inspect" && show_vm_performance "$PICKED_VM" ;;
            T|t)
                if [[ "$ANIMATIONS" == true ]]; then ANIMATIONS=false; else ANIMATIONS=true; fi ;;
            0) print_status INFO "Goodbye from Invis Cloud · 4z1m"; exit 0 ;;
            *) print_status ERROR "Invalid option"; sleep 1 ;;
        esac
    done
}

# ---------------------------------------------------------------------
#  OS catalogue
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
