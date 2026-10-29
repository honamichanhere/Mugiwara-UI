--// Shell: a centered glass card with the Mugiwara neon look, its own ScreenGui and open / close
--// animations. The Key UI and the Loading UI are built on it (the main Window has its own chrome).

local HttpService = game:GetService("HttpService")

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Neon = Import("components/Neon")

local Create, Tween = Utility.Create, Utility.Tween

local RADIUS = 16

local Shell = {}
Shell.__index = Shell

-- opts: Name, Size (Vector2), Backdrop (transparency to dim to, nil = none), InstantBackdrop,
--       IgnoreGuiInset, MinScale, MaxScale, Glow (default true), MobileScale (see Compat.AutoScale)
function Shell.new(library, opts)
	local theme = library.Theme
	local self = setmetatable({}, Shell)
	self.Library = library
	self.Theme = theme
	self.Maid = Utility.Maid.new()
	self.DesignSize = opts.Size
	self.MinScale = opts.MinScale or 0.4
	self.MaxScale = opts.MaxScale or 1
	self.BackdropTarget = opts.Backdrop
	self.MobileScale = opts.MobileScale
	self.Neon = {}
	local maid = self.Maid

	local gui = Create("ScreenGui", {
		Name = "MugiwaraUI_" .. (opts.Name or "Shell") .. "_" .. string.sub(HttpService:GenerateGUID(false), 1, 8),
		ResetOnSpawn = false,
		IgnoreGuiInset = opts.IgnoreGuiInset == true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10002,
	})
	Compat.Protect(gui)
	gui.Parent = Compat.GetGuiParent()
	maid:Give(gui)
	self.Gui = gui

	if opts.Backdrop then
		self.Backdrop = Create("Frame", {
			Name = "Backdrop",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(8, 4, 2),
			BackgroundTransparency = opts.InstantBackdrop and opts.Backdrop or 1,
			Parent = gui,
		})
	end

	local main = Create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(self.DesignSize.X, self.DesignSize.Y),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	self.Main = main
	self.UIScale = Create("UIScale", { Parent = main })

	-- centered anchor: UIScale scales around the anchor point, so the pop animation grows from the middle
	local pop = Create("Frame", {
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = main,
	})
	self.Pop = pop
	self.PopScale = Create("UIScale", { Scale = 0.88, Parent = pop })

	if opts.Glow ~= false then
		self.Neon = Neon.Glow(pop, theme, maid, RADIUS)
	end

	local card = Create("CanvasGroup", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		GroupTransparency = 1,
		Parent = pop,
	})
	Utility.Corner(card, RADIUS)
	theme:Bind(card, { BackgroundColor3 = "Popup", BackgroundTransparency = "PopupAlpha" })
	Neon.Glass(card, theme)
	self.Card = card

	table.insert(self.Neon, Neon.Border(pop, theme, maid, RADIUS, 5))
	for _, entry in ipairs(self.Neon) do
		entry.Stroke.Transparency = 1
	end

	maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fit()
	end))
	self:_fit()
	return self
end

function Shell:_fit()
	local area = self.Gui.AbsoluteSize
	if area.X <= 0 or area.Y <= 0 then
		local camera = workspace.CurrentCamera
		area = camera and camera.ViewportSize or Vector2.new(1280, 720)
	end
	local fit = math.min((area.X - 32) / self.DesignSize.X, (area.Y - 32) / self.DesignSize.Y)
	self.UIScale.Scale = Utility.Clamp(fit, self.MinScale, self.MaxScale) * Compat.AutoScale(area, self.MobileScale)
end

function Shell:Show()
	if self.Backdrop and self.Backdrop.BackgroundTransparency > self.BackdropTarget then
		Tween(self.Backdrop, { BackgroundTransparency = self.BackdropTarget }, 0.5)
	end
	Tween(self.PopScale, { Scale = 1 }, 0.7, Enum.EasingStyle.Back)
	Tween(self.Card, { GroupTransparency = 0 }, 0.5)
	for _, entry in ipairs(self.Neon) do
		Tween(entry.Stroke, { Transparency = entry.Base }, 0.5)
	end
end

-- Plays the exit animation, then destroys everything and calls onDone.
function Shell:Hide(onDone)
	if self.Hiding then
		return
	end
	self.Hiding = true
	Tween(self.PopScale, { Scale = 0.88 }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	Tween(self.Card, { GroupTransparency = 1 }, 0.35)
	for _, entry in ipairs(self.Neon) do
		Tween(entry.Stroke, { Transparency = 1 }, 0.3)
	end
	if self.Backdrop then
		Tween(self.Backdrop, { BackgroundTransparency = 1 }, 0.4)
	end
	task.delay(0.45, function()
		self:Destroy()
		if onDone then
			onDone()
		end
	end)
end

function Shell:Destroy()
	self.Maid:Clean()
end

return Shell
