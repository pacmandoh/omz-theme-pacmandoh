#!/usr/bin/env bash

#                                               _________     ______
# ______________ _____________ _________ _____________  /________  /_
# ___  __ \  __ `/  ___/_  __ `__ \  __ `/_  __ \  __  /_  __ \_  __ \
# __  /_/ / /_/ // /__ _  / / / / / /_/ /_  / / / /_/ / / /_/ /  / / /
# _  .___/\__,_/ \___/ /_/ /_/ /_/\__,_/ /_/ /_/\__,_/  \____//_/ /_/
# /_/

DRY_RUN=no
VERBOSE=no
for arg in "$@"; do
  case "$arg" in
  -n | --dry-run)
    DRY_RUN=yes
    ;;
  -v | --verbose)
    VERBOSE=yes
    ;;
  -h | --help)
    printf "Usage: %s [--dry-run] [--verbose]\n" "$0"
    exit 0
    ;;
  esac
done

#%% ============= utils ============= %%#
is_dry_run() {
  [ "$DRY_RUN" == yes ]
}

dry_run_msg() {
  printf "\033[1m[dry-run]\033[0m %s\n" "$*"
}

is_verbose() {
  [ "$VERBOSE" == yes ]
}

step_msg() {
  printf "\n\033[1m[%s/5] %s\033[0m\n" "$1" "$2"
}

task_msg() {
  printf "  %s... " "$*"
}

task_done() {
  printf "\033[92mdone\033[0m\n"
}

task_skip() {
  printf "\033[93mskipped\033[0m\n"
}

task_fail() {
  printf "\033[91mfailed\033[0m\n"
}

run_logged() {
  local log_file

  log_file=$(mktemp "${TMPDIR:-/tmp}/pacmandoh-install.XXXXXX.log") || return 1
  if is_verbose; then
    "$@"
  else
    "$@" >"$log_file" 2>&1
  fi
  local status=$?

  if [ $status -ne 0 ] && ! is_verbose; then
    printf "\033[1mCommand failed. Log: %s\033[0m\n" "$log_file"
    tail -n 20 "$log_file"
  elif [ $status -eq 0 ] && ! is_verbose; then
    rm -f "$log_file"
  fi

  return $status
}

