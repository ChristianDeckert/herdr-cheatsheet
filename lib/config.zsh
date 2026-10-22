# Shared settings loader for panel.zsh and sheet.zsh.
# User config lives in herdr's per-plugin config dir so plugin updates never overwrite it.
CS_ROOT="${CS_ROOT:-${0:A:h:h}}"
CS_CONFIG_DIR="${CHEATSHEET_CONFIG_DIR:-${HERDR_PLUGIN_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr-cheatsheet}}"
CS_PLUGIN_ID="${CHEATSHEET_PLUGIN_ID:-${HERDR_PLUGIN_ID:-}}"
HERDR_CONFIG="${HERDR_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"

CHEATSHEET_RATIO=0.80
CHEATSHEET_AUTO_OPEN=all
CHEATSHEET_TERMINAL_NAME="iTerm"
CHEATSHEET_TERMINAL_KEYS="$CS_CONFIG_DIR/terminal-keys.txt"
CHEATSHEET_ALIAS_FILE=".project.zsh"

if mkdir -p "$CS_CONFIG_DIR" 2>/dev/null; then
  for f in config.zsh terminal-keys.txt; do
    [[ -f "$CS_CONFIG_DIR/$f" ]] || cp "$CS_ROOT/defaults/$f" "$CS_CONFIG_DIR/$f" 2>/dev/null
  done
fi
[[ -f "$CS_CONFIG_DIR/config.zsh" ]] && source "$CS_CONFIG_DIR/config.zsh"
