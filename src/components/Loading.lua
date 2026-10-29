--// Loading UI: terminal-style loading card. The behavior (scrambled title, typed fake logs, progress that
--// follows real stages, staggered enter / exit) is the Mugiwara Hub loading screen; only the look follows
--// the active Mugiwara theme.
--//
--//   local Loader = MugiwaraUI:Loading({ Title = "Mugiwara Hub", Owner = "Honami", Version = "v1.0.0" })
--//   Loader:SetStatus("Loading modules")
--//   Loader:SetProgress(40, 70)     -- jump to 40%, then creep up to 70% while the stage runs
--//   Loader:Log("Fetching data", "info")
--//   Loader:Finish("Welcome!")      -- the loader never ends on its own
--//   Loader.Finished:Wait()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Utility = Import("core/Utility")
local Compat = Import("core/Compat")
local Base = Import("components/Base")
local Shell = Import("components/Shell")

local Create, Tween = Utility.Create, Utility.Tween

local DEFAULT_LOGS = {
	"Establishing secure connection",
	"Verifying key session",
	"Fetching UI library",
	"Decrypting payload",
	"Scanning game environment",
	"Resolving game modules",
	"Mounting global tabs",
	"Syncing configuration",
	"Allocating memory blocks",
	"Compiling feature modules",
	"Checking for updates",
	"Optimizing render pipeline",
}

local SCRAMBLE_CHARS = "!@#$%&*<>?/\\|01ABCDEFXZ"
local HEX_CHARS = "0123456789ABCDEF"
local ENTER_STAGGER = 0.1
local EXIT_STAGGER = 0.06

