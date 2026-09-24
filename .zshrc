# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-${HOME}/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-${HOME}/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Nothing below may print or prompt: VS Code resolves the extension-host environment by
# running `zsh -ilc` without a tty, and p10k's instant prompt flags any early output.
# Environment (PATH, EDITOR, SSH_AUTH_SOCK) lives in ~/.zshenv; the login banner in ~/.zprofile.

# Path to your Oh My Zsh installation.
export ZSH="${HOME}/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

# Update Oh My Zsh silently every 13 days. The default mode asks "[Y/n]" at shell start,
# which the instant prompt cannot show (check_for_upgrade.sh forces auto mode silent).
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 13

# `history` shows ISO timestamps. Read by lib/history.zsh, so it must be set before OMZ loads.
HIST_STAMPS="yyyy-mm-dd"

# fzf: with ~/.fzf/bin on PATH (from ~/.zshenv) the plugin runs `fzf --zsh`, which binds
# ^R (history), ^T (files), Alt-C (cd) and **<Tab> (fzf-completion). Nothing else may
# initialise fzf. zsh-autosuggestions is a custom plugin cloned by install.sh next to
# zsh-syntax-highlighting.
plugins=(git fzf copyfile isodate last-working-dir ssh zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# ---- User configuration ---------------------------------------------------------------

# History: keep everything, once (OMZ already sets extended_history, share_history, ...).
HISTSIZE=100000
SAVEHIST=$HISTSIZE
setopt hist_ignore_all_dups hist_save_no_dups hist_reduce_blanks

# Ubuntu's "command not found" package hints (OMZ does not source this).
[[ -r /etc/zsh_command_not_found ]] && source /etc/zsh_command_not_found

# Clipboard over SSH via OSC 52 (Windows Terminal, iTerm2, kitty, WezTerm, recent VS Code).
# Replaces the lazy stubs from OMZ lib/clipboard.zsh, which find no backend on a headless VM
# (both must be overridden: the stub clippaste would otherwise re-run detect-clipboard and
# clobber a lone clipcopy override). Inside tmux, `load-buffer -w` fills a tmux buffer and
# forwards to the outer terminal; that needs `set -s set-clipboard on` from ~/.tmux.conf.
# `copyfile <file>` from the copyfile plugin uses clipcopy.
function clipcopy() {
  emulate -L zsh
  if [[ -n ${TMUX:-} ]]; then
    tmux load-buffer -w "${1:--}"
  else
    printf '\033]52;c;%s\a' "$(base64 -w0 < "${1:-/dev/stdin}")" > /dev/tty
  fi
}
function clippaste() {
  print -u2 "clippaste: terminals do not expose the clipboard to remote hosts; paste with the terminal."
  return 1
}

# ls with colors and hyperlinks(click on file names to open them in the default application)
alias ls='ls --color=auto --hyperlink=auto'
# Ubuntu ships bat as batcat
(( $+commands[bat] )) || alias bat='batcat'

# tmux: attach to (or create) a named session, default "main".
ta() { tmux new-session -A -s "${1:-main}"; }

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Must be the last thing sourced: wraps the ZLE widgets defined above (fzf, autosuggestions).
source "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
