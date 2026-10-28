--// Theme: design tokens + live re-theming. Every themed instance is registered
--// through Theme:Bind(instance, { Property = "Token" | function(tokens) }).

local RunService = game:GetService("RunService")

local Utility = Import("core/Utility")

local Theme = {}
Theme.__index = Theme

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function linear(stops)
	local count = #stops
	local points = table.create(count)
	for index, color in ipairs(stops) do
		points[index] = ColorSequenceKeypoint.new((index - 1) / (count - 1), color)
	end
	return ColorSequence.new(points)
end

-- A -> B -> C -> B -> A so a rotating gradient loops without a visible seam.
local function cycle(stops)
	local mirrored = table.clone(stops)
	for index = #stops - 1, 1, -1 do
		table.insert(mirrored, stops[index])
	end
	return linear(mirrored)
end

--// Presets ----------------------------------------------------------------------
-- BASE holds every token. It is also the "Normal" theme (orange / red / white / black / yellow);
-- the other presets only list what they change.
local BASE = {
	Background = rgb(8, 8, 13),
	BackgroundAlpha = 0.2,
	Sidebar = rgb(0, 0, 0),
	SidebarAlpha = 0.5,
	Card = rgb(255, 255, 255),
	CardAlpha = 0.94,
	CardHoverAlpha = 0.89,
	Stroke = rgb(255, 255, 255),
	StrokeAlpha = 0.9,
	Field = rgb(0, 0, 0),
	FieldAlpha = 0.45,
	Popup = rgb(14, 14, 20),
	PopupAlpha = 0.08,
	Track = rgb(255, 255, 255),
	TrackAlpha = 0.84,
	Text = rgb(247, 247, 252),
	SubText = rgb(192, 194, 210),
	Muted = rgb(134, 136, 154),
	OnAccent = rgb(28, 12, 8),
	Accent = rgb(255, 150, 40),
	Success = rgb(80, 230, 150),
	Warning = rgb(255, 205, 70),
	Danger = rgb(255, 72, 92),
	Gradient = {
		rgb(255, 246, 222),
		rgb(255, 200, 62),
		rgb(255, 122, 26),
		rgb(255, 52, 82),
	},
}

local DEFAULT = "Gear 5"

-- order shown in menus; themes added later come after these, alphabetically
Theme.Order = { "Gear 5", "Gear 4", "Gear 3", "Normal" }

