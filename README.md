# Declarative Workstation Bootstrap & Dotfiles with Mise

A unified, declarative machine bootstrapper and dotfiles management system for **Fedora Silverblue** and **macOS**, powered natively by [**mise**](https://mise.jdx.dev).

This repository provisions an entire developer workstation from scratch in a single command: desktop applications (Flatpaks), system-level configurations (`/etc`), rootless container sockets, shell dotfile templates, versioned CLI tools, and encrypted secrets.

> **Note:** Thoroughly tested on Fedora Silverblue; macOS support is structured and ready for platform overlays.

---

## Prerequisites (Bitwarden Vault)

Before bootstrapping a fresh computer, ensure your Bitwarden vault contains two **Secure Notes**:

1. **`mise-github-auth-key`**:
   Your OpenSSH private key with push access to your GitHub account (`-----BEGIN OPENSSH PRIVATE KEY-----`).
2. **`mise-age-key`**:
   Your raw `age` private key (`AGE-SECRET-KEY-1...`).
3. Optional, but recommended: **`mise-github-token`**:
   Token for Mise when downloading packages/tools to prevent rate limit error

*(Ensure the matching SSH public key is added to your GitHub account under **Settings → SSH and GPG keys**).*

---

## How to Bootstrap a Fresh Machine

### Option A: The One-Liner Bootstrap Script (Recommended)

Run this single command in a terminal on a clean installation:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nikokultalahti/mise-bootstrap/main/bootstrap.sh)
```
*(Or `./bootstrap.sh` if the repository is already cloned).*

The script will:
1. Install `mise` and put it on PATH.
2. Install `bitwarden` CLI and `fnox`.
3. Configure the EU Bitwarden vault (`https://vault.bitwarden.eu`) and prompt you to log in and unlock.
4. Clone or navigate to the repository.
5. Prompt you interactively to choose **1) Personal** (default) or **2) Work**.
6. Run `fnox exec -- mise bootstrap` with the appropriate profile flags.

---

### Option B: Manual Command-Line Bootstrap

If you prefer to run the commands step-by-step:

#### Personal Machine (Linux):
No `-E` flag is needed. `.miserc.toml` has `auto_env = true`, so `mise` automatically recognizes Linux and layers `mise.linux.toml` on top of `mise.toml` (which defaults to personal profile).
```bash
curl https://mise.run | sh
mise bootstrap --from https://github.com/nikokultalahti/mise-bootstrap.git --from-dir ~/Dev/mise-bootstrap --force-dotfiles
```
- **Files loaded:** `mise.toml` (base) + `mise.linux.toml` (platform & personal)
- **What gets installed:** Common CLI tools, personal CLI tools (`yt-dlp`, `goose`, `fabric`, `talos`), 47 Flathub apps, Fedora system files (`/etc`), systemd timers, and personal dotfiles.

#### Work Machine (macOS):
The `-E work` flag specifies the work role profile. `.miserc.toml` automatically recognizes macOS and loads `mise.macos.toml`, while `-E work` loads `mise.work.toml` to override identity variables and install work packages and tools.
```bash
curl https://mise.run | sh
mise -E work bootstrap --from https://github.com/nikokultalahti/mise-bootstrap.git --from-dir ~/Dev/mise-bootstrap --force-dotfiles
```
- **Files loaded:** `mise.toml` (base) + `mise.macos.toml` (platform) + `mise.work.toml` (work profile)
- **What gets installed:** Common CLI tools, macOS Homebrew packages (`zsh-autosuggestions`, `zsh-syntax-highlighting`), work Homebrew casks & formulae (19 casks including `aerospace`, `raycast`, `gcloud-cli`, `ghostty`, `hermes-desktop`, `visual-studio-code`, plus `podman`, `hermes-agent`), work developer tools (`kubectl`, `k9s`, `terragrunt`, `opentofu`, `claude-code`, etc.), and work-tailored dotfiles (work email, Google Cloud SDK shell integrations, Bitbucket SSH rewrite).
- **Automatic Persistence:** The final bootstrap hook (`scripts/final.sh`) automatically runs `mise settings set env work`, writing `env = "work"` to `~/.config/mise/config.local.toml`. On all subsequent runs (`mise bootstrap`, `mise install`, `mise upgrade`), your work Mac stays in the `work` environment without needing `-E work` again!

During either run, secrets are fetched via fnox (using Bitwarden as the provider) or directly via Bitwarden CLI as a fallback. Your SSH key and `age` key are automatically extracted into place, system files are configured, dotfiles are deployed, tools are installed, and the git remote is flipped to SSH.

---

### Step 2: Minimal Host Layering (Fedora Silverblue)

Once the user-space bootstrap completes, layer the minimal packages needed on the host OS:

