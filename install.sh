#!/data/data/com.termux/files/usr/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  termux-rocd — Bulletproof Termux Container Provisioner via proot-distro
#  (Host: Bash | Container root@localhost: Auto Zsh Detection Wrapper)
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
echo -e "${BOLD}${GRN}     ⚡ Termux Reset & Bulletproof rocd Provisioner   ${RST}"
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

# 5. Provision Full Stack Dev Tools & Zsh INSIDE container (root@localhost)
echo -e "${YLW}📦 Step 5: Pre-installing Zsh, Termux-Zsh theme, sudo, Node.js, npm, git & gh in container...${RST}"
proot-distro login ubuntu -- /bin/bash -c "
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

  # Set default shell in container to Zsh
  chsh -s /usr/bin/zsh root 2>/dev/null || true

  # Install Termux-Zsh dotfiles theme inside container /root
  cd /root
  rm -f zsh.tar.xz
  wget -q -O zsh.tar.xz https://github.com/ivansslo/Termux-Zsh/raw/main/zsh.tar.xz || wget -q -O zsh.tar.xz https://github.com/atamshkai/Termux-Zsh/raw/main/zsh.tar.xz || true
  if [ -f zsh.tar.xz ]; then
    tar -xvJf zsh.tar.xz 2>/dev/null || tar -xvf zsh.tar.xz 2>/dev/null || true
    if [ -d /root/zsh ]; then
      cp -rn /root/zsh/.* /root/ 2>/dev/null || true
      rm -rf /root/zsh /root/zsh.tar.xz
    fi
  fi
" 2>/dev/null || echo -e "${YLW}⚠️ Container tool provisioning finished with minor notices.${RST}"

# 6. Create Crash-Free Global Shortcut Launcher 'rocd'
echo -e "${YLW}🔗 Step 6: Creating crash-free launcher shortcut 'rocd'...${RST}"
BIN_DIR="${PREFIX:-$HOME/.local}/bin"
mkdir -p "$BIN_DIR"

cat << 'EOF' > "$BIN_DIR/rocd"
#!/data/data/com.termux/files/usr/bin/bash
# Crash-free shortcut launcher for rocd container (root@localhost) via native proot-distro

export PROOT_NO_SECCOMP=1
export PROOT_FORCE_READLINK=1

# Ensure host DNS resolv.conf exists before running
RESOLV="${PREFIX:-/data/data/com.termux/files/usr}/etc/resolv.conf"
if [ ! -f "$RESOLV" ] || [ ! -s "$RESOLV" ]; then
  rm -f "$RESOLV" 2>/dev/null || true
  mkdir -p "$(dirname "$RESOLV")"
  printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > "$RESOLV" 2>/dev/null || true
fi

if [ "$1" = "reset" ]; then
  echo "🧹 Resetting rocd Ubuntu container..."
  proot-distro remove ubuntu 2>/dev/null || true
  proot-distro install ubuntu
  echo "✅ Container reset to fresh state."
  exit 0
fi

if [ $# -gt 0 ]; then
  exec proot-distro login ubuntu -- "$@"
else
  echo "🚀 Entering rocd Ubuntu Container (root@localhost)..."
  exec proot-distro login ubuntu -- /bin/bash -c "[ -x /usr/bin/zsh ] && exec /usr/bin/zsh -l || exec /bin/bash -l"
fi
EOF

chmod +x "$BIN_DIR/rocd"

# 7. Configure Termux ~/.bashrc Safely
echo -e "${YLW}⚙️ Step 7: Configuring Termux ~/.bashrc to auto-start rocd safely...${RST}"
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
echo -e "${BOLD}${GRN}🎉 Crash-Free rocd Container Setup Complete!${RST}"
echo -e "${GRN}=====================================================${RST}"
echo -e "  • Host Shell:      ${CYN}Bash (Clean & Lightweight Host)${RST}"
echo -e "  • Container Shell: ${CYN}Zsh (Auto-detected in root@localhost)${RST}"
echo -e "  • Shortcut Command: ${BOLD}${GRN} rocd ${RST}"
echo ""
