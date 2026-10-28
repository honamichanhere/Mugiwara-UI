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
local Theme = Import("core/Theme")
local Base = Import("components/Base")
local Tab = Import("components/Tab")
local TabSection = Import("components/TabSection")
local Dialog = Import("components/Dialog")
local Popup = Import("components/Popup")

local Create, Tween = Utility.Create, Utility.Tween
local WHITE = Color3.new(1, 1, 1)

local TOPBAR = 54
local FOOTER = 56
local MARGIN = 24 -- breathing room kept around a maximized window
local MORPH_TIME = 0.45

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

-- opts: Title, Subtitle, Version, Icon, Size, MinSize, MaxSize, Resizable, Folder, ToggleKey, Blur,
--       Neon, OpenButton, ConfirmClose, ShowUser, SideBarWidth, ThemeSwitcher, Background
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
	self.Maximized = false
	self.UserScale = 1
	self._tabOrder = 0
	self.OnDestroy = opts.OnDestroy

	local maid = self.Maid
	local size = toVector(opts.Size, Vector2.new(640, 430))
	local minSize = toVector(opts.MinSize, Vector2.new(480, 340))
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

	-- Everything lives in `pop`. It is anchored at its center: UIScale scales around the
	-- anchor point, so a top-left anchor made open / close / minimize grow from the corner.
	local pop = Create("Frame", {
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = main,
	})
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

	-- optional wallpaper (Window:SetBackground) with a dark scrim to keep text readable
	self.BackgroundImage = Create("ImageLabel", {
		Name = "Wallpaper",
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Crop,
		ImageTransparency = 1,
		Visible = false,
		Parent = win,
	})
	self.BackgroundScrim = Create("Frame", {
		Name = "Scrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = win,
	})

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
	-- Icon: asset id (full color logo) or an icon-set name such as "lucide:sun" (tinted on the gradient badge)
	local logo, monochrome
	if opts.Icon then
		local slot = Create("Frame", {
			Name = "Logo",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = brand,
		})
		logo, monochrome = Icons.Create(opts.Icon, slot)
		if not logo then
			slot:Destroy()
		elseif monochrome then
			slot.Size = UDim2.fromOffset(18, 18)
			Base.Gradient(theme, brand, 45)
			Icons.BindImage(theme, logo, "OnAccent")
		else
			brand.BackgroundTransparency = 1
		end
	end
	if not logo then
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
	local titleRow = Create("Frame", {
		Name = "TitleRow",
		Position = UDim2.new(0, 56, 0, hasSubtitle and 8 or 0),
		Size = UDim2.new(1, -240, 0, hasSubtitle and 22 or TOPBAR),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = topbar,
	})
	Utility.List(titleRow, 8, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)

	local titleLabel = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = self.Title,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		LayoutOrder = 1,
		Parent = titleRow,
	})
	Base.Gradient(theme, titleLabel, 0)
	self.TitleLabel = titleLabel

	-- version badge next to the title
	local versionPill = Create("Frame", {
		Name = "Version",
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		LayoutOrder = 2,
		Visible = false,
		Parent = titleRow,
	})
	Utility.Corner(versionPill, Utility.Pill)
	Utility.Padding(versionPill, 0, 0, 8, 8)
	Base.Gradient(theme, versionPill, 0)
	local versionLabel = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = versionPill,
	})
	theme:Bind(versionLabel, { TextColor3 = "OnAccent" })
	self.VersionPill = versionPill
	self.VersionLabel = versionLabel

	if hasSubtitle then
		local subtitle = Create("TextLabel", {
			Position = UDim2.new(0, 56, 0, 30),
			Size = UDim2.new(1, -240, 0, 14),
			Text = opts.Subtitle or opts.Author,
			Font = Utility.Fonts.Desc,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = topbar,
		})
		theme:Bind(subtitle, { TextColor3 = "SubText" })
		self.SubtitleLabel = subtitle
	end

	local function hoverFeedback(button, glyphs, tint)
		button.MouseEnter:Connect(function()
			Tween(button, { BackgroundTransparency = 0.88 }, 0.15)
			for _, glyph in ipairs(glyphs) do
				Icons.SetColor(glyph, tint and theme.Tokens[tint] or theme.Tokens.Text)
			end
		end)
		button.MouseLeave:Connect(function()
			Tween(button, { BackgroundTransparency = 1 }, 0.2)
			for _, glyph in ipairs(glyphs) do
				Icons.SetColor(glyph, theme.Tokens.SubText)
			end
		end)
	end

	-- 34x34 hit area; glyphs are centered inside it
	local function controlButton(offset)
		local button = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			Parent = topbar,
		})
		Utility.Corner(button, 9)
		return button
	end

	local closeButton = controlButton(-12)
	local closeGlyph = Icons.Bind(theme, Icons.Close(closeButton, 20, 2), "SubText")
	hoverFeedback(closeButton, { closeGlyph }, "Danger")

	local maximizeButton = controlButton(-50)
	local squareGlyph = Icons.Bind(theme, Icons.Square(maximizeButton, 20, 2), "SubText")
	local restoreGlyph = Icons.Bind(theme, Icons.Restore(maximizeButton, 20, 2), "SubText")
	restoreGlyph.Visible = false
	hoverFeedback(maximizeButton, { squareGlyph, restoreGlyph }, nil)
	self._squareGlyph, self._restoreGlyph = squareGlyph, restoreGlyph

	local minimizeButton = controlButton(-88)
	local minusGlyph = Icons.Bind(theme, Icons.Minus(minimizeButton, 20, 2), "SubText")
	hoverFeedback(minimizeButton, { minusGlyph }, nil)

	local themeButton
	if opts.ThemeSwitcher ~= false then
		themeButton = controlButton(-126)
		-- ring + inner dot, sized to match the other 20px glyphs
		local ring = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			Parent = themeButton,
		})
		Utility.Corner(ring, Utility.Pill)
		local ringStroke = Utility.Stroke(ring, WHITE, 0.2, 2)
		Base.Gradient(theme, ringStroke, 45)
		local dot = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = WHITE,
			Parent = ring,
		})
		Utility.Corner(dot, Utility.Pill)
		Base.Gradient(theme, dot, 45)
		themeButton.MouseEnter:Connect(function()
			Tween(themeButton, { BackgroundTransparency = 0.88 }, 0.15)
			Tween(dot, { Size = UDim2.fromOffset(13, 13) }, 0.25, Enum.EasingStyle.Back)
		end)
		themeButton.MouseLeave:Connect(function()
			Tween(themeButton, { BackgroundTransparency = 1 }, 0.2)
			Tween(dot, { Size = UDim2.fromOffset(10, 10) }, 0.2)
		end)
	end

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
			Font = Utility.Fonts.Desc,
			TextSize = 12,
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
		self.Grip = grip

		local startSize, startPosition, startPointer
		Utility.DragInput(grip, maid, function(input)
			startSize = main.Size
			startPosition = main.Position
			startPointer = input.Position
		end, function(position)
			if not startPointer or self.Maximized then
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
	end, nil, function()
		return not self.Maximized
	end)

	maid:Give(closeButton.MouseButton1Click:Connect(function()
		self:RequestClose()
	end))
	maid:Give(minimizeButton.MouseButton1Click:Connect(function()
		self:Close()
	end))
	maid:Give(maximizeButton.MouseButton1Click:Connect(function()
		self:ToggleMaximized()
	end))
	if themeButton then
		maid:Give(themeButton.MouseButton1Click:Connect(function()
			self:OpenThemeMenu()
		end))
	end

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
	self:SetVersion(opts.Version)
	if type(opts.Background) == "table" then
		self:SetBackground(opts.Background.Image, opts.Background.Transparency, opts.Background.Dim)
	elseif opts.Background then
		self:SetBackground(opts.Background)
	end
	self:_fit()
	self:SetBlur(opts.Blur == true)
	library.Windows[self] = true

	self:Open()
	return self
