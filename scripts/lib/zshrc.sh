#!/usr/bin/env bash

_pacmandoh_zshrc_path() {
  printf '%s/.zshrc' "$HOME"
}

_pacmandoh_zshrc_has_omz_source() {
  local zshrc=$(_pacmandoh_zshrc_path)

  [ -f "$zshrc" ] || return 1
  grep -qE 'source[[:space:]].*oh-my-zsh\.sh|\.[[:space:]].*oh-my-zsh\.sh' "$zshrc"
}

# Insert before OMZ source so ZSH_THEME and plugins= take effect on load.
_pacmandoh_zshrc_insert_before_omz() {
  local line=$1
  local zshrc tmp_file

  zshrc=$(_pacmandoh_zshrc_path)
  [ -f "$zshrc" ] || touch "$zshrc"

  if is_dry_run; then
    if _pacmandoh_zshrc_has_omz_source; then
      dry_run_msg "insert before source oh-my-zsh.sh: ${line}"
    else
      dry_run_msg "append to ~/.zshrc: ${line}"
    fi
    return
  fi

  if ! _pacmandoh_zshrc_has_omz_source; then
    printf '\n%s\n' "$line" >>"$zshrc"
    return 0
  fi

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/pacmandoh.zshrc.XXXXXX") || return 1
  awk -v ins="$line" '
    !inserted && /source[[:space:]].*oh-my-zsh\.sh|\.[[:space:]].*oh-my-zsh\.sh/ {
      print ins
      inserted = 1
    }
    { print }
  ' "$zshrc" >"$tmp_file"
  mv "$tmp_file" "$zshrc"
}

_pacmandoh_zshrc_plugin_present() {
  local plugin=$1
  local zshrc=$(_pacmandoh_zshrc_path)

  [ -f "$zshrc" ] || return 1
  awk -v p="$plugin" '
    function has_plugin(line) {
      return line ~ "(^|[[:space:]])" p "([[:space:]]|\\)|$)"
    }
    /^[[:space:]]*plugins=\(/ {
      in_block = 1
      if (has_plugin($0)) { found = 1; exit }
      if ($0 ~ /\)/) in_block = 0
      next
    }
    in_block {
      if (has_plugin($0)) { found = 1; exit }
      if ($0 ~ /^[[:space:]]*\)/) in_block = 0
      next
    }
    END { exit(found ? 0 : 1) }
  ' "$zshrc"
}

set_zshrc_value() {
  local key=$1
  local value=$2
  local tmp_file line

  if is_dry_run; then
    dry_run_msg "set ${key}=${value} in ~/.zshrc"
    return
  fi

  [ -f "$(_pacmandoh_zshrc_path)" ] || touch "$(_pacmandoh_zshrc_path)"
  if grep -q "^${key}=" "$(_pacmandoh_zshrc_path)"; then
    tmp_file=$(mktemp "${TMPDIR:-/tmp}/pacmandoh.zshrc.XXXXXX") || return 1
    sed -E "s|^${key}=.*|${key}=${value}|" "$(_pacmandoh_zshrc_path)" >"$tmp_file"
    mv "$tmp_file" "$(_pacmandoh_zshrc_path)"
    return
  fi

  line="${key}=${value}"
  _pacmandoh_zshrc_insert_before_omz "$line"
}

add_zsh_plugin() {
  local plugin=$1
  local zshrc tmp_file

  if is_dry_run; then
    dry_run_msg "add ${plugin} to plugins=(...) in ~/.zshrc"
    return
  fi

  zshrc=$(_pacmandoh_zshrc_path)
  [ -f "$zshrc" ] || touch "$zshrc"
  _pacmandoh_zshrc_plugin_present "$plugin" && return 0

  if ! grep -q '^[[:space:]]*plugins=(' "$zshrc"; then
    _pacmandoh_zshrc_insert_before_omz "plugins=(${plugin})"
    return 0
  fi

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/pacmandoh.zshrc.XXXXXX") || return 1
  awk -v plugin="$plugin" '
    function has_plugin(line,    p) {
      p = plugin
      return line ~ "(^|[[:space:]])" p "([[:space:]]|\\)|$)"
    }
  {
    if (!in_block && $0 ~ /^[[:space:]]*plugins=\(/) {
      in_block = 1
      if (has_plugin($0)) { print; next }
      if ($0 ~ /\)/) {
        sub(/\)/, " " plugin ")")
        print
        in_block = 0
        next
      }
      print
      next
    }
    if (in_block) {
      if (has_plugin($0)) { print; next }
      if ($0 ~ /^[[:space:]]*\)/) {
        print "    " plugin
        print
        in_block = 0
        next
      }
      print
      next
    }
    print
  }' "$zshrc" >"$tmp_file"
  mv "$tmp_file" "$zshrc"
}

