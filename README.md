# herdr-cheatsheet

A clickable cheat-sheet panel for [herdr](https://herdr.dev). It docks on the right of your tabs and shows:

- **just**: the recipes of the project you're working in, from the nearest `justfile` above the focused pane's directory. It follows focus between projects.
- **herdr**: the core keybindings resolved from herdr's defaults plus your `config.toml` overrides, and all of your custom `[[keys.command]]` bindings with their descriptions.
- **Terminal keys**: an editable list of your terminal emulator's shortcuts (iTerm defaults included).

Rows marked `▸` run when you click them:

- **Recipes** run inside the panel. Press any key to return, and Ctrl-C stops long-running ones.
- **herdr actions** like new tab, split, zoom, rename or new workspace run through herdr's CLI.
- **Your custom bindings** run as configured.

```
just — my-app
 ▸build         [xb] Build the app for the simulator
 ▸run           [xr] Build, install and launch on the simulator
 ▸test          [xt] Run tests; one spec: `just test SomeSpec`

herdr (prefix ^B)
  ^B ?          help (all keys)
 ▸^B c          new tab
 ▸^B ⇧t         rename tab
 ▸^B v          split right
 ▸^B ⌥r         just run (build + launch in simulator)
 ▸^B ⇧k         toggle cheat sheet

iTerm
  ⌘T            new tab
  ⌘D            split right

 click ▸ to run · r refresh · q close
```

## Requirements

- herdr 0.9.5 or newer, on macOS or Linux
- `zsh` and `jq`
- [`just`](https://github.com/casey/just) (optional, needed for the recipe section)

## Install

```sh
herdr plugin install ChristianDeckert/herdr-cheatsheet
```

herdr shows the manifest and scripts before installing. Add a toggle key to `~/.config/herdr/config.toml` and reload with `herdr server reload-config`:

```toml
[[keys.command]]
key = "prefix+shift+k"
type = "plugin_action"
command = "christiandeckert.cheatsheet.toggle"
description = "toggle cheat sheet"
```

The panel appears in new workspaces and tabs right away. To add it to the tab you're in, press the toggle key. To add it to tab 1 of every existing workspace, restart the server:

```sh
herdr server stop && herdr
```

## Configuration

On first run the plugin copies two files into its config directory. Print the directory with `herdr plugin config-dir christiandeckert.cheatsheet`. Plugin updates never touch these files.

**`config.zsh`**

| Setting | Default | Meaning |
|---|---|---|
| `CHEATSHEET_RATIO` | `0.80` | Share kept by the main pane (`0.80` = 20% wide panel) |
| `CHEATSHEET_AUTO_OPEN` | `all` | `all`: every new tab · `first`: tab 1 of each workspace · `off`: toggle key only |
| `CHEATSHEET_TERMINAL_NAME` | `iTerm` | Heading of the terminal-keys section (`""` hides it) |
| `CHEATSHEET_TERMINAL_KEYS` | `terminal-keys.txt` | File with `keys\|description` lines |
| `CHEATSHEET_ALIAS_FILE` | `.project.zsh` | Optional file in a project root whose `alias x='just recipe'` lines appear next to the recipes |

**`terminal-keys.txt`**: one `keys|description` per line. Lines starting with `#` are ignored. Replace the iTerm defaults with your own shortcuts, for example for WezTerm, Ghostty or Kitty.

Content changes show up within two seconds. Width and auto-open settings apply to newly opened panels.

## How it works

- `panel.zsh` manages the pane. It opens a right split labeled `cheatsheet`, and runs on herdr startup, `workspace.created`, `tab.created` and the toggle action.
- herdr restores panes after a restart as plain shells. The startup hook finds the labeled pane and restarts the sheet in it instead of opening a second panel.
- `sheet.zsh` draws the panel and redraws only when the focused project, the justfile, your herdr config, the terminal keys file or the pane size changes. It enables mouse reporting so herdr forwards clicks to it.
- Rows that only exist in herdr's UI are dimmed and do nothing on click: help, workspace picker, goto, sidebar, scrollback editor. So are destructive ones: close pane, detach.

## Uninstall

```sh
herdr plugin uninstall christiandeckert.cheatsheet
```

Then remove the `[[keys.command]]` entry and close any open panels with `q`.

## Trust

Like every herdr plugin, this runs as ordinary code under your user account. Read `panel.zsh` and `sheet.zsh` before installing. Clicking a `just` recipe or a custom binding runs exactly that command in the focused project's directory.

## License

MIT
