-- Minimal Roblox API mock so the bundle can run under plain Lua (fengari).
-- It does NOT render anything; it only lets the smoke test exercise the library logic.

local function typed(name, t)
	return setmetatable(t, { __typeof = name })
end

function typeof(v)
	local kind = type(v)
	if kind ~= "table" then
		return kind
	end
	local mt = getmetatable(v)
	return (mt and mt.__typeof) or "table"
end

--// signals
local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(fn)
		local entry = { fn = fn }
		table.insert(self.handlers, entry)
		return typed("RBXScriptConnection", {
			Connected = true,
			Disconnect = function()
				for index, other in ipairs(self.handlers) do
					if other == entry then
						table.remove(self.handlers, index)
						break
					end
				end
			end,
		})
	end
	function signal:Fire(...)
		local copy = {}
		for index, handler in ipairs(self.handlers) do
			copy[index] = handler
		end
		for _, handler in ipairs(copy) do
			handler.fn(...)
		end
	end
	return typed("RBXScriptSignal", signal)
end

--// data types
local function vectorOp(op)
	return function(a, b)
		local function get(v, key)
			if type(v) == "number" then
				return v
			end
			return v[key] or 0
		end
		return Vector3.new(op(get(a, "X"), get(b, "X")), op(get(a, "Y"), get(b, "Y")), op(get(a, "Z"), get(b, "Z")))
	end
end

local vectorMT = {
	__typeof = "Vector3",
	__add = vectorOp(function(a, b) return a + b end),
	__sub = vectorOp(function(a, b) return a - b end),
	__mul = vectorOp(function(a, b) return a * b end),
	__div = vectorOp(function(a, b) return a / b end),
	__index = function(t, key)
		if key == "Magnitude" then
			return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		end
	end,
}

Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vectorMT) end }
Vector2 = { new = function(x, y) return setmetatable({ X = x or 0, Y = y or 0, Z = 0 }, vectorMT) end }

UDim = { new = function(s, o) return typed("UDim", { Scale = s or 0, Offset = o or 0 }) end }
UDim2 = {
	new = function(xs, xo, ys, yo)
		return typed("UDim2", { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) })
	end,
	fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,
	fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,
}

local color3MT = {
	__typeof = "Color3",
	__index = {
		Lerp = function(a, b, t)
			return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
		end,
		ToHSV = function(c)
			local r, g, b = c.R, c.G, c.B
			local max, min = math.max(r, g, b), math.min(r, g, b)
			local d = max - min
			local h = 0
			if d ~= 0 then
				if max == r then h = ((g - b) / d) % 6
				elseif max == g then h = (b - r) / d + 2
				else h = (r - g) / d + 4 end
				h = h / 6
			end
			return h, max == 0 and 0 or d / max, max
		end,
	},
}
Color3 = {
	new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, color3MT) end,
	fromRGB = function(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		local r, g, b = v, t, p
		i = i % 6
		if i == 1 then r, g, b = q, v, p
		elseif i == 2 then r, g, b = p, v, t
		elseif i == 3 then r, g, b = p, q, v
		elseif i == 4 then r, g, b = t, p, v
		elseif i == 5 then r, g, b = v, p, q end
		return Color3.new(r, g, b)
	end,
}

ColorSequenceKeypoint = { new = function(time, value) return { Time = time, Value = value } end }
ColorSequence = {
	new = function(a, b)
		local points = a
		if type(a) ~= "table" or getmetatable(a) then
			points = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b) }
		end
		return typed("ColorSequence", { Keypoints = points })
	end,
}
NumberSequenceKeypoint = { new = function(time, value) return { Time = time, Value = value } end }
NumberSequence = { new = function(a, b) return typed("NumberSequence", { a = a, b = b }) end }
TweenInfo = { new = function(...) return { ... } end }

Enum = setmetatable({}, {
	__index = function(enum, name)
		local group = setmetatable({}, {
			__index = function(items, item)
				local value = typed("EnumItem", { Name = item, EnumType = name })
				rawset(items, item, value)
				return value
			end,
		})
		rawset(enum, name, group)
		return group
	end,
})

