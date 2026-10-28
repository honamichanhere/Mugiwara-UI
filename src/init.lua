--// Mugiwara UI entry point.

local Compat = Import("core/Compat")
local Icons = Import("core/Icons")
local IconSets = Import("core/IconSets")
local Theme = Import("core/Theme")
local Window = Import("components/Window")
local Notification = Import("components/Notification")
local ChatTransports = Import("components/ChatTransports")
local KeySystem = Import("components/KeySystem")
local Loading = Import("components/Loading")

-- Re-executing the script replaces the previous instance instead of stacking UIs.
local env = Compat.Env
if env.MugiwaraUI and type(env.MugiwaraUI.Destroy) == "function" then
	pcall(function()
		env.MugiwaraUI:Destroy()
	end)
end

local Library = {
	Version = "@VERSION@",
	Windows = {},
	Theme = Theme.new("Gear 5"),
	Icons = Icons,
	IconSets = IconSets,
	ChatTransports = ChatTransports, -- Http (Cloudflare Worker backend) and Memory (offline demo)
	Compat = Compat,
}

function Library:CreateWindow(opts)
	return Window.new(self, opts)
end

-- Key UI: a separate card that validates a key with your Validate(key) function. KeyUI:Wait() -> key | nil
function Library:KeySystem(opts)
	return KeySystem(self, opts)
end

-- Loading UI: terminal-style loader. Drive it with SetStatus / SetProgress / Log, end it with Finish().
function Library:Loading(opts)
	return Loading(self, opts)
end

function Library:Notify(opts)
	return Notification.Notify(self, opts)
end

function Library:SetTheme(name)
	return self.Theme:Set(name)
end

function Library:GetTheme()
	return self.Theme.Name
end

function Library:GetThemes()
	return self.Theme:List()
end

-- Library:AddTheme("Mine", { Accent = Color3..., Gradient = { Color3... } })
function Library:AddTheme(name, tokens)
	self.Theme:Add(name, tokens)
end

-- Default icon set for names without a prefix ("house" vs "lucide:house"): lucide, craft, geist, gravity, solar
function Library:SetIconSet(name)
	return IconSets.SetDefault(name)
end

-- Icons of the built-in controls: Chevron, Check, Close, Minus, Square, Restore.
-- UI:SetGlyphs({ Close = "lucide:circle-x" }); false keeps the drawn version. Call it before CreateWindow.
function Library:SetGlyphs(map)
	Icons.SetGlyphs(map)
end

-- Downloads icon sets ahead of time (in the background) so the first icons do not wait on the network.
function Library:PreloadIcons(...)
	IconSets.Preload({ ... })
end

function Library:Destroy()
	for window in pairs(self.Windows) do
		window:Destroy()
	end
	if self._loader then
		self._loader:Destroy()
	end
	if self._keyUI then
		self._keyUI:Close()
	end
	if self._notifyGui then
		self._notifyGui:Destroy()
		self._notifyGui = nil
		self._notifyHolder = nil
	end
	if env.MugiwaraUI == self then
		env.MugiwaraUI = nil
	end
end

env.MugiwaraUI = Library

return Library
