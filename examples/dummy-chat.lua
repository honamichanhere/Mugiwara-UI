-- Mugiwara UI chat demo.
--
--   CHAT_URL = ""                       offline demo: fake players talk now and then (Memory transport)
--   CHAT_URL = "https://....workers.dev" real chat through your Cloudflare Worker (see server/worker/README.md)
--
-- Names are the Roblox names of whoever runs the script. Click a message to Reply / Copy / Delete (your own)
-- / Mute (someone else's).

local CHAT_URL = ""

local URL = "https://raw.githubusercontent.com/honamichanhere/Mugiwara-UI/main/dist/main.lua"

local function loadLibrary()
	if isfile and readfile and isfile("MugiwaraUI.lua") then
		return loadstring(readfile("MugiwaraUI.lua"))()
	end
	return loadstring(game:HttpGet(URL))()
end

local MugiwaraUI = loadLibrary()

local Window = MugiwaraUI:CreateWindow({
	Title = "Mugiwara Chat",
	Subtitle = CHAT_URL ~= "" and "live" or "offline demo",
	Version = "v1.0.0",
	Icon = "lucide:message-circle",
	Folder = "MugiwaraChat",
	Size = UDim2.fromOffset(660, 480),
})

local ChatTab = Window:Tab({ Title = "Chat", Icon = "lucide:message-circle" })

local transport
if CHAT_URL ~= "" then
	transport = MugiwaraUI.ChatTransports.Http({
		Url = CHAT_URL,
		Channel = "global", -- different channel names are separate rooms
		Folder = "MugiwaraChat", -- the device token lives here
	})
else
	transport = MugiwaraUI.ChatTransports.Memory() -- no backend: a few bots chat with you
end

ChatTab:Chat({
	Title = "Live Chat",
	Transport = transport,
	Height = 320,
	MaxLength = 200,
	BackgroundPoll = 20, -- keep listening (slowly) while the window is hidden, so the toast below can appear
	OnMessage = function(message)
		if not Window.Opened then
			MugiwaraUI:Notify({
				Title = message.DisplayName,
				Content = message.Text,
				Type = "info",
				Duration = 4,
			})
		end
	end,
})

local Info = Window:Tab({ Title = "About", Icon = "lucide:info" })
Info:Paragraph({
	Title = "How it works",
	Desc = "Your Roblox name and avatar are used automatically. History is loaded from the backend, new messages arrive by polling (every few seconds while the chat is open).",
	Icon = "lucide:info",
})
Info:Label({ Title = CHAT_URL ~= "" and ("Backend: " .. CHAT_URL) or "Backend: none (offline demo with fake players)", Icon = "lucide:server" })
