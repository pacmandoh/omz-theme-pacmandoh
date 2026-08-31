#!/usr/bin/env bash

OMZ_MIRROR_TUNA="https://mirrors.tuna.tsinghua.edu.cn/git/ohmyzsh.git"
OMZ_MIRROR_SJTUG="https://mirrors.sjtug.sjtu.edu.cn/git/ohmyzsh.git"
OMZ_MIRROR_GITEE="https://gitee.com/mirrors/oh-my-zsh.git"
OMZ_MIRROR_GITHUB="https://github.com/ohmyzsh/ohmyzsh.git"

probe_omz_mirror() {
  local url=$1
  run_with_timeout 5 env GIT_TERMINAL_PROMPT=0 git ls-remote --heads "$url" >/dev/null 2>&1
}

detect_omz_mirror() {
  if probe_omz_mirror "$OMZ_MIRROR_SJTUG"; then
    echo "sjtug"
  elif probe_omz_mirror "$OMZ_MIRROR_GITEE"; then
    echo "gitee"
  elif probe_omz_mirror "$OMZ_MIRROR_TUNA"; then
    echo "tuna"
  else
    echo "github"
  fi
}

omz_mirror_label() {
  case "$1" in
  tuna) echo "TUNA (Tsinghua University TUNA Association)" ;;
  sjtug) echo "SJTUG (Shanghai Jiao Tong University)" ;;
  gitee) echo "Gitee" ;;
  github) echo "GitHub" ;;
  esac
}

resolve_omz_source() {
  case "$1" in
  "Auto Detect (Recommended)" | auto) detect_omz_mirror ;;
  TUNA*) echo "tuna" ;;
  SJTUG*) echo "sjtug" ;;
  Gitee | gitee) echo "gitee" ;;
  GitHub | github) echo "github" ;;
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
  if ! run_logged run_with_timeout 120 env GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$remote" "$tmp_dir"; then
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
  local tools=("curl" "wget" "fetch")
  local tool

  _pacmandoh_menu_single "Download tool for Oh-My-Zsh installer" "${tools[@]}"
  tool="$PACMANDOH_MENU_RESULT"

  while ! command -v "$tool" >/dev/null 2>&1 || ! "$tool" --version >/dev/null 2>&1; do
    err_msg "${tool} isn't available!"
    _pacmandoh_menu_single "Download tool for Oh-My-Zsh installer" "${tools[@]}"
    tool="$PACMANDOH_MENU_RESULT"
  done

  if is_dry_run; then
    dry_run_msg "run Oh-My-Zsh installer from install.ohmyz.sh using ${tool}"
    return 0
  fi

  task_msg "Running Oh-My-Zsh installer"
  case "$tool" in
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

pacmandoh_require_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    return 0
  fi

  err_msg "Zsh is not installed!"
  printf "${PACMANDOH_CLR_BOLD}Please install zsh before continuing.${PACMANDOH_CLR_RESET}\n"
  printf "${PACMANDOH_CLR_BOLD}Example (Ubuntu/Debian):${PACMANDOH_CLR_RESET} sudo apt install zsh\n"
  return 1
}

pacmandoh_install_omz_if_needed() {
  local source_choice=${1:-auto}

  step_msg "omz" "Oh-My-Zsh"

  if [ "$INSTALL_OMZ" == no ]; then
    task_msg "Skipping Oh-My-Zsh"
    task_skip
    return 0
  fi

  if ! pacmandoh_require_zsh; then
    exit 1
  fi

  if [ -d "$HOME/.oh-my-zsh" ]; then
    task_msg "Oh-My-Zsh already exists"
    task_skip
    return 0
  fi

  local omz_source
  omz_source=$(resolve_omz_source "$source_choice")
  if [ "$omz_source" == "installer" ]; then
    if ! install_omz_from_installer; then
      err_msg "Oh-My-Zsh install failed!"
      exit 1
    fi
    return 0
  fi

  if [ "$source_choice" == "Auto Detect (Recommended)" ] || [ "$source_choice" == auto ]; then
    printf "  Detected source: %s\n" "$(omz_mirror_label "$omz_source")"
  fi

  local omz_remote
  case "$omz_source" in
  tuna) omz_remote=$OMZ_MIRROR_TUNA ;;
  sjtug) omz_remote=$OMZ_MIRROR_SJTUG ;;
  gitee) omz_remote=$OMZ_MIRROR_GITEE ;;
  github) omz_remote=$OMZ_MIRROR_GITHUB ;;
  esac

  if ! install_omz_from_git "$omz_remote"; then
    err_msg "Oh-My-Zsh install failed!"
    exit 1
  fi
}
