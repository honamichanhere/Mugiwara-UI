--// ViewportView: draws something 3D (a model, your character, an asset, a mesh) inside a ViewportFrame and
--// lets the camera orbit around it. Shared by the Viewport element and the GridDropdown cells.
--//
--// A source is any of:
--//   * an Instance (Model, Part, Accessory, Tool...): a copy is shown, the original is never touched
--//   * true / "Character" / "LocalPlayer": your own character; a Player instance: that player's character
--//   * an asset id (number, "123", "rbxassetid://123"): loaded with game:GetObjects, then cached
--//   * a table with ONE of: Model, Character, Asset, UserId, Mesh = { MeshId, TextureId, Size, Scale }
--//     (UserId builds a rig with Players:CreateHumanoidModelFromUserId, which not every executor allows)
--//
--// Look options: Yaw (-25), Pitch (12), Zoom (1), FieldOfView (35), Rotate (true = 25 deg/s, or a number),
--//   Draggable (true), Ambient, LightColor, LightDirection.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Utility = Import("core/Utility")

local Create = Utility.Create

local ViewportView = {}

local assetCache = {} -- digits / "user:id" -> template Instance (failures are not cached)

local SOURCE_KEYS = { "Source", "Model", "Character", "Asset", "UserId", "Mesh" }
local LOOK_KEYS = { "Yaw", "Pitch", "Zoom", "FieldOfView", "Rotate", "Draggable", "Ambient", "LightColor", "LightDirection" }

-- true when `value` is a table that carries a source (so an element's options can double as a source)
function ViewportView.HasSource(value)
	if type(value) ~= "table" then
		return false
	end
	for _, key in ipairs(SOURCE_KEYS) do
		if value[key] ~= nil and value[key] ~= false then
			return true
		end
	end
	return false
end

-- base look options overridden by the look keys of `source` when it is a table
function ViewportView.Options(base, source)
	local merged = {}
	for _, key in ipairs(LOOK_KEYS) do
		merged[key] = base and base[key]
	end
	if type(source) == "table" then
		for _, key in ipairs(LOOK_KEYS) do
			if source[key] ~= nil then
				merged[key] = source[key]
			end
		end
	end
	return merged
end

local function digitsOf(value)
	if type(value) == "number" then
		return Utility.IdText(value)
	end
	if type(value) == "string" then
		return string.match(value, "^%d+$") or string.match(value, "^rbxassetid://(%d+)$")
	end
	return nil
end

local function characterOf(player)
	local character = player and player.Character
	if character then
		return character
	end
	return nil, "That character is not loaded yet"
end

local function loadAsset(digits)
	if assetCache[digits] then
		return assetCache[digits]
	end
	local ok, objects = pcall(function()
		return game:GetObjects("rbxassetid://" .. digits)
	end)
	local root = ok and objects and objects[1] or nil
	if root and objects[2] then
		local together = Create("Model", { Name = "Asset" })
		for _, object in ipairs(objects) do
			object.Parent = together
		end
		root = together
	end
	if not root then
		return nil, "Could not load asset " .. digits .. " (needs game:GetObjects, and the asset must be a model)"
	end
	assetCache[digits] = root
	return root
end

local function loadUser(userId)
	local key = "user:" .. tostring(userId)
	if assetCache[key] then
		return assetCache[key]
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)
	if not ok or not model then
		return nil, "This executor cannot build a character from a user id"
	end
	assetCache[key] = model
	return model
end

-- A part with a mesh on it. `Size` is only used to frame the camera: a file mesh keeps its own size.
local function buildMesh(spec)
	local part = Create("Part", {
		Name = "Mesh",
		Anchored = true,
		Size = spec.Size or Vector3.new(4, 4, 4),
	})
	Create("SpecialMesh", {
		MeshType = Enum.MeshType.FileMesh,
		MeshId = spec.MeshId or "",
		TextureId = spec.TextureId or "",
		Scale = spec.Scale or Vector3.new(1, 1, 1),
		Parent = part,
	})
	local model = Create("Model", { Name = "Stage" })
	part.Parent = model
	return model
