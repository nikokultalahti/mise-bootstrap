# Declarative Workstation Bootstrap & Dotfiles with Mise

A unified, declarative machine bootstrapper and dotfiles management system for **Fedora Silverblue** and **macOS**, powered natively by [**mise**](https://mise.jdx.dev).
**Note:** At the moment only thoroughly tested on Silverblue.

This repository provisions an entire developer workstation from scratch in a single command: GUI applications (Flatpaks), system-level configurations (`/etc`), rootless container sockets, shell dotfile templates, versioned CLI tools, and encrypted secrets.

---

## Architecture & Core Philosophy

1. **Zero-Sudo Initial Entry Point:** The setup begins entirely in user space over public HTTPS. Root privileges are never required upfront to clone or initialize the machine.
2. **Immutable Host Boundary (Silverblue):** Keep host OS layering minimal. The immutable host is reserved strictly for the kernel, display server, GPU drivers, terminal emulator, multiplexer (`tmux`), and container runtimes (`podman`, `distrobox`).
3. **GUI Applications via Flathub:** Desktop apps are installed exclusively from Flathub. Flathub builds bundle required codecs and runtimes, eliminating host package conflicts and dirty codec layering.
4. **User-Space CLI Tooling:** Developer CLI binaries (`starship`, `atuin`, `eza`, `ripgrep`, `fzf`, `gh`, `age`, etc.) are installed directly into `~/.local/share/mise` via GitHub releases and Aqua registries rather than host package layers or Homebrew.
5. **Zero-Knowledge Secret Recovery via Bitwarden:** During initial bootstrap, the Bitwarden Desktop Flatpak CLI interactively authenticates once to retrieve:
   - Your private OpenSSH key into `~/.ssh/id_ed25519`
   - Your `age` decryption key into `~/.config/age/dotfiles-age-key.txt`
6. **Encrypted System Files in Public Git:** Sensitive system configs (such as `system/nextdns.age`) remain encrypted in git using `age`. Plaintext secrets never touch disk or git history unencrypted.
7. **Automatic Remote Protocol Switch:** Boots anonymously via HTTPS, retrieves your SSH key from Bitwarden, and automatically flips the repository's git remote to `git@github.com:...` so future git operations are immediately ready for push.
8. **Work vs. Personal Multi-Profile:** Sibling profile `mise.work.toml` dynamically customizes git identity, work email, and corporate repository credential helpers without hardcoding.
9. **Zero-Maintenance Upgrades (Bluefin-Style):** A persistent daily systemd user timer automatically and silently updates all desktop Flatpaks, all global Mise CLI tools (`mise upgrade --yes`), and any Distrobox containers in the background.

---

## Repository Structure

```text
dotfiles/
├── mise.toml                  # Master machine configuration & bootstrap phases
├── mise.work.toml             # Work environment overrides (email, machine type)
├── bootstrap.sh               # One-liner bootstrap wrapper
├── system/                    # Privileged /etc system files
│   ├── nextdns.age            # Encrypted NextDNS systemd-resolved config
│   ├── rpm-ostreed.conf       # Staged background OS updates configuration
│   └── vscode.repo            # Official Microsoft repository for VS Code layering
├── templates/                 # Dynamic dotfiles rendered via Tera template engine
│   ├── gitconfig.tera         # Git config with conditional work/personal profiles
│   ├── zshrc.tera             # Zsh configuration, tool inits, and completions
│   └── zprofile.tera          # Environment & PATH setup
├── .config/                   # Static application configs
│   ├── atuin/config.toml      # Shell history sync settings
│   ├── bat/                   # Bat syntax highlighter config & themes
│   ├── tealdeer/config.toml   # Fast tldr client settings
│   └── vscode/settings.tera   # VS Code settings (container sockets & themes)
├── .bashrc                    # Static bash fallback config
└── README.md
```

---

## Prerequisites (Bitwarden Vault)

Before bootstrapping a new computer, ensure your Bitwarden vault contains two **Secure Notes**:

1. **`dotfiles-github-auth-key`**:
   Your OpenSSH private key with push access to your GitHub account (`-----BEGIN OPENSSH PRIVATE KEY-----`).
2. **`dotfiles-age-key`**:
   Your raw `age` private key (`AGE-SECRET-KEY-1...`).

*(Ensure the matching SSH public key is added to your GitHub account under Settings → SSH Keys).*

---

## How to Bootstrap a Fresh Machine

### Step 1: Run the Bootstrap Command

On a clean installation, install `mise` and run the bootstrap:

#### Personal Machine:
```bash
curl https://mise.run | sh
mise bootstrap --from https://github.com/nikokultalahti/dotfiles.git --from-dir ~/Dev/dotfiles
```

#### Work Machine:
```bash
curl https://mise.run | sh
mise -E work bootstrap --from https://github.com/nikokultalahti/dotfiles.git --from-dir ~/Dev/dotfiles
```

*(Alternatively, run via the included script: `bash <(curl -fsSL https://raw.githubusercontent.com/nikokultalahti/dotfiles/master/bootstrap.sh)`)*

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

## Phased Lifecycle Execution

`mise bootstrap` executes configuration sections through a deterministic, phased order:

```
[bootstrap.hooks.pre-packages]
       ↓
[bootstrap.packages] (Flatpaks installed)
       ↓
[bootstrap.hooks.post-packages] (Bitwarden CLI login & key retrieval)
       ↓
[bootstrap.files] (/etc system configs placed)
       ↓
[bootstrap.services] (System timers & user Podman socket started)
       ↓
[dotfiles] (Configs linked, copied, and Tera templates rendered)
       ↓
[tools] (CLI tools installed via mise)
       ↓
[bootstrap.hooks.post-tools] (Stream-decrypt nextdns.age into /etc)
       ↓
[bootstrap.hooks.final] (Flip Git origin to SSH & persist work profile)
```

- **Pre-Packages Hook:** Ensures the official Flathub remote is prioritized (`--prio=10`) and deprioritizes Fedora's filtered Flatpak remote (`--prio=1`).
- **System Packages (`[bootstrap.packages]`):** Installs desktop Flatpaks (Bitwarden, Commit, Firefox, Thunderbird, Obsidian, Signal, Pods, Flatseal, etc.).
- **Post-Packages Hook:** 
  - Enables GNOME Software automatic background updates.
  - Launches the Bitwarden CLI, prompts for authentication, and extracts `~/.ssh/id_ed25519` and your `age` key.
  - Pre-seeds `github.com` into `~/.ssh/known_hosts`.
- **System Files (`[bootstrap.files]`):** Declaratively manages `/etc/rpm-ostreed.conf` and `/etc/yum.repos.d/vscode.repo` owned by `root`.
- **System Services (`[bootstrap.services]` & `[bootstrap.linux.systemd.units]`):** 
  - Enables `rpm-ostreed-automatic.timer` (background OS update staging).
  - Starts the user-level rootless `podman.socket` (for Dev Containers).
  - Deploys and enables `workstation-auto-update.timer` to automatically update Flatpaks, Mise tools, and Distrobox containers daily.
- **Dotfiles & Templates (`[dotfiles]`):**
  - Symlinks `~/.config/mise/config.toml` back to `~/Dev/dotfiles/mise.toml` (self-managing config).
  - Copies static configs (`atuin`, `bat`, `tealdeer`, `.bashrc`).
  - Renders dynamic Tera templates into `$HOME` (`.zshrc`, `.zprofile`, `.gitconfig`, `vscode/settings.json`).
- **Tools (`[tools]`):** Installs developer CLI utilities (`age`, `starship`, `atuin`, `eza`, `fd`, `fzf`, `gh`, `jq`, `ripgrep`, `television`, `zoxide`, `goose`, `litra-rs`).
- **Post-Tools Hook:** Uses `mise exec -- age` to stream-decrypt `system/nextdns.age` directly into `/etc/systemd/resolved.conf.d/nextdns.conf` with `sudo tee` and restarts `systemd-resolved`.
- **Final Hook:** Rewrites the repository remote from HTTPS to `git@github.com:...` and, if bootstrapping on a work machine, runs `mise settings set env work` to persist the profile.

---

## Day-to-Day Workflow

Your dotfiles repository lives at `~/Dev/dotfiles` as a standard, independent Git repository.

### Making Changes
1. Navigate to the repository:
   ```bash
   cd ~/Dev/dotfiles
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
cd ~/Dev/dotfiles
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