select_option() {
  choices=()
  is_multi=no
  for choice in "$@"; do
    if [ "$choice" == "multi" ]; then
      is_multi=yes
    else
      choices+=("$choice")
    fi
  done

  selected=0
  multi_selected=()
  tput sc

  while true; do
    tput rc
    for index in "${!choices[@]}"; do
      is_selected=no
      for picked in "${multi_selected[@]}"; do
        [ "$picked" == "$index" ] && is_selected=yes
      done

      if [ "$is_selected" == yes ]; then
        if [ "$index" -eq $selected ]; then
          printf "\033[1m\033[4m\033[34m\u25CF %s\033[0m\n" "${choices[$index]}"
        else
          printf "\033[1m\033[34m\u25CF %s\033[0m\n" "${choices[$index]}"
        fi
      elif [ "$index" -eq $selected ]; then
        if [ "$is_multi" == yes ]; then
          if [ "$selected" -eq "$((${#choices[@]} - 1))" ]; then
            printf "\033[1m\033[4m\033[92m✔ \033[34m%s\033[0m\n" "${choices[$index]}"
          else
            printf "\033[4m\033[34m○ %s\033[0m\n" "${choices[$index]}"
          fi
        else
          printf "\033[1m\033[4m\033[34m\u25CF %s\033[0m\n" "${choices[$index]}"
        fi
      else
        echo -e "○ ${choices[$index]}"
      fi
    done

    read -rn1 -s key
    case "$key" in
    A)
      if [ $selected -gt 0 ]; then
        selected=$((selected - 1))
      fi
      ;;
    B)
      if [ $selected -lt $((${#choices[@]} - 1)) ]; then
        selected=$((selected + 1))
      fi
      ;;
    "")
      if [ "$is_multi" == yes ]; then
        selected_is_picked=no
        for picked in "${multi_selected[@]}"; do
          [ "$picked" == "$selected" ] && selected_is_picked=yes
        done

        if [ "${choices[$selected]}" == "apply" ]; then
          break
        elif [ "${choices[$selected]}" == "none" ]; then
          multi_selected=()
          break
        elif [ "${choices[$selected]}" == "all" ]; then
          multi_selected=()
          for index in "${!choices[@]}"; do
            [ "${choices[$index]}" == "all" ] && continue
            [ "${choices[$index]}" == "none" ] && continue
            [ "${choices[$index]}" == "apply" ] && continue
            multi_selected+=("$index")
          done
          break
        else
          if [ "$selected_is_picked" == yes ]; then
            next_multi_selected=()
            for picked in "${multi_selected[@]}"; do
              [ "$picked" != "$selected" ] && next_multi_selected+=("$picked")
            done
            multi_selected=("${next_multi_selected[@]}")
          else
            multi_selected+=("$selected")
          fi
        fi
      else
        break
      fi
      ;;
    esac
  done

  if [ "$is_multi" == yes ]; then
    multi_selected_option=()
    for index in "${multi_selected[@]}"; do
      multi_selected_option+=("${choices[$index]}")
    done
  else
    selected_option="${choices[$selected]}"
  fi
  tput rc && tput ed
}

set_zshrc_value() {
  local key=$1
  local value=$2
  local tmp_file

  if is_dry_run; then
    dry_run_msg "set ${key}=${value} in ~/.zshrc"
    return
  fi

  [ -f "$HOME/.zshrc" ] || touch "$HOME/.zshrc"
  tmp_file=$(mktemp "${TMPDIR:-/tmp}/pacmandoh.zshrc.XXXXXX") || return 1
  if grep -q "^${key}=" "$HOME/.zshrc"; then
    sed -E "s|^${key}=.*|${key}=${value}|" "$HOME/.zshrc" >"$tmp_file"
  else
    printf "\n%s=%s\n" "$key" "$value" >>"$HOME/.zshrc"
    rm -f "$tmp_file"
    return
  fi
  mv "$tmp_file" "$HOME/.zshrc"
}

add_zsh_plugin() {
  local plugin=$1
  local tmp_file

  if is_dry_run; then
    dry_run_msg "add ${plugin} to plugins=(...) in ~/.zshrc"
    return
  fi

  [ -f "$HOME/.zshrc" ] || touch "$HOME/.zshrc"
  grep -Eq "plugins=\(${plugin}([[:space:]]|\\))|plugins=\([^)]*[[:space:]]${plugin}([[:space:]]|\\))" "$HOME/.zshrc" && return
  if ! grep -q "plugins=(" "$HOME/.zshrc"; then
    printf "\nplugins=(%s)\n" "$plugin" >>"$HOME/.zshrc"
    return
  fi
  tmp_file=$(mktemp "${TMPDIR:-/tmp}/pacmandoh.zshrc.XXXXXX") || return 1
  sed -E "s|plugins=\\(([^)]*)\\)|plugins=(\\1 ${plugin})|" "$HOME/.zshrc" >"$tmp_file"
  mv "$tmp_file" "$HOME/.zshrc"
}

backup_zshrc_once() {
  if is_dry_run; then
    dry_run_msg "backup ~/.zshrc to ~/.zshrc.pacmandoh.bak"
    return
  fi

  [ -f "$HOME/.zshrc" ] || touch "$HOME/.zshrc"
  [ -f "$HOME/.zshrc.pacmandoh.bak" ] || cp "$HOME/.zshrc" "$HOME/.zshrc.pacmandoh.bak"
}

run_with_timeout() {
  local seconds=$1
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$seconds" "$@"
  else
    "$@"
  fi
}

OMZ_MIRROR_CERNET="https://mirrors.cernet.edu.cn/ohmyzsh.git"
OMZ_MIRROR_TUNA="https://mirrors.tuna.tsinghua.edu.cn/git/ohmyzsh.git"
OMZ_MIRROR_GITHUB="https://github.com/ohmyzsh/ohmyzsh.git"

probe_omz_mirror() {
  local url=$1

  run_with_timeout 5 env GIT_TERMINAL_PROMPT=0 git ls-remote --heads "$url" >/dev/null 2>&1
}

detect_omz_mirror() {
  if probe_omz_mirror "$OMZ_MIRROR_CERNET"; then
    echo "cernet"
  elif probe_omz_mirror "$OMZ_MIRROR_TUNA"; then
    echo "tuna"
  else
    echo "github"
  fi
}

omz_mirror_label() {
  case "$1" in
  cernet) echo "CERNET (China Education and Research Network)" ;;
  tuna) echo "TUNA (Tsinghua University TUNA Association)" ;;
  github) echo "GitHub" ;;
  esac
}

