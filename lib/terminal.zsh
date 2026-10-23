# Detects the terminal emulator the user is attached from and finds its shortcut list.
# Inside herdr panes TERM_PROGRAM is always "herdr", so the herdr client's process ancestry
# is the reliable signal; environment hints inherited by the server are the fallback.

cs_os() {
  [[ -n $CHEATSHEET_OS ]] && { print -r -- $CHEATSHEET_OS; return }
  [[ $OSTYPE == darwin* ]] && print macos || print linux
}

_cs_term_from_name() { # process name (macOS: full path, Linux: comm truncated to 15 chars)
  case ${1:t} in
    iTerm2|iTermServer*) print iterm ;;
    Terminal) print apple-terminal ;;
    ghostty) print ghostty ;;
    wezterm-gui|wezterm) print wezterm ;;
    kitty) print kitty ;;
    alacritty|Alacritty) print alacritty ;;
    gnome-terminal*|kgx|ptyxis*|tilix) print gnome-terminal ;;
    konsole) print konsole ;;
    "Code Helper"*|code|Code) print vscode ;;
    *) return 1 ;;
  esac
}

# Walks up from each herdr client process; processes started by the herdr server
# (pane shells, plugin hooks, `herdr pane …` calls) have a herdr ancestor and are skipped.
_cs_term_from_ps() {
  local -A parent name
  local pid ppid comm p id hops
  ps -axo pid=,ppid=,comm= 2>/dev/null | while read -r pid ppid comm; do
    parent[$pid]=$ppid name[$pid]=$comm
  done
  for pid in ${(kOn)name}; do
    [[ ${name[$pid]:t} == herdr ]] || continue
    p=${parent[$pid]} hops=0
    while [[ -n $p && $p != 0 && $p != 1 ]] && (( hops++ < 40 )); do
      case ${name[$p]:t} in
        herdr) break ;;
        sshd*) break ;;   # attached over SSH: the terminal is on another machine
      esac
      if id=$(_cs_term_from_name "${name[$p]}"); then print $id; return; fi
      p=${parent[$p]}
    done
  done
  return 1
}

_cs_term_from_env() {
  case $__CFBundleIdentifier in
    com.googlecode.iterm2) print iterm; return ;;
    com.apple.Terminal) print apple-terminal; return ;;
    com.mitchellh.ghostty) print ghostty; return ;;
    com.github.wez.wezterm) print wezterm; return ;;
    net.kovidgoyal.kitty) print kitty; return ;;
    org.alacritty|io.alacritty) print alacritty; return ;;
    com.microsoft.VSCode*) print vscode; return ;;
  esac
  if [[ $LC_TERMINAL == iTerm2 || -n $ITERM_SESSION_ID || -n $ITERM_PROFILE ]]; then print iterm
  elif [[ -n $GHOSTTY_RESOURCES_DIR || -n $GHOSTTY_BIN_DIR ]]; then print ghostty
  elif [[ -n $WEZTERM_PANE || -n $WEZTERM_EXECUTABLE ]]; then print wezterm
  elif [[ -n $KITTY_WINDOW_ID || -n $KITTY_PID ]]; then print kitty
  elif [[ -n $ALACRITTY_WINDOW_ID || -n $ALACRITTY_SOCKET ]]; then print alacritty
  elif [[ -n $KONSOLE_VERSION ]]; then print konsole
  elif [[ -n $WT_SESSION ]]; then print windows-terminal
  elif [[ -n $VSCODE_INJECTION || -n $VSCODE_GIT_IPC_HANDLE ]]; then print vscode
  elif [[ -n $VTE_VERSION ]]; then print gnome-terminal
  else return 1
  fi
}

cs_detect_terminal() { # -> terminal id, "generic" when unknown, or the configured value
  local t=${CHEATSHEET_TERMINAL:-auto}
  [[ $t != auto ]] && { print -r -- $t; return }
  _cs_term_from_ps || _cs_term_from_env || print generic
}

cs_app_file() { # id -> key list of an app (user override first, then built-in)
  local d
  for d in "$CS_CONFIG_DIR/apps" "$CS_ROOT/defaults/apps"; do
    [[ -f "$d/$1.txt" ]] && { print -r -- "$d/$1.txt"; return }
  done
}

cs_terminal_file() { # id -> shortcut list (user override first, then built-in, then generic)
  local id=$1 os=$(cs_os) d f
  for d in "$CS_CONFIG_DIR/terminals" "$CS_ROOT/defaults/terminals"; do
    for f in "$id.$os.txt" "$id.txt"; do
      [[ -f "$d/$f" ]] && { print -r -- "$d/$f"; return }
    done
  done
  f="$CS_ROOT/defaults/terminals/generic.$os.txt"
  [[ -f "$f" ]] && print -r -- "$f"
}
