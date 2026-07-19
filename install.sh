#!/data/data/com.termux/files/usr/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  termux-rocd — Termux Reset & Auto-Healing udocker Container Launcher
# ═════════════════════════════════════════════════════════════════════════════

set -e

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export DPKG_OPTIONS="--force-confold --force-confdef"
export PROOT_NO_SECCOMP=1
export PROOT_FORCE_READLINK=1

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
CYN='\033[0;36m'
BOLD='\033[1m'
RST='\033[0m'

echo -e "${CYN}=====================================================${RST}"
echo -e "${BOLD}${GRN}     ⚡ Termux Reset & Auto-Healing rocd Provisioner  ${RST}"
echo -e "${CYN}=====================================================${RST}"
echo ""

# Fix any interrupted dpkg locks/prompts on Termux host
dpkg --configure -a --force-confold --force-confdef 2>/dev/null || true

# 0. Ensure valid resolv.conf exists on Termux host
RESOLV_CONF="${PREFIX:-/data/data/com.termux/files/usr}/etc/resolv.conf"
rm -f "$RESOLV_CONF" 2>/dev/null || true
mkdir -p "$(dirname "$RESOLV_CONF")"
printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > "$RESOLV_CONF" 2>/dev/null || {
  ETC_DIR="${PREFIX:-/data/data/com.termux/files/usr}/etc"
  rm -rf "$ETC_DIR" 2>/dev/null || true
  mkdir -p "$ETC_DIR"
  printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > "$ETC_DIR/resolv.conf"
}

