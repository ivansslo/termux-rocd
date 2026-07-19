#!/data/data/com.termux/files/usr/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  termux-rocd — Reset Termux, Install Zsh Theme & Provision Container + Zsh
# ═════════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
CYN='\033[0;36m'
BOLD='\033[1m'
RST='\033[0m'

echo -e "${CYN}=====================================================${RST}"
echo -e "${BOLD}${GRN}     ⚡ Termux Reset, Zsh & udocker Container Engine  ${RST}"
echo -e "${CYN}=====================================================${RST}"
echo ""

# 0. Ensure valid resolv.conf exists on Termux host (handling broken symlinks)
RESOLV_CONF="${PREFIX:-/data/data/com.termux/files/usr}/etc/resolv.conf"
rm -f "$RESOLV_CONF" 2>/dev/null || true
mkdir -p "$(dirname "$RESOLV_CONF")"
printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > "$RESOLV_CONF" 2>/dev/null || {
  ETC_DIR="${PREFIX:-/data/data/com.termux/files/usr}/etc"
  rm -rf "$ETC_DIR" 2>/dev/null || true
  mkdir -p "$ETC_DIR"
  printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > "$ETC_DIR/resolv.conf"
}

# 1. Reset & Purge Termux Caches / Broken Environment
echo -e "${YLW}🧹 Step 1: Cleaning Termux caches & temporary files...${RST}"
python3 -m pip cache purge 2>/dev/null || true
pkg clean -y 2>/dev/null || true
rm -rf ~/.cache ~/.tmp /data/data/com.termux/files/usr/tmp/* 2>/dev/null || true
echo -e "${GRN}✅ Caches cleared.${RST}\n"

# 2. Update Termux System Packages & Install Base Tools + Zsh
echo -e "${YLW}📦 Step 2: Updating packages & installing Host Zsh + container tools...${RST}"
pkg update -y && pkg upgrade -y
pkg install -y zsh wget python clang make pkg-config libffi openssl curl git jq proot tar unzip openssh

# 3. Download and Apply Custom Zsh Environment on Host Termux
echo -e "${YLW}🎨 Step 3: Installing Termux-Zsh custom shell dotfiles on host...${RST}"
cd "$HOME"
rm -f zsh.tar.xz 2>/dev/null || true
if wget -q -O zsh.tar.xz "https://github.com/ivansslo/Termux-Zsh/raw/main/zsh.tar.xz" || wget -q -O zsh.tar.xz "https://github.com/atamshkai/Termux-Zsh/raw/main/zsh.tar.xz"; then
  tar -xvJf zsh.tar.xz 2>/dev/null || tar -xvf zsh.tar.xz 2>/dev/null || true
  if [ -d "$HOME/zsh" ]; then
    cp -rn "$HOME/zsh/".* "$HOME/" 2>/dev/null || true
    rm -rf "$HOME/zsh" "$HOME/zsh.tar.xz"
  fi
  echo -e "${GRN}✅ Zsh configuration & theme applied to host Termux!${RST}"
else
  echo -e "${YLW}⚠️ Could not fetch zsh.tar.xz, using standard Zsh config.${RST}"
fi

# Set default host shell to zsh if available
if command -v zsh &>/dev/null; then
  chsh -s zsh 2>/dev/null || true
fi

# 4. Install udocker Engine
echo -e "${YLW}🐳 Step 4: Installing udocker engine via pip...${RST}"
python3 -m pip install --upgrade pip setuptools wheel --quiet 2>/dev/null || true
python3 -m pip install udocker

echo -e "${YLW}⚙️ Step 5: Initializing udocker engine binaries...${RST}"
udocker install

# 5. Provision Default Ubuntu Container (roc-container)
echo -e "${YLW}📦 Step 6: Pulling base container image (Ubuntu 22.04 LTS)...${RST}"
udocker pull ubuntu:22.04

echo -e "${YLW}🚀 Step 7: Creating container instance 'roc-container'...${RST}"
udocker rm -f roc-container 2>/dev/null || true
udocker create --name=roc-container ubuntu:22.04

# 6. Configure PRoot/Fakechroot Execution Mode for Android ARM64
echo -e "${YLW}🔧 Step 8: Configuring Android ARM64 execution mode (F8 / P1 PRoot)...${RST}"
udocker setup --execmode=F8 roc-container 2>/dev/null || udocker setup --execmode=P1 roc-container 2>/dev/null || true

# 7. Provision Zsh & Termux-Zsh Dotfiles inside the Container (root@localhost)
echo -e "${YLW}🐚 Step 9: Installing Zsh & dotfiles inside container (root@localhost)...${RST}"
udocker run --user=root roc-container /bin/bash -c "
  set -e
  apt-get update -y
  apt-get install -y zsh wget curl git tar
  cd /root
  wget -q -O zsh.tar.xz https://github.com/ivansslo/Termux-Zsh/raw/main/zsh.tar.xz || wget -q -O zsh.tar.xz https://github.com/atamshkai/Termux-Zsh/raw/main/zsh.tar.xz || true
  if [ -f zsh.tar.xz ]; then
    tar -xvJf zsh.tar.xz 2>/dev/null || tar -xvf zsh.tar.xz 2>/dev/null || true
    if [ -d /root/zsh ]; then
      cp -rn /root/zsh/.* /root/ 2>/dev/null || true
      rm -rf /root/zsh /root/zsh.tar.xz
    fi
  fi
  chsh -s /usr/bin/zsh root 2>/dev/null || true
" 2>/dev/null || echo -e "${YLW}⚠️ Zsh container setup finished with minor warnings.${RST}"

# 8. Create Shortcut Launcher 'rocd' with Zsh as default container shell
echo -e "${YLW}🔗 Step 10: Creating global launcher shortcut 'rocd'...${RST}"
BIN_DIR="${PREFIX:-$HOME/.local}/bin"
mkdir -p "$BIN_DIR"

cat << 'EOF' > "$BIN_DIR/rocd"
#!/data/data/com.termux/files/usr/bin/bash
# Shortcut launcher for udocker roc-container with Zsh & Bash support

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
  udocker create --name=roc-container ubuntu:22.04
  udocker setup --execmode=F8 roc-container 2>/dev/null || udocker setup --execmode=P1 roc-container 2>/dev/null || true
  echo "✅ Container roc-container reset to fresh state."
  exit 0
fi

if [ "$1" = "mode" ]; then
  mode="${2:-P1}"
  echo "⚙️ Setting execution mode to $mode..."
  udocker setup --execmode="$mode" roc-container
  echo "✅ Mode updated to $mode."
  exit 0
fi

if [ $# -gt 0 ]; then
  exec udocker run --user=root roc-container "$@"
else
  echo "🚀 Entering udocker Termux Container (Ubuntu 22.04 with Zsh)..."
  exec udocker run --user=root roc-container /usr/bin/zsh 2>/dev/null || exec udocker run --user=root roc-container /bin/zsh 2>/dev/null || exec udocker run --user=root roc-container /bin/bash
fi
EOF

chmod +x "$BIN_DIR/rocd"

echo ""
echo -e "${GRN}=====================================================${RST}"
echo -e "${BOLD}${GRN}🎉 Termux Reset, Host Zsh & Container Zsh Setup Complete!${RST}"
echo -e "${GRN}=====================================================${RST}"
echo -e "  • Host Shell:      ${CYN}Zsh with custom dotfiles theme${RST}"
echo -e "  • Container Shell: ${CYN}Zsh (root@localhost in roc-container)${RST}"
echo -e "  • Shortcut Command:${BOLD}${GRN} rocd ${RST}"
echo ""
echo -e "${CYN}💡 How to use your container:${RST}"
echo -e "  1. Enter container shell:   ${BOLD}rocd${RST}"
echo -e "  2. Run command inside:      ${BOLD}rocd apt-get update${RST}"
echo -e "  3. Reset container state:   ${BOLD}rocd reset${RST}"
echo ""