resolve_omz_source() {
  case "$1" in
  "Auto Detect (Recommended)") detect_omz_mirror ;;
  CERNET*) echo "cernet" ;;
  TUNA*) echo "tuna" ;;
  GitHub) echo "github" ;;
  *) echo "installer" ;;
  esac
}

install_omz_from_git() {
  local remote=$1
  local tmp_dir

  if is_dry_run; then
    dry_run_msg "clone ${remote} into ~/.oh-my-zsh"
    return 0
  fi

  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/pacmandoh-ohmyzsh.XXXXXX") || return 1
  task_msg "Cloning Oh-My-Zsh"
  if ! run_logged env GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$remote" "$tmp_dir"; then
    task_fail
    rm -rf "$tmp_dir"
    return 1
  fi
  task_done

  task_msg "Installing Oh-My-Zsh files"
  if ! mv "$tmp_dir" "$HOME/.oh-my-zsh"; then
    task_fail
    rm -rf "$tmp_dir"
    return 1
  fi
  task_done

  if [ ! -f "$HOME/.zshrc" ] && [ -f "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" ]; then
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
  fi
}

install_omz_from_installer() {
  printf "\033[1mInstallation \033[92mtool\033[0m\033[1m:\033[0m\n"
  tools=("curl" "wget" "fetch")
  select_option "${tools[@]}"
  while ! $selected_option --version >/dev/null 2>/dev/null; do
    tput cuu 1 && tput ed
    printf "\033[1m\033[91mTool isn't installed! ✘\033[0m\n"
    select_option "${tools[@]}"
  done
  tput cuu 1 && tput ed

  if is_dry_run; then
    dry_run_msg "run Oh-My-Zsh installer from install.ohmyz.sh using ${selected_option}"
    return 0
  fi

  task_msg "Running Oh-My-Zsh installer"
  case "$selected_option" in
  curl) run_logged env RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://install.ohmyz.sh/)" ;;
  wget) run_logged env RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(wget -O- https://install.ohmyz.sh/)" ;;
  fetch) run_logged env RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(fetch -o - https://install.ohmyz.sh/)" ;;
  esac
  installer_status=$?
  [ $installer_status -eq 0 ] && task_done || task_fail
  if [ $installer_status -ne 0 ] || [ ! -d "$HOME/.oh-my-zsh" ]; then
    return 1
  fi
}

PLUGIN_PROBE_GITEE="https://gitee.com/dou-aqqq/zsh-autosuggestions.git"
PLUGIN_PROBE_GITHUB="https://github.com/zsh-users/zsh-autosuggestions.git"

detect_plugin_source() {
  if probe_omz_mirror "$PLUGIN_PROBE_GITEE"; then
    echo "gitee"
  else
    echo "github"
  fi
}

resolve_plugin_source() {
  case "$1" in
  "Auto Detect (Recommended)") detect_plugin_source ;;
  gitee) echo "gitee" ;;
  *) echo "github" ;;
  esac
}

