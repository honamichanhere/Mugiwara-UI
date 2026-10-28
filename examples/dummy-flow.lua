-- Mugiwara UI flow demo:  Key UI  >  Loading UI  >  Main UI
-- Everything is fake: ANY key you type is accepted, the "loading" only pretends to work.
--
--   1. Key UI      MugiwaraUI:KeySystem({...})   -> KeyUI:Wait() returns the accepted key
--   2. Loading UI  MugiwaraUI:Loading({...})     -> SetStatus / SetProgress / Log, then Finish()
--   3. Main UI     MugiwaraUI:CreateWindow({...})
--
-- Offline test: save dist/main.lua as "MugiwaraUI.lua" in your executor workspace folder.

local URL = "https://raw.githubusercontent.com/honamichanhere/Mugiwara-UI/main/dist/main.lua"

local function loadLibrary()
	if isfile and readfile and isfile("MugiwaraUI.lua") then
		return loadstring(readfile("MugiwaraUI.lua"))()
	end
	return loadstring(game:HttpGet(URL))()
end

local MugiwaraUI = loadLibrary()

local HUB = {
	Name = "Mugiwara Dummy",
	Owner = "Honami",
	Version = "v1.0.0",
	Folder = "MugiwaraFlow",
}

--// 1. Key UI ------------------------------------------------------------------------
local KeyUI = MugiwaraUI:KeySystem({
	Title = HUB.Name,
	Subtitle = "Key System",
	Icon = "lucide:key-round",
	Note = "Demo: any key is accepted. Type anything and press Verify.",
	Folder = HUB.Folder,
	Links = {
		{ Title = "Get Key", Icon = "lucide:external-link", Link = "https://example.com/get-key" },
		{ Title = "Discord", Icon = "lucide:message-circle", Link = "https://discord.gg/example" },
	},
	-- Your real check goes here (HTTP request, hash compare...). It may yield. Return true / false, message.
	Validate = function(key)
		task.wait(0.8) -- pretend to ask a server
		return true, "Key accepted"
	end,
	OnSuccess = function(key)
		print("[Flow] key accepted:", key)
	end,
})

local key = KeyUI:Wait() -- yields until a key is accepted (or the card is closed)
if not key then
	print("[Flow] key UI closed, stopping")
	return
end

--// 2. Loading UI ----------------------------------------------------------------------
local Loader = MugiwaraUI:Loading({
	Title = HUB.Name,
	Owner = HUB.Owner,
	Version = HUB.Version,
})

-- { status, progress target, creep cap, seconds, log line }
local stages = {
	{ "Loading libraries", 20, 40, 1.4, "Fetching UI library" },
	{ "Loading modules", 45, 70, 1.6, "Mounting feature modules" },
	{ "Syncing configuration", 75, 90, 1.2, "Reading saved settings" },
}
for _, stage in ipairs(stages) do
	Loader:SetStatus(stage[1])
	Loader:SetProgress(stage[2], stage[3]) -- jump to the target, then creep up to the cap
	Loader:Log(stage[5], "info")
	task.wait(stage[4])
end
Loader:Log("Everything is ready", "ok")

Loader:Finish("Welcome, " .. string.sub(key, 1, 2) .. "***")
Loader.Finished:Wait() -- resumes once the loading card is completely gone

--// 3. Main UI -------------------------------------------------------------------------
local Window = MugiwaraUI:CreateWindow({
	Title = HUB.Name,
	Subtitle = "Key > Loading > Main",
	Version = HUB.Version,
	Icon = "lucide:sun",
	Folder = HUB.Folder,
	Size = UDim2.fromOffset(620, 420),
})

local Home = Window:Tab({ Title = "Home", Icon = "lucide:house" })

Home:Paragraph({
	Title = "Flow completed",
	Desc = "You came through the Key UI and the Loading UI. This is the Main UI.",
	Icon = "lucide:circle-check",
})
Home:Label({ Title = "Key used: " .. string.sub(key, 1, 2) .. string.rep("*", math.max(#key - 2, 0)), Icon = "lucide:key-round" })
Home:Label({ Title = "Executor: " .. tostring(MugiwaraUI.Compat.Executor), Icon = "lucide:cpu" })

Home:Button({
	Title = "Forget saved key",
	Desc = "Turn on 'Remember key' in the Key UI, run again, and the key UI is skipped. This clears it.",
	Icon = "lucide:trash-2",
	Callback = function()
		KeyUI:ClearSavedKey()
		MugiwaraUI:Notify({ Title = "Saved key cleared", Content = "The Key UI will show up next run.", Type = "success" })
	end,
})

Home:Button({
	Title = "Run the loading UI again",
	Icon = "lucide:loader",
	Callback = function()
		local again = MugiwaraUI:Loading({ Title = HUB.Name, Owner = HUB.Owner, Version = HUB.Version })
		again:SetStatus("Reloading")
		again:SetProgress(60, 90)
		task.delay(3, function()
			again:Finish("Reloaded")
		end)
	end,
})

local Features = Window:Tab({ Title = "Features", Icon = "lucide:sliders-horizontal" })
Features:Toggle({ Title = "Fake feature", Icon = "lucide:zap", Flag = "fake", Callback = function(on) print("fake:", on) end })
Features:Slider({ Title = "Amount", Flag = "amount", Value = { Min = 0, Max = 100, Default = 40 }, Suffix = "%" })
Features:Dropdown({ Title = "Mode", Flag = "mode", Values = { "Safe", "Normal", "Fast" }, Value = "Normal", Searchable = false })

local Settings = Window:Tab({ Title = "Settings", Icon = "lucide:app-window" })
Window:ConfigSection(Settings)
Window:LoadAutoConfig()

MugiwaraUI:Notify({ Title = "Welcome", Content = "Press RightShift to hide / show.", Type = "success" })
