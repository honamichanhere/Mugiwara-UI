-- Mugiwara UI dummy hub: every feature wired to harmless fake actions.
-- Nothing here touches the game; callbacks only print / notify / update labels.
--
-- Test options:
--   A) paste this whole file into your executor (loads the library from GitHub)
--   B) offline: save dist/main.lua into your executor's workspace folder as "MugiwaraUI.lua"
--      -> this script loads that file first, so you can test local changes without pushing

local URL = "https://raw.githubusercontent.com/honamichanhere/Mugiwara-UI/main/dist/main.lua"

local function loadLibrary()
	if isfile and readfile and isfile("MugiwaraUI.lua") then
		return loadstring(readfile("MugiwaraUI.lua"))()
	end
	return loadstring(game:HttpGet(URL))()
end

local MugiwaraUI = loadLibrary()

-- Paste an image here (asset id, "rbxassetid://..." or an http(s) URL) to test the wallpaper
-- and the image cards. Leave empty to skip. URLs need request + writefile + getcustomasset.
local DEMO_IMAGE = ""

local Window = MugiwaraUI:CreateWindow({
	Title = "Mugiwara Dummy",
	Subtitle = "test hub - UI v" .. MugiwaraUI.Version,
	Version = "v1.0.0", -- badge next to the title
	Icon = "lucide:sun", -- icon sets: "set:name" (lucide, craft, geist, gravity, solar), or an asset id
	Folder = "MugiwaraDummy",
	Size = UDim2.fromOffset(660, 440),
	ToggleKey = Enum.KeyCode.RightShift,
	Background = DEMO_IMAGE ~= "" and { Image = DEMO_IMAGE, Transparency = 0.55 } or nil,
})

local function say(title, content, kind)
	MugiwaraUI:Notify({ Title = title, Content = content, Type = kind or "info", Duration = 3 })
end

--// 1. Dashboard ---------------------------------------------------------------
-- Tab sections: titled, collapsible groups of tabs in the sidebar
local Overview = Window:TabSection({ Title = "Overview" })
local Dashboard = Overview:Tab({ Title = "Dashboard", Icon = "lucide:layout-dashboard" })

local status = Dashboard:Paragraph({ Title = "Session", Desc = "Starting..." })
local startedAt = os.clock()
local lastAction = "none"

local function refreshStatus()
	status:SetDesc(string.format("Uptime: %ds\nLast action: %s", math.floor(os.clock() - startedAt), lastAction))
end

-- self-rescheduling ticker; stops once the window is destroyed
local function tick()
	if Window.Destroyed then
		return
	end
	refreshStatus()
	task.delay(1, tick)
end
tick()

local function act(name)
	lastAction = name
	refreshStatus()
end

Dashboard:Button({
	Title = "Say hello",
	Desc = "Fires a success notification.",
	Icon = "lucide:zap",
	Callback = function()
		act("hello")
		say("Yohoho!", "The dummy hub says hi.", "success")
	end,
})

Dashboard:Button({
	Title = "Copy player name",
	Desc = "Uses setclipboard when the executor has it.",
	Callback = function()
		local name = game:GetService("Players").LocalPlayer.Name
		local ok = MugiwaraUI.Compat.SetClipboard(name)
		act("copy name")
		say(ok and "Copied" or "No clipboard", ok and name or "This executor has no setclipboard.", ok and "success" or "warning")
	end,
})

Dashboard:Paragraph({
	Title = "Window controls",
	Desc = "Top bar: theme menu, minimize, maximize, close. Drag the top bar to move, drag the bottom-right grip to resize.",
	Image = DEMO_IMAGE ~= "" and DEMO_IMAGE or nil, -- image card: fades in from the right
})

Dashboard:Label({ Title = "Executor: " .. tostring(MugiwaraUI.Compat.Executor) })
Dashboard:Label({ Title = "File access: " .. (MugiwaraUI.Compat.FilesSupported and "yes" or "no (configs disabled)") })

--// 2. Elements ----------------------------------------------------------------
local Elements = Overview:Tab({ Title = "Elements", Icon = "lucide:sliders-horizontal" })

local master = Elements:Toggle({
	Title = "Master switch",
	Desc = "Locks / unlocks the controls below (element:Lock).",
	Flag = "master",
	Value = true,
})

local dependents = {}
local function track(element)
	table.insert(dependents, element)
	return element
end

track(Elements:Toggle({
	Title = "Auto Farm (fake)",
	Icon = "lucide:swords",
	Flag = "farm",
	Callback = function(on)
		act("farm " .. tostring(on))
	end,
}))

