#!/data/data/com.termux/files/usr/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  termux-rocd — Reset Termux & Provision udocker Container Engine
# ═════════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
CYN='\033[0;36m'
BOLD='\033[1m'
RST='\033[0m'

echo -e "${CYN}=====================================================${RST}"
echo -e "${BOLD}${GRN}     ⚡ Termux Reset & udocker Container Provisioner  ${RST}"
echo -e "${CYN}=====================================================${RST}"
echo ""

# 1. Reset & Purge Termux Caches / Broken Environment
echo -e "${YLW}🧹 Step 1: Cleaning and resetting Termux caches & broken packages...${RST}"
python3 -m pip cache purge 2>/dev/null || true
pkg clean -y 2>/dev/null || true
rm -rf ~/.cache ~/.tmp /data/data/com.termux/files/usr/tmp/* 2>/dev/null || true
echo -e "${GRN}✅ Cache & temporary files cleared.${RST}\n"

# 2. Update Termux System Packages
echo -e "${YLW}📦 Step 2: Updating Termux system packages...${RST}"
pkg update -y && pkg upgrade -y

# 3. Install Required Base Utilities for Containers
echo -e "${YLW}🔧 Step 3: Installing essential container tools (python, curl, proot, git)...${RST}"
pkg install -y python clang make pkg-config libffi openssl curl wget git jq proot tar unzip openssh

# 4. Install udocker Engine
echo -e "${YLW}🐳 Step 4: Installing udocker engine via pip...${RST}"
python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install udocker

echo -e "${YLW}⚙️ Step 5: Initializing udocker binaries & execution modes...${RST}"
udocker install

# 5. Provision Default Ubuntu Container (roc-container)
echo -e "${YLW}📦 Step 6: Pulling base container image (Ubuntu 22.04 LTS)...${RST}"
udocker pull ubuntu:22.04

echo -e "${YLW}🚀 Step 7: Creating container instance 'roc-container'...${RST}"
udocker rm -f roc-container 2>/dev/null || true
udocker create --name=roc-container ubuntu:22.04

# 6. Create Shortcut Launcher 'rocd'
echo -e "${YLW}🔗 Step 8: Creating global launcher shortcut 'rocd'...${RST}"
BIN_DIR="${PREFIX:-$HOME/.local}/bin"
mkdir -p "$BIN_DIR"

cat << 'EOF' > "$BIN_DIR/rocd"
#!/data/data/com.termux/files/usr/bin/bash
# Shortcut launcher for udocker roc-container

if [ "$1" = "reset" ]; then
  echo "🧹 Resetting udocker containers..."
  udocker rm -f roc-container 2>/dev/null || true
  udocker create --name=roc-container ubuntu:22.04
  echo "✅ Container roc-container reset to fresh state."
  exit 0
fi

echo "🚀 Entering udocker Termux Container (Ubuntu 22.04)..."
udocker run --user=root roc-container /bin/bash "$@"
EOF

chmod +x "$BIN_DIR/rocd"

echo ""
echo -e "${GRN}=====================================================${RST}"
echo -e "${BOLD}${GRN}🎉 Termux Container Transformation Complete!${RST}"
echo -e "${GRN}=====================================================${RST}"
echo -e "  • udocker Version: $(udocker version | head -n 1 2>/dev/null || echo 'installed')"
echo -e "  • Container Name:  ${CYN}roc-container${RST} (Ubuntu 22.04)"
echo -e "  • Shortcut Command:${BOLD}${GRN} rocd ${RST}"
echo ""
echo -e "${CYN}💡 How to use your new container:${RST}"
echo -e "  1. Enter container shell:   ${BOLD}rocd${RST}"
echo -e "  2. Run command inside:      ${BOLD}rocd echo 'Hello Container!'${RST}"
echo -e "  3. Reset container state:   ${BOLD}rocd reset${RST}"
echo ""