end

--// Layout ------------------------------------------------------------------------
function Window:_area()
	local area = self.Gui.AbsoluteSize
	if area.X <= 0 or area.Y <= 0 then
		local camera = workspace.CurrentCamera
		area = camera and camera.ViewportSize or Vector2.new(1280, 720)
	end
	return area
end

-- Shrinks the window on small screens (phones) so it never overflows the viewport.
function Window:_fitScale(size)
	local area = self:_area()
	local fit = math.min(1, (area.X - MARGIN) / size.X, (area.Y - MARGIN) / size.Y)
	return math.max(fit, 0.4) * self.UserScale
end

function Window:_maximizedSize()
	local area = self:_area()
	return UDim2.fromOffset((area.X - MARGIN) / self.UserScale, (area.Y - MARGIN) / self.UserScale)
end

function Window:_fit()
	if self._morphing then
		return
	end
	if self.Maximized then
		self.UIScale.Scale = self.UserScale
		self.Main.Size = self:_maximizedSize()
		return
	end
	local size = self.Main.Size
	self.UIScale.Scale = self:_fitScale(Vector2.new(size.X.Offset, size.Y.Offset))
end

function Window:SetScale(scale)
	self.UserScale = Utility.Clamp(scale, 0.5, 1.6)
	self:_fit()
