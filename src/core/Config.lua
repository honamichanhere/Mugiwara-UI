--// Config: saves/loads every flagged element to <Folder>/configs/<name>.json.
--// A small index file is kept so listing works even on executors without listfiles.

local HttpService = game:GetService("HttpService")

local Compat = Import("core/Compat")

local Config = {}

local function root(window)
	return window.Folder .. "/configs"
end

local function indexPath(window)
	return root(window) .. "/_index.json"
end

local function filePath(window, name)
	return root(window) .. "/" .. name .. ".json"
end

function Config.Sanitize(name)
	name = string.gsub(tostring(name or ""), "[^%w%-_ ]", "")
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	return name
end

function Config.List(window)
	local raw = Compat.ReadFile(indexPath(window))
	if not raw then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(decoded) ~= "table" then
		return {}
	end
	local names = {}
	for _, name in ipairs(decoded) do
		if Compat.FileExists(filePath(window, name)) then
			table.insert(names, name)
		end
	end
	return names
end

local function writeIndex(window, names)
	table.sort(names)
	Compat.WriteFile(indexPath(window), HttpService:JSONEncode(names))
end

function Config.Save(window, name)
	name = Config.Sanitize(name)
	if name == "" then
		return false, "Config name is empty"
	end
	if not Compat.FilesSupported then
		return false, "This executor has no file access"
	end

	local data = {}
	for flag, element in pairs(window.Flags) do
		if element.Serialize then
			data[flag] = element.Serialize()
		end
	end

	Compat.EnsureFolder(root(window))
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, { Version = 1, Data = data })
	if not ok then
		return false, "Could not encode config"
	end
	if not Compat.WriteFile(filePath(window, name), encoded) then
		return false, "Could not write file"
	end

	local names = Config.List(window)
	if not table.find(names, name) then
		table.insert(names, name)
	end
	writeIndex(window, names)
	return true
end

function Config.Load(window, name)
	name = Config.Sanitize(name)
	local raw = Compat.ReadFile(filePath(window, name))
	if not raw then
		return false, "Config not found"
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(decoded) ~= "table" or type(decoded.Data) ~= "table" then
		return false, "Config is corrupted"
	end
	for flag, value in pairs(decoded.Data) do
		local element = window.Flags[flag]
		if element and element.Deserialize then
			pcall(element.Deserialize, value)
		end
	end
	return true
end

function Config.Delete(window, name)
	name = Config.Sanitize(name)
	Compat.DeleteFile(filePath(window, name))
	local names = {}
	for _, existing in ipairs(Config.List(window)) do
		if existing ~= name then
			table.insert(names, existing)
		end
	end
	writeIndex(window, names)
	return true
end

function Config.GetAutoLoad(window)
	local raw = Compat.ReadFile(root(window) .. "/_autoload.txt")
	if raw and raw ~= "" then
		return raw
	end
	return nil
end

function Config.SetAutoLoad(window, name)
	Compat.EnsureFolder(root(window))
	Compat.WriteFile(root(window) .. "/_autoload.txt", name and Config.Sanitize(name) or "")
end

return Config
