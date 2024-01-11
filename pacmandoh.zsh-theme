#  _______________________________________________________________________________
# (  ____                                             ____            __          )
# ( /\  _`\                                          /\  _`\         /\ \         )
# ( \ \ \L\ \ __      ___    ___ ___      __      ___\ \ \/\ \    ___\ \ \___     )
# (  \ \ ,__/'__`\   /'___\/' __` __`\  /'__`\  /' _ `\ \ \ \ \  / __`\ \  _ `\   )
# (   \ \ \/\ \L\.\_/\ \__//\ \/\ \/\ \/\ \L\.\_/\ \/\ \ \ \_\ \/\ \L\ \ \ \ \ \  )
# (    \ \_\ \__/.\_\ \____\ \_\ \_\ \_\ \__/.\_\ \_\ \_\ \____/\ \____/\ \_\ \_\ )
# (     \/_/\/__/\/_/\/____/\/_/\/_/\/_/\/__/\/_/\/_/\/_/\/___/  \/___/  \/_/\/_/ )
# (                                                                               )
# (                                                                               )
#  -------------------------------------------------------------------------------

# OPTIONALS
PACMANDOH_PROMPT_ALTERNATIVE=multiline # multiline | oneline
PACMANDOH_NEED_TIMER=yes
PACMANDOH_NEWLINE_BEFORE_PROMPT=yes

#%%=================================================================================%%#

# color
local reset="%{$reset_color%}"
local bold="%{$terminfo[bold]%}"
local blue="%{$fg[blue]%}"
local red="%{$fg[red]%}"
local magenta="%{$fg[magenta]%}"
local green="%{$fg[green]%}"
local dark_green="%{$FG[022]%}"
local light_green="%{$FG[082]%}"
local orange="%{$FG[202]%}"
local gray="%{$FG[242]%}"
local yellow="%{$FG[226]%}"

constructor() {
  get() {
    local items=$1
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
      [[ $EUID -eq 0 ]] && items=$2
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      [[ ! -O $(pwd) ]] && items=$2
    fi
    echo -n $items
  }

  prompt_char() {
    if git branch >/dev/null 2>/dev/null; then
      if [[ -n $(git status --porcelain) ]]; then
        echo -n 'øø'
      else
        echo -n '○'
      fi
    else
      echo -n ':>'
    fi
  }

  # Without using vcs_info, write it through `git status`
  git_status_info() {
    if git branch >/dev/null 2>/dev/null; then
      local -a git_status
      IFS=$'\n' git_status=($(git status --porcelain))

      local -A count=(modified 0 added 0 deleted 0 untracked 0 renamed 0 conflicted 0)
      local -A status_color=(modified $orange added $light_green deleted $red untracked $green renamed $reset conflicted $red)
      local -A status_symbol=(modified M added A deleted D untracked U renamed R conflicted "!C")

      for line in "${git_status[@]}"; do
        local gstatus="${line[1, 2]}"
        case $gstatus in
        ' M') ((count[modified]++)) ;;
        'MM') ((count[modified]++)) ;;
        'A ') ((count[added]++)) ;;
        ' D') ((count[deleted]++)) ;;
        '??') ((count[untracked]++)) ;;
        'R ') ((count[renamed]++)) ;;
        'C ') ((count[conflicted]++)) ;;
        *) ;;
        esac
      done

      local git_info_msg
      for k v (${(kv)count}) {
        if [[ ${count[$k]} -gt 0 ]]; then
          git_info_msg+=" ${status_color[$k]}${status_symbol[$k]}:${count[$k]}$reset"
        fi
      }

      local git_box=""
      [[ -n $git_info_msg ]] && git_box="$1${reset}($git_info_msg )"
      echo -n "$git_box"
    fi
  }

  utils() {
    if [[ -n $1 ]]; then
      local basestr="$(basename $1)"
      echo -n "${line_color}$2$basestr$reset${line_color}$3"
    fi
  }

  utils_is_project() {
    if [[ -f $1 ]]; then
      echo -n "$(utils $2 $3 $4)"
    fi
  }

  box_name() {
    local box="${SHORT_HOST:-$HOST}"
    [[ -f ~/.box-name ]] && box="$(< ~/.box-name)"
    echo "${box:gs/%/%%}"
  }
    
  local line_color=$(get $reset $yellow)
  local root_info=$(get $bold$blue $bold$red)
  local path_color=$(get $bold$orange $reset$bold)
  case $PACMANDOH_PROMPT_ALTERNATIVE in
  multiline)
    local icon=$(get " $reset${gray}at $blue" " 💀 $reset$red")
    local conda_info=$(utils "$CONDA_DEFAULT_ENV" "-($magenta${bold}🅒 " ")$reset")
    local virtualenv_info=$(utils "$VIRTUAL_ENV" "($reset${bold}📦 " ")-$reset")
    local node_info=$(utils_is_project "package.json" "$(node --version 2>/dev/null)" "- [${bold}${dark_green}⬢ " "]$reset")
    local git_status_style=" $(get $reset $blue)➜ "
    echo -n "${line_color}╭──($root_info%n$icon$(box_name)$reset${line_color})$conda_info$(git_prompt_info)$(git_status_info $git_status_style)\n${line_color}├ %(?:$bold${green}➜ :$bold${red}➜ )$reset${line_color}{$path_color%~$reset${line_color}} ${node_info}\n${line_color}╰$virtualenv_info$root_info$(prompt_char)$reset "
    ;;
  oneline)
    local icon=$(get "" "💀$reset$red$bold")
    local conda_info=$(utils "$CONDA_DEFAULT_ENV" " ${gray}using$magenta${bold} " "$reset")
    local virtualenv_info=$(utils "$VIRTUAL_ENV" " ${gray}using$reset${bold} " "$reset")
    local node_info=$(utils_is_project "package.json" "$(node --version 2>/dev/null)" "(${bold}${dark_green}" ") $reset")
    local git_status_style=" "
    echo -n "$node_info$root_info$icon%n$reset$conda_info${virtualenv_info}$(git_status_info $git_status_style)$(git_prompt_info) %(?:$bold${green}➜ :$bold${red}➜ )${reset}[$path_color%~$reset${line_color}] ─$(prompt_char)$reset "
    ;;
  esac
}

