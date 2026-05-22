#!/usr/bin/env bash
# =============================================================================
# DevBox Essentials — essentials.sh
# Interactive tool installer for Ubuntu/Debian.
# Pick what you want. Installs only what you choose.
# No profiles. No compliance controls. Just tools.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Deepak-coder80/devbox-essentials/main/essentials.sh | bash
# =============================================================================

set -euo pipefail

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
# Helpers
# -----------------------------------------------------------------------------

LOG_FILE="$HOME/.config/devbox-essentials/install.log"
mkdir -p "$(dirname "$LOG_FILE")"

log()     { echo -e "${GREEN}[✔]${RESET} $*" | tee -a "$LOG_FILE"; }
info()    { echo -e "${BLUE}[→]${RESET} $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[✘]${RESET} $*" | tee -a "$LOG_FILE"; }
heading() { echo -e "\n${BOLD}${CYAN}$*${RESET}\n"; }

installed() { command -v "$1" &>/dev/null; }

# -----------------------------------------------------------------------------
# Selection state — 1 = selected, 0 = not selected
# -----------------------------------------------------------------------------

declare -A SELECTED

# All available tools and their default state (0 = off, 1 = on)
declare -A TOOLS=(
  # Core
  [git]="1"
  [curl]="1"
  [wget]="1"
  [unzip]="1"
  [jq]="1"
  [htop]="1"
  [tree]="1"

  # Editors
  [vscode]="1"
  [neovim]="0"

  # Containers
  [docker]="1"
  [docker-compose]="1"
  [lazydocker]="0"

  # Languages
  [node]="0"
  [python]="0"
  [go]="0"
  [java]="0"
  [ruby]="0"

  # Python tools
  [poetry]="0"
  [pipx]="0"
  [ruff]="0"

  # Node tools
  [pnpm]="0"
  [yarn]="0"

  # DevOps
  [kubectl]="0"
  [helm]="0"
  [terraform]="0"
  [awscli]="0"
  [k9s]="0"

  # Utilities
  [ripgrep]="0"
  [fzf]="0"
  [bat]="0"
  [eza]="0"
  [tmux]="0"
  [starship]="0"
  [gh]="0"         # GitHub CLI
  [httpie]="0"
)

# Tool display names and descriptions
declare -A TOOL_DESC=(
  [git]="Git — version control"
  [curl]="curl — transfer data from URLs"
  [wget]="wget — file downloader"
  [unzip]="unzip — extract zip files"
  [jq]="jq — JSON processor"
  [htop]="htop — interactive process viewer"
  [tree]="tree — directory tree viewer"
  [vscode]="VS Code — code editor"
  [neovim]="Neovim — terminal text editor"
  [docker]="Docker — container runtime"
  [docker-compose]="Docker Compose — multi-container apps"
  [lazydocker]="Lazydocker — Docker TUI"
  [node]="Node.js LTS — JavaScript runtime"
  [python]="Python 3.12 — Python runtime"
  [go]="Go (latest) — Go runtime"
  [java]="Java 21 (Temurin) — JDK"
  [ruby]="Ruby (latest) — Ruby runtime"
  [poetry]="Poetry — Python dependency manager"
  [pipx]="pipx — install Python CLI tools"
  [ruff]="Ruff — fast Python linter"
  [pnpm]="pnpm — fast Node package manager"
  [yarn]="Yarn — Node package manager"
  [kubectl]="kubectl — Kubernetes CLI"
  [helm]="Helm — Kubernetes package manager"
  [terraform]="Terraform — infrastructure as code"
  [awscli]="AWS CLI v2 — Amazon Web Services"
  [k9s]="k9s — Kubernetes TUI"
  [ripgrep]="ripgrep (rg) — fast grep"
  [fzf]="fzf — fuzzy finder"
  [bat]="bat — better cat with syntax highlighting"
  [eza]="eza — better ls"
  [tmux]="tmux — terminal multiplexer"
  [starship]="Starship — cross-shell prompt"
  [gh]="GitHub CLI — manage GitHub from terminal"
  [httpie]="HTTPie — human-friendly HTTP client"
)

