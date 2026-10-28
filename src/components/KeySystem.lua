--// Key UI: a separate glass card that asks for a key and validates it with YOUR function.
--//
--//   local KeyUI = MugiwaraUI:KeySystem({
--//       Title = "Mugiwara Hub",
--//       Folder = "MugiwaraHub",
--//       Links = { { Title = "Get Key", Link = "https://example.com/key" } },
--//       Validate = function(key) return key == "abc", "Invalid key" end,
--//   })
--//   local key = KeyUI:Wait()   -- yields until a key is accepted; nil if the user closed the card

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Icons = Import("core/Icons")
local Base = Import("components/Base")
local Shell = Import("components/Shell")

local Create, Tween = Utility.Create, Utility.Tween

local WIDTH = 420
local PAD = 24

local function trim(text)
	text = string.gsub(tostring(text or ""), "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text
end

-- opts: Title, Subtitle, Icon, Note (false hides it), Placeholder, Folder, SaveKey (default true: offers
--       the "Remember key" switch), Remember (switch starts on), Links = { { Title, Link, Icon, Callback } },
--       Validate(key) -> valid, message  (required, may yield), OnSuccess(key), OnClose()
return function(library, opts)
	opts = opts or {}
	if type(opts.Validate) ~= "function" then
		error("MugiwaraUI:KeySystem needs a Validate(key) function that returns true or false, message", 2)
	end

	local theme = library.Theme
	local folder = opts.Folder or "MugiwaraUI"
	local keyPath = folder .. "/key.txt"
	local canSave = opts.SaveKey ~= false and Compat.FilesSupported
	local links = opts.Links or {}

	local KeyUI = {
		Completed = Utility.Signal.new(true),
		Key = nil,
		Destroyed = false,
	}

	if library._keyUI and not library._keyUI.Destroyed then
		library._keyUI:Close()
	end
	library._keyUI = KeyUI

	local shell, status, box, submitButton, submitLabel
	local busy, finished = false, false
	local remember = opts.Remember == true

	--// validation ---------------------------------------------------------------------
	-- returns valid (bool), message (string|nil); errors inside Validate count as invalid
	local function runValidate(key)
		local ok, valid, message = pcall(opts.Validate, key)
		if not ok then
			warn("[MugiwaraUI] Validate error: " .. tostring(valid))
			return false, "Validation failed. Try again."
		end
		return valid == true, message
	end

	local function setStatus(text, kind)
		if not status then
			return
		end
		local colors = {
			info = theme.Tokens.SubText,
			error = theme.Tokens.Danger,
			success = theme.Tokens.Success,
			busy = theme.Tokens.Accent,
		}
		status.Text = text or ""
		status.TextColor3 = colors[kind or "info"]
	end

	function KeyUI:SetStatus(text, kind)
		setStatus(text, kind)
	end

	function KeyUI:ClearSavedKey()
		Compat.DeleteFile(keyPath)
	end

	local function finish(key)
		if finished then
			return
		end
		finished = true
		KeyUI.Key = key
		local function done()
			KeyUI.Destroyed = true
			KeyUI.Completed:Fire(key)
		end
		if shell then
			shell:Hide(done)
		else
			done()
		end
	end

	function KeyUI:Close()
		if finished then
			return
		end
		Utility.SafeCall(opts.OnClose)
		finish(nil)
	end

	function KeyUI:Wait()
		return self.Completed:Wait()
	end

	--// UI ------------------------------------------------------------------------------
	local function shake()
		local offsets = { 10, -9, 7, -5, 3, 0 }
		for index, dx in ipairs(offsets) do
			task.delay((index - 1) * 0.05, function()
				if shell and shell.Pop.Parent then
					Tween(shell.Pop, { Position = UDim2.new(0.5, dx, 0.5, 0) }, 0.05, Enum.EasingStyle.Sine)
				end
			end)
		end
	end

	local function submit(typed)
		if busy or finished then
			return
		end
		local key = trim(typed or (box and box.Text) or "")
		if key == "" then
			setStatus("Please enter your key.", "error")
			shake()
			return
		end

		busy = true
		setStatus("Checking key...", "busy")
		if submitLabel then
			submitLabel.Text = "Checking..."
		end

		task.spawn(function()
			local valid, message = runValidate(key)
			if not valid then
				busy = false -- an accepted key keeps the card locked while it plays the success animation
			end

			if valid then
				setStatus(message or "Key accepted.", "success")
				if submitLabel then
					submitLabel.Text = "Access granted"
				end
				if submitButton then
					submitButton.BackgroundColor3 = theme.Tokens.Success
				end
				if canSave then
					if remember then
						Compat.EnsureFolder(folder)
						Compat.WriteFile(keyPath, key)
					else
						Compat.DeleteFile(keyPath)
					end
				end
				Utility.SafeCall(opts.OnSuccess, key)
				task.delay(0.9, function()
					finish(key)
				end)
			else
				setStatus(message or "Invalid key.", "error")
				if submitLabel then
					submitLabel.Text = "Verify Key"
				end
				shake()
			end
		end)
	end

	function KeyUI:Submit(key)
		submit(key)
	end

	local function build()
		local hasNote = opts.Note ~= false
		local hasLinks = #links > 0
		local y = 20

		-- vertical layout: positions are computed first so the card gets exactly the height it needs
		local headerY = y
		y = y + 64
		local noteY = y
		if hasNote then
			y = y + 44
		end
		local fieldY = y
		y = y + 46 + 6
		local statusY = y
		y = y + 20 + 6
		local rememberY = y
		if canSave then
			y = y + 26 + 10
		end
		local verifyY = y
		y = y + 46 + 10
		local linksY = y
		if hasLinks then
			y = y + 34
		end
		local height = y + (hasLinks and 24 or 14)

		shell = Shell.new(library, {
			Name = "Key",
			Size = Vector2.new(WIDTH, height),
			Backdrop = 0.45,
			MinScale = 0.55,
		})
		local maid = shell.Maid
		local card = shell.Card

		--// header
		local brand = Create("Frame", {
			Position = UDim2.fromOffset(PAD, headerY),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = card,
		})
		Utility.Corner(brand, 12)
		Base.Gradient(theme, brand, 45)
		local slot = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Parent = brand,
		})
		local logo, monochrome = Icons.Create(opts.Icon or "lucide:key-round", slot)
		if logo and monochrome then
			Icons.BindImage(theme, logo, "OnAccent")
		elseif logo then
			brand.BackgroundTransparency = 1
			slot.Size = UDim2.fromScale(1, 1)
		else
			slot:Destroy()
			local letter = Create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				Text = string.upper(string.sub(opts.Title or "M", 1, 1)),
				Font = Enum.Font.GothamBlack,
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = brand,
			})
			theme:Bind(letter, { TextColor3 = "OnAccent" })
		end

		local title = Create("TextLabel", {
			Position = UDim2.fromOffset(PAD + 56, headerY + 3),
			Size = UDim2.new(1, -(PAD + 56 + 56), 0, 24),
			Text = opts.Title or "Mugiwara Hub",
			Font = Utility.Fonts.Title,
			TextSize = 19,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		Base.Gradient(theme, title, 0)

		local subtitle = Create("TextLabel", {
			Position = UDim2.fromOffset(PAD + 56, headerY + 27),
			Size = UDim2.new(1, -(PAD + 56 + 56), 0, 16),
			Text = opts.Subtitle or "Key System",
			Font = Utility.Fonts.Desc,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		theme:Bind(subtitle, { TextColor3 = "SubText" })

		local closeButton = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, headerY - 4),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			Parent = card,
		})
		Utility.Corner(closeButton, 9)
		local closeGlyph = Icons.Bind(theme, Icons.Close(closeButton, 20, 2), "SubText")
		closeButton.MouseEnter:Connect(function()
			Tween(closeButton, { BackgroundTransparency = 0.88 }, 0.15)
			Icons.SetColor(closeGlyph, theme.Tokens.Danger)
		end)
		closeButton.MouseLeave:Connect(function()
			Tween(closeButton, { BackgroundTransparency = 1 }, 0.2)
			Icons.SetColor(closeGlyph, theme.Tokens.SubText)
		end)
		maid:Give(closeButton.MouseButton1Click:Connect(function()
			KeyUI:Close()
		end))

		--// note
		if hasNote then
			local note = Create("TextLabel", {
				Position = UDim2.fromOffset(PAD, noteY),
				Size = UDim2.new(1, -PAD * 2, 0, 36),
				Text = opts.Note or "Enter your key to continue.",
				Font = Utility.Fonts.Desc,
				TextSize = 14,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				Parent = card,
			})
			theme:Bind(note, { TextColor3 = "SubText" })
		end

		--// key field
		local field, fieldStroke = Base.Field(theme, card, UDim2.new(1, -PAD * 2, 0, 46), UDim2.fromOffset(PAD, fieldY))
		local keyIconSlot = Create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			Parent = field,
		})
		local keyIcon = Icons.Create("lucide:key-round", keyIconSlot)
		if keyIcon then
			Icons.BindImage(theme, keyIcon, "Muted")
		end

		local getClipboard = Compat.GetClipboard
		local pasteWidth = getClipboard and 64 or 0
		box = Create("TextBox", {
			Position = UDim2.fromOffset(46, 0),
			Size = UDim2.new(1, -(46 + 10 + pasteWidth), 1, 0),
			Text = "",
			PlaceholderText = opts.Placeholder or "Enter your key...",
			Font = Utility.Fonts.Body,
			TextSize = 15,
			ClearTextOnFocus = false,
			Parent = field,
		})
		theme:Bind(box, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })
		KeyUI.Box = box

		maid:Give(box.Focused:Connect(function()
			Tween(fieldStroke, { Transparency = 0.2 }, 0.2)
			fieldStroke.Color = theme.Tokens.Accent
		end))
		maid:Give(box.FocusLost:Connect(function(enterPressed)
			Tween(fieldStroke, { Transparency = theme.Tokens.StrokeAlpha }, 0.2)
			fieldStroke.Color = theme.Tokens.Stroke
			if enterPressed then
				submit()
			end
		end))

		if getClipboard then
			local paste = Create("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(52, 30),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Text = "Paste",
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = field,
			})
			Utility.Corner(paste, 8)
			theme:Bind(paste, { BackgroundColor3 = "Card", BackgroundTransparency = "CardHoverAlpha", TextColor3 = "Text" })
			maid:Give(paste.MouseButton1Click:Connect(function()
				local text = getClipboard()
				if text and text ~= "" then
					box.Text = trim(text)
				end
			end))
		end

		--// status line
		status = Create("TextLabel", {
			Position = UDim2.fromOffset(PAD + 2, statusY),
			Size = UDim2.new(1, -(PAD + 2) * 2, 0, 20),
			Text = "",
			Font = Utility.Fonts.Label,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		KeyUI.Status = status

		--// remember switch
		if canSave then
			local row = Create("TextButton", {
				Position = UDim2.fromOffset(PAD, rememberY),
				Size = UDim2.new(1, -PAD * 2, 0, 26),
				Parent = card,
			})
			local rowLabel = Create("TextLabel", {
				Position = UDim2.fromOffset(2, 0),
				Size = UDim2.new(1, -60, 1, 0),
				Text = "Remember key on this device",
				Font = Utility.Fonts.Body,
				TextSize = 14,
				Parent = row,
			})
			theme:Bind(rowLabel, { TextColor3 = "Text" })

			local track = Create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(40, 22),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Parent = row,
			})
			Utility.Corner(track, Utility.Pill)
			theme:Bind(track, { BackgroundColor3 = "Track", BackgroundTransparency = "TrackAlpha" })
			local fill = Create("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = remember and 0 or 1,
				Parent = track,
			})
			Utility.Corner(fill, Utility.Pill)
			Base.Gradient(theme, fill, 0)
			local knob = Create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, remember and 21 or 3, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Parent = track,
			})
			Utility.Corner(knob, Utility.Pill)

			maid:Give(row.MouseButton1Click:Connect(function()
				remember = not remember
				Tween(fill, { BackgroundTransparency = remember and 0 or 1 }, 0.2)
				Tween(knob, { Position = UDim2.new(0, remember and 21 or 3, 0.5, 0) }, 0.22)
			end))
		end

		--// verify button
		-- centered anchor so the press animation shrinks toward the middle
		local verifyHolder = Create("Frame", {
			Position = UDim2.fromOffset(PAD, verifyY),
			Size = UDim2.new(1, -PAD * 2, 0, 46),
			BackgroundTransparency = 1,
			Parent = card,
		})
		submitButton = Create("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = verifyHolder,
		})
		Utility.Corner(submitButton, 12)
		Base.Gradient(theme, submitButton, 0)
		submitLabel = Create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = "Verify Key",
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = submitButton,
		})
		theme:Bind(submitLabel, { TextColor3 = "OnAccent" })

		maid:Give(submitButton.MouseButton1Click:Connect(function()
			Tween(submitButton, { Size = UDim2.new(1, -8, 1, -6) }, 0.08)
			task.delay(0.09, function()
				if submitButton.Parent then
					Tween(submitButton, { Size = UDim2.fromScale(1, 1) }, 0.35, Enum.EasingStyle.Back)
				end
			end)
			submit()
		end))

		--// links
		KeyUI.LinkButtons = {}
		if hasLinks then
			local row = Create("Frame", {
				Position = UDim2.fromOffset(PAD, linksY),
				Size = UDim2.new(1, -PAD * 2, 0, 34),
				BackgroundTransparency = 1,
				Parent = card,
			})
			local gap = 8
			local count = #links
			Utility.List(row, gap, Enum.FillDirection.Horizontal)
			for index, link in ipairs(links) do
				local button = Create("TextButton", {
					Size = UDim2.new(1 / count, -gap * (count - 1) / count, 1, 0),
					LayoutOrder = index,
					BackgroundColor3 = Color3.new(1, 1, 1),
					Parent = row,
				})
				KeyUI.LinkButtons[index] = button
				Utility.Corner(button, 10)
				theme:Bind(button, { BackgroundColor3 = "Card", BackgroundTransparency = "CardHoverAlpha" })
				local buttonStroke = Utility.Stroke(button, Color3.new(1, 1, 1), 0.9, 1)
				theme:Bind(buttonStroke, { Color = "Stroke", Transparency = "StrokeAlpha" })

				-- icon + text centered as one group
				local group = Create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(0, 20),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Parent = button,
				})
				Utility.List(group, 8, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
				if link.Icon then
					local iconSlot = Create("Frame", { Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, LayoutOrder = 1, Parent = group })
					local icon = Icons.Create(link.Icon, iconSlot)
					if icon then
						Icons.BindImage(theme, icon, "Accent")
					else
						iconSlot:Destroy()
					end
				end
				local text = Create("TextLabel", {
					Size = UDim2.fromOffset(0, 20),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = link.Title or "Link",
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					LayoutOrder = 2,
					Parent = group,
				})
				theme:Bind(text, { TextColor3 = "Text" })

				maid:Give(button.MouseButton1Click:Connect(function()
					if link.Callback then
						Utility.SafeCall(link.Callback)
					elseif link.Link then
						-- executors cannot open a browser, so the link goes to the clipboard
						if Compat.SetClipboard(link.Link) then
							setStatus("Link copied to your clipboard.", "success")
						else
							setStatus(link.Link, "info")
						end
					end
				end))
			end
		end

		shell:Show()
		if not Compat.IsMobile then
			task.delay(0.5, function()
				if box and box.Parent then
					box:CaptureFocus()
				end
			end)
		end
	end

	--// start: a saved key that still validates skips the UI entirely -------------------------
	task.spawn(function()
		if canSave then
			local saved = Compat.ReadFile(keyPath)
			saved = saved and trim(saved) or ""
			if saved ~= "" then
				local valid = runValidate(saved)
				if valid then
					Utility.SafeCall(opts.OnSuccess, saved)
					finish(saved)
					return
				end
				Compat.DeleteFile(keyPath)
			end
		end
		if not finished then
			build()
		end
	end)

	return KeyUI
end
