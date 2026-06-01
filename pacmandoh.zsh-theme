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

  _pacmandoh_git_data() {
    PACMANDOH_GIT_BRANCH=""
    PACMANDOH_GIT_DIRTY=""
    PACMANDOH_GIT_STATUS_MSG=""

    local git_status
    git_status="$(git status --porcelain=v1 --branch 2>/dev/null)" || return 1

    local -a git_status_lines
    IFS=$'\n' git_status_lines=(${(f)git_status})

    if [[ ${git_status_lines[1]} == '## '* ]]; then
      PACMANDOH_GIT_BRANCH=${git_status_lines[1]#'## '}
      PACMANDOH_GIT_BRANCH=${PACMANDOH_GIT_BRANCH%%...*}
      PACMANDOH_GIT_BRANCH=${PACMANDOH_GIT_BRANCH%% \[*}
    fi

    local -A count=(modified 0 added 0 deleted 0 untracked 0 renamed 0 conflicted 0)
    local line index_status worktree_status
    for line in "${git_status_lines[@]:1}"; do
      [[ -z $line ]] && continue
      PACMANDOH_GIT_DIRTY=1

      index_status=${line[1,1]}
      worktree_status=${line[2,2]}

      if [[ $index_status == U || $worktree_status == U || $index_status$worktree_status == (AA|DD) ]]; then
        ((count[conflicted]++))
        continue
      fi

      [[ $line == '??'* ]] && ((count[untracked]++)) && continue
      [[ $index_status == R ]] && ((count[renamed]++))
      [[ $index_status == A ]] && ((count[added]++))
      [[ $index_status == M || $worktree_status == M ]] && ((count[modified]++))
      [[ $index_status == D || $worktree_status == D ]] && ((count[deleted]++))
    done

    local -A status_color=(modified $orange added $light_green deleted $red untracked $green renamed $reset conflicted $red)
    local -A status_symbol=(modified M added A deleted D untracked U renamed R conflicted "!C")
    local k
    for k in modified added deleted untracked renamed conflicted; do
      if [[ ${count[$k]} -gt 0 ]]; then
        PACMANDOH_GIT_STATUS_MSG+=" ${status_color[$k]}${status_symbol[$k]}:${count[$k]}$reset"
      fi
    done
  }

  prompt_char() {
    if [[ -n $PACMANDOH_GIT_BRANCH ]]; then
      [[ -n $PACMANDOH_GIT_DIRTY ]] && echo -n 'øø' || echo -n '○'
    else
      echo -n ':>'
    fi
  }

  git_status_info() {
    [[ -n $PACMANDOH_GIT_STATUS_MSG ]] && echo -n "$1${reset}($PACMANDOH_GIT_STATUS_MSG )"
  }

  git_info() {
    [[ -n $PACMANDOH_GIT_BRANCH ]] || return
    local dirty_msg=${ZSH_THEME_GIT_PROMPT_CLEAN}
    [[ -n $PACMANDOH_GIT_DIRTY ]] && dirty_msg=${ZSH_THEME_GIT_PROMPT_DIRTY}
    echo -n "${ZSH_THEME_GIT_PROMPT_PREFIX}${PACMANDOH_GIT_BRANCH}${dirty_msg}${ZSH_THEME_GIT_PROMPT_SUFFIX}"
  }

  node_prompt_info() {
    [[ -f package.json ]] || return

    local node_command=$commands[node]
    if [[ -z $node_command && -n $NVM_DIR && -d $NVM_DIR/versions/node ]]; then
      local nvm_version=""
      if [[ -f $NVM_DIR/alias/default ]]; then
        nvm_version="$(<$NVM_DIR/alias/default)"
        nvm_version=${nvm_version%%[[:space:]]*}
        [[ $nvm_version != v* ]] && nvm_version="v$nvm_version"
      fi

      if [[ -z $nvm_version || ! -x $NVM_DIR/versions/node/$nvm_version/bin/node ]]; then
        local -a nvm_versions
        nvm_versions=($NVM_DIR/versions/node/v*(N/))
        nvm_version=${nvm_versions[-1]:t}
      fi

      [[ -x $NVM_DIR/versions/node/$nvm_version/bin/node ]] && node_command="$NVM_DIR/versions/node/$nvm_version/bin/node"
    fi

    [[ -n $node_command ]] || return
    if [[ -z $PACMANDOH_NODE_VERSION_CACHE || $PACMANDOH_NODE_COMMAND_CACHE != $node_command ]]; then
      PACMANDOH_NODE_VERSION_CACHE=${$($node_command --version 2>/dev/null)#v}
      PACMANDOH_NODE_COMMAND_CACHE=$node_command
    fi
    local node_prompt=$PACMANDOH_NODE_VERSION_CACHE
    echo "${ZSH_THEME_NVM_PROMPT_PREFIX}${node_prompt:gs/%/%%}${ZSH_THEME_NVM_PROMPT_SUFFIX}"
  }

  utils() {
    if [[ -n $1 ]]; then
      local basestr="${1:t}"
      echo -n "${line_color}$2$basestr$reset${line_color}$3"
    fi
  }

  utils_is_project() {
    if [[ -f $1 ]]; then
      local value="$($2)"
      [[ -n $value ]] && echo -n "$(utils $value $3 $4)"
    fi
  }

  box_name() {
    local box="${SHORT_HOST:-$HOST}"
    [[ -f ~/.box-name ]] && box="$(< ~/.box-name)"
    echo "${box:gs/%/%%}"
  }
    
  _pacmandoh_git_data

  local line_color=$(get $reset $yellow)
  local root_info=$(get $bold$blue $bold$red)
  local path_color=$(get $bold$orange $reset$bold)
  case $PACMANDOH_PROMPT_ALTERNATIVE in
  multiline)
    local icon=$(get " $reset${gray}at $blue" " 💀 $reset$red")
    local conda_info=$(utils "$CONDA_DEFAULT_ENV" "-($magenta${bold}🅒 " ")$reset")
    local virtualenv_info=$(utils "$VIRTUAL_ENV" "($reset${bold}📦 " ")-$reset")
    local node_info=$(utils_is_project "package.json" node_prompt_info "- [${bold}${dark_green}⬢ " "]$reset")
    local git_status_style=" $(get $reset $blue)➜ "
    echo -n "${line_color}╭──($root_info%n$icon$(box_name)$reset${line_color})$conda_info$(git_info)$(git_status_info $git_status_style)\n${line_color}├ %(?:$bold${light_green}➜ :$bold${red}➜ )$reset${line_color}{$path_color%~$reset${line_color}} ${node_info}\n${line_color}╰$virtualenv_info$root_info$(prompt_char)$reset "
    ;;
  oneline)
    local icon=$(get "" "💀$reset$red$bold")
    local conda_info=$(utils "$CONDA_DEFAULT_ENV" " ${gray}using$magenta${bold} " "$reset")
    local virtualenv_info=$(utils "$VIRTUAL_ENV" " ${gray}using$reset${bold} " "$reset")
    local node_info=$(utils_is_project "package.json" node_prompt_info "(${bold}${dark_green}" ") $reset")
    local git_status_style=" "
    echo -n "$node_info$root_info$icon%n$reset$conda_info${virtualenv_info}$(git_status_info $git_status_style)$(git_info) %(?:$bold${light_green}➜ :$bold${red}➜ )${reset}${line_color}[$path_color%~$reset${line_color}] ─$reset$root_info$(prompt_char)$reset "
    ;;
  esac
}

if [[ $PACMANDOH_NEED_TIMER == yes ]]; then
  zmodload zsh/datetime 2>/dev/null

  _current_time_millis() {
    echo -n "$EPOCHREALTIME"
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
      printf -v cost "%.3f" $(( time_end - _COMMAND_TIME_BEGIN ))
      _COMMAND_TIME_BEGIN="-20240101"
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
setopt promptsubst

ZSH_THEME_GIT_PROMPT_PREFIX=" ${gray}on$reset "
ZSH_THEME_GIT_PROMPT_SUFFIX=$reset
ZSH_THEME_GIT_PROMPT_DIRTY="${red}✘✘✘"
ZSH_THEME_GIT_PROMPT_CLEAN="${green}✔"
