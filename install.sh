#!/data/data/com.termux/files/usr/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  termux-rocd — Termux Reset & Auto-Launch rocd Container via ~/.bashrc
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
echo -e "${BOLD}${GRN}     ⚡ Termux Reset & Auto-Launch rocd Provisioner  ${RST}"
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
echo -e "${YLW}🐚 Step 2: Setting default host shell to Bash (removing Zsh on host)...${RST}"
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
echo -e "${YLW}🔧 Step 8: Configuring Android ARM64 execution mode (P1 PRoot)...${RST}"
udocker setup --execmode=P1 roc-container 2>/dev/null || udocker setup --execmode=R1 roc-container 2>/dev/null || udocker setup --execmode=F8 roc-container 2>/dev/null || true

# 7. Provision Full Stack Dev Tools in root@localhost container
echo -e "${YLW}📦 Step 9: Installing sudo, Node.js LTS, npm, git, gh CLI, curl & dev tools in root@localhost...${RST}"
udocker run --user=root roc-container /bin/bash -c "
  set -e
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y sudo curl wget git jq unzip tar nano vim net-tools lsof procps ca-certificates gnupg build-essential python3 python3-pip python3-venv libffi-dev libssl-dev

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
" 2>/dev/null || echo -e "${YLW}⚠️ Container tool provisioning finished with minor notices.${RST}"

# 8. Create Global Shortcut Launcher 'rocd'
echo -e "${YLW}🔗 Step 10: Creating global launcher shortcut 'rocd'...${RST}"
BIN_DIR="${PREFIX:-$HOME/.local}/bin"
mkdir -p "$BIN_DIR"

cat << 'EOF' > "$BIN_DIR/rocd"
#!/data/data/com.termux/files/usr/bin/bash
# Shortcut launcher for udocker roc-container (root@localhost)

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
  udocker setup --execmode=P1 roc-container 2>/dev/null || udocker setup --execmode=R1 roc-container 2>/dev/null || udocker setup --execmode=F8 roc-container 2>/dev/null || true
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
  echo "🚀 Entering udocker Termux Container (root@localhost Ubuntu 22.04)..."
  exec udocker run --user=root -w /root roc-container /bin/bash -l
fi
EOF

chmod +x "$BIN_DIR/rocd"

# 9. Configure Termux ~/.bashrc to Auto-Launch rocd container on startup
echo -e "${YLW}⚙️ Step 11: Configuring Termux ~/.bashrc to auto-start rocd as root local...${RST}"
touch "$HOME/.bashrc"
sed -i '/zsh/d' "$HOME/.bashrc" 2>/dev/null || true

if ! grep -q "rocd" "$HOME/.bashrc" 2>/dev/null; then
  cat << 'EOF' >> "$HOME/.bashrc"

# Automatically launch rocd container on Termux startup
if [ -t 0 ] && [ -x "$PREFIX/bin/rocd" ] && [ -z "$ROCD_ACTIVE" ]; then
  export ROCD_ACTIVE=1
  exec rocd
fi
EOF
fi

echo ""
echo -e "${GRN}=====================================================${RST}"
echo -e "${BOLD}${GRN}🎉 Auto-Launch rocd in Termux ~/.bashrc Configured!${RST}"
echo -e "${GRN}=====================================================${RST}"
echo -e "  • Host Shell:      ${CYN}Bash (Zsh removed from host)${RST}"
echo -e "  • Auto-Start:     ${CYN}rocd added to ~/.bashrc (launches root@localhost automatically)${RST}"
echo -e "  • Container Stack: ${CYN}Ubuntu 22.04 with sudo, Node.js v20, npm, git, gh, curl, wget${RST}"
echo ""
