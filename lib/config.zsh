# Shared settings loader for panel.zsh and sheet.zsh.
# User config lives in herdr's per-plugin config dir so plugin updates never overwrite it.
CS_ROOT="${CS_ROOT:-${0:A:h:h}}"
CS_CONFIG_DIR="${CHEATSHEET_CONFIG_DIR:-${HERDR_PLUGIN_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr-cheatsheet}}"
CS_PLUGIN_ID="${CHEATSHEET_PLUGIN_ID:-${HERDR_PLUGIN_ID:-}}"
CS_STATE_DIR="${CHEATSHEET_STATE_DIR:-${HERDR_PLUGIN_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/herdr-cheatsheet}}"
HERDR_CONFIG="${HERDR_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"

# defaults; values already in the environment win, config.zsh (sourced below) wins over both
: ${CHEATSHEET_RATIO:=} ${CHEATSHEET_WIDTH:=54} ${CHEATSHEET_AUTO_OPEN:=all} ${CHEATSHEET_TERMINAL:=auto}
: ${CHEATSHEET_TERMINAL_KEYS:=} ${CHEATSHEET_TERMINAL_NAME:=} ${CHEATSHEET_ALIAS_FILE=.project.zsh}
: ${CHEATSHEET_BANNER:=on} ${CHEATSHEET_AGENTS:=all} ${CHEATSHEET_AGENTS_MAX:=8} ${CHEATSHEET_UPDATE_CHECK:=on}

mkdir -p "$CS_STATE_DIR" 2>/dev/null
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

# Cheat-sheet panes are recognized by their title "cheatsheet" while the sheet runs, by the label
# "cheatsheet" (set while the logo is hidden, and by versions before 0.5.5), or by their working
# directory: herdr runs plugin panes in the plugin root and restores them there, as plain shells, after
# a server restart. A GitHub install keeps every version in its own checkout below one directory, so
# that directory covers panels started by older versions too. Linked installs skip the directory test,
# since a developer's own shells may sit in the plugin root.
if [[ $CS_ROOT == */checkout && ${CS_ROOT:h:h:t} == "${CS_PLUGIN_ID}-"* ]]; then
  CS_PANE_HOME="${CS_ROOT:h:h}/"
else
  CS_PANE_HOME=""
fi
CS_SHEET_JQ='def sheet: .label == "cheatsheet" or .terminal_title_stripped == "cheatsheet"
  or ($home != "" and ((.cwd // "") | startswith($home)));'
cs_jq() { jq --arg home "$CS_PANE_HOME" "$@" }

source "$CS_ROOT/lib/terminal.zsh"