end

function Window:NextTabOrder()
	self._tabOrder = self._tabOrder + 1
	return self._tabOrder
end

--// Maximize ------------------------------------------------------------------------
function Window:SetMaximized(state)
	state = state and true or false
	if state == self.Maximized then
		return
	end
	local main = self.Main
	self._morphing = true -- freeze _fit while the size / scale tweens run

	if state then
		self._restore = { Size = main.Size, Position = main.Position }
		self.Maximized = true
		Tween(main, { Size = self:_maximizedSize(), Position = UDim2.fromScale(0.5, 0.5) }, MORPH_TIME)
		Tween(self.UIScale, { Scale = self.UserScale }, MORPH_TIME)
	else
		self.Maximized = false
		local restore = self._restore or { Size = UDim2.fromOffset(640, 430), Position = UDim2.fromScale(0.5, 0.5) }
		Tween(main, { Size = restore.Size, Position = restore.Position }, MORPH_TIME)
		Tween(
			self.UIScale,
			{ Scale = self:_fitScale(Vector2.new(restore.Size.X.Offset, restore.Size.Y.Offset)) },
			MORPH_TIME
		)
	end

	self._squareGlyph.Visible = not state
	self._restoreGlyph.Visible = state
	if self.Grip then
		self.Grip.Visible = not state
	end

	task.delay(MORPH_TIME + 0.05, function()
		self._morphing = false
		if not self.Destroyed then
			self:_fit()
		end
	end)
end

function Window:ToggleMaximized()
	self:SetMaximized(not self.Maximized)
end

