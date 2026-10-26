#!/bin/sh
# herdr-cheatsheet installer: installs or updates the plugin and adds its two key bindings.
#
#   curl -fsSL https://raw.githubusercontent.com/ChristianDeckert/herdr-cheatsheet/main/install.sh | sh
#   ... | sh -s -- --yes          install without herdr's review prompt
#   ... | sh -s -- --uninstall    remove the plugin and the key bindings this script added
set -eu

REPO=ChristianDeckert/herdr-cheatsheet
ID=christiandeckert.cheatsheet
MIN_HERDR=0.9.4
TOGGLE_KEY=prefix+alt+k
# 0.6.5 and older bound the toggle here. herdr silently drops a built-in default whose key a user
# binding takes, and this one is swap-pane-up.
OLD_TOGGLE_KEY=prefix+shift+k
# the same file herdr reads
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml"
BACKUP="" CREATED=0

say() { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
die() { printf 'herdr-cheatsheet: %s\n' "$*" >&2; exit 1; }

usage() {
  say "usage: install.sh [--yes] [--uninstall]"
  say "  --yes        install or update without herdr's review prompt"
  say "  --uninstall  remove the plugin and the key bindings this script added"
}

YES=0 MODE=install
for arg in "$@"; do
  case $arg in
    -y|--yes) YES=1 ;;
    --uninstall) MODE=uninstall ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown option: $arg" ;;
  esac
done

install_hint() { # tool
  if command -v brew >/dev/null 2>&1; then say "brew install $1"
  elif command -v apt-get >/dev/null 2>&1; then say "sudo apt-get install $1"
  elif command -v dnf >/dev/null 2>&1; then say "sudo dnf install $1"
  elif command -v pacman >/dev/null 2>&1; then say "sudo pacman -S $1"
  else say "install $1 with your package manager"
  fi
}

version_ge() { # a b: is a >= b, for dotted numbers
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | head -n 1)" = "$2" ]
}

# herdr asks before installing; it reads the answer from the terminal, since stdin is this script.
herdr_confirmed() { # herdr arguments...
  if [ "$YES" = 1 ]; then
    herdr "$@" --yes
  elif (: </dev/tty) 2>/dev/null; then
    herdr "$@" </dev/tty
  else
    die "no terminal to confirm in; run it again with: sh -s -- --yes"
  fi
}

plugin_source() { # github, local or nothing
  herdr plugin list --json --plugin "$ID" 2>/dev/null |
    jq -r '.result.plugins[0].source.kind // empty' 2>/dev/null || true
}

backup_config() {
  [ -n "$BACKUP" ] && return 0
  BACKUP="$CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$CONFIG" "$BACKUP"
}

# herdr rejects a broken config; then the previous version goes back in place.
check_config() {
  if ! out=$(herdr config check 2>&1); then
    if [ -n "$BACKUP" ]; then cp "$BACKUP" "$CONFIG"; elif [ "$CREATED" = 1 ]; then rm -f "$CONFIG"; fi
    die "herdr rejected $CONFIG, restored the previous version:
$out"
  fi
}

# A binding is assigned as key = "…" in a [[keys.command]] block or as action = "…" in [keys].
key_used() { # key
  k=$(printf '%s' "$1" | sed 's/[+.]/\\&/g')
  grep -Eq "=[[:space:]]*[\"']$k[\"']" "$CONFIG" 2>/dev/null && return 0
  # built-in defaults that herdr --default-config doesn't list
  case $1 in prefix+shift+[hjkl]) return 0 ;; esac
  herdr --default-config 2>/dev/null | grep -Eq "^#[[:space:]]*[a-z_]+[[:space:]]*=[[:space:]]*\"$k\""
}

action_bound() { # action
  grep -Eq "^[[:space:]]*command[[:space:]]*=[[:space:]]*[\"']$ID\\.$1[\"']" "$CONFIG" 2>/dev/null
}