end

-- Returns a template Instance (never modified) or nil plus a reason. May yield.
function ViewportView.Resolve(source)
	local kind = typeof(source)
	if kind == "Instance" then
		if source:IsA("Player") then
			return characterOf(source)
		end
		return source
	end
	if source == true or source == "Character" or source == "LocalPlayer" then
		return characterOf(Players.LocalPlayer)
	end
	local digits = digitsOf(source)
	if digits then
		return loadAsset(digits)
	end
	if kind == "table" then
		if source.Source ~= nil then
			return ViewportView.Resolve(source.Source)
		elseif source.Model ~= nil then
			return ViewportView.Resolve(source.Model)
		elseif source.Character ~= nil and source.Character ~= false then
			return ViewportView.Resolve(source.Character)
		elseif source.Asset ~= nil then
			return ViewportView.Resolve(source.Asset)
		elseif source.UserId ~= nil then
			return loadUser(source.UserId)
		elseif type(source.Mesh) == "table" then
			return buildMesh(source.Mesh)
		end
	end
	return nil, "Unsupported viewport source"
end

-- Clone that also works when the original is not Archivable
local function copyOf(template)
	local ok, copy = pcall(function()
		return template:Clone()
	end)
	if ok and copy then
		return copy
	end
	local wasArchivable = template.Archivable
	pcall(function()
		template.Archivable = true
	end)
	ok, copy = pcall(function()
		return template:Clone()
	end)
	pcall(function()
		template.Archivable = wasArchivable
	end)
	if ok and copy then
		return copy
	end
	return nil
end

