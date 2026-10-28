local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local el = Base.Card(container, opts, 44, 24)

	local track = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = el.Right,
	})
	Utility.Corner(track, Utility.Pill)
	theme:Bind(track, { BackgroundColor3 = "Track", BackgroundTransparency = "TrackAlpha" })

	local fill = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Parent = track,
	})
	Utility.Corner(fill, Utility.Pill)
	Base.Gradient(theme, fill, 0)

	-- neon halo around the track while on
	local halo = Utility.Stroke(fill, Color3.new(1, 1, 1), 1, 3)
	Base.Gradient(theme, halo, 0)

	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	})
	Utility.Corner(knob, Utility.Pill)

	local function render(value, instant)
		local goals = {
			{ fill, { BackgroundTransparency = value and 0 or 1 } },
			{ halo, { Transparency = value and 0.5 or 1 } },
			{ knob, { Position = UDim2.new(0, value and 23 or 3, 0.5, 0) } },
		}
		for _, entry in ipairs(goals) do
			if instant then
				for property, goal in pairs(entry[2]) do
					entry[1][property] = goal
				end
			else
				Tween(entry[1], entry[2], 0.22, Enum.EasingStyle.Quint)
			end
		end
	end

	el.Value = (opts.Value or opts.Default) == true
	render(el.Value, true)

	function el:Set(value, silent)
		value = value and true or false
		self.Value = value
		render(value, false)
		if not silent then
			Utility.SafeCall(opts.Callback, value)
		end
	end

	function el:Toggle()
		self:Set(not self.Value)
	end

	function el:SetCallback(fn)
		opts.Callback = fn
	end

	el.Serialize = function()
		return el.Value
	end
	el.Deserialize = function(value)
		el:Set(value == true)
	end

	el.Maid:Give(el.Top.MouseButton1Click:Connect(function()
		if not el.Locked then
			el:Toggle()
		end
	end))

	return Base.Finish(container, el, opts, "Toggle")
end
