_damagedLimbs = {}
_deadCunts = {}
_hasKO = {}
_lastDamageHash = {}

local config = load(LoadResourceFile(GetCurrentResourceName(), "config/shared.lua"))()
GlobalState["Medical:Pricing"] = config.Medical.checkInPrice

function table.copy(t)
	local u = {}
	for k, v in pairs(t) do
		u[k] = v
	end
	return setmetatable(u, getmetatable(t))
end

local function getReleaseTime(source, isMinor)
	if isMinor then
		return config.Medical.releaseTime.knockedOut
	end
	local onDuty = plsr.State:Player(source).onDuty
	if onDuty == "police" or onDuty == "ems" then
		return config.Medical.releaseTime.onDutyStaff
	end
	return config.Medical.releaseTime.civilian
end

local function handleDeath(source, char)
	local sid = char:GetData("SID")
	if _deadCunts[sid] ~= nil then
		return
	end

	local ped = GetPlayerPed(source)
	local deathHash = GetPedCauseOfDeath(ped)
	if not deathHash or deathHash == 0 then
		deathHash = _lastDamageHash[sid] or 0
	end

	local weapEntry = Config.Weapons[deathHash]
	local isMinor = weapEntry ~= nil and weapEntry.minor or false

	if _hasKO[sid] then
		isMinor = false
	elseif isMinor then
		_hasKO[sid] = true
		SetTimeout(300000, function()
			_hasKO[sid] = nil
		end)
	end

	local deadTime = os.time()
	local releaseTime = deadTime + getReleaseTime(source, isMinor)

	_deadCunts[sid] = {
		deadData = { isMinor = isMinor },
		isDeadTime = deadTime,
		releaseTime = releaseTime,
	}

	plsr.State:SetPublicFlag(source, 'isDead', true)
	plsr.State:SetPublicFlag(source, 'deadData', { isMinor = isMinor })
	plsr.State:Player(source).isDeadTime = deadTime
	plsr.State:Player(source).releaseTime = releaseTime

	plsr.Callbacks:ClientCallback(source, "Damage:Client:OnDeath", {
		isMinor = isMinor,
		deadTime = deadTime,
		releaseTime = releaseTime,
	})
end

