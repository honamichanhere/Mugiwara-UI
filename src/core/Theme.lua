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
-- Gear 5: black glass, Nika white -> sun gold -> drum orange -> Gomu red.
local Gear5 = {
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

Theme.Presets = {
	Gear5 = Gear5,
	Sunrise = {
		Background = rgb(18, 9, 6),
		BackgroundAlpha = 0.16,
		Accent = rgb(255, 130, 40),
		Gradient = { rgb(255, 214, 102), rgb(255, 150, 40), rgb(255, 86, 40), rgb(214, 32, 60) },
	},
	Joyboy = {
		Background = rgb(16, 16, 24),
		BackgroundAlpha = 0.26,
		CardAlpha = 0.91,
		CardHoverAlpha = 0.85,
		Accent = rgb(255, 214, 120),
		Gradient = { rgb(255, 255, 255), rgb(255, 238, 176), rgb(255, 200, 80), rgb(255, 156, 52) },
	},
	Gomu = {
		Background = rgb(14, 6, 9),
		BackgroundAlpha = 0.18,
		Accent = rgb(255, 80, 92),
		Gradient = { rgb(255, 138, 112), rgb(255, 64, 76), rgb(214, 22, 56), rgb(255, 168, 64) },
	},
}

local function resolve(name)
	local tokens = table.clone(Gear5)
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
	self.Name = Theme.Presets[name] and name or "Gear5"
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
	local names = {}
	for name in pairs(Theme.Presets) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return Theme
