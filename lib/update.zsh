# Update notice for GitHub installs, sourced by sheet.zsh.
# All panels share one result file and redraw when it changes.
zmodload zsh/datetime
UPDATE_FILE="$CS_STATE_DIR/update"
# The panel that runs an update writes the new plugin root here; every panel then restarts from it.
ROOT_FILE="$CS_STATE_DIR/root"
typeset -A UPDATE

plugin_info() { # prints kind, owner, repo, commit, version, root (tab separated)
  "$H" plugin list --json --plugin "$CS_PLUGIN_ID" 2>/dev/null | jq -r '.result.plugins[0] |
    [.source.kind, .source.owner, .source.repo, .source.resolved_commit, .version, .plugin_root] | @tsv'
}

write_update_file() { # lines
  print -rl -- "$@" > "$UPDATE_FILE.tmp" && mv "$UPDATE_FILE.tmp" "$UPDATE_FILE"
}

fetch_update() {
  setopt local_options extended_glob
  local kind owner repo installed version root remote ver
  IFS=$'\t' read -r kind owner repo installed version root <<< "$(plugin_info)"
  if [[ $kind != github ]]; then
    write_update_file "skipped=installed from ${kind:-unknown source}"
    return
  fi
  remote=$(GIT_TERMINAL_PROMPT=0 git -c http.lowSpeedLimit=100 -c http.lowSpeedTime=15 \
    ls-remote "https://github.com/$owner/$repo.git" HEAD 2>&1)
  if [[ $? -ne 0 || ${remote%%$'\t'*} != [0-9a-f](#c40) ]]; then
    write_update_file "installed=$installed" "current=$version" "error=git ls-remote: ${${(f)remote}[1]}"
    return
  fi
  remote=${remote%%$'\t'*}
  if [[ $remote != $installed ]]; then
    ver=$(curl -fsS --max-time 15 "https://raw.githubusercontent.com/$owner/$repo/$remote/herdr-plugin.toml" |
      sed -n 's/^version *= *"\(.*\)".*/\1/p')
  fi
  write_update_file "installed=$installed" "current=$version" "remote=$remote" "version=${ver//[^0-9A-Za-z.+-]/}"
}

# Starts a background check; runs when a panel starts and on refresh. Panels starting together (herdr
# startup restores all of them at once) reuse a result younger than a minute instead of each asking GitHub.
update_check() { # [force]
  [[ $CHEATSHEET_UPDATE_CHECK == off || -z $CS_PLUGIN_ID ]] && return
  local lock="$UPDATE_FILE.lock"
  [[ $1 != force && -f $UPDATE_FILE ]] && (( EPOCHSECONDS - $(zstat +mtime "$UPDATE_FILE") < 60 )) && return
  # a lock left behind by a killed check expires after ten minutes
  [[ -d $lock ]] && (( EPOCHSECONDS - $(zstat +mtime "$lock") > 600 )) && rmdir "$lock" 2>/dev/null
  mkdir "$lock" 2>/dev/null || return
  ( { fetch_update } always { rmdir "$lock" 2>/dev/null } ) </dev/null >/dev/null 2>&1 &!
}

read_update() {
  local l
  UPDATE=()
  [[ -f $UPDATE_FILE ]] || return
  for l in "${(@f)$(<$UPDATE_FILE)}"; do UPDATE[${l%%=*}]=${l#*=}; done
}

update_available() { [[ -n $UPDATE[remote] && $UPDATE[remote] != $UPDATE[installed] ]] }

# An available update goes under the banner where it is seen; the quiet status lines go last.
render_update() {
  read_update
  update_available || return
  line ""
  row "u" "update to ${UPDATE[version]:-the latest version}" "$B$K" "panel:update"
}

render_update_status() {
  update_available && return
  if [[ -n $UPDATE[error] ]]; then
    line ""
    line " ${D}✗ update check failed, r retries${R}"
  elif [[ -n $UPDATE[remote] ]]; then
    line ""
    line " ${D}✓ up to date${UPDATE[current]:+ · $UPDATE[current]}${R}"
  fi
}

# Runs herdr's own update (it shows what changed and asks before installing).
update_now() {
  local kind owner repo before after version root
  IFS=$'\t' read -r kind owner repo before version root <<< "$(plugin_info)"
  run_inline "${(q)H} plugin update ${(q)CS_PLUGIN_ID}" wait
  IFS=$'\t' read -r kind owner repo after version root <<< "$(plugin_info)"
  [[ -n $after && $after != $before ]] || return
  read_update
  write_update_file "installed=$after" "current=$version" "remote=${UPDATE[remote]}" "version=${UPDATE[version]}"
  print -r -- "$root" > "$ROOT_FILE.tmp" && mv "$ROOT_FILE.tmp" "$ROOT_FILE"
}

# Restarts this panel from the new plugin root once an update was installed from any panel.
follow_update() {
  local m root
  m=$(zstat +mtime "$ROOT_FILE" 2>/dev/null)
  [[ $m == $ROOT_STAMP ]] && return
  ROOT_STAMP=$m
  root=$(<"$ROOT_FILE")
  [[ $root != $ROOT && -f $root/sheet.zsh ]] || return
  printf '%s\e[?25h' "$MOUSE_OFF"
  normal_tty
  exec zsh "$root/sheet.zsh"
}
