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

- Glass window with animated neon border: drag, resize, **maximize**, minimize to a floating button, `RightShift` toggle
- Top bar with a **theme menu** and a **version badge**
- Optional **wallpaper** for the whole window and **image cards** for single elements
- Mobile friendly: scales down to fit small screens, touch dragging, no hover-only interactions
- Tabs, **tab sections** (collapsible sidebar groups), collapsible sections nestable up to **2 levels**, 10 element types, notifications, dialogs
- Color picker popup: color square, hue slider, opacity slider (0-100), HEX / RGB / HSV / HSL fields
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
| `Version` | none | Badge next to the title, e.g. `"v1.2.0"` |
| `ThemeSwitcher` | `true` | Theme menu button in the top bar |
| `Background` | none | Wallpaper: `"rbxassetid://..."` or `{ Image, Transparency, Dim }` |
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

Window methods: `Tab`, `TabSection`, `SelectTab`, `SidebarLabel`, `SidebarDivider`, `Dialog`, `Notify`, `SetTitle`, `SetVersion`, `SetTheme`, `OpenThemeMenu`, `SetBackground`, `SetBlur`, `SetScale`, `SetToggleKey`, `SetMaximized`, `ToggleMaximized`, `Open`, `Close`, `Toggle`, `Destroy`, `SaveConfig`, `LoadConfig`, `DeleteConfig`, `GetConfigs`, `LoadAutoConfig`, `ConfigSection`.

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
tab:Input({ Title, Value, Placeholder, Numeric, Type = "Input" | "Textarea", Callback(text) })
tab:Keybind({ Title, Value = "K", Callback(), OnChange(key) })
tab:Colorpicker({ Title, Default, Transparency, Callback(color, transparency) })  -- opens a popup
tab:Label({ Title })
tab:Paragraph({ Title, Desc })
tab:Divider({ Title })                     -- Title optional
tab:Section({ Title, Opened })             -- returns a container; section:SetOpen(bool)
```

### Background images

Two options, both optional:

- **Wallpaper** (recommended): one image behind the whole window. The glass cards let it show through, so it reads as a single picture instead of cropped pieces. `Window:SetBackground("rbxassetid://...", 0.55, 0.45)` (image, transparency, dark scrim) or the `Background` window option.
- **Image card**: `Image = "..."` on any element puts a picture inside that one card. It fades in from the right so the title stays readable.

**Store images are Decals.** The id you copy from the Roblox Store / Toolbox is a *Decal* id, and an `ImageLabel` cannot display it. Mugiwara UI detects this and reads the real image out of the Decal for you (needs `game:GetObjects`, which most executors have). If it cannot, you get a notification saying so; then use the asset's **Image id** instead (in Studio: insert the decal, copy the `Texture` property). A notification also appears when Roblox refuses to load the image (private or moderated asset).

Images can be an asset id, `rbxassetid://...`, or an http(s) URL. URLs are downloaded once into `<Folder>/cache` and need `request`, `writefile` and `getcustomasset` on the executor; otherwise they are skipped silently.

### Themes

Built in: `Gear5` (default), `Sunrise`, `Joyboy`, `Gomu`. Switch from the dot in the top bar or with `MugiwaraUI:SetTheme(name)`; gradients cross-fade.

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
