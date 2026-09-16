# mise-bootstrap

A unified, declarative machine bootstrapper and dotfiles manager for **Fedora Silverblue** and **macOS**, powered entirely by [**mise**](https://mise.jdx.dev): a zero-sudo, cloud-native workflow that handles CLI tools, Flatpaks, system files, secrets, and dotfile templates.

---

## Architecture & Features

* **Zero-Sudo Bootstrap:** Initial installation runs entirely in user-space without upfront root privileges.
* **Full Flathub Migration:** Automatically prioritizes Flathub, migrates pre-existing Fedora Flatpaks (like Firefox) to full Flathub builds with complete codecs, and disables Fedora's Flatpak remote.
* **Native Secret Recovery:** Uses the Bitwarden Desktop Flatpak CLI (`flatpak run --command=bw ...`) to interactively authenticate and retrieve your `age` secret key during bootstrap.
* **Encrypted Secrets in Public Git:** Sensitive SSH host declarations and configurations are encrypted with `age` (`.ssh/config.age`), making this repository 100% safe to host as a public GitHub repo.
* **Declarative System Files (`[bootstrap.files]`):** Manages `/etc/rpm-ostreed.conf` directly from this repository and notifies `rpm-ostreed-automatic.timer` to stage background OS updates.
* **Continuous Bidirectional Sync:** Boots via anonymous HTTPS, places your decrypted SSH credentials, and then automatically flips the git origin to `git@github.com:...` to enable `mise-history` background autosyncing.


## Bootstrap process in Silverblue

1. Bootstrap
``` 
curl https://mise.run | sh
mise bootstrap --adopt nikokultalahti/mise-bootstrap
```
For work machine, run:
mise -E work bootstrap --adopt nikokultalahti/mise-bootstrap
```

2. Layering
```  
# Remove Firefox and Gnome Tour, layer in packages  
sudo rpm-ostree override remove firefox firefox-langpacks gnome-tour \
  --install code \
  --install distrobox \
  --install zsh \
  --install zsh-autosuggestions \
  --install zsh-syntax-highlighting \
  --install tmux
```
3. Reboot  
```systemctl reboot```

### Additional commands

Completely uninstall mise
```mise implode```