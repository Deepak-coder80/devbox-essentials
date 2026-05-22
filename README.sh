# DevBox Essentials

A lightweight, interactive tool installer for Ubuntu/Debian developer machines.

Pick what you want. Install only what you need. No profiles. No compliance overhead.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Deepak-coder80/devbox-essentials/main/essentials.sh | bash
```

That's it. The script opens an interactive menu in your terminal.

---

## How It Works

1. Run the curl command above
2. A menu appears — tools are grouped by category
3. Enter a number to toggle a tool on or off
4. Press `i` to install your selection
5. Restart your shell when done: `exec bash`

### Menu controls

| Key | Action |
|---|---|
| `1`–`99` | Toggle that tool on/off |
| `a` | Select all tools |
| `n` | Deselect all tools |
| `i` | Install selected tools |
| `q` | Quit without installing |

---

## Available Tools

### Core utilities
- git, curl, wget, unzip, jq, htop, tree

### Editors
- VS Code, Neovim

### Containers
- Docker, Docker Compose, Lazydocker

### Languages
- Node.js LTS, Python 3.12, Go, Java 21 (Temurin), Ruby

### Python tools
- Poetry, pipx, Ruff

### Node tools
- pnpm, Yarn

### DevOps
- kubectl, Helm, Terraform, AWS CLI v2, k9s

### Utilities
- ripgrep, fzf, bat, eza, tmux, Starship prompt, GitHub CLI, HTTPie

---

## Notes

- No sudo password needed upfront — the script asks only when required
- Already-installed tools are skipped automatically
- Safe to re-run — nothing breaks
- Log file saved at `~/.config/devbox-essentials/install.log`

---

## After Installing Docker

Docker requires a group permission change. Log out and back in after installing:

```bash
# Verify Docker works without sudo after re-login
docker run hello-world
```

## After Installing Languages (Node, Python, Go)

Languages are managed by `mise`. Activate it in your current shell:

```bash
exec bash
# then verify
node --version
python --version
go version
```

---

## Difference vs DevBox (Full)

| | DevBox Essentials | DevBox Full |
|---|---|---|
| Interactive menu | Yes | No — fully automated |
| Role profiles | No | Yes (backend, frontend, devops, ml) |
| ISO 27001 controls | No | Yes |
| AWS CodeArtifact | No | Yes |
| Git security hooks | No | Yes |
| Audit logging | No | Yes |
| Best for | Personal machines, quick setup | Company-managed developer machines |

Use DevBox Full for company machines. Use DevBox Essentials for personal machines or quick setups.

---

## Requirements

- Ubuntu 20.04+ or Debian 11+
- Bash
- sudo access
- Internet connection