track(Elements:Slider({
	Title = "Speed multiplier",
	Icon = "lucide:flame",
	Desc = "Step 0.1, with a suffix.",
	Flag = "speed",
	Value = { Min = 0.5, Max = 5, Default = 1 },
	Step = 0.1,
	Suffix = "x",
	Callback = function(value)
		act("speed " .. value)
	end,
}))

track(Elements:Slider({
	Title = "Distance",
	Flag = "distance",
	Value = { Min = 0, Max = 500, Default = 120 },
	Step = 5,
	Callback = function(value)
		act("distance " .. value)
	end,
}))

track(Elements:Dropdown({
	Title = "Target",
	Flag = "target",
	Values = { "Nearest", "Lowest HP", "Highest HP", "Boss" },
	Value = "Nearest",
	Callback = function(value)
		act("target " .. tostring(value))
	end,
}))

track(Elements:Dropdown({
	Title = "Skills",
	Desc = "Multi select.",
	Flag = "skills",
	Values = { "Pistol", "Gatling", "Bazooka", "Rocket", "Elephant Gun" },
	Value = { "Pistol", "Gatling" },
	Multi = true,
	Callback = function(values)
		act("skills " .. table.concat(values, "+"))
	end,
}))

local islands = Elements:Dropdown({
	Title = "Island (searchable)",
	Desc = "More than 8 values turns search on automatically.",
	Flag = "island",
	Values = { "Dawn", "Windmill", "Shells Town", "Orange Town", "Syrup", "Baratie", "Arlong Park", "Loguetown", "Reverse Mountain", "Whisky Peak", "Little Garden", "Drum", "Alabasta" },
	Value = "Dawn",
	Callback = function(value)
		act("island " .. tostring(value))
	end,
})

Elements:Button({
	Title = "Refresh island list",
	Desc = "dropdown:Refresh(newValues) swaps the options at runtime.",
	Callback = function()
		islands:Refresh({ "Skypiea", "Water 7", "Enies Lobby", "Thriller Bark", "Sabaody" }, false)
		act("refresh islands")
	end,
})

Elements:Divider({ Title = "text inputs" })

track(Elements:Input({
	Title = "Player name",
	Flag = "playername",
	Placeholder = "Luffy",
	Callback = function(text)
		act("name " .. text)
	end,
}))

track(Elements:Input({
	Title = "Amount (numbers only)",
	Flag = "amount",
	Numeric = true,
	Placeholder = "100",
	Callback = function(text)
		act("amount " .. text)
	end,
}))

track(Elements:Input({
	Title = "Notes",
	Type = "Textarea",
	Flag = "notes",
	Placeholder = "Multi-line notes...",
}))

track(Elements:Keybind({
	Title = "Action key",
	Icon = "lucide:keyboard",
	Desc = "Click, press a key. Backspace clears, Escape cancels.",
	Flag = "actionkey",
	Value = "K",
	Callback = function(key)
		act("key " .. key)
		say("Keybind", key .. " pressed", "info")
	end,
}))

track(Elements:Colorpicker({
	Title = "ESP color",
	Icon = "lucide:palette",
	Flag = "espcolor",
	Default = Color3.fromRGB(255, 150, 40),
	Transparency = 0,
	Callback = function(color, transparency)
		act(string.format("color %d,%d,%d a%.2f", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5), 1 - transparency))
	end,
}))

master:SetCallback(function(on)
	for _, element in ipairs(dependents) do
		if on then
			element:Unlock()
		else
			element:Lock(true)
		end
	end
	act("master " .. tostring(on))
end)

local Group = Elements:Section({ Title = "Collapsible section", Opened = true })
Group:Toggle({ Title = "A toggle inside a section", Flag = "insection" })
Group:Label({ Title = "Sections hold every element type." })
-- Sections nest up to 2 levels: tab > section > section ("double section")
local nested = Group:Section({ Title = "Double section (2nd level)", Opened = false })
nested:Button({
	Title = "Nested button",
	Callback = function()
		act("nested button")
	end,
})
nested:Button({
	Title = "Try a 3rd level",
	Desc = "Not allowed: the library raises an error, caught here with pcall.",
	Callback = function()
		local ok, err = pcall(function()
			nested:Section({ Title = "Too deep" })
		end)
		say(ok and "Allowed?!" or "Rejected", tostring(err), ok and "warning" or "info")
	end,
})
local hideMe = Group:Button({
	Title = "Hide me for 2 seconds",
	Desc = "element:SetVisible(false)",
})
hideMe:SetCallback(function()
	hideMe:SetVisible(false)
	task.delay(2, function()
		hideMe:SetVisible(true)
	end)
end)

