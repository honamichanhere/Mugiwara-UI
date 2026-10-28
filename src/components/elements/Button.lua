local Utility = Import("core/Utility")
local Icons = Import("core/Icons")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local el = Base.Card(container, opts, 34, 26)

	-- centered anchor: the press animation shrinks toward the middle, not the top-left
	local pill = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = el.Right,
	})
	Utility.Corner(pill, 8)
	Base.Gradient(theme, pill, 0)

	local arrow = Icons.Chevron(pill, 14, 2)
	arrow.Rotation = -90
	Icons.Bind(theme, arrow, "OnAccent")

	function el:Fire()
		Tween(pill, { Size = UDim2.new(1, -6, 1, -6) }, 0.08)
		task.delay(0.09, function()
			if pill.Parent then
				Tween(pill, { Size = UDim2.fromScale(1, 1) }, 0.35, Enum.EasingStyle.Back)
			end
		end)
		Utility.SafeCall(opts.Callback)
	end

	function el:SetCallback(fn)
		opts.Callback = fn
	end

	el.Maid:Give(el.Top.MouseButton1Click:Connect(function()
		if not el.Locked then
			el:Fire()
		end
	end))

	return Base.Finish(container, el, opts, "Button")
end
