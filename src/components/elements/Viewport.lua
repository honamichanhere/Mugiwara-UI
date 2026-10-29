--// Viewport: a card with a 3D preview (a model, your character, an asset, a mesh) that you can turn by dragging.

local Players = game:GetService("Players")

local Utility = Import("core/Utility")
local ViewportView = Import("core/ViewportView")
local Base = Import("components/Base")

local Create = Utility.Create

-- opts: Title, Desc, Icon, Height (180), plus ONE source:
--         Model = Instance, Character = true | Player, Asset = id, UserId = id, Mesh = { MeshId, TextureId, Size, Scale },
--         or Source = any of those (see core/ViewportView.lua)
--       look: Yaw (-25), Pitch (12), Zoom (1), FieldOfView (35), Rotate (true = 25 deg/s, or a number), Draggable (true),
--             Ambient, LightColor, LightDirection
--       Background: nil = the theme's field color, false = transparent, Color3 = that color
--       Follow (default true): a Character source reloads when you respawn
-- el:SetModel / SetAsset / SetCharacter / SetUserId / SetMesh / SetSource / Clear / Refresh,
-- el:SetYaw / SetPitch / SetZoom / SetRotate(speed | false), el.View (the ViewportView), el:GetViewport()
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local el = Base.Card(container, opts)

	local hasHeader = el.Top.Visible
	local extra = Base.Extra(el, opts.Height or 180, hasHeader and 10 or 0)

	local stageFrame = Create("Frame", {
		Name = "Stage",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ClipsDescendants = true,
		Parent = extra,
	})
	Utility.Corner(stageFrame, 8)
	if opts.Background == false then
		stageFrame.BackgroundTransparency = 1
	elseif typeof(opts.Background) == "Color3" then
		stageFrame.BackgroundColor3 = opts.Background
	else
		theme:Bind(stageFrame, { BackgroundColor3 = "Field", BackgroundTransparency = "FieldAlpha" })
	end

	local view = ViewportView.new(stageFrame, opts)
	el.View = view

	local note = Create("TextLabel", {
		Name = "Note",
		Size = UDim2.fromScale(1, 1),
		Text = "Nothing to show",
		Font = Utility.Fonts.Desc,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = stageFrame,
	})
	theme:Bind(note, { TextColor3 = "Muted" })

	view.OnState = function(state, message)
		note.Visible = state ~= "ready"
		if state == "loading" then
			note.Text = "Loading..."
		elseif state == "failed" then
			note.Text = message or "Could not load this model"
		else
			note.Text = "Nothing to show"
		end
	end

	--// source ----------------------------------------------------------------------
	function el:SetSource(source)
		view:SetSource(source)
	end

	function el:SetModel(model)
		view:SetSource(model)
	end

	function el:SetAsset(id)
		view:SetSource({ Asset = id })
	end

	-- player: a Player (default: you)
	function el:SetCharacter(player)
		view:SetSource(player or "Character")
	end

	function el:SetUserId(userId)
		view:SetSource({ UserId = userId })
	end

	function el:SetMesh(spec)
		view:SetSource({ Mesh = spec })
	end

	function el:Clear()
		view:Clear()
	end

	function el:Refresh()
		view:Refresh()
	end

	--// camera ----------------------------------------------------------------------
	function el:SetYaw(degrees)
		view:SetYaw(degrees)
	end

	function el:SetPitch(degrees)
		view:SetPitch(degrees)
	end

	function el:SetZoom(value)
		view:SetZoom(value)
	end

	-- speed in degrees per second; false / 0 stops
	function el:SetRotate(speed)
		if not speed or speed == 0 then
			view:Spin(false)
		else
			view:Spin(true, speed == true and 25 or speed)
		end
	end

	function el:GetViewport()
		return view.Frame
	end

	--// start ------------------------------------------------------------------------
	if ViewportView.HasSource(opts) then
		view:SetSource(opts)
	end

	-- a respawn builds a new character: show it too
	local followsCharacter = opts.Source == "Character" or opts.Character == true or opts.Source == true
	local player = Players.LocalPlayer
	if followsCharacter and opts.Follow ~= false and player and player.CharacterAdded then
		el.Maid:Give(player.CharacterAdded:Connect(function()
			task.delay(1, function() -- the appearance arrives a moment after the character
				view:Refresh()
			end)
		end))
	end

	el.Maid:Give(function()
		view:Destroy()
	end)

	return Base.Finish(container, el, opts, "Viewport")
end