plugin_source_remote() {
  local plugin=$1
  local source=$2

  if [ "$source" == gitee ]; then
    printf "https://gitee.com/dou-aqqq/%s.git" "$plugin"
    return
  fi

  case "$plugin" in
  zsh-autosuggestions) printf "https://github.com/zsh-users/zsh-autosuggestions.git" ;;
  zsh-syntax-highlighting) printf "https://github.com/zsh-users/zsh-syntax-highlighting.git" ;;
  conda-zsh-completion) printf "https://github.com/conda-incubator/conda-zsh-completion.git" ;;
  esac
}

install_plugin_from_git() {
  local plugin=$1
  local remote=$2
  local target="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/${plugin}"

  if is_dry_run; then
    dry_run_msg "clone ${remote} into ${target}"
    return 0
  fi

  if [ -d "$target" ]; then
    printf "\033[1m%s already exists \033[91m✘\033[0m\n" "$plugin"
    sleep 1
    return 0
  fi

  task_msg "Installing ${plugin}"
  if run_logged run_with_timeout 120 env GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$remote" "$target"; then
    task_done
    sleep 1
  else
    task_fail
    printf "\033[1mCheck your network or try the other repository source.\033[0m\n"
    rm -rf "$target"
    sleep 2
  fi
}

remove_zshrc_block() {
  local start_marker=$1
  local end_marker=$2
  local tmp_file

  if is_dry_run; then
    dry_run_msg "remove ~/.zshrc block from '${start_marker}' to '${end_marker}'"
    return
  fi

  [ -f "$HOME/.zshrc" ] || touch "$HOME/.zshrc"
  tmp_file=$(mktemp "${TMPDIR:-/tmp}/pacmandoh.zshrc.XXXXXX") || return 1
  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$HOME/.zshrc" >"$tmp_file"
  mv "$tmp_file" "$HOME/.zshrc"
}

remove_zshrc_lines() {
  local tmp_file

  if is_dry_run; then
    dry_run_msg "remove eager nvm source lines from ~/.zshrc"
    return
  fi

  [ -f "$HOME/.zshrc" ] || touch "$HOME/.zshrc"
  tmp_file=$(mktemp "${TMPDIR:-/tmp}/pacmandoh.zshrc.XXXXXX") || return 1
  grep -vE '^(export NVM_DIR=|.*nvm\.sh.*|.*bash_completion\.d/nvm.*)' "$HOME/.zshrc" >"$tmp_file"
  mv "$tmp_file" "$HOME/.zshrc"
}

append_zshrc_lazy_conda() {
  local conda_bin=$1
  local conda_root

  grep -q "# >>> conda lazy initialize >>>" "$HOME/.zshrc" && return
  conda_root=$(dirname "$(dirname "$conda_bin")")
  if is_dry_run; then
    dry_run_msg "append lazy conda loader for ${conda_bin} to ~/.zshrc"
    return
  fi

  cat >>"$HOME/.zshrc" <<EOF

# >>> conda lazy initialize >>>
export PATH="${conda_root}/condabin:\$PATH"

__pacmandoh_conda_load() {
  unset -f conda
  local __conda_setup
  __conda_setup="\$("${conda_bin}" "shell.zsh" "hook" 2> /dev/null)"
  if [ \$? -eq 0 ]; then
    eval "\$__conda_setup"
  elif [ -f "${conda_root}/etc/profile.d/conda.sh" ]; then
    . "${conda_root}/etc/profile.d/conda.sh"
  else
    export PATH="${conda_root}/bin:\$PATH"
  fi
  unset __conda_setup
}

conda() {
  __pacmandoh_conda_load
  conda "\$@"
}
# <<< conda lazy initialize <<<
EOF
}

