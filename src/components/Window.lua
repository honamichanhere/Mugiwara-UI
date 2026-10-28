--// Window: glass shell with a neon rotating border, topbar, tab sidebar and page area.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Icons = Import("core/Icons")
local Config = Import("core/Config")
local Base = Import("components/Base")
local Tab = Import("components/Tab")
local Dialog = Import("components/Dialog")

local Create, Tween = Utility.Create, Utility.Tween
local WHITE = Color3.new(1, 1, 1)

local TOPBAR = 54
local FOOTER = 56

-- Concentric strokes around the window fake a soft neon glow without any image asset.
local NEON_LAYERS = {
	{ pad = 0, thickness = 3, transparency = 0.5 },
	{ pad = 3, thickness = 7, transparency = 0.8 },
	{ pad = 10, thickness = 14, transparency = 0.92 },
}

local Window = {}
Window.__index = Window

local function toVector(size, fallback)
	if typeof(size) == "UDim2" then
		return Vector2.new(size.X.Offset, size.Y.Offset)
	end
	if typeof(size) == "Vector2" then
		return size
	end
	return fallback
end

local function spin(maid, gradient, seconds)
	local tween = TweenService:Create(
		gradient,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		{ Rotation = gradient.Rotation + 360 }
	)
	tween:Play()
	maid:Give(function()
		tween:Cancel()
	end)
end