--// table / task extras (Luau)
function table.clone(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = v
	end
	return copy
end
function table.find(t, value)
	for index, v in ipairs(t) do
		if v == value then
			return index
		end
	end
end
function table.create(_) return {} end

local delayed = {}
task = {
	spawn = function(fn, ...) fn(...) end,
	defer = function(fn, ...) fn(...) end,
	delay = function(time, fn, ...)
		table.insert(delayed, { time = time, fn = fn, args = { ... } })
	end,
	wait = function() end,
	-- test helper: run every pending task.delay callback
	flush = function()
		table.sort(delayed, function(a, b) return a.time < b.time end)
		local queue = delayed
		delayed = {}
		for _, item in ipairs(queue) do
			item.fn(table.unpack(item.args))
		end
	end,
}

WARNINGS = {}
function warn(...)
	local parts = {}
	for _, v in ipairs({ ... }) do
		table.insert(parts, tostring(v))
	end
	table.insert(WARNINGS, table.concat(parts, " "))
end

--// Instance
local EVENTS = {
	MouseEnter = true, MouseLeave = true, MouseButton1Click = true, MouseButton1Down = true,
	InputBegan = true, InputChanged = true, InputEnded = true, Changed = true, Destroying = true,
	Focused = true, FocusLost = true, ChildAdded = true, ChildRemoved = true, AncestryChanged = true,
}
local GUI_CLASSES = {
	Frame = true, TextLabel = true, TextButton = true, TextBox = true, ImageLabel = true,
	ImageButton = true, ScrollingFrame = true, CanvasGroup = true,
}
local DEFAULTS = {
	AbsoluteSize = function() return Vector2.new(1280, 720) end,
	AbsolutePosition = function() return Vector2.new(0, 0) end,
	AbsoluteContentSize = function() return Vector2.new(100, 100) end,
	Size = function() return UDim2.new(0, 0, 0, 0) end,
	Position = function() return UDim2.new(0, 0, 0, 0) end,
	Visible = true,
	Text = "",
	Rotation = 0,
}

local Methods = {}
local instanceMT = { __typeof = "Instance" }

local function setParent(inst, parent)
	local props = rawget(inst, "_props")
	local old = props.Parent
	if old then
		local siblings = rawget(old, "_children")
		for index, child in ipairs(siblings) do
			if child == inst then
				table.remove(siblings, index)
				break
			end
		end
	end
	props.Parent = parent
	if parent then
		table.insert(rawget(parent, "_children"), inst)
	end
end

function Methods.IsA(self, name)
	local class = rawget(self, "_class")
	return class == name or (name == "GuiObject" and GUI_CLASSES[class] == true)
end
function Methods.GetChildren(self)
	local copy = {}
	for index, child in ipairs(rawget(self, "_children")) do
		copy[index] = child
	end
	return copy
end
function Methods.FindFirstChild(self, name)
	for _, child in ipairs(rawget(self, "_children")) do
		if child.Name == name then
			return child
		end
	end
end
function Methods.FindFirstChildOfClass(self, class)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_class") == class then
			return child
		end
	end
end
function Methods.WaitForChild(self, name)
	return Methods.FindFirstChild(self, name)
end
function Methods.GetPropertyChangedSignal(self, name)
	local signals = rawget(self, "_propSignals")
	if not signals[name] then
		signals[name] = newSignal()
	end
	return signals[name]
end
function Methods.Destroy(self)
	if rawget(self, "_destroyed") then
		return
	end
	rawset(self, "_destroyed", true)
	for _, child in ipairs(Methods.GetChildren(self)) do
		Methods.Destroy(child)
	end
	self.Destroying:Fire()
	setParent(self, nil)
end

instanceMT.__index = function(self, key)
	local value = rawget(self, "_props")[key]
	if value ~= nil then
		return value
	end
	if Methods[key] then
		return Methods[key]
	end
	if EVENTS[key] then
		local signal = newSignal()
		rawget(self, "_props")[key] = signal
		return signal
	end
	local default = DEFAULTS[key]
	if type(default) == "function" then
		return default()
	end
	if key == "Name" then
		return rawget(self, "_class")
	end
	return default
end

instanceMT.__newindex = function(self, key, value)
	if key == "Parent" then
		setParent(self, value)
		return
	end
	rawget(self, "_props")[key] = value
	local signal = rawget(self, "_propSignals")[key]
	if signal then
		signal:Fire()
	end
end

Instance = {
	new = function(class)
		return setmetatable({ _class = class, _props = {}, _children = {}, _propSignals = {} }, instanceMT)
	end,
}

--// services
local playerGui = Instance.new("Folder")
local localPlayer = {
	Name = "Tester",
	DisplayName = "Tester",
	UserId = 1,
	FindFirstChildOfClass = function() return playerGui end,
	WaitForChild = function() return playerGui end,
}

local jsonStore, jsonCount = {}, 0

local services = {
	Players = {
		LocalPlayer = localPlayer,
		GetUserThumbnailAsync = function() return "rbxasset://avatar" end,
	},
	UserInputService = {
		TouchEnabled = false,
		KeyboardEnabled = true,
		InputBegan = newSignal(),
		InputChanged = newSignal(),
		InputEnded = newSignal(),
	},
	TweenService = {
		Create = function(_, inst, _, goal)
			return {
				Play = function()
					for key, value in pairs(goal) do
						inst[key] = value
					end
				end,
				Cancel = function() end,
			}
		end,
	},
	HttpService = {
		GenerateGUID = function() return "abcdef12-0000-0000-0000-000000000000" end,
		JSONEncode = function(_, value)
			jsonCount = jsonCount + 1
			jsonStore["mock:" .. jsonCount] = value
			return "mock:" .. jsonCount
		end,
		JSONDecode = function(_, text)
			return assert(jsonStore[text], "bad json")
		end,
	},
	TextService = {
		GetTextSize = function(_, text) return Vector2.new(#text * 6, 14) end,
	},
	RunService = { Heartbeat = newSignal() },
	MarketplaceService = {
		GetProductInfo = function(_, id)
			return { AssetTypeId = MOCK_ASSET_TYPES[id] }
		end,
	},
	Lighting = Instance.new("Folder"),
	CoreGui = Instance.new("Folder"),
}

game = {
	GetService = function(_, name)
		return assert(services[name], "unmocked service " .. name)
	end,
}
workspace = { CurrentCamera = { ViewportSize = Vector2.new(1280, 720) } }

MOCK_ASSET_TYPES = {}
MOCK = { services = services, playerGui = playerGui, localPlayer = localPlayer }

--// in-memory executor file api
local files, folders = {}, {}
writefile = function(path, content) files[path] = content end
readfile = function(path) return assert(files[path], "no such file " .. path) end
isfile = function(path) return files[path] ~= nil end
makefolder = function(path) folders[path] = true end
isfolder = function(path) return folders[path] == true end
delfile = function(path) files[path] = nil end
MOCK.files = files

-- executors expose these; the examples load the bundle through them
loadstring = function(source)
	return load(source, "=chunk")
end
game.HttpGet = function()
	return DIST_SOURCE
end

-- a Decal asset wraps the real image; the library reads the image id from it
game.GetObjects = function()
	local decal = Instance.new("Decal")
	decal.Texture = "http://www.roblox.com/asset/?id=999"
	return { decal }
end
