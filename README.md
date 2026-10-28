# Mugiwara UI

A glass + neon UI library for Roblox script hubs, themed after Luffy's **Gear 5**: black glass, white → gold → orange → red gradients and a rotating neon border. Pure Luau, one file, no image assets.

> Status: **beta**. Logic is covered by automated tests; the visuals are checked by hand on real executors. Open an issue with a screenshot if something looks off.

**Documentation:** this README is the full reference · [CHANGELOG.md](CHANGELOG.md) what changed in each version · [server/worker/README.md](server/worker/README.md) the chat backend · [CLAUDE.md](CLAUDE.md) the project guide for AI-assisted sessions (architecture, rules learned, decisions).

## Install

Load a **pinned version** (recommended). A tag never changes, so a later push cannot break the hubs that use it:

```lua
local MugiwaraUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-UI/v0.8.0/dist/main.lua"))()
```

`.../main/dist/main.lua` always serves the newest build (GitHub caches it for about 5 minutes). Available tags are listed in the
[CHANGELOG](CHANGELOG.md).

## Quick start

```lua
local MugiwaraUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-UI/v0.8.0/dist/main.lua"))()

local Window = MugiwaraUI:CreateWindow({
    Title = "Mugiwara Hub",
    Subtitle = "Gear 5 edition",
    Folder = "MugiwaraHub",
})

local Main = Window:Tab({ Title = "Main" })

Main:Toggle({
    Title = "Auto Farm",
    Flag = "autofarm",
    Callback = function(state) print(state) end,
})

MugiwaraUI:Notify({ Title = "Loaded", Content = "Yohoho!", Type = "success" })
```

See [`examples/showcase.lua`](examples/showcase.lua) for every element.

## Try it

[`examples/dummy.lua`](examples/dummy.lua) is a fake hub that uses every feature (nothing touches the game). Paste it into your executor and run it.

To test local changes without pushing: run `npm run build`, copy `dist/main.lua` into your executor's `workspace` folder as `MugiwaraUI.lua`, then run the dummy. It loads that local file first and only falls back to GitHub when it is missing.

## The flow: Key UI > Loading UI > Main UI

Three pieces of the same set, all drawn in the active theme:

```lua
local MugiwaraUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-UI/v0.8.0/dist/main.lua"))()

-- 1) Key UI: a separate card. Validate is YOUR check (HTTP request, hash...), it may yield.
local KeyUI = MugiwaraUI:KeySystem({
    Title = "Mugiwara Hub",
    Folder = "MugiwaraHub",
    Links = { { Title = "Get Key", Icon = "lucide:external-link", Link = "https://example.com/key" } },
    Validate = function(key)
        return key == "secret", "That key is not valid" -- true / false, message
    end,
})
local key = KeyUI:Wait()       -- yields until accepted; nil when the user closed the card
if not key then return end

-- 2) Loading UI: the loader never ends on its own, call Finish()
local Loader = MugiwaraUI:Loading({ Title = "Mugiwara Hub", Owner = "Honami", Version = "v1.0.0" })
Loader:SetStatus("Loading modules")
Loader:SetProgress(40, 70)     -- jump to 40%, then creep toward 70% while the stage runs
Loader:Log("Fetching data", "info")
Loader:Finish("Welcome!")
Loader.Finished:Wait()         -- resumes when the loading card is gone

-- 3) Main UI
local Window = MugiwaraUI:CreateWindow({ Title = "Mugiwara Hub" })
```

Run [`examples/dummy-flow.lua`](examples/dummy-flow.lua) to see it (any key is accepted there).

**Key UI options:** `Title`, `Subtitle`, `Icon`, `Note` (`false` hides it), `Placeholder`, `Folder`, `Validate(key)` (**required**, must return `true` to accept), `Links` (`{ Title, Link, Icon, Callback }`; a `Link` is copied to the clipboard because executors cannot open a browser), `Heading`, `SaveKey` (default `true`: an accepted key is always saved for the next run; `false` never saves), `OnSuccess(key)`, `OnClose()`. The card is wide (21:9): identity on the left, the form on the right.
Methods: `Wait()`, `Submit(key)`, `Close()`, `ClearSavedKey()`, `SetStatus(text, kind)`; `KeyUI.Completed` is a signal. When a saved key still validates, the Key UI is skipped entirely and `Wait()` returns immediately; an outdated saved key is deleted and the card shows up.

