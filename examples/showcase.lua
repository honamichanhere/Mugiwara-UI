-- Mugiwara UI showcase: every element + notifications, dialogs, themes and configs.
-- Run it on any executor (Delta, Xeno, Solara, ...).

local MugiwaraUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-UI/main/dist/main.lua"))()

local Window = MugiwaraUI:CreateWindow({
	Title = "Mugiwara Hub",
	Subtitle = "Gear 5 edition",
	Folder = "MugiwaraHub",
	Size = UDim2.fromOffset(640, 430),
	ToggleKey = Enum.KeyCode.RightShift,
	Blur = false, -- true = blur the game behind the window while it is open
})

--// Main tab
local Main = Window:Tab({ Title = "Main" })

Main:Paragraph({
	Title = "Welcome, Straw Hat",
	Desc = "Everything here is a placeholder. Hook your own logic into the callbacks.",
})

Main:Button({
	Title = "Say hello",
	Desc = "Fires a notification.",
	Callback = function()
		MugiwaraUI:Notify({ Title = "Yohoho!", Content = "Mugiwara UI is alive.", Type = "success", Duration = 4 })
	end,
})

Main:Toggle({
	Title = "Auto Farm",
	Desc = "Toggles a (fake) farm loop.",
	Flag = "autofarm",
	Value = false,
	Callback = function(state)
		print("Auto Farm:", state)
	end,
})

Main:Slider({
	Title = "Walk Speed",
	Flag = "walkspeed",
	Value = { Min = 16, Max = 200, Default = 16 },
	Step = 1,
	Callback = function(value)
		local humanoid = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = value
		end
	end,
})

Main:Dropdown({
	Title = "Target",
	Flag = "target",
	Values = { "Nearest", "Lowest HP", "Highest HP", "Boss" },
	Value = "Nearest",
	Callback = function(value)
		print("Target:", value)
	end,
})

Main:Dropdown({
	Title = "Skills",
	Desc = "Multi select",
	Flag = "skills",
	Values = { "Pistol", "Gatling", "Bazooka", "Rocket", "Elephant Gun" },
	Value = { "Pistol" },
	Multi = true,
	Callback = function(values)
		print("Skills:", table.concat(values, ", "))
	end,
})

--// Inputs tab
local Inputs = Window:Tab({ Title = "Inputs" })

Inputs:Input({
	Title = "Player name",
	Flag = "playername",
	Placeholder = "Luffy",
	Callback = function(text)
		print("Name:", text)
	end,
})

Inputs:Input({
	Title = "Notes",
	Type = "Textarea",
	Flag = "notes",
	Placeholder = "Write anything...",
})

Inputs:Keybind({
	Title = "Panic key",
	Desc = "Click, then press a key. Backspace clears, Escape cancels.",
	Flag = "panic",
	Value = "K",
	Callback = function()
		MugiwaraUI:Notify({ Title = "Panic", Content = "Panic key pressed.", Type = "warning" })
	end,
})

Inputs:Colorpicker({
	Title = "ESP color",
	Flag = "espcolor",
	Default = Color3.fromRGB(255, 150, 40),
	Transparency = 0,
	Callback = function(color, transparency)
		print("ESP:", color, transparency)
	end,
})

local Group = Inputs:Section({ Title = "Collapsible section", Opened = true })
Group:Toggle({ Title = "Inside a section", Flag = "insection" })
Group:Label({ Title = "Sections can hold every element." })
Group:Divider({ Title = "divider" })
Group:Button({
	Title = "Open dialog",
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
						MugiwaraUI:Notify({ Title = "Bazooka!", Type = "info" })
					end,
				},
			},
		})
	end,
})

--// Settings tab
Window:SidebarDivider()
local Settings = Window:Tab({ Title = "Settings" })

Settings:Dropdown({
	Title = "Theme",
	Values = MugiwaraUI:GetThemes(),
	Value = MugiwaraUI:GetTheme(),
	Searchable = false,
	Callback = function(name)
		MugiwaraUI:SetTheme(name)
	end,
})

Settings:Toggle({
	Title = "Background blur",
	Callback = function(state)
		Window:SetBlur(state)
	end,
})

Window:ConfigSection(Settings)

-- applies the config marked "auto load", if any
Window:LoadAutoConfig()

MugiwaraUI:Notify({
	Title = "Mugiwara UI " .. MugiwaraUI.Version,
	Content = "Press RightShift to hide / show the window.",
	Duration = 5,
})
