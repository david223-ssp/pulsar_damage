-- Bone injuries (merged from Xoticz-health)
-- Server-authoritative: limb injury (0-100) + bleeding stacks per character, persisted on the
-- character ("Injuries") and mirrored to the client through the "injuries" player state bag.

local config = load(LoadResourceFile(GetCurrentResourceName(), "config/shared.lua"))()
local cfg = config.Injuries

_injuries = {}

local _classNames = {}
for name, id in pairs(Config.WeaponClasses) do
	_classNames[id] = name
end

local function text(key, ...)
	local str = cfg.text[key] or key
	if select("#", ...) > 0 then
		return str:format(...)
	end
	return str
end

local function prune(list)
	for bone, inj in pairs(list) do
		if (inj.damage or 0) <= 0 and (inj.bleeding or 0) <= 0 then
			list[bone] = nil
		end
	end
end

-- fresh copy on every sync, so plsr.State always sees a new value (the cache table is mutated in place)
local function copyInjuries(list)
	local out = {}
	for bone, inj in pairs(list or {}) do
		out[bone] = { damage = inj.damage, bleeding = inj.bleeding }
	end
	return out
end

-- mirrored to the owning client only as plsr.State.flags.injuries (medics read GetInjuries server-side)
local function syncInjuries(source, sid)
	local data = _injuries[sid] or {}
	plsr.State:SetPlayerFlag(source, "injuries", copyInjuries(data))

	local char = plsr.Fetch:CharacterSource(source)
	if char ~= nil and char:GetData("SID") == sid then
		char:SetData("Injuries", data)
	end
end

function GetInjuries(sid)
	return _injuries[sid] or {}
end

function IsBleeding(sid)
	for _, inj in pairs(_injuries[sid] or {}) do
		if (inj.bleeding or 0) > 0 then
			return true
		end
	end
	return false
end

function LoadInjuries(source, char)
	local sid = char:GetData("SID")
	local saved = char:GetData("Injuries")
	_injuries[sid] = type(saved) == "table" and saved or {}
	syncInjuries(source, sid)
end

-- damage = HP lost on the hit (already measured client-side), weaponHash = cause
function InjureLimb(source, sid, bone, damage, weaponHash)
	if not cfg.enabled or bone == nil or bone == "NONE" or Config.BoneLabels[bone] == nil then
		return
	end

	damage = tonumber(damage)
	if damage == nil then
		damage = cfg.fallbackDamage
	end
	damage = math.min(100, damage * cfg.damageMultiplier)
	if damage < cfg.minDamage then
		return
	end

	_injuries[sid] = _injuries[sid] or {}
	local inj = _injuries[sid][bone] or { damage = 0, bleeding = 0 }
	inj.damage = math.min(100, inj.damage + math.floor(damage))

	if cfg.bleed.enabled then
		local class = weaponHash and Config.WeaponClassBindings[weaponHash]
		local chance = class and cfg.bleed.chance[_classNames[class]] or cfg.bleed.defaultChance
		if math.random(100) <= chance then
			inj.bleeding = math.min(cfg.bleed.maxStacks, inj.bleeding + 1)
		end
	end

	_injuries[sid][bone] = inj
	syncInjuries(source, sid)
end

-- bones / stopBleed: number or "all"
function HealInjuries(source, bones, stopBleed)
	local char = plsr.Fetch:CharacterSource(source)
	if char == nil then
		return
	end
	local sid = char:GetData("SID")
	local list = _injuries[sid]
	if list == nil then
		return
	end

	for _, inj in pairs(list) do
		if bones then
			inj.damage = bones == "all" and 0 or math.max(0, inj.damage - bones)
		end
		if stopBleed then
			inj.bleeding = stopBleed == "all" and 0 or math.max(0, inj.bleeding - stopBleed)
		end
	end
	prune(list)
	syncInjuries(source, sid)
end

function ClearInjuries(source)
	local char = plsr.Fetch:CharacterSource(source)
	if char == nil then
		return
	end
	local sid = char:GetData("SID")
	_injuries[sid] = {}
	syncInjuries(source, sid)
end

AddEventHandler("Characters:Server:PlayerLoggedOut", function(source, cData)
	local sid = type(cData) == "table" and (cData.SID or (cData.GetData and cData:GetData("SID"))) or nil
	if sid ~= nil then
		_injuries[sid] = nil
	end
	plsr.State:SetPlayerFlag(source, "injuries", {})
end)

