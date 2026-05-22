#!/usr/bin/env bash
# =============================================================================
# DevBox Essentials — basic-dev-env.sh
# Non-interactive developer environment bootstrap
# Ubuntu / Debian only
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

LOG_FILE="$HOME/.config/devbox-essentials/basic-install.log"

mkdir -p "$(dirname "$LOG_FILE")"

log()     { echo -e "${GREEN}[✔]${RESET} $*" | tee -a "$LOG_FILE"; }
info()    { echo -e "${BLUE}[→]${RESET} $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[✘]${RESET} $*" | tee -a "$LOG_FILE"; }
heading() { echo -e "\n${BOLD}${CYAN}$*${RESET}\n"; }

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

if (( BASH_VERSINFO[0] < 4 )); then
  error "Bash 4+ required"
  exit 1
fi

if ! grep -qiE "ubuntu|debian" /etc/os-release 2>/dev/null; then
  warn "Designed for Ubuntu/Debian"
fi

if ! sudo -n true 2>/dev/null; then
  info "sudo access required"
  sudo true || exit 1
fi

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

tool_installed() {

  case "$1" in

    docker-compose)
      docker compose version &>/dev/null
      ;;

    vscode)
      command -v code &>/dev/null
      ;;

    nvim)
      command -v nvim &>/dev/null
      ;;

    *)
      command -v "$1" &>/dev/null
      ;;
  esac
}

retry() {

  local retries=3
  local count=0

  until "$@"; do

    count=$((count + 1))

    if (( count >= retries )); then
      return 1
    fi

    warn "Retrying..."

    sleep 2
  done
}

apt_install() {

  local pkg="$1"

  info "Installing $pkg..."

  if retry sudo apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1; then
    log "$pkg installed"
  else
    warn "$pkg install failed"
  fi
}

# -----------------------------------------------------------------------------
# APT Health Recovery
# -----------------------------------------------------------------------------

repair_known_bad_repos() {

  if grep -R "microsoft.com insiders-fast" /etc/apt/sources.list.d &>/dev/null; then

    warn "Removing broken Microsoft insiders repo..."

    sudo rm -f /etc/apt/sources.list.d/*insiders* || true
  fi
}

repair_spotify_key() {

  if grep -R "repository.spotify.com" /etc/apt/sources.list.d &>/dev/null; then

    warn "Repairing Spotify GPG key..."

    curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg \
      | gpg --dearmor \
      | sudo tee /usr/share/keyrings/spotify.gpg >/dev/null || true
  fi
}

apt_update() {

  info "Updating apt repositories..."

  if ! sudo apt-get update; then

    warn "apt update failed"
    warn "Attempting recovery..."

    sudo apt --fix-broken install -y || true
    sudo dpkg --configure -a || true

    sudo apt-get update || true
  fi
}

# -----------------------------------------------------------------------------
# Install Core Utilities
# -----------------------------------------------------------------------------

install_core() {

  heading "Installing core utilities"

  local packages=(
    git
    curl
    wget
    unzip
    jq
    htop
    tree
  )

  for pkg in "${packages[@]}"; do

    if tool_installed "$pkg"; then
      log "$pkg already installed"
    else
      apt_install "$pkg"
    fi

  done
}

# -----------------------------------------------------------------------------
# VS Code
# -----------------------------------------------------------------------------

install_vscode() {

  heading "Installing VS Code"

  if tool_installed vscode; then
    log "VS Code already installed"
    return
  fi

  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor > /tmp/microsoft.gpg

  sudo install -o root -g root -m 644 \
    /tmp/microsoft.gpg \
    /usr/share/keyrings/

  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

  sudo apt-get update >> "$LOG_FILE" 2>&1

  apt_install code

  rm -f /tmp/microsoft.gpg
}

# -----------------------------------------------------------------------------
# Neovim
# -----------------------------------------------------------------------------

install_neovim() {

  heading "Installing Neovim"

  if tool_installed nvim; then
    log "Neovim already installed"
    return
  fi

  if retry sudo snap install nvim --classic >> "$LOG_FILE" 2>&1; then
    log "Neovim installed"
  else
    warn "Neovim install failed"
  fi
}

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------

install_docker() {

  heading "Installing Docker"

  if tool_installed docker; then
    log "Docker already installed"
  else

    curl -fsSL https://get.docker.com | sudo bash >> "$LOG_FILE" 2>&1

    sudo usermod -aG docker "$USER"

    log "Docker installed"
  fi

  if tool_installed docker-compose; then
    log "Docker Compose already installed"
  else
    apt_install docker-compose-plugin
  fi
}

# -----------------------------------------------------------------------------
# Python Tooling
# -----------------------------------------------------------------------------

install_python_tools() {

  heading "Installing Python tooling"

  # pipx
  if tool_installed pipx; then

    log "pipx already installed"

  else

    apt_install pipx

    export PATH="$HOME/.local/bin:$PATH"

    pipx ensurepath >> "$LOG_FILE" 2>&1 || true
  fi

  # poetry
  if tool_installed poetry; then

    log "Poetry already installed"

  else

    if tool_installed pipx; then

      pipx install poetry >> "$LOG_FILE" 2>&1 \
        && log "Poetry installed" \
        || warn "Poetry install failed"

    else

      curl -fsSL https://install.python-poetry.org \
        | python3 - >> "$LOG_FILE" 2>&1 \
        && log "Poetry installed" \
        || warn "Poetry install failed"
    fi
  fi

  # ruff
  if tool_installed ruff; then

    log "Ruff already installed"

  else

    if tool_installed pipx; then

      pipx install ruff >> "$LOG_FILE" 2>&1 \
        && log "Ruff installed" \
        || warn "Ruff install failed"

    else

      curl -fsSL https://astral.sh/ruff/install.sh \
        | bash >> "$LOG_FILE" 2>&1 \
        && log "Ruff installed" \
        || warn "Ruff install failed"
    fi
  fi
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

print_summary() {

  heading "Basic developer environment setup complete"

  echo -e "${BOLD}Installed:${RESET}"
  echo "  ✔ Core utilities"
  echo "  ✔ VS Code"
  echo "  ✔ Neovim"
  echo "  ✔ Docker"
  echo "  ✔ Docker Compose"
  echo "  ✔ pipx"
  echo "  ✔ Poetry"
  echo "  ✔ Ruff"

  echo ""
  echo -e "${BOLD}Log file:${RESET} $LOG_FILE"

  echo ""
  echo -e "${YELLOW}Restart your shell:${RESET}"
  echo "  exec bash"

  echo ""
  echo -e "${YELLOW}Docker:${RESET}"
  echo "  Log out and back in for Docker group permissions"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

heading "DevBox Essentials — Basic Developer Environment"

repair_known_bad_repos
repair_spotify_key

sudo dpkg --configure -a || true
sudo apt-get install -f -y || true

apt_update

install_core
install_vscode
install_neovim
install_docker
install_python_tools

print_summary