append_zshrc_lazy_nvm() {
  grep -q "__pacmandoh_nvm_load" "$HOME/.zshrc" && return
  if is_dry_run; then
    dry_run_msg "append lazy nvm loader to ~/.zshrc"
    return
  fi

  cat >>"$HOME/.zshrc" <<'EOF'

export NVM_DIR="$HOME/.nvm"

__pacmandoh_nvm_load() {
  unset -f nvm node npm npx corepack
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
  [ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
  [ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"
}

nvm() { __pacmandoh_nvm_load; nvm "$@"; }
node() { __pacmandoh_nvm_load; node "$@"; }
npm() { __pacmandoh_nvm_load; npm "$@"; }
npx() { __pacmandoh_nvm_load; npx "$@"; }
corepack() { __pacmandoh_nvm_load; corepack "$@"; }
EOF
}

configure_lazy_shell_tools() {
  local conda_bin=""

  backup_zshrc_once

  [ -x "$HOME/miniconda3/bin/conda" ] && conda_bin="$HOME/miniconda3/bin/conda"
  [ -z "$conda_bin" ] && [ -x "$HOME/anaconda3/bin/conda" ] && conda_bin="$HOME/anaconda3/bin/conda"
  [ -z "$conda_bin" ] && conda_bin=$(command -v conda 2>/dev/null)

  if [ -n "$conda_bin" ]; then
    if ! grep -q "# >>> conda lazy initialize >>>" "$HOME/.zshrc"; then
      remove_zshrc_block "# >>> conda initialize >>>" "# <<< conda initialize <<<"
      append_zshrc_lazy_conda "$conda_bin"
    fi
  fi

  if [ -d "$HOME/.nvm" ] || [ -d "/opt/homebrew/opt/nvm" ] || [ -d "/usr/local/opt/nvm" ]; then
    if ! grep -q "__pacmandoh_nvm_load" "$HOME/.zshrc"; then
      remove_zshrc_lines
      append_zshrc_lazy_nvm
    fi
  fi
}
#%% ================================= %%#

clear
tput civis
printf "\033[1mWelcome to PacmanDoh's installer!\n\n"
is_dry_run && printf "\033[1mDry-run mode: no files will be changed and no repositories will be cloned.\033[0m\n"
is_verbose && printf "\033[1mVerbose mode: command output will be shown.\033[0m\n"
printf "\n"

echo -e '\033[95m                                              _________     ______'
sleep 0.05
echo '______________ _____________ _________ _____________  /________  /_'
sleep 0.05
# shellcheck disable=SC2016
# shellcheck disable=SC1003
echo '___  __ \  __ `/  ___/_  __ `__ \  __ `/_  __ \  __  /_  __ \_  __ \'
sleep 0.05
echo '__  /_/ / /_/ // /__ _  / / / / / /_/ /_  / / / /_/ / / /_/ /  / / /'
sleep 0.05
echo '_  .___/\__,_/ \___/ /_/ /_/ /_/\__,_/ /_/ /_/\__,_/  \____//_/ /_/'
sleep 0.05
echo -e '/_/\033[0m'
sleep 0.05
echo

printf "\033[1mOperate:\033[0m\n"
printf "\033[1m▲ ▼ to select | ↵ to apply\033[0m\n\n"
step_msg 1 "Oh-My-Zsh"
printf "\033[1mNeed to install \033[93moh-my-zsh\033[0m\033[1m?\033[0m\n"
need_omz=(no yes)
select_option "${need_omz[@]}"
printf "\033[1A\033[K"

#================================== omz install ==================================#
if [ "$selected_option" == yes ]; then
  printf "\033[1mInstallation \033[91msource\033[0m\033[1m:\033[0m\n"
  _source=(
    "Auto Detect (Recommended)"
    "CERNET (China Education and Research Network)"
    "TUNA (Tsinghua University TUNA Association)"
    "GitHub"
    "Official installer (install.ohmyz.sh)"
  )
  select_option "${_source[@]}"
  tput cuu 1 && tput ed
  # check zsh
  if ! command -v zsh >/dev/null 2>&1; then
    printf "\033[1m\033[91mZsh is not installed!\033[0m \033[91m✘\033[0m\n"
    printf "\033[1mPlease install \033[95mzsh\033[0m \033[1mbefore continuing this installer.\033[0m\n"
    printf "\033[1mExample (Ubuntu/Debian):\033[0m sudo apt install zsh\n"
    printf "\033[1mThen re-run: \033[93m./install.sh\033[0m\n"
    sleep 2
    exit 1
  fi

  if [ -d "$HOME/.oh-my-zsh" ]; then
    printf "  Oh-My-Zsh already exists... "
    task_skip
  else
    omz_source=$(resolve_omz_source "$selected_option")
    if [ "$omz_source" == "installer" ]; then
      if ! install_omz_from_installer; then
        printf "\033[1m\033[91mOh-My-Zsh install failed! ✘\033[0m\n"
        exit 1
      fi
    else
      if [ "$selected_option" == "Auto Detect (Recommended)" ]; then
        printf "  Detected source: %s\n" "$(omz_mirror_label "$omz_source")"
      fi
      case "$omz_source" in
      cernet) omz_remote=$OMZ_MIRROR_CERNET ;;
      tuna) omz_remote=$OMZ_MIRROR_TUNA ;;
      github) omz_remote=$OMZ_MIRROR_GITHUB ;;
      esac
      if ! install_omz_from_git "$omz_remote"; then
        printf "\033[1m\033[91mOh-My-Zsh install failed! ✘\033[0m\n"
        exit 1
      fi
    fi
  fi