CreateThread(function()
	RegisterChatCommands()

	plsr.Middleware:Add("Characters:Spawning", function(source)
		local char = plsr.Fetch:CharacterSource(source)
		if char ~= nil then
			local sid = char:GetData("SID")
			if _deadCunts[sid] ~= nil then
				plsr.State:SetPublicFlag(source, 'isDead', true)
				plsr.State:SetPublicFlag(source, 'deadData', _deadCunts[sid].deadData)
				plsr.State:Player(source).isDeadTime = _deadCunts[sid].isDeadTime
				plsr.State:Player(source).releaseTime = _deadCunts[sid].releaseTime

				Wait(100)
			end

			if char:GetData("Damage") ~= nil then
				char:SetData("Damage", nil)
			end
			_damagedLimbs[sid] = _damagedLimbs[sid] or {}
			LoadInjuries(source, char)
		end
	end, 2)

	plsr.Callbacks:RegisterServerCallback("Damage:GetLimbDamage", function(source, data, cb)
		if data == nil or source == nil then
			cb({})
			return
		end
		local char = plsr.Fetch:CharacterSource(data)
		if char ~= nil then
			local damage = plsr.Damage:GetLimbDamage(char:GetData("SID"))

			local menuData = {}

			local reductions = char:GetData("HPReductions") or 0
			if reductions > 0 then
				if reductions > 1 then
					table.insert(menuData, {
						label = "Signs of Trauma",
						description = "Signs of multiple major traumas (Health Reduced)",
					})
				else
					table.insert(menuData, {
						label = "Sign of Trauma",
						description = "Sign of major trauma (Health Reduced)",
					})
				end
			end

			local injuries = GetInjuries(char:GetData("SID"))

			local bleedingLimbs = 0
			for _, inj in pairs(injuries) do
				if (inj.bleeding or 0) > 0 then
					bleedingLimbs += 1
				end
			end
			if bleedingLimbs > 0 then
				table.insert(menuData, {
					label = config.Injuries.text.diag_bleeding_summary_label,
					description = string.format(config.Injuries.text.diag_bleeding_summary, bleedingLimbs),
				})
			end

			local limbs = {}
			for k in pairs(damage or {}) do
				limbs[k] = true
			end
			for k in pairs(injuries) do
				limbs[k] = true
			end

			for k in pairs(limbs) do
				local data = {}
				for k2, v2 in pairs((damage or {})[k] or {}) do
					if v2 > 0 then
						table.insert(data, string.format("%s %s", v2, Config.DamageTypeLabels[k2]))
					end
				end

				local inj = injuries[k]
				if inj ~= nil then
					if (inj.damage or 0) > 0 then
						table.insert(data, string.format(config.Injuries.text.diag_injury, inj.damage))
					end
					if (inj.bleeding or 0) > 0 then
						table.insert(data, string.format(config.Injuries.text.diag_bleeding, inj.bleeding))
					end
				end

				if #data > 0 then
					table.insert(menuData, {
						label = Config.BoneLabels[k],
						description = table.concat(data, ", "),
					})
				end
			end

			if #menuData == 0 then
				table.insert(menuData, {
					label = "No Observed Injuries",
				})
			end

			cb(menuData)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Damage:SyncReductions", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		if char ~= nil then
			char:SetData("HPReductions", data)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Damage:CanRelease", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		if char == nil then
			cb(false)
			return
		end
		local entry = _deadCunts[char:GetData("SID")]
		if entry == nil then
			cb(false)
			return
		end
		cb(os.time() >= entry.releaseTime)
	end)

	CreateThread(function()
		while true do
			local players = GetPlayers()
			local count = #players
			if count > 0 then
				local interval = math.max(50, math.floor(250 / count))
				for _, srcStr in ipairs(players) do
					local src = tonumber(srcStr)
					local char = plsr.Fetch:CharacterSource(src)
					if char ~= nil then
						local sid = char:GetData("SID")
						if _deadCunts[sid] == nil then
							local ped = GetPlayerPed(src)
							if ped ~= 0 and GetEntityHealth(ped) <= 100 then
								handleDeath(src, char)
							end
						end
					end
					Wait(interval)
				end
			else
				Wait(1000)
			end
		end
	end)
end)

DAMAGE = {
	GetLimbDamage = function(self, sid)
		return _damagedLimbs[sid]
	end,
	ResetLimbDamage = function(self, sid)
		_damagedLimbs[sid] = {}
	end,
	Injuries = {
		Get = function(self, sid)
			return GetInjuries(sid)
		end,
		IsBleeding = function(self, sid)
			return IsBleeding(sid)
		end,
		Add = function(self, source, bone, damage, weaponHash)
			local char = plsr.Fetch:CharacterSource(source)
			if char ~= nil then
				InjureLimb(source, char:GetData("SID"), bone, damage, weaponHash)
			end
		end,
		Heal = function(self, source, bones, stopBleed)
			HealInjuries(source, bones, stopBleed)
		end,
		Clear = function(self, source)
			ClearInjuries(source)
		end,
	},
	Effects = {
		Painkiller = function(self, source, tier)
			plsr.Callbacks:ClientCallback(source, "Damage:ApplyPainkiller", config.Medical.painkillerHeal * (tier or 1))
		end,
		Adrenaline = function(self, source, tier)
			plsr.Callbacks:ClientCallback(source, "Damage:ApplyAdrenaline", config.Medical.adrenalineHeal * (tier or 1))
		end,
	},
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Damage", DAMAGE)
end)

