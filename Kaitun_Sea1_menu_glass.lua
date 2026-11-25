--[[
	Kaitun Sea 1 | boot-hardened rewrite
	built from KaitunDump_2753915549.txt and KaitunDump2_2753915549.txt (Delta 1.0.747, PlaceVersion 4632)

	SOURCES
	  dump-verified : place/sea, Data folder layout, quest GUI path and title format, Enemies folder, mob Level
	                  attribute, Combat tool (ToolTip Melee), quests module (118 quests, embedded as DumpQuests),
	                  the remotes the game itself fired during the dump (listed in the ANTI section)
	  KB file       : everything the dump did not contain (command templates, NPC and spawn positions, entrance
	                  pairs). Produced by Kaitun_Collector.luau, or by the Learn button inside this script
	                  (startQuest only)
	  assumption    : the attack input (tool:Activate / screen click) is tried live and kept only if the target's
	                  health really drops. Speed caps and swing gaps of the stealth profiles are uncalibrated.
	  NOT in the dump: the executor function list (every executor call here is feature-detected and pcall'd),
	                  the Validator / Validator2 / CheckTeleportGlitchFix remotes, any startQuest / addPoint /
	                  setSpawn call.
	Anything missing gates its feature visibly (Data tab). Not run by its author.

	REVISION (glass pass): liquid-glass menu (smoked-glass window, frosted tiles, rim light, optional blur behind the
	open menu), no CanvasGroup anymore, a boot pill that is on screen before any other stage runs, the anti hook is
	installed AFTER the menu exists, GUI host re-check, sliders no longer scroll the page under your finger.
	REVISION (menu pass): header FARM switch, draggable K orb, Show HUD, menu scale, menu key box, settings file
	(KaitunCfg_<PlaceId>.json), boss/story quests skipped by default, stuck-mob skip, quest spots learned from
	quests you accept by hand (stored under questPos in the KB file). No new remote names or offsets were added.
	Written without a Lua parser or a game session: nothing here was compiled or run.
]]

if getgenv().KaitunSea1 then
	pcall(getgenv().KaitunSea1.Stop)
end

----------------------------------------------------------------------------------------------------
-- BOOT SAFETY (outside Main, so a crash inside Main can still be shown on screen)
----------------------------------------------------------------------------------------------------
local Boot = { stage = "start", host = "none" }
local function BootStage(s)
	Boot.stage = s
	pcall(function()
		getgenv().KaitunBoot = Boot
	end)
	if Boot.onStage then
		pcall(Boot.onStage, s)
	end
end
local function SafeService(name)
	local ok, svc = pcall(function()
		return game:GetService(name)
	end)
	if ok then
		return svc
	end
	return nil
end
-- parents a ScreenGui to the first host that really accepts it: gethui, CoreGui, PlayerGui
-- first (optional) = host index to try first, later hosts follow and wrap around
local function PlaceGui(gui, first)
	if not first then
		pcall(function()
			if syn and syn.protect_gui then
				syn.protect_gui(gui)
			elseif protect_gui then
				protect_gui(gui)
			end
		end)
	end
	local plr = game:GetService("Players").LocalPlayer
	local hosts = {
		{ "gethui", function()
			return gethui and gethui()
		end },
		{ "CoreGui", function()
			return game:GetService("CoreGui")
		end },
		{ "PlayerGui", function()
			return plr and (plr:FindFirstChildOfClass("PlayerGui") or plr:WaitForChild("PlayerGui", 5))
		end },
	}
	for k = 0, #hosts - 1 do
		local idx = ((first or 1) - 1 + k) % #hosts + 1
		local h = hosts[idx]
		local okH, host = pcall(h[2])
		if okH and host then
			local okP = pcall(function()
				gui.Parent = host
			end)
			if okP and gui.Parent == host then
				Boot.host = h[1]
				Boot.hostIdx = idx
				return true
			end
		end
	end
	return false
end

-- boot pill: a small glass label that exists before KB, anti hook or any other stage runs, so a hang is visible
local function BootPillClose()
	pcall(function()
		if Boot.pillGui then
			Boot.pillGui:Destroy()
			Boot.pillGui, Boot.pill = nil, nil
		end
	end)
end
local function BootPill(text)
	pcall(function()
		if not Boot.pillGui then
			local g = Instance.new("ScreenGui")
			g.Name = "KaitunBootPill"
			g.ResetOnSpawn = false
			g.IgnoreGuiInset = true
			g.DisplayOrder = 998
			local l = Instance.new("TextLabel")
			l.AnchorPoint = Vector2.new(0.5, 0)
			l.Position = UDim2.new(0.5, 0, 0, 10)
			l.Size = UDim2.fromOffset(300, 32)
			l.BackgroundColor3 = Color3.fromRGB(22, 19, 42)
			l.BackgroundTransparency = 0.25
			l.BorderSizePixel = 0
			l.TextColor3 = Color3.fromRGB(248, 245, 255)
			l.Font = Enum.Font.GothamSemibold
			l.TextSize = 14
			l.Parent = g
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 16)
			c.Parent = l
			local s = Instance.new("UIStroke")
			s.Color = Color3.new(1, 1, 1)
			s.Transparency = 0.5
			s.Thickness = 1.25
			s.Parent = l
			if not PlaceGui(g) then
				return
			end
			Boot.pillGui, Boot.pill = g, l
		end
		Boot.pill.Text = text
	end)
end
Boot.onStage = function(s)
	if s == "ready" then
		BootPillClose()
	else
		BootPill("kaitun  ~  " .. s)
	end
end
local function Notify(title, text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = title, Text = text, Duration = 8 })
	end)
end
local function ShowFatal(err)
	local text = "kaitun failed at stage '" .. Boot.stage .. "'\n" .. tostring(err)
	pcall(function()
		if writefile then
			writefile("KaitunBoot.log", text)
		end
	end)
	pcall(function()
		local g = Instance.new("ScreenGui")
		g.Name = "KaitunFatal"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 1000
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -24, 0, 200)
		b.Position = UDim2.fromOffset(12, 60)
		b.BackgroundColor3 = Color3.fromRGB(40, 12, 24)
		b.TextColor3 = Color3.fromRGB(255, 200, 220)
		b.TextWrapped = true
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextYAlignment = Enum.TextYAlignment.Top
		b.TextSize = 13
		b.Font = Enum.Font.Code
		b.Text = string.sub(text, 1, 900) .. "\n(tap to close, full text in KaitunBoot.log)"
		b.Parent = g
		b.MouseButton1Click:Connect(function()
			g:Destroy()
		end)
		PlaceGui(g)
	end)
	Notify("kaitun", "failed at stage: " .. Boot.stage)
	BootPill("kaitun failed at: " .. Boot.stage)
end