-- Scripts and sounds do nothing in a ViewportFrame; dropping them keeps the copy light
local function strip(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Sound") then
			pcall(function()
				descendant:Destroy()
			end)
		end
	end
end

local function asModel(object)
	if object:IsA("Model") then
		return object
	end
	local model = Create("Model", { Name = "Stage" })
	object.Parent = model
	return model
end

-- parent: where the ViewportFrame goes. Returns a view; view.Frame is the ViewportFrame.
-- view.OnState(state, message) is called with "loading", "ready", "failed" or "empty".
function ViewportView.new(parent, opts)
	opts = opts or {}
	local view = { Maid = Utility.Maid.new(), State = "empty" }
	local maid = view.Maid

	local frame = Create("ViewportFrame", {
		Name = "Viewport",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = opts.Draggable ~= false, -- an Active frame swallows clicks meant for the cell it sits in
		Ambient = opts.Ambient or Color3.fromRGB(190, 192, 205),
		LightColor = opts.LightColor or Color3.fromRGB(255, 255, 255),
		LightDirection = opts.LightDirection or Vector3.new(-1, -1.2, -0.8),
		Parent = parent,
	})
	local camera = Create("Camera", { FieldOfView = opts.FieldOfView or 35, Parent = frame })
	frame.CurrentCamera = camera
	view.Frame = frame
	view.Camera = camera

	local stage, center, radius
	local yaw, pitch, zoom = opts.Yaw or -25, opts.Pitch or 12, opts.Zoom or 1
	local spinSpeed = 0
	if type(opts.Rotate) == "number" then
		spinSpeed = opts.Rotate
	elseif opts.Rotate then
		spinSpeed = 25
	end
	local source, token, dragging = nil, 0, false
	-- Destroying also fires when an ancestor is destroyed (a cell being rebuilt). Not IsDescendantOf(game):
	-- executors keep their GUIs in hidden containers that are not part of the game tree.
	local alive = true
	maid:Give(frame.Destroying:Connect(function()
		alive = false
	end))

	local function setState(state, message)
		view.State = state
		view.Message = message
		if view.OnState then
			Utility.SafeCall(view.OnState, state, message)
		end
	end

	local function aim()
		if not stage then
			return
		end
		local distance = radius / math.sin(math.rad(camera.FieldOfView / 2)) * 0.8 / zoom
		camera.CFrame = CFrame.new(center)
			* CFrame.Angles(0, math.rad(yaw), 0)
			* CFrame.Angles(-math.rad(pitch), 0, 0)
			* CFrame.new(0, 0, distance)
	end

	--// content ----------------------------------------------------------------------
	local function clear()
		if stage then
			stage:Destroy()
			stage = nil
		end
	end

	-- Shows `newSource` (see the top of this file); nil clears the view. Returns immediately: loading
	-- happens in the background and is reported through OnState.
	function view:SetSource(newSource)
		token = token + 1
		local mine = token
		source = newSource
		clear()
		if newSource == nil then
			setState("empty")
			return
		end
		setState("loading")
		task.spawn(function()
			local template, reason = ViewportView.Resolve(newSource)
			if mine ~= token or not alive then
				return
			end
			if not template then
				setState("failed", reason or "Nothing to show")
				return
			end
			local copy = copyOf(template)
			if not copy then
				setState("failed", "This model cannot be cloned")
				return
			end
			strip(copy)
			local model = asModel(copy)
			model.Parent = frame

			local ok, boxCFrame, boxSize = pcall(function()
				return model:GetBoundingBox()
			end)
			if not ok or not boxSize or boxSize.Magnitude <= 0 then
				model:Destroy()
				setState("failed", "There is nothing visible in this model")
				return
			end
			stage = model
			center = boxCFrame.Position
			radius = math.max(boxSize.Magnitude / 2, 0.25)
			aim()
			setState("ready")
		end)
	end

	-- loads the same source again (a respawned character, a changed model)
	function view:Refresh()
		if source ~= nil then
			view:SetSource(source)
		end
	end

	function view:Clear()
		view:SetSource(nil)
	end

	--// camera -----------------------------------------------------------------------
	function view:SetYaw(degrees)
		yaw = degrees
		aim()
	end

	function view:SetPitch(degrees)
		pitch = Utility.Clamp(degrees, -85, 85)
		aim()
	end

	function view:SetZoom(value)
		zoom = Utility.Clamp(value, 0.2, 8)
		aim()
	end

	function view:GetCamera()
		return yaw, pitch, zoom
	end

	--// spinning ---------------------------------------------------------------------
	local spinConnection
	local wantSpin = spinSpeed ~= 0

	local function stopSpin()
		if spinConnection then
			spinConnection:Disconnect()
			spinConnection = nil
		end
	end

	local function startSpin()
		if spinConnection or spinSpeed == 0 then
			return
		end
		spinConnection = RunService.Heartbeat:Connect(function(step)
			if not alive then
				stopSpin()
				return
			end
			if not dragging then
				yaw = yaw + spinSpeed * (step or 0.016)
				aim()
			end
		end)
	end

	-- Spin(true / false) starts or stops; speed (degrees per second) is optional
	function view:Spin(on, speed)
		if speed then
			spinSpeed = speed
		end
		if on == false then
			stopSpin()
		elseif spinSpeed ~= 0 then
			startSpin()
		end
	end

	if wantSpin then
		startSpin()
	end

	--// dragging to turn it ------------------------------------------------------------
	if opts.Draggable ~= false then
		local startPointer, startYaw, startPitch
		Utility.DragInput(frame, maid, function(input)
			startPointer = input.Position
			startYaw, startPitch = yaw, pitch
			dragging = true
		end, function(position)
			if not startPointer then
				return
			end
			local delta = position - startPointer
			yaw = startYaw - delta.X * 0.6
			pitch = Utility.Clamp(startPitch + delta.Y * 0.4, -85, 85)
			aim()
		end, function()
			dragging = false
			startPointer = nil
		end)
	end

	function view:Destroy()
		token = token + 1
		stopSpin()
		maid:Clean()
		frame:Destroy()
	end

	return view
end

return ViewportView