local function randomHex(length)
	local out = table.create(length)
	for index = 1, length do
		local pick = math.random(1, #HEX_CHARS)
		out[index] = string.sub(HEX_CHARS, pick, pick)
	end
	return table.concat(out)
end

local function hex(color)
	return "#" .. Utility.ToHex(color)
end

-- opts: Title, Owner, Version, Terminal (window title), Prompt, Logs (fake log lines), MaxLogLines, InstantCover
return function(library, opts)
	opts = opts or {}
	local theme = library.Theme
	local tokens = theme.Tokens

	-- the previous loader (if any) is replaced instead of stacking
	if library._loader and not library._loader.Destroyed then
		library._loader:Destroy()
	end

	-- palette comes from the active theme
	local C = {
		accent = tokens.Accent,
		gold = tokens.Gradient[2] or tokens.Accent,
		text = tokens.Text,
		dim = tokens.SubText,
		ok = tokens.Success,
		warn = tokens.Warning,
		err = tokens.Danger,
	}
	local config = {
		Title = opts.Title or "Mugiwara Hub",
		Owner = opts.Owner or opts.Author,
		Version = opts.Version,
		Terminal = opts.Terminal or "root@mugiwara: ~/loader",
		Prompt = opts.Prompt or "root@mugiwara",
		MaxLogLines = opts.MaxLogLines or 6,
		Logs = opts.Logs or DEFAULT_LOGS,
	}

	local state = {
		finishing = false,
		finished = false,
		titleBusy = false,
		status = "Initializing",
		startTime = os.clock(),
		lastHex = 0,
		-- Progress: with Loader:SetProgress(target, cap) the percent follows the real stages (jumps to
		-- `target`, then creeps toward `cap`). Without it a time curve is used.
		manualProgress = false,
		target = 0,
		cap = 0,
	}
	local logOrder = 0

	local shell = Shell.new(library, {
		Name = "Loading",
		Size = Vector2.new(460, 312),
		Backdrop = 0.35,
		InstantBackdrop = opts.InstantCover == true,
		IgnoreGuiInset = true,
		MinScale = 0.55,
		MaxScale = 1.3,
		MobileScale = opts.MobileScale,
	})
	local maid = shell.Maid
	local card = shell.Card

	--// content blocks: separate CanvasGroups so they enter / leave one after another
	local content = Create("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = card })

	local function createBlock(name)
		return Create("CanvasGroup", {
			Name = name,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Position = UDim2.fromOffset(0, 14),
			Parent = content,
		})
	end

	local HeaderBlock = createBlock("HeaderBlock")
	local DividerBlock = createBlock("DividerBlock")
	local TerminalBlock = createBlock("TerminalBlock")
	local ProgressBlock = createBlock("ProgressBlock")
	local FooterBlock = createBlock("FooterBlock")
	local Blocks = { HeaderBlock, DividerBlock, TerminalBlock, ProgressBlock, FooterBlock }

	--// header
	local Title = Create("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -60, 0, 32),
		Font = Enum.Font.GothamBlack,
		Text = "",
		TextSize = 26,
		Parent = HeaderBlock,
	})
	Base.Gradient(theme, Title, 0)

	local PulseDot = Create("Frame", {
		Name = "PulseDot",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -22, 0, 32),
		Size = UDim2.fromOffset(9, 9),
		BackgroundColor3 = C.accent,
		Parent = HeaderBlock,
	})
	Utility.Corner(PulseDot, Utility.Pill)

	local parts = {}
	if config.Owner then
		table.insert(parts, string.format('Owner: <font color="%s">%s</font>', hex(C.accent), config.Owner))
	end
	if config.Version and config.Version ~= "" then
		table.insert(parts, string.format('Version: <font color="%s">%s</font>', hex(C.gold), config.Version))
	end
	local subtitle = Create("TextLabel", {
		Name = "Subtitle",
		Position = UDim2.fromOffset(20, 50),
		Size = UDim2.new(1, -40, 0, 16),
		Font = Enum.Font.Code,
		RichText = true,
		TextSize = 13,
		TextColor3 = C.dim,
		Text = table.concat(parts, "   |   "),
		Parent = HeaderBlock,
	})
	theme:Bind(subtitle, { TextColor3 = "SubText" })

	--// divider (grows from the center when its block enters)
	local DIVIDER_SIZE = UDim2.new(1, -40, 0, 1)
	local DividerLine = Create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.new(0, 0, 0, 1),
		BackgroundColor3 = C.dim,
		Parent = DividerBlock,
	})
	Base.Gradient(theme, DividerLine, 0).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})

	--// terminal
	local TerminalBox = Create("Frame", {
		Name = "Terminal",
		Position = UDim2.fromOffset(20, 86),
		Size = UDim2.new(1, -40, 0, 150),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ClipsDescendants = true,
		Parent = TerminalBlock,
	})
	Utility.Corner(TerminalBox, 8)
	theme:Bind(TerminalBox, { BackgroundColor3 = "Field", BackgroundTransparency = "FieldAlpha" })
	local terminalStroke = Utility.Stroke(TerminalBox, C.dim, 0.8, 1)
	theme:Bind(terminalStroke, { Color = "Stroke", Transparency = "StrokeAlpha" })

	for index, color in ipairs({ C.err, C.warn, C.ok }) do
		local dot = Create("Frame", {
			Position = UDim2.fromOffset(10 + (index - 1) * 14, 7),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = color,
			Parent = TerminalBox,
		})
		Utility.Corner(dot, Utility.Pill)
	end

	local terminalTitle = Create("TextLabel", {
		Name = "TerminalTitle",
		Position = UDim2.fromOffset(56, 3),
		Size = UDim2.new(1, -66, 0, 16),
		Font = Enum.Font.Code,
		TextSize = 12,
		Text = config.Terminal,
		Parent = TerminalBox,
	})
	theme:Bind(terminalTitle, { TextColor3 = "SubText" })

	local terminalRule = Create("Frame", {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = TerminalBox,
	})
	theme:Bind(terminalRule, { BackgroundColor3 = "Stroke", BackgroundTransparency = "StrokeAlpha" })

	local LogFrame = Create("Frame", {
		Name = "Logs",
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 1, -50),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = TerminalBox,
	})
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 2),
		Parent = LogFrame,
	})

	local PROMPT_TEXT = string.format(
		'<font color="%s">%s</font><font color="%s">:~$</font> ',
		hex(C.gold),
		config.Prompt,
		hex(C.dim)
	)
	local PromptLabel = Create("TextLabel", {
		Name = "Prompt",
		Position = UDim2.new(0, 10, 1, -20),
		Size = UDim2.new(1, -20, 0, 16),
		Font = Enum.Font.Code,
		RichText = true,
		TextSize = 12,
		TextColor3 = C.text,
		Text = PROMPT_TEXT,
		Parent = TerminalBox,
	})

	-- scanline sweeping down the terminal
	local Scanline = Create("Frame", {
		Name = "Scanline",
		Position = UDim2.fromScale(0, -0.05),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = C.gold,
		BackgroundTransparency = 0.85,
		ZIndex = 5,
		Parent = TerminalBox,
	})

	local function loop(inst, info, goal)
		local tween = TweenService:Create(inst, info, goal)
		tween:Play()
		maid:Give(function()
			tween:Cancel()
		end)
	end
	loop(Scanline, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Position = UDim2.fromScale(0, 1.05) })

	--// status + progress
	local StatusLabel = Create("TextLabel", {
		Name = "Status",
		Position = UDim2.fromOffset(20, 246),
		Size = UDim2.new(1, -100, 0, 16),
		Font = Enum.Font.Code,
		TextSize = 13,
		TextColor3 = C.text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = ProgressBlock,
	})

	local PercentLabel = Create("TextLabel", {
		Name = "Percent",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 246),
		Size = UDim2.fromOffset(70, 16),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = C.gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0%",
		Parent = ProgressBlock,
	})

	local BAR_SIZE = UDim2.new(1, -40, 0, 6)
	local BarTrack = Create("Frame", {
		Name = "BarTrack",
		Position = UDim2.fromOffset(20, 268),
		Size = UDim2.new(0, 0, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = ProgressBlock,
	})
	Utility.Corner(BarTrack, Utility.Pill)
	theme:Bind(BarTrack, { BackgroundColor3 = "Track", BackgroundTransparency = "TrackAlpha" })

	local Fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = BarTrack,
	})
	Utility.Corner(Fill, Utility.Pill)
	local FillGradient = Base.Gradient(theme, Fill, 0)

	local Shimmer = Create("Frame", {
		Name = "Shimmer",
		Position = UDim2.fromScale(-0.3, 0),
		Size = UDim2.fromScale(0.3, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = BarTrack,
	})
	Create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = Shimmer,
	})
	loop(Shimmer, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), { Position = UDim2.fromScale(1, 0) })

	-- random hex line under the bar (decoration)
	local HexFooter = Create("TextLabel", {
		Name = "HexFooter",
		Position = UDim2.fromOffset(20, 284),
		Size = UDim2.new(1, -40, 0, 14),
		Font = Enum.Font.Code,
		TextSize = 11,
		TextColor3 = C.dim,
		TextTransparency = 0.45,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = FooterBlock,
	})

	--// text animations ---------------------------------------------------------------
	-- title "decodes" letter by letter
	local function scrambleText(label, finalText, duration)
		state.titleBusy = true
		local length = #finalText
		local stepTime = duration / math.max(length, 1)

		for revealed = 0, length do
			if not label.Parent then
				break
			end
			local out = { string.sub(finalText, 1, revealed) }
			for index = revealed + 1, length do
				if string.sub(finalText, index, index) == " " then
					table.insert(out, " ")
				else
					local pick = math.random(1, #SCRAMBLE_CHARS)
					table.insert(out, string.sub(SCRAMBLE_CHARS, pick, pick))
				end
			end
			label.Text = table.concat(out)
			task.wait(stepTime)
		end

		if label.Parent then
			label.Text = finalText
		end
		state.titleBusy = false
	end

	local LOG_TYPES = {
		info = { tag = "*", color = C.warn },
		ok = { tag = "+", color = C.ok },
		warn = { tag = "!", color = C.warn },
		error = { tag = "x", color = C.err },
	}

	-- one log line with a typing effect
	local function addLog(message, kind)
		if not LogFrame.Parent then
			return nil
		end

		local logType = LOG_TYPES[kind] or LOG_TYPES.info
		local timeStr = os.date("%H:%M:%S")
		logOrder = logOrder + 1

		local richText = string.format(
			'<font color="%s">[%s]</font> <font color="%s">[%s]</font> %s',
			hex(C.dim),
			timeStr,
			hex(logType.color),
			logType.tag,
			message
		)
		-- length without RichText tags (for the typing effect)
		local plainLength = #string.format("[%s] [%s] %s", timeStr, logType.tag, message)

		local line = Create("TextLabel", {
			Name = "Log",
			Size = UDim2.new(1, 0, 0, 15),
			Font = Enum.Font.Code,
			RichText = true,
			TextSize = 12,
			TextColor3 = C.text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = logOrder,
			MaxVisibleGraphemes = 0,
			Text = richText,
			Parent = LogFrame,
		})

		-- drop the oldest lines when there are too many
		local lines = {}
		for _, child in ipairs(LogFrame:GetChildren()) do
			if child:IsA("TextLabel") then
				table.insert(lines, child)
			end
		end
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		while #lines > config.MaxLogLines do
			table.remove(lines, 1):Destroy()
		end

		task.spawn(function()
			for index = 1, plainLength do
				if not line.Parent then
					return
				end
				line.MaxVisibleGraphemes = index
				task.wait(0.012)
			end
			if line.Parent then
				line.MaxVisibleGraphemes = -1
			end
		end)

		return { Label = line, Base = richText }
	end

	-- appends " OK" / " RETRY" to a log line
	local function completeLog(entry, word, color)
		if not entry or not entry.Label.Parent then
			return
		end
		entry.Label.MaxVisibleGraphemes = -1
		entry.Label.Text = string.format('%s <font color="%s">%s</font>', entry.Base, hex(color), word)
	end

	--// per-frame loop -----------------------------------------------------------------
	local percentValue = Instance.new("NumberValue")
	percentValue.Value = 0
	maid:Give(percentValue)

	maid:Give(RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()

		PulseDot.BackgroundTransparency = 0.35 + 0.35 * math.sin(now * 5)
		PromptLabel.Text = PROMPT_TEXT .. ((math.floor(now * 2.5) % 2 == 0) and "_" or "")

		-- percent: follows the real stages with SetProgress, otherwise a time curve.
		-- Never goes down and stops at 99% until Finish is called.
		if not state.finishing then
			local current = percentValue.Value
			if state.manualProgress then
				if current < state.target then
					current = current + (state.target - current) * (1 - math.exp(-dt * 7))
				elseif current < state.cap then
					current = current + (state.cap - current) * (1 - math.exp(-dt / 5))
				end
			else
				current = math.max(current, 99 * (1 - math.exp(-(now - state.startTime) / 12)))
			end
			percentValue.Value = math.min(current, 99)
		end
		local percent = percentValue.Value
		PercentLabel.Text = string.format("%d%%", math.floor(percent))
		Fill.Size = UDim2.fromScale(percent / 100, 1)

		if not state.finished then
			local dots = string.rep(".", math.floor(now * 3) % 4)
			StatusLabel.Text = state.status .. dots
		end

		-- random hex (rate limited)
		if now - state.lastHex > 0.07 then
			state.lastHex = now
			HexFooter.Text = string.format(
				"0x%s  %s %s  %s  MEM:0x%s",
				randomHex(8),
				randomHex(4),
				randomHex(4),
				randomHex(6),
				randomHex(4)
			)
		end
	end))

	--// API -------------------------------------------------------------------------------
	local Loader = { Gui = shell.Gui, Shell = shell, Destroyed = false }

	-- Loader.FinishEvent:Fire(message) finishes the loader; Loader.Finished fires once the UI is gone
	Loader.FinishEvent = Utility.Signal.new()
	local closed = Utility.Signal.new(true)
	Loader.Finished = closed

	function Loader:SetStatus(text)
		if state.finishing then
			return
		end
		state.status = tostring(text)
	end

	-- `target` = percent to reach quickly, `cap` = slow creep limit while the stage is still running
	function Loader:SetProgress(target, cap)
		if state.finishing then
			return
		end
		state.manualProgress = true
		state.target = math.max(state.target, tonumber(target) or 0)
		state.cap = math.max(state.target, tonumber(cap) or state.target)
	end

	-- kind: "info" | "ok" | "warn" | "error"
	function Loader:Log(text, kind)
		return addLog(tostring(text), kind)
	end

	-- removes the UI immediately, without the exit animation
	function Loader:Destroy()
		if self.Destroyed then
			return
		end
		self.Destroyed = true
		shell:Destroy()
		if Compat.Env.MugiwaraLoader == self then
			Compat.Env.MugiwaraLoader = nil
		end
	end

	function Loader:Finish(message)
		if state.finishing then
			return
		end
		state.finishing = true

		task.spawn(function()
			state.status = "Finalizing"
			addLog("All modules loaded successfully", "ok")

			Tween(percentValue, { Value = 100 }, 0.6)
			task.wait(0.35)
			FillGradient.Color = ColorSequence.new(C.ok)
			local player = Players.LocalPlayer
			addLog(message or ("Access granted. Welcome, " .. (player and player.DisplayName or "player")), "ok")
			task.wait(0.35)

			state.finished = true
			StatusLabel.Text = "Ready"
			StatusLabel.TextColor3 = C.ok
			PulseDot.BackgroundColor3 = C.ok
			scrambleText(Title, config.Title, 0.35)
			task.wait(0.6)

			-- exit: the reverse of the enter, bottom block first, then the card and backdrop
			for index = #Blocks, 1, -1 do
				local block = Blocks[index]
				task.delay((#Blocks - index) * EXIT_STAGGER, function()
					Tween(block, { GroupTransparency = 1, Position = UDim2.fromOffset(0, 12) }, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
					if block == DividerBlock then
						Tween(DividerLine, { Size = UDim2.new(0, 0, 0, 1) }, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
					elseif block == ProgressBlock then
						Tween(BarTrack, { Size = UDim2.new(0, 0, 0, 6) }, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
					end
				end)
			end
			task.wait(#Blocks * EXIT_STAGGER + 0.05)

			shell:Hide(function()
				Loader.Destroyed = true
				if Compat.Env.MugiwaraLoader == Loader then
					Compat.Env.MugiwaraLoader = nil
				end
				closed:Fire()
			end)
		end)
	end

	Loader.FinishEvent:Connect(function(message)
		Loader:Finish(message)
	end)

	-- reachable from other scripts (executor)
	Compat.Env.MugiwaraLoader = Loader
	library._loader = Loader

	--// enter animation ---------------------------------------------------------------------
	shell:Show()

	-- blocks slide up + fade in one after another; the divider and the bar grow as their block shows
	for index, block in ipairs(Blocks) do
		task.delay(0.2 + (index - 1) * ENTER_STAGGER, function()
			if not block.Parent then
				return
			end
			Tween(block, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.5)
			if block == DividerBlock then
				Tween(DividerLine, { Size = DIVIDER_SIZE }, 0.6)
			elseif block == ProgressBlock then
				Tween(BarTrack, { Size = BAR_SIZE }, 0.6)
			end
		end)
	end
	task.delay(0.25, scrambleText, Title, config.Title, 0.9)

	task.delay(0.3, function()
		addLog("Booting " .. config.Title .. ((config.Version and config.Version ~= "") and (" " .. config.Version) or ""), "ok")
	end)

	-- fake log loop, runs until Finish
	task.spawn(function()
		task.wait(0.9)
		local index = 0
		while not state.finishing and shell.Gui.Parent do
			index = index % #config.Logs + 1
			local entry = addLog(config.Logs[index] .. "...", "info")
			task.wait(math.random(40, 95) / 100)
			if state.finishing then
				break
			end

			-- now and then a "warning" so it looks real
			if math.random() < 0.12 then
				completeLog(entry, "RETRY", C.warn)
				task.wait(0.3)
				addLog("Packet timeout, retrying connection", "warn")
			else
				completeLog(entry, "OK", C.ok)
			end
			task.wait(math.random(15, 40) / 100)
		end
	end)

	-- small glitch on the title every few seconds
	task.spawn(function()
		while shell.Gui.Parent and not state.finishing do
			task.wait(math.random(35, 65) / 10)
			if not state.finishing and not state.titleBusy and Title.Parent then
				local original = config.Title
				local position = math.random(1, #original)
				local pick = math.random(1, #SCRAMBLE_CHARS)
				Title.Text = string.sub(original, 1, position - 1) .. string.sub(SCRAMBLE_CHARS, pick, pick) .. string.sub(original, position + 1)
				Title.Position = UDim2.fromOffset(22, 16)
				task.wait(0.06)
				Title.Position = UDim2.fromOffset(19, 16)
				task.wait(0.05)
				Title.Position = UDim2.fromOffset(20, 16)
				Title.Text = original
			end
		end
	end)

	return Loader
end