-- Medical items --------------------------------------------------------------------------------

local function registerItems()
	for itemName, effect in pairs(cfg.items) do
		plsr.Inventory.Items:RegisterUse(itemName, "DamageInjuries", function(source, item)
			local char = plsr.Fetch:CharacterSource(source)
			if char == nil then
				return
			end
			local sid = char:GetData("SID")

			if effect.consume then
				if plsr.State:Player(source).isDead then
					return plsr.Execute:Client(source, "Notification", "Error", text("cant_use_downed"))
				end
				if effect.requireBleeding and not IsBleeding(sid) then
					return plsr.Execute:Client(source, "Notification", "Error", text("not_bleeding"))
				end
				if not plsr.Inventory.Items:RemoveSlot(item.Owner, item.Name, 1, item.Slot, 1) then
					return
				end
			end

			local hadInjuries = next(GetInjuries(sid)) ~= nil
			local wasBleeding = IsBleeding(sid)

			HealInjuries(source, effect.bones, effect.stopBleed)

			if wasBleeding and effect.stopBleed and not IsBleeding(sid) then
				plsr.Execute:Client(source, "Notification", "Success", text("item_bleed_stopped"))
			elseif hadInjuries and effect.bones then
				plsr.Execute:Client(source, "Notification", "Success", text("item_treated"))
			end
		end)
	end
end

local function waitForInventory()
	local timeout = GetGameTimer() + 120000
	while not exports["pulsar_core"]:HasComponent("Inventory") and GetGameTimer() < timeout do
		Wait(500)
	end
	return exports["pulsar_core"]:HasComponent("Inventory")
end

-- Test commands --------------------------------------------------------------------------------

local function registerTestCommands()
	local boneKeys = {}
	for bone in pairs(Config.BoneLabels) do
		table.insert(boneKeys, bone)
	end

	plsr.Chat:RegisterAdminCommand("hurtbone", function(source, args, rawCommand)
		local char = plsr.Fetch:CharacterSource(source)
		if char == nil then
			return
		end
		local bone = args[1] and args[1]:upper() or "RANDOM"
		if bone == "RANDOM" then
			bone = boneKeys[math.random(#boneKeys)]
		end
		if Config.BoneLabels[bone] == nil then
			plsr.Chat.Send.System:Single(source, "Valid: " .. table.concat(boneKeys, ", "))
			return
		end
		InjureLimb(source, char:GetData("SID"), bone, tonumber(args[2]) or 25, `WEAPON_PISTOL`)
		plsr.Chat.Send.System:Single(source, string.format("%s injured", Config.BoneLabels[bone]))
	end, {
		help = "Injure a limb (test)",
		params = {
			{ name = "Limb", help = "LLEG, RARM, HEAD... or random" },
			{ name = "Amount", help = "Injury 0-100 (default 25)" },
		},
	}, -1)

	plsr.Chat:RegisterAdminCommand("showinjuries", function(source, args, rawCommand)
		local char = plsr.Fetch:CharacterSource(source)
		if char == nil then
			return
		end
		local list = GetInjuries(char:GetData("SID"))
		if next(list) == nil then
			plsr.Chat.Send.System:Single(source, "No injuries")
			return
		end
		for bone, inj in pairs(list) do
			plsr.Chat.Send.System:Single(
				source,
				string.format("%s: %s, %s", Config.BoneLabels[bone] or bone, text("diag_injury", inj.damage), text("diag_bleeding", inj.bleeding))
			)
		end
	end, {
		help = "Show your limb injuries (test)",
	}, -1)

	plsr.Chat:RegisterAdminCommand("clearinjuries", function(source, args, rawCommand)
		ClearInjuries(source)
		plsr.Chat.Send.System:Single(source, "Injuries cleared")
	end, {
		help = "Clear your limb injuries (test)",
	}, -1)
end

CreateThread(function()
	if not cfg.enabled then
		return
	end

	if cfg.testCommands then
		registerTestCommands()
	end

	if waitForInventory() then
		registerItems()
	else
		print("^1[pulsar_damage] Inventory component not found, injury item effects not registered^7")
	end
end)

-- pulsar_inventory keeps use callbacks in memory, re-register when it restarts
AddEventHandler("onResourceStart", function(resource)
	if resource == "pulsar_inventory" and cfg.enabled then
		CreateThread(function()
			Wait(5000)
			if waitForInventory() then
				registerItems()
			end
		end)
	end
end)