**Loading UI options:** `Title`, `Owner`, `Version`, `Terminal` (terminal window title), `Prompt`, `Logs` (list of fake log lines), `MaxLogLines`, `InstantCover`.
Methods: `SetStatus(text)`, `SetProgress(target, cap)`, `Log(text, "info"|"ok"|"warn"|"error")`, `Finish(message)`, `Destroy()`; `Loader.Finished` (signal, `:Wait()` / `:Connect()`) and `Loader.FinishEvent:Fire()`. The running loader is also available as `getgenv().MugiwaraLoader`.

## Features

- Glass window with animated neon border: drag, resize, **maximize**, minimize to a floating button, `RightShift` toggle
- Top bar with a **theme menu** and a **version badge**
- Optional **wallpaper** for the whole window and **image cards** for single elements
- Mobile friendly: scales down to fit small screens, touch dragging, no hover-only interactions
- Tabs, **tab sections** (collapsible sidebar groups), collapsible sections nestable up to **2 levels**, 16 element types (including live chat), row layout, notifications, dialogs
- Color picker popup: color square, hue slider, opacity slider (0-100), HEX / RGB / HSV / HSL fields
- 4 built-in themes with live switching, plus custom themes
- Config saving (JSON) with flags, auto-load, and a ready-made config manager section
- Executor-safe: every executor API is optional and wrapped (`gethui`, `cloneref`, file functions, ...)
- Re-running the script replaces the old UI instead of stacking copies

## API

### Library

| Call | Description |
| --- | --- |
| `MugiwaraUI:CreateWindow(opts)` | Creates a window (options below) |
| `MugiwaraUI:KeySystem(opts)` | Key UI card, see "The flow" |
| `MugiwaraUI:Loading(opts)` | Loading UI card, see "The flow" |
| `MugiwaraUI:Notify(opts)` | Toast: `Title`, `Content`, `Duration` (seconds, 0 = sticky), `Type` (`info`/`success`/`warning`/`error`); at most 6 on screen |
| `MugiwaraUI:SetTheme(name)` / `GetTheme()` / `GetThemes()` | Switch themes live |
| `MugiwaraUI:AddTheme(name, tokens)` | Register a theme (see below) |
| `MugiwaraUI:SetIconSet(name)` / `PreloadIcons(...)` | Default icon set / download sets in the background |
| `MugiwaraUI:SetGlyphs({ Close = "lucide:x", ... })` | Icons of the built-in controls (before `CreateWindow`) |
| `MugiwaraUI.Icons.Register({ name = "rbxassetid://..." })` | Register icons usable as `Icon = "name"` |
| `MugiwaraUI.ChatTransports` | `Http` and `Memory` transports for `tab:Chat` |
| `MugiwaraUI.Version`, `MugiwaraUI.Compat` | Library version; executor helpers (`Executor`, `FilesSupported`, `SetClipboard`...) |
| `MugiwaraUI:Destroy()` | Remove every window, loader, key card and toast |

### Window options

| Option | Default | Notes |
| --- | --- | --- |
| `Title`, `Subtitle` | `"Mugiwara UI"` | Topbar text |
| `Version` | none | Badge next to the title, e.g. `"v1.2.0"` |
| `ThemeSwitcher` | `true` | Theme menu button in the top bar |
| `Background` | the theme's wallpaper | `nil` = wallpaper of the current theme, `false` = none, or yours: `"rbxassetid://..."` / `{ Image, Transparency, Dim }` |
| `Icon` | letter badge | Asset id / registered icon |
| `Size` | `640x430` | `UDim2.fromOffset(w, h)` |
| `MinSize`, `MaxSize` | `480x340`, `1000x760` | Resize limits |
| `Theme` | `"Gear 5"` | Starting theme name |
| `OnDestroy` | none | Function called when the window is destroyed |
| `Resizable` | `true` | Bottom-right grip |
| `Folder` | `"MugiwaraUI"` | Workspace folder for configs |
| `ToggleKey` | `Enum.KeyCode.RightShift` | |
| `Blur` | `false` | Blurs the game behind the window |
| `Neon` | `true` | Glow rings around the window |
| `OpenButton` | `true` | The floating button that reopens a minimized window. Sits in the middle of the left edge and can be dragged. `false` removes it; `{ Title = "M", Position = UDim2.new(0, 36, 0.5, 0) }` changes the glyph / start position |
| `ConfirmClose` | `true` | Ask before the X button destroys the UI |
| `ShowUser` | `true` | Avatar chip in the sidebar |
| `SideBarWidth` | `176` (`150` on mobile) | |