```bash
# Remove default Firefox & Tour, layer native editor, container tools, and shell
sudo rpm-ostree override remove firefox firefox-langpacks gnome-tour \
  --install code \
  --install distrobox \
  --install zsh \
  --install zsh-autosuggestions \
  --install zsh-syntax-highlighting \
  --install tmux
```

### Step 3: Reboot
```bash
systemctl reboot
```

---

## Architecture & Core Philosophy

1. **Zero-Sudo Initial Entry Point:** The setup begins entirely in user space over public HTTPS. Root privileges are never required upfront to clone or initialize the machine.
2. **Immutable Host Boundary (Silverblue):** Keep host OS layering minimal. The immutable host is reserved strictly for the kernel, display server, GPU drivers, terminal emulator, multiplexer (`tmux`), and container runtimes (`podman`, `distrobox`).
3. **GUI Applications via Flathub:** Desktop apps are installed exclusively from Flathub. Flathub builds bundle required codecs and runtimes, eliminating host package conflicts and dirty codec layering.
4. **User-Space CLI Tooling:** Developer CLI binaries (`starship`, `atuin`, `eza`, `ripgrep`, `fzf`, `gh`, `age`, etc.) are installed directly into `~/.local/share/mise` via GitHub releases and Aqua registries rather than host package layers or Homebrew.
5. **Zero-Knowledge Secret Recovery via Bitwarden:** During initial bootstrap, the Bitwarden Desktop Flatpak CLI interactively authenticates once to retrieve:
   - Your private OpenSSH key into `~/.ssh/id_ed25519`
   - Your `age` decryption key into `~/.config/age/dotfiles-age-key.txt`
6. **Encrypted System Files in Public Git:** Sensitive system configs (such as `system_files/nextdns.age`) remain encrypted in git using `age`. Plaintext secrets never touch disk or git history unencrypted.
7. **Automatic Remote Protocol Switch:** Boots anonymously via HTTPS, retrieves your SSH key from Bitwarden, and automatically flips the repository's git remote to `git@github.com:...` so future git operations are immediately ready for push.
8. **Layered Platform & Role Profiles:** Automatic OS detection (`auto_env = true` in `.miserc.toml`) dynamically separates universal tools (`mise.toml`), Linux Flatpaks & system configs (`mise.linux.toml`), macOS Homebrew packages (`mise.macos.toml`), and work profile overrides (`mise.work.toml`).
9. **Zero-Maintenance Upgrades:** A persistent daily systemd user timer on Linux automatically updates all desktop Flatpaks, Mise CLI tools (`mise upgrade --yes`), and Distrobox containers in the background.

---

## Phased Lifecycle Execution

`mise bootstrap` executes configuration sections through a deterministic order:

```
[bootstrap.hooks.pre-packages]
       ↓
[bootstrap.packages] (Flatpaks installed)
       ↓
[bootstrap.hooks.post-packages] (Secret retrieval via fnox or Bitwarden CLI fallback)
       ↓
[bootstrap.files] (/etc system configs placed)
       ↓
[bootstrap.services] (System timers & user Podman socket started)
       ↓
[dotfiles] (Configs linked, copied, and Tera templates rendered)
       ↓
[bootstrap.linux.systemd.units] (Workstation auto-update timer & service deployed)
       ↓
[tools] (CLI tools installed via mise)
       ↓
[bootstrap.hooks.post-tools] (Stream-decrypt secrets via age)
       ↓
[bootstrap.hooks.final] (Flip Git origin to SSH & persist work profile)
```

- **Pre-Packages Hook (`scripts/pre-packages.sh`):** Ensures the official Flathub remote is prioritized (`--prio=10`) and deprioritizes Fedora's filtered Flatpak remote (`--prio=1`).
- **System Packages (`[bootstrap.packages]`):** Installs desktop Flatpaks (Bitwarden, Commit, Firefox, Thunderbird, Obsidian, Signal, Pods, Flatseal, etc.).
- **Post-Packages Hook (`scripts/post-packages.sh`):** 
  - Enables GNOME Software automatic background updates.
  - Fetches `~/.ssh/id_ed25519` and your `age` key from fnox environment variables (`GITHUB_SSH_KEY`, `DOTFILES_AGE_KEY`), or falls back to Bitwarden CLI if fnox is not used.
  - Pre-seeds `github.com` into `~/.ssh/known_hosts`.
- **System Files (`[bootstrap.files]`):** Declaratively manages `/etc/rpm-ostreed.conf` and `/etc/yum.repos.d/vscode.repo` owned by `root`.
- **System Services (`[bootstrap.services]`):** Enables `rpm-ostreed-automatic.timer` (background OS update staging) and the user-level rootless `podman.socket` (for Dev Containers).
- **Dotfiles & Templates (`[dotfiles]`):**
  - Symlinks `~/.config/mise/config.toml` back to `~/Dev/mise-bootstrap/mise.toml` (self-managing config).
  - Copies static configs (`atuin`, `bat`, `tealdeer`, `.bashrc`).
  - Renders dynamic Tera templates into `$HOME` (`.zshrc`, `.zprofile`, `.gitconfig`, `vscode/settings.json`).