function Window.new(library, opts)
	opts = opts or {}
	local theme = library.Theme

	local self = setmetatable({}, Window)
	self.Library = library
	self.Theme = theme
	self.Maid = Utility.Maid.new()
	self.Tabs = {}
	self.Flags = {}
	self.Folder = opts.Folder or "MugiwaraUI"
	self.Title = opts.Title or "Mugiwara UI"
	self.ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
	self.Opened = false
	self.UserScale = 1
	self._tabOrder = 0
	self.OnDestroy = opts.OnDestroy

	local maid = self.Maid
	local size = toVector(opts.Size, Vector2.new(640, 430))
	local minSize = toVector(opts.MinSize, Vector2.new(470, 320))
	local maxSize = toVector(opts.MaxSize, Vector2.new(1000, 760))
	local sidebarWidth = opts.SideBarWidth or (Compat.IsMobile and 150 or 176)

	--// root gui
	local gui = Create("ScreenGui", {
		Name = "MugiwaraUI_" .. string.sub(HttpService:GenerateGUID(false), 1, 8),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10000,
	})
	Compat.Protect(gui)
	gui.Parent = Compat.GetGuiParent()
	maid:Give(gui)
	self.Gui = gui

	local main = Create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	self.Main = main
	self.UIScale = Create("UIScale", { Parent = main })

	-- everything inside `pop` so the open animation scales around the center
	local pop = Create("Frame", { Name = "Pop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = main })
	self.PopScale = Create("UIScale", { Parent = pop })

	--// neon glow
	self.Neon = {}
	if opts.Neon ~= false then
		for _, layer in ipairs(NEON_LAYERS) do
			local ring = Create("Frame", {
				Name = "Glow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, layer.pad * 2, 1, layer.pad * 2),
				BackgroundTransparency = 1,
				Parent = pop,
			})
			Utility.Corner(ring, 16 + layer.pad)
			local stroke = Utility.Stroke(ring, WHITE, layer.transparency, layer.thickness)
			spin(maid, Base.Gradient(theme, stroke, 0, "CycleSeq"), 9)
			table.insert(self.Neon, { Stroke = stroke, Base = layer.transparency })
		end
	end

	--// glass body (CanvasGroup so the whole window fades as one)
	local win = Create("CanvasGroup", {
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		GroupTransparency = 1,
		Parent = pop,
	})
	Utility.Corner(win, 16)
	theme:Bind(win, { BackgroundColor3 = "Background", BackgroundTransparency = "BackgroundAlpha" })
	self.Frame = win

	-- ambient accent wash + glass sheen
	-- one UIGradient per instance: Roblox ignores extra ones, so color + transparency share it
	local wash = Create("Frame", { Name = "Wash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = win })
	Base.Gradient(theme, wash, 35).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.86),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.9),
	})

	local sheen = Create("Frame", { Name = "Sheen", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = win })
	Create("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.92),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(1, 0.97),
		}),
		Parent = sheen,
	})

	--// neon border
	local border = Create("Frame", {
		Name = "Border",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = pop,
	})
	Utility.Corner(border, 16)
	local borderStroke = Utility.Stroke(border, WHITE, 0.3, 1.5)
	spin(maid, Base.Gradient(theme, borderStroke, 0, "CycleSeq"), 9)
	table.insert(self.Neon, { Stroke = borderStroke, Base = 0.3 })

	--// topbar
	local topbar = Create("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, TOPBAR),
		BackgroundTransparency = 1,
		Parent = win,
	})

	local brand = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = WHITE,
		Parent = topbar,
	})
	Utility.Corner(brand, 9)
	local logo = Icons.Resolve(opts.Icon)
	if logo then
		Create("ImageLabel", { Size = UDim2.fromScale(1, 1), Image = logo, Parent = brand })
		brand.BackgroundTransparency = 1
	else
		Base.Gradient(theme, brand, 45)
		local letter = Create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = string.upper(string.sub(self.Title, 1, 1)),
			Font = Enum.Font.GothamBlack,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = brand,
		})
		theme:Bind(letter, { TextColor3 = "OnAccent" })
	end

	local hasSubtitle = opts.Subtitle ~= nil or opts.Author ~= nil
	local titleLabel = Create("TextLabel", {
		Position = UDim2.new(0, 56, 0, hasSubtitle and 9 or 0),
		Size = UDim2.new(1, -160, 0, hasSubtitle and 20 or TOPBAR),
		Text = self.Title,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = topbar,
	})
	Base.Gradient(theme, titleLabel, 0)
	self.TitleLabel = titleLabel

	if hasSubtitle then
		local subtitle = Create("TextLabel", {
			Position = UDim2.new(0, 56, 0, 29),
			Size = UDim2.new(1, -160, 0, 14),
			Text = opts.Subtitle or opts.Author,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = topbar,
		})
		theme:Bind(subtitle, { TextColor3 = "SubText" })
		self.SubtitleLabel = subtitle
	end

	local function controlButton(offset, drawGlyph, tint)
		local button = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			Parent = topbar,
		})
		Utility.Corner(button, 9)
		local glyph = drawGlyph(button, 14, 2)
		Icons.Bind(theme, glyph, "SubText")
		button.MouseEnter:Connect(function()
			Tween(button, { BackgroundTransparency = 0.88 }, 0.15)
			Icons.SetColor(glyph, tint and theme.Tokens[tint] or theme.Tokens.Text)
		end)
		button.MouseLeave:Connect(function()
			Tween(button, { BackgroundTransparency = 1 }, 0.2)
			Icons.SetColor(glyph, theme.Tokens.SubText)
		end)
		return button
	end

	local closeButton = controlButton(-14, Icons.Close, "Danger")
	local minimizeButton = controlButton(-50, Icons.Minus, nil)

	local topLine = Create("Frame", {
		Position = UDim2.fromOffset(0, TOPBAR),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = WHITE,
		Parent = win,
	})
	Base.Gradient(theme, topLine, 0).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 0.9),
	})

	--// sidebar
	local sidebar = Create("Frame", {
		Name = "Sidebar",
		Position = UDim2.fromOffset(0, TOPBAR + 1),
		Size = UDim2.new(0, sidebarWidth, 1, -(TOPBAR + 1)),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Parent = win,
	})
	theme:Bind(sidebar, { BackgroundColor3 = "Sidebar", BackgroundTransparency = "SidebarAlpha" })

	local sideEdge = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = WHITE,
		Parent = sidebar,
	})
	theme:Bind(sideEdge, { BackgroundColor3 = "Stroke", BackgroundTransparency = "StrokeAlpha" })

	local showUser = opts.ShowUser ~= false
	local footerHeight = showUser and FOOTER or 0

	self.TabList = Create("ScrollingFrame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 1, -footerHeight),
		ScrollBarThickness = 0,
		Parent = sidebar,
	})
	Utility.Padding(self.TabList, 10, 10, 8, 9)
	Utility.List(self.TabList, 4)

	if showUser then
		local footer = Create("Frame", {
			Name = "Footer",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, -1, 0, FOOTER),
			BackgroundTransparency = 1,
			Parent = sidebar,
		})
		local footerLine = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = WHITE,
			Parent = footer,
		})
		theme:Bind(footerLine, { BackgroundColor3 = "Stroke", BackgroundTransparency = "StrokeAlpha" })

		local player = Players.LocalPlayer
		local avatar = Create("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.9,
			Parent = footer,
		})
		Utility.Corner(avatar, Utility.Pill)
		local avatarStroke = Utility.Stroke(avatar, WHITE, 0.3, 1.5)
		Base.Gradient(theme, avatarStroke, 45)

		local display = Create("TextLabel", {
			Position = UDim2.fromOffset(52, 10),
			Size = UDim2.new(1, -60, 0, 18),
			Text = player and player.DisplayName or "Player",
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = footer,
		})
		theme:Bind(display, { TextColor3 = "Text" })
		local handle = Create("TextLabel", {
			Position = UDim2.fromOffset(52, 28),
			Size = UDim2.new(1, -60, 0, 16),
			Text = "@" .. (player and player.Name or "player"),
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = footer,
		})
		theme:Bind(handle, { TextColor3 = "SubText" })

		if player then
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(
						player.UserId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size100x100
					)
				end)
				if ok and avatar.Parent then
					avatar.Image = image
				end
			end)
		end
	end

	--// pages
	self.Pages = Create("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(sidebarWidth, TOPBAR + 1),
		Size = UDim2.new(1, -sidebarWidth, 1, -(TOPBAR + 1)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = win,
	})

	--// resize grip
	if opts.Resizable ~= false then
		local grip = Create("TextButton", {
			Name = "Resize",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -3, 1, -3),
			Size = UDim2.fromOffset(22, 22),
			ZIndex = 20,
			Parent = pop,
		})
		for _, spec in ipairs({ { 12, 0 }, { 6, 4 } }) do
			local line = Create("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -4 - spec[2], 1, -4),
				Size = UDim2.fromOffset(spec[1], 2),
				Rotation = -45,
				BackgroundColor3 = WHITE,
				Parent = grip,
			})
			Utility.Corner(line, Utility.Pill)
			theme:Bind(line, { BackgroundColor3 = "Muted" })
		end

		local startSize, startPosition, startPointer
		Utility.DragInput(grip, maid, function(input)
			startSize = main.Size
			startPosition = main.Position
			startPointer = input.Position
		end, function(position)
			if not startPointer then
				return
			end
			local scale = self.UIScale.Scale
			local delta = (position - startPointer) / scale
			local width = Utility.Clamp(startSize.X.Offset + delta.X, minSize.X, maxSize.X)
			local height = Utility.Clamp(startSize.Y.Offset + delta.Y, minSize.Y, maxSize.Y)
			main.Size = UDim2.fromOffset(width, height)
			-- keep the top-left corner anchored while the center-anchored frame grows
			main.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + (width - startSize.X.Offset) * scale / 2,
				startPosition.Y.Scale,
				startPosition.Y.Offset + (height - startSize.Y.Offset) * scale / 2
			)
		end, function()
			startPointer = nil
			self:_fit()
		end)
	end

	--// floating open button
	if opts.OpenButton ~= false then
		local button = Create("TextButton", {
			Name = "OpenButton",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 52),
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			Visible = false,
			Parent = gui,
		})
		Utility.Corner(button, Utility.Pill)
		theme:Bind(button, { BackgroundColor3 = "Popup", BackgroundTransparency = "PopupAlpha" })
		local ring = Utility.Stroke(button, WHITE, 0.15, 2)
		spin(maid, Base.Gradient(theme, ring, 0, "CycleSeq"), 6)
		local halo = Utility.Stroke(button, WHITE, 0.7, 6)
		spin(maid, Base.Gradient(theme, halo, 0, "CycleSeq"), 6)

		local mark = Create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = (opts.OpenButton and opts.OpenButton.Title) or string.upper(string.sub(self.Title, 1, 1)),
			Font = Enum.Font.GothamBlack,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})
		Base.Gradient(theme, mark, 45)

		Utility.Draggable(button, button, maid, nil, function()
			self:Open()
		end)
		self.OpenButton = button
	end

	--// wiring
	Utility.Draggable(topbar, main, maid, function()
		return self.UIScale.Scale
	end)

	maid:Give(closeButton.MouseButton1Click:Connect(function()
		self:RequestClose()
	end))
	maid:Give(minimizeButton.MouseButton1Click:Connect(function()
		self:Close()
	end))

	maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and self.ToggleKey and input.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end))

	maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fit()
	end))
	maid:Give(main:GetPropertyChangedSignal("Size"):Connect(function()
		self:_fit()
	end))

	self.ConfirmClose = opts.ConfirmClose ~= false
	self:_fit()
	self:SetBlur(opts.Blur == true)
	library.Windows[self] = true

	self:Open()
	return self
