#!/bin/bash
set -e

# These dotfiles are self-sufficient: they acquire the tools they need rather than expecting a
# host or a container image to provide them.
REQUIRED_TOOLS=(git stow zsh curl)

warn() {
    echo "$@" >&2
}

# Install whatever is missing, but never at the cost of failing the whole install: a dotfiles
# failure is silent in a dev container, so it is better to degrade and keep going. On a machine
# that already has these tools this is a no-op.
install_missing_tools() {
    local tool
    local missing=()

    for tool in "${REQUIRED_TOOLS[@]}"; do
        command -v "${tool}" &> /dev/null || missing+=("${tool}")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi

    echo "Missing tools: ${missing[*]}"

    if ! command -v apt-get &> /dev/null; then
        warn "No apt-get available; install ${missing[*]} manually for the full setup."

        return 1
    fi

    echo "Installing ${missing[*]}.."

    if ! sudo -n apt-get update -qq; then
        warn "apt-get update failed; skipping installation of ${missing[*]}."

        return 0
    fi

    if ! sudo -n DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "${missing[@]}"; then
        warn "Failed to install ${missing[*]}; continuing without them."
    fi
}

# The dev container image no longer sets a login shell for us, and the Oh My Zsh installer is run
# with --unattended below, which suppresses its own chsh. So do it here, for this account only.
# Plain chsh cannot work where the account has no password (PAM rejects it), hence sudo.
use_zsh_as_login_shell() {
    local zsh_path user_name

    zsh_path="$(command -v zsh)"
    user_name="$(id -un)"

    echo "Setting ${zsh_path} as the login shell.."

    if ! sudo -n chsh -s "${zsh_path}" "${user_name}" &> /dev/null; then
        warn "Could not set zsh as the login shell; do it manually with 'chsh -s ${zsh_path}'."
    fi
}

install_missing_tools

if ! command -v stow &> /dev/null; then
    echo "stow could not be found. Please install stow to use this script." >&2

    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "git could not be found. Please install git to use this script." >&2

    exit 1
fi

if command -v zsh &> /dev/null; then
    use_zsh_as_login_shell

    if ! command -v curl &> /dev/null; then
        echo "curl could not be found. Please install curl to use zsh related tools." >&2
    else
        echo "Installing Oh My Zsh.."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

        echo "Installing Powerlevel10k theme.."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"

        echo "Installing zsh-syntax-highlighting plugin.."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

        echo "Installing fzf.."
        git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/.fzf" && yes | "${HOME}/.fzf/install"
    fi
else
    echo "zsh could not be found, will not install zsh related tools." >&2
fi

cd "$(dirname "${BASH_SOURCE[0]}")"

if stow --adopt . > /dev/null; then
    echo "Successfully stowed dotfiles."
else
    echo "Failed to stow dotfiles!" >&2
    exit 1
fi

if git restore .; then
    echo "Successfully restored .git directory."
else
    echo "Failed to restore .git directory!" >&2

    exit 1
fi

echo "Dotfiles installation complete!"
exit 0

# For the origin of adopted approach, see https://www.reddit.com/r/linux4noobs/comments/b5ig2h/comment/igmv8pp/
