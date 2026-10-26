# Detects the terminal emulator the user is attached from and finds its shortcut list.
# Inside herdr panes TERM_PROGRAM is always "herdr", so the herdr client's process ancestry
# is the reliable signal; environment hints inherited by the server are the fallback.

if [[ -n $CHEATSHEET_OS ]]; then CS_OS=$CHEATSHEET_OS
elif [[ $OSTYPE == darwin* ]]; then CS_OS=macos
else CS_OS=linux
fi

_cs_term_from_name() { # process name (macOS: full path, Linux: comm truncated to 15 chars)
  case ${1:t} in
    iTerm2|iTermServer*) print iterm ;;
    Terminal) print apple-terminal ;;
    ghostty) print ghostty ;;
    wezterm-gui|wezterm|wezterm-mux-ser*) print wezterm ;;
    kitty) print kitty ;;
    alacritty|Alacritty) print alacritty ;;
    gnome-terminal*|kgx|ptyxis*|tilix) print gnome-terminal ;;
    konsole|yakuake) print konsole ;;
    foot|footclient) print foot ;;
    urxvt*|rxvt-unicode*) print urxvt ;;
    xterm|uxterm) print xterm ;;
    "Code Helper"*|code|Code) print vscode ;;
    Hyper|"Hyper Helper"*|hyper) print hyper ;;
    *) return 1 ;;
  esac
}

# Walks up from each herdr client process; processes started by the herdr server
# (pane shells, plugin hooks, `herdr pane …` calls) have a herdr ancestor and are skipped. Clients
# whose terminal isn't found this way (attached over SSH, or from inside tmux) are kept in
# _CS_CLIENTS for _cs_term_from_client_env.
typeset -ga _CS_CLIENTS
_cs_term_from_ps() {
  local -A parent name
  local pid ppid comm p id hops
  _CS_CLIENTS=()
  ps -A -o pid=,ppid=,comm= 2>/dev/null | while read -r pid ppid comm; do
    parent[$pid]=$ppid name[$pid]=$comm
  done
  for pid in ${(kOn)name}; do
    [[ ${name[$pid]:t} == herdr ]] || continue
    p=${parent[$pid]} hops=0
    # the server runs detached, below init or the user's service manager
    [[ $p == 1 || ${name[$p]:t} == (launchd|systemd) ]] && continue
    while [[ -n $p && $p != 0 && $p != 1 ]] && (( hops++ < 40 )); do
      case ${name[$p]:t} in
        herdr) continue 2 ;;
        sshd*) break ;;   # attached over SSH: the terminal is on another machine
      esac
      if id=$(_cs_term_from_name "${name[$p]}"); then print $id; return; fi
      p=${parent[$p]}
    done
    _CS_CLIENTS+=($pid)
  done
  return 1
}

# The variables _cs_term_from_env reads.
_CS_TERM_VARS=(__CFBundleIdentifier TERM_PROGRAM LC_TERMINAL ITERM_SESSION_ID ITERM_PROFILE
  GHOSTTY_RESOURCES_DIR GHOSTTY_BIN_DIR WEZTERM_PANE WEZTERM_EXECUTABLE KITTY_WINDOW_ID KITTY_PID
  ALACRITTY_WINDOW_ID ALACRITTY_SOCKET KONSOLE_VERSION KONSOLE_DBUS_SESSION WT_SESSION VSCODE_INJECTION
  VSCODE_GIT_IPC_HANDLE XTERM_VERSION GNOME_TERMINAL_SCREEN VTE_VERSION TERM COLORTERM)

