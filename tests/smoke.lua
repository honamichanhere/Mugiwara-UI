-- Smoke test: builds a full UI against the mock and pokes every element.
-- Fails (non-zero exit) on any runtime error or any warn() emitted by the library.

local UIS = MOCK.services.UserInputService

local function check(condition, message)
	if not condition then
		error("ASSERT: " .. message, 2)
	end
end

local UI = assert(load(DIST_SOURCE, "=dist"))()
check(type(UI.CreateWindow) == "function", "CreateWindow missing")
check(UI.Version ~= "@VERSION@", "version placeholder was not replaced")

local Window = UI:CreateWindow({
	Title = "Test", Subtitle = "sub", Folder = "SmokeTest", Version = "v9.9",
	Background = { Image = "rbxassetid://123", Transparency = 0.6 },
})
check(Window.VersionPill.Visible and Window.VersionLabel.Text == "v9.9", "version badge")
check(Window.BackgroundImage.Visible and Window.BackgroundImage.Image == "rbxassetid://123", "wallpaper from asset id")
check(Window.Opened, "window should open on creation")

--// tabs + elements
local Main = Window:Tab({ Title = "Main" })
local Other = Window:Tab({ Title = "Other", Icon = "rbxassetid://123" })
Window:SidebarLabel("Group")
Window:SidebarDivider()
check(Window.CurrentTab == Main, "first tab should be selected")
Window:SelectTab(Other)
check(Window.CurrentTab == Other, "SelectTab failed")
Window:SelectTab(1)

local clicked = 0
local button = Main:Button({ Title = "Btn", Desc = "d", Callback = function() clicked = clicked + 1 end })
button.Top.MouseButton1Click:Fire()
check(clicked == 1, "button callback")

local toggled
local toggle = Main:Toggle({ Title = "Tg", Flag = "tg", Callback = function(v) toggled = v end })
toggle.Top.MouseButton1Click:Fire()
check(toggle.Value == true and toggled == true, "toggle click")
toggle:Set(false, true)
check(toggle:Get() == false, "toggle silent set")

local sliderValue
local slider = Main:Slider({
	Title = "Sl", Flag = "sl", Value = { Min = 0, Max = 10, Default = 2 }, Step = 0.5,
	Callback = function(v) sliderValue = v end,
})
check(slider.Value == 2, "slider default")
slider:Set(7.3)
check(slider.Value == 7.5 and sliderValue == 7.5, "slider snap to step, got " .. tostring(slider.Value))
slider:Set(99)
check(slider.Value == 10, "slider clamp")

local picked
local dropdown = Main:Dropdown({
	Title = "Dd", Flag = "dd", Values = { "a", "b", "c" }, Value = "a",
	Callback = function(v) picked = v end,
})
check(dropdown:Get() == "a", "dropdown default")
dropdown.Top.MouseButton1Click:Fire() -- open
dropdown:Set("c")
check(dropdown:Get() == "c" and picked == "c", "dropdown set")
dropdown:Refresh({ "x", "y" }, false)
check(dropdown:Get() == nil, "dropdown refresh clears selection")

local multi = Main:Dropdown({ Title = "Multi", Flag = "multi", Values = { "a", "b", "c" }, Multi = true, Value = { "a", "c" } })
local got = multi:Get()
check(#got == 2 and got[1] == "a" and got[2] == "c", "multi default")
multi:Set({ "b" })
check(#multi:Get() == 1 and multi:Get()[1] == "b", "multi set")

local searchable = Main:Dropdown({ Title = "Big", Values = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" } })
check(searchable ~= nil, "searchable dropdown")

local typed
local input = Main:Input({ Title = "In", Flag = "in", Callback = function(v) typed = v end })
input:Set("hello")
check(input:Get() == "hello" and typed == "hello", "input set")
Main:Input({ Title = "Area", Type = "Textarea", Flag = "area" })
Main:Input({ Title = "Num", Numeric = true })

local pressed = 0
local keybind = Main:Keybind({ Title = "Kb", Flag = "kb", Value = "K", Callback = function() pressed = pressed + 1 end })
UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = { Name = "K" } }, false)
check(pressed == 1, "keybind press")
keybind.Top.MouseButton1Click:Fire() -- listen
UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.G }, false)
check(keybind:Get() == "G", "keybind rebind, got " .. tostring(keybind:Get()))
check(pressed == 1, "rebind must not fire callback")

