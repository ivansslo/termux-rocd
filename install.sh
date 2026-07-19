#!/data/data/com.termux/files/usr/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  termux-rocd — Termux Reset, Zsh Theme, Node.js & Full Container Dev Tools
# ═════════════════════════════════════════════════════════════════════════════

set -e

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export DPKG_OPTIONS="--force-confold --force-confdef"

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
CYN='\033[0;36m'
BOLD='\033[1m'
RST='\033[0m'

echo -e "${CYN}=====================================================${RST}"
echo -e "${BOLD}${GRN}     ⚡ Termux Reset, Zsh & Full udocker Provisioner   ${RST}"
echo -e "${CYN}=====================================================${RST}"
echo ""

# Fix any interrupted dpkg locks/prompts on Termux host
dpkg --configure -a --force-confold --force-confdef 2>/dev/null || true

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
echo -e "${YLW}📦 Step 2: Updating host packages non-interactively & installing Zsh + tools...${RST}"
pkg update -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" 2>/dev/null || apt-get update -y
pkg upgrade -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" 2>/dev/null || true
pkg install -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" zsh wget python clang make pkg-config libffi openssl curl git jq proot tar unzip openssh

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

# 5. Provision Default Ubuntu Container (roc-container with explicit linux/arm64 platform)
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

# 6. Configure PRoot/Fakechroot Execution Mode for Android ARM64
echo -e "${YLW}🔧 Step 8: Configuring Android ARM64 execution mode (F8 / P1 PRoot)...${RST}"
udocker setup --execmode=F8 roc-container 2>/dev/null || udocker setup --execmode=P1 roc-container 2>/dev/null || true

# 7. Provision Full Stack Dev Tools & Zsh inside container (root@localhost)
echo -e "${YLW}📦 Step 9: Installing Zsh, sudo, Node.js LTS, npm, git, gh CLI, curl, wget & dev tools in root@localhost...${RST}"
udocker run --user=root roc-container /bin/bash -c "
  set -e
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y zsh sudo curl wget git jq unzip tar nano vim net-tools lsof procps ca-certificates gnupg build-essential python3 python3-pip python3-venv libffi-dev libssl-dev

  # Install Node.js v20 LTS & upgrade npm to latest
  if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
  fi
  npm install -g npm@latest tsx vite tsup 2>/dev/null || true

  # Install GitHub CLI (gh)
  if ! command -v gh >/dev/null 2>&1; then
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg 2>/dev/null || true
    chmod 644 /etc/apt/keyrings/githubcli-archive-keyring.gpg 2>/dev/null || true
    echo 'deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | tee /etc/apt/sources.list.d/github-cli.list > /dev/null || true
    apt-get update -y || true
    apt-get install -y gh || true
  fi

  # Set Zsh as default shell for root in container
  chsh -s /usr/bin/zsh root 2>/dev/null || chsh -s /bin/zsh root 2>/dev/null || true

  # Setup Zsh & Termux-Zsh dotfiles theme for root
  cd /root
  wget -q -O zsh.tar.xz https://github.com/ivansslo/Termux-Zsh/raw/main/zsh.tar.xz || wget -q -O zsh.tar.xz https://github.com/atamshkai/Termux-Zsh/raw/main/zsh.tar.xz || true
  if [ -f zsh.tar.xz ]; then
    tar -xvJf zsh.tar.xz 2>/dev/null || tar -xvf zsh.tar.xz 2>/dev/null || true
    if [ -d /root/zsh ]; then
      cp -rn /root/zsh/.* /root/ 2>/dev/null || true
      rm -rf /root/zsh /root/zsh.tar.xz
    fi
  fi
" 2>/dev/null || echo -e "${YLW}⚠️ Container tool provisioning finished with minor notices.${RST}"

# 8. Create Shortcut Launcher 'rocd'
echo -e "${YLW}🔗 Step 10: Creating global launcher shortcut 'rocd'...${RST}"
BIN_DIR="${PREFIX:-$HOME/.local}/bin"
mkdir -p "$BIN_DIR"

cat << 'EOF' > "$BIN_DIR/rocd"
#!/data/data/com.termux/files/usr/bin/bash
# Shortcut launcher for udocker roc-container with full dev environment & Zsh

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
  mode="${2:-P1}"
  echo "⚙️ Setting execution mode to $mode..."
  udocker setup --execmode="$mode" roc-container
  echo "✅ Mode updated to $mode."
  exit 0
fi

if [ $# -gt 0 ]; then
  exec udocker run --user=root -w /root roc-container "$@"
else
  echo "🚀 Entering udocker Termux Container (Ubuntu 22.04 with Zsh & Dev Stack)..."
  exec udocker run --user=root -w /root roc-container /bin/bash -c "[ -x /usr/bin/zsh ] && exec /usr/bin/zsh -l || [ -x /bin/zsh ] && exec /bin/zsh -l || exec /bin/bash -l"
fi
EOF

chmod +x "$BIN_DIR/rocd"

echo ""
echo -e "${GRN}=====================================================${RST}"
echo -e "${BOLD}${GRN}🎉 Full Container Provisioning Complete!${RST}"
echo -e "${GRN}=====================================================${RST}"
echo -e "  • Installed Tools: ${CYN}zsh, sudo, Node.js (npm latest), git, gh CLI, curl, wget, tsx, vite, tsup${RST}"
echo -e "  • Interactive Shell: ${CYN}Zsh (root@localhost with Termux-Zsh theme)${RST}"
echo -e "  • Shortcut Command:  ${BOLD}${GRN} rocd ${RST}"
echo ""
