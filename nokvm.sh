#!/bin/bash
set -euo pipefail

# ============================================================
#                NXR TECHNOLOGIES VPS MANAGER
# ============================================================

VM_DIR="${VM_DIR:-$HOME/vms}"

# ============================================================
# Colors
# ============================================================

BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
RESET='\033[0m'

# ============================================================
# Header
# ============================================================

display_header() {
    clear

    cat << "EOF"

===============================================================
 _   _  __  __   ____    _____         _                    _
| \ | ||  \/  | |  _ \  |_   _|__  ___| |__  _ __   ___   | |
|  \| || |\/| | | |_) |   | |/ _ \/ __| '_ \| '_ \ / _ \  | |
| |\  || |  | | |  _ <    | |  __/ (__| | | | | | | (_) | | |
|_| \_||_|  |_| |_| \_\   |_|\___|\___|_| |_|_| |_|\___/  |_|

                 NXR TECHNOLOGIES
                    VPS MANAGER

===============================================================
EOF

    echo
}

# ============================================================
# Status Messages
# ============================================================

print_status() {
    local type="$1"
    local message="$2"

    case "$type" in
        INFO)
            echo -e "${BLUE}[INFO]${RESET} $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${RESET} $message"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${RESET} $message"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${RESET} $message"
            ;;
        INPUT)
            echo -e "${CYAN}[INPUT]${RESET} $message"
            ;;
        *)
            echo "[$type] $message"
            ;;
    esac
}

# ============================================================
# Dependency Check
# ============================================================

check_dependencies() {

    local deps=(
        qemu-system-x86_64
        qemu-img
        cloud-localds
        wget
        openssl
        ss
    )

    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        print_status ERROR "Missing dependencies:"
        echo "  ${missing[*]}"
        echo
        print_status INFO "Install them with:"
        echo "apt install -y qemu-system qemu-utils cloud-image-utils wget openssl iproute2"
        exit 1
    fi
}

# ============================================================
# Validation
# ============================================================

