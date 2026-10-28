--// IconSets: icons from the Footagesus/Icons collection (https://github.com/Footagesus/Icons, MIT).
--//
--// Nothing is bundled. A set (a few hundred KB of asset ids) is downloaded the first time one of its
--// icons is used, then cached in the executor workspace so later runs work offline.
--// The download is pinned to one commit: a raw URL for a commit never changes, so the code that
--// gets executed on users' machines cannot be swapped by a later push to that repository.

local Compat = Import("core/Compat")
local Utility = Import("core/Utility")

local REPO = "Footagesus/Icons"
local COMMIT = "46d30c19ba7bc601d6ec794a48dc3a89568b1eec"
local CACHE_DIR = "MugiwaraUI/cache"
local RETRY_AFTER = 30 -- seconds before a failed download is attempted again

local IconSets = {}

IconSets.Default = "lucide"

-- "sfsymbols" exists in that repository but is left out on purpose: Apple's license only
-- allows SF Symbols in apps for Apple platforms.
IconSets.Available = { "lucide", "craft", "geist", "gravity", "solar" }

local allowed = {}
for _, name in ipairs(IconSets.Available) do
	allowed[name] = true
end

-- loaded sets live on the executor environment so re-running the script does not download again
local store = Compat.Env.__MugiwaraIconSets
if not store then
	store = {}
	Compat.Env.__MugiwaraIconSets = store
end
local failedAt = {}

local function sourceUrl(set)
	return string.format("https://raw.githubusercontent.com/%s/%s/%s/dist/Icons.lua", REPO, COMMIT, set)
end

local function cachePath(set)
	return string.format("%s/icons-%s-%s.lua", CACHE_DIR, set, string.sub(COMMIT, 1, 8))
end

-- A set file is a Lua table of data only (asset ids and Vector2 values).
local function readSet(set)
	local path = cachePath(set)
	local source = Compat.ReadFile(path)
	local fromCache = source ~= nil
	if not source then
		source = Compat.HttpGet(sourceUrl(set))
	end
	if not source or not loadstring then
		return nil
	end

	local compiled = loadstring(source)
	local ok, data = false, nil
	if compiled then
		ok, data = pcall(compiled)
	end
	if not ok or type(data) ~= "table" then
		if fromCache then
			Compat.DeleteFile(path) -- corrupted cache: next run downloads it again
		end
		return nil
	end

	if not fromCache then
		Compat.EnsureFolder(CACHE_DIR)
		Compat.WriteFile(path, source)
	end
	return data
end

-- Downloads (or reads from cache) a set. May yield on the first call. Returns the data or nil.
function IconSets.Load(set)
	if not allowed[set] then
		return nil
	end
	if store[set] then
		return store[set]
	end
	if failedAt[set] and os.clock() - failedAt[set] < RETRY_AFTER then
		return nil
	end
	local data = readSet(set)
	if data then
		store[set] = data
		failedAt[set] = nil
		return data
	end
	failedAt[set] = os.clock()
	return nil
end

-- Loads sets in the background so the first icon does not stall the UI build.
function IconSets.Preload(sets)
	task.spawn(function()
		for _, set in ipairs(sets or { IconSets.Default }) do
			IconSets.Load(set)
		end
	end)
end

function IconSets.SetDefault(set)
	set = string.lower(tostring(set))
	if not allowed[set] then
		return false
	end
	IconSets.Default = set
	return true
end

-- "house" -> default set; "craft:folder-stroke" -> that set; unknown prefix (or a disabled set) -> nil
function IconSets.Parse(icon)
	if type(icon) ~= "string" then
		return nil
	end
	local set, name = string.match(icon, "^(%w+):(.+)$")
	if set then
		set = string.lower(set)
		if allowed[set] then
			return set, name
		end
		return nil
	end
	return IconSets.Default, icon
end

-- Turns a raw entry into { Image, RectSize, RectOffset, Parts }.
-- Flat sets map name -> "rbxassetid://..."; spritesheet sets (craft, geist) store a cell inside a sheet.
-- Parts are extra layers (duotone icons); they are resolved one level deep.
local function describe(data, name, depth)
	local entry = data.Icons and data.Icons[name]
	if entry then
		local sheet = data.Spritesheets and data.Spritesheets[tostring(entry.Image)] or entry.Image
		if type(sheet) == "number" then
			sheet = "rbxassetid://" .. sheet
		end
		local descriptor = {
			Image = sheet,
			RectSize = entry.ImageRectSize,
			RectOffset = entry.ImageRectPosition,
		}
		if entry.Parts and depth < 1 then
			descriptor.Parts = {}
			for _, partName in ipairs(entry.Parts) do
				local part = describe(data, partName, depth + 1)
				if part then
					table.insert(descriptor.Parts, part)
				end
			end
		end
		return descriptor
	end

	local flat = data[name]
	if type(flat) == "string" then
		return { Image = flat }
	end
	return nil
end

-- Returns a descriptor, or nil when the set is disabled / unreachable / has no such icon.
function IconSets.Get(icon)
	local set, name = IconSets.Parse(icon)
	if not set then
		return nil
	end
	local data = IconSets.Load(set)
	if not data then
		return nil
	end
	return describe(data, name, 0)
end

-- Writes a descriptor into an ImageLabel (extra layers become child ImageLabels).
function IconSets.Apply(label, descriptor)
	label.Image = descriptor.Image
	if descriptor.RectSize then
		label.ImageRectSize = descriptor.RectSize
		label.ImageRectOffset = descriptor.RectOffset or Vector2.new(0, 0)
	end
	for _, part in ipairs(descriptor.Parts or {}) do
		local layer = Utility.Create("ImageLabel", {
			Name = "Part",
			Size = UDim2.fromScale(1, 1),
			Parent = label,
		})
		IconSets.Apply(layer, part)
	end
end

IconSets.Commit = COMMIT

return IconSets
