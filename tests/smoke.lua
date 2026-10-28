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
UI:SetTheme("Gear5")
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