if [[ $PACMANDOH_NEED_TIMER == yes ]]; then
  _current_time_millis() {
    local time_millis
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
      time_millis="$(date +%s.%3N)"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      # TODO Solve the problem of performance degradation and visible delay caused by calling ruby
      time_millis="$(ruby -e 'puts Time.now.strftime("%s.%3N")')" # Since MacOS catalina, MacOS has built-in Ruby
    fi
    echo -n $time_millis
  }

  status_box() {
    local box=""
    [[ -n $cost ]] && box="[${1}s $2]"
    echo -n "$box"
  }
fi

check_exit_status() {
  if [[ $PACMANDOH_NEED_TIMER == yes ]]; then
    echo -n "%(?:$bold$green$(status_box $cost ✔)$reset :$bold$red$(status_box $cost ✘)$reset )"
  else
    echo -n "%(?:$bold${green}[✔]$reset :$bold${red}[✘]$reset )"
  fi
}

preexec() {
  [[ $PACMANDOH_PROMPT_ALTERNATIVE == oneline ]] && PACMANDOH_NEED_TIMER=no && PACMANDOH_NEWLINE_BEFORE_PROMPT=no
  [[ $PACMANDOH_NEED_TIMER == yes ]] && _COMMAND_TIME_BEGIN=$(_current_time_millis)
}

precmd() {
  if [[ $PACMANDOH_NEED_TIMER == yes ]]; then
    command_execute_after() {
      if [[ $_COMMAND_TIME_BEGIN = "-20240101" ]] || [[ $_COMMAND_TIME_BEGIN = "" ]]; then
        return 1
      fi

      local time_end=$(_current_time_millis)
      cost=$(bc -l <<<"${time_end}-${_COMMAND_TIME_BEGIN}")
      _COMMAND_TIME_BEGIN="-20240101"
      local length_cost=${#cost}
      if [ "$length_cost" = "4" ]; then
        cost="0${cost}"
      fi
    }
    command_execute_after
  fi

  if [[ $PACMANDOH_NEWLINE_BEFORE_PROMPT == yes ]]; then
    if [[ -z "$_NEW_LINE_BEFORE_PROMPT" ]]; then
      _NEW_LINE_BEFORE_PROMPT=1
    else
      echo
    fi
  fi
}

_RPROMPT_ALTERNATIVE() {
  case $PACMANDOH_PROMPT_ALTERNATIVE in
  multiline)
    echo -n "$(check_exit_status)${bold}❮֍ %*❯$reset"
    ;;
  oneline)
    echo -n "%(?.. %? %F{red}%B⨯%b%F{reset})%(1j. %j %F{yellow}%B⚙%b%F{reset}.)"
    ;;
  esac
}

PROMPT="\$(constructor)"
RPROMPT="\$(_RPROMPT_ALTERNATIVE)"

ZSH_THEME_GIT_PROMPT_PREFIX=" ${gray}on$reset "
ZSH_THEME_GIT_PROMPT_SUFFIX=$reset
ZSH_THEME_GIT_PROMPT_DIRTY="${red}✘✘✘"
ZSH_THEME_GIT_PROMPT_CLEAN="${green}✔"

#%%=================================================================================%%#
# ZSH CONFIG OPTIONALS
# by Kali Linux

#  _  __     _ _
# | |/ /__ _| (_)
# | ' // _` | | |
# | . \ (_| | | |
# |_|\_\__,_|_|_|
#

setopt autocd              # change directory just by typing its name
#setopt correct            # auto correct mistakes
setopt interactivecomments # allow comments in interactive mode
setopt magicequalsubst     # enable filename expansion for arguments of the form ‘anything=expression’
setopt nonomatch           # hide error message if there is no match for the pattern
setopt notify              # report the status of background jobs immediately
setopt numericglobsort     # sort filenames numerically when it makes sense
setopt promptsubst         # enable command substitution in prompt

WORDCHARS=${WORDCHARS//\/} # Don't consider certain characters part of the word

# configure key keybindings
bindkey -e                                        # emacs key bindings
bindkey ' ' magic-space                           # do history expansion on space
bindkey '^U' backward-kill-line                   # ctrl + U
bindkey '^[[3;5~' kill-word                       # ctrl + Supr
bindkey '^[[3~' delete-char                       # delete
bindkey '^[[1;5C' forward-word                    # ctrl + ->
bindkey '^[[1;5D' backward-word                   # ctrl + <-
bindkey '^[[5~' beginning-of-buffer-or-history    # page up
bindkey '^[[6~' end-of-buffer-or-history          # page down
bindkey '^[[H' beginning-of-line                  # home
bindkey '^[[F' end-of-line                        # end
bindkey '^[[Z' undo                               # shift + tab undo last action

# enable completion features
autoload -Uz compinit
compinit -d ~/.cache/zcompdump
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# History configurations
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=2000
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
#setopt share_history         # share command history data

# some more ls aliases
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'
