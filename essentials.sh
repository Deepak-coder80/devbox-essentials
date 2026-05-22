#!/usr/bin/env bash
# =============================================================================
# DevBox Essentials — essentials.sh
# Interactive tool installer for Ubuntu/Debian
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# Bash version
# -----------------------------------------------------------------------------

if (( BASH_VERSINFO[0] < 4 )); then
  echo "Bash 4+ required."
  exit 1
fi

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

safe_clear() {
  [[ -t 1 ]] && printf "\033c"
}

tool_cmd() {

  case "$1" in
    bat) echo "batcat" ;;
    vscode) echo "code" ;;
    python) echo "python3" ;;
    docker-compose) echo "docker" ;;
    *) echo "$1" ;;
  esac
}

installed() {

  local cmd

  case "$1" in

    docker-compose)

      docker compose version &>/dev/null
      return $?
      ;;

    *)

      cmd="$(tool_cmd "$1")"

      command -v "$cmd" &>/dev/null
      return $?
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

    sleep 2
  done
}

# -----------------------------------------------------------------------------
# APT Recovery
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

  info "Updating apt..."

  if ! sudo apt-get update; then

    warn "apt update failed"
    warn "Attempting recovery..."

    sudo apt --fix-broken install -y || true
    sudo dpkg --configure -a || true

    if ! sudo apt-get update; then

      warn "APT still failing"
      warn "Broken third-party repositories detected"
      warn "Continuing installer anyway"

      return 0
    fi
  fi
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

download_and_run() {

  local url="$1"

  local tmpfile
  tmpfile=$(mktemp)

  curl -fsSL "$url" -o "$tmpfile"

  sudo bash "$tmpfile" >> "$LOG_FILE" 2>&1

  rm -f "$tmpfile"
}

# -----------------------------------------------------------------------------
# Selection state
# -----------------------------------------------------------------------------

declare -A SELECTED

declare -A TOOLS=(
  [git]="1"
  [curl]="1"
  [wget]="1"
  [unzip]="1"
  [jq]="1"
  [htop]="1"
  [tree]="1"

  [vscode]="1"
  [neovim]="0"

  [docker]="1"
  [docker-compose]="1"
  [lazydocker]="0"

  [node]="0"
  [python]="0"
  [go]="0"
  [java]="0"
  [ruby]="0"

  [poetry]="0"
  [pipx]="0"
  [ruff]="0"

  [pnpm]="0"
  [yarn]="0"

  [kubectl]="0"
  [helm]="0"
  [terraform]="0"
  [awscli]="0"
  [k9s]="0"

  [ripgrep]="0"
  [fzf]="0"
  [bat]="0"
  [eza]="0"
  [tmux]="0"
  [starship]="0"
  [gh]="0"
  [httpie]="0"
)

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
  [go]="Go runtime"
  [java]="Java 21 (Temurin)"
  [ruby]="Ruby runtime"

  [poetry]="Poetry"
  [pipx]="pipx"
  [ruff]="Ruff"

  [pnpm]="pnpm"
  [yarn]="Yarn"

  [kubectl]="kubectl"
  [helm]="Helm"
  [terraform]="Terraform"
  [awscli]="AWS CLI v2"
  [k9s]="k9s"

  [ripgrep]="ripgrep"
  [fzf]="fzf"
  [bat]="bat"
  [eza]="eza"
  [tmux]="tmux"
  [starship]="Starship"
  [gh]="GitHub CLI"
  [httpie]="HTTPie"
)