backup_zshrc_once() {
  if is_dry_run; then
    dry_run_msg "backup ~/.zshrc to ~/.zshrc.pacmandoh.bak"
    return
  fi

  [ -f "$HOME/.zshrc" ] || touch "$HOME/.zshrc"
  [ -f "$HOME/.zshrc.pacmandoh.bak" ] || cp "$HOME/.zshrc" "$HOME/.zshrc.pacmandoh.bak"
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

  [ -f "$HOME/.zshrc" ] && grep -q "# >>> conda lazy initialize >>>" "$HOME/.zshrc" && return
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
  [ -f "$HOME/.zshrc" ] && grep -q "__pacmandoh_nvm_load" "$HOME/.zshrc" && return
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
    if ! { [ -f "$HOME/.zshrc" ] && grep -q "# >>> conda lazy initialize >>>" "$HOME/.zshrc"; }; then
      remove_zshrc_block "# >>> conda initialize >>>" "# <<< conda initialize <<<"
      append_zshrc_lazy_conda "$conda_bin"
    fi
  fi

  if [ -d "$HOME/.nvm" ] || [ -d "/opt/homebrew/opt/nvm" ] || [ -d "/usr/local/opt/nvm" ]; then
    if ! { [ -f "$HOME/.zshrc" ] && grep -q "__pacmandoh_nvm_load" "$HOME/.zshrc"; }; then
      remove_zshrc_lines
      append_zshrc_lazy_nvm
    fi
  fi
}

pacmandoh_apply_cli_prompt_style() {
  case "$PROMPT_STYLE" in
  oneline)
    set_zshrc_value "PACMANDOH_PROMPT_ALTERNATIVE" "oneline"
    ;;
  multiline)
    set_zshrc_value "PACMANDOH_PROMPT_ALTERNATIVE" "multiline"
    ;;
  esac
}

_pacmandoh_zshrc_theme_is_random() {
  local zshrc=$(_pacmandoh_zshrc_path)

  [ -f "$zshrc" ] || return 1
  grep -qE '^[[:space:]]*ZSH_THEME=("?)random\1' "$zshrc"
}

pacmandoh_configure_theme_auto() {
  if _pacmandoh_zshrc_theme_is_random; then
    err_msg "Current theme is \"random\" — cannot auto-configure."
    sleep 1
    return
  fi

  task_msg "Setting ZSH_THEME"
  set_zshrc_value "ZSH_THEME" '"pacmandoh"'
  task_done
  sleep 1
}

pacmandoh_has_omz() {
  [ -d "${ZSH:-$HOME/.oh-my-zsh}" ] || [ -d "$HOME/.oh-my-zsh" ]
}

pacmandoh_plugin_dir() {
  printf "%s/plugins" "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
}

pacmandoh_require_omz() {
  is_dry_run && return 0
  pacmandoh_has_omz && return 0
  err_msg "Oh-My-Zsh is not installed."
  printf "Rerun the installer and choose to install Oh-My-Zsh:\n"
  printf "  ./install.sh\n"
  printf "  curl -fsSL https://gitee.com/pacmandoh/omz-theme-pacmandoh/raw/main/install.sh | bash\n"
  exit 1
}

pacmandoh_install_theme() {
  step_msg "theme" "Theme"
  pacmandoh_require_omz

  if is_dry_run; then
    dry_run_msg "copy pacmandoh.zsh-theme to ~/.oh-my-zsh/custom/themes/"
    return
  fi

  task_msg "Copying pacmandoh.zsh-theme"
  mkdir -p "$HOME/.oh-my-zsh/custom/themes"
  cp "$(pacmandoh_theme_path)" "$HOME/.oh-my-zsh/custom/themes/"
  task_done
}

pacmandoh_update_theme() {
  step_msg "theme" "Theme"
  pacmandoh_require_omz

  if is_dry_run; then
    dry_run_msg "update pacmandoh.zsh-theme in ~/.oh-my-zsh/custom/themes/"
    return
  fi

  task_msg "Updating pacmandoh.zsh-theme"
  mkdir -p "$HOME/.oh-my-zsh/custom/themes"
  cp "$(pacmandoh_theme_path)" "$HOME/.oh-my-zsh/custom/themes/pacmandoh.zsh-theme"
  task_done
}
