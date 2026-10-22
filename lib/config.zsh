# Shared settings loader for panel.zsh and sheet.zsh.
# User config lives in herdr's per-plugin config dir so plugin updates never overwrite it.
CS_ROOT="${CS_ROOT:-${0:A:h:h}}"
CS_CONFIG_DIR="${CHEATSHEET_CONFIG_DIR:-${HERDR_PLUGIN_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr-cheatsheet}}"
CS_PLUGIN_ID="${CHEATSHEET_PLUGIN_ID:-${HERDR_PLUGIN_ID:-}}"
HERDR_CONFIG="${HERDR_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"

# defaults; values already in the environment win, config.zsh (sourced below) wins over both
: ${CHEATSHEET_RATIO:=0.80} ${CHEATSHEET_AUTO_OPEN:=all} ${CHEATSHEET_TERMINAL:=auto}
: ${CHEATSHEET_TERMINAL_KEYS:=} ${CHEATSHEET_TERMINAL_NAME:=} ${CHEATSHEET_ALIAS_FILE=.project.zsh}
: ${CHEATSHEET_BANNER:=on} ${CHEATSHEET_AGENTS:=all} ${CHEATSHEET_AGENTS_MAX:=8}

if mkdir -p "$CS_CONFIG_DIR" 2>/dev/null; then
  [[ -f "$CS_CONFIG_DIR/config.zsh" ]] || cp "$CS_ROOT/defaults/config.zsh" "$CS_CONFIG_DIR/config.zsh" 2>/dev/null
fi
[[ -f "$CS_CONFIG_DIR/config.zsh" ]] && source "$CS_CONFIG_DIR/config.zsh"

# v0.1.0 seeded an iTerm list into terminal-keys.txt. An untouched copy means "detect the terminal";
# an edited copy keeps being shown as before.
if [[ -n "$CHEATSHEET_TERMINAL_KEYS" && -f "$CHEATSHEET_TERMINAL_KEYS" &&
      "$(cksum < "$CHEATSHEET_TERMINAL_KEYS")" == "3593249569 440" ]]; then
  CHEATSHEET_TERMINAL_KEYS=""
fi

source "$CS_ROOT/lib/terminal.zsh"
