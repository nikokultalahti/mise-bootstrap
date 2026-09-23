# Fedora Silverblue Install 

## System update

Update system
```bash
rpm-ostree upgrade
```

Update flatpaks
```bash
flatpak update
```

Update Firmware
```bash
fwupdmgr refresh --force
fwupdmgr get-devices
fwupdmgr get-updates
fwupdmgr update
```
Reboot
```bash
systemctl reboot
```

## Bootstrap

Run:
```bash <(curl -fsSL https://raw.githubusercontent.com/nikokultalahti/mise-bootstrap/main/bootstrap.sh)```

## RPM-Ostree

Remove and install layered packages
```bash
sudo rpm-ostree override remove firefox firefox-langpacks gnome-tour \
  --install=distrobox \
  --install=tmux \
  --install=code \
  --install=zsh \
  --install=zsh-autosuggestions \
  --install=zsh-syntax-highlighting \
```
Reboot
```bash
systemctl reboot
```

## Configure
- Set up Gnome Settings, incl. Ptyxis
- Set up Gnome Extensions
- Set up Firefox
- Set up Flatpaks
    - Enable Bitwarden SSH Agent
