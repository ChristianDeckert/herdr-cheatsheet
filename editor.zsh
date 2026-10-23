#!/bin/zsh
# Runs the editor for a file picked in the cheat sheet's search, in the tab opened for it. When the
# editor exits, the tab closes too, together with the cheat sheet that opened in it, unless other panes
# have joined the tab since.
CS_ROOT="${0:A:h}"
source "$CS_ROOT/lib/config.zsh"
H="${HERDR_BIN_PATH:-herdr}"
${=CHEATSHEET_EDITOR_CMD:-vi} "$CHEATSHEET_FILE"
others=$("$H" pane list | cs_jq -r --arg t "$HERDR_TAB_ID" --arg me "$HERDR_PANE_ID" \
  "$CS_SHEET_JQ"' [.result.panes[] | select(.tab_id == $t and .pane_id != $me and (sheet | not))] | length')
[[ $others == 0 ]] && "$H" tab close "$HERDR_TAB_ID" >/dev/null
