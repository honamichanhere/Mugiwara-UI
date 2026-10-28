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

local ASSET_IMAGE, ASSET_DECAL = 1, 13
local resolvedAssets = {}

-- Roblox Store images are almost always Decal assets, and an ImageLabel cannot show a Decal id
-- (it renders nothing). A Decal wraps the real image, so the image id is read from the Decal.
-- Returns the usable image string, or nil plus the reason it cannot be used.
local function imageFromAssetId(id)
	if resolvedAssets[id] then
		return resolvedAssets[id]
	end

	local assetType
	local ok, info = pcall(function()
		return service("MarketplaceService"):GetProductInfo(id, Enum.InfoType.Asset)
	end)
	if ok and type(info) == "table" then
		assetType = info.AssetTypeId
	end

	local image, reason
	if assetType == ASSET_DECAL then
		-- only Decals are ever loaded as objects, and the result is destroyed right away
		local loaded, objects = pcall(function()
			return game:GetObjects("rbxassetid://" .. id)
		end)
		local root = loaded and objects and objects[1]
		if root then
			local decal = root:IsA("Decal") and root or root:FindFirstChildWhichIsA("Decal", true)
			image = decal and decal.Texture
			pcall(function()
				root:Destroy()
			end)
		end
		if not image or image == "" then
			image = nil
			reason = "Asset " .. id .. " is a Decal and this executor cannot convert it (needs game:GetObjects). Use its Image id instead."
		end
	elseif assetType == nil or assetType == ASSET_IMAGE then
		image = "rbxassetid://" .. id
	else
		reason = "Asset " .. id .. " is not an image (asset type " .. tostring(assetType) .. ")."
	end

	if image then
		resolvedAssets[id] = image
	end
	return image, reason
end

-- Turns an asset id / "rbxassetid://..." / http(s) URL into something an ImageLabel accepts.
-- URLs are downloaded once into <folder>/cache and served through getcustomasset
-- (needs request + writefile + getcustomasset). May yield, so call it from a task.
-- Returns the image, or nil plus a reason.
function Compat.ResolveImage(source, folder)
	if type(source) == "string" then
		source = string.gsub(source, "^%s+", "")
		source = string.gsub(source, "%s+$", "")
	end
	if source == nil or source == "" then
		return nil
	end

	local id = tonumber(source) or tonumber(string.match(tostring(source), "^rbxassetid://(%d+)$"))
	if id then
		return imageFromAssetId(id)
	end
	if type(source) ~= "string" then
		return nil, "Unsupported image value"
	end
	if string.find(source, "^rbxasset") then
		return source
	end

	if string.find(source, "^https?://") then
		local requester = request or http_request or (syn and syn.request)
		local assetOf = getcustomasset or getsynasset
		if not (requester and assetOf and Compat.FilesSupported) then
			return nil, "This executor cannot download URLs (needs request, writefile and getcustomasset)."
		end
		local path = (folder or "MugiwaraUI") .. "/cache/" .. hashText(source) .. ".png"
		if not Compat.FileExists(path) then
			local response = try(requester, { Url = source, Method = "GET" })
			if not (response and response.Body and (response.StatusCode == nil or response.StatusCode == 200)) then
				return nil, "Could not download the image."
			end
			Compat.EnsureFolder((folder or "MugiwaraUI") .. "/cache")
			if not Compat.WriteFile(path, response.Body) then
				return nil, "Could not save the image to the executor folder."
			end
		end
		local asset = try(assetOf, path)
		if not asset then
			return nil, "getcustomasset failed for the downloaded image."
		end
		return asset
	end
	return nil, "Unrecognized image. Use an asset id, rbxassetid://id, or an http(s) URL."
end

-- true / false when Roblox reports the load result, nil when it cannot be checked
function Compat.ImageLoaded(label)
	local ok, status = pcall(function()
		local provider = service("ContentProvider")
		provider:PreloadAsync({ label })
		return provider:GetAssetFetchStatus(label.Image)
	end)
	if not ok or status == nil then
		return nil
	end
	if status == Enum.AssetFetchStatus.Success then
		return true
	elseif status == Enum.AssetFetchStatus.Failure then
		return false
	end
	return nil
end

--// HTTP -----------------------------------------------------------------------
-- Plain GET for executors: game:HttpGet first, request() as a fallback. Returns the body or nil.
function Compat.HttpGet(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" and body ~= "" then
		return body
	end
	local requester = request or http_request or (syn and syn.request)
	if requester then
		local response = try(requester, { Url = url, Method = "GET" })
		if response and type(response.Body) == "string" and (response.StatusCode == nil or response.StatusCode == 200) then
			return response.Body
		end
	end
	return nil
end

-- Full request (method, headers, body). Returns the response table, or nil plus a reason.
function Compat.HttpRequest(options)
	local requester = request or http_request or (syn and syn.request)
	if not requester then
		return nil, "This executor has no request function"
	end
	local ok, response = pcall(requester, options)
	if not ok then
		return nil, tostring(response)
	end
	return response
end

--// Clipboard -----------------------------------------------------------------
-- Reading the clipboard is only offered by some executors; nil when unavailable.
Compat.GetClipboard = (getclipboard or readclipboard) and function()
	local reader = getclipboard or readclipboard
	local ok, text = pcall(reader)
	return ok and type(text) == "string" and text or nil
end or nil

function Compat.SetClipboard(text)
	local setter = setclipboard or toclipboard or (Clipboard and Clipboard.set)
	if setter then
		return (pcall(setter, tostring(text)))
	end
	return false
end

return Compat