Dialogs: `Window:Dialog({ Title, Content, Buttons = { { Title, Style = "Primary" | "Secondary" | "Danger", Callback } } })`.

Window methods: `Tab`, `TabSection`, `SelectTab`, `SidebarLabel`, `SidebarDivider`, `Dialog`, `Notify`, `SetTitle`, `SetVersion`, `SetTheme`, `OpenThemeMenu`, `SetBackground`, `UseThemeBackground`, `SetBlur`, `SetScale`, `SetToggleKey`, `SetMaximized`, `ToggleMaximized`, `Open`, `Close`, `Toggle`, `Destroy`, `SaveConfig`, `LoadConfig`, `DeleteConfig`, `GetConfigs`, `LoadAutoConfig`, `ConfigSection`.

### Layout: tabs and sections

```
Window
 ├─ Tab                          flat tab in the sidebar
 ├─ TabSection (collapsible)     titled group of tabs; one level only
 │    └─ Tab
 │         ├─ elements
 │         └─ Section (level 1)  collapsible group
 │              ├─ elements
 │              └─ Section (level 2)   the deepest allowed ("double section")
 │                   └─ elements        a 3rd level raises an error
```

```lua
local Combat = Window:TabSection({ Title = "Combat", Opened = true })
local Aim = Combat:Tab({ Title = "Aim" })          -- tabs inside a tab section
local Misc = Window:Tab({ Title = "Misc" })        -- or a plain tab

local Outer = Aim:Section({ Title = "Targeting" })
local Inner = Outer:Section({ Title = "Filters" }) -- double section
Inner:Toggle({ Title = "Ignore friends" })
```

### Elements

Tabs and sections share the same element methods. All elements accept `Title`, `Desc`, `Flag` (enables config saving), `Locked`, `Image` (card background, asset id or URL) and `ImageTransparency`, and return an object with `Set`, `Get`, `SetTitle`, `SetDesc`, `SetVisible`, `Lock`, `Unlock`, `Destroy`.

```lua
tab:Button({ Title, Desc, Callback })
tab:Toggle({ Title, Value, Callback(state) })
tab:Slider({ Title, Value = { Min, Max, Default }, Step, Suffix, Callback(value) })
tab:Dropdown({ Title, Values, Value, Multi, AllowNone, Searchable, Callback(value) })  -- el:Refresh(values, keepSelection)
--   Values: "text" or { Title, Desc, Icon, IconColor } per item (title only, title + icon, or everything); Get() returns the Title
tab:Input({ Title, Value, Placeholder, Numeric, Type = "Input" | "Textarea", Callback(text) })
tab:Keybind({ Title, Value = "K", Callback(), OnChange(key) })
tab:Colorpicker({ Title, Default, Transparency, Callback(color, transparency) })  -- opens a popup
tab:Label({ Title })
tab:Paragraph({ Title, Desc })
tab:Divider({ Title })                     -- Title optional
tab:ProgressBar({ Title, Value, Min, Max, Suffix })   -- el:Set(value) animates; el:SetText("custom")
tab:Code({ Title, Code, Language = "lua", Copy = true, Height = 220 })  -- Lua highlighted, copy button, scrolls sideways
tab:Image({ Image, Height = 150, Scale = "Crop" | "Fit" | "Stretch", Title })  -- asset id / URL; el:SetImage(...)
tab:Space(16)                              -- blank gap
tab:Chat({ Transport = ..., Height = 340 })   -- live chat, see "Live chat" below
local row = tab:Group({ Gap = 8 })         -- children share the width side by side
row:Button({ Title = "A" }); row:Button({ Title = "B" })
tab:Section({ Title, Opened })             -- returns a container; section:SetOpen(bool)
```