fi
#=================================================================================#

#============================= install theme-pacmandoh ===========================#
step_msg 2 "Theme"
if ! is_dry_run && [ ! -d "$HOME/.oh-my-zsh" ]; then
  printf "\033[1m\033[91mOh-My-Zsh isn't installed! ✘\n"
  exit
fi
if is_dry_run; then
  dry_run_msg "copy pacmandoh.zsh-theme to ~/.oh-my-zsh/custom/themes/"
else
  task_msg "Copying pacmandoh.zsh-theme"
  mkdir -p "$HOME/.oh-my-zsh/custom/themes"
  cp ./pacmandoh.zsh-theme "$HOME/.oh-my-zsh/custom/themes/"
  task_done
fi

step_msg 3 ".zshrc"
printf "\033[1mModify \033[93mZSH_THEME\033[0m \033[1min .zshrc?\033[0m\n"
config_zshrc=("auto" "manual")
select_option "${config_zshrc[@]}"
if [ "$selected_option" == auto ]; then
  [ "$ZSH_THEME" != "random" ] && tput cuu 1 && tput ed &&
    task_msg "Setting ZSH_THEME" &&
    set_zshrc_value "ZSH_THEME" '"pacmandoh"' &&
    task_done &&
    sleep 1 &&
    tput cuu 1 && tput ed

  [ "$ZSH_THEME" == "random" ] &&
    # TODO: added automatic addition of "pacmandoh" to ZSH_THEME_RANDOM_CANDIDATES
    printf "\033[1mCurrent theme is \"random\" \033[91m✘\033[0m\n" && sleep 1 &&
    tput cuu 1 && tput ed
else
  tput cuu 1 && tput ed
  printf "\033[1mAdd theme to .zshrc manually\033[93m ⚠️\033[0m\n"
  sleep 1
  tput cuu 1 && tput ed
fi
#=================================================================================#

#============================== pacmandoh optional ===============================#
printf "\033[1mAdditional config options:\033[0m\n"
# printf "+-----------------------------------------+\n"
# printf "* multi or oneline ? default: multiline   *\n"
# printf "* need timer ? default: yes               *\n"
# printf "* newline before prompt ? default: yes    *\n"
# printf "+-----------------------------------------+\n"

