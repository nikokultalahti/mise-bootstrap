# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Ensure ~/.local/bin and ~/bin are in $PATH
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Activate mise
eval "$(mise activate bash)"

# Set Bitwarden SSH agent for dev containers
export SSH_AUTH_SOCK="$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
alias bw="flatpak run --command=bw com.bitwarden.desktop"

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
