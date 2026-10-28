# Mugiwara UI

A glass + neon UI library for Roblox script hubs, themed after Luffy's **Gear 5**: black glass, white → gold → orange → red gradients and a rotating neon border. Pure Luau, one file, no image assets.

> Status: **v0.1 (beta)**. The logic is covered by a smoke test, but the visuals still need tuning on real executors. Open an issue with a screenshot if something looks off.

## Quick start

```lua
local MugiwaraUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-UI/main/dist/main.lua"))()

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

## Features

- Glass window with animated neon border, drag, resize, minimize to a floating button, `RightShift` toggle
- Mobile friendly: scales down to fit small screens, touch dragging, no hover-only interactions
- Tabs, collapsible sections, 10 element types, notifications, dialogs
- 4 built-in themes with live switching, plus custom themes
- Config saving (JSON) with flags, auto-load, and a ready-made config manager section
- Executor-safe: every executor API is optional and wrapped (`gethui`, `cloneref`, file functions, ...)
- Re-running the script replaces the old UI instead of stacking copies

## API

### Library

| Call | Description |
| --- | --- |
| `MugiwaraUI:CreateWindow(opts)` | Creates a window |
| `MugiwaraUI:Notify(opts)` | Toast: `Title`, `Content`, `Duration` (0 = sticky), `Type` (`info`/`success`/`warning`/`error`) |
| `MugiwaraUI:SetTheme(name)` / `GetTheme()` / `GetThemes()` | Switch themes live |
| `MugiwaraUI:AddTheme(name, tokens)` | Register a theme (see below) |
| `MugiwaraUI.Icons.Register({ name = "rbxassetid://..." })` | Register icons usable as `Icon = "name"` |
| `MugiwaraUI:Destroy()` | Remove every window |

### Window options

| Option | Default | Notes |
| --- | --- | --- |
| `Title`, `Subtitle` | `"Mugiwara UI"` | Topbar text |
| `Icon` | letter badge | Asset id / registered icon |
| `Size` | `640x430` | `UDim2.fromOffset(w, h)` |
| `MinSize`, `MaxSize` | `470x320`, `1000x760` | Resize limits |
| `Resizable` | `true` | Bottom-right grip |
| `Folder` | `"MugiwaraUI"` | Workspace folder for configs |
| `ToggleKey` | `Enum.KeyCode.RightShift` | |
| `Blur` | `false` | Blurs the game behind the window |
| `Neon` | `true` | Glow rings around the window |
| `OpenButton` | `true` | `false` removes the floating button; `{ Title = "M" }` sets its glyph |
| `ConfirmClose` | `true` | Ask before the X button destroys the UI |
| `ShowUser` | `true` | Avatar chip in the sidebar |
| `SideBarWidth` | `176` (`150` on mobile) | |

Window methods: `Tab`, `SelectTab`, `SidebarLabel`, `SidebarDivider`, `Dialog`, `Notify`, `SetTitle`, `SetTheme`, `SetBlur`, `SetScale`, `SetToggleKey`, `Open`, `Close`, `Toggle`, `Destroy`, `SaveConfig`, `LoadConfig`, `DeleteConfig`, `GetConfigs`, `LoadAutoConfig`, `ConfigSection`.

### Elements

Tabs and sections share the same element methods. All elements accept `Title`, `Desc`, `Flag` (enables config saving), `Locked`, and return an object with `Set`, `Get`, `SetTitle`, `SetDesc`, `SetVisible`, `Lock`, `Unlock`, `Destroy`.

```lua
tab:Button({ Title, Desc, Callback })
tab:Toggle({ Title, Value, Callback(state) })
tab:Slider({ Title, Value = { Min, Max, Default }, Step, Suffix, Callback(value) })
tab:Dropdown({ Title, Values, Value, Multi, AllowNone, Searchable, Callback(value) })  -- el:Refresh(values, keepSelection)
tab:Input({ Title, Value, Placeholder, Numeric, Type = "Input" | "Textarea", Callback(text) })
tab:Keybind({ Title, Value = "K", Callback(), OnChange(key) })
tab:Colorpicker({ Title, Default, Transparency, Callback(color, transparency) })
tab:Label({ Title })
tab:Paragraph({ Title, Desc })
tab:Divider({ Title })                     -- Title optional
tab:Section({ Title, Opened })             -- returns a container; section:SetOpen(bool)
```

### Themes

Built in: `Gear5` (default), `Sunrise`, `Joyboy`, `Gomu`.

```lua
MugiwaraUI:AddTheme("Mine", {
    Accent = Color3.fromRGB(80, 200, 255),
    Gradient = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(80, 200, 255), Color3.fromRGB(120, 80, 255) },
    BackgroundAlpha = 0.3, -- more see-through glass
})
MugiwaraUI:SetTheme("Mine")
```

Unspecified tokens fall back to `Gear5`. Tokens live in [`src/core/Theme.lua`](src/core/Theme.lua).

### Configs

Give elements a `Flag`, then either call `Window:SaveConfig("name")` / `LoadConfig("name")` yourself or drop a manager into any tab:

```lua
Window:ConfigSection(SettingsTab)
Window:LoadAutoConfig() -- call after the whole UI is built
```

Files go to `<Folder>/configs/`. An index file keeps the list working on executors without `listfiles`.

## Executor notes

Developed against the common executors (Delta, Xeno, Solara and similar). Only these are used, each optional: `gethui`, `cloneref`, `identifyexecutor`, `writefile`/`readfile`/`isfile`/`makefolder`/`isfolder`/`delfile`, `setclipboard`. Without file functions the UI works and config saving reports that it is unavailable. GUI parent order is `gethui()` → `CoreGui` → `PlayerGui`.

## Development

```bash
npm install
npm test        # build + static check + smoke test
npm run build   # bundle src/ into dist/main.lua
```

- `src/` — modules, loaded with `Import("path")`; the build bundles them into one file
- `build/check.mjs` — syntax and undefined-global check
- `tests/` — Roblox API mock + smoke test (runs on Lua 5.3 via fengari; checks logic, not rendering)

Commit `dist/main.lua` after building: that file is what `loadstring` fetches.

## Credits

The API shape is inspired by [WindUI](https://github.com/Footagesus/WindUI) by Footagesus (MIT). Mugiwara UI is a from-scratch implementation with its own design and code.

## License

MIT — see [LICENSE](LICENSE).