end

--// Layout ------------------------------------------------------------------------
-- Shrinks the window on small screens (phones) so it never overflows the viewport.
function Window:_fit()
	local area = self.Gui.AbsoluteSize
	if area.X <= 0 or area.Y <= 0 then
		local camera = workspace.CurrentCamera
		area = camera and camera.ViewportSize or Vector2.new(1280, 720)
	end
	local size = self.Main.Size
	local fit = math.min(1, (area.X - 24) / size.X.Offset, (area.Y - 24) / size.Y.Offset)
	self.UIScale.Scale = math.max(fit, 0.4) * self.UserScale
end

function Window:SetScale(scale)
	self.UserScale = Utility.Clamp(scale, 0.5, 1.6)
	self:_fit()
end

function Window:NextTabOrder()
	self._tabOrder = self._tabOrder + 1
	return self._tabOrder
end

--// Visibility --------------------------------------------------------------------
function Window:Open()
	if self.Opened then
		return
	end
	self.Opened = true
	self.Main.Visible = true
	self.PopScale.Scale = 0.9
	Tween(self.PopScale, { Scale = 1 }, 0.45, Enum.EasingStyle.Back)
	Tween(self.Frame, { GroupTransparency = 0 }, 0.3)
	for _, neon in ipairs(self.Neon) do
		Tween(neon.Stroke, { Transparency = neon.Base }, 0.4)
	end

	if self.OpenButton then
		local button = self.OpenButton
		Tween(button, { Size = UDim2.fromOffset(0, 0) }, 0.15)
		task.delay(0.15, function()
			if self.Opened then
				button.Visible = false
			end
		end)
	end
	self:_syncBlur()