### Icons

Tabs, the window logo and every element accept an `Icon`:

```lua
local Window = MugiwaraUI:CreateWindow({ Title = "Hub", Icon = "lucide:sun" })
local Farm = Window:Tab({ Title = "Farm", Icon = "swords" })        -- default set is lucide
Farm:Toggle({ Title = "Auto Farm", Icon = "lucide:flame" })
Farm:Button({ Title = "Open", Icon = "craft:folder-stroke" })       -- "set:name"
local el = Farm:Label({ Title = "Dynamic", Icon = "solar:crown-bold" })
el:SetIcon("geist:bell")                                            -- returns false if the icon was not found
```

**Colors.** Icons follow the theme accent by default. `IconColor` (on any element, tab or dropdown item) takes a `Color3` (fixed) or a theme token name such as `"Success"` / `"Danger"` (follows the theme); `el:SetIconColor(color)` changes it later and `nil` goes back to the accent. Tabs: `IconColor` is used idle and selected; add `IconColorActive` for a different selected color, or `tab:SetIconColor(idle, active)`. Asset-id icons are tinted too.

```lua
Farm:Toggle({ Title = "Auto Farm", Icon = "lucide:flame", IconColor = Color3.fromRGB(255, 120, 40) })
Farm:Button({ Title = "Heal", Icon = "lucide:heart", IconColor = "Success" })
Window:Tab({ Title = "Combat", Icon = "lucide:swords", IconColor = Color3.fromRGB(255, 90, 90), IconColorActive = Color3.new(1, 1, 1) })
```

**Built-in controls** (dropdown arrow, check marks, close / minimize / maximize / restore) are lucide icons too. They start as drawn shapes so nothing is missing offline, and swap to the icon when it is available. Change them before `CreateWindow`: `MugiwaraUI:SetGlyphs({ Close = "lucide:circle-x", Check = "lucide:check-check" })` (names: `Chevron`, `Check`, `Close`, `Minus`, `Square`, `Restore`; any icon name or asset id; `false` keeps the drawn version).

