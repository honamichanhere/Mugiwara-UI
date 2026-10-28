--// Executor compatibility layer. Every executor function is optional; each helper
--// degrades gracefully so the UI still works on weak executors (Solara, Xeno, Delta...).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Compat = {}

local function try(fn, ...)
	local ok, result = pcall(fn, ...)
	if ok then
		return result
	end
	return nil
end

Compat.Env = (getgenv and try(getgenv)) or _G

Compat.Executor = (identifyexecutor and try(identifyexecutor)) or "Unknown"

Compat.IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function service(name)
	local raw = game:GetService(name)
	if cloneref then
		return try(cloneref, raw) or raw
	end
	return raw
end

Compat.Service = service

--// GUI parent -----------------------------------------------------------------
local function canParentTo(container)
	if not container then
		return false
	end
	return (pcall(function()
		local probe = Instance.new("Folder")
		probe.Parent = container
		probe:Destroy()
	end))
end

function Compat.GetGuiParent()
	if gethui then
		local hui = try(gethui)
		if hui and canParentTo(hui) then
			return hui
		end
	end

	local coreGui = try(service, "CoreGui")
	if coreGui and canParentTo(coreGui) then
		return coreGui
	end

	local player = Players.LocalPlayer
	local playerGui = player and (player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5))
	return playerGui
end

function Compat.Protect(gui)
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
	elseif protect_gui then
		pcall(protect_gui, gui)
	end
end

--// Files ---------------------------------------------------------------------
Compat.FilesSupported = (writefile ~= nil and readfile ~= nil and isfile ~= nil and makefolder ~= nil and isfolder ~= nil)

function Compat.EnsureFolder(path)
	if not Compat.FilesSupported then
		return false
	end
	local built = ""
	for part in string.gmatch(path, "[^/\\]+") do
		built = built == "" and part or (built .. "/" .. part)
		if not try(isfolder, built) then
			pcall(makefolder, built)
		end
	end
	return try(isfolder, path) == true
end

function Compat.WriteFile(path, content)
	if not Compat.FilesSupported then
		return false
	end
	return (pcall(writefile, path, content))
end

function Compat.ReadFile(path)
	if not Compat.FilesSupported then
		return nil
	end
	if not try(isfile, path) then
		return nil
	end
	return try(readfile, path)
end

function Compat.FileExists(path)
	return Compat.FilesSupported and try(isfile, path) == true
end

function Compat.DeleteFile(path)
	if delfile and Compat.FileExists(path) then
		return (pcall(delfile, path))
	end
	return false
end

--// Images --------------------------------------------------------------------
local function hashText(text)
	local hash = 5381
	for index = 1, #text do
		hash = (hash * 33 + string.byte(text, index)) % 4294967296
	end
	return string.format("%08x", hash)
end

-- Turns an asset id / "rbxassetid://..." / http(s) URL into something an ImageLabel accepts.
-- URLs are downloaded once into <folder>/cache and served through getcustomasset
-- (needs request + writefile + getcustomasset). May yield, so call it from a task.
function Compat.ResolveImage(source, folder)
	if type(source) == "number" then
		return "rbxassetid://" .. source
	end
	if type(source) ~= "string" or source == "" then
		return nil
	end
	if string.find(source, "^rbxasset") then
		return source
	end
	if tonumber(source) then
		return "rbxassetid://" .. source
	end
	if string.find(source, "^https?://") then
		local requester = request or http_request or (syn and syn.request)
		local assetOf = getcustomasset or getsynasset
		if not (requester and assetOf and Compat.FilesSupported) then
			return nil
		end
		local path = (folder or "MugiwaraUI") .. "/cache/" .. hashText(source) .. ".png"
		if not Compat.FileExists(path) then
			local response = try(requester, { Url = source, Method = "GET" })
			if not (response and response.Body and (response.StatusCode == nil or response.StatusCode == 200)) then
				return nil
			end
			Compat.EnsureFolder((folder or "MugiwaraUI") .. "/cache")
			if not Compat.WriteFile(path, response.Body) then
				return nil
			end
		end
		return try(assetOf, path)
	end
	return nil
end

--// Clipboard -----------------------------------------------------------------
function Compat.SetClipboard(text)
	local setter = setclipboard or toclipboard or (Clipboard and Clipboard.set)
	if setter then
		return (pcall(setter, tostring(text)))
	end
	return false
end

return Compat