# 1. Reset & Purge Termux Host Caches
echo -e "${YLW}🧹 Step 1: Cleaning Termux host caches...${RST}"
python3 -m pip cache purge 2>/dev/null || true
pkg clean -y 2>/dev/null || true
rm -rf ~/.cache ~/.tmp /data/data/com.termux/files/usr/tmp/* 2>/dev/null || true
echo -e "${GRN}✅ Caches cleared.${RST}\n"

# 2. Revert Host Shell to Bash (Remove Zsh on Host)
echo -e "${YLW}🐚 Step 2: Setting default host shell to Bash...${RST}"
if command -v chsh &>/dev/null; then
  chsh -s bash 2>/dev/null || true
fi

# 3. Update Termux System Packages
echo -e "${YLW}📦 Step 3: Updating host system packages non-interactively...${RST}"
pkg update -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" 2>/dev/null || apt-get update -y
pkg upgrade -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" 2>/dev/null || true
pkg install -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" wget python clang make pkg-config libffi openssl curl git jq proot tar unzip openssh

# 4. Install udocker Engine
echo -e "${YLW}🐳 Step 4: Installing udocker engine via pip...${RST}"
python3 -m pip install --upgrade pip setuptools wheel --quiet 2>/dev/null || true
python3 -m pip install udocker

echo -e "${YLW}⚙️ Step 5: Initializing udocker engine binaries...${RST}"
udocker install

# 5. Provision Default Ubuntu Container (roc-container linux/arm64)
echo -e "${YLW}📦 Step 6: Pulling base container image (linux/arm64 platform)...${RST}"
udocker pull --platform=linux/arm64 ubuntu:22.04 2>/dev/null || \
udocker pull arm64v8/ubuntu:22.04 2>/dev/null || \
udocker pull ubuntu:22.04 2>/dev/null || \
udocker pull --platform=linux/arm64 debian:bookworm 2>/dev/null || true

echo -e "${YLW}🚀 Step 7: Creating container instance 'roc-container'...${RST}"
udocker rm -f roc-container 2>/dev/null || true
udocker create --name=roc-container ubuntu:22.04 2>/dev/null || \
udocker create --name=roc-container arm64v8/ubuntu:22.04 2>/dev/null || \
udocker create --name=roc-container debian:bookworm 2>/dev/null || \
udocker create --name=roc-container arm64v8/debian:bookworm

# 6. Configure PRoot Execution Mode for Android ARM64
echo -e "${YLW}🔧 Step 8: Configuring Android ARM64 execution mode (F8 PRoot)...${RST}"
udocker setup --execmode=F8 roc-container 2>/dev/null || udocker setup --execmode=P1 roc-container 2>/dev/null || true

# 7. Create Auto-Healing Global Launcher 'rocd'
echo -e "${YLW}🔗 Step 9: Creating global launcher shortcut 'rocd'...${RST}"
BIN_DIR="${PREFIX:-$HOME/.local}/bin"
mkdir -p "$BIN_DIR"

cat << 'EOF' > "$BIN_DIR/rocd"
#!/data/data/com.termux/files/usr/bin/bash
# Shortcut launcher for udocker roc-container with auto-repair and failover

export PROOT_NO_SECCOMP=1
export PROOT_FORCE_READLINK=1

# Ensure host DNS resolv.conf exists before mounting
RESOLV="${PREFIX:-/data/data/com.termux/files/usr}/etc/resolv.conf"
if [ ! -f "$RESOLV" ] || [ ! -s "$RESOLV" ]; then
  rm -f "$RESOLV" 2>/dev/null || true
  mkdir -p "$(dirname "$RESOLV")"
  printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > "$RESOLV" 2>/dev/null || true
fi

if [ "$1" = "reset" ]; then
  echo "🧹 Resetting udocker containers..."
  udocker rm -f roc-container 2>/dev/null || true
  udocker pull --platform=linux/arm64 ubuntu:22.04 2>/dev/null || udocker pull arm64v8/ubuntu:22.04 2>/dev/null || true
  udocker create --name=roc-container ubuntu:22.04 2>/dev/null || udocker create --name=roc-container arm64v8/ubuntu:22.04 2>/dev/null || udocker create --name=roc-container debian:bookworm
  udocker setup --execmode=F8 roc-container 2>/dev/null || udocker setup --execmode=P1 roc-container 2>/dev/null || true
  echo "✅ Container roc-container reset to fresh state."
  exit 0
fi

if [ "$1" = "mode" ]; then
  mode="${2:-F8}"
  echo "⚙️ Setting execution mode to $mode..."
  udocker setup --execmode="$mode" roc-container
  echo "✅ Mode updated to $mode."
  exit 0
fi

# Multi-mode Execution Function with Auto-healing
run_container() {
  local target_cmd="${1:-/bin/bash}"
  shift || true
  
  if udocker run --user=root -w /root roc-container "$target_cmd" "$@"; then
    return 0
  fi
  
  echo "⚠️ Mode P1/Default exited with error. Auto-repairing mode to F8 (Fakechroot)..."
  udocker setup --execmode=F8 roc-container 2>/dev/null || true
  if udocker run --user=root -w /root roc-container "$target_cmd" "$@"; then
    return 0
  fi

  echo "⚠️ Mode F8 failed. Trying mode R1..."
  udocker setup --execmode=R1 roc-container 2>/dev/null || true
  if udocker run --user=root -w /root roc-container "$target_cmd" "$@"; then
    return 0
  fi

  echo "⚠️ Trying fallback mode P2..."
  udocker setup --execmode=P2 roc-container 2>/dev/null || true
  udocker run --user=root -w /root roc-container "$target_cmd" "$@"
}

if [ $# -gt 0 ]; then
  run_container "$@"
else
  echo "🚀 Entering udocker Termux Container (root@localhost Ubuntu 22.04)..."
  run_container /bin/bash
fi
EOF

chmod +x "$BIN_DIR/rocd"

# 8. Configure Termux ~/.bashrc Safely (Without force closing on exit)
echo -e "${YLW}⚙️ Step 10: Configuring Termux ~/.bashrc to auto-start rocd safely...${RST}"
touch "$HOME/.bashrc"
sed -i '/zsh/d' "$HOME/.bashrc" 2>/dev/null || true
sed -i '/rocd/d' "$HOME/.bashrc" 2>/dev/null || true

cat << 'EOF' >> "$HOME/.bashrc"

# Safe auto-launch rocd container on Termux startup
if [ -t 0 ] && [ -x "$PREFIX/bin/rocd" ] && [ -z "$ROCD_ACTIVE" ]; then
  export ROCD_ACTIVE=1
  rocd || echo "⚠️ Container exited. Retaining Termux host session."
fi
EOF

echo ""
echo -e "${GRN}=====================================================${RST}"
echo -e "${BOLD}${GRN}🎉 Auto-Healing rocd Container Setup Complete!${RST}"
echo -e "${GRN}=====================================================${RST}"
echo -e "  • Safe Auto-Start:  ${CYN}rocd starts automatically without process exit lock${RST}"
echo -e "  • Auto-Repair Modes:${CYN}Automatic failover across F8, P1, R1, P2 execution modes${RST}"
echo -e "  • Shortcut Command: ${BOLD}${GRN} rocd ${RST}"
echo ""