end

function Window:Close()
	if not self.Opened then
		return
	end
	self.Opened = false
	Tween(self.PopScale, { Scale = 0.93 }, 0.25)
	Tween(self.Frame, { GroupTransparency = 1 }, 0.22)
	for _, neon in ipairs(self.Neon) do
		Tween(neon.Stroke, { Transparency = 1 }, 0.2)
	end
	task.delay(0.26, function()
		if not self.Opened then
			self.Main.Visible = false
		end
	end)

	if self.OpenButton then
		local button = self.OpenButton
		button.Visible = true
		Tween(button, { Size = UDim2.fromOffset(52, 52) }, 0.4, Enum.EasingStyle.Back)
	end
	self:_syncBlur()
end

function Window:Toggle()
	if self.Opened then
		self:Close()
	else
		self:Open()
	end
end

function Window:RequestClose()
	if not self.ConfirmClose then
		self:Destroy()
		return
	end
	self:Dialog({
		Title = "Close " .. self.Title .. "?",
		Content = "The interface will be destroyed. Run the script again to reopen it.",
		Buttons = {
			{ Title = "Cancel", Style = "Secondary" },
			{
				Title = "Close",
				Style = "Danger",
				Callback = function()
					self:Destroy()
				end,
			},
		},
	})
end

function Window:SetToggleKey(key)
	self.ToggleKey = key
end

--// Blur ----------------------------------------------------------------------------
function Window:SetBlur(enabled, size)
	self.BlurEnabled = enabled
	self.BlurSize = size or 14
	self:_syncBlur()
end

function Window:_syncBlur()
	local existing = Lighting:FindFirstChild("MugiwaraBlur")
	if self.BlurEnabled and self.Opened then
		if not existing then
			existing = Create("BlurEffect", { Name = "MugiwaraBlur", Size = 0, Parent = Lighting })
		end
		Tween(existing, { Size = self.BlurSize }, 0.4)
	elseif existing then
		Tween(existing, { Size = 0 }, 0.3)
	end
end

--// Content ---------------------------------------------------------------------
function Window:Tab(opts)
	local tab = Tab(self, opts)
	table.insert(self.Tabs, tab)
	if not self.CurrentTab then
		self:SelectTab(tab)
	end
	return tab
end

function Window:_removeTab(tab)
	local index = table.find(self.Tabs, tab)
	if index then
		table.remove(self.Tabs, index)
	end
	if self.CurrentTab == tab then
		self.CurrentTab = nil
		if self.Tabs[1] then
			self:SelectTab(self.Tabs[1])
		end
	end
end