validate_name() {

    local value="$1"

    if [[ ! "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_status ERROR "Only letters, numbers, - and _ are allowed."
        return 1
    fi

    return 0
}

validate_number() {

    local value="$1"

    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        print_status ERROR "Must be a number."
        return 1
    fi

    return 0
}

validate_size() {

    local value="$1"

    if [[ ! "$value" =~ ^[0-9]+[GgMmTt]$ ]]; then
        print_status ERROR "Example: 20G, 512M, 1T"
        return 1
    fi

    return 0
}

validate_port() {

    local value="$1"

    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        print_status ERROR "Invalid port."
        return 1
    fi

    if [ "$value" -lt 1024 ] || [ "$value" -gt 65535 ]; then
        print_status ERROR "Port must be between 1024 and 65535."
        return 1
    fi

    return 0
}

# ============================================================
# OS Configuration
# ============================================================

declare -A OS_NAME
declare -A OS_URL
declare -A OS_HOSTNAME
declare -A OS_USERNAME

OS_NAME[1]="Ubuntu 22.04"
OS_URL[1]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
OS_HOSTNAME[1]="ubuntu-22"
OS_USERNAME[1]="ubuntu"

OS_NAME[2]="Ubuntu 24.04"
OS_URL[2]="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
OS_HOSTNAME[2]="ubuntu-24"
OS_USERNAME[2]="ubuntu"

OS_NAME[3]="Debian 12"
OS_URL[3]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
OS_HOSTNAME[3]="debian-12"
OS_USERNAME[3]="debian"

OS_NAME[4]="Debian 13"
OS_URL[4]="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
OS_HOSTNAME[4]="debian-13"
OS_USERNAME[4]="debian"

OS_NAME[5]="AlmaLinux 9"
OS_URL[5]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
OS_HOSTNAME[5]="alma-9"
OS_USERNAME[5]="almalinux"

OS_NAME[6]="Rocky Linux 9"
OS_URL[6]="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
OS_HOSTNAME[6]="rocky-9"
OS_USERNAME[6]="rocky"

OS_COUNT=6

# ============================================================
# VM List
# ============================================================

get_vm_list() {

    find "$VM_DIR" \
        -maxdepth 1 \
        -name "*.conf" \
        -printf "%f\n" 2>/dev/null |
        sed 's/\.conf$//' |
        sort
}

# ============================================================
# Load VM Configuration
# ============================================================

load_vm_config() {

    local vm="$1"
    local config="$VM_DIR/$vm.conf"

    if [ ! -f "$config" ]; then
        print_status ERROR "VM configuration not found."
        return 1
    fi

    unset VM_NAME
    unset OS_TYPE
    unset IMG_URL
    unset HOSTNAME
    unset USERNAME
    unset PASSWORD
    unset DISK_SIZE
    unset MEMORY
    unset CPUS
    unset CPU_NAME
    unset SSH_PORT
    unset IMG_FILE
    unset SEED_FILE
    unset CREATED

    # shellcheck disable=SC1090
    source "$config"

    return 0
}

# ============================================================
# Save VM Configuration
# ============================================================

save_vm_config() {

    local config="$VM_DIR/$VM_NAME.conf"

    cat > "$config" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
CPU_NAME="$CPU_NAME"
SSH_PORT="$SSH_PORT"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
EOF

    print_status SUCCESS "Configuration saved."
}

# ============================================================
# Create Cloud-Init
# ============================================================

create_cloud_init() {

    cat > "$VM_DIR/user-data" <<EOF
#cloud-config

hostname: $HOSTNAME

manage_etc_hosts: true

ssh_pwauth: true

disable_root: false

users:
  - name: $USERNAME
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false

chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false

growpart:
  mode: auto
  devices:
    - /

resize_rootfs: true

runcmd:

  - growpart /dev/vda 1 || true
  - resize2fs /dev/vda1 || true

  - sed -ri 's/^#?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

  - sed -ri 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

  - systemctl restart ssh || systemctl restart sshd || true
EOF

    cat > "$VM_DIR/meta-data" <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    cloud-localds \
        "$SEED_FILE" \
        "$VM_DIR/user-data" \
        "$VM_DIR/meta-data"

    rm -f "$VM_DIR/user-data"
    rm -f "$VM_DIR/meta-data"
}

# ============================================================
# Download VM Image
# ============================================================

setup_vm_image() {

    mkdir -p "$VM_DIR"

    if [ -f "$IMG_FILE" ]; then

        print_status INFO "VM image already exists."

    else

        print_status INFO "Downloading $OS_TYPE..."

        wget \
            --show-progress \
            "$IMG_URL" \
            -O "$IMG_FILE.tmp"

        mv "$IMG_FILE.tmp" "$IMG_FILE"

        print_status SUCCESS "OS image downloaded."

    fi

    print_status INFO "Resizing disk to $DISK_SIZE..."

    qemu-img resize "$IMG_FILE" "$DISK_SIZE"

    print_status INFO "Creating cloud-init configuration..."

    create_cloud_init

    print_status SUCCESS "VM image prepared."
}

# ============================================================
# Create New VM
# ============================================================

create_new_vm() {

    display_header

    print_status INFO "Create New VPS"
    echo

    # --------------------------------------------------------
    # OS Selection
    # --------------------------------------------------------

    echo "Available Operating Systems:"
    echo

    for i in $(seq 1 "$OS_COUNT"); do
        echo "  $i) ${OS_NAME[$i]}"
    done

    echo

    while true; do

        read -rp "$(echo -e "${CYAN}Select OS [1-$OS_COUNT]: ${RESET}")" os_choice

        if [[ "$os_choice" =~ ^[0-9]+$ ]] &&
           [ "$os_choice" -ge 1 ] &&
           [ "$os_choice" -le "$OS_COUNT" ]; then

            break
        fi

        print_status ERROR "Invalid OS selection."

    done

    OS_TYPE="${OS_NAME[$os_choice]}"
    IMG_URL="${OS_URL[$os_choice]}"

    # --------------------------------------------------------
    # VPS Name
    # --------------------------------------------------------

    echo

    while true; do

        read -rp "$(echo -e "${CYAN}Enter VPS name: ${RESET}")" VM_NAME

        if ! validate_name "$VM_NAME"; then
            continue
        fi

        if [ -f "$VM_DIR/$VM_NAME.conf" ]; then
            print_status ERROR "A VPS with this name already exists."
            continue
        fi

        break

    done

    # --------------------------------------------------------
    # Hostname
    # --------------------------------------------------------

    while true; do

        read -rp "$(echo -e "${CYAN}Hostname [$VM_NAME]: ${RESET}")" HOSTNAME

        HOSTNAME="${HOSTNAME:-$VM_NAME}"

        if validate_name "$HOSTNAME"; then
            break
        fi

    done

    # --------------------------------------------------------
    # Username
    # --------------------------------------------------------

    DEFAULT_USERNAME="${OS_USERNAME[$os_choice]}"

    read -rp \
        "$(echo -e "${CYAN}Username [$DEFAULT_USERNAME]: ${RESET}")" \
        USERNAME

    USERNAME="${USERNAME:-$DEFAULT_USERNAME}"

    # --------------------------------------------------------
    # Password
    # --------------------------------------------------------

    while true; do

        read -rsp \
            "$(echo -e "${CYAN}Root/SSH password: ${RESET}")" \
            PASSWORD

        echo

        if [ -n "$PASSWORD" ]; then
            break
        fi

        print_status ERROR "Password cannot be empty."

    done

    # --------------------------------------------------------
    # RAM
    # --------------------------------------------------------

    while true; do

        read -rp \
            "$(echo -e "${CYAN}RAM in MB [65536 = 64GB]: ${RESET}")" \
            MEMORY

        MEMORY="${MEMORY:-65536}"

        if validate_number "$MEMORY"; then
            break
        fi

    done

    # --------------------------------------------------------
    # CPU Count
    # --------------------------------------------------------

    while true; do

        read -rp \
            "$(echo -e "${CYAN}CPU cores [16]: ${RESET}")" \
            CPUS

        CPUS="${CPUS:-16}"

        if validate_number "$CPUS"; then
            break
        fi

    done

    # --------------------------------------------------------
    # CUSTOM CPU NAME
    # --------------------------------------------------------

    echo
    print_status INFO "Custom CPU branding"
    echo
    echo "Examples:"
    echo "  AMD Ryzen 9 9950X3D"
    echo "  AMD EPYC 9755"
    echo "  Intel Xeon Gold 6430"
    echo "  Intel Core i9-14900K"
    echo

    read -rp \
        "$(echo -e "${CYAN}CPU Name [NXR Virtual CPU]: ${RESET}")" \
        CPU_NAME

    CPU_NAME="${CPU_NAME:-NXR Virtual CPU}"

    # --------------------------------------------------------
    # Disk
    # --------------------------------------------------------

    while true; do

        read -rp \
            "$(echo -e "${CYAN}Disk size [100G]: ${RESET}")" \
            DISK_SIZE

        DISK_SIZE="${DISK_SIZE:-100G}"

        if validate_size "$DISK_SIZE"; then
            break
        fi

    done

    # --------------------------------------------------------
    # SSH Port
    # --------------------------------------------------------

    while true; do

        read -rp \
            "$(echo -e "${CYAN}SSH Port [2222]: ${RESET}")" \
            SSH_PORT

        SSH_PORT="${SSH_PORT:-2222}"

        if ! validate_port "$SSH_PORT"; then
            continue
        fi

        if ss -tln 2>/dev/null |
            grep -qE "[:.]$SSH_PORT[[:space:]]"; then

            print_status ERROR "Port $SSH_PORT is already in use."
            continue

        fi

        break

    done

    # --------------------------------------------------------
    # Files
    # --------------------------------------------------------

    IMG_FILE="$VM_DIR/$VM_NAME.qcow2"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"

    CREATED="$(date '+%Y-%m-%d %H:%M:%S')"

    # --------------------------------------------------------
    # Summary
    # --------------------------------------------------------

    echo
    echo "==========================================================="
    echo "                    VPS CONFIGURATION"
    echo "==========================================================="
    echo
    echo "VPS Name     : $VM_NAME"
    echo "OS           : $OS_TYPE"
    echo "Hostname     : $HOSTNAME"
    echo "Username     : $USERNAME"
    echo "RAM          : $MEMORY MB"
    echo "CPU Cores    : $CPUS"
    echo "CPU Name     : $CPU_NAME"
    echo "Disk         : $DISK_SIZE"
    echo "SSH Port     : $SSH_PORT"
    echo
    echo "==========================================================="
    echo

    read -rp \
        "$(echo -e "${CYAN}Create this VPS? [Y/n]: ${RESET}")" \
        confirm

    confirm="${confirm:-y}"

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then

        print_status WARN "VPS creation cancelled."
        return

    fi

    # --------------------------------------------------------
    # Create
    # --------------------------------------------------------

    setup_vm_image
    save_vm_config

    print_status SUCCESS "VPS '$VM_NAME' created successfully."

    echo
    print_status INFO "Start it from the main menu."
}

# ============================================================
# Check VM Running
# ============================================================

is_vm_running() {

    local vm="$1"

    if load_vm_config "$vm"; then

        if pgrep -f "qemu-system-x86_64.*${IMG_FILE}" >/dev/null 2>&1; then
            return 0
        fi

    fi

    return 1
}

# ============================================================
# Start VM
# ============================================================

start_vm() {

    local vm="$1"

    load_vm_config "$vm"

    if is_vm_running "$vm"; then

        print_status WARN "VPS '$vm' is already running."
        return

    fi

    if [ ! -f "$IMG_FILE" ]; then

        print_status ERROR "Disk image not found."
        return 1

    fi

    if [ ! -f "$SEED_FILE" ]; then

        print_status WARN "Cloud-init seed missing."
        create_cloud_init

    fi

    echo
    print_status INFO "Starting VPS: $VM_NAME"

    echo
    echo "==========================================================="
    echo "                    NXR TECHNOLOGIES"
    echo "==========================================================="
    echo "VPS Name     : $VM_NAME"
    echo "OS           : $OS_TYPE"
    echo "RAM          : $MEMORY MB"
    echo "CPU Cores    : $CPUS"
    echo "CPU Name     : $CPU_NAME"
    echo "SSH Port     : $SSH_PORT"
    echo "==========================================================="
    echo

    print_status INFO \
        "SSH: ssh -p $SSH_PORT $USERNAME@127.0.0.1"

    echo

    # --------------------------------------------------------
    # QEMU
    # --------------------------------------------------------

    qemu-system-x86_64 \
        -accel tcg \
        -cpu qemu64 \
        -m "$MEMORY" \
        -smp "$CPUS" \
        -smbios type=1,manufacturer="NXR Technologies",product="NXR Technologies VPS",version="1.0" \
        -smbios type=4,manufacturer="NXR Technologies",version="$CPU_NAME",part="$CPU_NAME" \
        -drive "file=$IMG_FILE,format=qcow2,if=virtio" \
        -drive "file=$SEED_FILE,format=raw,if=virtio" \
        -boot order=c \
        -device virtio-net-pci,netdev=n0 \
        -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22" \
        -device virtio-balloon-pci \
        -object rng-random,filename=/dev/urandom,id=rng0 \
        -device virtio-rng-pci,rng=rng0 \
        -nographic \
        -serial mon:stdio

    print_status INFO "VPS '$VM_NAME' stopped."
}

# ============================================================
# Stop VM
# ============================================================

stop_vm() {

    local vm="$1"

    load_vm_config "$vm"

    if ! is_vm_running "$vm"; then

        print_status INFO "VPS '$vm' is not running."
        return

    fi

    print_status INFO "Stopping VPS '$vm'..."

    pkill -f "qemu-system-x86_64.*${IMG_FILE}" || true

    sleep 2

    if is_vm_running "$vm"; then

        print_status WARN "Force stopping VPS..."

        pkill -9 -f "qemu-system-x86_64.*${IMG_FILE}" || true

    fi

    print_status SUCCESS "VPS '$vm' stopped."
}

# ============================================================
# Show VM Information
# ============================================================

show_vm_info() {

    local vm="$1"

    load_vm_config "$vm"

    local status="Stopped"

    if is_vm_running "$vm"; then
        status="Running"
    fi

    echo
    echo "==========================================================="
    echo "                    VPS INFORMATION"
    echo "==========================================================="
    echo
    echo "VPS Name     : $VM_NAME"
    echo "Status       : $status"
    echo "OS           : $OS_TYPE"
    echo "Hostname     : $HOSTNAME"
    echo "Username     : $USERNAME"
    echo "Password     : $PASSWORD"
    echo "RAM          : $MEMORY MB"
    echo "CPU Cores    : $CPUS"
    echo "CPU Name     : $CPU_NAME"
    echo "Disk         : $DISK_SIZE"
    echo "SSH Port     : $SSH_PORT"
    echo "SSH Command  : ssh -p $SSH_PORT $USERNAME@127.0.0.1"
    echo "Created      : $CREATED"
    echo
    echo "==========================================================="
}

# ============================================================
# Delete VM
# ============================================================

delete_vm() {

    local vm="$1"

    load_vm_config "$vm"

    echo
    print_status WARN \
        "This will permanently delete VPS '$VM_NAME'."

    read -rp \
        "$(echo -e "${CYAN}Type DELETE to confirm: ${RESET}")" \
        confirmation

    if [ "$confirmation" != "DELETE" ]; then

        print_status INFO "Deletion cancelled."
        return

    fi

    if is_vm_running "$vm"; then

        stop_vm "$vm"

    fi

    rm -f "$IMG_FILE"
    rm -f "$SEED_FILE"
    rm -f "$VM_DIR/$VM_NAME.conf"

    print_status SUCCESS "VPS '$VM_NAME' deleted."
}

# ============================================================
# Select VM
# ============================================================

select_vm() {

    mapfile -t VMS < <(get_vm_list)

    if [ "${#VMS[@]}" -eq 0 ]; then

        print_status WARN "No VPSs found."
        return 1

    fi

    echo

    for i in "${!VMS[@]}"; do

        local status="Stopped"

        if is_vm_running "${VMS[$i]}"; then
            status="Running"
        fi

        printf "  %2d) %-25s [%s]\n" \
            "$((i+1))" \
            "${VMS[$i]}" \
            "$status"

    done

    echo

    while true; do

        read -rp \
            "$(echo -e "${CYAN}Select VPS number: ${RESET}")" \
            number

        if [[ "$number" =~ ^[0-9]+$ ]] &&
           [ "$number" -ge 1 ] &&
           [ "$number" -le "${#VMS[@]}" ]; then

            SELECTED_VM="${VMS[$((number-1))]}"
            return 0

        fi

        print_status ERROR "Invalid selection."

    done
}

# ============================================================
# Main Menu
# ============================================================

main_menu() {

    while true; do

        display_header

        mapfile -t VMS < <(get_vm_list)

        echo "NXR VPS STATUS"
        echo "-----------------------------------------------------------"

        if [ "${#VMS[@]}" -eq 0 ]; then

            echo "  No VPSs created."

        else

            for i in "${!VMS[@]}"; do

                local status="STOPPED"

                if is_vm_running "${VMS[$i]}"; then
                    status="RUNNING"
                fi

                printf "  %2d) %-25s %s\n" \
                    "$((i+1))" \
                    "${VMS[$i]}" \
                    "$status"

            done

        fi

        echo
        echo "==========================================================="
        echo "                         MAIN MENU"
        echo "==========================================================="
        echo
        echo "  1) Create VPS"
        echo "  2) Start VPS"
        echo "  3) Stop VPS"
        echo "  4) VPS Information"
        echo "  5) Delete VPS"
        echo "  0) Exit"
        echo
        echo "==========================================================="

        read -rp \
            "$(echo -e "${CYAN}Select option: ${RESET}")" \
            choice

        case "$choice" in

            1)
                create_new_vm
                read -rp "Press Enter to continue..."
                ;;

            2)
                if select_vm; then
                    start_vm "$SELECTED_VM"
                fi
                ;;

            3)
                if select_vm; then
                    stop_vm "$SELECTED_VM"
                fi
                read -rp "Press Enter to continue..."
                ;;

            4)
                if select_vm; then
                    show_vm_info "$SELECTED_VM"
                fi
                read -rp "Press Enter to continue..."
                ;;

            5)
                if select_vm; then
                    delete_vm "$SELECTED_VM"
                fi
                read -rp "Press Enter to continue..."
                ;;

            0)
                echo
                print_status SUCCESS "Goodbye from NXR Technologies."
                exit 0
                ;;

            *)
                print_status ERROR "Invalid option."
                sleep 1
                ;;

        esac

    done
}

# ============================================================
# Initialize
# ============================================================

mkdir -p "$VM_DIR"

check_dependencies

main_menu