--// 2b. Icons -------------------------------------------------------------------
local IconsTab = Overview:Tab({ Title = "Icons", Icon = "lucide:image" })

IconsTab:Paragraph({
	Title = "Icon sets",
	Desc = "Icons come from github.com/Footagesus/Icons (pinned to one commit). A set is downloaded the first time it is used, then cached in your executor workspace.",
	Icon = "lucide:info",
})

local samples = IconsTab:Section({ Title = "One icon per set", Opened = true })
for _, sample in ipairs({
	{ "Lucide", "lucide:house" },
	{ "Craft", "craft:folder-stroke" },
	{ "Geist", "geist:bell" },
	{ "Gravity UI", "gravity:gear" },
	{ "Solar", "solar:crown-bold" },
}) do
	samples:Button({
		Title = sample[1],
		Desc = sample[2],
		Icon = sample[2],
		Callback = function()
			say(sample[1], sample[2], "info")
		end,
	})
end

local tryIt = IconsTab:Section({ Title = "Try any icon", Opened = true })
local previewSet, previewName = "lucide", "heart"
local preview = tryIt:Paragraph({ Title = "Preview", Desc = "lucide:heart", Icon = "lucide:heart" })

tryIt:Dropdown({
	Title = "Set",
	Values = MugiwaraUI.IconSets.Available,
	Value = "lucide",
	Searchable = false,
	Callback = function(value)
		previewSet = value or "lucide"
	end,
})

tryIt:Input({
	Title = "Icon name",
	Desc = "Lucide: house, swords, skull... Solar names end with -bold / -linear.",
	Value = "heart",
	Placeholder = "heart",
	Callback = function(text)
		previewName = text
	end,
})

tryIt:Button({
	Title = "Show icon",
	Callback = function()
		local icon = previewSet .. ":" .. previewName
		local found = preview:SetIcon(icon)
		preview:SetDesc(found and icon or (icon .. "  (not found)"))
		if not found then
			say("Icon not found", icon .. " does not exist in that set (or it could not be downloaded).", "warning")
		end
	end,
})

--// 2c. More elements: ProgressBar, Code, Image, Group, Space ---------------------
local More = Overview:Tab({ Title = "More", Icon = "lucide:layers" })

local download = More:ProgressBar({
	Title = "Download",
	Desc = "progressBar:Set(value) animates the bar.",
	Icon = "lucide:loader",
	Value = 0,
})

-- Group: elements side by side, equal widths
local presets = More:Group({ Gap = 8 })
presets:Button({ Title = "0%", Callback = function() download:Set(0) end })
presets:Button({ Title = "50%", Callback = function() download:Set(50) end })
presets:Button({ Title = "100%", Callback = function() download:Set(100) end })

More:Button({
	Title = "Simulate download",
	Icon = "lucide:play",
	Callback = function()
		task.spawn(function()
			for value = 0, 100, 4 do
				download:Set(value)
				task.wait(0.06)
			end
		end)
	end,
})

More:Space(6)
More:Divider({ Title = "side by side" })
local switches = More:Group()
switches:Toggle({ Title = "Left", Flag = "group_left" })
switches:Toggle({ Title = "Right", Flag = "group_right" })

