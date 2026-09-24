# ~/.zprofile -- zsh reads this for login shells only, BEFORE ~/.zshrc.  That is
# the point: the powerlevel10k instant-prompt block at the top of .zshrc redirects
# stdout/stderr into a file and later complains about "console output during zsh
# initialization"; output produced here reaches the terminal first and stays
# above the prompt.
#
# Nothing may be printed unless every guard passes: VS Code's Remote-SSH
# bootstrap and tmux also start login shells, and stray output there breaks a
# protocol or repeats the banner in every pane.  Guards:
#   interactive, tty on stdin/stdout   a human on a terminal, not `ssh host cmd`
#   SSH_CONNECTION set                 reached over SSH (console/su logins stay quiet)
#   TMUX unset                         tmux panes are login shells too
#   TERM_PROGRAM != vscode             VS Code terminals, even if made login shells
#   TERM != dumb                       Emacs TRAMP and friends
#   no /.dockerenv                     these dotfiles are stowed inside dev containers
#   SHLVL == 1                         the shell sshd started, not a nested `zsh -l`
# Redisplay any time with `welcome` (no --login: does not touch the bookkeeping).
if [[ -o interactive && -t 0 && -t 1 ]] &&
   [[ -n ${SSH_CONNECTION-} && -z ${TMUX-} ]] &&
   [[ ${TERM_PROGRAM-} != vscode && ${TERM-} != dumb && ! -e /.dockerenv ]] &&
   (( SHLVL == 1 )) &&
   [[ -x ${HOME}/.local/bin/welcome ]]; then
  "${HOME}/.local/bin/welcome" --login
fi