printf "\033[1m- multiline or oneline?\033[0m\n"
options=("oneline" "default")
select_option "${options[@]}"
! grep -q "PACMANDOH_PROMPT_ALTERNATIVE" "$HOME/.zshrc" && [ "$selected_option" == oneline ] &&
  set_zshrc_value "PACMANDOH_PROMPT_ALTERNATIVE" "oneline"

if [ "$selected_option" == oneline ]; then
  tput cuu 2 && tput ed
  printf "\033[1mBoth is \033[91mno\033[0m \033[1min oneline!\033[0m\n" &&
    sleep 1 &&
    tput cuu 1 && tput ed
else
  tput cuu 1 && tput ed
  options=("no" "yes")
  printf "\033[1m- Need timer?\033[0m\n"
  select_option "${options[@]}"
  ! grep -q "PACMANDOH_NEED_TIMER" "$HOME/.zshrc" && [ "$selected_option" == no ] &&
    set_zshrc_value "PACMANDOH_NEED_TIMER" "no"
  tput cuu 1 && tput ed

  printf "\033[1m- Newline before PROMPT?\033[0m\n"
  select_option "${options[@]}"
  ! grep -q "PACMANDOH_NEWLINE_BEFORE_PROMPT" "$HOME/.zshrc" && [ "$selected_option" == no ] &&
    set_zshrc_value "PACMANDOH_NEWLINE_BEFORE_PROMPT" "no"
  tput cuu 2 && tput ed
fi
#=================================================================================#

#============================== lazy shell tools ==================================#
step_msg 4 "Startup"
printf "\033[1mLazy-load \033[95mconda/nvm\033[0m \033[1mto speed up startup?\033[0m\n"
options=("yes" "no")
select_option "${options[@]}"
if [ "$selected_option" == yes ]; then
  configure_lazy_shell_tools
  tput cuu 1 && tput ed
  task_msg "Configuring lazy loaders"
  task_done
  sleep 1
else
  tput cuu 1 && tput ed
fi
#=================================================================================#

#============================ custom oh-my-zsh plugins ===========================#
step_msg 5 "Plugins"
printf "\033[1mOh-My-Zsh plugins you need:\033[0m\n"
# printf "+-----------------------------------------+\n"
# printf "* If you want to install them all, select *\n"
# printf "* all without clicking apply. In other    *\n"
# printf "* cases, you can select the ones you want *\n"
# printf "* to install (multiple choices)           *\n"
# printf "+-----------------------------------------+\n"
plugins=("none" "all" "zsh-autosuggestions" "zsh-syntax-highlighting" "conda-zsh-completion" "apply")
select_option "${plugins[@]}" "multi"
tput cuu 1 && tput ed

if [ ${#multi_selected_option[@]} -ne 0 ]; then
  git_source=("Auto Detect (Recommended)" "github" "gitee")
  printf "\033[1mSelect git repository:\033[0m\n"
  select_option "${git_source[@]}"
  tput cuu 1 && tput ed
  plugin_source=$(resolve_plugin_source "$selected_option")
  if [ "$selected_option" == "Auto Detect (Recommended)" ]; then
    printf "  Detected source: %s\n" "$plugin_source"
  fi
  for i in "${multi_selected_option[@]}"; do
    install_plugin_from_git "$i" "$(plugin_source_remote "$i" "$plugin_source")"
  done
fi

if [ ${#multi_selected_option[@]} -ne 0 ]; then
  printf "\033[1mAdd plugins to ~/.zshrc?\033[0m\n"
  select_option "${config_zshrc[@]}"
  [ "$selected_option" == auto ] &&
    for i in "${multi_selected_option[@]}"; do
      add_zsh_plugin "$i"
    done
fi

printf "\n\033[1mDone! 🎉\033[92m ✔\033[0m\n"
sleep 1
tput init
printf "\033[1mRestart your terminal or run \033[93mexec zsh\033[0m \033[1mto use pacmandoh.\033[0m\n"