# herdr gives its panes TERM=xterm-256color, but a client keeps the environment of the shell it was
# started from. Linux shows it in /proc, so a client attached over SSH still names the terminal through
# TERM (xterm-kitty, foot, alacritty, rxvt-unicode-256color) or LC_TERMINAL.
_cs_term_from_client_env() {
  local pid
  for pid in $_CS_CLIENTS; do
    [[ -r /proc/$pid/environ ]] || continue
    (
      local kv
      unset $_CS_TERM_VARS
      for kv in ${(0)"$(</proc/$pid/environ)"}; do
        (( ${_CS_TERM_VARS[(Ie)${kv%%=*}]} )) && export "$kv"
      done
      _cs_term_from_env
    ) && return
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
    co.zeit.hyper) print hyper; return ;;
  esac
  if [[ $LC_TERMINAL == iTerm2 || -n $ITERM_SESSION_ID || -n $ITERM_PROFILE ]]; then print iterm
  elif [[ -n $GHOSTTY_RESOURCES_DIR || -n $GHOSTTY_BIN_DIR ]]; then print ghostty
  elif [[ -n $WEZTERM_PANE || -n $WEZTERM_EXECUTABLE ]]; then print wezterm
  elif [[ -n $KITTY_WINDOW_ID || -n $KITTY_PID ]]; then print kitty
  elif [[ -n $ALACRITTY_WINDOW_ID || -n $ALACRITTY_SOCKET ]]; then print alacritty
  elif [[ -n $KONSOLE_VERSION || -n $KONSOLE_DBUS_SESSION ]]; then print konsole
  elif [[ -n $WT_SESSION ]]; then print windows-terminal
  elif [[ -n $VSCODE_INJECTION || -n $VSCODE_GIT_IPC_HANDLE || $TERM_PROGRAM == vscode ]]; then print vscode
  elif [[ $TERM_PROGRAM == Hyper ]]; then print hyper
  elif [[ -n $XTERM_VERSION ]]; then print xterm
  elif [[ -n $VTE_VERSION || -n $GNOME_TERMINAL_SCREEN ]]; then print gnome-terminal
  else
    case $TERM_PROGRAM in
      iTerm.app) print iterm; return ;;
      Apple_Terminal) print apple-terminal; return ;;
      WezTerm) print wezterm; return ;;
      ghostty) print ghostty; return ;;
    esac
    case $TERM in
      xterm-kitty) print kitty ;;
      xterm-ghostty) print ghostty ;;
      alacritty*) print alacritty ;;
      foot*) print foot ;;
      wezterm) print wezterm ;;
      rxvt-unicode*) print urxvt ;;
      *) [[ $COLORTERM == rxvt* ]] && print urxvt || return 1 ;;
    esac
  fi
}

cs_detect_terminal() { # -> terminal id, "generic" when unknown, or the configured value
  local t=${CHEATSHEET_TERMINAL:-auto}
  [[ $t != auto ]] && { print -r -- $t; return }
  _cs_term_from_ps || _cs_term_from_client_env || _cs_term_from_env || print generic
}

cs_cmd_file() { # tools|devtools -> its command list (user override first, then built-in)
  local f
  for f in "$CS_CONFIG_DIR/$1.txt" "$CS_ROOT/defaults/$1.txt"; do
    [[ -f "$f" ]] && { print -r -- "$f"; return }
  done
}

cs_app_file() { # id -> key list of an app (user override first, then built-in; OS variant first)
  local d f os=$CS_OS
  for d in "$CS_CONFIG_DIR/apps" "$CS_ROOT/defaults/apps"; do
    for f in "$1.$os.txt" "$1.txt"; do
      [[ -f "$d/$f" ]] && { print -r -- "$d/$f"; return }
    done
  done
}

cs_terminal_file() { # id -> shortcut list (user override first, then built-in, then generic)
  local id=$1 os=$CS_OS d f
  for d in "$CS_CONFIG_DIR/terminals" "$CS_ROOT/defaults/terminals"; do
    for f in "$id.$os.txt" "$id.txt"; do
      [[ -f "$d/$f" ]] && { print -r -- "$d/$f"; return }
    done
  done
  f="$CS_ROOT/defaults/terminals/generic.$os.txt"
  [[ -f "$f" ]] && print -r -- "$f"
}