- **Linux Systemd User Units (`[bootstrap.linux.systemd.units]`):** Deploys and enables `workstation-auto-update.timer` to automatically update Flatpaks, Mise tools, and Distrobox containers daily.
- **Tools (`[tools]`):** Installs developer CLI utilities (universal: `age`, `starship`, `atuin`, `eza`, `fd`, `fzf`, `gh`, `helix`, `jq`, `ripgrep`, `sops`, `television`, `zoxide`, `litra-rs`; personal: `yt-dlp`, `goose`, `fabric`, `talos`; work: `kubectl`, `k9s`, `terragrunt`, `opentofu`, `claude-code`, etc.).
- **Post-Tools Hook (`scripts/post-tools.sh`):** Uses `mise exec -- age` to stream-decrypt encrypted configuration secrets (`~/.ssh/config`, `nextdns.conf`).
- **Final Hook (`scripts/final.sh`):** Rewrites the repository remote from HTTPS to `git@github.com:...` and, if bootstrapping on a work machine, runs `mise settings set env work` to persist the profile.

---

## Repository Structure

```text
mise-bootstrap/
├── bootstrap.sh               # One-liner bootstrap entrypoint script
├── .miserc.toml               # Early-init config (auto_env = true for OS detection)
├── fnox.toml                  # Secret manager configuration (Bitwarden provider)
├── mise.toml                  # Base layer: universal CLI tools, baseline dotfiles, personal defaults
├── mise.linux.toml            # Linux platform layer: Flatpaks, /etc system files, systemd timers
├── mise.macos.toml            # macOS platform layer: Homebrew packages, macOS tools
├── mise.work.toml             # Work profile layer: work email, gcloud, work settings
├── scripts/                   # Modular bootstrap phase scripts
│   ├── pre-packages.sh        # Configures and prioritizes Flathub (Linux)
│   ├── post-packages.sh       # Fetches Bitwarden secrets & enables auto-updates
│   ├── post-tools.sh          # Decrypts age secrets (SSH & NextDNS)
│   └── final.sh               # Switches git origin to SSH & persists profile
├── system_files/              # Privileged /etc system files (Linux)
│   ├── nextdns.age            # Encrypted NextDNS systemd-resolved config
│   ├── rpm-ostreed.conf       # Staged background OS updates configuration
│   └── vscode.repo            # Official Microsoft repository for VS Code layering
├── dotfiles/                  # Dotfiles and dynamic templates (cross-platform source of truth)
│   ├── .bashrc                # Static bash fallback config
│   ├── .config/               # Static application configs
│   │   ├── atuin/config.toml  # Shell history sync settings
│   │   ├── bat/               # Bat syntax highlighter config & themes
│   │   ├── tealdeer/config.toml # Fast tldr client settings
│   │   └── vscode/settings.tera # VS Code settings (container sockets & themes)
│   ├── .ssh/                  # Encrypted SSH config
│   │   └── ssh_config_personal.age
│   ├── gitconfig.tera         # Git config with conditional work/personal profiles
│   ├── zprofile.tera          # Environment & PATH setup
│   └── zshrc.tera             # Zsh configuration, tool inits, and completions
└── README.md
```

---

## Day-to-Day Workflow

Your bootstrap and dotfiles repository lives at `~/Dev/mise-bootstrap` as a standard, independent Git repository.

### Making Changes
1. Navigate to the repository:
   ```bash
   cd ~/Dev/mise-bootstrap
   ```
2. Edit any configuration file, template, or `mise.toml`.
3. Apply the changes immediately to your live environment:
   ```bash
   mise bootstrap dotfiles apply
   ```
   *(Or re-run the full convergence: `mise bootstrap`)*
4. Commit and push normally over SSH:
   ```bash
   git add .
   git commit -m "Update zsh aliases and starship prompt"
   git push
   ```

### Updating on Another Machine
To pull and apply the latest configurations on another computer:
```bash
cd ~/Dev/mise-bootstrap
git pull
mise bootstrap
```

---

## Useful Commands

| Task | Command |
| :--- | :--- |
| **Inspect dotfiles status** | `mise bootstrap dotfiles status` |
| **Preview dotfile diffs** | `mise bootstrap dotfiles diff` |
| **Re-apply dotfiles only** | `mise bootstrap dotfiles apply` |
| **Full machine state check** | `mise bootstrap status` |
| **Simulate bootstrap apply** | `mise bootstrap --dry-run` |
| **Check auto-update timer** | `systemctl --user list-timers \| grep workstation` |
| **Run auto-update manually** | `systemctl --user start dev.mise.workstation-auto-update.service` |
| **Update all CLI tools** | `mise upgrade` |
| **Completely uninstall mise** | `mise implode` |