# Group ordering for display
GROUPS=(
  "Core utilities:git curl wget unzip jq htop tree"
  "Editors:vscode neovim"
  "Containers:docker docker-compose lazydocker"
  "Languages:node python go java ruby"
  "Python tools:poetry pipx ruff"
  "Node tools:pnpm yarn"
  "DevOps:kubectl helm terraform awscli k9s"
  "Utilities:ripgrep fzf bat eza tmux starship gh httpie"
)

# -----------------------------------------------------------------------------
# Interactive menu
# -----------------------------------------------------------------------------

print_menu() {
  clear
  echo -e "${BOLD}${CYAN}"
  echo "  ╔═══════════════════════════════════════════╗"
  echo "  ║        DevBox Essentials Installer        ║"
  echo "  ║   Space = toggle  |  Enter = install      ║"
  echo "  ╚═══════════════════════════════════════════╝"
  echo -e "${RESET}"

  local idx=1
  declare -g -A MENU_INDEX=()

  for group_entry in "${GROUPS[@]}"; do
    local group_name="${group_entry%%:*}"
    local group_tools="${group_entry##*:}"

    echo -e "  ${BOLD}── $group_name ${RESET}"

    for tool in $group_tools; do
      local state="${SELECTED[$tool]:-${TOOLS[$tool]}}"
      local desc="${TOOL_DESC[$tool]}"
      local already=""
      installed "$tool" && already=" ${YELLOW}(already installed)${RESET}"

      if [[ "$state" == "1" ]]; then
        echo -e "  ${GREEN}[x]${RESET} ${idx}. $desc$already"
      else
        echo -e "  ${BLUE}[ ]${RESET} ${idx}. $desc$already"
      fi

      MENU_INDEX[$idx]="$tool"
      idx=$((idx + 1))
    done
    echo ""
  done

  echo -e "  ${BOLD}Commands:${RESET}"
  echo -e "  Enter a number to toggle a tool"
  echo -e "  ${BOLD}a${RESET} = select all  |  ${BOLD}n${RESET} = select none"
  echo -e "  ${BOLD}i${RESET} = install selected  |  ${BOLD}q${RESET} = quit"
  echo ""
}

run_menu() {
  # Initialise selection from defaults
  for tool in "${!TOOLS[@]}"; do
    SELECTED[$tool]="${TOOLS[$tool]}"
  done

  while true; do
    print_menu

    echo -ne "  ${BOLD}Your choice: ${RESET}"
    read -r choice

    case "$choice" in
      a)
        for tool in "${!SELECTED[@]}"; do SELECTED[$tool]=1; done
        ;;
      n)
        for tool in "${!SELECTED[@]}"; do SELECTED[$tool]=0; done
        ;;
      i)
        echo ""
        # Check at least one tool selected
        local any=0
        for tool in "${!SELECTED[@]}"; do
          [[ "${SELECTED[$tool]}" == "1" ]] && any=1 && break
        done
        if [[ "$any" == "0" ]]; then
          warn "Nothing selected. Pick at least one tool."
          sleep 1
        else
          break
        fi
        ;;
      q)
        echo "Exiting."
        exit 0
        ;;
      ''|*[!0-9]*)
        warn "Enter a number, a, n, i, or q"
        sleep 1
        ;;
      *)
        local tool="${MENU_INDEX[$choice]:-}"
        if [[ -z "$tool" ]]; then
          warn "Invalid number"
          sleep 1
        else
          # Toggle
          if [[ "${SELECTED[$tool]}" == "1" ]]; then
            SELECTED[$tool]=0
          else
            SELECTED[$tool]=1
          fi
        fi
        ;;
    esac
  done
}

