export ZSH="$HOME/.oh-my-zsh"

ZSH=~/.oh-my-zsh
ZSH_CUSTOM=~/.zsh-custom
ZSH_THEME=bira
ZSH_COLORIZE_CHROMA_FORMATTER=terminal256

plugins=(
  brew git golang vi-mode kubectl kubectx
)

source $ZSH/oh-my-zsh.sh

# bigger history
HISTSIZE=10000000
SAVEHIST=10000000


# -- START: set show-mode-in-prompt --
function zle-keymap-select zle-line-init
{
    # change cursor shape in iTerm2
    case $KEYMAP in
        vicmd)      print -n -- "\E]50;CursorShape=0\C-G";;  # block cursor
        viins|main) print -n -- "\E]50;CursorShape=1\C-G";;  # line cursor
    esac

    zle reset-prompt
    zle -R
}

function zle-line-finish
{
    print -n -- "\E]50;CursorShape=0\C-G"  # block cursor
}

zle -N zle-line-init
zle -N zle-line-finish
zle -N zle-keymap-select
# -- END: set show-mode-in-prompt --

#bindkey "^R" history-incremental-search-backward
#bindkey "^P" history-beginning-search-backward
#bindkey "^N" history-beginning-search-forward
bindkey -M viins 'jk' vi-cmd-mode
export KEYTIMEOUT=20

# homebrew
export HOMEBREW_NO_ANALYTICS=1
