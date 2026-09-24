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

# .gitconfig selects the identity with includeIf "hasconfig:...", which needs git >= 2.36.
# Ubuntu 22.04 ships 2.34 (e.g. the PetaLinux dev container): there the rules are silently
# ignored and no identity is configured at all. Upgrade from the git-core PPA when we can.
MIN_GIT_VERSION=2.36

upgrade_old_git() {
    local have arch codename ppa_list
    have="$(git --version | awk '{print $3}')"

    # sort -V puts the smaller version first; if MIN is not the smaller one, we already have >= MIN.
    if [[ "$(printf '%s\n%s\n' "${MIN_GIT_VERSION}" "${have}" | sort -V | head -1)" == "${MIN_GIT_VERSION}" ]]; then
        return 0
    fi

    echo "git ${have} is older than ${MIN_GIT_VERSION}; upgrading from the git-core PPA.."

    if ! command -v apt-get &> /dev/null || ! sudo -n true &> /dev/null; then
        warn "Cannot upgrade git here (no apt-get or no passwordless sudo); do it manually:"
        warn "  sudo add-apt-repository -y ppa:git-core/ppa && sudo apt-get install -y git"

        return 0
    fi

    # add-apt-repository imports the PPA key for us, but the source line it writes is not restricted
    # to an architecture. On an image with a foreign architecture enabled (e.g. the PetaLinux container
    # adds i386 for the Xilinx tools) apt then also requests the PPA's i386 index, Launchpad answers
    # 503, and apt drops the whole PPA - while apt-get update still exits 0 and git stays old.
    # So we own the source line: pinned to the native architecture and rewritten on every run
    # (add-apt-repository would otherwise append a second, unpinned line on each rerun).
    arch="$(dpkg --print-architecture)"
    codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
    ppa_list="/etc/apt/sources.list.d/git-core-ubuntu-ppa-${codename}.list"

    sudo -n DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends software-properties-common \
        && sudo -n add-apt-repository -y -n ppa:git-core/ppa \
        && echo "deb [arch=${arch}] https://ppa.launchpadcontent.net/git-core/ppa/ubuntu ${codename} main" \
            | sudo -n tee "${ppa_list}" > /dev/null \
        && sudo -n apt-get update -qq \
        && sudo -n DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends git \
        || warn "git upgrade failed; identity rules will not apply until git >= ${MIN_GIT_VERSION}."

    # apt-get update only warns when it drops a repository, and apt-get install is content with the
    # version already installed, so the chain above cannot detect a silent no-op. Verify the result.
    have="$(git --version | awk '{print $3}')"

    if [[ "$(printf '%s\n%s\n' "${MIN_GIT_VERSION}" "${have}" | sort -V | head -1)" != "${MIN_GIT_VERSION}" ]]; then
        warn "git is still ${have} after the upgrade attempt; identity rules will not apply until git >= ${MIN_GIT_VERSION}."
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
upgrade_old_git

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

        echo "Installing zsh-autosuggestions plugin.."
        git clone https://github.com/zsh-users/zsh-autosuggestions.git "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

        echo "Installing fzf.."
        git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/.fzf" && yes | "${HOME}/.fzf/install"
    fi
else
    echo "zsh could not be found, will not install zsh related tools." >&2
fi

cd "$(dirname "${BASH_SOURCE[0]}")"

# ssh refuses a group-writable config and sshd a group-writable ~/.ssh (umask here is 002).
mkdir -m 700 -p "${HOME}/.ssh"
chmod 600 .ssh/config

if stow --adopt --no-folding . > /dev/null; then
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
