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
local ok_color="%{$FG[071]%}"
local err_color="%{$FG[167]%}"

_pacmandoh_pick() {
  if [[ $PACMANDOH_PRIVILEGED == yes ]]; then
    echo -n $2
  else
    echo -n $1
  fi
}

_pacmandoh_refresh_privileged() {
  if [[ $PACMANDOH_PRIV_PWD == $PWD ]]; then
    return
  fi

  PACMANDOH_PRIV_PWD=$PWD
  PACMANDOH_PRIVILEGED=no
  if [[ "$OSTYPE" == linux-gnu* ]]; then
    [[ $EUID -eq 0 ]] && PACMANDOH_PRIVILEGED=yes
  elif [[ "$OSTYPE" == darwin* ]]; then
    [[ ! -O $PWD ]] && PACMANDOH_PRIVILEGED=yes
  fi
}

_pacmandoh_git_cache_key() {
  local git_dir index_mtime

  git_dir=$(git rev-parse --git-dir 2>/dev/null) || return 1
  [[ -n $git_dir ]] || return 1
  [[ $git_dir != /* ]] && git_dir="$PWD/${git_dir#./}"
  git_dir=${git_dir:A}

  if [[ -f $git_dir/index ]]; then
    if [[ "$OSTYPE" == darwin* ]]; then
      index_mtime=$(stat -f %m "$git_dir/index" 2>/dev/null)
    else
      index_mtime=$(stat -c %Y "$git_dir/index" 2>/dev/null)
    fi
  else
    index_mtime=0
  fi

  print -r -- "$PWD:$index_mtime"
}

_pacmandoh_git_data() {
  local cache_key git_status

  cache_key=$(_pacmandoh_git_cache_key) || {
    PACMANDOH_GIT_BRANCH=""
    PACMANDOH_GIT_DIRTY=""
    PACMANDOH_GIT_STATUS_MSG=""
    PACMANDOH_GIT_AHEAD=0
    PACMANDOH_GIT_BEHIND=0
    PACMANDOH_GIT_CACHE_KEY=""
    return 1
  }

  if [[ $PACMANDOH_GIT_CACHE_KEY == $cache_key ]]; then
    return 0
  fi

  PACMANDOH_GIT_BRANCH=""
  PACMANDOH_GIT_DIRTY=""
  PACMANDOH_GIT_STATUS_MSG=""
  PACMANDOH_GIT_AHEAD=0
  PACMANDOH_GIT_BEHIND=0

  git_status="$(git --no-optional-locks status --porcelain=v1 --branch 2>/dev/null)" || {
    PACMANDOH_GIT_CACHE_KEY=""
    return 1
  }

  local -a git_status_lines
  IFS=$'\n' git_status_lines=(${(f)git_status})

  if [[ ${git_status_lines[1]} == '## '* ]]; then
    local branch_line=${git_status_lines[1]#'## '}

    PACMANDOH_GIT_BRANCH=${branch_line%%...*}
    PACMANDOH_GIT_BRANCH=${PACMANDOH_GIT_BRANCH%% \[*}

    if [[ $branch_line =~ '\[ahead ([0-9]+)' ]]; then
      PACMANDOH_GIT_AHEAD=$match[1]
    fi
    if [[ $branch_line =~ 'behind ([0-9]+)' ]]; then
      PACMANDOH_GIT_BEHIND=$match[1]
    fi
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

  PACMANDOH_GIT_CACHE_KEY=$cache_key
}

_pacmandoh_prompt_char() {
  if [[ -n $PACMANDOH_GIT_BRANCH ]]; then
    [[ -n $PACMANDOH_GIT_DIRTY ]] && echo -n 'øø' || echo -n '○'
  else
    echo -n ':>'
  fi
}

_pacmandoh_git_status_info() {
  [[ -n $PACMANDOH_GIT_STATUS_MSG ]] && echo -n "$1${reset}($PACMANDOH_GIT_STATUS_MSG )"
}

_pacmandoh_git_ahead_behind_info() {
  local msg=""

  [[ ${PACMANDOH_GIT_AHEAD:-0} -gt 0 ]] && msg+=" ${green}↑${PACMANDOH_GIT_AHEAD}${reset}"
  [[ ${PACMANDOH_GIT_BEHIND:-0} -gt 0 ]] && msg+=" ${red}↓${PACMANDOH_GIT_BEHIND}${reset}"
  [[ -n $msg ]] && echo -n "$msg"
}

_pacmandoh_git_info() {
  [[ -n $PACMANDOH_GIT_BRANCH ]] || return
  local dirty_msg=${ZSH_THEME_GIT_PROMPT_CLEAN}
  [[ -n $PACMANDOH_GIT_DIRTY ]] && dirty_msg=${ZSH_THEME_GIT_PROMPT_DIRTY}
  echo -n "${ZSH_THEME_GIT_PROMPT_PREFIX}${PACMANDOH_GIT_BRANCH}${dirty_msg}$(_pacmandoh_git_ahead_behind_info)${ZSH_THEME_GIT_PROMPT_SUFFIX}"
}

_pacmandoh_resolve_node_command() {
  local node_command=${commands[node]:-}

  if [[ -n $node_command && -x $node_command ]]; then
    print -r -- $node_command
    return 0
  fi

  [[ -n $NVM_DIR && -d $NVM_DIR/versions/node ]] || return 1

  if [[ -z $PACMANDOH_NVM_COMMAND_CACHE || $PACMANDOH_NVM_CACHE_DIR != $NVM_DIR || $PACMANDOH_NVM_PWD != $PWD ]]; then
    local nvm_version=""

    if [[ -f $PWD/.nvmrc ]]; then
      nvm_version="$(<$PWD/.nvmrc)"
    elif [[ -f $PWD/.node-version ]]; then
      nvm_version="$(<$PWD/.node-version)"
    elif [[ -f $NVM_DIR/alias/default ]]; then
      nvm_version="$(<$NVM_DIR/alias/default)"
    fi

    nvm_version=${nvm_version%%[[:space:]]*}
    [[ -n $nvm_version && $nvm_version != v* ]] && nvm_version="v$nvm_version"

    if [[ -z $nvm_version || ! -x $NVM_DIR/versions/node/$nvm_version/bin/node ]]; then
      local -a nvm_versions
      nvm_versions=($NVM_DIR/versions/node/v*(N/))
      nvm_version=${nvm_versions[-1]:t}
    fi

    if [[ -x $NVM_DIR/versions/node/$nvm_version/bin/node ]]; then
      PACMANDOH_NVM_COMMAND_CACHE="$NVM_DIR/versions/node/$nvm_version/bin/node"
    else
      PACMANDOH_NVM_COMMAND_CACHE=""
    fi
    PACMANDOH_NVM_CACHE_DIR=$NVM_DIR
    PACMANDOH_NVM_PWD=$PWD
  fi

  [[ -n $PACMANDOH_NVM_COMMAND_CACHE ]] && print -r -- $PACMANDOH_NVM_COMMAND_CACHE
}

_pacmandoh_node_version() {
  local node_command version_line

  node_command=$(_pacmandoh_resolve_node_command) || return 1

  if [[ -z $PACMANDOH_NODE_VERSION_CACHE || $PACMANDOH_NODE_COMMAND_CACHE != $node_command ]]; then
    version_line=$("$node_command" --version 2>/dev/null)
    version_line=${version_line//$'\n'/}
    version_line=${version_line#v}
    [[ -n $version_line ]] || return 1
    PACMANDOH_NODE_VERSION_CACHE=$version_line
    PACMANDOH_NODE_COMMAND_CACHE=$node_command
  fi

  [[ -n $PACMANDOH_NODE_VERSION_CACHE ]] || return 1
  print -r -- $PACMANDOH_NODE_VERSION_CACHE
}

_pacmandoh_env_conda_label() {
  [[ -n $CONDA_DEFAULT_ENV ]] || return 1
  echo -n "${reset}${magenta}${bold}🅒 ${CONDA_DEFAULT_ENV:t}${reset}"
}

_pacmandoh_env_venv_label() {
  [[ -n $VIRTUAL_ENV ]] || return 1
  echo -n "${reset}${bold}◎ ${VIRTUAL_ENV:t}${reset}"
}

_pacmandoh_env_node_label() {
  local node_version

  [[ -f package.json ]] || return 1
  node_version=$(_pacmandoh_node_version) || return 1
  [[ -n $node_version ]] || return 1
  echo -n "${reset}${bold}${dark_green}⬢ ${node_version}${reset}"
}

_pacmandoh_multiline_env_line() {
  local -a parts=()
  local label

  label=$(_pacmandoh_env_conda_label) && parts+=("[${label}${PACMANDOH_LINE_COLOR}]")
  label=$(_pacmandoh_env_venv_label) && parts+=("[${label}${PACMANDOH_LINE_COLOR}]")
  label=$(_pacmandoh_env_node_label) && parts+=("[${label}${PACMANDOH_LINE_COLOR}]")

  [[ ${#parts[@]} -eq 0 ]] && return 1

  echo -n "${PACMANDOH_LINE_COLOR}├─${(j:-:)parts}\n"
}

_pacmandoh_oneline_env_prefix() {
  local -a parts=()
  local label

  label=$(_pacmandoh_env_conda_label) && parts+=("(${label})")
  label=$(_pacmandoh_env_venv_label) && parts+=("(${label})")
  label=$(_pacmandoh_env_node_label) && parts+=("(${label})")

  [[ ${#parts[@]} -eq 0 ]] && return 1

  echo -n "${(j::)parts}"
}

_pacmandoh_box_name() {
  local box_file=$HOME/.box-name

  if [[ -f $box_file ]]; then
    local box_mtime
    if [[ "$OSTYPE" == darwin* ]]; then
      box_mtime=$(stat -f %m "$box_file" 2>/dev/null)
    else
      box_mtime=$(stat -c %Y "$box_file" 2>/dev/null)
    fi

    if [[ $PACMANDOH_BOX_CACHE_MTIME != $box_mtime || -z $PACMANDOH_BOX_CACHE ]]; then
      PACMANDOH_BOX_CACHE="$(<$box_file)"
      PACMANDOH_BOX_CACHE_MTIME=$box_mtime
    fi
    echo -n ${PACMANDOH_BOX_CACHE:gs/%/%%}
    return
  fi

  echo -n ${${SHORT_HOST:-$HOST}:gs/%/%%}
}

constructor() {
  _pacmandoh_refresh_privileged
  _pacmandoh_git_data

  PACMANDOH_LINE_COLOR=$(_pacmandoh_pick $reset $red)
  local root_info=$(_pacmandoh_pick $bold$blue $bold$red)
  local path_color=$(_pacmandoh_pick $bold$orange $reset$bold)
  local path_trunc='%(4~.%-1~/…/%3~.%3~)'
  local path_trunc_oneline='%(3~.…/%2~.%2~)'

  case $PACMANDOH_PROMPT_ALTERNATIVE in
  multiline)
    local icon=$(_pacmandoh_pick "@" " 💀 $reset$red")
    local env_line git_status_style prompt

    git_status_style=" $(_pacmandoh_pick $reset $blue)➜ "
    prompt="${PACMANDOH_LINE_COLOR}╭──(${root_info}%n${icon}$(_pacmandoh_box_name)${reset}${PACMANDOH_LINE_COLOR})$(_pacmandoh_git_info)$(_pacmandoh_git_status_info $git_status_style)\n${PACMANDOH_LINE_COLOR}├─[${path_color}${path_trunc}${reset}${PACMANDOH_LINE_COLOR}]"
    env_line=$(_pacmandoh_multiline_env_line)
    [[ -n $env_line ]] && prompt+="\n${env_line}"
    prompt+="\n${PACMANDOH_LINE_COLOR}╰${root_info}$(_pacmandoh_prompt_char)${reset} "
    echo -n "$prompt"
    ;;
  oneline)
    local icon=$(_pacmandoh_pick "" "💀 $reset$red$bold")
    local env_prefix=$(_pacmandoh_oneline_env_prefix)
    local arrow_ok=$bold$ok_color
    local arrow_err=$bold$err_color
    [[ -n $env_prefix ]] && env_prefix+=" "
    echo -n "${env_prefix}${root_info}${icon}%n$reset$(_pacmandoh_git_info) %(?:${arrow_ok}%1{➜%} :${arrow_err}%1{➜%} )$reset${PACMANDOH_LINE_COLOR}[${path_color}${path_trunc_oneline}${reset}${PACMANDOH_LINE_COLOR}] ─$reset${root_info}$(_pacmandoh_prompt_char)$reset "
    ;;
  esac
}

if [[ $PACMANDOH_NEED_TIMER == yes ]]; then
  zmodload zsh/datetime 2>/dev/null
fi

preexec() {
  [[ $PACMANDOH_PROMPT_ALTERNATIVE == oneline ]] && PACMANDOH_NEED_TIMER=no && PACMANDOH_NEWLINE_BEFORE_PROMPT=no
  [[ $PACMANDOH_NEED_TIMER == yes ]] && _COMMAND_TIME_BEGIN=$EPOCHREALTIME
}

precmd() {
  if [[ $PACMANDOH_NEED_TIMER == yes && -n $_COMMAND_TIME_BEGIN && $_COMMAND_TIME_BEGIN != "-20240101" ]]; then
    printf -v cost "%.3f" $(( EPOCHREALTIME - _COMMAND_TIME_BEGIN ))
    _COMMAND_TIME_BEGIN="-20240101"
  fi

  if [[ $PACMANDOH_NEWLINE_BEFORE_PROMPT == yes ]]; then
    if [[ -z "$_NEW_LINE_BEFORE_PROMPT" ]]; then
      _NEW_LINE_BEFORE_PROMPT=1
    else
      echo
    fi
  fi
}

_pacmandoh_status_box() {
  [[ -n $cost ]] && echo -n "[${cost}s $1]" || echo -n "[$1]"
}

_pacmandoh_rprompt() {
  case $PACMANDOH_PROMPT_ALTERNATIVE in
  oneline)
    echo -n '%(?.. %? %F{red}%B⨯%b%F{reset})%(1j. %j %F{yellow}%B⚙%b%F{reset}.)'
    ;;
  *)
    if [[ $PACMANDOH_NEED_TIMER == yes ]]; then
      echo -n "%(?:$bold$green$(_pacmandoh_status_box ✔)$reset :$bold$red$(_pacmandoh_status_box ✘)$reset )${gray}%*${reset}"
    else
      echo -n "%(?:$bold${green}[✔]$reset :$bold${red}[✘]$reset )${gray}%*${reset}"
    fi
    ;;
  esac
}

PROMPT='$(constructor)'
RPROMPT='$(_pacmandoh_rprompt)'
setopt promptsubst

ZSH_THEME_GIT_PROMPT_PREFIX=" ${gray}on$reset "
ZSH_THEME_GIT_PROMPT_SUFFIX=$reset
ZSH_THEME_GIT_PROMPT_DIRTY="${red}✘"
ZSH_THEME_GIT_PROMPT_CLEAN="${green}✔"
