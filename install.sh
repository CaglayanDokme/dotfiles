#!/bin/bash
set -e

if ! command -v stow &> /dev/null; then
    echo "stow could not be found. Please install stow to use this script." >&2

    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "git could not be found. Please install git to use this script." >&2

    exit 1
fi

if command -v zsh &> /dev/null; then
    if ! command -v curl &> /dev/null; then
        echo "curl could not be found. Please install curl to use zsh related tools." >&2
    else
        echo "Installing Oh My Zsh.."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

        echo "Installing Powerlevel10k theme.."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"

        echo "Installing zsh-syntax-highlighting plugin.."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
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