More:Divider({ Title = "code" })
More:Code({
	Title = "Example.lua",
	Desc = "Lua is highlighted, long lines scroll sideways, Copy puts it on the clipboard.",
	Code = [==[-- Teleport to the highest ground
local Players = game:GetService("Players")
local player = Players.LocalPlayer

for index = 1, 3 do
    print("attempt", index, "of", 3.0)
end

local message = "Mugiwara UI says hi"
return #message > 0]==],
})

More:Divider({ Title = "image" })
More:Image({
	Title = "Image element",
	Desc = DEMO_IMAGE ~= "" and "Loaded from DEMO_IMAGE." or "Set DEMO_IMAGE at the top of this file to see a picture here.",
	Image = DEMO_IMAGE ~= "" and DEMO_IMAGE or nil,
	Height = 160,
})

--// 3. Notifications & dialogs -------------------------------------------------
local Feedback = Window:TabSection({ Title = "Feedback" })
local Notifs = Feedback:Tab({ Title = "Notifications", Icon = "lucide:bell" })

Notifs:Button({ Title = "Info", Callback = function() say("Info", "Something neutral happened.", "info") end })
Notifs:Button({ Title = "Success", Callback = function() say("Success", "Everything worked.", "success") end })
Notifs:Button({ Title = "Warning", Callback = function() say("Warning", "Careful with that.", "warning") end })
Notifs:Button({ Title = "Error", Callback = function() say("Error", "Something broke.", "error") end })
Notifs:Button({
	Title = "Sticky (click to dismiss)",
	Callback = function()
		MugiwaraUI:Notify({ Title = "Sticky", Content = "Duration = 0 stays until you click it.", Duration = 0 })
	end,
})
Notifs:Button({
	Title = "Spam 8 notifications",
	Desc = "Only the newest 6 stay on screen.",
	Callback = function()
		for index = 1, 8 do
			MugiwaraUI:Notify({ Title = "Notification " .. index, Content = "Stack test", Duration = 4 })
		end
	end,
})

Notifs:Divider({ Title = "dialogs" })

Notifs:Button({
	Title = "Confirm dialog",
	Callback = function()
		Window:Dialog({
			Title = "Gomu Gomu no...",
			Content = "Are you sure you want to continue?",
			Buttons = {
				{ Title = "Nope", Style = "Secondary" },
				{
					Title = "Do it",
					Style = "Primary",
					Callback = function()
						say("Bazooka!", "Confirmed.", "success")
					end,
				},
			},
		})
	end,
})

Notifs:Button({
	Title = "Danger dialog",
	Callback = function()
		Window:Dialog({
			Title = "Delete everything?",
			Content = "This is only a test, nothing is deleted.",
			Buttons = {
				{ Title = "Cancel", Style = "Secondary" },
				{ Title = "Delete", Style = "Danger", Callback = function() say("Deleted", "(not really)", "error") end },
			},
		})
	end,
})

--// 4. Window controls ---------------------------------------------------------
Window:SidebarDivider()
local SettingsGroup = Window:TabSection({ Title = "Settings" })
local Settings = SettingsGroup:Tab({ Title = "Window", Icon = "lucide:app-window" })

Settings:Paragraph({
	Title = "Theme",
	Desc = "The theme menu moved to the top bar (the colored dot). Pick one there and everything re-tints live.",
})

Settings:Button({
	Title = "Maximize / restore",
	Desc = "Same as the square button in the top bar.",
	Callback = function()
		Window:ToggleMaximized()
	end,
})

Settings:Input({
	Title = "Wallpaper",
	Desc = "Asset id or URL. Empty removes it.",
	Placeholder = "rbxassetid://...",
	Callback = function(text)
		Window:SetBackground(text)
	end,
})

Settings:Slider({
	Title = "Wallpaper strength",
	Desc = "Applies the next time a wallpaper is set.",
	Value = { Min = 0, Max = 100, Default = 45 },
	Suffix = "%",
	Callback = function(value)
		Window.BackgroundImage.ImageTransparency = 1 - value / 100
	end,
})

Settings:Slider({
	Title = "UI scale",
	Value = { Min = 0.6, Max = 1.4, Default = 1 },
	Step = 0.05,
	Suffix = "x",
	Callback = function(value)
		Window:SetScale(value)
	end,
})

Settings:Toggle({
	Title = "Background blur",
	Desc = "Blurs the game behind the window while it is open.",
	Callback = function(on)
		Window:SetBlur(on)
	end,
})

Settings:Keybind({
	Title = "Toggle window key",
	Value = "RightShift",
	OnChange = function(key)
		local ok, keyCode = pcall(function()
			return Enum.KeyCode[key]
		end)
		if key and ok and keyCode then
			Window:SetToggleKey(keyCode)
			say("Toggle key", "Now using " .. key, "info")
		end
	end,
})

Settings:Input({
	Title = "Window title",
	Value = "Mugiwara Dummy",
	Callback = function(text)
		if text ~= "" then
			Window:SetTitle(text)
		end
	end,
})

Settings:Button({
	Title = "Minimize window",
	Desc = "Click the floating button to bring it back.",
	Callback = function()
		Window:Close()
	end,
})

Settings:Button({
	Title = "Destroy UI",
	Callback = function()
		Window:Dialog({
			Title = "Destroy the UI?",
			Content = "Run the script again to bring it back.",
			Buttons = {
				{ Title = "Cancel", Style = "Secondary" },
				{ Title = "Destroy", Style = "Danger", Callback = function() Window:Destroy() end },
			},
		})
	end,
})

--// 5. Configs -----------------------------------------------------------------
local Configs = SettingsGroup:Tab({ Title = "Configs", Icon = "lucide:save" })
Configs:Paragraph({
	Title = "How it works",
	Desc = "Every element with a Flag is saved. Change a few values on the Elements tab, save a config here, change them again, then load it back.",
})
Window:ConfigSection(Configs)

-- apply the config marked "auto load", if any (call after the UI is fully built)
Window:LoadAutoConfig()

say("Dummy hub loaded", "Press RightShift to hide / show.", "success")