function Window:SelectTab(target)
	if type(target) == "number" then
		target = self.Tabs[target]
	end
	if not target or target == self.CurrentTab then
		return
	end
	local previous = self.CurrentTab
	self.CurrentTab = target
	if previous then
		previous:_setSelected(false)
	end
	target:_setSelected(true)
end

-- Small caption inside the sidebar tab list.
function Window:SidebarLabel(text)
	local label = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		Text = "  " .. string.upper(text),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		LayoutOrder = self:NextTabOrder(),
		Parent = self.TabList,
	})
	self.Theme:Bind(label, { TextColor3 = "Muted" })
	return label
end

function Window:SidebarDivider()
	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 9),
		BackgroundTransparency = 1,
		LayoutOrder = self:NextTabOrder(),
		Parent = self.TabList,
	})
	local line = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = WHITE,
		Parent = holder,
	})
	self.Theme:Bind(line, { BackgroundColor3 = "Stroke", BackgroundTransparency = "StrokeAlpha" })
	return holder
end

function Window:SetTitle(text)
	self.Title = text
	self.TitleLabel.Text = text
end

function Window:Dialog(opts)
	return Dialog(self, opts)
end

function Window:Notify(opts)
	return self.Library:Notify(opts)
end

function Window:SetTheme(name)
	return self.Library:SetTheme(name)
end

--// Config --------------------------------------------------------------------------
function Window:SaveConfig(name)
	return Config.Save(self, name)
end

function Window:LoadConfig(name)
	return Config.Load(self, name)
end

function Window:DeleteConfig(name)
	return Config.Delete(self, name)
end

function Window:GetConfigs()
	return Config.List(self)
end

-- Loads the config marked as auto-load (call after building the whole UI).
function Window:LoadAutoConfig()
	local name = Config.GetAutoLoad(self)
	if name then
		return Config.Load(self, name)
	end
	return false
end

-- Drops a ready-made config manager (name box, list, save/load/delete) into a tab or section.
function Window:ConfigSection(parent, opts)
	opts = opts or {}
	local section = parent:Section({ Title = opts.Title or "Configuration", Opened = opts.Opened ~= false })
	local typed, selected = "", Config.GetAutoLoad(self)
	local dropdown
	local autoToggle

	local function report(ok, message, success)
		self:Notify({
			Title = "Config",
			Content = ok and success or message,
			Type = ok and "success" or "error",
			Duration = 3,
		})
	end

	section:Input({
		Title = "Config name",
		Placeholder = "my-config",
		Callback = function(value)
			typed = value
		end,
	})

	dropdown = section:Dropdown({
		Title = "Saved configs",
		Values = Config.List(self),
		Value = selected,
		Searchable = false,
		AllowNone = true,
		Callback = function(value)
			selected = value
		end,
	})

	section:Button({
		Title = "Save",
		Desc = "Saves under the typed name, or overwrites the selected config.",
		Callback = function()
			local name = typed ~= "" and typed or selected
			local ok, message = Config.Save(self, name or "")
			if ok then
				name = Config.Sanitize(name)
				dropdown:Refresh(Config.List(self), false)
				dropdown:Set(name, true)
				selected = name
			end
			report(ok, message, "Saved \"" .. tostring(name) .. "\"")
		end,
	})

	section:Button({
		Title = "Load",
		Callback = function()
			local ok, message = Config.Load(self, selected or "")
			report(ok, message, "Loaded \"" .. tostring(selected) .. "\"")
		end,
	})

	section:Button({
		Title = "Delete",
		Callback = function()
			if not selected then
				report(false, "Select a config first")
				return
			end
			Config.Delete(self, selected)
			dropdown:Refresh(Config.List(self), false)
			report(true, nil, "Deleted \"" .. selected .. "\"")
			selected = nil
		end,
	})

	autoToggle = section:Toggle({
		Title = "Auto load on execute",
		Desc = "Loads the selected config automatically next time (call window:LoadAutoConfig()).",
		Value = Config.GetAutoLoad(self) ~= nil,
		Callback = function(value)
			if value and not selected then
				autoToggle:Set(false, true)
				report(false, "Select a config first")
				return
			end
			Config.SetAutoLoad(self, value and selected or nil)
		end,
	})

	return section
end

--// Lifecycle ------------------------------------------------------------------------
function Window:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Opened = false
	self.BlurEnabled = false
	self:_syncBlur()
	self.Library.Windows[self] = nil
	Utility.SafeCall(self.OnDestroy)
	self.Maid:Clean()
end

return Window