- Sets: `lucide` (default), `craft`, `geist`, `gravity`, `solar`. Change the default with `MugiwaraUI:SetIconSet("craft")`.
- Plain asset ids (`"rbxassetid://123"`, `123`) and names added with `MugiwaraUI.Icons.Register({ name = id })` also work; those are drawn in their own colors.
- The icon data is **not bundled**. It comes from [Footagesus/Icons](https://github.com/Footagesus/Icons) (MIT) and is loaded per set the first time one of its icons is used (Lucide is about 85 KB, Solar about 440 KB), then cached in `MugiwaraUI/cache` in the executor workspace. Use `MugiwaraUI:PreloadIcons("lucide", "solar")` to fetch in the background.
- The download is **pinned to a single commit**, so a later push to that repository cannot change what runs on your users' machines. Bump `COMMIT` in [`src/core/IconSets.lua`](src/core/IconSets.lua) to update.
- If a set cannot be downloaded, tabs fall back to a letter badge and elements simply show no icon.
- `sfsymbols` exists upstream but is intentionally disabled: Apple's license only allows SF Symbols in apps for Apple platforms.

### Live chat

`tab:Chat` is a chat room for everyone running your hub: Roblox names and avatars, history, replies, deleting your own
messages, muting people, a "new messages" pill when you are reading older ones. The element only draws the chat; a
**transport** moves the messages:

```lua
-- real chat: deploy the Cloudflare Worker from server/worker (free, ~5 minutes, see server/worker/README.md)
local transport = MugiwaraUI.ChatTransports.Http({
    Url = "https://mugiwara-chat.<you>.workers.dev",
    Channel = "global",     -- other names are separate rooms
    Folder = "MugiwaraHub", -- the device token is stored here
})

-- no backend yet: fake players chat with you (for trying the UI)
-- local transport = MugiwaraUI.ChatTransports.Memory()

local chat = tab:Chat({
    Title = "Live Chat",
    Transport = transport,
    Height = 340,
    MaxLength = 200,
    BackgroundPoll = 20, -- optional: keep listening while hidden so OnMessage can notify
    OnMessage = function(message) print(message.DisplayName, message.Text) end,
})
```

Click a message to Reply / Copy / Delete (your own) / Mute (someone else's). Options: `Height`, `MaxLength` (200),
`Cooldown` (1.5 s between sends), `History` (messages per page, 50), `PollInterval` (3 s while people talk),
`IdlePollInterval` (8 s), `BackgroundPoll`, `Notice`, `Placeholder`, `OnMessage(message)` (called one at a time, `NotifySpacing` seconds apart (0.8), and only for the newest `NotifyLimit` (5) messages of a burst; never for muted users).
Methods: `Send(text)`, `Refresh()`, `Clear()`, `Mute(userId)`, `Unmute(userId)`, `GetMuted()`, `GetMessages()`.

Things to know:

- **Names**: the client sends `LocalPlayer`'s name; the Worker replaces it with what Roblox's API says for that user id
  (so a display name cannot be invented; if Roblox rate-limits the lookup, a *new* account is asked to try again in a moment) and binds each Roblox user id to a per-device secret token the first time it
  sends, so nobody can post as an account that already chatted or delete its messages. Which person is behind an id
  still cannot be proven from an executor.
- **No moderation** (no word lists, bans or reports), but there are cheap safeguards, all configurable: a **kill
  switch** (on / read-only / off with one SQL command, clients show "Read-only" / "Disabled"), per-user and
  per-network rate limits, **retention** (messages expire after `RETENTION_HOURS`, default 72), reserved names
  ("Owner", "Admin"...), and an optional link / phone-number filter that is off by default. See
  [server/worker/README.md](server/worker/README.md#safeguards).
- **Privacy**: messages, Roblox ids and names are stored in your own D1 database and Roblox does not filter this chat.
  The chat shows a privacy banner until the user taps "Got it" (`Notice = false` hides it, `Notice = "text"` replaces it;
  the Worker's `NOTICE` variable changes it without republishing the hub).
- Polling only runs while the chat is on screen (3 s while people talk, 8 s otherwise, backing off when offline).
- Message text is never parsed as RichText, and names are escaped.
- Writing your own backend: a transport is a table with `User`, `History`, `Poll`, `Send`, `Delete` (see
  [`ChatTransports.lua`](src/components/ChatTransports.lua) for the exact contract).

Demo: [`examples/dummy-chat.lua`](examples/dummy-chat.lua).

### Background images

Two options, both optional:

- **Wallpaper** (recommended): one image behind the whole window. The glass cards let it show through, so it reads as a single picture instead of cropped pieces. Every theme ships its own (transparency 0.3, it changes with the theme). Replace it with `Window:SetBackground("rbxassetid://...", 0.3, 0.45)` (image, transparency, dark scrim) or the `Background` window option; `Background = false` / `SetBackground(nil)` removes it and `Window:UseThemeBackground()` brings the theme's back.
- **Image card**: `Image = "..."` on any element puts a picture inside that one card. It fades in from the right so the title stays readable.

**Store images are Decals.** The id you copy from the Roblox Store / Toolbox is a *Decal* id, and an `ImageLabel` cannot display it. Mugiwara UI detects this and reads the real image out of the Decal for you (needs `game:GetObjects`, which most executors have). If it cannot, you get a notification saying so; then use the asset's **Image id** instead (in Studio: insert the decal, copy the `Texture` property). A notification also appears when Roblox refuses to load the image (private or moderated asset).

Images can be an asset id, `rbxassetid://...`, or an http(s) URL. URLs are downloaded once into `<Folder>/cache` and need `request`, `writefile` and `getcustomasset` on the executor; otherwise they are skipped silently.

### Themes

Built in: `Gear 5` (default, white), `Gear 4` (black and red), `Gear 3` (yellow and red) and `Normal` (orange, red, white, black, yellow). Switch from the dot in the top bar or with `MugiwaraUI:SetTheme(name)`; gradients cross-fade.

```lua
MugiwaraUI:AddTheme("Mine", {
    Accent = Color3.fromRGB(80, 200, 255),
    Gradient = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(80, 200, 255), Color3.fromRGB(120, 80, 255) },
    BackgroundAlpha = 0.3, -- more see-through glass
})
MugiwaraUI:SetTheme("Mine")
```

A theme can carry its own picture: `Wallpaper = "rbxassetid://..."`, `WallpaperAlpha` (0.3) and `WallpaperDim` (0.4); `Desc` is the line shown in the theme menu. Unspecified tokens fall back to the `Normal` palette. Tokens live in [`src/core/Theme.lua`](src/core/Theme.lua).

### Configs

Give elements a `Flag`, then either call `Window:SaveConfig("name")` / `LoadConfig("name")` yourself or drop a manager into any tab:

```lua
Window:ConfigSection(SettingsTab)
Window:LoadAutoConfig() -- call after the whole UI is built
```

Files go to `<Folder>/configs/`. An index file keeps the list working on executors without `listfiles`.

## Migrating from WindUI

The element and option names follow WindUI where it was practical (`Tab`, `Button`, `Toggle`, `Slider` with `Value = { Min, Max, Default }`, `Dropdown`, `Input`, `Keybind`, `Colorpicker`, `Paragraph`, `Divider`, `Notify`, `Dialog`, `CreateWindow` with `Title` / `Icon` / `Folder` / `Size` / `Theme`), so simple hubs mostly port by changing the loader line. It is **not** a 1:1 replacement.

Elements in WindUI's source tree and where they stand here:

| WindUI | Mugiwara UI |
| --- | --- |
| Button, Toggle, Slider, Dropdown, Input, Keybind, Colorpicker, Paragraph, Divider, Section | available |
| Key system | available as a separate Key UI (not a `CreateWindow` option) |
| Code, ProgressBar, Image, Space | available |
| (not in WindUI) Chat | `tab:Chat`, needs the Cloudflare Worker in `server/worker` |
| Group / HStack | `tab:Group()` (a row; equal widths). VStack is simply the default (elements stack vertically) |
| Video, Viewport | **missing** |

Other differences to check when porting: config saving goes through `Flag` + `Window:SaveConfig` / `ConfigSection` (not WindUI's config manager API), sections can be nested at most 2 levels, and the sidebar group is `Window:TabSection`.

## Executor notes

Developed against the common executors (Delta, Xeno, Solara and similar). Every executor function is optional and guarded: `gethui`, `cloneref`, `identifyexecutor`, `loadstring`, `game:HttpGet`, `request`, `writefile`/`readfile`/`isfile`/`makefolder`/`isfolder`/`delfile`, `setclipboard`/`getclipboard`, `getcustomasset`. Without file functions the UI works, but configs, saved keys, cached icons and the chat device token are unavailable (each reports it or falls back). Without `request`, the chat shows Offline. GUI parent order is `gethui()` → `CoreGui` → `PlayerGui`.

## Development

```bash
npm install
npm test        # build + static check + Lua tests + chat Worker tests
npm run build   # bundle src/ into dist/main.lua
```

- `src/` — modules, loaded with `Import("path")`; the build bundles them into one file
- `build/check.mjs` — syntax and undefined-global check
- `tests/` — Roblox API mock + smoke / flow / chat tests (Lua 5.3 via fengari; checks logic, not rendering)
- `server/worker/` — the chat backend (Cloudflare Worker + D1) and its tests

Commit `dist/main.lua` after building: that file is what `loadstring` fetches. Releases are git tags (see [CLAUDE.md](CLAUDE.md#releasing)).

## Credits

Icons are loaded from [Footagesus/Icons](https://github.com/Footagesus/Icons) (MIT, Copyright (c) 2025 Footages), which converts these upstream sets. Their licenses apply to the icons themselves:

| Set | Upstream | License |
| --- | --- | --- |
| Lucide | [lucide-icons/lucide](https://github.com/lucide-icons/lucide) | ISC |
| Gravity UI | [gravity-ui/icons](https://gravity-ui.com/icons) | MIT |
| Solar | [480 Design](https://icones.js.org/collection/solar) | CC BY 4.0 (attribution required) |
| Geist | [Vercel Geist](https://vercel.com/geist/icons) | check upstream |
| Craft | [Figma community file](https://www.figma.com/community/file/1415718327120418204) | check upstream |

The API shape is inspired by [WindUI](https://github.com/Footagesus/WindUI) by Footagesus (MIT). Mugiwara UI is a from-scratch implementation with its own design and code.

## License

MIT — see [LICENSE](LICENSE).