MENU_GROUPS=(
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
# Dependencies
# -----------------------------------------------------------------------------

is_selected() {
  [[ "${SELECTED[$1]:-0}" == "1" ]]
}

resolve_dependencies() {

  is_selected poetry && SELECTED[python]=1
  is_selected ruff && SELECTED[python]=1
  is_selected pipx && SELECTED[python]=1

  is_selected pnpm && SELECTED[node]=1
  is_selected yarn && SELECTED[node]=1

  is_selected lazydocker && SELECTED[docker]=1
  is_selected k9s && SELECTED[kubectl]=1
}

# -----------------------------------------------------------------------------
# Menu
# -----------------------------------------------------------------------------

print_menu() {

  safe_clear

  echo -e "${BOLD}${CYAN}"
  echo "  ╔════════════════════════════════════════════════════╗"
  echo "  ║            DevBox Essentials Installer            ║"
  echo "  ╠════════════════════════════════════════════════════╣"
  echo "  ║  Toggle tools: type number then press Enter       ║"
  echo "  ║                                                    ║"
  echo "  ║   [x] selected    [ ] not selected                 ║"
  echo "  ║                                                    ║"
  echo "  ║   Examples:                                        ║"
  echo "  ║     9     → toggle Neovim                         ║"
  echo "  ║     21    → toggle pnpm                           ║"
  echo "  ║                                                    ║"
  echo "  ║   Commands:                                        ║"
  echo "  ║     a = select all                                ║"
  echo "  ║     n = select none                               ║"
  echo "  ║     i = install selected tools                    ║"
  echo "  ║     q = quit                                      ║"
  echo "  ╚════════════════════════════════════════════════════╝"
  echo -e "${RESET}"

  unset MENU_INDEX
  declare -g -A MENU_INDEX

  local idx=1

  for group_entry in "${MENU_GROUPS[@]}"; do

    local group_name="${group_entry%%:*}"
    local group_tools="${group_entry##*:}"

    echo -e "  ${BOLD}── $group_name${RESET}"

    for tool in $group_tools; do

      local state="0"

      if [[ -v SELECTED[$tool] ]]; then
        state="${SELECTED[$tool]}"
      elif [[ -v TOOLS[$tool] ]]; then
        state="${TOOLS[$tool]}"
      fi

      local desc="${TOOL_DESC[$tool]:-$tool}"
      local already=""

      if installed "$tool"; then
        already=" ${YELLOW}(installed)${RESET}"
      fi

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
}

run_menu() {

  for tool in "${!TOOLS[@]}"; do
    SELECTED[$tool]="${TOOLS[$tool]}"
  done

  while true; do

    print_menu

    echo -ne "  ${BOLD}Choice:${RESET} "

    if ! read -r choice; then
      echo ""
      warn "Input cancelled"
      exit 1
    fi

    case "$choice" in

      a)

        for tool in "${!SELECTED[@]}"; do
          SELECTED[$tool]=1
        done
        ;;

      n)

        for tool in "${!SELECTED[@]}"; do
          SELECTED[$tool]=0
        done
        ;;

      i)

        resolve_dependencies

        local any=0

        for tool in "${!SELECTED[@]}"; do

          if [[ "${SELECTED[$tool]}" == "1" ]]; then
            any=1
            break
          fi
        done

        if [[ "$any" == "0" ]]; then
          warn "Nothing selected"
          sleep 1
        else
          break
        fi
        ;;

      q)

        echo "Exiting."
        exit 0
        ;;

      *)

        if [[ "$choice" =~ ^[0-9]+$ ]]; then

          local tool="${MENU_INDEX[$choice]:-}"

          if [[ -z "$tool" ]]; then

            warn "Invalid number"
            sleep 1

          else

            if [[ "${SELECTED[$tool]}" == "1" ]]; then
              SELECTED[$tool]=0
            else
              SELECTED[$tool]=1
            fi

          fi

        else

          warn "Invalid input"
          sleep 1

        fi
        ;;
    esac
  done
}

# -----------------------------------------------------------------------------
# Confirm
# -----------------------------------------------------------------------------

confirm_install() {

  safe_clear

  heading "You selected:"

  for tool in "${!SELECTED[@]}"; do

    if [[ "${SELECTED[$tool]}" == "1" ]]; then
      echo -e "  ${GREEN}✔${RESET} ${TOOL_DESC[$tool]}"
    fi

  done

  echo ""

  echo -ne "${BOLD}Install now? [y/N]: ${RESET}"

  local confirm

  if ! read -r confirm; then
    echo ""
    warn "Input cancelled"
    exit 1
  fi

  [[ "$confirm" =~ ^[Yy]$ ]] || {
    echo "Cancelled."
    exit 0
  }
}

# -----------------------------------------------------------------------------
# Install
# -----------------------------------------------------------------------------

install_tools() {

  heading "Checking package manager health..."

  repair_known_bad_repos
  repair_spotify_key

  sudo dpkg --configure -a || true
  sudo apt-get install -f -y || true

  apt_update

  heading "Installing selected tools..."

  if is_selected git; then
    installed git || apt_install git
  fi

  if is_selected curl; then
    installed curl || apt_install curl
  fi

  if is_selected wget; then
    installed wget || apt_install wget
  fi

  if is_selected unzip; then
    installed unzip || apt_install unzip
  fi

  if is_selected jq; then
    installed jq || apt_install jq
  fi

  if is_selected htop; then
    installed htop || apt_install htop
  fi

  if is_selected tree; then
    installed tree || apt_install tree
  fi

  heading "Installation completed"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

if ! grep -qiE "ubuntu|debian" /etc/os-release 2>/dev/null; then
  warn "Designed for Ubuntu/Debian"
fi

if ! sudo -n true 2>/dev/null; then
  info "sudo access required"
  sudo true || exit 1
fi

run_menu
confirm_install
install_tools