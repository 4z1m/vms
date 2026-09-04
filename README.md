# ⚡ NXR Technologies KVM VPS Manager

<p align="center">
  <img src="https://img.shields.io/badge/NXR-Technologies-5865F2?style=for-the-badge" alt="NXR Technologies">
  <img src="https://img.shields.io/badge/KVM-Virtualization-success?style=for-the-badge" alt="KVM">
  <img src="https://img.shields.io/badge/QEMU-Powered-orange?style=for-the-badge" alt="QEMU">
  <img src="https://img.shields.io/badge/Linux-Supported-blue?style=for-the-badge&logo=linux" alt="Linux">
</p>

<p align="center">
  <b>⚡ Fast • 🖥️ KVM • 🛠️ Simple • 🚀 Lightweight</b>
</p>

A lightweight **KVM VPS Manager** built with **Bash + QEMU** for creating and managing virtual machines directly from the terminal.

## 🚀 Install

Run this command on your Linux server:

```bash
bash <(curl -s https://raw.githubusercontent.com/4z1m/vms/main/nokvm.sh)
```

## ✨ Features

* ⚡ KVM hardware virtualization
* 🖥️ QEMU powered
* 🧠 Custom CPU cores
* 🏷️ Custom CPU name
* 💾 Custom RAM
* 💿 Custom disk size
* 🐧 Multiple Linux operating systems
* 🌐 Custom SSH port
* 🔐 Custom username & password
* 🏷️ Custom VPS name
* 🖥️ Custom hostname
* ▶️ Start VPS
* ⏹️ Stop VPS
* 🔄 Restart VPS
* 🗑️ Delete VPS
* ℹ️ VPS information
* 🎨 Interactive terminal interface

## 🖥️ Supported OS

* Ubuntu 22.04
* Ubuntu 24.04
* Debian 12
* Debian 13
* AlmaLinux 9
* Rocky Linux 9

## ⚡ KVM

The manager uses QEMU with KVM acceleration:

```bash
-accel kvm
-cpu host
```

Check if KVM is available:

```bash
ls -l /dev/kvm
```

Test access:

```bash
test -r /dev/kvm && test -w /dev/kvm && echo "KVM AVAILABLE" || echo "KVM NOT AVAILABLE"
```

## 🧠 Custom CPU Name

You can choose a custom CPU name when creating a VPS.

Example:

```text
AMD EPYC 9755
AMD Ryzen 9 9950X3D
Intel Xeon Gold 6430
Intel Core i9-14900K
```

> **Note:** The custom CPU name is branding/metadata. It does not physically change the host CPU.

## 💻 Example

```text
VPS Name    : nxr-vps
OS          : Ubuntu 24.04
RAM         : 16 GB
CPU Cores   : 8
CPU Name    : AMD EPYC 9755
Disk        : 100 GB
SSH Port    : 2222
Virtualization: KVM
```

Connect to the VPS:

```bash
ssh root@SERVER_IP -p 2222
```

## ⚠️ Requirements

Your server must support **KVM virtualization**.

Check:

```bash
ls -l /dev/kvm
```

QEMU is also required:

```bash
qemu-system-x86_64 --version
```

If `/dev/kvm` is missing or inaccessible, your VPS provider may have disabled **KVM/nested virtualization**.

## 🔒 Security

For production use:

* Use strong passwords
* Prefer SSH keys
* Configure a firewall
* Avoid exposing unnecessary ports
* Keep the host updated
* Protect VPS configuration files

## 🏢 NXR Technologies

**Build. Virtualize. Deploy.** ⚡

Made with ❤️ by **NXR Technologies**.

⭐ If you find this project useful, consider starring the repository.
