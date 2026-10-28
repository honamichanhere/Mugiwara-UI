--// Popup: floating card drawn over the window (color picker, theme menu).
--// Clicking outside closes it. Only one popup is open at a time.

local Utility = Import("core/Utility")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

-- opts: Width, Padding (14), Gap (10), Dim (default true), AnchorPoint, Position, OnClose
return function(window, opts)
	opts = opts or {}
	local theme = window.Theme

	if window.ActivePopup then
		window.ActivePopup:Close(true)
	end

	local overlay = Create("TextButton", {
		Name = "Popup",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 60,
		Parent = window.Frame,
	})
	local dim = opts.Dim ~= false
	if dim then
		Tween(overlay, { BackgroundTransparency = 0.5 }, 0.25)
	end

	-- the card is anchored where it should grow from, so the UIScale pop is centered on it
	local card = Create("CanvasGroup", {
		Name = "Card",
		AnchorPoint = opts.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = opts.Position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, opts.Width or 280, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(0, 0, 0),
		GroupTransparency = 1,
		Active = true,
		ZIndex = 61,
		Parent = overlay,
	})
	Utility.Corner(card, 14)
	theme:Bind(card, { BackgroundColor3 = "Popup", BackgroundTransparency = "PopupAlpha" })
	-- A UIStroke on the CanvasGroup itself is NOT covered by GroupTransparency,
	-- so its transparency is tweened by hand together with the group.
	local outline = Utility.Stroke(card, Color3.new(1, 1, 1), 1, 1.4)
	Base.Gradient(theme, outline, 45)
	Utility.Padding(card, opts.Padding or 14)
	Utility.List(card, opts.Gap or 10)

	local pop = Create("UIScale", { Scale = 0.94, Parent = card })
	Tween(pop, { Scale = 1 }, 0.35, Enum.EasingStyle.Quint)
	Tween(card, { GroupTransparency = 0 }, 0.25)
	Tween(outline, { Transparency = 0.3 }, 0.25)

	local popup = { Card = card, Overlay = overlay, Closed = false }

	function popup:Close(instant)
		if self.Closed then
			return
		end
		self.Closed = true
		if window.ActivePopup == self then
			window.ActivePopup = nil
		end
		if instant then
			overlay:Destroy()
		else
			-- every part runs for the same time so nothing lingers after the fade ends
			Tween(pop, { Scale = 0.95 }, 0.2)
			Tween(card, { GroupTransparency = 1 }, 0.2)
			Tween(outline, { Transparency = 1 }, 0.2)
			Tween(overlay, { BackgroundTransparency = 1 }, 0.2)
			task.delay(0.22, function()
				overlay:Destroy()
			end)
		end
		Utility.SafeCall(opts.OnClose)
	end

	overlay.MouseButton1Click:Connect(function()
		popup:Close()
	end)

	window.ActivePopup = popup
	return popup
end
