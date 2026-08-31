#!/usr/bin/env bash

PACMANDOH_PLUGIN_GITEE_ORG="pacmandoh"
PLUGIN_PROBE_GITEE="https://gitee.com/${PACMANDOH_PLUGIN_GITEE_ORG}/zsh-autosuggestions.git"

PACMANDOH_KNOWN_PLUGINS=(
  zsh-autosuggestions
  zsh-syntax-highlighting
  conda-zsh-completion
)

PACMANDOH_BUILTIN_PLUGINS=(
  extract
  gitignore
  sudo
  z
  colored-man-pages
  copypath
  copyfile
  dirhistory
  docker
  docker-compose
  kubectl
  python
  pip
  virtualenv
  golang
  rust
  npm
  terraform
  aws
  vscode
  autojump
  ssh-agent
  macos
  brew
  command-not-found
  systemd
)

pacmandoh_builtin_plugin_choices() {
  local plugin

  for plugin in "${PACMANDOH_BUILTIN_PLUGINS[@]}"; do
    case "$plugin" in
    macos | brew)
      [[ "$OSTYPE" == darwin* ]] && printf '%s\n' "$plugin"
      ;;
    command-not-found | systemd)
      [[ "$OSTYPE" == linux* ]] && printf '%s\n' "$plugin"
      ;;
    *)
      printf '%s\n' "$plugin"
      ;;
    esac
  done
}

PACMANDOH_SELECTED_BUILTIN_PLUGINS=()

pacmandoh_is_external_plugin() {
  local plugin=$1
  local known

  for known in "${PACMANDOH_KNOWN_PLUGINS[@]}"; do
    [ "$known" == "$plugin" ] && return 0
  done
  return 1
}

pacmandoh_is_builtin_plugin() {
  local plugin=$1
  local known

  for known in "${PACMANDOH_BUILTIN_PLUGINS[@]}"; do
    [ "$known" == "$plugin" ] && return 0
  done
  return 1
}

pacmandoh_add_plugins_to_zshrc() {
  local plugin

  for plugin in "${PACMANDOH_SELECTED_PLUGINS[@]}" "${PACMANDOH_SELECTED_BUILTIN_PLUGINS[@]}"; do
    add_zsh_plugin "$plugin"
  done
}

detect_plugin_source() {
  if probe_omz_mirror "$PLUGIN_PROBE_GITEE"; then
    echo "gitee"
  else
    echo "github"
  fi
}

resolve_plugin_source() {
  case "$1" in
  "Auto Detect (Recommended)" | auto) detect_plugin_source ;;
  gitee) echo "gitee" ;;
  *) echo "github" ;;
  esac
}

plugin_gitee_remote() {
  local plugin=$1

  case "$plugin" in
  zsh-autosuggestions | zsh-syntax-highlighting | conda-zsh-completion)
    printf "https://gitee.com/%s/%s.git" "$PACMANDOH_PLUGIN_GITEE_ORG" "$plugin"
    ;;
  *)
    return 1
    ;;
  esac
}

plugin_source_remote() {
  local plugin=$1
  local source=$2

  if [ "$source" == gitee ]; then
    if plugin_gitee_remote "$plugin"; then
      return 0
    fi
    plugin_source_remote "$plugin" github
    return
  fi

  case "$plugin" in
  zsh-autosuggestions) printf "https://github.com/zsh-users/zsh-autosuggestions.git" ;;
  zsh-syntax-highlighting) printf "https://github.com/zsh-users/zsh-syntax-highlighting.git" ;;
  conda-zsh-completion) printf "https://github.com/conda-incubator/conda-zsh-completion.git" ;;
  esac
}

update_plugin_from_git() {
  local plugin=$1
  local target="$(pacmandoh_plugin_dir)/${plugin}"

  if [ ! -d "$target" ]; then
    task_msg "Updating ${plugin}"
    task_skip
    return 0
  fi

  if is_dry_run; then
    dry_run_msg "git pull in ${target}"
    return 0
  fi

  if [ ! -d "$target/.git" ]; then
    task_msg "Updating ${plugin}"
    task_fail
    return 1
  fi

  task_msg "Updating ${plugin}"
  if run_logged run_with_timeout 120 env GIT_TERMINAL_PROMPT=0 git -C "$target" pull --ff-only; then
    task_done
  else
    task_fail
    return 1
  fi
}

pacmandoh_discover_installed_plugins() {
  local plugin

  PACMANDOH_SELECTED_PLUGINS=()
  for plugin in "${PACMANDOH_KNOWN_PLUGINS[@]}"; do
    if [ -d "$(pacmandoh_plugin_dir)/${plugin}" ]; then
      PACMANDOH_SELECTED_PLUGINS+=("$plugin")
    fi
  done
}

