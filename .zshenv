# ~/.zshenv - read by EVERY zsh: login, interactive, `zsh -c`, `ssh int-devenv2 cmd`, the
# VS Code Remote-SSH bootstrap and its `zsh -ilc` environment resolver. Keep it tiny,
# silent and builtin-only.

# Ubuntu's /etc/zsh/zshrc runs compinit unless this is set; Oh My Zsh runs its own.
skip_global_compinit=1

# One copy of each PATH entry even when shells nest (tmux panes, VS Code terminals).
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/.fzf/bin" $path)

export EDITOR=nano VISUAL=nano

# Fall back to the systemd user agent (ssh-agent.socket, socket-activated) when no live
# agent is inherited. A forwarded laptop agent keeps precedence; a dead forwarded socket
# (tmux re-attach, VS Code reconnect) is replaced by the local one.
if [[ ! -S ${SSH_AUTH_SOCK:-} ]]; then
  _sock="${XDG_RUNTIME_DIR:-/run/user/$UID}/openssh_agent"
  [[ -S $_sock ]] && export SSH_AUTH_SOCK="$_sock"
  unset _sock
fi
