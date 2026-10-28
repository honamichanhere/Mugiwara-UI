--// Chat transports: how the Chat element talks to a backend. A transport is a table with:
--//
--//   transport.User                      { UserId, Name, DisplayName }  (who "me" is)
--//   transport:History({ Limit, Before }) -> { Messages, Cursor, More } | nil, error, code
--//   transport:Poll(cursor)               -> { Messages, Cursor }       | nil, error, code  (new messages AND deletions)
--//   transport:Send({ Text, ReplyTo })    -> message                    | nil, error, code
--//   transport:Delete(id)                 -> true                       | nil, error, code
--//   transport:Info()                     -> { Mode, RetentionHours, MaxLength, CooldownMs, Notice } | nil   (optional)
--//   transport:Destroy()                  (optional)
--//
--// `code` is optional: "disabled" (the owner turned the chat off) and "readonly" make the Chat element lock its
--// input instead of reporting a plain connection error. Mode is "on", "readonly" or "off".
--//
--// A message is { Id, UserId, Name, DisplayName, Text, Time (unix seconds), Deleted, Reply = { Id, Name, Text } }.
--// All calls may yield. Ready-made transports: Http (the Cloudflare Worker in server/worker) and Memory (demo).

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Compat = Import("core/Compat")

local Transports = {}

local function localUser()
	local player = Players.LocalPlayer
	return {
		UserId = player and player.UserId or 0,
		Name = player and player.Name or "player",
		DisplayName = player and player.DisplayName or "Player",
	}
end

local function copyMessage(message)
	local copy = table.clone(message)
	if message.Reply then
		copy.Reply = table.clone(message.Reply)
	end
	return copy
end

local function urlEncode(value)
	return (string.gsub(tostring(value), "[^%w%-_%.~]", function(char)
		return string.format("%%%02X", string.byte(char))
	end))
end

--// Http ------------------------------------------------------------------------------------
-- opts: Url (the Worker URL), Channel ("global"), Folder (where the device token is kept)
-- The device token is a random secret stored in <Folder>/chat-token.txt. The server binds your UserId
-- to its hash the first time you send, so nobody else can post as you or delete your messages.
function Transports.Http(opts)
	opts = opts or {}
	if type(opts.Url) ~= "string" or opts.Url == "" then
		error("ChatTransports.Http needs the Url of your chat Worker", 2)
	end

	local base = string.gsub(opts.Url, "/+$", "")
	local channel = opts.Channel or "global"
	local tokenPath = (opts.Folder or "MugiwaraUI") .. "/chat-token.txt"

	local transport = { User = localUser(), Channel = channel }

	local token = Compat.ReadFile(tokenPath)
	if not token or #token < 16 then
		token = string.gsub(HttpService:GenerateGUID(false) .. HttpService:GenerateGUID(false), "-", "")
		Compat.EnsureFolder(opts.Folder or "MugiwaraUI")
		Compat.WriteFile(tokenPath, token)
	end

	local function call(method, path, query, body)
		local url = base .. path
		if query then
			local parts = {}
			for key, value in pairs(query) do
				table.insert(parts, urlEncode(key) .. "=" .. urlEncode(value))
			end
			table.sort(parts)
			url = url .. "?" .. table.concat(parts, "&")
		end

		local response, reason = Compat.HttpRequest({
			Url = url,
			Method = method,
			Headers = body and { ["Content-Type"] = "application/json" } or nil,
			Body = body and HttpService:JSONEncode(body) or nil,
		})
		if not response then
			return nil, reason
		end

		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body or "")
		if not ok then
			decoded = nil
		end
		local failed = (response.StatusCode and response.StatusCode >= 400) or (decoded and decoded.error)
		if failed then
			local code = decoded and decoded.error
			if code == "chat_disabled" then
				code = "disabled"
			elseif code == "chat_readonly" then
				code = "readonly"
			end
			return nil, (decoded and decoded.message) or ("HTTP " .. tostring(response.StatusCode)), code
		end
		return decoded or {}
	end

	local function map(raw)
		local message = {
			Id = raw.id,
			UserId = raw.userId,
			Name = raw.name,
			DisplayName = raw.displayName,
			Text = raw.text or "",
			Time = raw.time,
			Deleted = raw.deleted == true,
		}
		if raw.replyTo then
			message.Reply = { Id = raw.replyTo, Name = raw.replyName, Text = raw.replyText }
		end
		return message
	end

	local function mapAll(list)
		local out = {}
		for _, raw in ipairs(list or {}) do
			table.insert(out, map(raw))
		end
		return out
	end

	function transport:History(options)
		options = options or {}
		local result, reason, code = call("GET", "/v1/history", {
			channel = channel,
			limit = options.Limit or 50,
			before = options.Before,
		})
		if not result then
			return nil, reason, code
		end
		return { Messages = mapAll(result.messages), Cursor = result.rev, More = result.more == true }
	end

	function transport:Poll(cursor)
		local result, reason, code = call("GET", "/v1/poll", { channel = channel, since = cursor or 0 })
		if not result then
			return nil, reason, code
		end
		return { Messages = mapAll(result.messages), Cursor = result.rev }
	end

	function transport:Send(options)
		local result, reason, code = call("POST", "/v1/send", nil, {
			channel = channel,
			userId = self.User.UserId,
			name = self.User.Name,
			displayName = self.User.DisplayName,
			text = options.Text,
			replyTo = options.ReplyTo,
			token = token,
		})
		if not result or not result.message then
			return nil, reason or "Could not send", code
		end
		return map(result.message)
	end

	function transport:Delete(id)
		local result, reason, code = call("POST", "/v1/delete", nil, {
			channel = channel,
			id = id,
			userId = self.User.UserId,
			token = token,
		})
		if not result then
			return nil, reason, code
		end
		return true
	end

	-- the owner's settings: kill switch state, retention, limits and the privacy notice
	function transport:Info()
		local result = call("GET", "/v1/info")
		if not result then
			return nil
		end
		return {
			Mode = result.mode or "on",
			RetentionHours = result.retentionHours,
			MaxLength = result.maxLength,
			CooldownMs = result.cooldownMs,
			Notice = result.notice,
		}
	end

	return transport
