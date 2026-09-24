# Declarative Workstation Bootstrap & Dotfiles with Mise

A unified, declarative machine bootstrapper and dotfiles management for **Fedora Silverblue** and **macOS**, powered by [**mise**](https://mise.jdx.dev).

This repository provisions a workstation in a single command: desktop applications (Flatpaks), system-level configurations (`/etc`), rootless container sockets, shell dotfile templates, CLI tools, and secrets pulled directly from Bitwarden.

> **Note:** Thoroughly tested on Fedora Silverblue; macOS not so much.

---

## Prerequisites (Bitwarden Vault)

Before bootstrapping a fresh computer, ensure your Bitwarden vault contains these **Secure Notes**:

1. **`mise-github-auth-key`**:
   Your OpenSSH private key with push access to your GitHub account (`-----BEGIN OPENSSH PRIVATE KEY-----`).
2. **`mise-ssh-config-personal`** / **`mise-ssh-config-work`**:
   The full contents of `~/.ssh/config` for that machine.
3. **`mise-nextdns-conf`** (personal Linux machine only):
   The full contents of `/etc/systemd/resolved.conf.d/nextdns.conf`.
4. Optional, but recommended: **`mise-github-token`**:
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

There are exactly two machines, and `-E` is always explicit — neither profile is an implicit default. Each role file (`mise.personal.toml` / `mise.work.toml`) contains *everything* for that machine (tools, packages, system files/services/hooks); there's no separate OS layer to reason about.

#### Personal Machine (Linux):
```bash
curl https://mise.run | sh
mise -E personal bootstrap --from https://github.com/nikokultalahti/mise-bootstrap.git --from-dir ~/Dev/mise-bootstrap --force-dotfiles
```
- **Files loaded:** `mise.toml` (base) + `mise.personal.toml` (everything personal)

#### Work Machine (macOS):
```bash
curl https://mise.run | sh
mise -E work bootstrap --from https://github.com/nikokultalahti/mise-bootstrap.git --from-dir ~/Dev/mise-bootstrap --force-dotfiles
```
- **Files loaded:** `mise.toml` (base) + `mise.work.toml` (everything work related)
- **Automatic Persistence:** The final bootstrap hook (`scripts/final.sh`) automatically runs `mise settings set env <profile>`, writing it to `~/.config/mise/config.toml` — a real, untracked, machine-local file (this repo's own `mise.toml` is symlinked into `~/.config/mise/conf.d/` instead, precisely so it never collides with that write target). On all subsequent runs (`mise bootstrap`, `mise install`, `mise upgrade`), the machine stays in that environment without needing `-E` again.

> If either machine's OS ever changes (e.g. work moves to Linux), the relevant role file is edited by hand at that point — there's deliberately no generic OS layer being maintained.

During either run, mise's native `[bootstrap.secrets]` reads your SSH key, SSH config, and (personal Linux only) NextDNS config straight from the fnox-populated environment and writes them to their target paths — no custom fetch script involved. System files are configured, dotfiles are deployed, tools are installed, and the git remote is flipped to SSH.

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
2. **Immutable Host Boundary (Silverblue):** Keep host OS layering minimal. 
3. **GUI Applications via Flathub:** Desktop apps are installed exclusively from Flathub. Flathub builds bundle required codecs and runtimes, eliminating host package conflicts and dirty codec layering.
4. **User-Space CLI Tooling:** Developer CLI binaries are installed into `~/.local/share/mise` rather than host package layers or Homebrew.
5. **Secrets Pulled Directly from Bitwarden, No Custom Scripts:** `[bootstrap.secrets]` declares logical names mapped to the env vars fnox populates from Bitwarden secure notes; `[bootstrap.files]`/`[dotfiles]` write them straight to their target paths with mise's own `secret()` template function, redacted from every plan, dry-run, and status output:
   - Your private OpenSSH key into `~/.ssh/id_ed25519`
   - Your SSH config into `~/.ssh/config`
   - Your NextDNS config into `/etc/systemd/resolved.conf.d/nextdns.conf` (personal Linux only), restarting `systemd-resolved` on change

   Nothing sensitive is committed to this repository — Bitwarden's own access control is the only protection, with no separate encryption key to manage or rotate. Without fnox, `mise bootstrap --prompt-secrets` prompts for any missing value interactively instead.
6. **Automatic Remote Protocol Switch:** Boots anonymously via HTTPS, retrieves your SSH key from Bitwarden, and automatically flips the repository's git remote to `git@github.com:...` so future git operations are immediately ready for push.
7. **Two Explicit Role Profiles:** `mise.toml` holds common tools/dotfiles/hooks; `mise.personal.toml` and `mise.work.toml` each hold everything else for that specific machine. Always loaded via an explicit `-E personal`/`-E work` flag.
8. **Zero-Maintenance Upgrades:** A persistent daily systemd user timer on Linux automatically updates all desktop Flatpaks, Mise CLI tools (`mise upgrade --yes`), and Distrobox containers in the background.

---

## Phased Lifecycle Execution

`mise bootstrap` executes configuration sections through a deterministic order:

```
[bootstrap.hooks.pre-packages]
       ↓
[bootstrap.packages] (Flatpaks installed)
       ↓
[bootstrap.files] (/etc system configs placed; SSH key/config & NextDNS config
                    rendered from Bitwarden secrets via [bootstrap.secrets])
       ↓
[bootstrap.services] (System timers, systemd-resolved & user Podman socket started)
       ↓
[dotfiles] (Configs linked, copied, and Tera templates rendered)
       ↓
[bootstrap.linux.systemd.units] (Workstation auto-update timer & service deployed)
       ↓
[tools] (CLI tools installed via mise)
       ↓
[bootstrap.hooks.final] (Flip Git origin to SSH & persist chosen profile)
```

---

## Repository Structure

```text
mise-bootstrap/
├── bootstrap.sh               # One-liner bootstrap entrypoint script
├── fnox.toml                  # Secret manager configuration (Bitwarden provider)
├── mise.toml                  # Base layer: universal CLI tools, dotfiles, hooks, SSH secrets/files (no role/OS content)
├── mise.personal.toml         # Everything personal: tools, Flathub apps, /etc files, NextDNS secret/file, systemd timers
├── mise.work.toml             # Everything work: tools, Homebrew casks/formulae, work identity
├── scripts/                   # Modular bootstrap phase scripts (secrets are handled declaratively, not scripted)
│   ├── linux/
│   │   ├── pre-packages-config-flatpak-gnome.sh # Configures and prioritizes Flathub (Linux)
│   │   └── pre-tools-podman-socket.sh           # Enables rootless Podman user socket
│   └── final.sh                                 # Switches git origin to SSH & persists profile
├── system_files/              # Privileged /etc system files (Linux)
│   ├── rpm-ostreed.conf       # Staged background OS updates configuration
│   └── vscode.repo            # Official Microsoft repository for VS Code layering
├── dotfiles/                  # Dotfiles and dynamic templates (cross-platform source of truth)
│   ├── .bashrc                # Static bash fallback config
│   ├── .config/               # Static application configs
│   │   ├── atuin/config.toml  # Shell history sync settings
│   │   ├── bat/               # Bat syntax highlighter config & themes
│   │   ├── tealdeer/config.toml # Fast tldr client settings
│   │   └── vscode/settings.tera # VS Code settings (container sockets & themes)
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
To pull and apply the latest configurations on another computer where already initialized:
```bash
cd ~/Dev/mise-bootstrap
git pull
mise bootstrap
```

---

## Useful Commands

| Task | Command |
| :--- | :--- |
| **Check secrets availability** | `mise bootstrap secrets status` |
| **Inspect dotfiles status** | `mise bootstrap dotfiles status` |
| **Preview dotfile diffs** | `mise bootstrap dotfiles diff` |
| **Re-apply dotfiles only** | `mise bootstrap dotfiles apply` |
| **Full machine state check** | `mise bootstrap status` |
| **Simulate bootstrap apply** | `mise bootstrap --dry-run` |
| **Check auto-update timer** | `systemctl --user list-timers \| grep workstation` |
| **Run auto-update manually** | `systemctl --user start dev.mise.workstation-auto-update.service` |
| **Update all CLI tools** | `mise upgrade` |
| **Completely uninstall mise** | `mise implode` |