local color
local picker = Main:Colorpicker({ Title = "Cp", Flag = "cp", Default = Color3.fromRGB(255, 0, 0), Transparency = 0, Callback = function(c) color = c end })
picker:Set(Color3.fromRGB(0, 255, 0))
check(color ~= nil and color.G > 0.99, "colorpicker set")
picker:Set("#0000FF")
check(picker:Get().B > 0.99, "colorpicker hex string")

--// color picker popup
picker:Set(Color3.fromRGB(255, 0, 0))
picker.Top.MouseButton1Click:Fire()
local ui = picker._ui
check(ui ~= nil and Window.ActivePopup ~= nil, "color picker popup opens")
ui.Boxes[1].Text = "#112233"
ui.Boxes[1].FocusLost:Fire(true)
check(math.abs(picker:Get().B - 0x33 / 255) < 0.01, "hex field applies")
ui.SetMode("RGB")
ui.Boxes[1].Text = "255"
ui.Boxes[1].FocusLost:Fire(true)
check(picker:Get().R > 0.99, "rgb field applies")
ui.SetMode("HSV")
ui.Boxes[2].Text = "0"
ui.Boxes[2].FocusLost:Fire(true)
check(picker:Get().R == picker:Get().G, "hsv saturation 0 gives gray")
ui.SetMode("HSL")
ui.Boxes[3].Text = "50"
ui.Boxes[3].FocusLost:Fire(true)
check(picker:Get().R > 0.49 and picker:Get().R < 0.51, "hsl lightness applies")
ui.Alpha.Text = "50%"
ui.Alpha.FocusLost:Fire(true)
check(math.abs(picker:GetTransparency() - 0.5) < 0.001, "opacity field is 0-100")
ui.Boxes[1].Text = "garbage"
ui.Boxes[1].FocusLost:Fire(true) -- must not error
picker:Close()
check(picker._ui == nil and Window.ActivePopup == nil, "color picker popup closes")

Main:Label({ Title = "label" })
Main:Label("string label")
Main:Paragraph({ Title = "p", Desc = "d" })
Main:Divider()
Main:Divider({ Title = "caption" })

Main:Button({ Title = "Image card", Image = "rbxassetid://1" })
local section = Main:Section({ Title = "Sec", Opened = true })
local inner2 = section:Section({ Title = "Double", Opened = true })
inner2:Toggle({ Title = "deep", Flag = "deep" })
local tooDeep, message = pcall(function() return inner2:Section({ Title = "Triple" }) end)
check(not tooDeep and string.find(message, "2 levels"), "third section level must be rejected")
local inner = section:Toggle({ Title = "inside", Flag = "inside" })
check(inner.Type == "Toggle", "section:Toggle must create a toggle element")
section:SetOpen(false)
section:ToggleOpen()
check(section.Open == true, "section reopen")

--// ProgressBar, Code, Image, Group, Space
local bar = Main:ProgressBar({ Title = "Load", Value = 25 })
check(bar.Value == 25, "progress bar default value")
bar:Set(80)
check(bar.Value == 80, "progress bar set")
bar:Set(500)
check(bar.Value == 100, "progress bar clamps high")
bar:Set(-5)
check(bar.Value == 0, "progress bar clamps low")
bar:SetText("custom")
bar:Set(10, true)

