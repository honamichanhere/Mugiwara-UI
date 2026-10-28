# Changelog

Versions follow `package.json`. Every release is a git tag (`v0.6.1`, ...); `dist/main.lua` at that tag is what users load.

## 0.7.0
- **Chat safeguards** (all optional and configurable in `server/worker/wrangler.toml`):
  - kill switch (on / read-only / off, one SQL command, no redeploy) and a matching state in the chat ("Read-only", "Disabled", locked input, unlocks by itself);
  - per-network rate limits (`IP_SENDS_PER_MIN`, `IP_NEW_USERS_PER_HOUR`) with hashed addresses;
  - retention (`RETENTION_HOURS` 72, `KEEP_MESSAGES` 1000) enforced on read and by an hourly cron job;
  - names verified against Roblox's API (cached a week, one retry; strict by default: Roblox sometimes answers Cloudflare with HTTP 429, then a *new* account is asked to try again in a moment, `VERIFY_ROBLOX = "lenient"` trusts the client instead), reserved names (`RESERVED_NAMES`, `OWNER_IDS`);
  - optional link / phone filter (`FILTER`, off by default);
  - `GET /v1/info`, privacy banner in the chat (`Notice` option / `NOTICE` variable).
- `server/worker/admin.sql` and `npm run chat:on|readonly|off`; transports pass an error `code` and gain `Info()`.
- Existing deployments: re-run `schema.sql` and `wrangler deploy` (see the Worker README). Old clients keep working.

## 0.6.2
- The floating open button now starts in the middle of the left edge (was top center). `OpenButton = { Position = UDim2... }` overrides it; `OpenButton = true` no longer errors.

## 0.6.1
- Chat notifications (`OnMessage`) arrive one by one: queued, `NotifySpacing` (0.8 s) apart, only the newest `NotifyLimit` (5) of a burst, never for muted users.

## 0.6.0
- **Live chat**: `tab:Chat` with replies, deleting own messages, history + "load older", mute, new-messages pill, cooldown, offline handling.
- Transports: `ChatTransports.Http` (Cloudflare Worker) and `ChatTransports.Memory` (offline demo with fake players).
- `server/worker`: Cloudflare Worker + D1 backend (poll by revision, per-device token bound to the Roblox user id, owner-only delete, cooldown, pruning). No moderation by design.

## 0.5.0
- Themes are now **Gear 5** (default, white), **Gear 4** (black and red), **Gear 3** (yellow and red) and **Normal** (orange, red, white, black, yellow). Sunrise, Joyboy and Gomu were removed.
- Key UI: wide 21:9 two-column card; the "Remember key" switch is gone (an accepted key is always saved, `SaveKey = false` opts out); the backdrop now covers the top bar strip (`IgnoreGuiInset`).
- New elements: `ProgressBar`, `Code` (Lua highlighting + copy), `Image`, `Group` (side-by-side row), `Space`.

## 0.4.0
- **Key UI** (`MugiwaraUI:KeySystem`) and **Loading UI** (`MugiwaraUI:Loading`, ported from the Mugiwara Hub loading screen) so Key > Loading > Main is one set.
- Shared `Shell` and `Neon` helpers; `Utility.Signal`; `CreateWindow({ Theme = ... })`.
- `examples/dummy-flow.lua`.

## 0.3.0
- Icon sets from Footagesus/Icons (lucide, craft, geist, gravity, solar), loaded per set from a pinned commit and cached; `Icon` option on tabs, the window logo and every element; `element:SetIcon`.

## 0.2.2
- Readability: bold titles, Medium body text (`Utility.Fonts`), larger text, lighter secondary colors.
- Roomier color picker, bigger top bar buttons, ring + dot theme button.

## 0.2.1
- Fixed the popup / dialog close fade (a stroke on a `CanvasGroup` is not covered by `GroupTransparency`).
- Roblox Store images are Decals: they are converted to Image ids automatically; clear messages when an image cannot load.

## 0.2.0
- Color picker popup (square, hue, opacity 0-100, HEX / RGB / HSV / HSL), maximize button, theme menu and version badge in the top bar, tab sections (`Window:TabSection`), sections limited to 2 levels, wallpaper (`Window:SetBackground`) and image cards (`Image` option).
- Animations scale from the center; smoother slider drag, theme cross-fade, page slide-in.

## 0.1.0
- First version: glass window with neon border, tabs, sections, Button / Toggle / Slider / Dropdown / Input / Keybind / Colorpicker / Label / Paragraph / Divider, notifications, dialogs, themes, config saving, executor compatibility layer, bundler, static check and smoke test.