end

--// Memory ----------------------------------------------------------------------------------
-- A chat that lives inside this script only: for trying the UI before you have a backend.
-- opts: Bots (default true: a few fake players talk now and then), Seed (messages to start with)
function Transports.Memory(opts)
	opts = opts or {}
	local transport = { User = localUser(), Channel = "memory" }
	local messages, byId = {}, {}
	local rev, nextId = 0, 1
	local alive = true

	local BOTS = {
		{ UserId = 1001, Name = "Zoro_Roronoa", DisplayName = "Zoro" },
		{ UserId = 1002, Name = "Nami_Navigator", DisplayName = "Nami" },
		{ UserId = 1003, Name = "Usopp_Sniper", DisplayName = "Usopp" },
		{ UserId = 1004, Name = "Sanji_Cook", DisplayName = "Sanji" },
	}
	local LINES = {
		"anyone farming right now?",
		"this hub is so smooth",
		"which server are you on?",
		"found a new spot, dm me",
		"lol that boss is free",
		"brb getting food",
		"who wants to team up?",
		"update when?",
	}

	local function add(user, text, replyId)
		rev = rev + 1
		local message = {
			Id = nextId,
			Rev = rev,
			UserId = user.UserId,
			Name = user.Name,
			DisplayName = user.DisplayName,
			Text = text,
			Time = os.time(),
			Deleted = false,
		}
		local original = replyId and byId[replyId]
		if original then
			local preview = original.Deleted and "Message deleted" or string.sub(original.Text, 1, 80)
			message.Reply = { Id = original.Id, Name = original.DisplayName, Text = preview }
		end
		nextId = nextId + 1
		table.insert(messages, message)
		byId[message.Id] = message
		return message
	end

	for index, text in ipairs(opts.Seed or {}) do
		local bot = BOTS[(index - 1) % #BOTS + 1]
		add(bot, text)
	end
	if opts.Seed == nil and opts.Bots ~= false then
		add(BOTS[1], "welcome to the chat!")
		add(BOTS[2], "say something, replies and deleting your own messages work too")
	end

	function transport:History(options)
		options = options or {}
		local limit = options.Limit or 50
		local picked = {}
		for index = #messages, 1, -1 do
			local message = messages[index]
			if not options.Before or message.Id < options.Before then
				table.insert(picked, 1, copyMessage(message))
				if #picked >= limit then
					break
				end
			end
		end
		local more = #picked > 0 and picked[1].Id > 1
		return { Messages = picked, Cursor = rev, More = more }
	end

	function transport:Poll(cursor)
		local changes = {}
		for _, message in ipairs(messages) do
			if message.Rev > (cursor or 0) then
				table.insert(changes, copyMessage(message))
			end
		end
		return { Messages = changes, Cursor = rev }
	end

	function transport:Send(options)
		return copyMessage(add(self.User, options.Text, options.ReplyTo))
	end

	function transport:Delete(id)
		local message = byId[id]
		if not message or message.UserId ~= self.User.UserId then
			return nil, "You can only delete your own messages"
		end
		message.Deleted = true
		message.Text = ""
		rev = rev + 1
		message.Rev = rev
		return true
	end

	-- Posts as another (fake) user. Handy for demos and tests.
	function transport:Say(user, text, replyId)
		return copyMessage(add(user, text, replyId))
	end

	-- Removes any message, whoever wrote it. Handy for demos and tests.
	function transport:Remove(id)
		local message = byId[id]
		if not message then
			return false
		end
		message.Deleted = true
		message.Text = ""
		rev = rev + 1
		message.Rev = rev
		return true
	end

	function transport:Info()
		return { Mode = "on" }
	end

	function transport:Destroy()
		alive = false
	end

	if opts.Bots ~= false then
		task.spawn(function()
			while alive do
				task.wait(math.random(60, 120) / 10)
				if not alive then
					break
				end
				local bot = BOTS[math.random(1, #BOTS)]
				local replyId = (#messages > 0 and math.random() < 0.3) and messages[#messages].Id or nil
				add(bot, LINES[math.random(1, #LINES)], replyId)
			end
		end)
	end

	return transport
end

return Transports