local snippet = [=[local x = 5 -- note
print("a<b")]=]
local codeEl = Main:Code({ Title = "Snippet", Code = snippet })
check(string.find(codeEl.TextLabel.Text, "<font", 1, true), "lua code is highlighted")
check(string.find(codeEl.TextLabel.Text, "&lt;", 1, true), "rich text characters are escaped")
codeEl.CopyButton.MouseButton1Click:Fire()
check(MOCK.clipboard == snippet, "the copy button copies the raw code")
codeEl:Set("return 1")
check(codeEl:Get() == "return 1" and string.find(codeEl.TextLabel.Text, "return", 1, true), "Code:Set updates the text")
Main:Code({ Code = [=[--[[ long
comment ]] local n = 0xFF + 3.5 local s = [[raw]] local t = 'it's' local u = "x\"y"]=], Copy = false })
local plain = Main:Code({ Code = "a <b> c", Language = "text", Copy = false })
check(not plain.Top.Visible, "no title and no copy button hides the header row")
check(not string.find(plain.TextLabel.Text, "<font", 1, true) and string.find(plain.TextLabel.Text, "&lt;b&gt;", 1, true), "other languages stay plain but escaped")

local pic = Main:Image({ Image = "rbxassetid://1", Height = 100 })
check(not pic.Top.Visible and pic.ImageLabel.Image == "rbxassetid://1", "an image card without text has no header")
pic:SetImage("rbxassetid://2")
check(pic.ImageLabel.Image == "rbxassetid://2", "SetImage swaps the picture")
check(Main:Image({ Title = "Captioned" }).Top.Visible, "a titled image card keeps its header")

local row = Main:Group({ Gap = 6 })
local g1 = row:Button({ Title = "A" })
local g2 = row:Toggle({ Title = "B" })
local g3 = row:Button({ Title = "C" })
check(math.abs(g1.Frame.Size.X.Scale - 1 / 3) < 1e-9 and g1.Frame.Size.X.Offset == -4, "group children share the width equally")
check(row.Depth == Main.Depth, "a group does not count as a section level")
g3:Destroy()
check(math.abs(g1.Frame.Size.X.Scale - 0.5) < 1e-9 and g2.Frame.Size.X.Offset == -3, "the group rebalances when a child is removed")
check(Main:Space(20).Frame.Size.Y.Offset == 20 and Main:Space().Frame.Size.Y.Offset == 12, "Space height")

--// icon sets (Footagesus/Icons)
local houseTab = Window:Tab({ Title = "House", Icon = "house" })
check(houseTab.IconLabel and houseTab.IconLabel.Image == "rbxassetid://111", "flat set icon (default lucide)")
check(Window:Tab({ Title = "Prefixed", Icon = "lucide:settings" }).IconLabel.Image == "rbxassetid://222", "prefixed icon name")

local sheetTab = Window:Tab({ Title = "Sheet", Icon = "craft:folder-stroke" })
local sheet = sheetTab.IconLabel
check(sheet.Image == "rbxassetid://5" and sheet.ImageRectSize.X == 96 and sheet.ImageRectOffset.X == 96, "spritesheet icon uses the rect")

local layered = Window:Tab({ Title = "Layered", Icon = "geist:bell" }).IconLabel
check(layered.Image == "rbxassetid://7" and #layered:GetChildren() == 1, "icon Parts become child layers")
check(layered:GetChildren()[1].ImageRectOffset.X == 128, "part layer uses its own rect")

check(Window:Tab({ Title = "Missing", Icon = "lucide:does-not-exist" }).IconLabel == nil, "unknown icon falls back to the letter badge")
check(Window:Tab({ Title = "Apple", Icon = "sfsymbols:house" }).IconLabel == nil, "sfsymbols is not enabled")
check(Window:Tab({ Title = "Asset", Icon = "rbxassetid://424242" }).IconLabel.Image == "rbxassetid://424242", "plain asset ids still work")

local fetched = {}
for _, url in ipairs(HTTP_LOG) do
	check(string.find(url, "46d30c19ba7bc601d6ec794a48dc3a89568b1eec", 1, true), "icon downloads must be pinned to a commit: " .. url)
	check(not string.find(url, "sfsymbols", 1, true), "sfsymbols must never be downloaded")
	fetched[url] = (fetched[url] or 0) + 1
end
for url, count in pairs(fetched) do
	check(count == 1, "each set is downloaded once (cached afterwards): " .. url)
end

local iconic = Main:Button({ Title = "With icon", Icon = "lucide:house" })
check(iconic:SetIcon("lucide:settings") == true, "SetIcon swaps the icon")
check(iconic:SetIcon("lucide:nope") == false, "SetIcon reports a missing icon")
check(iconic:SetIcon(nil) == true, "SetIcon(nil) removes the icon")
check(UI:SetIconSet("craft") and UI.IconSets.Default == "craft", "default set can change")
check(not UI:SetIconSet("sfsymbols"), "sfsymbols cannot be selected")
UI:SetIconSet("lucide")

--// tab sections
local group = Window:TabSection({ Title = "Group" })
local groupTab = group:Tab({ Title = "InGroup" })
groupTab:Toggle({ Title = "in group" })
group:SetOpen(false)
group:ToggleOpen()
check(group.Open and #group.Tabs == 1, "tab section")
Window:SelectTab(groupTab)
check(Window.CurrentTab == groupTab, "select tab inside a tab section")
Window:SelectTab(Main)

--// maximize + theme menu + background
Window:SetMaximized(true)
check(Window.Maximized and not Window._squareGlyph.Visible, "maximize")
Window:SetMaximized(false)
check(not Window.Maximized and Window._squareGlyph.Visible, "restore")
task.flush()
local menu = Window:OpenThemeMenu()
check(Window.ActivePopup == menu, "theme menu opens")
menu:Close()
Window:SetBackground(nil)
check(not Window.BackgroundImage.Visible, "wallpaper removed")
MOCK_ASSET_TYPES[555] = 13 -- Decal (what the Roblox Store hands out)
Window:SetBackground("555")
check(Window.BackgroundImage.Image == "http://www.roblox.com/asset/?id=999", "decal id is converted to its image")
MOCK_ASSET_TYPES[556] = 1 -- real Image asset
Window:SetBackground("rbxassetid://556")
check(Window.BackgroundImage.Image == "rbxassetid://556", "image id is used as is")
MOCK_ASSET_TYPES[557] = 10 -- Model: not an image
Window:SetBackground("557")
check(Window.BackgroundImage.Image == "rbxassetid://556", "non-image asset is rejected and leaves the wallpaper alone")
Window:SetBackground("https://example.com/x.png") -- no request/getcustomasset in the mock: must not error
Window:SetVersion("")
check(not Window.VersionPill.Visible, "version hidden")

--// locking / visibility / destroy
button:Lock(true)
check(button.Locked, "lock")
button:Unlock()
button:SetVisible(false)
button:SetTitle("Renamed")
button:SetDesc("x")
local doomed = Main:Button({ Title = "Doomed" })
doomed:Destroy()

--// notifications + dialogs
UI:Notify({ Title = "Hi", Content = "there", Type = "success", Duration = 3 })
UI:Notify({ Title = "Err", Type = "error" })
UI:Notify({ Title = "Sticky", Duration = 0 })
Window:Dialog({ Title = "Sure?", Content = "x", Buttons = { { Title = "No" }, { Title = "Yes", Style = "Primary" }, { Title = "Del", Style = "Danger" } } })
task.flush()

--// themes
for _, name in ipairs(UI:GetThemes()) do
	check(UI:SetTheme(name), "theme " .. name)
end
check(UI:SetTheme("DoesNotExist") == false, "unknown theme")
UI:AddTheme("Custom", { Accent = Color3.fromRGB(1, 2, 3), Gradient = { Color3.fromRGB(1, 1, 1), Color3.fromRGB(2, 2, 2) } })
check(UI:SetTheme("Custom"), "custom theme")
UI:SetTheme("Gear 5")
MOCK.services.RunService.Heartbeat:Fire() -- gradient cross-fade runs without error

--// config round trip
check(Window:SaveConfig("one"), "save config")
toggle:Set(true, true)
slider:Set(1, true)
input:Set("changed", true)
check(Window:LoadConfig("one"), "load config")
check(toggle:Get() == false, "config restored toggle")
check(slider:Get() == 10, "config restored slider, got " .. tostring(slider:Get()))
check(input:Get() == "hello", "config restored input")
check(#Window:GetConfigs() == 1 and Window:GetConfigs()[1] == "one", "config list")
Window:ConfigSection(Main)
check(not Window:LoadAutoConfig(), "no autoload yet")
Window:DeleteConfig("one")
check(#Window:GetConfigs() == 0, "config delete")

--// window lifecycle
Window:Close()
check(not Window.Opened, "close")
task.flush()
Window:Toggle()
check(Window.Opened, "toggle reopen")
Window:SetTitle("Renamed window")
Window:SetBlur(true)
Window:SetBlur(false)
Window:SetScale(0.8)
Window:Destroy()
check(Window.Destroyed, "destroy")

--// second window + re-execution replaces the first library
local Second = UI:CreateWindow({ Title = "Second", Neon = false, OpenButton = false, ShowUser = false, Resizable = false })
Second:Tab({ Title = "T" }):Toggle({ Title = "x" })
local UI2 = assert(load(DIST_SOURCE, "=dist"))()
check(Second.Destroyed, "re-executing the script must destroy the previous instance")
UI2:Destroy()

check(#WARNINGS == 0, "library emitted warnings: " .. table.concat(WARNINGS, " | "))
print("smoke test passed")