--// Visibility --------------------------------------------------------------------
function Window:Open()
	if self.Opened then
		return
	end
	self.Opened = true
	self.Main.Visible = true
	self.PopScale.Scale = 0.9
	Tween(self.PopScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Quint)
	Tween(self.Frame, { GroupTransparency = 0 }, 0.3)
	for _, neon in ipairs(self.Neon) do
		Tween(neon.Stroke, { Transparency = neon.Base }, 0.4)
	end

	if self.OpenButton then
		local button = self.OpenButton
		Tween(button, { Size = UDim2.fromOffset(0, 0) }, 0.18)
		task.delay(0.18, function()
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
	if self.ActivePopup then
		self.ActivePopup:Close(true)
	end
	Tween(self.PopScale, { Scale = 0.92 }, 0.3, Enum.EasingStyle.Quint)
	Tween(self.Frame, { GroupTransparency = 1 }, 0.24)
	for _, neon in ipairs(self.Neon) do
		Tween(neon.Stroke, { Transparency = 1 }, 0.2)
	end
	task.delay(0.3, function()
		if not self.Opened then
			self.Main.Visible = false
		end
	end)

	if self.OpenButton then
		local button = self.OpenButton
		button.Visible = true
		Tween(button, { Size = UDim2.fromOffset(52, 52) }, 0.5, Enum.EasingStyle.Back)
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

--// Background image ------------------------------------------------------------------
-- image: asset id, "rbxassetid://...", or an http(s) URL (needs request + writefile + getcustomasset).
-- transparency: 0-1, higher = fainter (default 0.55). dim: 0-1 dark scrim over the image (default 0.45).
-- Pass nil / "" to remove it.
function Window:SetBackground(image, transparency, dim)
	local label, scrim = self.BackgroundImage, self.BackgroundScrim
	if image == nil or image == "" then
		label.Visible = false
		scrim.Visible = false
		return
	end
	local target = transparency or 0.55
	local shade = dim or 0.45
	task.spawn(function()
		local asset, reason = Compat.ResolveImage(image, self.Folder)
		if not label.Parent then
			return
		end
		if not asset then
			self:Notify({ Title = "Wallpaper", Content = reason or "Could not load the image.", Type = "warning", Duration = 6 })
			return
		end
		label.Image = asset
		label.Visible = true
		scrim.Visible = true
		Tween(label, { ImageTransparency = target }, 0.6)
		Tween(scrim, { BackgroundTransparency = 1 - shade }, 0.6)

		if Compat.ImageLoaded(label) == false then
			self:Notify({
				Title = "Wallpaper",
				Content = "Roblox could not load this image. It may be private, moderated, or not an Image asset.",
				Type = "warning",
				Duration = 7,
			})
		end
	end)
end

--// Title / version ---------------------------------------------------------------------
function Window:SetTitle(text)
	self.Title = text
	self.TitleLabel.Text = text
end

function Window:SetVersion(text)
	if text == nil or text == "" then
		self.VersionPill.Visible = false
		return
	end
	self.VersionLabel.Text = tostring(text)
	self.VersionPill.Visible = true
end

--// Theme menu ---------------------------------------------------------------------------
function Window:OpenThemeMenu()
	local library = self.Library
	local theme = self.Theme
	local popup = Popup(self, {
		Width = 210,
		Dim = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, TOPBAR - 2),
	})
	local card = popup.Card
	card:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 4)

	local caption = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		Text = "THEME",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		LayoutOrder = 0,
		Parent = card,
	})
	theme:Bind(caption, { TextColor3 = "Muted" })

	for index, name in ipairs(library:GetThemes()) do
		local selected = name == library:GetTheme()
		local row = Create("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = selected and 0.86 or 1,
			LayoutOrder = index,
			Parent = card,
		})
		Utility.Corner(row, 9)
		row.MouseEnter:Connect(function()
			if not selected then
				Tween(row, { BackgroundTransparency = 0.93 }, 0.15)
			end
		end)
		row.MouseLeave:Connect(function()
			if not selected then
				Tween(row, { BackgroundTransparency = 1 }, 0.2)
			end
		end)

		local swatch = Create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(38, 12),
			BackgroundColor3 = WHITE,
			Parent = row,
		})
		Utility.Corner(swatch, Utility.Pill)
		Create("UIGradient", { Color = Theme.Preview(name).GradientSeq, Parent = swatch })

		local label = Create("TextLabel", {
			Position = UDim2.fromOffset(58, 0),
			Size = UDim2.new(1, -86, 1, 0),
			Text = name,
			Font = selected and Enum.Font.GothamBold or Utility.Fonts.Label,
			TextSize = 14,
			Parent = row,
		})
		theme:Bind(label, { TextColor3 = "Text" })

		if selected then
			local check = Icons.Check(row, 14, 2)
			check.AnchorPoint = Vector2.new(0.5, 0.5)
			check.Position = UDim2.new(1, -18, 0.5, 0)
			Icons.Bind(theme, check, "Text")
		end

		row.MouseButton1Click:Connect(function()
			library:SetTheme(name)
			popup:Close()
		end)
	end
	return popup
end

--// Content ---------------------------------------------------------------------
function Window:_createTab(opts, parent)
	local tab = Tab(self, opts, parent)
	table.insert(self.Tabs, tab)
	if not self.CurrentTab then
		self:SelectTab(tab)
	end
	return tab
end

function Window:Tab(opts)
	return self:_createTab(opts, nil)
end

-- Titled, collapsible group of tabs in the sidebar: Window:TabSection({ Title }):Tab({ ... })
function Window:TabSection(opts)
	return TabSection(self, opts)
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
		TextSize = 11,
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