local function Main()

	----------------------------------------------------------------------------------------------------
	-- CONFIG
	----------------------------------------------------------------------------------------------------
	local Defaults = {
		Team = "Pirates",
		AutoFarm = true,
		AutoStats = true,
		MeleePercent = 50, -- rest goes to Defense
		AutoSpawn = true,
		AntiAFK = true,
		AutoRejoin = true,
		AntiKick = true,
		WhiteScreen = false,
		FPS = 0, -- 0 = untouched
		MenuKey = "RightShift",
		BaseSpeed = 200, -- studs/s, uncalibrated
		SpeedPercent = 100,
		AdaptiveSpeed = true,
		ArriveRadius = 12,
		MeleeRange = 4,
		Hover = 0,
		LevelMargin = 5, -- quest-less mode: farm mobs up to Level + margin
		BringMobs = true,
		SkipBossQuests = true, -- skips quests with 1 target (bosses) or 50 targets (story lines), counts from DumpQuests
		ShowHud = true,
		GlassBlur = true, -- blur the game behind the open menu
		UIScale = 100, -- percent, menu window only
		Stealth = "Light", -- Off | Light | Heavy, see Profiles
		Block = { Validator = false, Validator2 = false, CheckTeleportGlitchFix = false },
		Music = { Enabled = false, Id = "", Volume = 0.5 },
	}
	local function Merge(dst, src)
		for k, v in pairs(src) do
			if type(v) == "table" then
				if type(dst[k]) ~= "table" then
					dst[k] = {}
				end
				Merge(dst[k], v)
			elseif dst[k] == nil then
				dst[k] = v
			end
		end
	end
	local Cfg = getgenv().KaitunCfg or {}
	getgenv().KaitunCfg = Cfg
	local CfgFile = "KaitunCfg_" .. tostring(game.PlaceId) .. ".json"
	if next(Cfg) == nil then
		local okF, saved = pcall(function()
			if isfile and readfile and isfile(CfgFile) then
				return game:GetService("HttpService"):JSONDecode(readfile(CfgFile))
			end
			return nil
		end)
		if okF and type(saved) == "table" then
			for k, v in pairs(saved) do
				Cfg[k] = v
			end
		end
	end
	Merge(Cfg, Defaults)

	----------------------------------------------------------------------------------------------------
	-- BOOT (never blocks: the menu is built before anything can hang)
	----------------------------------------------------------------------------------------------------
	BootStage("waiting for game")
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local Players = game:GetService("Players")
	while not Players.LocalPlayer do
		task.wait()
	end
	local LocalPlayer = Players.LocalPlayer
	BootStage("services")
	local TweenService = game:GetService("TweenService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local TeleportService = game:GetService("TeleportService")
	local HttpService = game:GetService("HttpService")
	local SoundService = SafeService("SoundService")
	local VirtualUser = SafeService("VirtualUser")
	local VirtualInputManager = SafeService("VirtualInputManager")
	local CoreGui = SafeService("CoreGui")

	local SeaOk = game.PlaceId == 2753915549 -- Sea 1, from the dump
	local Running = true
	local T0 = os.clock()
	local Conns = {}
	local function Bind(signal, fn)
		local c = signal:Connect(fn)
		Conns[#Conns + 1] = c
		return c
	end
	local LastSaved = ""
	local function SaveCfg(force)
		if not writefile then
			return false
		end
		local okS = pcall(function()
			local s = HttpService:JSONEncode(Cfg)
			if force or s ~= LastSaved then
				writefile(CfgFile, s)
				LastSaved = s
			end
		end)
		return okS
	end

	-- lazy proxy, callers are pcall'd (Data may not exist yet)
	local D = setmetatable({}, {
		__index = function(_, k)
			return LocalPlayer.Data[k]
		end,
	})
	local MaxLevel = LocalPlayer:GetAttribute("LevelCap") or 2800 -- dump: LevelCap = 2800

	local LogLines, LogHooks = {}, {}
	local function Log(msg)
		local line = string.format("[%s] %s", os.date("%H:%M:%S"), msg)
		LogLines[#LogLines + 1] = line
		if #LogLines > 80 then
			table.remove(LogLines, 1)
		end
		print("[kaitun] " .. msg)
		for _, f in ipairs(LogHooks) do
			pcall(f, line)
		end
	end
	local Status = { Task = "Booting", Sub = "" }
	local function SetTask(t, sub)
		if Status.Task ~= t then
			Status.Task = t
			Log(t)
		end
		if sub ~= nil then
			Status.Sub = sub
		end
	end
	local function SetSub(s)
		Status.Sub = s
	end
	local function Commas(n)
		local s = tostring(math.floor(tonumber(n) or 0))
		local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (r:gsub("^,", ""))
	end

	pcall(function()
		sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
	end)

	----------------------------------------------------------------------------------------------------
	-- KNOWLEDGE BASE (file written by the Collector)
	----------------------------------------------------------------------------------------------------
	local KB = { cmd = {}, quests = {}, npcs = {}, spawns = {}, enemies = {}, entrances = {}, notes = {}, questPos = {} }
	local KBSource = "none"

	local function Revive(v)
		if type(v) == "table" then
			if v["$v3"] then
				return Vector3.new(v.x, v.y, v.z)
			end
			local o = {}
			for k, x in pairs(v) do
				o[k] = Revive(x)
			end
			return o
		end
		return v
	end

	-- quests module of the game, parsed from KaitunDump2 (118 entries, PlaceVersion 4632). Names and levels only:
	-- NPC positions and the start command are not in the dump.
	local DumpQuests = {
		{ key = "BanditQuest1", idx = 1, minLevel = 0, mob = "Bandit", count = 5 },
		{ key = "MarineQuest", idx = 1, minLevel = 0, mob = "Trainee", count = 5 },
		{ key = "JungleQuest", idx = 1, minLevel = 10, mob = "Monkey", count = 6 },
		{ key = "JungleQuest", idx = 2, minLevel = 15, mob = "Gorilla", count = 8 },
		{ key = "JungleQuest", idx = 3, minLevel = 20, mob = "The Gorilla King", count = 1 },
		{ key = "BuggyQuest1", idx = 1, minLevel = 30, mob = "Pirate", count = 8 },
		{ key = "BuggyQuest1", idx = 2, minLevel = 40, mob = "Brute", count = 8 },
		{ key = "BuggyQuest1", idx = 3, minLevel = 55, mob = "Chef", count = 1 },
		{ key = "DesertQuest", idx = 1, minLevel = 60, mob = "Desert Bandit", count = 8 },
		{ key = "DesertQuest", idx = 2, minLevel = 75, mob = "Desert Officer", count = 6 },
		{ key = "SnowQuest", idx = 1, minLevel = 90, mob = "Snow Bandit", count = 7 },
		{ key = "SnowQuest", idx = 2, minLevel = 100, mob = "Snowman", count = 8 },
		{ key = "SnowQuest", idx = 3, minLevel = 105, mob = "Yeti", count = 1 },
		{ key = "MarineQuest2", idx = 1, minLevel = 120, mob = "Chief Petty Officer", count = 8 },
		{ key = "MarineQuest2", idx = 2, minLevel = 130, mob = "Vice Admiral", count = 1 },
		{ key = "SkyQuest", idx = 1, minLevel = 150, mob = "Sky Bandit", count = 7 },
		{ key = "SkyQuest", idx = 2, minLevel = 175, mob = "Dark Master", count = 8 },
		{ key = "PrisonerQuest", idx = 1, minLevel = 190, mob = "Prisoner", count = 8 },
		{ key = "PrisonerQuest", idx = 2, minLevel = 210, mob = "Dangerous Prisoner", count = 8 },
		{ key = "ImpelQuest", idx = 1, minLevel = 225, mob = "Ruthless Prisoner", count = 8 },
		{ key = "ImpelQuest", idx = 2, minLevel = 230, mob = "Warden", count = 1 },
		{ key = "ColosseumQuest", idx = 1, minLevel = 250, mob = "Toga Warrior", count = 7 },
		{ key = "ColosseumQuest", idx = 2, minLevel = 275, mob = "Gladiator", count = 8 },
		{ key = "MagmaQuest", idx = 1, minLevel = 300, mob = "Military Soldier", count = 7 },
		{ key = "MagmaQuest", idx = 2, minLevel = 325, mob = "Military Spy", count = 8 },
		{ key = "MagmaQuest", idx = 3, minLevel = 350, mob = "Magma Admiral", count = 1 },
		{ key = "FishmanQuest", idx = 1, minLevel = 375, mob = "Fishman Warrior", count = 8 },
		{ key = "FishmanQuest", idx = 2, minLevel = 400, mob = "Fishman Commando", count = 7 },
		{ key = "FishmanQuest", idx = 3, minLevel = 425, mob = "Fishman Lord", count = 1 },
		{ key = "SkyExp1Quest", idx = 1, minLevel = 450, mob = "God's Guard", count = 7 },
		{ key = "SkyExp1Quest", idx = 2, minLevel = 475, mob = "Shanda", count = 9 },
		{ key = "SkyExp1Quest", idx = 3, minLevel = 500, mob = "Wysper", count = 1 },
		{ key = "SkyExp2Quest", idx = 1, minLevel = 525, mob = "Royal Squad", count = 8 },
		{ key = "SkyExp2Quest", idx = 2, minLevel = 550, mob = "Royal Soldier", count = 8 },
		{ key = "SkyExp2Quest", idx = 3, minLevel = 575, mob = "Thunder God", count = 1 },
		{ key = "FountainQuest", idx = 1, minLevel = 625, mob = "Galley Pirate", count = 8 },
		{ key = "FountainQuest", idx = 2, minLevel = 650, mob = "Galley Captain", count = 9 },
		{ key = "FountainQuest", idx = 3, minLevel = 675, mob = "Cyborg", count = 1 },
		{ key = "Area1Quest", idx = 1, minLevel = 700, mob = "Raider", count = 8 },
		{ key = "Area1Quest", idx = 2, minLevel = 725, mob = "Mercenary", count = 8 },
		{ key = "Area1Quest", idx = 3, minLevel = 750, mob = "Diamond", count = 1 },
		{ key = "Area2Quest", idx = 1, minLevel = 775, mob = "Swan Pirate", count = 8 },
		{ key = "Area2Quest", idx = 2, minLevel = 800, mob = "Factory Staff", count = 8 },
		{ key = "Area2Quest", idx = 3, minLevel = 850, mob = "Jeremy", count = 1 },
		{ key = "BartiloQuest", idx = 1, minLevel = 850, mob = "Swan Pirate", count = 50 },
		{ key = "MarineQuest3", idx = 1, minLevel = 875, mob = "Marine Lieutenant", count = 8 },
		{ key = "MarineQuest3", idx = 2, minLevel = 900, mob = "Marine Captain", count = 9 },
		{ key = "MarineQuest3", idx = 3, minLevel = 925, mob = "Orbitus", count = 1 },
		{ key = "ZombieQuest", idx = 1, minLevel = 950, mob = "Zombie", count = 8 },
		{ key = "ZombieQuest", idx = 2, minLevel = 975, mob = "Vampire", count = 8 },
		{ key = "SnowMountainQuest", idx = 1, minLevel = 1000, mob = "Snow Trooper", count = 8 },
		{ key = "SnowMountainQuest", idx = 2, minLevel = 1050, mob = "Winter Warrior", count = 9 },
		{ key = "IceSideQuest", idx = 1, minLevel = 1100, mob = "Lab Subordinate", count = 8 },
		{ key = "IceSideQuest", idx = 2, minLevel = 1125, mob = "Horned Warrior", count = 9 },
		{ key = "IceSideQuest", idx = 3, minLevel = 1150, mob = "Smoke Admiral", count = 1 },
		{ key = "FireSideQuest", idx = 1, minLevel = 1175, mob = "Magma Ninja", count = 8 },
		{ key = "FireSideQuest", idx = 2, minLevel = 1200, mob = "Lava Pirate", count = 8 },
		{ key = "ShipQuest1", idx = 1, minLevel = 1250, mob = "Ship Deckhand", count = 8 },
		{ key = "ShipQuest1", idx = 2, minLevel = 1275, mob = "Ship Engineer", count = 8 },
		{ key = "ShipQuest2", idx = 1, minLevel = 1300, mob = "Ship Steward", count = 8 },
		{ key = "ShipQuest2", idx = 2, minLevel = 1325, mob = "Ship Officer", count = 8 },
		{ key = "FrostQuest", idx = 1, minLevel = 1350, mob = "Arctic Warrior", count = 8 },
		{ key = "FrostQuest", idx = 2, minLevel = 1375, mob = "Snow Lurker", count = 8 },
		{ key = "FrostQuest", idx = 3, minLevel = 1400, mob = "Awakened Ice Admiral", count = 1 },
		{ key = "ForgottenQuest", idx = 1, minLevel = 1425, mob = "Sea Soldier", count = 8 },
		{ key = "ForgottenQuest", idx = 2, minLevel = 1450, mob = "Water Fighter", count = 8 },
		{ key = "ForgottenQuest", idx = 3, minLevel = 1475, mob = "Tide Keeper", count = 1 },
		{ key = "PiratePortQuest", idx = 1, minLevel = 1500, mob = "Pirate Millionaire", count = 8 },
		{ key = "PiratePortQuest", idx = 2, minLevel = 1525, mob = "Pistol Billionaire", count = 8 },
		{ key = "PiratePortQuest", idx = 3, minLevel = 1550, mob = "Stone", count = 1 },
		{ key = "DragonCrewQuest", idx = 1, minLevel = 1575, mob = "Dragon Crew Warrior", count = 8 },
		{ key = "DragonCrewQuest", idx = 2, minLevel = 1600, mob = "Dragon Crew Archer", count = 8 },
		{ key = "VenomCrewQuest", idx = 1, minLevel = 1625, mob = "Hydra Enforcer", count = 8 },
		{ key = "VenomCrewQuest", idx = 2, minLevel = 1650, mob = "Venomous Assailant", count = 8 },
		{ key = "VenomCrewQuest", idx = 3, minLevel = 1675, mob = "Hydra Leader", count = 1 },
		{ key = "MarineTreeIsland", idx = 1, minLevel = 1700, mob = "Marine Commodore", count = 8 },
		{ key = "MarineTreeIsland", idx = 2, minLevel = 1725, mob = "Marine Rear Admiral", count = 8 },
		{ key = "MarineTreeIsland", idx = 3, minLevel = 1750, mob = "Kilo Admiral", count = 1 },
		{ key = "DeepForestIsland3", idx = 1, minLevel = 1775, mob = "Fishman Raider", count = 8 },
		{ key = "CitizenQuest", idx = 1, minLevel = 1800, mob = "Forest Pirate", count = 50 },
		{ key = "DeepForestIsland3", idx = 2, minLevel = 1800, mob = "Fishman Captain", count = 8 },
		{ key = "DeepForestIsland", idx = 1, minLevel = 1825, mob = "Forest Pirate", count = 8 },
		{ key = "DeepForestIsland", idx = 2, minLevel = 1850, mob = "Mythological Pirate", count = 8 },
		{ key = "DeepForestIsland", idx = 3, minLevel = 1875, mob = "Captain Elephant", count = 1 },
		{ key = "DeepForestIsland2", idx = 1, minLevel = 1900, mob = "Jungle Pirate", count = 8 },
		{ key = "DeepForestIsland2", idx = 2, minLevel = 1925, mob = "Musketeer Pirate", count = 8 },
		{ key = "DeepForestIsland2", idx = 3, minLevel = 1950, mob = "Beautiful Pirate", count = 1 },
		{ key = "HauntedQuest1", idx = 1, minLevel = 1975, mob = "Reborn Skeleton", count = 8 },
		{ key = "HauntedQuest1", idx = 2, minLevel = 2000, mob = "Living Zombie", count = 8 },
		{ key = "HauntedQuest2", idx = 1, minLevel = 2025, mob = "Demonic Soul", count = 8 },
		{ key = "HauntedQuest2", idx = 2, minLevel = 2050, mob = "Posessed Mummy", count = 8 },
		{ key = "NutsIslandQuest", idx = 1, minLevel = 2075, mob = "Peanut Scout", count = 8 },
		{ key = "NutsIslandQuest", idx = 2, minLevel = 2100, mob = "Peanut President", count = 8 },
		{ key = "IceCreamIslandQuest", idx = 1, minLevel = 2125, mob = "Ice Cream Chef", count = 8 },
		{ key = "IceCreamIslandQuest", idx = 2, minLevel = 2150, mob = "Ice Cream Commander", count = 8 },
		{ key = "IceCreamIslandQuest", idx = 3, minLevel = 2175, mob = "Cake Queen", count = 1 },
		{ key = "CakeQuest1", idx = 1, minLevel = 2200, mob = "Cookie Crafter", count = 8 },
		{ key = "CakeQuest1", idx = 2, minLevel = 2225, mob = "Cake Guard", count = 8 },
		{ key = "CakeQuest2", idx = 1, minLevel = 2250, mob = "Baking Staff", count = 8 },
		{ key = "CakeQuest2", idx = 2, minLevel = 2275, mob = "Head Baker", count = 8 },
		{ key = "ChocQuest1", idx = 1, minLevel = 2300, mob = "Cocoa Warrior", count = 8 },
		{ key = "ChocQuest1", idx = 2, minLevel = 2325, mob = "Chocolate Bar Battler", count = 8 },
		{ key = "ChocQuest2", idx = 1, minLevel = 2350, mob = "Sweet Thief", count = 8 },
		{ key = "ChocQuest2", idx = 2, minLevel = 2375, mob = "Candy Rebel", count = 8 },
		{ key = "CandyQuest1", idx = 1, minLevel = 2400, mob = "Candy Pirate", count = 8 },
		{ key = "CandyQuest1", idx = 2, minLevel = 2425, mob = "Snow Demon", count = 8 },
		{ key = "TikiQuest1", idx = 1, minLevel = 2450, mob = "Isle Outlaw", count = 8 },
		{ key = "TikiQuest1", idx = 2, minLevel = 2475, mob = "Island Boy", count = 8 },
		{ key = "TikiQuest2", idx = 1, minLevel = 2500, mob = "Sun-kissed Warrior", count = 8 },
		{ key = "TikiQuest2", idx = 2, minLevel = 2525, mob = "Isle Champion", count = 8 },
		{ key = "TikiQuest3", idx = 1, minLevel = 2550, mob = "Serpent Hunter", count = 8 },
		{ key = "TikiQuest3", idx = 2, minLevel = 2575, mob = "Skull Slayer", count = 8 },
		{ key = "SubmergedQuest1", idx = 1, minLevel = 2600, mob = "Reef Bandit", count = 8 },
		{ key = "SubmergedQuest1", idx = 2, minLevel = 2625, mob = "Coral Pirate", count = 8 },
		{ key = "SubmergedQuest2", idx = 1, minLevel = 2650, mob = "Sea Chanter", count = 8 },
		{ key = "SubmergedQuest2", idx = 2, minLevel = 2675, mob = "Ocean Prophet", count = 8 },
		{ key = "SubmergedQuest3", idx = 1, minLevel = 2675, mob = "High Disciple", count = 8 },
		{ key = "SubmergedQuest3", idx = 2, minLevel = 2700, mob = "Grand Devotee", count = 8 },
	}

	local function MergeDumpQuests()
		local have = {}
		for _, q in ipairs(KB.quests) do
			have[tostring(q.key) .. "#" .. tostring(q.idx)] = true
		end
		local added = 0
		for _, q in ipairs(DumpQuests) do
			if not have[q.key .. "#" .. q.idx] then
				KB.quests[#KB.quests + 1] = { key = q.key, idx = q.idx, minLevel = q.minLevel, mob = q.mob, count = q.count, fromDump = true }
				added = added + 1
			end
		end
		if added > 0 then
			Log("quest list: +" .. added .. " from the embedded dump")
		end
	end

	local function LoadKB()
		local data = nil
		KBSource = "none"
		if type(getgenv().KaitunKB) == "table" then
			data = getgenv().KaitunKB
			KBSource = "getgenv().KaitunKB"
		else
			local name = "KaitunKB_" .. game.PlaceId .. ".json"
			if isfile and readfile and isfile(name) then
				local ok, res = pcall(function()
					return HttpService:JSONDecode(readfile(name))
				end)
				if ok and type(res) == "table" then
					data = Revive(res)
					KBSource = name
				end
			end
		end
		if data then
			for k in pairs(KB) do
				if type(data[k]) == "table" then
					KB[k] = data[k]
				end
			end
			Log("KB loaded from " .. KBSource)
		else
			Log("no KB file (run Kaitun_Collector.luau)")
		end
		MergeDumpQuests()
	end
	BootStage("kb")
	LoadKB()

	-- Sea 1 entrance pair read from ReplicatedStorage.GuideModule.TeleportQuests in the dump:
	-- stand on the first point, the second is where it leads.
	local Entrances = { { src = Vector3.new(4050.311, -1.688, -1814.124), dst = Vector3.new(61170.047, -2, 1952.834) } }
	local function AllEntrances()
		local out = {}
		for _, e in ipairs(Entrances) do
			out[#out + 1] = e
		end
		for _, e in ipairs(KB.entrances) do
			if typeof(e.src) == "Vector3" and typeof(e.dst) == "Vector3" then
				out[#out + 1] = e
			end
		end
		return out
	end

	local function ResolveRemote(path)
		if type(path) ~= "string" then
			return nil
		end
		local inst = nil
		for part in path:gmatch("[^%.]+") do
			if not inst then
				local ok, svc = pcall(function()
					return game:GetService(part)
				end)
				inst = ok and svc or game:FindFirstChild(part)
			else
				inst = inst:FindFirstChild(part)
			end
			if not inst then
				return nil
			end
		end
		return inst
	end

	local function CallCmd(name, vars)
		local tpl = KB.cmd[name]
		local remote = ResolveRemote(KB.cmd[name .. "Remote"])
		if type(tpl) ~= "table" or not remote then
			return false, "unknown command: " .. name
		end
		local args = {}
		for i, v in ipairs(tpl) do
			if type(v) == "string" and vars and vars[v] ~= nil then
				args[i] = vars[v]
			else
				args[i] = v
			end
		end
		local ok, res = pcall(function()
			if remote:IsA("RemoteFunction") then
				return remote:InvokeServer(table.unpack(args, 1, #tpl))
			end
			remote:FireServer(table.unpack(args, 1, #tpl))
			return true
		end)
		return ok, res
	end

	----------------------------------------------------------------------------------------------------
	-- ANTI (kick guard, observer for every client remote call, opt-in blocks by name)
	----------------------------------------------------------------------------------------------------
	-- dump-verified (KaitunDump2, PlaceVersion 4632), fired by the game's own scripts and left untouched by default:
	--   Net.RE/InputTelemetry                   input event batches, roughly every 2 s
	--   Remotes.Clock.DelayedRequestFunction    clock probe, roughly every 2 s
	--   Net.RE/RegisterAttack (0.5, 1)          once per swing
	-- NOT in that dump: Validator, Validator2, CheckTeleportGlitchFix. The names come from an earlier dump and their
	-- effect is unknown, so they stay watch-only until a toggle is switched on by hand.
	-- Server-side kicks cannot be stopped from the client; AutoRejoin covers those.
	BootStage("anti")
	local Anti = getgenv().KaitunAnti3
	if not Anti then
		Anti = { Block = {}, Seen = {}, Blocked = 0, Kicked = 0, Kick = true, Installed = false, Learn = nil }
		getgenv().KaitunAnti3 = Anti
	end
	Anti.LP = LocalPlayer
	local function SyncAnti()
		Anti.Kick = Cfg.AntiKick
		local b = {}
		for n, v in pairs(Cfg.Block) do
			if v == true then
				b[n] = true
			end
		end
		Anti.Block = b
	end
	SyncAnti()
	local function InstallAnti()
		if Anti.Installed then
			return true
		end
		if not (hookmetamethod and getnamecallmethod and newcclosure) then
			return false, "executor lacks hookmetamethod / getnamecallmethod / newcclosure"
		end
		local ok, err = pcall(function()
			local old
			old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
				local method = getnamecallmethod()
				if method == "FireServer" or method == "InvokeServer" then
					if typeof(self) == "Instance" and not (checkcaller and checkcaller()) then
						local nm = self.Name
						Anti.Seen[nm] = (Anti.Seen[nm] or 0) + 1
						local W = Anti.Watch
						if W then
							pcall(W, self, nm, ...)
						end
						local L = Anti.Learn
						if L then
							pcall(L.push, self, nm, ...)
						end
						if Anti.Block[nm] then
							Anti.Blocked = Anti.Blocked + 1
							return nil
						end
					end
				elseif Anti.Kick and (method == "Kick" or method == "kick") and rawequal(self, Anti.LP) then
					Anti.Kicked = Anti.Kicked + 1
					return nil
				end
				if setnamecallmethod then
					setnamecallmethod(method)
				end
				return old(self, ...)
			end))
		end)
		if ok then
			Anti.Installed = true
			return true
		end
		return false, tostring(err)
	end
	-- InstallAnti() runs after the menu is on screen (see the end of Main), so a hook problem can never hide the menu

	----------------------------------------------------------------------------------------------------
	-- HELPERS
	----------------------------------------------------------------------------------------------------
	local function Root()
		local c = LocalPlayer.Character
		return c and c:FindFirstChild("HumanoidRootPart")
	end
	local function Alive()
		local c = LocalPlayer.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if h and h.Health > 0 and r then
			return r
		end
		return nil
	end

	-- dump: PlayerGui.Main.Quest.Container.QuestTitle.Title, text like "DEFEAT 5 BANDITS (0/5)"
	local function QuestState()
		local ok, q = pcall(function()
			return LocalPlayer.PlayerGui.Main.Quest
		end)
		if not ok or not q then
			return nil
		end
		local c = q:FindFirstChild("Container")
		local qt = c and c:FindFirstChild("QuestTitle")
		local t = qt and qt:FindFirstChild("Title")
		local text = t and t.Text or ""
		local cur, need = text:match("%((%d+)/(%d+)%)")
		return { visible = q.Visible, text = text, cur = tonumber(cur), need = tonumber(need) }
	end
	local function TitleHasMob(text, mob)
		return text ~= "" and mob ~= nil and string.find(text:lower(), mob:lower(), 1, true) ~= nil
	end

	local function MobRoot(m)
		local h = m:FindFirstChildOfClass("Humanoid")
		local r = m:FindFirstChild("HumanoidRootPart")
		if h and r and h.Health > 0 then
			return r
		end
		return nil
	end

	local MobSkip = {} -- [mob instance] = os.clock() until which it is ignored (stuck watchdog)
	local function NearestEnemy(name)
		local folder = workspace:FindFirstChild("Enemies")
		local me = Root()
		if not (folder and me) then
			return nil
		end
		local best, bestD = nil, math.huge
		for _, m in ipairs(folder:GetChildren()) do
			if m.Name == name and not (MobSkip[m] and MobSkip[m] > os.clock()) then
				local r = MobRoot(m)
				if r then
					local d = (r.Position - me.Position).Magnitude
					if d < bestD then
						best, bestD = m, d
					end
				end
			end
		end
		return best
	end

	local function MobCenter(name)
		local sum, n = Vector3.zero, 0
		local folder = workspace:FindFirstChild("Enemies")
		if folder then
			for _, m in ipairs(folder:GetChildren()) do
				if m.Name == name then
					local r = MobRoot(m)
					if r then
						sum = sum + r.Position
						n = n + 1
					end
				end
			end
		end
		if n > 0 then
			return sum / n
		end
		local sp = KB.spawns[name]
		if type(sp) == "table" and #sp > 0 then
			for _, p in ipairs(sp) do
				if typeof(p) == "Vector3" then
					sum = sum + p
					n = n + 1
				end
			end
			if n > 0 then
				return sum / n
			end
		end
		local e = KB.enemies[name]
		if type(e) == "table" and typeof(e.pos) == "Vector3" then
			return e.pos
		end
		return nil
	end

	----------------------------------------------------------------------------------------------------
	-- MOVEMENT (waypoint tween, short final snap, rubber-band detector that slows itself down)
	----------------------------------------------------------------------------------------------------
	-- STEALTH PROFILES: all numbers are uncalibrated starting points, tune them from the Anti tab.
	-- Off keeps the old behaviour. Light caps flight speed and jitters the swing gap. Heavy also takes short breaks.
	local Profiles = {
		Off = { cap = math.huge, swingMin = 0.12, swingMax = 0.12, pause = false },
		Light = { cap = 160, swingMin = 0.10, swingMax = 0.24, pause = false },
		Heavy = { cap = 120, swingMin = 0.16, swingMax = 0.40, pause = true },
	}
	local ProfileOrder = { "Off", "Light", "Heavy" }
	local Pace = { gap = 0.12, last = 0, pauseUntil = 0, nextPause = os.clock() + 60 }
	local function Profile()
		return Profiles[Cfg.Stealth] or Profiles.Light
	end

	local ActiveTween, MoveTarget, LastEntrance = nil, nil, 0
	local SpeedScale, RubberCount, MoveSpeed, LastGood = 1, 0, Cfg.BaseSpeed, os.clock()

	local function CancelMove()
		if ActiveTween then
			ActiveTween:Cancel()
			ActiveTween = nil
		end
		MoveTarget = nil
	end
	local function EnsureFixVelo(hrp)
		if not hrp:FindFirstChild("fixvelo") then
			local bv = Instance.new("BodyVelocity")
			bv.Name = "fixvelo"
			bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			bv.Velocity = Vector3.zero
			bv.Parent = hrp
		end
	end

	-- one tween leg; returns true when within ArriveRadius (then snaps the last few studs)
	local function Steer(hrp, target)
		local dist = (hrp.Position - target.Position).Magnitude
		if dist <= Cfg.ArriveRadius then
			CancelMove()
			hrp.CFrame = target
			return true
		end
		if MoveTarget and (MoveTarget - target.Position).Magnitude > 25 then
			CancelMove()
		end
		if not (ActiveTween and ActiveTween.PlaybackState == Enum.PlaybackState.Playing) then
			local speed = math.max(40, math.min(Cfg.BaseSpeed * SpeedScale * (Cfg.SpeedPercent / 100), Profile().cap))
			MoveSpeed = speed
			MoveTarget = target.Position
			ActiveTween = TweenService:Create(hrp, TweenInfo.new(dist / speed, Enum.EasingStyle.Linear), { CFrame = target })
			ActiveTween:Play()
		end
		return false
	end

	local function MoveTo(target)
		local hrp = Alive()
		if not hrp then
			return false
		end
		EnsureFixVelo(hrp)
		local hum = hrp.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Sit then
			hum.Sit = false
		end
		local dist = (hrp.Position - target.Position).Magnitude
		if KB.cmd.requestEntrance and dist > 2500 then
			local best, bestCost = nil, dist - 500
			for _, e in ipairs(AllEntrances()) do
				local cost = (hrp.Position - e.src).Magnitude + (e.dst - target.Position).Magnitude
				if cost < bestCost then
					best, bestCost = e, cost
				end
			end
			if best then
				if (hrp.Position - best.src).Magnitude <= 20 then
					if os.clock() - LastEntrance > 3 then
						LastEntrance = os.clock()
						CancelMove()
						SetSub("Using entrance")
						CallCmd("requestEntrance", { ["{pos}"] = best.dst })
					end
					return false
				end
				Steer(hrp, CFrame.new(best.src))
				return false
			end
		end
		return Steer(hrp, target)
	end

	do
		local LastPos = nil
		Bind(RunService.Heartbeat, function(dt)
			local hrp = Root()
			if not hrp then
				LastPos = nil
				return
			end
			local p = hrp.Position
			if ActiveTween and ActiveTween.PlaybackState == Enum.PlaybackState.Playing then
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
			if ActiveTween and ActiveTween.PlaybackState == Enum.PlaybackState.Playing and LastPos and MoveTarget and os.clock() - LastEntrance > 2 then
				local jump = (p - LastPos).Magnitude
				if jump > MoveSpeed * dt * 4 + 20 and (p - MoveTarget).Magnitude > (LastPos - MoveTarget).Magnitude + 15 then
					RubberCount = RubberCount + 1
					LastGood = os.clock()
					if Cfg.AdaptiveSpeed then
						SpeedScale = math.max(0.45, SpeedScale * 0.85)
					end
					Log(string.format("rubber-band #%d: pulled back %.0f studs, speed scale %.2f", RubberCount, jump, SpeedScale))
					CancelMove()
				end
			end
			if SpeedScale < 1 and os.clock() - LastGood > 15 then
				SpeedScale = math.min(1, SpeedScale * 1.05)
				LastGood = os.clock() - 10
			end
			LastPos = p
		end)
	end

	----------------------------------------------------------------------------------------------------
	-- COMBAT (input goes through the game's own combat; the backend is verified by real damage)
	----------------------------------------------------------------------------------------------------
	local function EquipMelee()
		local c = LocalPlayer.Character
		if not c then
			return nil
		end
		for _, t in ipairs(c:GetChildren()) do
			if t:IsA("Tool") and t.ToolTip == "Melee" then
				return t
			end
		end
		local bp = LocalPlayer:FindFirstChild("Backpack")
		local hum = c:FindFirstChildOfClass("Humanoid")
		if bp and hum then
			for _, t in ipairs(bp:GetChildren()) do
				if t:IsA("Tool") and t.ToolTip == "Melee" then
					hum:EquipTool(t)
					return t
				end
			end
		end
		return nil
	end

	local Backends = {
		{ name = "tool:Activate", fire = function(tool)
			if tool then
				tool:Activate()
			end
		end },
		{ name = "screen click", fire = function()
			local v = workspace.CurrentCamera.ViewportSize
			VirtualInputManager:SendMouseButtonEvent(v.X / 2, v.Y / 2, 0, true, game, 1)
			VirtualInputManager:SendMouseButtonEvent(v.X / 2, v.Y / 2, 0, false, game, 1)
		end },
	}
	local BackendIdx, BackendOk, Exhausted = 1, {}, false
	local function Swing(tool)
		local now = os.clock()
		local p = Profile()
		if now < Pace.pauseUntil or now - Pace.last < Pace.gap then
			return
		end
		if p.pause and BackendOk[BackendIdx] and now > Pace.nextPause then
			Pace.pauseUntil = now + 1.5 + math.random() * 2.5
			Pace.nextPause = Pace.pauseUntil + 40 + math.random() * 50
			return
		end
		Pace.last = now
		Pace.gap = p.swingMin + math.random() * (p.swingMax - p.swingMin)
		pcall(Backends[BackendIdx].fire, tool)
	end

	local function Prep(m)
		local h, r = m:FindFirstChildOfClass("Humanoid"), m:FindFirstChild("HumanoidRootPart")
		if h and r then
			h.WalkSpeed = 0
			h.JumpPower = 0
			r.CanCollide = false
		end
	end

	local function KillMob(mob, stopFn)
		local hum = mob:FindFirstChildOfClass("Humanoid")
		local hrp = mob:FindFirstChild("HumanoidRootPart")
		if not (hum and hrp) then
			return false
		end
		local lastHp, hpAt = hum.Health, os.clock()
		while Running and Cfg.AutoFarm do
			task.wait()
			local me = Alive()
			if not me or not mob.Parent or hum.Health <= 0 then
				break
			end
			if stopFn and stopFn() then
				break
			end
			Prep(mob)
			if Cfg.BringMobs then
				local folder = workspace:FindFirstChild("Enemies")
				for _, o in ipairs(folder and folder:GetChildren() or {}) do
					if o ~= mob and o.Name == mob.Name then
						local r = MobRoot(o)
						if r and (r.Position - hrp.Position).Magnitude < 250 then
							Prep(o)
							r.CFrame = hrp.CFrame
						end
					end
				end
			end
			local want = hrp.CFrame * CFrame.new(0, Cfg.Hover, Cfg.MeleeRange)
			if (me.Position - hrp.Position).Magnitude > 60 then
				MoveTo(want)
			else
				CancelMove()
				me.CFrame = CFrame.lookAt(want.Position, Vector3.new(hrp.Position.X, want.Position.Y, hrp.Position.Z))
				Swing(EquipMelee())
			end
			if (me.Position - hrp.Position).Magnitude > 60 then
				hpAt = os.clock()
			end
			if hum.Health < lastHp - 0.5 then
				if not BackendOk[BackendIdx] then
					BackendOk[BackendIdx] = true
					Log("attack backend verified: " .. Backends[BackendIdx].name)
				end
				lastHp, hpAt = hum.Health, os.clock()
			elseif os.clock() - hpAt > 4 and not BackendOk[BackendIdx] and (me.Position - hrp.Position).Magnitude < 12 then
				hpAt = os.clock()
				if BackendIdx < #Backends then
					BackendIdx = BackendIdx + 1
					Log("no damage dealt, trying backend: " .. Backends[BackendIdx].name)
				elseif not Exhausted then
					Exhausted = true
					Log("attack unverified on every backend; Collector spy must capture a real attack")
				end
			end
			if BackendOk[BackendIdx] and os.clock() - hpAt > 12 then
				MobSkip[mob] = os.clock() + 30
				Log("no damage for 12 s on " .. mob.Name .. ", skipping that one for 30 s")
				break
			end
		end
		CancelMove()
		return hum.Health <= 0
	end

	----------------------------------------------------------------------------------------------------
	-- QUEST ENGINE (quest list and commands come from the KB, never hardcoded)
	----------------------------------------------------------------------------------------------------
	local Bad, Attempts = {}, {}
	local function QKey(q)
		return tostring(q.key) .. "#" .. tostring(q.idx)
	end

	local function SkippedByRule(q)
		if not Cfg.SkipBossQuests then
			return false
		end
		return type(q.count) == "number" and (q.count == 1 or q.count >= 50)
	end

	local function PickQuest(level)
		local best = nil
		for _, q in ipairs(KB.quests) do
			if type(q.minLevel) == "number" and type(q.mob) == "string" and level >= q.minLevel and not Bad[QKey(q)] and not SkippedByRule(q) then
				if not best or q.minLevel > best.minLevel then
					best = q
				end
			end
		end
		return best
	end

	local function QuestNPCPos(q)
		if typeof(q.npcPos) == "Vector3" then
			return q.npcPos
		end
		local spot = KB.questPos[tostring(q.key)]
		if typeof(spot) == "Vector3" then
			return spot
		end
		local center = MobCenter(q.mob)
		if not center then
			return nil
		end
		local best, bestD = nil, math.huge
		for _, n in ipairs(KB.npcs) do
			if n.isQuest and typeof(n.pos) == "Vector3" then
				local d = (n.pos - center).Magnitude
				if d < bestD then
					best, bestD = n, d
				end
			end
		end
		return best and best.pos or nil
	end

	local function WaitAtMobs(mobName)
		local c = MobCenter(mobName)
		if c then
			MoveTo(CFrame.new(c + Vector3.new(0, Cfg.Hover + 3, 0)))
		else
			SetSub("no position known for " .. mobName .. " (KB spawns empty)")
		end
	end

	local function FarmQuest(q)
		local qs = QuestState()
		if not qs then
			SetTask("Quest GUI missing")
			return
		end
		if qs.visible and TitleHasMob(qs.text, q.mob) then
			local mob = NearestEnemy(q.mob)
			if mob then
				SetTask("Farming | " .. q.mob, qs.text)
				KillMob(mob, function()
					local s = QuestState()
					return not (s and s.visible and TitleHasMob(s.text, q.mob))
				end)
			else
				SetTask("Farming | waiting for " .. q.mob, qs.text)
				WaitAtMobs(q.mob)
			end
			return
		end
		if qs.visible then
			SetTask("Dropping wrong quest", qs.text)
			local ok = CallCmd("abandonOrTurnIn")
			if not ok then
				Bad[QKey(q)] = true
				Log("cannot drop current quest: no abandon command in KB")
			end
			task.wait(0.5)
			return
		end
		local pos = QuestNPCPos(q)
		if not KB.cmd.startQuest then
			SetTask("Quest start gated", "KB has no startQuest command (teach it in the Collector)")
			return false
		end
		if not pos then
			SetTask("Quest NPC unknown", q.key .. ": accept it by hand once and the spot is learned")
			Bad[QKey(q)] = true
			return false
		end
		SetTask("Taking quest | " .. q.mob, q.key .. " #" .. tostring(q.idx))
		if MoveTo(CFrame.new(pos + Vector3.new(0, 3, 0))) then
			Attempts[QKey(q)] = (Attempts[QKey(q)] or 0) + 1
			CallCmd("startQuest", { ["{key}"] = q.key, ["{idx}"] = q.idx })
			task.wait(0.7)
			local s = QuestState()
			if s and s.visible then
				Attempts[QKey(q)] = 0
				if Cfg.AutoSpawn and KB.cmd.setSpawn then
					CallCmd("setSpawn")
				end
			elseif Attempts[QKey(q)] >= 3 then
				Bad[QKey(q)] = true
				Log("quest " .. QKey(q) .. " would not start after 3 tries, skipping")
			end
		end
		return true
	end

	-- no usable quest: farm the live mobs whose Level attribute (dump) fits the player
	local function FarmNoQuest(level)
		local folder = workspace:FindFirstChild("Enemies")
		local me = Root()
		if not (folder and me) then
			return
		end
		local best, bestL, bestD = nil, -1, math.huge
		for _, m in ipairs(folder:GetChildren()) do
			local r = MobRoot(m)
			local l = m:GetAttribute("Level")
			if r and type(l) == "number" and l <= level + Cfg.LevelMargin and not (MobSkip[m] and MobSkip[m] > os.clock()) then
				local d = (r.Position - me.Position).Magnitude
				if l > bestL or (l == bestL and d < bestD) then
					best, bestL, bestD = m, l, d
				end
			end
		end
		if best then
			SetTask("Farming (no quest) | " .. best.Name, "Level " .. tostring(bestL))
			KillMob(best)
			return
		end
		SetTask("Farming gated", "no mob in range streamed in, and no quest data in KB")
		task.wait(0.5)
	end

	-- the mob named by the quest GUI title (works when the quest was taken by hand)
	local function ActiveQuestMob()
		local s = QuestState()
		if not (s and s.visible and s.text ~= "") then
			return nil, s
		end
		local best = nil
		for _, q in ipairs(KB.quests) do
			if type(q.mob) == "string" and TitleHasMob(s.text, q.mob) then
				if not best or #q.mob > #best then
					best = q.mob
				end
			end
		end
		return best, s
	end

	local function FarmMobName(mob, sub)
		local m = NearestEnemy(mob)
		if m then
			SetTask("Farming | " .. mob, sub)
			KillMob(m)
		else
			SetTask("Farming | waiting for " .. mob, sub)
			WaitAtMobs(mob)
		end
	end

	local function MainStep()
		if not LocalPlayer:GetAttribute("LoadComplete") then
			SetTask("Waiting for load")
			task.wait(0.5)
			return
		end
		if not LocalPlayer.Team then
			SetTask("Pick a team", "team command unknown to this script, choose it by hand")
			task.wait(1)
			return
		end
		if not Alive() then
			SetTask("Waiting for respawn")
			CancelMove()
			task.wait(0.25)
			return
		end
		local level = D.Level.Value
		local q = PickQuest(level)
		if q and KB.cmd.startQuest then
			if FarmQuest(q) == false then
				task.wait(0.3)
			end
			return
		end
		local active, st = ActiveQuestMob()
		if active and (NearestEnemy(active) or MobCenter(active)) then
			FarmMobName(active, st.text)
		elseif q and (NearestEnemy(q.mob) or MobCenter(q.mob)) then
			FarmMobName(q.mob, "start command unknown (Data > Learn), farming " .. q.mob .. " without a quest")
		else
			FarmNoQuest(level)
		end
	end

	task.spawn(function()
		local lastErr, lastAt = "", 0
		while Running do
			task.wait()
			if Cfg.AutoFarm and SeaOk then
				local ok, err = pcall(MainStep)
				if not ok then
					err = tostring(err)
					if err ~= lastErr or os.clock() - lastAt > 10 then
						lastErr, lastAt = err, os.clock()
						Log("error: " .. err)
					end
					CancelMove()
					task.wait(0.5)
				end
			else
				SetTask(SeaOk and "Idle (AutoFarm off)" or "Wrong place: this build is Sea 1 only")
				CancelMove()
				task.wait(0.25)
			end
		end
	end)

	----------------------------------------------------------------------------------------------------
	-- LEARN (derives the startQuest template from one quest accepted by hand; no value is guessed)
	----------------------------------------------------------------------------------------------------
	local Learn = { status = "idle", active = false, found = nil }
	function Learn.Finish()
		local f = Learn.found
		Learn.active = false
		if not f then
			Learn.status = "nothing seen: no remote call carried a known quest key"
			Log("learn: " .. Learn.status)
			return
		end
		local path = f.remote:GetFullName()
		if ResolveRemote(path) ~= f.remote then
			Learn.status = "remote path not resolvable: " .. path
			Log("learn: " .. Learn.status)
			return
		end
		local idxs = {}
		for _, q in ipairs(KB.quests) do
			if tostring(q.key) == f.key then
				idxs[q.idx] = true
			end
		end
		local idxAt = nil
		for i = 1, f.args.n do
			if i ~= f.keyAt and type(f.args[i]) == "number" and idxs[f.args[i]] then
				idxAt = i
				break
			end
		end
		local tpl = {}
		for i = 1, f.args.n do
			local v = f.args[i]
			if i == f.keyAt then
				tpl[i] = "{key}"
			elseif i == idxAt then
				tpl[i] = "{idx}"
			elseif type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
				tpl[i] = v
			else
				Learn.status = "argument " .. i .. " is a " .. typeof(v) .. ", cannot store it"
				Log("learn: " .. Learn.status)
				return
			end
		end
		KB.cmd.startQuest = tpl
		KB.cmd.startQuestRemote = path
		Bad, Attempts = {}, {}
		local file = "KaitunKB_" .. game.PlaceId .. ".json"
		local raw = {}
		if isfile and readfile and isfile(file) then
			pcall(function()
				raw = HttpService:JSONDecode(readfile(file))
			end)
		end
		if type(raw) ~= "table" then
			raw = {}
		end
		raw.cmd = type(raw.cmd) == "table" and raw.cmd or {}
		raw.cmd.startQuest = tpl
		raw.cmd.startQuestRemote = path
		local saved = pcall(function()
			writefile(file, HttpService:JSONEncode(raw))
		end)
		Learn.status = "learned " .. path .. (saved and " (saved)" or " (not saved: no writefile)")
		Log("learn: " .. Learn.status .. " | key at arg " .. f.keyAt .. ", idx at " .. tostring(idxAt))
		Log("next: accept each quest by hand once, the script stores where you stood and flies there later")
	end
	function Learn.Start()
		if Learn.active then
			return
		end
		if not Anti.Installed then
			Learn.status = "needs the anti hook (executor lacks hookmetamethod)"
			return
		end
		Learn.active, Learn.found = true, nil
		Learn.status = "waiting 30 s: accept a quest from its NPC by hand"
		local deadline = os.clock() + 30
		local keys = {}
		for _, q in ipairs(KB.quests) do
			if q.key then
				keys[tostring(q.key)] = true
			end
		end
		Anti.Learn = { push = function(remote, name, ...)
			if Learn.found or os.clock() > deadline then
				return
			end
			local args = table.pack(...)
			for i = 1, args.n do
				if type(args[i]) == "string" and keys[args[i]] then
					Learn.found = { remote = remote, args = args, keyAt = i, key = args[i] }
					return
				end
			end
		end }
		task.spawn(function()
			while Running and os.clock() < deadline and not Learn.found do
				task.wait(0.2)
			end
			Anti.Learn = nil
			if Running then
				Learn.Finish()
			end
		end)
	end

	----------------------------------------------------------------------------------------------------
	-- QUEST SPOTS (learned: when YOU accept a quest through the learned startQuest remote, the place your character
	-- stands on is stored for that quest key. It is your position, not an NPC model position.)
	----------------------------------------------------------------------------------------------------
	local function SaveQuestPos()
		local file = "KaitunKB_" .. game.PlaceId .. ".json"
		pcall(function()
			local raw = {}
			if isfile and readfile and isfile(file) then
				local okR, res = pcall(function()
					return HttpService:JSONDecode(readfile(file))
				end)
				if okR and type(res) == "table" then
					raw = res
				end
			end
			local out = {}
			for k, v in pairs(KB.questPos) do
				if typeof(v) == "Vector3" then
					out[k] = { ["$v3"] = true, x = v.X, y = v.Y, z = v.Z }
				end
			end
			raw.questPos = out
			writefile(file, HttpService:JSONEncode(raw))
		end)
	end
	Anti.Watch = function(remote, name, ...)
		local tpl, path = KB.cmd.startQuest, KB.cmd.startQuestRemote
		if type(tpl) ~= "table" or type(path) ~= "string" or remote:GetFullName() ~= path then
			return
		end
		local args = table.pack(...)
		for i = 1, #tpl do
			if tpl[i] == "{key}" and type(args[i]) == "string" then
				local me = Root()
				if me then
					KB.questPos[args[i]] = me.Position
					Bad, Attempts = {}, {}
					SaveQuestPos()
					Log("learned quest spot: " .. args[i])
				end
				return
			end
		end
	end

	----------------------------------------------------------------------------------------------------
	-- UPKEEP (needs the learned addPoint command)
	----------------------------------------------------------------------------------------------------
	task.spawn(function()
		while Running do
			pcall(function()
				if Cfg.AutoStats and KB.cmd.addPoint and D.Points.Value > 0 then
					local pts = D.Points.Value
					local melee = math.floor(pts * Cfg.MeleePercent / 100 + 0.5)
					if melee > 0 then
						CallCmd("addPoint", { ["{stat}"] = "Melee", ["{n}"] = melee })
					end
					if pts - melee > 0 then
						CallCmd("addPoint", { ["{stat}"] = "Defense", ["{n}"] = pts - melee })
					end
				end
			end)
			task.wait(1)
		end
	end)

	----------------------------------------------------------------------------------------------------
	-- SYSTEM
	----------------------------------------------------------------------------------------------------
	Bind(LocalPlayer.Idled, function()
		if Cfg.AntiAFK then
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.zero)
			end)
		end
	end)
	pcall(function()
		Bind(CoreGui.RobloxPromptGui.promptOverlay.ChildAdded, function(v)
			if Cfg.AutoRejoin and v.Name == "ErrorPrompt" then
				Log("disconnect prompt, rejoining")
				task.wait(3)
				TeleportService:Teleport(game.PlaceId)
			end
		end)
	end)
	local function ApplyRender()
		pcall(function()
			RunService:Set3dRenderingEnabled(not Cfg.WhiteScreen)
		end)
	end
	local function ApplyFPS()
		if Cfg.FPS > 0 and setfpscap then
			pcall(setfpscap, Cfg.FPS)
		end
	end
	ApplyRender()
	ApplyFPS()

	local MusicSound = Instance.new("Sound")
	MusicSound.Name = "KaitunMusic"
	MusicSound.Looped = true
	MusicSound.Volume = Cfg.Music.Volume
	MusicSound.Parent = SoundService
	local function MusicId()
		return (tostring(Cfg.Music.Id or ""):gsub("%D", ""))
	end
	local function ApplyMusic()
		local id = MusicId()
		MusicSound.Volume = Cfg.Music.Volume
		if Cfg.Music.Enabled and id ~= "" then
			local want = "rbxassetid://" .. id
			if MusicSound.SoundId ~= want then
				MusicSound.SoundId = want
			end
			if not MusicSound.IsPlaying then
				MusicSound:Play()
			end
			return true
		end
		MusicSound:Stop()
		return false
	end


	-- UI (liquid glass: smoked-glass window, frosted tiles, white rim light, blur behind the open menu)
	----------------------------------------------------------------------------------------------------
	local Theme = {
		Glass = Color3.fromRGB(22, 19, 42), -- window and HUD tint
		Pink = Color3.fromRGB(255, 124, 196),
		Violet = Color3.fromRGB(148, 112, 255),
		Ice = Color3.fromRGB(196, 228, 255),
		Mint = Color3.fromRGB(120, 235, 200),
		Text = Color3.fromRGB(248, 245, 255),
		Dim = Color3.fromRGB(178, 172, 210),
		Off = Color3.fromRGB(120, 114, 156),
	}

	local function Make(class, props, parent)
		local o = Instance.new(class)
		for k, v in pairs(props) do
			o[k] = v
		end
		if parent then
			o.Parent = parent
		end
		return o
	end
	local function Tw(o, t, props, style, dir)
		local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
		tw:Play()
		return tw
	end
	local function Round(o, r)
		return Make("UICorner", { CornerRadius = UDim.new(0, r) }, o)
	end
	local function Stroke(o, c, t, tr)
		return Make("UIStroke", { Color = c, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	end
	local function Grad(o, c0, c1, rot)
		return Make("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rot or 0 }, o)
	end
	local function Viewport()
		local cam = workspace.CurrentCamera
		return cam and cam.ViewportSize or Vector2.new(1280, 720)
	end

	-- glass building blocks
	--   Rim   : white stroke, bright on the top-left edge and faint on the bottom-right (returns its UIGradient, spin it for a shimmer)
	--   Sheen : soft white gradient laid over a panel, strongest at the top
	--   Tile  : turns a Frame/Button into a frosted tile (returns its UIStroke)
	local Rim, Sheen, Tile
	do
		local rimAlpha = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.3, 0.6),
			NumberSequenceKeypoint.new(0.7, 0.88),
			NumberSequenceKeypoint.new(1, 0.4),
		})
		local sheenAlpha = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(0.5, 0.95),
			NumberSequenceKeypoint.new(1, 1),
		})
		Rim = function(o, thickness)
			local st = Stroke(o, Color3.new(1, 1, 1), thickness or 1.25, 0)
			return Make("UIGradient", {
				Color = ColorSequence.new(Color3.new(1, 1, 1), Theme.Ice), Transparency = rimAlpha, Rotation = 45,
			}, st)
		end
		Sheen = function(o, radius, z)
			local s = Make("Frame", {
				Name = "Sheen", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0, ZIndex = z or 0,
			}, o)
			Round(s, radius)
			Make("UIGradient", { Rotation = 90, Transparency = sheenAlpha }, s)
			return s
		end
		Tile = function(o, radius, tr)
			o.BackgroundColor3 = Color3.new(1, 1, 1)
			o.BackgroundTransparency = tr or 0.9
			o.BorderSizePixel = 0
			Round(o, radius)
			return Stroke(o, Color3.new(1, 1, 1), 1, 0.8)
		end
	end

	BootStage("ui-window")
	local Gui = Make("ScreenGui", {
		Name = "KaitunRewrite", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
	})
	if not PlaceGui(Gui) then
		Log("no GUI host accepted the menu (gethui, CoreGui and PlayerGui all refused)")
	end

	-- toasts
	local ToastHolder = Make("Frame", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(280, 300), BackgroundTransparency = 1,
	}, Gui)
	Make("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
	}, ToastHolder)

	local function Toast(text)
		local t = Make("TextLabel", {
			Size = UDim2.fromOffset(260, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Glass, BackgroundTransparency = 1, BorderSizePixel = 0,
			TextColor3 = Theme.Text, TextTransparency = 1, Font = Enum.Font.GothamSemibold,
			TextSize = 13, TextWrapped = true, Text = text,
		}, ToastHolder)
		Make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, t)
		Round(t, 14)
		local st = Stroke(t, Color3.new(1, 1, 1), 1.25, 1)
		Tw(t, 0.25, { BackgroundTransparency = 0.25, TextTransparency = 0 })
		Tw(st, 0.25, { Transparency = 0.35 })
		task.delay(3.2, function()
			if t.Parent then
				Tw(t, 0.3, { BackgroundTransparency = 1, TextTransparency = 1 })
				Tw(st, 0.3, { Transparency = 1 })
				task.wait(0.35)
				t:Destroy()
			end
		end)
	end

	-- HUD
	local vp = Viewport()
	local Hud = Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -120),
		Size = UDim2.fromOffset(math.min(460, vp.X - 24), 88),
		BackgroundColor3 = Theme.Glass, BackgroundTransparency = 0.3, BorderSizePixel = 0,
	}, Gui)
	Round(Hud, 20)
	local HudGrad = Rim(Hud, 1.5)
	Sheen(Hud, 20)
	local HudDot = Make("Frame", {
		Position = UDim2.fromOffset(16, 17), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Theme.Mint, BorderSizePixel = 0,
	}, Hud)
	Round(HudDot, 5)
	local HudTask = Make("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(34, 9), Size = UDim2.new(1, -48, 0, 26),
		Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = "booting",
	}, Hud)
	local HudSub = Make("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 35), Size = UDim2.new(1, -32, 0, 18),
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = "",
	}, Hud)
	local HudStats = Make("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 54), Size = UDim2.new(1, -32, 0, 16),
		Font = Enum.Font.GothamSemibold, TextSize = 12, TextColor3 = Theme.Mint, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
	}, Hud)
	local HudBar = Make("Frame", {
		Position = UDim2.new(0, 16, 1, -11), Size = UDim2.new(1, -32, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82, BorderSizePixel = 0,
	}, Hud)
	Round(HudBar, 2)
	local HudFill = Make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, HudBar)
	Round(HudFill, 2)
	Grad(HudFill, Theme.Pink, Theme.Violet, 0)
	Tw(Hud, 0.6, { Position = UDim2.new(0.5, 0, 0, 12) }, Enum.EasingStyle.Back)

	-- window: plain Frames only (no CanvasGroup), Active so touches on the glass never rotate the game camera
	local WinW = math.clamp(vp.X - 24, 300, 600)
	local WinH = math.clamp(vp.Y - 110, 230, 390)
	local Win = Make("Frame", {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 52), Size = UDim2.fromOffset(WinW, WinH),
		BackgroundColor3 = Theme.Glass, BackgroundTransparency = 0.3, BorderSizePixel = 0, Active = true,
	}, Gui)
	Round(Win, 22)
	local HeaderGrad = Rim(Win, 1.5)
	Sheen(Win, 22)
	local WinScale = Make("UIScale", { Scale = math.clamp((tonumber(Cfg.UIScale) or 100) / 100, 0.7, 1.3) }, Win)
	local MenuVisible = true
	local SetBlur = function() end -- real version is assigned below the pages, the System tab toggle calls it

	local Repaints = {} -- toggle redraw callbacks, so the header FARM switch and the Farm tab stay in sync
	local Header = Make("Frame", { Name = "Header", Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 44) }, Win)
	Tile(Header, 16, 0.9)
	Make("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -170, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "kaitun  //  sea 1  ~",
	}, Header)
	local MinBtn = Make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(30, 30),
		Text = "-", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = Theme.Text, AutoButtonColor = false,
	}, Header)
	Tile(MinBtn, 15, 0.84)
	local FarmChip = Make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, 0), Size = UDim2.fromOffset(88, 28),
		Text = "FARM OFF", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Dim, AutoButtonColor = false,
	}, Header)
	local ChipStroke = Tile(FarmChip, 14, 0.88)
	local function PaintChip()
		local on = Cfg.AutoFarm and true or false
		FarmChip.Text = on and "FARM ON" or "FARM OFF"
		FarmChip.TextColor3 = on and Theme.Mint or Theme.Dim
		FarmChip.BackgroundColor3 = on and Theme.Mint or Color3.new(1, 1, 1)
		FarmChip.BackgroundTransparency = on and 0.78 or 0.88
		ChipStroke.Color = on and Theme.Mint or Color3.new(1, 1, 1)
		ChipStroke.Transparency = on and 0.35 or 0.8
	end
	PaintChip()
	FarmChip.MouseButton1Click:Connect(function()
		Cfg.AutoFarm = not Cfg.AutoFarm
		if not Cfg.AutoFarm then
			CancelMove()
		end
		PaintChip()
		for _, f in ipairs(Repaints) do
			pcall(f)
		end
	end)

	local Side = Make("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 62), Size = UDim2.new(0, 116, 1, -72), ScrollBarThickness = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, Win)
	Tile(Side, 16, 0.92)
	Make("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, Side)
	Make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, Side)
	local Content = Make("Frame", { Position = UDim2.fromOffset(134, 62), Size = UDim2.new(1, -144, 1, -72), BackgroundTransparency = 1, ClipsDescendants = true }, Win)

	local Tabs = {}
	local function AddTab(name)
		local btn = Make("TextButton", {
			Size = UDim2.new(1, -12, 0, 34), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Text = name,
			Font = Enum.Font.GothamSemibold, TextSize = 14, TextColor3 = Theme.Dim, AutoButtonColor = false, LayoutOrder = #Tabs + 1,
		}, Side)
		Round(btn, 12)
		local st = Stroke(btn, Theme.Pink, 1.25, 1)
		local page = Make("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.Violet, ScrollBarImageTransparency = 0.3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
		}, Content)
		Make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, page)
		Make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 9) }, page)
		local entry = { btn = btn, page = page, st = st }
		function entry.pick()
			for _, t in ipairs(Tabs) do
				t.page.Visible = false
				Tw(t.btn, 0.2, { BackgroundTransparency = 1, TextColor3 = Theme.Dim })
				Tw(t.st, 0.2, { Transparency = 1 })
			end
			page.Visible = true
			page.Position = UDim2.new(0, 18, 0, 0)
			Tw(page, 0.28, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
			Tw(btn, 0.2, { BackgroundTransparency = 0.84, TextColor3 = Theme.Text })
			Tw(st, 0.2, { Transparency = 0.45 })
		end
		btn.MouseButton1Click:Connect(entry.pick)
		table.insert(Tabs, entry)
		return page
	end

	local function NextOrder(page)
		local n = (page:GetAttribute("n") or 0) + 1
		page:SetAttribute("n", n)
		return n
	end
	local function Row(page, h)
		local r = Make("Frame", { Size = UDim2.new(1, 0, 0, h or 46), LayoutOrder = NextOrder(page) }, page)
		Tile(r, 14, 0.9)
		r.MouseEnter:Connect(function()
			Tw(r, 0.15, { BackgroundTransparency = 0.83 })
		end)
		r.MouseLeave:Connect(function()
			Tw(r, 0.15, { BackgroundTransparency = 0.9 })
		end)
		return r
	end
	local function RowLabel(r, text, desc)
		Make("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, desc and 7 or 0), Size = UDim2.new(1, -90, 0, desc and 22 or 46),
			Text = text, Font = Enum.Font.GothamSemibold, TextSize = 15, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, r)
		if desc then
			Make("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 28), Size = UDim2.new(1, -90, 0, 18),
				Text = desc, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, r)
		end
	end

	local function Section(page, text)
		Make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = string.upper(text), Font = Enum.Font.GothamBold,
			TextSize = 11, TextColor3 = Theme.Pink, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = NextOrder(page),
		}, page)
	end

	-- get/set toggle; set may return false to reject the change
	local function Toggle(page, text, desc, get, set)
		local r = Row(page, desc and 54 or 46)
		RowLabel(r, text, desc)
		local track = Make("Frame", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(46, 26),
		}, r)
		Tile(track, 13, 0.78)
		local fill = Make("Frame", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		}, track)
		Round(fill, 13)
		Grad(fill, Theme.Pink, Theme.Violet, 0)
		local knob = Make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
		}, track)
		Round(knob, 10)
		Stroke(knob, Color3.new(1, 1, 1), 1, 0.6)
		local shown = nil
		local function paint(on)
			on = on and true or false
			if shown == on then
				return
			end
			shown = on
			Tw(fill, 0.2, { BackgroundTransparency = on and 0.1 or 1 })
			Tw(knob, 0.22, { Position = on and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, Enum.EasingStyle.Back)
		end
		paint(get())
		Repaints[#Repaints + 1] = function()
			paint(get())
		end
		local hit = Make("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", ZIndex = 5 }, r)
		hit.MouseButton1Click:Connect(function()
			local v = not get()
			if set(v) == false then
				v = not v
			end
			paint(get())
		end)
	end
	local function CfgToggle(page, text, desc, key, after)
		Toggle(page, text, desc, function()
			return Cfg[key]
		end, function(v)
			Cfg[key] = v
			if after then
				after(v)
			end
		end)
	end

	local function Button(page, text, cb)
		local r = Row(page, 40)
		local b = Make("TextButton", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = text, Font = Enum.Font.GothamBold, TextSize = 14,
			TextColor3 = Theme.Text, AutoButtonColor = false, TextTruncate = Enum.TextTruncate.AtEnd,
		}, r)
		b.MouseButton1Click:Connect(function()
			Tw(r, 0.08, { BackgroundColor3 = Theme.Pink, BackgroundTransparency = 0.55 })
			task.delay(0.1, function()
				Tw(r, 0.25, { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9 })
			end)
			cb()
		end)
		return b
	end

	local function Info(page, label)
		local r = Row(page, 34)
		Make("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), Text = label,
			Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Left,
		}, r)
		local v = Make("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, -14, 1, 0), Text = "-",
			Font = Enum.Font.GothamSemibold, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, r)
		return function(t)
			if v.Text ~= t then
				v.Text = t
			end
		end
	end

	local function Slider(page, text, lo, hi, step, get, set, fmt)
		local r = Row(page, 58)
		Make("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 6), Size = UDim2.new(1, -100, 0, 20), Text = text,
			Font = Enum.Font.GothamSemibold, TextSize = 15, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, r)
		local val = Make("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 6), Size = UDim2.fromOffset(80, 20),
			Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Pink, TextXAlignment = Enum.TextXAlignment.Right,
		}, r)
		local track = Make("Frame", {
			Position = UDim2.new(0, 14, 0, 38), Size = UDim2.new(1, -28, 0, 8), BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.8, BorderSizePixel = 0,
		}, r)
		Round(track, 4)
		local fill = Make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, track)
		Round(fill, 4)
		Grad(fill, Theme.Pink, Theme.Violet, 0)
		local thumb = Make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
		}, track)
		Round(thumb, 8)
		Stroke(thumb, Theme.Violet, 1.5, 0.3)
		local function render(v)
			local f = math.clamp((v - lo) / (hi - lo), 0, 1)
			Tw(fill, 0.08, { Size = UDim2.new(f, 0, 1, 0) })
			Tw(thumb, 0.08, { Position = UDim2.new(f, 0, 0.5, 0) })
			val.Text = fmt and fmt(v) or tostring(v)
		end
		render(get())
		local dragging = false
		local function fromX(x)
			local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			local v = math.clamp(lo + math.floor((hi - lo) * rel / step + 0.5) * step, lo, hi)
			set(v)
			render(v)
		end
		r.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				page.ScrollingEnabled = false -- a finger on a slider must not also scroll the page
				fromX(i.Position.X)
			end
		end)
		Bind(UserInputService.InputChanged, function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				fromX(i.Position.X)
			end
		end)
		Bind(UserInputService.InputEnded, function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = false
				page.ScrollingEnabled = true
			end
		end)
	end

	local function TextInput(page, text, placeholder, get, set)
		local r = Row(page, 46)
		RowLabel(r, text)
		local box = Make("TextBox", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 28),
			BackgroundColor3 = Color3.fromRGB(10, 8, 24), BackgroundTransparency = 0.45, BorderSizePixel = 0,
			Text = get(), PlaceholderText = placeholder, PlaceholderColor3 = Theme.Dim,
			TextColor3 = Theme.Text, Font = Enum.Font.GothamSemibold, TextSize = 13, ClearTextOnFocus = false,
		}, r)
		Round(box, 10)
		Stroke(box, Color3.new(1, 1, 1), 1, 0.75)
		box.FocusLost:Connect(function()
			local res = set(box.Text)
			if type(res) == "string" then
				box.Text = res
			end
		end)
	end



	BootStage("ui-pages")
	local FarmPage = AddTab("Farm")
	local UpkeepPage = AddTab("Upkeep")
	local MovePage = AddTab("Move")
	local AntiPage = AddTab("Anti")
	local MusicPage = AddTab("Music")
	local SystemPage = AddTab("System")
	local DataPage = AddTab("Data")
	local LogPage = AddTab("Log")

	-- Farm
	Section(FarmPage, "live")
	local sQuest = Info(FarmPage, "Quest")
	local sBackend = Info(FarmPage, "Attack input")
	local sMob = Info(FarmPage, "Target mob")
	Section(FarmPage, "farm")
	CfgToggle(FarmPage, "Auto Farm", "Quest-driven, falls back to mob-level farming", "AutoFarm", function(v)
		if not v then
			CancelMove()
		end
	end)
	CfgToggle(FarmPage, "Bring mobs", "Pull same-name mobs onto the target", "BringMobs")
	CfgToggle(FarmPage, "Skip boss and story quests", "1-target and 50-target quests stall the farm", "SkipBossQuests")
	Slider(FarmPage, "Melee range", 2, 12, 1, function()
		return Cfg.MeleeRange
	end, function(v)
		Cfg.MeleeRange = v
	end, function(v)
		return v .. " studs"
	end)
	Slider(FarmPage, "Hover height", 0, 40, 1, function()
		return Cfg.Hover
	end, function(v)
		Cfg.Hover = v
	end, function(v)
		return v .. " studs"
	end)
	Slider(FarmPage, "Level margin (no-quest mode)", 0, 20, 1, function()
		return Cfg.LevelMargin
	end, function(v)
		Cfg.LevelMargin = v
	end)

	-- Upkeep
	Section(UpkeepPage, "stats and spawn")
	CfgToggle(UpkeepPage, "Auto Stats", "Needs the addPoint command from the KB", "AutoStats")
	Slider(UpkeepPage, "Melee share", 0, 100, 5, function()
		return Cfg.MeleePercent
	end, function(v)
		Cfg.MeleePercent = v
	end, function(v)
		return v .. "% (rest Defense)"
	end)
	CfgToggle(UpkeepPage, "Set spawn after quest", "Needs the setSpawn command from the KB", "AutoSpawn")

	-- Move
	Section(MovePage, "flight")
	local sScale = Info(MovePage, "Speed scale")
	local sRubber = Info(MovePage, "Rubber-bands")
	Slider(MovePage, "Base speed", 100, 320, 10, function()
		return Cfg.BaseSpeed
	end, function(v)
		Cfg.BaseSpeed = v
	end, function(v)
		return v .. " /s"
	end)
	Slider(MovePage, "Speed percent", 40, 120, 5, function()
		return Cfg.SpeedPercent
	end, function(v)
		Cfg.SpeedPercent = v
	end, function(v)
		return v .. "%"
	end)
	Slider(MovePage, "Arrive radius", 4, 40, 2, function()
		return Cfg.ArriveRadius
	end, function(v)
		Cfg.ArriveRadius = v
	end, function(v)
		return v .. " studs"
	end)
	CfgToggle(MovePage, "Adaptive speed", "Slows down after a rubber-band, recovers later", "AdaptiveSpeed")
	Button(MovePage, "Reset speed scale", function()
		SpeedScale = 1
		RubberCount = 0
	end)

	-- Anti
	Section(AntiPage, "live")
	local sSeen = Info(AntiPage, "Busiest remotes")
	local sBlocked = Info(AntiPage, "Blocked / kicks stopped")
	local sProf = Info(AntiPage, "Profile limits")
	Section(AntiPage, "stealth")
	local StealthBtn = nil
	StealthBtn = Button(AntiPage, "Stealth profile: " .. tostring(Cfg.Stealth), function()
		local at = 1
		for i, n in ipairs(ProfileOrder) do
			if n == Cfg.Stealth then
				at = i
			end
		end
		Cfg.Stealth = ProfileOrder[at % #ProfileOrder + 1]
		StealthBtn.Text = "Stealth profile: " .. Cfg.Stealth
	end)
	Section(AntiPage, "guards")
	CfgToggle(AntiPage, "Block client kicks", "Stops LocalPlayer:Kick from the game's own scripts", "AntiKick", SyncAnti)
	for _, name in ipairs({ "Validator", "Validator2", "CheckTeleportGlitchFix" }) do
		Toggle(AntiPage, "Block " .. name, "Not in the latest dump, effect unknown", function()
			return Cfg.Block[name]
		end, function(v)
			Cfg.Block[name] = v
			SyncAnti()
		end)
	end

	-- Music
	Section(MusicPage, "music")
	Toggle(MusicPage, "Play music", "Loops the asset id below", function()
		return Cfg.Music.Enabled
	end, function(v)
		Cfg.Music.Enabled = v
		if v and MusicId() == "" then
			Cfg.Music.Enabled = false
			Toast("nuu~ paste an audio asset id first")
			return false
		end
		ApplyMusic()
	end)
	TextInput(MusicPage, "Audio asset id", "digits only", function()
		return Cfg.Music.Id
	end, function(t)
		Cfg.Music.Id = (t:gsub("%D", ""))
		if Cfg.Music.Enabled then
			ApplyMusic()
		end
	end)
	Slider(MusicPage, "Volume", 0, 100, 5, function()
		return math.floor(Cfg.Music.Volume * 100 + 0.5)
	end, function(v)
		Cfg.Music.Volume = v / 100
		MusicSound.Volume = Cfg.Music.Volume
	end, function(v)
		return v .. "%"
	end)

	-- System
	Section(SystemPage, "system")
	CfgToggle(SystemPage, "Anti AFK", nil, "AntiAFK")
	CfgToggle(SystemPage, "Auto Rejoin", "Rejoin when the disconnect prompt appears", "AutoRejoin")
	CfgToggle(SystemPage, "White Screen", "Turns 3D rendering off", "WhiteScreen", ApplyRender)
	CfgToggle(SystemPage, "Show HUD", "Top status bar", "ShowHud")
	CfgToggle(SystemPage, "Glass blur", "Blurs the game behind the open menu", "GlassBlur", function()
		SetBlur(MenuVisible)
	end)
	local ScaleBtn = nil
	ScaleBtn = Button(SystemPage, "Menu scale: " .. tostring(Cfg.UIScale) .. "%", function()
		local steps = { 80, 90, 100, 110, 120 }
		local at = 3
		for i, s in ipairs(steps) do
			if s == Cfg.UIScale then
				at = i
			end
		end
		Cfg.UIScale = steps[at % #steps + 1]
		WinScale.Scale = Cfg.UIScale / 100
		ScaleBtn.Text = "Menu scale: " .. tostring(Cfg.UIScale) .. "%"
	end)
	TextInput(SystemPage, "Menu key", "KeyCode name", function()
		return tostring(Cfg.MenuKey)
	end, function(t)
		local okK, key = pcall(function()
			return Enum.KeyCode[t]
		end)
		if okK and key then
			Cfg.MenuKey = t
			Toast("menu key: " .. t)
			return t
		end
		Toast("nuu~ that is not a KeyCode name")
		return tostring(Cfg.MenuKey)
	end)
	Button(SystemPage, "Save settings now", function()
		Toast(SaveCfg(true) and "settings saved" or "nuu~ no writefile in this executor")
	end)
	Slider(SystemPage, "FPS cap", 0, 240, 10, function()
		return Cfg.FPS
	end, function(v)
		Cfg.FPS = v
		ApplyFPS()
	end, function(v)
		return v == 0 and "untouched" or tostring(v)
	end)
	Button(SystemPage, "Rejoin server", function()
		TeleportService:Teleport(game.PlaceId)
	end)

	-- Data (what is verified, what is missing)
	Section(DataPage, "what this script knows")
	local capNames = {
		"Sea 1 place", "Quest GUI", "KB file", "Quests usable", "startQuest cmd", "addPoint cmd",
		"setSpawn cmd", "entrance cmd", "Quest NPCs", "Quest spots learned", "Mob spawns", "Anti hook", "UI host",
	}
	local caps = {}
	for _, n in ipairs(capNames) do
		caps[n] = Info(DataPage, n)
	end
	Button(DataPage, "Reload KB file", function()
		LoadKB()
		Bad, Attempts = {}, {}
		Toast("KB reloaded: " .. KBSource)
	end)
	Section(DataPage, "teach the script")
	local sLearn = Info(DataPage, "Learn startQuest")
	Button(DataPage, "Learn startQuest (accept a quest by hand, 30 s)", Learn.Start)

	local function UpdatePages()
		local qs = QuestState()
		sQuest(qs and (qs.visible and qs.text or "none active") or "GUI missing")
		sBackend(Backends[BackendIdx].name .. (BackendOk[BackendIdx] and " (verified)" or " (unverified)"))
		sMob(Status.Sub ~= "" and Status.Sub or "-")
		sScale(string.format("%.2f (%d studs/s)", SpeedScale, math.floor(MoveSpeed)))
		sRubber(tostring(RubberCount))
		local seen = {}
		for n, c in pairs(Anti.Seen) do
			seen[#seen + 1] = { n = n, c = c }
		end
		table.sort(seen, function(a, b)
			return a.c > b.c
		end)
		local top = {}
		for i = 1, math.min(3, #seen) do
			top[i] = seen[i].n .. " x" .. seen[i].c
		end
		sSeen(#top > 0 and table.concat(top, ", ") or "none yet")
		local pf = Profile()
		sProf(string.format("%s | cap %s | swing %.2f-%.2fs%s", tostring(Cfg.Stealth),
			pf.cap == math.huge and "none" or (pf.cap .. " studs/s"), pf.swingMin, pf.swingMax, pf.pause and " | breaks" or ""))
		sLearn(Learn.status)
		sBlocked(Anti.Blocked .. " / " .. Anti.Kicked)
		local validQ, nq, ns = 0, 0, 0
		for _, q in ipairs(KB.quests) do
			if type(q.minLevel) == "number" and type(q.mob) == "string" then
				validQ = validQ + 1
			end
		end
		for _, n in ipairs(KB.npcs) do
			if n.isQuest then
				nq = nq + 1
			end
		end
		for _ in pairs(KB.spawns) do
			ns = ns + 1
		end
		local function yn(b)
			return b and "ok" or "MISSING"
		end
		caps["Sea 1 place"](yn(SeaOk) .. " (dump)")
		caps["Quest GUI"](yn(qs ~= nil) .. " (dump)")
		caps["KB file"](KBSource)
		caps["Quests usable"](validQ .. " of " .. #KB.quests)
		caps["startQuest cmd"](yn(KB.cmd.startQuest ~= nil))
		caps["addPoint cmd"](yn(KB.cmd.addPoint ~= nil))
		caps["setSpawn cmd"](yn(KB.cmd.setSpawn ~= nil))
		caps["entrance cmd"](yn(KB.cmd.requestEntrance ~= nil))
		local nspots = 0
		for _ in pairs(KB.questPos) do
			nspots = nspots + 1
		end
		caps["Quest NPCs"](tostring(nq))
		caps["Quest spots learned"](tostring(nspots))
		caps["Mob spawns"](tostring(ns) .. " names")
		caps["Anti hook"](yn(Anti.Installed))
		caps["UI host"](Boot.host)
	end

	-- Log
	local LogScroll = LogPage
	local function AddLogLine(line)
		Make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, Text = line, Font = Enum.Font.Code, TextSize = 12, TextColor3 = Theme.Text,
			LayoutOrder = NextOrder(LogScroll),
		}, LogScroll)
		local kids = {}
		for _, c in ipairs(LogScroll:GetChildren()) do
			if c:IsA("TextLabel") then
				kids[#kids + 1] = c
			end
		end
		if #kids > 80 then
			table.sort(kids, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			kids[1]:Destroy()
		end
	end
	for _, l in ipairs(LogLines) do
		AddLogLine(l)
	end
	LogHooks[#LogHooks + 1] = AddLogLine


	-- menu show / hide: the window pops with a UIScale tween and the game behind it is blurred while it is open
	local Blur = nil
	SetBlur = function(on)
		pcall(function()
			if not Blur or not Blur.Parent then
				Blur = Instance.new("BlurEffect")
				Blur.Name = "KaitunGlassBlur"
				Blur.Size = 0
				Blur.Parent = workspace.CurrentCamera
			end
			Tw(Blur, 0.3, { Size = (on and Cfg.GlassBlur ~= false) and 16 or 0 })
		end)
	end
	local function SetMenu(v)
		MenuVisible = v
		local base = math.clamp((tonumber(Cfg.UIScale) or 100) / 100, 0.7, 1.3)
		SetBlur(v)
		if v then
			Win.Visible = true
			WinScale.Scale = base * 0.92
			Tw(WinScale, 0.4, { Scale = base }, Enum.EasingStyle.Back)
		else
			Tw(WinScale, 0.18, { Scale = base * 0.92 })
			task.delay(0.2, function()
				if not MenuVisible then
					Win.Visible = false
				end
			end)
		end
	end
	MinBtn.MouseButton1Click:Connect(function()
		SetMenu(false)
	end)

	-- keeps an object's anchor point on screen while it is dragged (p = UDim2 position, size = its absolute size)
	local function ClampPos(p, anchor, size)
		local v = Viewport()
		local loX, hiX = -p.X.Scale * v.X + anchor.X * size.X, (1 - p.X.Scale) * v.X - (1 - anchor.X) * size.X
		local loY, hiY = -p.Y.Scale * v.Y + anchor.Y * size.Y, (1 - p.Y.Scale) * v.Y - (1 - anchor.Y) * size.Y
		local x = hiX >= loX and math.clamp(p.X.Offset, loX, hiX) or (loX + hiX) / 2
		local y = hiY >= loY and math.clamp(p.Y.Offset, loY, hiY) or (loY + hiY) / 2
		return UDim2.new(p.X.Scale, x, p.Y.Scale, y)
	end

	-- the K orb: a glass bubble, tap to open or close the menu, drag to move it
	local Orb = Make("TextButton", {
		Name = "Orb", Position = UDim2.new(0, 14, 0, 70), Size = UDim2.fromOffset(46, 46), ZIndex = 10,
		BackgroundColor3 = Theme.Glass, BackgroundTransparency = 0.25, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
	}, Gui)
	Round(Orb, 23)
	local OrbTint = Make("Frame", {
		Name = "Tint", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45,
		BorderSizePixel = 0, ZIndex = 10,
	}, Orb)
	Round(OrbTint, 23)
	Grad(OrbTint, Theme.Pink, Theme.Violet, 45)
	Sheen(Orb, 23, 11)
	local OrbGrad = Rim(Orb, 1.75)
	Make("TextLabel", {
		Name = "K", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "K", Font = Enum.Font.GothamBold,
		TextSize = 20, TextColor3 = Color3.new(1, 1, 1), ZIndex = 12,
	}, Orb)
	do
		local drag, moved, startPos, startOrb = false, false, nil, nil
		Orb.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				drag, moved, startPos, startOrb = true, false, i.Position, Orb.Position
				i.Changed:Connect(function()
					if i.UserInputState == Enum.UserInputState.End then
						drag = false
						if not moved then
							SetMenu(not MenuVisible)
						end
					end
				end)
			end
		end)
		Bind(UserInputService.InputChanged, function(i)
			if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				local d = i.Position - startPos
				if d.Magnitude > 6 then
					moved = true
				end
				if moved then
					Orb.Position = ClampPos(
						UDim2.new(startOrb.X.Scale, startOrb.X.Offset + d.X, startOrb.Y.Scale, startOrb.Y.Offset + d.Y),
						Vector2.new(0, 0), Orb.AbsoluteSize)
				end
			end
		end)
	end

	Bind(UserInputService.InputBegan, function(i, gp)
		if gp then
			return
		end
		local ok, key = pcall(function()
			return Enum.KeyCode[Cfg.MenuKey]
		end)
		if ok and key and i.KeyCode == key then
			SetMenu(not MenuVisible)
		end
	end)

	-- drag window by header
	do
		local dragging, startInput, startPos = false, nil, nil
		Header.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging, startInput, startPos = true, i.Position, Win.Position
				i.Changed:Connect(function()
					if i.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		Bind(UserInputService.InputChanged, function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				local d = i.Position - startInput
				Win.Position = ClampPos(
					UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y),
					Vector2.new(0.5, 0.5), Win.AbsoluteSize)
			end
		end)
	end

	-- ambient animation: the rim light slowly circles the window, the HUD and the orb
	Bind(RunService.Heartbeat, function()
		local t = os.clock()
		HeaderGrad.Rotation = (t * 18) % 360
		HudGrad.Rotation = (t * 30) % 360
		OrbGrad.Rotation = (t * 45) % 360
		HudDot.BackgroundTransparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(t * 4))
	end)


	-- live numbers
	task.spawn(function()
		local saveTick = 0
		while Running do
			pcall(function()
				if not Gui.Parent then
					PlaceGui(Gui)
				end
				local s = math.floor(os.clock() - T0)
				local level = D.Level.Value
				HudTask.Text = string.lower(Status.Task)
				HudSub.Text = Status.Sub
				HudStats.Text = string.format("Lv %d/%d  |  $%s  |  F %s  |  %02d:%02d:%02d", level, MaxLevel, Commas(D.Beli.Value), Commas(D.Fragments.Value), math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
				Tw(HudFill, 0.3, { Size = UDim2.new(math.clamp(level / MaxLevel, 0, 1), 0, 1, 0) })
				HudDot.BackgroundColor3 = Cfg.AutoFarm and Theme.Mint or Theme.Off
			end)
			pcall(function()
				Hud.Visible = Cfg.ShowHud ~= false
				PaintChip()
				for _, f in ipairs(Repaints) do
					f()
				end
			end)
			saveTick = saveTick + 1
			if saveTick % 20 == 0 then
				SaveCfg()
			end
			pcall(UpdatePages)
			task.wait(0.25)
		end
	end)

	-- shutdown
	local function Stop()
		Running = false
		SaveCfg(true)
		CancelMove()
		Anti.Kick = false
		Anti.Learn = nil
		Anti.Watch = nil
		Anti.Block = {}
		for _, c in ipairs(Conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		pcall(function()
			MusicSound:Destroy()
		end)
		pcall(function()
			if Blur then
				Blur:Destroy()
			end
		end)
		pcall(function()
			Gui:Destroy()
		end)
		pcall(function()
			RunService:Set3dRenderingEnabled(true)
		end)
	end
	getgenv().KaitunSea1 = { Stop = Stop }
	Button(SystemPage, "Unload script", Stop)

	if Cfg.Music.Enabled then
		if not ApplyMusic() then
			Cfg.Music.Enabled = false
		end
	end

	Tabs[1].pick()
	SetMenu(true)
	-- host re-check: a ScreenGui that is parented but has no layout size is not being drawn, try the next host
	task.delay(1.5, function()
		if Running and Gui.Parent and Win.Visible and Win.AbsoluteSize.X <= 0 then
			Log("menu has no layout size under host " .. tostring(Boot.host) .. ", trying the next host")
			PlaceGui(Gui, (Boot.hostIdx or 0) + 1)
		end
	end)
	Log("kaitun sea 1 loaded | place " .. tostring(game.PlaceId) .. " | KB: " .. KBSource)
	Toast("hai~ kaitun sea 1 is up :3  (" .. Cfg.MenuKey .. " toggles the menu)")
	BootStage("ready")
	task.spawn(function()
		local okA, errA = InstallAnti()
		Log(okA and "anti hook on" or ("anti hook unavailable: " .. tostring(errA)))
	end)
	Notify("kaitun sea 1", "loaded, ui host: " .. Boot.host .. ". Tap the K orb (top-left) to open or close the menu.")
	pcall(function()
		if writefile then
			writefile("KaitunBoot.log", "ok | ui host " .. Boot.host .. " | anti " .. tostring(Anti.Installed))
		end
	end)
end

local okMain, errMain = xpcall(Main, function(e)
	return debug.traceback(tostring(e), 2)
end)
if not okMain then
	warn("[kaitun] boot failed at stage '" .. Boot.stage .. "': " .. tostring(errMain))
	ShowFatal(errMain)
end
