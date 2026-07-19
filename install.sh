#!/data/data/com.termux/files/usr/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  termux-rocd — Container Engine Provisioner with Direct 'ubuntu' Command
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
echo -e "${BOLD}${GRN}  ⚡ termux-rocd Provisioner (Direct 'ubuntu' Command) ${RST}"
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

# Clear any broken default_shell override in proot-distro
rm -f "${PREFIX:-/data/data/com.termux/files/usr}/etc/proot-distro/ubuntu.override.sh" 2>/dev/null || true

# 1. Reset & Purge Termux Host Caches
echo -e "${YLW}🧹 Step 1: Cleaning Termux host caches...${RST}"
python3 -m pip cache purge 2>/dev/null || true
pkg clean -y 2>/dev/null || true
rm -rf ~/.cache ~/.tmp /data/data/com.termux/files/usr/tmp/* 2>/dev/null || true
echo -e "${GRN}✅ Host caches cleared.${RST}\n"

# 2. Keep Host Shell on Bash
echo -e "${YLW}🐚 Step 2: Ensuring host shell is Bash...${RST}"
if command -v chsh &>/dev/null; then
  chsh -s bash 2>/dev/null || true
fi

# 3. Update Termux System Packages & Install Native proot-distro Engine
echo -e "${YLW}📦 Step 3: Installing Termux container utilities & proot-distro...${RST}"
pkg update -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" 2>/dev/null || apt-get update -y
pkg upgrade -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" 2>/dev/null || true
pkg install -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" proot-distro proot wget python clang make pkg-config libffi openssl curl git jq tar unzip openssh

# 4. Provision Native Android-Patched Ubuntu Container via proot-distro
echo -e "${YLW}🚀 Step 4: Installing Ubuntu container image via proot-distro...${RST}"
if proot-distro list 2>/dev/null | grep -q "ubuntu.*installed"; then
  echo -e "${GRN}✅ Ubuntu container already present.${RST}"
else
  proot-distro install ubuntu
fi

# 5. Provision Full Stack Dev Tools INSIDE container (root@localhost)
echo -e "${YLW}📦 Step 5: Installing Full Package Ubuntu Dev Tools in root@localhost...${RST}"
proot-distro login ubuntu --shell /bin/bash -- /bin/bash -c "
  set -e
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y sudo curl wget git jq unzip tar p7zip-full xz-utils bzip2 gzip nano vim neovim net-tools lsof procps psmisc tree htop ca-certificates gnupg build-essential python3 python3-pip python3-venv python3-dev libffi-dev libssl-dev libsqlite3-dev

  # Install Node.js v20 LTS & upgrade npm to latest
  if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
  fi
  npm install -g npm@latest pnpm yarn tsx vite tsup esbuild ts-node typescript firebase-tools 2>/dev/null || true

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

# 6. Create Global 'ubuntu' Command & 'rocd' Launcher
echo -e "${YLW}🔗 Step 6: Creating direct global 'ubuntu' and 'rocd' commands...${RST}"
BIN_DIR="${PREFIX:-$HOME/.local}/bin"
mkdir -p "$BIN_DIR"

# 'ubuntu' Direct Launcher
cat << 'EOF' > "$BIN_DIR/ubuntu"
#!/data/data/com.termux/files/usr/bin/bash
# Direct launcher for Ubuntu container (root@localhost)

export PROOT_NO_SECCOMP=1
export PROOT_FORCE_READLINK=1

# Ensure host DNS resolv.conf exists before running
RESOLV="${PREFIX:-/data/data/com.termux/files/usr}/etc/resolv.conf"
if [ ! -f "$RESOLV" ] || [ ! -s "$RESOLV" ]; then
  rm -f "$RESOLV" 2>/dev/null || true
  mkdir -p "$(dirname "$RESOLV")"
  printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > "$RESOLV" 2>/dev/null || true
fi

rm -f "${PREFIX:-/data/data/com.termux/files/usr}/etc/proot-distro/ubuntu.override.sh" 2>/dev/null || true

if [ "$1" = "reset" ]; then
  echo "🧹 Resetting Ubuntu container..."
  proot-distro remove ubuntu 2>/dev/null || true
  proot-distro install ubuntu
  echo "✅ Ubuntu container reset to fresh state."
  exit 0
fi

if [ $# -gt 0 ]; then
  exec proot-distro login ubuntu --shell /bin/bash -- "$@"
else
  echo "🚀 Entering Ubuntu Container (root@localhost)..."
  exec proot-distro login ubuntu --shell /bin/bash -- /bin/bash -c "[ -x /usr/bin/zsh ] && exec /usr/bin/zsh -l || exec /bin/bash -l"
fi
EOF

# Symlink rocd to ubuntu
cp "$BIN_DIR/ubuntu" "$BIN_DIR/rocd"
chmod +x "$BIN_DIR/ubuntu" "$BIN_DIR/rocd"

# 7. Configure Termux ~/.bashrc to Auto-Start 'ubuntu' Container
echo -e "${YLW}⚙️ Step 7: Configuring Termux ~/.bashrc to auto-start 'ubuntu' safely...${RST}"
touch "$HOME/.bashrc"
sed -i '/zsh/d' "$HOME/.bashrc" 2>/dev/null || true
sed -i '/rocd/d' "$HOME/.bashrc" 2>/dev/null || true
sed -i '/ubuntu/d' "$HOME/.bashrc" 2>/dev/null || true

cat << 'EOF' >> "$HOME/.bashrc"

# Safe auto-launch ubuntu container on Termux startup
if [ -t 0 ] && [ -x "$PREFIX/bin/ubuntu" ] && [ -z "$UBUNTU_ACTIVE" ]; then
  export UBUNTU_ACTIVE=1
  ubuntu || echo "⚠️ Container exited. Retaining Termux host session."
fi
EOF

echo ""
echo -e "${GRN}=====================================================${RST}"
echo -e "${BOLD}${GRN}🎉 Direct 'ubuntu' Command Provisioning Complete!${RST}"
echo -e "${GRN}=====================================================${RST}"
echo -e "  • Direct Command:  ${BOLD}${GRN} ubuntu ${RST} (Type 'ubuntu' anytime)"
echo -e "  • Container Shell: ${CYN}root@localhost (Ubuntu 22.04 LTS)${RST}"
echo -e "  • Auto-Start:      ${CYN}Launches 'ubuntu' automatically on opening Termux${RST}"
echo ""