# -----------------------------------------------------------------------------
# Confirm before installing
# -----------------------------------------------------------------------------

confirm_install() {
  clear
  heading "You selected:"

  for tool in "${!SELECTED[@]}"; do
    [[ "${SELECTED[$tool]}" == "1" ]] && echo -e "  ${GREEN}✔${RESET}  ${TOOL_DESC[$tool]}"
  done

  echo ""
  echo -ne "${BOLD}Install now? [y/N]: ${RESET}"
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }
}

# -----------------------------------------------------------------------------
# Installers
# -----------------------------------------------------------------------------

apt_install() {
  local pkg="$1"
  info "apt: installing $pkg..."
  sudo apt-get install -y -qq "$pkg" >> "$LOG_FILE" 2>&1 \
    && log "$pkg installed" \
    || warn "$pkg install failed — check $LOG_FILE"
}

is_selected() { [[ "${SELECTED[$1]:-0}" == "1" ]]; }

install_tools() {
  heading "Installing selected tools..."

  # Apt update once
  info "Updating apt..."
  sudo apt-get update -qq >> "$LOG_FILE" 2>&1

  # --- Core utilities ---
  is_selected git        && { installed git        || apt_install git; log "git: $(git --version)"; }
  is_selected curl       && { installed curl       || apt_install curl; }
  is_selected wget       && { installed wget       || apt_install wget; }
  is_selected unzip      && { installed unzip      || apt_install unzip; }
  is_selected jq         && { installed jq         || apt_install jq; }
  is_selected htop       && { installed htop       || apt_install htop; }
  is_selected tree       && { installed tree       || apt_install tree; }

  # --- VS Code ---
  if is_selected vscode && ! installed code; then
    info "Installing VS Code..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor > /tmp/microsoft.gpg
    sudo install -o root -g root -m 644 /tmp/microsoft.gpg /usr/share/keyrings/
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
      | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    sudo apt-get update -qq >> "$LOG_FILE" 2>&1
    apt_install code
    rm -f /tmp/microsoft.gpg
  fi

  # --- Neovim ---
  if is_selected neovim && ! installed nvim; then
    info "Installing Neovim..."
    sudo snap install nvim --classic >> "$LOG_FILE" 2>&1 && log "Neovim installed" || warn "Neovim install failed"
  fi

  # --- Docker ---
  if is_selected docker && ! installed docker; then
    info "Installing Docker..."
    curl -fsSL https://get.docker.com | sudo bash >> "$LOG_FILE" 2>&1
    sudo usermod -aG docker "$USER"
    log "Docker installed — log out and back in for group to take effect"
  fi

  if is_selected docker-compose && ! installed docker-compose; then
    info "Installing Docker Compose plugin..."
    sudo apt-get install -y -qq docker-compose-plugin >> "$LOG_FILE" 2>&1
    log "Docker Compose installed"
  fi

  if is_selected lazydocker && ! installed lazydocker; then
    info "Installing Lazydocker..."
    curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash >> "$LOG_FILE" 2>&1
    log "Lazydocker installed"
  fi

  # --- mise (runtime manager) — install if any language selected ---
  local need_mise=0
  for lang in node python go java ruby; do
    is_selected "$lang" && need_mise=1 && break
  done

  if [[ "$need_mise" == "1" ]] && ! installed mise; then
    info "Installing mise (runtime manager)..."
    curl -fsSL https://mise.run | bash >> "$LOG_FILE" 2>&1
    export PATH="$HOME/.local/bin:$PATH"
    eval "$("$HOME/.local/bin/mise" activate bash)" 2>/dev/null || true
    # Fix: use HTTPS for GitHub, not SSH (avoids key issues)
    git config --global url."https://github.com/".insteadOf "git@github.com:" 2>/dev/null || true
    log "mise installed"
  fi

  # --- Languages via mise ---
  if installed mise || [[ -f "$HOME/.local/bin/mise" ]]; then
    local mise_cmd="${HOME}/.local/bin/mise"
    [[ ! -f "$mise_cmd" ]] && mise_cmd="mise"

    is_selected node   && { info "Installing Node.js LTS...";  "$mise_cmd" use --global node@lts    >> "$LOG_FILE" 2>&1 && log "Node installed: $(node --version 2>/dev/null || echo ok)" || warn "Node install failed"; }
    is_selected python && { info "Installing Python 3.12...";  "$mise_cmd" use --global python@3.12 >> "$LOG_FILE" 2>&1 && log "Python installed" || warn "Python install failed"; }
    is_selected go     && { info "Installing Go...";           "$mise_cmd" use --global go@latest   >> "$LOG_FILE" 2>&1 && log "Go installed" || warn "Go install failed"; }
    is_selected java   && { info "Installing Java 21...";      "$mise_cmd" use --global java@temurin-21 >> "$LOG_FILE" 2>&1 && log "Java installed" || warn "Java install failed"; }
    is_selected ruby   && { info "Installing Ruby...";         "$mise_cmd" use --global ruby@latest >> "$LOG_FILE" 2>&1 && log "Ruby installed" || warn "Ruby install failed"; }
  fi

  # --- Python tools ---
  if is_selected pipx && ! installed pipx; then
    info "Installing pipx..."
    sudo apt-get install -y -qq pipx >> "$LOG_FILE" 2>&1 && pipx ensurepath >> "$LOG_FILE" 2>&1
    log "pipx installed"
  fi

  if is_selected poetry && ! installed poetry; then
    info "Installing Poetry..."
    if installed pipx; then
      pipx install poetry >> "$LOG_FILE" 2>&1 && log "Poetry installed" || warn "Poetry install failed"
    else
      curl -fsSL https://install.python-poetry.org | python3 - >> "$LOG_FILE" 2>&1 && log "Poetry installed" || warn "Poetry install failed"
    fi
  fi

  if is_selected ruff && ! installed ruff; then
    info "Installing Ruff..."
    if installed pipx; then
      pipx install ruff >> "$LOG_FILE" 2>&1 && log "Ruff installed" || warn "Ruff install failed"
    else
      curl -fsSL https://astral.sh/ruff/install.sh | bash >> "$LOG_FILE" 2>&1 && log "Ruff installed" || warn "Ruff install failed"
    fi
  fi

  # --- Node tools ---
  if is_selected pnpm && ! installed pnpm; then
    info "Installing pnpm..."
    npm install -g pnpm >> "$LOG_FILE" 2>&1 && log "pnpm installed" || warn "pnpm install failed — install Node first"
  fi

  if is_selected yarn && ! installed yarn; then
    info "Installing Yarn..."
    npm install -g yarn >> "$LOG_FILE" 2>&1 && log "Yarn installed" || warn "Yarn install failed — install Node first"
  fi

  # --- DevOps tools ---
  if is_selected kubectl && ! installed kubectl; then
    info "Installing kubectl..."
    curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
      -o /tmp/kubectl
    chmod +x /tmp/kubectl
    mkdir -p "$HOME/.local/bin"
    mv /tmp/kubectl "$HOME/.local/bin/kubectl"
    log "kubectl installed: $(kubectl version --client --short 2>/dev/null || echo ok)"
  fi

  if is_selected helm && ! installed helm; then
    info "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >> "$LOG_FILE" 2>&1
    log "Helm installed"
  fi

  if is_selected terraform && ! installed terraform; then
    info "Installing Terraform..."
    wget -qO /tmp/terraform.zip \
      "https://releases.hashicorp.com/terraform/$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version)/terraform_$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version)_linux_amd64.zip"
    unzip -o /tmp/terraform.zip -d "$HOME/.local/bin/" >> "$LOG_FILE" 2>&1
    rm /tmp/terraform.zip
    log "Terraform installed: $(terraform version | head -1)"
  fi

  if is_selected awscli && ! installed aws; then
    info "Installing AWS CLI v2..."
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -o /tmp/awscliv2.zip -d /tmp/ >> "$LOG_FILE" 2>&1
    sudo /tmp/aws/install >> "$LOG_FILE" 2>&1
    rm -rf /tmp/awscliv2.zip /tmp/aws
    log "AWS CLI installed: $(aws --version)"
  fi

  if is_selected k9s && ! installed k9s; then
    info "Installing k9s..."
    local k9s_ver
    k9s_ver=$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest | jq -r .tag_name)
    curl -fsSL "https://github.com/derailed/k9s/releases/download/${k9s_ver}/k9s_Linux_amd64.tar.gz" \
      | tar -xz -C "$HOME/.local/bin" k9s
    log "k9s installed"
  fi

  # --- Utilities ---
  if is_selected ripgrep && ! installed rg; then
    apt_install ripgrep
  fi

  if is_selected fzf && ! installed fzf; then
    info "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" >> "$LOG_FILE" 2>&1
    "$HOME/.fzf/install" --key-bindings --completion --no-update-rc >> "$LOG_FILE" 2>&1
    log "fzf installed"
  fi

  if is_selected bat && ! installed bat; then
    apt_install bat
    # On Ubuntu, bat is installed as batcat
    mkdir -p "$HOME/.local/bin"
    ln -sf /usr/bin/batcat "$HOME/.local/bin/bat" 2>/dev/null || true
    log "bat installed"
  fi

  if is_selected eza && ! installed eza; then
    info "Installing eza..."
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
      | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
    sudo apt-get update -qq >> "$LOG_FILE" 2>&1
    apt_install eza
  fi

  is_selected tmux && { installed tmux || apt_install tmux; }

  if is_selected starship && ! installed starship; then
    info "Installing Starship prompt..."
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes >> "$LOG_FILE" 2>&1
    # Add to bashrc
    if ! grep -q 'starship init' "$HOME/.bashrc" 2>/dev/null; then
      echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"
    fi
    log "Starship installed"
  fi

  if is_selected gh && ! installed gh; then
    info "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq >> "$LOG_FILE" 2>&1
    apt_install gh
  fi

  if is_selected httpie && ! installed http; then
    info "Installing HTTPie..."
    pipx install httpie >> "$LOG_FILE" 2>&1 \
      || pip3 install --user httpie >> "$LOG_FILE" 2>&1 \
      || warn "HTTPie install failed"
    log "HTTPie installed"
  fi

  # Ensure ~/.local/bin is in PATH
  if ! grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  fi
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

print_summary() {
  clear
  heading "Installation complete!"

  echo -e "  ${BOLD}Installed tools:${RESET}"
  for tool in "${!SELECTED[@]}"; do
    if [[ "${SELECTED[$tool]}" == "1" ]]; then
      echo -e "  ${GREEN}✔${RESET}  ${TOOL_DESC[$tool]}"
    fi
  done

  echo ""
  echo -e "  ${BOLD}Log file:${RESET} $LOG_FILE"
  echo ""
  echo -e "  ${YELLOW}Restart your shell to apply all changes:${RESET}"
  echo -e "  ${BOLD}  exec bash${RESET}"
  echo ""

  # Docker warning
  is_selected docker && echo -e "  ${YELLOW}Docker:${RESET} Log out and back in for Docker group permissions to take effect."
  echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

# Check OS
if ! grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
  warn "This script is designed for Ubuntu/Debian. Proceed with caution on other systems."
fi

# Check sudo available
if ! sudo -n true 2>/dev/null && ! sudo -v 2>/dev/null; then
  error "sudo access required for some tools. Talk to your IT admin."
  exit 1
fi

run_menu
confirm_install
install_tools
print_summary