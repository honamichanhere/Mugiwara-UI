local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Base = Import("components/Base")

local Create, Tween = Utility.Create, Utility.Tween

local SCALE_TYPES = {
	Crop = Enum.ScaleType.Crop,
	Fit = Enum.ScaleType.Fit,
	Stretch = Enum.ScaleType.Stretch,
}

-- opts: Image (asset id, rbxassetid://, or http(s) URL), Height (default 150), Scale ("Crop" | "Fit" | "Stretch"),
--       Title, Desc. Roblox Store ids are Decals: they are converted automatically (see Compat.ResolveImage).
-- el:SetImage(image) swaps the picture.
return function(container, opts)
	opts = opts or {}
	local theme = container.Window.Theme
	local el = Base.Card(container, opts)

	local hasHeader = el.Top.Visible
	local extra = Base.Extra(el, opts.Height or 150, hasHeader and 10 or 0)

	local frame = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ClipsDescendants = true,
		Parent = extra,
	})
	Utility.Corner(frame, 8)
	theme:Bind(frame, { BackgroundColor3 = "Field", BackgroundTransparency = "FieldAlpha" })

	local image = Create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		ScaleType = SCALE_TYPES[opts.Scale or "Crop"] or Enum.ScaleType.Crop,
		ImageTransparency = 1,
		Visible = false,
		Parent = frame,
	})

	el.ImageLabel = image

	local note = Create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = "Loading image...",
		Font = Utility.Fonts.Desc,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	theme:Bind(note, { TextColor3 = "Muted" })

	local version = 0

	function el:SetImage(source)
		version = version + 1
		local mine = version
		el.Value = source
		image.Visible = false
		note.Visible = true
		note.Text = "Loading image..."
		task.spawn(function()
			local asset, reason = Compat.ResolveImage(source, container.Window.Folder)
			if mine ~= version or not image.Parent then
				return
			end
			if not asset then
				note.Text = reason or "Image unavailable"
				return
			end
			image.Image = asset
			image.Visible = true
			Tween(image, { ImageTransparency = 0 }, 0.5)
			if Compat.ImageLoaded(image) == false and mine == version then
				image.Visible = false
				note.Text = "Roblox could not load this image"
			else
				note.Visible = false
			end
		end)
	end

	if opts.Image then
		el:SetImage(opts.Image)
	else
		note.Text = "No image"
	end

	return Base.Finish(container, el, opts, "Image")
end
