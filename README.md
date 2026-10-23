# herdr-cheatsheet

A clickable cheat-sheet panel for [herdr](https://herdr.dev). It docks on the right of your tabs, follows whatever you're working on, and puts the keys and commands you need one click away.

## tl;dr: at a glance

```sh
herdr plugin install ChristianDeckert/herdr-cheatsheet
```

Add two keys to `~/.config/herdr/config.toml`, then run `herdr server reload-config`:

```toml
[[keys.command]]
key = "prefix+shift+k"
type = "plugin_action"
command = "christiandeckert.cheatsheet.toggle"
description = "toggle cheat sheet"

[[keys.command]]
key = "prefix+f"
type = "plugin_action"
command = "christiandeckert.cheatsheet.search"
description = "search files"
```

- The panel opens on the right of every new tab. `prefix+shift+k` shows or hides it, `prefix+f` searches the project's files.
- Click any row marked `▸` to run it: just recipes, herdr actions, your own bindings, agents, the keys of the app running in the tab (vim, lazygit, Claude Code and 18 more), and ready-made ffmpeg and compression commands, which get typed at your shell prompt.
- Keys inside the panel: `/` search files · `e` open with · `r` refresh · `b` logo · `t` colors · `q` close · `u` update.
- Settings live in `config.zsh` in `$(herdr plugin config-dir christiandeckert.cheatsheet)`.
- Needs herdr 0.9.4+, zsh and jq on macOS or Linux; just, fzf and rg are optional.

<p align="center">
  <img src="docs/screenshot.png" alt="The cheat-sheet panel: logo, file search field, just recipes, grouped herdr keys, detected iTerm2 shortcuts, agent overview and panel controls" width="420">
</p>

## Features

### What the panel shows

- **Logo**: "CHEATSHEET" in the ANSI Shadow style with a retro gradient, and the focused project's path. Narrow panels get a compact logo.
- **File search**: a search field for the project's files. See [Search and open files](#search-and-open-files).
- **App keys**: while a known app runs in the tab, a section with its essential keys appears, and disappears when the app quits. Clicking a key sends it to the app: editors (Fresh, vim, Helix, micro, nano), file managers (superfile, yazi, ranger, nnn, lf, Midnight Commander), git and DevOps tools (lazygit, tig, gitui, lazydocker, k9s), system monitors (htop, btop, top) and AI agents (Claude Code, Codex). See [App keys](#app-keys).
- **just recipes**: the recipes of the project you're working in, from the nearest `justfile`, with the shortcuts from an optional `.project.zsh` (`alias xb='just build'`) next to them. The section follows focus between projects and only appears when there is a justfile.
- **herdr keys**: herdr's defaults plus your `config.toml` overrides, grouped into tabs, panes, workspaces, agents and herdr itself, with your own `[[keys.command]]` bindings under "your keys".
- **Tools**: ready-made commands for ffmpeg, tar, zip, gzip, xz, zstd, 7-Zip, bzip2 and brotli, always shown. See [Tools](#tools).
- **Terminal keys**: the default shortcuts of the terminal you're attached from (iTerm2, Terminal.app, Ghostty, WezTerm, kitty, Alacritty, Hyper, VS Code, GNOME Terminal, Konsole, Windows Terminal), detected automatically, with macOS and Linux variants. See [Terminal detection](#terminal-detection).
- **Agents**: every agent across your workspaces with its status, blocked and finished ones first. `(here)` marks the ones in the current tab.
- **Panel controls**: refresh, hide or show the logo, switch colors, close.
- **Update status**: `update to x.y.z` under the logo when a new version is out, otherwise `✓ up to date` at the bottom.

### Search and open files

- Start the search with your search key (`prefix+f` with the binding from [Install](#install)), `/` in the panel, or a click on the field. The key also moves the focus into the panel.
- Matches appear as you type, fuzzy-ranked with fzf when it's installed (`lgnvw` finds `LoginView.swift`). The search covers the project's git root and skips what `.gitignore` lists.
- Enter or a click opens the file in a new, focused tab named after it, with its own cheat sheet. Quitting the editor closes the tab again.
- **open with** (key `e`) lists the editors installed on your machine: terminal editors, GUI apps like VS Code, Cursor or Xcode (their own window), superfile (opens with the file selected), plus the system's fallbacks. Your pick applies to all panels.
- Without a terminal editor beyond vi, vim and nano, the panel suggests installing Fresh and superfile, in one click with Homebrew.

### One click away

Rows marked `▸` run when you click them:

- **Recipes** run inside the panel. Press any key to return, and Ctrl-C stops long-running ones.
- **herdr actions** run through herdr: new tab, split, zoom, next/previous pane, move tab, close pane, tab or workspace, reload config and more. Close rows act immediately. Rename and new-worktree rows ask for a name inside the panel.
- **Your custom bindings** run as configured: plugin actions through herdr, `pane` and `popup` commands inside the panel, `shell` commands in the background.
- **Agents** take you to that agent's pane, in any workspace.
- **Tools** type their command at a shell prompt in the tab, without Enter, with the cursor on the first `{placeholder}` to fill in. See [Tools](#tools).
- **App keys** send the key to the app's pane and focus it: `:w` saves in vim, `P` pushes in lazygit, `F9` kills in htop. See [App keys](#app-keys).
- **Update**: click `update to x.y.z` or press `u` to run `herdr plugin update`, which shows what changed and asks first. Every open panel then restarts on the new version.

The mouse wheel scrolls the panel when it's taller than the pane.

### Fits your terminal

- **Light and dark**: the panel asks the terminal for its background and switches between a pastel and a deeper palette, live when the terminal changes appearance.
- **Retro or terminal colors** (key `t`): the logo's pink, lavender and cyan, or your theme's own colors.
- **Logo on or off** (key `b`). The pane's frame shows the name `cheatsheet` only while the logo is hidden.
- **Width**: 54 columns by default, enough for the full logo, at most 40% of the tab.
- **Key symbols**: `⌃ ⌥ ⇧ ⌘` on macOS, `^` for Control on Linux.

### Stays out of your way

- It opens in every new workspace and tab, or only on request, as you configure it. The toggle key opens or closes it in the current tab.
- It runs as a herdr plugin pane, directly and without your shell, so your shell history, prompt hooks and `.zshrc` are never involved.
- After a herdr restart, the panels come back by themselves.
- It redraws only when something it shows changes: the focused project, a justfile, your herdr config, an agent's status, a running app, the pane size.

### Example

```
 ███╗█╗ █╗████╗ ██╗ █████╗████╗█╗ █╗████╗████╗█████╗
█╔══╝█║ █║█╔══╝█╔═█╗╚═█╔═╝█╔══╝█║ █║█╔══╝█╔══╝╚═█╔═╝
█║   ████║███╗ ████║  █║  ████╗████║███╗ ███╗   █║
█║   █╔═█║█╔═╝ █╔═█║  █║  ╚══█║█╔═█║█╔═╝ █╔═╝   █║
╚███╗█║ █║████╗█║ █║  █║  ████║█║ █║████╗████╗  █║
 ╚══╝╚╝ ╚╝╚═══╝╚╝ ╚╝  ╚╝  ╚═══╝╚╝ ╚╝╚═══╝╚═══╝  ╚╝
 ~/code/my-app

files
 ╭───────────────────────────────────────────────────╮
 │ search files…                                ⌃B f │
 ╰───────────────────────────────────────────────────╯
 ▸ e             open with: fresh

just — my-app
 ▸ build         [xb] Build the app for the simulator
 ▸ run           [xr] Build, install and launch on the simulator
 ▸ test          [xt] Run tests; one spec: `just test SomeSpec`

herdr (prefix ⌃B)
 tabs ─────────────────────────────────────────────
 ▸ ⌃B c          new tab
 ▸ ⌃B ⇧t         rename tab
 ▸ ⌃B ⇧x         close tab
 panes ────────────────────────────────────────────
 ▸ ⌃B v          split right
 ▸ ⌃B z          zoom pane
 herdr ────────────────────────────────────────────
   ⌃B ?          help (all keys)
 your keys ────────────────────────────────────────
 ▸ ⌃B ⌥r         just run (build + launch in simulator)
 ▸ ⌃B ⇧k         toggle cheat sheet

iTerm2 (detected)
 tabs ─────────────────────────────────────────────
   ⌘T            new tab
 panes ────────────────────────────────────────────
   ⌘D            split vertically (right)

agents (1 blocked · 2 idle · 1 working)
 ▸ ● blocked  api · Waiting for approval
 ▸ ◐ working  my-app · Refactor login flow (here)
 ▸ ○ idle     docs · Update changelog
 ▸ ○ idle     my-app · Fix flaky test

panel
 ▸ r             refresh
 ▸ b             hide logo
 ▸ t             terminal colors
 ▸ q             close panel
```

## Requirements

- herdr 0.9.4 or newer, on macOS or Linux
- `zsh` and `jq`
- [`just`](https://github.com/casey/just) (optional, needed for the recipe section)
- optional for the file search: [`fzf`](https://github.com/junegunn/fzf) for fuzzy ranking, [`rg`](https://github.com/BurntSushi/ripgrep) or [`fd`](https://github.com/sharkdp/fd) for fast file listing. Without them it falls back to `git ls-files` or `find` and an in-order match

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

[[keys.command]]
key = "prefix+f"
type = "plugin_action"
command = "christiandeckert.cheatsheet.search"
description = "search files"
```

The second binding starts the file search from anywhere in the tab and puts the focus in the panel.

The panel appears in new workspaces and tabs right away. To add it to the tab you're in, press the toggle key. To add it to tab 1 of every existing workspace, restart the server:

```sh
herdr server stop && herdr
```

## Configuration

On first run the plugin copies `config.zsh` into its config directory. Print the directory with `herdr plugin config-dir christiandeckert.cheatsheet`. Plugin updates never touch it. Every setting is commented out at its default; uncomment a line to change it.

| Setting | Default | Meaning |
|---|---|---|
| `CHEATSHEET_WIDTH` | `54` | Panel width in content columns; 54 fits the full logo. At most 40% of the tab |
| `CHEATSHEET_RATIO` | — | A fixed share kept by the main pane instead (`0.80` = 20% wide panel) |
| `CHEATSHEET_AUTO_OPEN` | `all` | `all`: every new tab · `first`: tab 1 of each workspace · `off`: toggle key only |
| `CHEATSHEET_BANNER` | `on` | `off` hides the logo banner. The panel's `b` row toggles it for all panels and overrides this setting |
| `CHEATSHEET_COLORS` | `retro` | `retro`: the pastel palette, deeper on light backgrounds · `terminal`: the theme's own magenta, blue and cyan. The panel's `t` row toggles it for all panels and overrides this setting |
| `CHEATSHEET_APPEARANCE` | `auto` | `auto` asks the terminal whether its background is light or dark; `dark` or `light` forces one |
| `CHEATSHEET_AGENTS` | `all` | `all` agents, `attention` (only blocked and done ones) or `off` |
| `CHEATSHEET_AGENTS_MAX` | `8` | Maximum agent rows, the rest is summarized as `+N more` |
| `CHEATSHEET_UPDATE_CHECK` | `on` | `off` turns off the update notice and its request to GitHub |
| `CHEATSHEET_TERMINAL` | `auto` | `auto` detects the terminal, `off` hides the section, or a terminal id from the table below |
| `CHEATSHEET_OS` | detected | `macos` or `linux`, picks which list variant is shown |
| `CHEATSHEET_TERMINAL_KEYS` | — | Show your own `keys\|description` file instead of a built-in list |
| `CHEATSHEET_TERMINAL_NAME` | — | Heading for that file |
| `CHEATSHEET_EDITOR` | — | Editor for files opened from the search. The panel's **open with** choice overrides it. Without either: `$VISUAL`, `$EDITOR`, then the first installed terminal editor (fresh, nvim, hx, micro, emacs, kak, vim, nano), then `vi`. GUI editors (`code`, `cursor`, `zed`, `subl`, `xed`, …) open in their own window, superfile (`spf`) with the file selected in its folder |
| `CHEATSHEET_APPS` | `on` | `off` hides the key sections of running apps |
| `CHEATSHEET_TOOLS` | `on` | `off` hides the tools section |
| `CHEATSHEET_ALIAS_FILE` | `.project.zsh` | Optional file in a project root whose `alias x='just recipe'` lines appear next to the recipes |

Content changes show up within two seconds; press `r` in the panel to detect the terminal again and check for updates. Width and auto-open settings apply to newly opened panels.

## Terminal detection

Inside herdr every pane reports `TERM_PROGRAM=herdr`, so the plugin looks at the herdr client process instead. It walks up its process tree to the terminal app, which also works when you attach from a different terminal than the one that started the server. When you attach over SSH, or when no local client is found, it falls back to environment hints the server inherited, such as `__CFBundleIdentifier`, `KITTY_WINDOW_ID`, `WEZTERM_PANE`, `WT_SESSION` or `VTE_VERSION`. Unknown terminals get a short generic list plus a hint to set `CHEATSHEET_TERMINAL`.

| Id | Terminal | Lists |
|---|---|---|
| `iterm` | iTerm2 | macOS |
| `apple-terminal` | Terminal.app | macOS |
| `ghostty` | Ghostty | macOS, Linux |
| `wezterm` | WezTerm | macOS, Linux |
| `kitty` | kitty | macOS, Linux |
| `alacritty` | Alacritty | macOS, Linux |
| `hyper` | Hyper | macOS, Linux |
| `vscode` | VS Code integrated terminal | macOS, Linux |
| `gnome-terminal` | GNOME Terminal, Console, Ptyxis, Tilix (VTE) | Linux |
| `konsole` | Konsole | Linux |
| `windows-terminal` | Windows Terminal (WSL) | Linux |
| `generic` | anything else | macOS, Linux |

Every list contains defaults confirmed in the terminal's official documentation or default configuration; each file names its sources in a `# source:` line. If you've remapped keys, override a list: copy it from the plugin's `defaults/terminals/` into a `terminals/` folder inside the config directory, keep the file name (for example `terminals/ghostty.macos.txt`) and edit it. Format: a `# name: Heading` line, then one `keys|description` per line. A `## label` line starts a group.

## App keys

The panel asks herdr which processes run in the foreground of its tab's panes (`herdr pane process-info`), adds the ones herdr can't inspect (macOS's `top` runs as root) from `ps` by the pane's foreground process group, and shows a key section for each app it knows. Scripts run by an interpreter (ranger under Python) are matched by the script's name:

| Kind | App | Process names | List |
|---|---|---|---|
| editor | Fresh | `fresh` | `fresh.txt` |
| editor | Vim | `vi`, `vim`, `nvim`, `view`, `vimdiff` | `vim.txt` |
| editor | Helix | `hx`, `helix` | `helix.txt` |
| editor | micro | `micro` | `micro.txt` |
| editor | GNU nano | `nano` | `nano.txt` |
| file manager | superfile | `spf`, `superfile` | `superfile.txt` |
| file manager | yazi | `yazi` | `yazi.txt` |
| file manager | ranger | `ranger` (also run as a Python script) | `ranger.txt` |
| file manager | nnn | `nnn` | `nnn.txt` |
| file manager | lf | `lf` | `lf.txt` |
| file manager | Midnight Commander | `mc` | `mc.txt` |
| git | lazygit | `lazygit` | `lazygit.txt` |
| git | tig | `tig` | `tig.txt` |
| git | gitui | `gitui` | `gitui.txt` |
| DevOps | lazydocker | `lazydocker` | `lazydocker.txt` |
| DevOps | k9s | `k9s` | `k9s.txt` |
| monitor | htop | `htop` | `htop.txt` |
| monitor | btop | `btop` | `btop.txt` |
| monitor | top | `top` | `top.macos.txt`, `top.linux.txt` |
| AI agent | Claude Code | `claude` | `claude.txt` |
| AI agent | Codex | `codex` (also its npm launcher and platform builds) | `codex.txt` |

Agent sections appear in every tab where an agent runs, so a tab with Claude Code in its main pane always shows Claude Code's keys. Lists with an OS suffix (`top.macos.txt`) are picked for that OS; overrides can use the same suffix.

Each list contains default keys confirmed in the app's documentation or default config and names its sources in a `# source:` line. To adapt one to your own bindings, copy it from the plugin's `defaults/apps/` into an `apps/` folder inside the config directory and edit it there; same format as the terminal lists. Keys are written as `Ctrl+`, `Alt+` and `Shift+` and shown as `⌃ ⌥ ⇧` on macOS.

### Clicking app keys

A click sends the row's key to the pane the app runs in, through `herdr pane send-keys` or `send-text`, and focuses that pane:

- Key combos (`Ctrl+S`, `Shift+Tab`, `F5`, `PgUp`) are sent as keys, typed keys and sequences (`q`, `gg`, `dd`) as text, and ex commands (`:w`, `:q!`) as text plus Enter.
- Entries that pair keys with actions (`Ctrl+Z / Ctrl+Y | undo / redo`) become one row per action. Entries listing alternative keys for one action (`F9 / k | kill process`) send the first key.
- Key sequences such as `Esc Esc` or Helix's `Space f` are sent in order; search placeholders (`/text`) send just the `/` that opens the app's search prompt.
- In vim and Helix every click sends Esc first, so a click never types into your file while insert mode is on.
- Ranges like `1-5` stay dimmed.

macOS ships UW Pico as `/usr/bin/nano`. Its keys differ from GNU nano's, so the nano section only appears for GNU nano (for example `brew install nano`).

## Tools

The tools section lists ready-made commands, grouped by tool:

| Tool | Commands |
|---|---|
| ffmpeg | convert to mp4, extract audio, trim, compress, make a gif, resize to 720p, show info (`ffprobe`) |
| tar | create `.tar.gz`, `.tar.xz`, `.tar.zst`; extract; list |
| zip | zip a folder, unzip into a folder, list |
| gzip, xz, zstd, bzip2, brotli | compress keeping the original, decompress |
| 7-Zip | create `.7z`, extract into a folder |

Placeholders are written in braces, `{input}`, `{output}`, `{dir}`, `{start}` and `{end}`, and highlighted in the panel. A click types the command at a shell prompt in the tab, the main pane first, without pressing Enter, puts the cursor on the first placeholder and focuses that pane. Braces rather than `<input>` because the shell would read `<` and `>` as redirects if one is left in by mistake. When no pane in the tab sits at a shell prompt (Claude Code or an editor in every pane), the command goes to the clipboard instead. Every command was run on test files with the installed tools, except 7-Zip's, which follow its documentation, and uses flags that both GNU and BSD tar accept; `.tar.zst` needs GNU tar 1.31 or newer and `zstd` installed. To change the list, copy the plugin's `defaults/tools.txt` into the config directory and edit it: `## tool` lines start a group, then one `command|description` per line.

## How it works

- The panel is a herdr plugin pane: herdr starts `sheet.zsh` directly, without your shell, and closes the pane when it exits (`q`, Ctrl-C or the toggle key). Nothing is typed into a shell, so your shell history, prompt hooks and `.zshrc` are never involved.
- `panel.zsh` opens and closes it on herdr startup, `workspace.created`, `tab.created` and the toggle action. herdr opens plugin panes at half width, so it then resizes the split to `CHEATSHEET_WIDTH` columns (or `CHEATSHEET_RATIO`).
- When a panel starts, it compares the installed commit (`herdr plugin list --json`) with the repository's latest one using a single `git ls-remote` to github.com. If they differ, it also downloads the new `herdr-plugin.toml` to show the version number. Panels that start together share one result, which is stored with any error in the plugin's state directory (`~/.local/state/herdr/plugins/christiandeckert.cheatsheet/update`). Local or linked installs aren't checked.
- herdr restores plugin panes after a server restart as plain shells. The startup hook closes such a pane and opens a fresh panel in its place, instead of opening a second one.
- Colors follow the terminal's theme. At start and on `r` the panel asks for the background color and the light/dark color scheme, which herdr answers for the terminal you're attached from. It also turns on color-scheme reports, so it switches between its dark and light palette as soon as the terminal does. Without an answer it assumes a dark background.
- The pane frame shows the name `cheatsheet` only while the logo is hidden, since the logo already names the panel. Panels are recognized by their title, by that name, or by their working directory: herdr runs plugin panes in the plugin's install directory and restores them there.
- Before 0.5.0 the panel was started by typing a command into a shell pane, which added a `CHEATSHEET_PLUGIN_ID=… zsh …/sheet.zsh` line to your shell history every time. Panels from those versions replace themselves with a plugin pane after updating. To remove the old history lines (zsh, macOS `sed`): `sed -i '' '/CHEATSHEET_PLUGIN_ID=/d' ~/.zsh_history`.
- The file search starts at the focused project's git root (or its directory). It lists files with `rg --files`, `fd`, `git ls-files` or `find`, whichever is available first; the first three skip what `.gitignore` lists, `find` skips `.git`, `node_modules`, `DerivedData`, `build` and `Pods`. Results are ranked with `fzf --filter` when fzf is installed, else the typed characters must appear in order. Terminal editors run in a plugin pane in a new tab, without your shell. When the editor exits, the tab closes with its cheat sheet, unless you've added other panes to it. Esc leaves the search and returns the focus to your pane.
- `sheet.zsh` draws the panel and redraws only when the focused project, the justfile or alias file, your herdr config, the terminal list, an agent's status or the pane size changes. It enables mouse reporting so herdr forwards clicks and the scroll wheel to it, and keeps terminal echo off so mouse input never shows up as text. When the content is taller than the pane, the wheel scrolls it.
- The herdr section lists herdr's default keys plus any optional action you've bound in `config.toml` (next/previous workspace or agent, last pane, move tab, clear pane, worktrees). Every action herdr can run from outside its UI is clickable, using its CLI or socket API. That includes closing a pane, tab or workspace, which happens immediately, like the key. The dimmed rows are herdr UI only: help, workspace picker, goto, sidebar, resize mode, settings, jump to notification, open worktree and detach. Key ranges like go to tab `1..9`, focus pane h/j/k/l and last pane are dimmed too.

## Uninstall

```sh
herdr plugin uninstall christiandeckert.cheatsheet
```

Then remove the `[[keys.command]]` entries and close any open panels with `q`.

## Trust

Like every herdr plugin, this runs as ordinary code under your user account. Read `panel.zsh`, `sheet.zsh` and `editor.zsh` before installing. Clicking a `just` recipe or a custom binding runs exactly that command in the focused project's directory, an install row runs exactly the `brew install` command it shows, an app key row sends exactly the key it shows to that app, and a tools row only types its command at your prompt; you press Enter.

## License

MIT