Theme.Presets = {
	-- Gear 5: white is the identity (Nika's hair, clouds), a little cool silver and soft gold for depth.
	["Gear 5"] = {
		Background = rgb(12, 13, 21),
		BackgroundAlpha = 0.22,
		CardAlpha = 0.91,
		CardHoverAlpha = 0.84,
		StrokeAlpha = 0.84,
		TrackAlpha = 0.8,
		Text = rgb(252, 252, 255),
		SubText = rgb(200, 204, 220),
		Muted = rgb(142, 146, 164),
		OnAccent = rgb(16, 18, 30),
		Accent = rgb(255, 255, 255),
		Gradient = {
			rgb(255, 255, 255),
			rgb(224, 234, 255),
			rgb(255, 247, 226),
			rgb(255, 224, 160),
		},
	},

	-- Gear 4: black and red.
	["Gear 4"] = {
		Background = rgb(5, 5, 8),
		BackgroundAlpha = 0.14,
		SidebarAlpha = 0.6,
		Popup = rgb(10, 8, 10),
		OnAccent = rgb(255, 255, 255),
		Accent = rgb(240, 46, 58),
		Gradient = {
			rgb(255, 116, 116),
			rgb(244, 56, 68),
			rgb(214, 32, 52),
			rgb(180, 20, 44),
		},
	},

	-- Gear 3: yellow into red.
	["Gear 3"] = {
		Background = rgb(20, 12, 4),
		BackgroundAlpha = 0.18,
		Popup = rgb(22, 14, 6),
		OnAccent = rgb(34, 14, 4),
		Accent = rgb(255, 204, 52),
		Gradient = {
			rgb(255, 246, 160),
			rgb(255, 208, 52),
			rgb(255, 142, 34),
			rgb(232, 52, 52),
		},
	},

	-- Normal: orange, red, white, black and yellow (the BASE tokens).
	["Normal"] = {},
}

local function resolve(name)
	local tokens = table.clone(BASE)
	local preset = Theme.Presets[name]
	if preset then
		for key, value in pairs(preset) do
			tokens[key] = value
		end
	end
	tokens.GradientSeq = linear(tokens.Gradient)
	tokens.CycleSeq = cycle(tokens.Gradient)
	return tokens
end

--// Instance ---------------------------------------------------------------------
function Theme.new(name)
	local self = setmetatable({}, Theme)
	self.Name = Theme.Presets[name] and name or DEFAULT
	self.Tokens = resolve(self.Name)
	self.Bindings = {}
	self.Listeners = {}
	return self
end

local FADE_TIME = 0.4

local function canBlend(from, to)
	return from ~= nil and from.Keypoints ~= nil and to.Keypoints ~= nil and #from.Keypoints == #to.Keypoints
end

local function blend(from, to, alpha)
	local a, b = from.Keypoints, to.Keypoints
	local points = table.create(#b)
	for index = 1, #b do
		points[index] = ColorSequenceKeypoint.new(b[index].Time, a[index].Value:Lerp(b[index].Value, alpha))
	end
	return ColorSequence.new(points)
end

-- `jobs` collects gradient swaps so they can cross-fade instead of snapping.
function Theme:_apply(binding, animate, jobs)
	local inst = binding.Instance
	local tweenable = {}
	for property, source in pairs(binding.Map) do
		local value
		if type(source) == "function" then
			value = source(self.Tokens)
		else
			value = self.Tokens[source]
		end
		if value ~= nil then
			local kind = typeof(value)
			if animate and (kind == "Color3" or kind == "number") then
				tweenable[property] = value
			elseif animate and jobs and kind == "ColorSequence" and canBlend(inst[property], value) then
				table.insert(jobs, { Instance = inst, Property = property, From = inst[property], To = value })
			else
				inst[property] = value
			end
		end
	end
	if next(tweenable) then
		Utility.Tween(inst, tweenable, FADE_TIME, Enum.EasingStyle.Quad)
	end
end

function Theme:_blendSequences(jobs)
	if self._blendConnection then
		self._blendConnection:Disconnect()
		self._blendConnection = nil
	end
	if #jobs == 0 then
		return
	end
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local progress = math.min((os.clock() - started) / FADE_TIME, 1)
		local eased = 1 - (1 - progress) ^ 3
		for _, job in ipairs(jobs) do
			job.Instance[job.Property] = progress >= 1 and job.To or blend(job.From, job.To, eased)
		end
		if progress >= 1 then
			connection:Disconnect()
			if self._blendConnection == connection then
				self._blendConnection = nil
			end
		end
	end)
	self._blendConnection = connection
end

function Theme:Bind(inst, map)
	local binding = { Instance = inst, Map = map }
	self.Bindings[binding] = true
	self:_apply(binding, false)
	inst.Destroying:Connect(function()
		self.Bindings[binding] = nil
	end)
	return inst
end

function Theme:Set(name)
	if not Theme.Presets[name] then
		return false
	end
	self.Name = name
	self.Tokens = resolve(name)
	local jobs = {}
	for binding in pairs(self.Bindings) do
		self:_apply(binding, true, jobs)
	end
	self:_blendSequences(jobs)
	for listener in pairs(self.Listeners) do
		task.spawn(listener, self.Tokens, name)
	end
	return true
end

-- For state-dependent colors that can't be a plain binding. Returns a disconnect function.
function Theme:OnChange(listener)
	self.Listeners[listener] = true
	return function()
		self.Listeners[listener] = nil
	end
end

function Theme:Add(name, overrides)
	Theme.Presets[name] = overrides
end

-- Tokens of any theme without applying it (theme menu previews).
function Theme.Preview(name)
	return resolve(name)
end

function Theme:List()
	local names, listed = {}, {}
	for _, name in ipairs(Theme.Order) do
		if Theme.Presets[name] then
			table.insert(names, name)
			listed[name] = true
		end
	end
	local extra = {}
	for name in pairs(Theme.Presets) do
		if not listed[name] then
			table.insert(extra, name)
		end
	end
	table.sort(extra)
	for _, name in ipairs(extra) do
		table.insert(names, name)
	end
	return names
end

return Theme
