--// Key UI: a separate, wide (21:9) glass card that asks for a key and validates it with YOUR function.
--// Left side: who you are (icon, title, note). Right side: key field, status, Verify, link buttons.
--// An accepted key is always saved (when the executor has file access); next run it is validated again
--// and, if it still passes, the Key UI never appears.
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

-- wide card; the height follows the content (a row of link buttons makes it taller)
local WIDTH = 700
local HEIGHT_PLAIN, HEIGHT_WITH_LINKS = 224, 262
local SIDE = 250

local function trim(text)
	text = string.gsub(tostring(text or ""), "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text
end

-- opts: Title, Subtitle, Icon, Note (false hides it), Heading, Placeholder, Folder,
--       SaveKey (default true; false = never save the key), Links = { { Title, Link, Icon, Callback } },
--       SubmitText ("Verify Key"), CheckingText ("Checking..."), SuccessText ("Access granted"): the button texts,
--       Height (card height in pixels, default follows the content), MobileScale (default 0.75 on phones),
--       Validate(key) -> true | false, message  (required, may yield; only `true` accepts),
--       OnSuccess(key), OnClose()
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
	local submitText = opts.SubmitText or "Verify Key"
	local checkingText = opts.CheckingText or "Checking..."
	local successText = opts.SuccessText or "Access granted"

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
			submitLabel.Text = checkingText
		end

		task.spawn(function()
			local valid, message = runValidate(key)
			if not valid then
				busy = false -- an accepted key keeps the card locked while it plays the success animation
				setStatus(message or "Invalid key.", "error")
				if submitLabel then
					submitLabel.Text = submitText
				end
				shake()
				return
			end

			setStatus(message or "Key accepted.", "success")
			if submitLabel then
				submitLabel.Text = successText
			end
			if submitButton then
				submitButton.BackgroundColor3 = theme.Tokens.Success
			end
			if canSave then
				Compat.EnsureFolder(folder)
				Compat.WriteFile(keyPath, key)
			end
			Utility.SafeCall(opts.OnSuccess, key)
			task.delay(0.9, function()
				finish(key)
			end)
		end)
	end

	function KeyUI:Submit(key)
		submit(key)
	end

	local function build()
		shell = Shell.new(library, {
			Name = "Key",
			Size = Vector2.new(WIDTH, opts.Height or (#links > 0 and HEIGHT_WITH_LINKS or HEIGHT_PLAIN)),
			MobileScale = opts.MobileScale,
			Backdrop = 0.45,
			-- covers the whole screen including the top bar strip (the backdrop used to stop below it)
			IgnoreGuiInset = true,
			MinScale = 0.5,
		})
		local maid = shell.Maid
		local card = shell.Card

		--// left panel: identity ---------------------------------------------------------
		local side = Create("Frame", {
			Name = "Side",
			Size = UDim2.new(0, SIDE, 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			Parent = card,
		})
		theme:Bind(side, { BackgroundColor3 = "Sidebar", BackgroundTransparency = "SidebarAlpha" })
		local sideEdge = Create("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = side,
		})
		theme:Bind(sideEdge, { BackgroundColor3 = "Stroke", BackgroundTransparency = "StrokeAlpha" })

		local identity = Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = side,
		})
		Utility.Padding(identity, 20, 20, 28, 24)
		Utility.List(identity, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local brand = Create("Frame", {
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = 1,
			Parent = identity,
		})
		Utility.Corner(brand, 16)
		Base.Gradient(theme, brand, 45)
		local slot = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(34, 34),
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
				TextSize = 30,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = brand,
			})
			theme:Bind(letter, { TextColor3 = "OnAccent" })
		end

		local title = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Title or "Mugiwara Hub",
			Font = Utility.Fonts.Title,
			TextSize = 23,
			TextWrapped = true,
			LayoutOrder = 2,
			Parent = identity,
		})
		Base.Gradient(theme, title, 0)

		local subtitle = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Subtitle or "Key System",
			Font = Utility.Fonts.Label,
			TextSize = 14,
			TextWrapped = true,
			LayoutOrder = 3,
			Parent = identity,
		})
		theme:Bind(subtitle, { TextColor3 = "Text" })

		if opts.Note ~= false then
			local note = Create("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = opts.Note or "Enter your key to continue.",
				Font = Utility.Fonts.Desc,
				TextSize = 13,
				TextWrapped = true,
				LayoutOrder = 4,
				Parent = identity,
			})
			theme:Bind(note, { TextColor3 = "SubText" })
		end

		--// right panel: the form -----------------------------------------------------------
		local form = Create("Frame", {
			Name = "Form",
			Position = UDim2.fromOffset(SIDE, 0),
			Size = UDim2.new(1, -SIDE, 1, 0),
			BackgroundTransparency = 1,
			Parent = card,
		})
		Utility.Padding(form, 20, 20, 34, 34)
		Utility.List(form, 10, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

		local heading = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 26),
			Text = opts.Heading or "Enter your key",
			Font = Utility.Fonts.Title,
			TextSize = 20,
			LayoutOrder = 1,
			Parent = form,
		})
		theme:Bind(heading, { TextColor3 = "Text" })

		local field, fieldStroke = Base.Field(theme, form, UDim2.new(1, 0, 0, 48))
		field.LayoutOrder = 2
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
				Size = UDim2.fromOffset(52, 32),
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

		status = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18),
			Text = "",
			Font = Utility.Fonts.Label,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 3,
			Parent = form,
		})
		KeyUI.Status = status

		-- centered anchor so the press animation shrinks toward the middle
		local verifyHolder = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundTransparency = 1,
			LayoutOrder = 4,
			Parent = form,
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
			Text = submitText,
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

		--// links ------------------------------------------------------------------------------
		KeyUI.LinkButtons = {}
		if #links > 0 then
			local row = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				LayoutOrder = 5,
				Parent = form,
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

		--// close ---------------------------------------------------------------------------------
		local closeButton = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 14),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			ZIndex = 5,
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

		KeyUI.Shell = shell
		KeyUI.SubmitButton = submitButton
		KeyUI.SubmitLabel = submitLabel

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
