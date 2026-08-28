#!/usr/bin/env bash

pacmandoh_finish() {
  _pacmandoh_ui_show_cursor
  if [ "${UPDATE_MODE:-no}" == yes ]; then
    printf '\n%s %b\n' \
      "$(_pacmandoh_print_icon done "$PACMANDOH_ICON_DONE")" \
      "${PACMANDOH_CLR_BOLD}Update complete! 🎉${PACMANDOH_CLR_RESET}"
    sleep 1
    warn_msg "Restart your terminal or run ${PACMANDOH_CLR_WARN}exec zsh${PACMANDOH_CLR_RESET} to load changes."
    warn_msg "Oh My Zsh itself: run ${PACMANDOH_CLR_WARN}omz update${PACMANDOH_CLR_RESET} in a zsh session."
    return
  fi
  printf '\n%s %b\n' \
    "$(_pacmandoh_print_icon done "$PACMANDOH_ICON_DONE")" \
    "${PACMANDOH_CLR_BOLD}Done! 🎉${PACMANDOH_CLR_RESET}"
  sleep 1
  warn_msg "Restart your terminal or run ${PACMANDOH_CLR_WARN}exec zsh${PACMANDOH_CLR_RESET} to use pacmandoh."
}

pacmandoh_run_update() {
  pacmandoh_update_theme
  pacmandoh_update_plugins
  pacmandoh_finish
}

pacmandoh_configure_prompt_interactive() {
  config_msg "Prompt options"
  _pacmandoh_menu_single "Prompt style" oneline default
  selected_option="$PACMANDOH_MENU_RESULT"

  if [ "$selected_option" == oneline ]; then
    set_zshrc_value "PACMANDOH_PROMPT_ALTERNATIVE" "oneline"
    warn_msg "Timer and newline are ${PACMANDOH_CLR_ERR}disabled${PACMANDOH_CLR_RESET} in oneline mode."
    sleep 1
    return
  fi

  set_zshrc_value "PACMANDOH_PROMPT_ALTERNATIVE" "multiline"

  _pacmandoh_menu_single "Need timer?" no yes
  set_zshrc_value "PACMANDOH_NEED_TIMER" "$PACMANDOH_MENU_RESULT"

  _pacmandoh_menu_single "Newline before prompt?" no yes
  set_zshrc_value "PACMANDOH_NEWLINE_BEFORE_PROMPT" "$PACMANDOH_MENU_RESULT"
}

pacmandoh_run_noninteractive() {
  pacmandoh_apply_profile
  pacmandoh_install_omz_if_needed auto
  pacmandoh_install_theme
  pacmandoh_configure_theme_auto
  pacmandoh_apply_cli_prompt_style

  if [ "$INSTALL_LAZY" == yes ]; then
    step_msg "startup" "Startup"
    configure_lazy_shell_tools
    task_msg "Configuring lazy loaders"
    task_done
  fi

  if [ -n "$INSTALL_PLUGINS" ] && [ "$INSTALL_PLUGINS" != none ]; then
    pacmandoh_install_plugins auto
  fi

  pacmandoh_finish
}

pacmandoh_run_interactive() {
  pacmandoh_print_banner

  _pacmandoh_menu_single "Install Oh-My-Zsh?" no yes
  selected_option="$PACMANDOH_MENU_RESULT"

  if [ "$selected_option" == yes ]; then
    _source=(
      "Auto Detect (Recommended)"
      "CERNET (China Education and Research Network)"
      "TUNA (Tsinghua University TUNA Association)"
      "GitHub"
      "Official installer (install.ohmyz.sh)"
    )
    _pacmandoh_menu_single "Oh-My-Zsh source" "${_source[@]}"
    selected_option="$PACMANDOH_MENU_RESULT"
    INSTALL_OMZ=yes
    pacmandoh_install_omz_if_needed "$selected_option"
  else
    INSTALL_OMZ=no
  fi

  pacmandoh_install_theme

  step_msg "zshrc" "Shell config"
  config_zshrc=(auto manual)
  _pacmandoh_menu_single "Set ZSH_THEME in .zshrc?" "${config_zshrc[@]}"
  selected_option="$PACMANDOH_MENU_RESULT"

  if [ "$selected_option" == auto ]; then
    pacmandoh_configure_theme_auto
  else
    warn_msg "Add theme to .zshrc manually."
    sleep 1
  fi

  pacmandoh_configure_prompt_interactive

  step_msg "startup" "Startup"
  options=(yes no)
  _pacmandoh_menu_single "Lazy-load conda/nvm?" "${options[@]}"
  selected_option="$PACMANDOH_MENU_RESULT"

  if [ "$selected_option" == yes ]; then
    configure_lazy_shell_tools
    task_msg "Configuring lazy loaders"
    task_done
  fi

  pacmandoh_install_plugins_interactive
  pacmandoh_finish
}

pacmandoh_main() {
  if [ "${UPDATE_MODE:-no}" == yes ]; then
    pacmandoh_run_update
    return
  fi

  if [ "$ASSUME_YES" == yes ]; then
    pacmandoh_run_noninteractive
  else
    pacmandoh_run_interactive
  fi
}