AddEventHandler("Characters:Server:PlayerLoggedOut", function(source, cData)
	SetPlayerInvincible(source, false)
	plsr.State:Player(source).isGodmode = false
end)

RegisterNetEvent("Damage:Server:StoreHealth", function(hp, armor)
	local src = source
	local char = plsr.Fetch:CharacterSource(src)
	if char ~= nil then
		char:SetData("HP", hp)
		char:SetData("Armor", armor)
	end
end)

RegisterNetEvent("Damage:Server:BoneDamage", function(damageData)
	local src = source
	local char = plsr.Fetch:CharacterSource(src)
	if char == nil then
		return
	end
	local sid = char:GetData("SID")

	_lastDamageHash[sid] = damageData.hash

	local wasDownBeforeHit = _deadCunts[sid] ~= nil

	local boneName = Config.Bones[damageData.bone]
	if boneName == nil or boneName == "NONE" then
		local fallback = config.Injuries.noBoneFallback and config.Injuries.noBoneFallback[damageData.hash]
		if fallback and #fallback > 0 then
			boneName = fallback[math.random(#fallback)]
		end
	end
	if boneName ~= nil and boneName ~= "NONE" then
		if _damagedLimbs[sid][boneName] == nil then
			_damagedLimbs[sid][boneName] = {}
			for k2, v2 in ipairs(Config.DamageTypes) do
				_damagedLimbs[sid][boneName][v2] = 0
			end
		end
		local dmgType = Config.ClassDamageTypes[Config.WeaponClassBindings[damageData.hash]]
		if dmgType ~= nil then
			_damagedLimbs[sid][boneName][dmgType] += 1
		end

		if not wasDownBeforeHit then
			InjureLimb(src, sid, boneName, damageData.damage, damageData.hash)
		end
	end

	-- a violent hit on an already-downed (minor) player escalates them to a full death
	local deadEntry = _deadCunts[sid]
	if deadEntry ~= nil and deadEntry.deadData.isMinor then
		local weapEntry = Config.Weapons[damageData.hash]
		if weapEntry ~= nil and weapEntry.violent then
			local releaseTime = os.time() + getReleaseTime(src, false)
			deadEntry.deadData.isMinor = false
			deadEntry.releaseTime = releaseTime

			plsr.State:SetPublicFlag(src, 'deadData', deadEntry.deadData)
			plsr.State:Player(src).releaseTime = releaseTime

			plsr.Callbacks:ClientCallback(src, "Damage:Client:OnDeath", {
				isMinor = false,
				deadTime = deadEntry.isDeadTime,
				releaseTime = releaseTime,
			})
		end
	end
end)

RegisterNetEvent("Damage:Server:Revived", function(wasMinor, wasFieldTreatment)
	local src = source
	local char = plsr.Fetch:CharacterSource(src)
	if char == nil then
		return
	end
	local sid = char:GetData("SID")

	_deadCunts[sid] = nil

	plsr.State:SetPublicFlag(src, 'isDead', false)
	plsr.State:SetPublicFlag(src, 'deadData', false)

	if not wasMinor and not wasFieldTreatment then
		plsr.Logger:Trace(
			"Damage",
			string.format(
				"%s %s (%s) Was Revived (Not Minor and Not Field Treatment)",
				char:GetData("First"),
				char:GetData("Last"),
				sid
			)
		)
		plsr.Damage:ResetLimbDamage(sid)
		if config.Injuries.clearOnRevive then
			ClearInjuries(src)
		end
	else
		if wasMinor then
			plsr.Logger:Trace(
				"Damage",
				string.format("%s %s (%s) Was Revived (Minor Injury)", char:GetData("First"), char:GetData("Last"), sid)
			)
		else
			plsr.Logger:Trace(
				"Damage",
				string.format("%s %s (%s) Was Revived (Field Treatment)", char:GetData("First"), char:GetData("Last"), sid)
			)
		end
	end
end)