ADDED="" SKIPPED=""
add_binding() { # action key description
  if action_bound "$1"; then
    info "$3: already bound in your config"
    return
  fi
  if key_used "$2"; then
    SKIPPED="$SKIPPED $1"
    info "$3: $2 is already in use, so no key was added. To bind another key, add:"
    printf '\n[[keys.command]]\nkey = "prefix+..."\ntype = "plugin_action"\ncommand = "%s.%s"\ndescription = "%s"\n\n' "$ID" "$1" "$3"
    return
  fi
  [ "$CREATED" = 1 ] || backup_config
  printf '\n[[keys.command]]\nkey = "%s"\ntype = "plugin_action"\ncommand = "%s.%s"\ndescription = "%s"\n' \
    "$2" "$ID" "$1" "$3" >> "$CONFIG"
  ADDED="$ADDED $2"
  info "$3: added $2"
}

# The toggle's [[keys.command]] blocks: "<all> <made by an older version of this script>".
toggle_blocks() {
  awk -v cmd="$ID.toggle" -v old="$OLD_TOGGLE_KEY" '
    function val(s) { sub(/^[^=]*=[[:space:]]*/, "", s); gsub(/^["\047]|["\047][[:space:]]*$/, "", s); return s }
    function flush() { if (c == cmd) { all++; if (k == old && d == "toggle cheat sheet") ours++ } k = c = d = ""; inb = 0 }
    /^[[:space:]]*\[/ { flush(); if ($0 ~ /^[[:space:]]*\[\[keys\.command\]\]/) inb = 1; next }
    inb && /^[[:space:]]*key[[:space:]]*=/ { k = val($0) }
    inb && /^[[:space:]]*command[[:space:]]*=/ { c = val($0) }
    inb && /^[[:space:]]*description[[:space:]]*=/ { d = val($0) }
    END { flush(); print all + 0, ours + 0 }' "$CONFIG"
}

# Removes the old toggle block (drop) or gives it the new key (rekey).
rewrite_toggle_block() { # drop|rekey
  tmp="$CONFIG.tmp.$$"
  cp "$CONFIG" "$tmp"
  awk -v cmd="$ID.toggle" -v old="$OLD_TOGGLE_KEY" -v new="$TOGGLE_KEY" -v mode="$1" '
    function val(s) { sub(/^[^=]*=[[:space:]]*/, "", s); gsub(/^["\047]|["\047][[:space:]]*$/, "", s); return s }
    function flush() {
      hit = (c == cmd && k == old && d == "toggle cheat sheet")
      for (i = 1; i <= n; i++) {
        if (hit && mode == "drop") continue
        if (hit && buf[i] ~ /^[[:space:]]*key[[:space:]]*=/) buf[i] = "key = \"" new "\""
        print buf[i]
      }
      n = 0; k = c = d = ""; inb = 0
    }
    /^[[:space:]]*\[/ { flush(); if ($0 ~ /^[[:space:]]*\[\[keys\.command\]\]/) inb = 1 }
    inb {
      buf[++n] = $0
      if ($0 ~ /^[[:space:]]*key[[:space:]]*=/) k = val($0)
      if ($0 ~ /^[[:space:]]*command[[:space:]]*=/) c = val($0)
      if ($0 ~ /^[[:space:]]*description[[:space:]]*=/) d = val($0)
      next
    }
    { print }
    END { flush() }' "$tmp" > "$CONFIG"
  rm -f "$tmp"
}

MIGRATED=""
migrate_toggle_key() {
  [ -f "$CONFIG" ] || return 0
  set -- $(toggle_blocks)
  [ "$2" -gt 0 ] || return 0
  if [ "$1" -gt "$2" ]; then
    backup_config
    rewrite_toggle_block drop
    MIGRATED=drop
    info "toggle cheat sheet: removed $OLD_TOGGLE_KEY, which replaced herdr's swap-pane-up; your other toggle key stays"
  elif key_used "$TOGGLE_KEY"; then
    info "toggle cheat sheet: $OLD_TOGGLE_KEY replaces herdr's swap-pane-up, and $TOGGLE_KEY is taken. To free swap-pane-up, give the toggle another key in $CONFIG"
  else
    backup_config
    rewrite_toggle_block rekey
    MIGRATED=rekey
    info "toggle cheat sheet: moved from $OLD_TOGGLE_KEY to $TOGGLE_KEY, so herdr's swap-pane-up works again"
  fi
}

reload_config() {
  if herdr server reload-config >/dev/null 2>&1; then
    info "reloaded herdr's config"
  else
    info "herdr isn't running; the keys work the next time you start it"
  fi
}

# --- checks
command -v herdr >/dev/null 2>&1 ||
  die "herdr isn't installed. Install it first: curl -fsSL https://herdr.dev/install.sh | sh"
command -v jq >/dev/null 2>&1 || die "jq is needed: $(install_hint jq)"

if [ "$MODE" = uninstall ]; then
  say "Removing herdr-cheatsheet"
  if [ -n "$(plugin_source)" ]; then
    herdr plugin uninstall "$ID" >/dev/null && info "uninstalled the plugin"
  else
    info "the plugin isn't installed"
  fi
  if [ -f "$CONFIG" ] && grep -q "$ID\\." "$CONFIG"; then
    backup_config
    # drops each [[keys.command]] block whose command is one of this plugin's actions
    awk -v pat="^[[:space:]]*command[[:space:]]*=[[:space:]]*[\"']christiandeckert[.]cheatsheet[.]" '
      function flush() { if (!drop) for (i = 1; i <= n; i++) print buf[i]; n = 0; drop = 0; inb = 0 }
      /^[[:space:]]*\[/ { flush(); if ($0 ~ /^[[:space:]]*\[\[keys\.command\]\]/) inb = 1 }
      inb { buf[++n] = $0; if ($0 ~ pat) drop = 1; next }
      { print }
      END { flush() }' "$BACKUP" > "$CONFIG"
    check_config
    reload_config
    info "removed its key bindings (backup: $BACKUP)"
  fi
  say "Done. Your settings stay in $(herdr plugin config-dir "$ID" 2>/dev/null || echo "herdr's plugin config folder")."
  exit 0
fi

version=$(herdr --version 2>/dev/null | awk '{ print $2 }')
version_ge "${version:-0}" "$MIN_HERDR" ||
  die "herdr $MIN_HERDR or newer is needed (you have ${version:-an unknown version}): herdr update"
command -v zsh >/dev/null 2>&1 || die "zsh is needed: $(install_hint zsh)"

# --- plugin
say "Installing herdr-cheatsheet"
case $(plugin_source) in
  github)
    info "already installed, updating"
    herdr_confirmed plugin update "$ID" ;;
  local)
    die "$ID is linked from a local folder (herdr plugin link). Unlink it first: herdr plugin unlink $ID" ;;
  *)
    herdr_confirmed plugin install "$REPO" ;;
esac
[ "$(plugin_source)" = github ] || die "the plugin wasn't installed"

# --- key bindings
mkdir -p "$(dirname "$CONFIG")"
if [ ! -f "$CONFIG" ]; then : > "$CONFIG"; CREATED=1; fi
migrate_toggle_key
add_binding toggle "$TOGGLE_KEY" "toggle cheat sheet"
add_binding search prefix+f "search files"
check_config
if [ -n "$ADDED" ] || [ -n "$MIGRATED" ]; then reload_config; fi

say ""
say "Done. New tabs and workspaces get the cheat sheet on the right."
case " $ADDED " in *" $TOGGLE_KEY "*) say "  $TOGGLE_KEY     show or hide it in the current tab" ;; esac
if [ "$MIGRATED" = rekey ]; then say "  $TOGGLE_KEY     show or hide it in the current tab (moved from $OLD_TOGGLE_KEY)"; fi
case " $ADDED " in *" prefix+f "*) say "  prefix+f         search the project's files" ;; esac
if [ -n "$BACKUP" ]; then say "  your previous config: $BACKUP"; fi
say "  uninstall: curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sh -s -- --uninstall"
