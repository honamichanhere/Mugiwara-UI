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

--// built-in glyphs are icons once the set is there (and stay drawn when it is not)
local closeImage = Window.Frame:FindFirstChild("Close", true):FindFirstChild("Image")
check(closeImage and closeImage.Image == "rbxassetid://903", "the close glyph is the lucide x icon")
check(#Window.Frame:FindFirstChild("Close", true):GetChildren() == 1, "the drawn bars are replaced, not stacked")
check(Window._squareGlyph:FindFirstChild("Image").Image == "rbxassetid://905", "maximize glyph is an icon")
check(Window._restoreGlyph:FindFirstChild("Image").Image == "rbxassetid://906", "restore glyph is an icon")
check(closeImage.ImageColor3 == UI.Theme.Tokens.SubText, "a glyph keeps the theme color it was bound to")
UI:SetGlyphs({ Check = false })
local drawnCheck = Main:Dropdown({ Title = "Drawn", Values = { "a" }, Value = "a" })
check(drawnCheck.Rows()[1].Check:FindFirstChild("Image") == nil, "SetGlyphs(false) keeps the drawn glyph")
UI:SetGlyphs({ Check = "lucide:check" })

--// icon colors
local function iconOf(element)
	local slot = element.Top:FindFirstChild("IconHolder")
	return slot and slot:FindFirstChild("Icon")
end
local plainIcon = Main:Toggle({ Title = "Plain", Icon = "lucide:house" })
check(iconOf(plainIcon).ImageColor3 == UI.Theme.Tokens.Accent, "icons follow the theme accent by default")
local red = Color3.fromRGB(255, 0, 0)
local tinted = Main:Slider({ Title = "Tinted", Icon = "lucide:house", IconColor = red, Value = { Min = 0, Max = 1, Default = 0 } })
check(iconOf(tinted).ImageColor3 == red, "IconColor sets a fixed color")
UI:SetTheme("Gear 4")
check(iconOf(tinted).ImageColor3 == red, "a custom icon color ignores theme changes")
check(iconOf(plainIcon).ImageColor3 == UI.Theme.Tokens.Accent, "the default color still follows the theme")
tinted:SetIconColor("Success")
check(iconOf(tinted).ImageColor3 == UI.Theme.Tokens.Success, "a token name follows the theme")
UI:SetTheme("Gear 3")
check(iconOf(tinted).ImageColor3 == UI.Theme.Tokens.Success, "token colors are rebound on theme change")
tinted:SetIconColor(nil)
check(iconOf(tinted).ImageColor3 == UI.Theme.Tokens.Accent, "SetIconColor(nil) goes back to the accent")
tinted:SetIconColor(red)
tinted:SetIcon("lucide:settings")
check(iconOf(tinted).Image == "rbxassetid://222" and iconOf(tinted).ImageColor3 == red, "SetIcon keeps the custom color")
UI:SetTheme("Gear 5")

local coloredTab = Window:Tab({ Title = "Colored", Icon = "lucide:house", IconColor = red })
check(coloredTab.IconLabel.ImageColor3 == red, "tab IconColor")
Window:SelectTab(coloredTab)
check(coloredTab.IconLabel.ImageColor3 == red, "tab keeps IconColor when selected")
local green = Color3.fromRGB(0, 255, 0)
coloredTab:SetIconColor(red, green)
check(coloredTab.IconLabel.ImageColor3 == green, "tab IconColorActive applies while selected")
Window:SelectTab(Main)
check(coloredTab.IconLabel.ImageColor3 == red, "tab goes back to the idle icon color")
coloredTab:SetIconColor(nil)
check(coloredTab.IconLabel.ImageColor3 == UI.Theme.Tokens.SubText, "tab icon color resets to the theme")
local letterTab = Window:Tab({ Title = "Letter", IconColor = red })
Window:SelectTab(Main)

--// dropdown items with icons and descriptions
local pickedItem
local rich = Main:Dropdown({
	Title = "Weapon",
	Values = {
		"Plain",
		{ Title = "Sword", Icon = "lucide:sword", IconColor = red },
		{ Title = "Gun", Desc = "Fast and loud" },
		{ Title = "Staff", Desc = "Slow", Icon = "lucide:house" },
	},
	Value = "Sword",
	Callback = function(value) pickedItem = value end,
})
local richRows = rich.Rows()
check(#richRows == 4, "every item gets a row")
check(richRows[1].Frame.Size.Y.Offset < richRows[3].Frame.Size.Y.Offset, "rows with a description are taller")
check(richRows[1].Frame:FindFirstChildOfClass("UIStroke") ~= nil, "rows have a border")
check(richRows[1].Frame:FindFirstChild("Icon", true) == nil and richRows[2].Frame:FindFirstChild("Icon", true) ~= nil, "icons only where requested")
check(richRows[2].Frame:FindFirstChild("Icon", true).ImageColor3 == red, "item IconColor")
local hasDesc = false
for _, descendant in ipairs(richRows[3].Frame:GetDescendants()) do
	hasDesc = hasDesc or (descendant:IsA("TextLabel") and descendant.Text == "Fast and loud")
end
check(hasDesc and richRows[3].Frame:FindFirstChild("Icon", true) == nil, "description-only row")
check(richRows[2].Stroke.Color == UI.Theme.Tokens.Accent, "the selected row's border uses the accent")
check(richRows[1].Stroke.Color == UI.Theme.Tokens.Stroke, "other rows use the stroke color")
check(rich:Get() == "Sword", "Get returns the item's Title")
check(rich.Frame:FindFirstChild("Icon", true) ~= nil, "the chosen item's icon shows in the closed button")
richRows[3].Frame.MouseButton1Click:Fire()
check(pickedItem == "Gun" and rich:Get() == "Gun", "choosing a described item returns its Title")
rich:Set("Plain", true)
check(rich:Get() == "Plain", "Set takes a Title")
rich:Refresh({ { Title = "New", Desc = "fresh" }, "Old" }, false)
check(#rich.Rows() == 2 and rich.Rows()[1].Frame.Size.Y.Offset == richRows[3].Frame.Size.Y.Offset, "Refresh accepts item tables")
local describedSearch = Main:Dropdown({
	Title = "Searchable",
	Searchable = true,
	Values = { { Title = "Alpha", Desc = "first letter" }, { Title = "Beta", Desc = "second" } },
})
local box
for _, descendant in ipairs(describedSearch.Frame:GetDescendants()) do
	if descendant:IsA("TextBox") then
		box = descendant
	end
end
box.Text = "second"
check(#describedSearch.Rows() == 1 and describedSearch.Rows()[1].Name == "Beta", "search also looks at descriptions")
UI:SetTheme("Gear 4")
check(rich.Rows()[1].Stroke.Color == UI.Theme.Tokens.Stroke, "row borders follow the theme")
UI:SetTheme("Gear 5")

--// grid dropdown (pictures in a grid)
MOCK_ASSET_TYPES[600] = 13 -- a Decal: converted to its image like the wallpaper
local gridPicked
local gridDrop = Main:GridDropdown({
	Title = "Skin",
	Columns = 4,
	CellHeight = 90,
	Values = {
		"Plain",
		{ Title = "Photo", Image = "rbxassetid://5" },
		{ Title = "Store", Image = "600" },
		{ Title = "Blade", Icon = "lucide:sword", IconColor = red },
		{ Title = "Wide", Image = "rbxassetid://6" },
	},
	Value = "Photo",
	Callback = function(value) gridPicked = value end,
})
local gridCells = gridDrop.Cells()
check(#gridCells == 5, "every item gets a cell")
local cellSize = gridDrop.GridLayout.CellSize
check(math.abs(cellSize.X.Scale - 0.25) < 1e-9 and cellSize.X.Offset == -6 and cellSize.Y.Offset == 90, "cell size comes from Columns and CellHeight")
check(gridDrop.GridFrame.Size.Y.Offset == 2 * 90 + 8 + 6, "the grid is as tall as its rows")
check(gridCells[2].Frame:FindFirstChild("Picture", true).Image == "rbxassetid://5", "Image shows in the cell")
check(gridCells[3].Frame:FindFirstChild("Picture", true).Image == "http://www.roblox.com/asset/?id=999", "Store (Decal) ids are converted")
check(gridCells[4].Frame:FindFirstChild("Icon", true).Image == "rbxassetid://333" and gridCells[4].Frame:FindFirstChild("Icon", true).ImageColor3 == red, "Icon items draw a tinted icon")
check(gridCells[1].Frame:FindFirstChild("Picture", true) == nil, "a plain string cell has no picture")
check(gridCells[2].Badge.Visible and not gridCells[1].Badge.Visible, "the selected cell shows its badge")
check(gridCells[2].Stroke.Color == UI.Theme.Tokens.Accent, "the selected cell's border uses the accent")
check(gridDrop.Right:FindFirstChild("Picture", true) ~= nil, "the chosen picture shows in the closed button")
gridCells[1].Frame.MouseButton1Click:Fire()
check(gridPicked == "Plain" and gridDrop:Get() == "Plain", "clicking a cell chooses it")
check(gridDrop.Right:FindFirstChild("Picture", true) == nil, "no picture in the closed button for a plain item")
gridDrop:Set("Blade", true)
check(gridDrop:Get() == "Blade" and gridPicked == "Plain", "silent Set does not call back")

gridDrop:SetGrid({ Columns = 2 })
cellSize = gridDrop.GridLayout.CellSize
check(math.abs(cellSize.X.Scale - 0.5) < 1e-9 and cellSize.X.Offset == -4 and cellSize.Y.Offset == 90, "SetGrid changes the columns")
check(gridDrop.GridFrame.Size.Y.Offset == math.min(3 * 90 + 2 * 8 + 6, 260), "and the height follows")
gridDrop:SetGrid({ CellHeight = 120, MaxHeight = 200 })
check(gridDrop.GridFrame.Size.Y.Offset == 200, "MaxHeight caps the grid (it scrolls)")

local gridBox
for _, descendant in ipairs(gridDrop.Frame:GetDescendants()) do
	if descendant:IsA("TextBox") then
		gridBox = descendant
	end
end
check(gridBox ~= nil, "the grid dropdown is searchable by default")
gridBox.Text = "bla"
check(#gridDrop.Cells() == 1 and gridDrop.Cells()[1].Name == "Blade", "search filters the grid")
gridBox.Text = ""
check(#gridDrop.Cells() == 5, "clearing the search brings everything back")

local multiGrid = Main:GridDropdown({
	Title = "Multi", Multi = true, Searchable = false, Titles = false,
	Values = { { Title = "Alpha", Image = "rbxassetid://5" }, { Title = "Beta", Image = "rbxassetid://6" } },
	Value = { "Alpha" },
})
multiGrid.Cells()[2].Frame.MouseButton1Click:Fire()
check(#multiGrid:Get() == 2, "multi select toggles cells")
local hasTitle = false
for _, descendant in ipairs(multiGrid.GridFrame:GetDescendants()) do
	hasTitle = hasTitle or (descendant:IsA("TextLabel") and descendant.Text == "Alpha")
end
check(not hasTitle, "Titles = false shows pictures only")
check(multiGrid.GridFrame.Parent ~= nil and not (function()
	for _, descendant in ipairs(multiGrid.Frame:GetDescendants()) do
		if descendant:IsA("TextBox") then return true end
	end
end)(), "Searchable = false has no search box")
gridDrop:Refresh({ "One", { Title = "Two", Image = "rbxassetid://7" } }, false)
check(#gridDrop.Cells() == 2 and gridDrop:Get() == nil, "Refresh swaps the items")
UI:SetTheme("Gear 4")
check(gridDrop.Cells()[1].Stroke.Color == UI.Theme.Tokens.Stroke, "cell borders follow the theme")
UI:SetTheme("Gear 5")

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

--// theme wallpapers (each theme ships its own; 0.3 transparency)
local themeImages = { ["Gear 5"] = 132136264088686, ["Gear 4"] = 97664760089542, ["Gear 3"] = 72569835503667, ["Normal"] = 95252648321318 }
for _, id in pairs(themeImages) do
	MOCK_ASSET_TYPES[id] = 1
end
local themed = UI:CreateWindow({ Title = "Themed", Folder = "ThemedTest", ThemeSwitcher = true })
check(themed.BackgroundImage.Visible and themed.BackgroundImage.Image == "rbxassetid://132136264088686", "a window without Background shows the theme's wallpaper")
check(themed.BackgroundImage.ImageTransparency == 0.3, "default wallpaper transparency is 0.3")
UI:SetTheme("Gear 4")
check(themed.BackgroundImage.Image == "rbxassetid://97664760089542", "the wallpaper follows the theme (Gear 4)")
UI:SetTheme("Gear 3")
check(themed.BackgroundImage.Image == "rbxassetid://72569835503667", "the wallpaper follows the theme (Gear 3)")
UI:SetTheme("Normal")
check(themed.BackgroundImage.Image == "rbxassetid://95252648321318", "the wallpaper follows the theme (Normal)")
themed:SetBackground("rbxassetid://556", 0.5)
UI:SetTheme("Gear 5")
check(themed.BackgroundImage.Image == "rbxassetid://556" and themed.BackgroundImage.ImageTransparency == 0.5, "a custom wallpaper wins over the theme's")
themed:SetBackground(nil)
UI:SetTheme("Gear 4")
check(not themed.BackgroundImage.Visible, "removing the wallpaper keeps it removed across theme changes")
themed:UseThemeBackground()
check(themed.BackgroundImage.Image == "rbxassetid://97664760089542", "UseThemeBackground brings the theme's wallpaper back")
UI:AddTheme("Plain Custom", { Accent = Color3.fromRGB(10, 200, 10) })
UI:SetTheme("Plain Custom")
check(not themed.BackgroundImage.Visible, "a theme without a wallpaper shows none")
UI:AddTheme("With Paper", { Wallpaper = "rbxassetid://777", WallpaperAlpha = 0.6 })
UI:SetTheme("With Paper")
check(themed.BackgroundImage.Image == "rbxassetid://777" and themed.BackgroundImage.ImageTransparency == 0.6, "custom themes can carry a wallpaper")
UI:SetTheme("Gear 5")
local bare = UI:CreateWindow({ Title = "Bare", Folder = "BareTest", Background = false })
check(not bare.BackgroundImage.Visible, "Background = false disables the theme wallpaper")
MOCK_ASSET_TYPES[424242] = 10 -- not an image: the theme wallpaper fails quietly
UI:AddTheme("Broken Paper", { Wallpaper = "424242" })
UI:SetTheme("Broken Paper")
local quietWindow = UI:CreateWindow({ Title = "Quiet", Folder = "QuietTest" })
check(not quietWindow.BackgroundImage.Visible, "an unusable theme wallpaper is skipped without a warning")
UI:SetTheme("Gear 5")
themed:Destroy()
bare:Destroy()
quietWindow:Destroy()

--// theme menu
local themeMenu = Window:OpenThemeMenu()
local themeRows = {}
for _, child in ipairs(themeMenu.Card:GetChildren()) do
	if child:IsA("TextButton") then
		table.insert(themeRows, child)
	end
end
check(#themeRows >= 4 and themeRows[1].Size.Y.Offset >= 48, "theme menu rows")
check(themeRows[1]:FindFirstChild("Swatch") ~= nil, "theme menu shows a preview swatch")
themeMenu:Close()
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

--// open button: middle of the left edge by default, configurable
local Placed = UI:CreateWindow({ Title = "Placed" })
local defaultPos = Placed.OpenButton.Position
check(defaultPos.X.Scale == 0 and defaultPos.X.Offset == 36 and defaultPos.Y.Scale == 0.5 and defaultPos.Y.Offset == 0, "the open button starts in the middle of the left edge")
Placed:Destroy()
local Custom = UI:CreateWindow({ Title = "Custom", OpenButton = { Title = "X", Position = UDim2.new(1, -40, 0.25, 0) } })
check(Custom.OpenButton.Position.X.Scale == 1 and Custom.OpenButton.Position.Y.Scale == 0.25, "OpenButton.Position overrides the start position")
Custom:Destroy()
local Plain = UI:CreateWindow({ Title = "Plain", OpenButton = true }) -- a bare true used to error
check(Plain.OpenButton ~= nil, "OpenButton = true works")
Plain:Destroy()

--// second window + re-execution replaces the first library
local Second = UI:CreateWindow({ Title = "Second", Neon = false, OpenButton = false, ShowUser = false, Resizable = false })
Second:Tab({ Title = "T" }):Toggle({ Title = "x" })
local UI2 = assert(load(DIST_SOURCE, "=dist"))()
check(Second.Destroyed, "re-executing the script must destroy the previous instance")
UI2:Destroy()

check(#WARNINGS == 0, "library emitted warnings: " .. table.concat(WARNINGS, " | "))
print("smoke test passed")
