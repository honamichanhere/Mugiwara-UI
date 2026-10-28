# Mugiwara UI: project guide for Claude sessions

Read this first when you start a new session in this folder. User docs are in [README.md](README.md); history in
[CHANGELOG.md](CHANGELOG.md); the chat backend in [server/worker/README.md](server/worker/README.md).

## What this is

A UI library for **Roblox script hubs** (code that runs inside executors such as Delta, Xeno, Solara), written in
Luau and shipped as one file: `dist/main.lua`, loaded by users with `loadstring(game:HttpGet(url))()`.
Look: dark glass + rotating neon border, Luffy themes (Gear 5 white is the default). It is an own implementation
that imitates the API shape of WindUI (Footagesus, MIT); no WindUI code is copied.
Repo: `honamichanhere/Mugiwara-UI` (public, `main`). The owner works from `D:\Document\Roblox Script\Mugiwara UI`.

The user talks in casual Indonesian, tests every change **visually in a real executor** and reports back with
screenshots or notes. Claude cannot render Roblox GUI, so say clearly what was only tested by the mock.

## Commands

```bash
npm install
npm test            # build + static check (build/check.mjs) + Lua tests (fengari) + Worker tests (node:sqlite)
npm run build       # src/**/*.lua -> dist/main.lua (version comes from package.json)
npm run test:server # Worker only
```

`dist/main.lua` is **committed** (it is the product). Rebuild before committing. Releases are git tags `vX.Y.Z`;
users should load `https://raw.githubusercontent.com/honamichanhere/Mugiwara-UI/<tag>/dist/main.lua`.

## Layout

```
src/init.lua                 Library table (CreateWindow, KeySystem, Loading, Notify, themes, icons, ChatTransports)
src/core/                    Utility (Create, Tween, Maid, Signal, Draggable...), Compat (executor shims), Theme,
                             Icons + IconSets (Footagesus/Icons loader), Config
src/components/Window.lua    window chrome, topbar, tabs, config section, theme menu, maximize
src/components/Container.lua element methods shared by Tab / Section / Group; Section nesting limit = 2
src/components/Base.lua      the glass card every element is built on (Card, Extra, Expandable, Field, Gradient)
src/components/elements/     Button Toggle Slider Dropdown Input Keybind Colorpicker Text(Label/Paragraph/Divider)
                             ProgressBar Code Image Chat
src/components/              Popup, Dialog, Notification, Tab, TabSection, Shell + Neon (shared look),
                             KeySystem, Loading, ChatTransports
build/                       build.mjs (bundler), check.mjs (syntax + undefined globals)
tests/                       mock.lua (Roblox API mock), smoke.lua, flow.lua, chat.lua, dummy-flow.lua, smoke.mjs (runner)
examples/                    showcase, dummy (every feature), dummy-flow (Key > Loading > Main), dummy-chat
server/worker/               Cloudflare Worker + D1 chat backend (index.js, schema.sql, wrangler.toml, tests)
```

Modules are plain files that use `Import("core/Utility")`; the bundler wraps each in a function. Style: tabs,
English comments, no Luau-only syntax (`continue`, `+=`, type annotations): the static check parses as Lua 5.1.

## Hard-won rules (each one was a real bug)

- `UIScale` scales around the object's **AnchorPoint**. Animated frames must be anchored at (0.5, 0.5) or they grow
  from the top-left corner.
- **One `UIGradient` per instance**; extra ones are ignored. Color and Transparency share the same gradient.
- A `UIStroke` that is a direct child of a **CanvasGroup is not covered by `GroupTransparency`**: tween its
  `Transparency` yourself (Popup, Dialog, Shell).
- `AbsoluteContentSize` is unreliable under `UIScale`: drawers sum their fixed child heights instead.
- A `TextButton` child **swallows clicks** meant for its parent row. Use a `TextLabel` when the parent must be clicked.
- `Window` ScreenGuis use `IgnoreGuiInset = false` (input positions match `AbsolutePosition`). The Key / Loading
  shells use `true` so their backdrop covers the top bar strip.
- Container method names collide with element constructors: a section's collapse method is `ToggleOpen`, not `Toggle`.
- Roblox Store ids are **Decals**, `ImageLabel` shows nothing for them: `Compat.ResolveImage` converts them.
- `coroutine.running()` can return two values: wrap it in parentheses before passing it on.
- Always call user callbacks through `Utility.SafeCall`; chat message text is never RichText, names are escaped.

## Testing and its limits

`tests/mock.lua` fakes just enough Roblox (Instance, signals, tweens, services) to run the real bundle on Lua 5.3.
Its `task` is a coroutine scheduler: `task.spawn` runs until the first `task.wait`, and **`task.delay` / `task.wait`
resume on the next `task.flush()` regardless of the time given**. Tests drive it with `pump()` loops. This checks
logic, never rendering, layout, animation or real executor behavior; that part is always verified by the user.
New feature = new assertions in `tests/` (and an example in `examples/` if it has a UI).

Tooling quirk: shell heredocs that contain single quotes break the Bash tool. Write helper scripts to files in the
scratchpad and run them with `node`.

## External pieces

- **Icons**: loaded at runtime from `Footagesus/Icons` (MIT), pinned to one commit in `src/core/IconSets.lua`
  (`COMMIT`), cached in the executor workspace. `sfsymbols` is deliberately disabled (Apple license). Upstream
  licenses: Lucide ISC, Gravity MIT, Solar CC BY 4.0 (credited in the README), Geist and Craft **unverified**.
- **Chat backend**: a Cloudflare Worker + D1 deployed in the owner's own free Cloudflare account (the owner created
  the account and approved `wrangler login`). The real `database_id` lives only in the gitignored
  `server/worker/wrangler.local.toml`; deploy with `npx wrangler deploy -c wrangler.local.toml` from
  `server/worker`. After upgrading the Worker code run `schema.sql` again, then deploy (README in that folder).
Kill switch: `npm run chat:off|readonly|on` in `server/worker`. The public URL is **not** committed on purpose (anyone with it can use the free quota); ask the
  owner or run `npx wrangler deployments list -c wrangler.local.toml`.

## Decisions the owner made (do not redo them)

- Free services only. Chat has **no moderation** (no word lists, bans, reports); the owner explicitly chose this. After a
  risk discussion (minors, hosted content, privacy, abuse) the owner asked for the cheap safeguards: kill switch,
  per-network limits, retention, Roblox-verified names, reserved names, optional filter (off by default), privacy banner.
- Themes are exactly Gear 5 (default), Gear 4, Gear 3, Normal.
- An accepted key is always saved (`SaveKey = false` opts out); there is no "remember" switch.
- Sections nest at most 2 levels. WindUI parity is not a goal beyond common hubs.

## Status

Done and tested by the owner in an executor: window, all elements except chat, themes, Key / Loading UI, icons.
The live chat was tested by the owner with a friend (v0.6.x). Not verified yet: the chat safeguards (v0.7.0) on real
accounts, behavior on every executor (Delta, Xeno, Solara) and on real phones. Missing compared to WindUI: Video, Viewport.

## Releasing

1. `npm test` must pass; commit `dist/main.lua` with the source.
2. Bump `version` in `package.json`, add a CHANGELOG entry.
3. `git tag vX.Y.Z && git push --tags`; tell the user the pinned URL.