pacmandoh_update_plugins() {
  local plugin

  step_msg "plugins" "Plugins"
  pacmandoh_require_omz

  if [ -n "$INSTALL_PLUGINS" ] && [ "$INSTALL_PLUGINS" != none ]; then
    pacmandoh_split_plugins "$INSTALL_PLUGINS"
  else
    pacmandoh_discover_installed_plugins
  fi

  if [ ${#PACMANDOH_SELECTED_PLUGINS[@]} -eq 0 ]; then
    task_msg "No plugins to update"
    task_skip
    return 0
  fi

  for plugin in "${PACMANDOH_SELECTED_PLUGINS[@]}"; do
    update_plugin_from_git "$plugin"
  done
}

install_plugin_from_git() {
  local plugin=$1
  local remote=$2
  local target="$(pacmandoh_plugin_dir)/${plugin}"

  if is_dry_run; then
    dry_run_msg "clone ${remote} into ${target}"
    return 0
  fi

  mkdir -p "$(pacmandoh_plugin_dir)"

  if [ -d "$target" ]; then
    err_msg "${plugin} already exists"
    sleep 1
    return 0
  fi

  task_msg "Installing ${plugin}"
  if run_logged run_with_timeout 120 env GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$remote" "$target"; then
    task_done
    sleep 1
  else
    task_fail
    warn_msg "Check your network or try the other repository source."
    rm -rf "$target"
    sleep 2
  fi
}

pacmandoh_split_plugins() {
  local raw=$1
  local item

  PACMANDOH_SELECTED_PLUGINS=()
  PACMANDOH_SELECTED_BUILTIN_PLUGINS=()
  [ -z "$raw" ] || [ "$raw" == none ] && return 0

  IFS=',' read -r -a _plugin_items <<<"$raw"
  for item in "${_plugin_items[@]}"; do
    item=${item//[[:space:]]/}
    [ -z "$item" ] && continue
    if [ "$item" == all ]; then
      PACMANDOH_SELECTED_PLUGINS=("${PACMANDOH_KNOWN_PLUGINS[@]}")
      return 0
    fi
    if pacmandoh_is_external_plugin "$item"; then
      PACMANDOH_SELECTED_PLUGINS+=("$item")
    elif pacmandoh_is_builtin_plugin "$item"; then
      PACMANDOH_SELECTED_BUILTIN_PLUGINS+=("$item")
    else
      warn_msg "Unknown plugin '${item}' — skipping." >&2
    fi
  done
}

pacmandoh_install_plugins() {
  local plugin_source=${1:-auto}
  local plugin

  step_msg "plugins" "Plugins"
  pacmandoh_split_plugins "$INSTALL_PLUGINS"

  if [ ${#PACMANDOH_SELECTED_PLUGINS[@]} -eq 0 ] && [ ${#PACMANDOH_SELECTED_BUILTIN_PLUGINS[@]} -eq 0 ]; then
    task_msg "No plugins selected"
    task_skip
    return 0
  fi

  if [ ${#PACMANDOH_SELECTED_PLUGINS[@]} -gt 0 ]; then
    pacmandoh_require_omz

    plugin_source=$(resolve_plugin_source "$plugin_source")
    if [ "$1" == "Auto Detect (Recommended)" ] || [ "$1" == auto ]; then
      printf "  Detected source: %s\n" "$plugin_source"
    fi

    for plugin in "${PACMANDOH_SELECTED_PLUGINS[@]}"; do
      install_plugin_from_git "$plugin" "$(plugin_source_remote "$plugin" "$plugin_source")"
    done
  fi

  pacmandoh_add_plugins_to_zshrc
}

pacmandoh_install_plugins_interactive() {
  local plugin_source
  local -a builtin_plugins=()
  local -a selected_external=()
  local -a selected_builtin=()
  local choice

  while IFS= read -r choice; do
    builtin_plugins+=("$choice")
  done < <(pacmandoh_builtin_plugin_choices)

  if _pacmandoh_menu_multi "Third-party plugins (git clone)" "${PACMANDOH_KNOWN_PLUGINS[@]}"; then
    selected_external=("${PACMANDOH_MENU_RESULT_ITEMS[@]}")
  fi

  if _pacmandoh_menu_multi "Oh My Zsh built-in plugins" "${builtin_plugins[@]}"; then
    selected_builtin=("${PACMANDOH_MENU_RESULT_ITEMS[@]}")
  fi

  PACMANDOH_SELECTED_PLUGINS=("${selected_external[@]}")
  PACMANDOH_SELECTED_BUILTIN_PLUGINS=("${selected_builtin[@]}")

  if [ ${#PACMANDOH_SELECTED_PLUGINS[@]} -eq 0 ] && [ ${#PACMANDOH_SELECTED_BUILTIN_PLUGINS[@]} -eq 0 ]; then
    return 0
  fi

  if [ ${#PACMANDOH_SELECTED_PLUGINS[@]} -gt 0 ]; then
    git_source=("Auto Detect (Recommended)" "github" "gitee")
    _pacmandoh_menu_single "Select git repository" "${git_source[@]}"
    selected_option="$PACMANDOH_MENU_RESULT"
    plugin_source=$(resolve_plugin_source "$selected_option")
    if [ "$selected_option" == "Auto Detect (Recommended)" ]; then
      printf "  Detected source: %s\n" "$plugin_source"
    fi

    step_msg "plugins" "Plugins"
    pacmandoh_require_omz

    for i in "${PACMANDOH_SELECTED_PLUGINS[@]}"; do
      install_plugin_from_git "$i" "$(plugin_source_remote "$i" "$plugin_source")"
    done
  elif [ ${#PACMANDOH_SELECTED_BUILTIN_PLUGINS[@]} -gt 0 ]; then
    step_msg "plugins" "Plugins"
  fi

  config_zshrc=("auto" "manual")
  _pacmandoh_menu_single "Add plugins to ~/.zshrc?" "${config_zshrc[@]}"
  selected_option="$PACMANDOH_MENU_RESULT"
  if [ "$selected_option" == auto ]; then
    pacmandoh_add_plugins_to_zshrc
  fi
}
