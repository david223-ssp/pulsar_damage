local config = load(LoadResourceFile(GetCurrentResourceName(), "config/shared.lua"))()

local koDict = "mini@cpr@char_b@cpr_def"
local koAnim = "cpr_pumpchest_idle"

local deadDict = "dead"
local deadAnim = "dead_d"

local vehDict = "veh@low@front_ps@idle_duck"
local vehAnim = "sit"

local drownDict = "dam_ko"
local drownAnim = "drown"

CreateThread(function()
	loadAnimDict(koDict)
	loadAnimDict(deadDict)
	loadAnimDict(vehDict)
end)

function ApplyLimp(ped)
	-- limp from low HP or from a leg/foot/pelvis injury (client/injuries.lua); painkillers suppress both
	local lowHp = (GetEntityHealth(ped) - 100) <= math.floor((GetEntityMaxHealth(ped) - 100) * config.Vitals.limpThreshold)
	local shouldLimp = lowHp or HasLimpInjury()
	if shouldLimp and not ((plsr.State.flags.onPainKillers or 0) > 0) then
		if not plsr.State.flags.isLimping then
			plsr.State.flags.isLimping = true
			plsr.Animations.PedFeatures:RequestFeaturesUpdate()
		end
	else
		if plsr.State.flags.isLimping then
			plsr.State.flags.isLimping = false
			plsr.Animations.PedFeatures:RequestFeaturesUpdate()
		end
	end
end

function DoDeadEvent()
	if _dmg.isDead then
		plsr.Weapons:UnequipIfEquippedNoAnim()
		if not plsr.State.flags.gameMode then
			plsr.Buffs:RemoveBuffType("weakness")
			DisableControls()
			DeadAnimLoop()
		else
			plsr.Hud.DeathTexts:Hide()
			TriggerEvent(string.format("Damage:Client:Gamemode:%s:Died", plsr.State.flags.gameMode))
		end
	else
		plsr.Hud.DeathTexts:Hide()
		ClearPedTasksImmediately(PlayerPedId())
		SetEntityInvincible(PlayerPedId(), plsr.State.flags.isAdmin and plsr.State.flags.isGodmode or false)
	end
end

local deathLooping = false
local aDict = deadDict
local aAnim = deadAnim

function DeadAnimLoop()
	CreateThread(function()
		local ped = PlayerPedId()

		aDict = deadDict
		aAnim = deadAnim

		local seat = 0
		local veh = GetVehiclePedIsIn(ped)
		if veh ~= 0 then
			local m = GetEntityModel(veh)
			for k = -1, GetVehicleModelNumberOfSeats(m) do
				if GetPedInVehicleSeat(veh, k) == ped then
					seat = k
				end
			end
		end

		DoScreenFadeOut(1000)
		while not IsScreenFadedOut() do
			Wait(10)
		end

		AnimpostfxPlay("DeathFailMPIn", 100.0, true)

		local loc = GetEntityCoords(ped)
		NetworkResurrectLocalPlayer(loc, true, true, false)

		if not veh then
			ClearPedTasksImmediately(ped)
		else
			TaskWarpPedIntoVehicle(ped, veh, seat)
			Wait(300)
		end

		local deadData = plsr.State.flags.deadData
		if type(deadData) == "table" and deadData.isMinor then
			aDict = koDict
			aAnim = koAnim
		end

		DoScreenFadeIn(1000)

		SetEntityHealth(ped, 200)

		if not deathLooping then
			deathLooping = true

			while _dmg.loggedIn and _dmg.isDead and not plsr.State.flags.isHospitalized do
				ped = PlayerPedId()

				local dd = plsr.State.flags.deadData
				if not (dd and dd.isMinor) then
					SetEntityInvincible(ped, true)
				else
					SetEntityInvincible(ped, false)
				end

				if IsPedInAnyVehicle(ped) then
					TaskPlayAnim(ped, vehDict, vehAnim, 8.0, -8, -1, 1, 0, 0, 0, 0)
				elseif IsEntityInWater(ped) then
					TaskPlayAnim(ped, drownDict, drownAnim, 8.0, -8, -1, 1, 0, 0, 0, 0)
				elseif plsr.State.flags.inTrunk then
					-- dosomething?
				else
					TaskPlayAnim(ped, aDict, aAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
				end
				Wait(100)
			end

			AnimpostfxStop("DeathFailMPIn")

			plsr.Hud.DeathTexts:Hide()
			ClearPedTasksImmediately(ped)
			SetEntityInvincible(ped, plsr.State.flags.isAdmin and plsr.State.flags.isGodmode or false)

			deathLooping = false
		end
	end)
end

local disabling = false
function DisableControls()
	if disabling then return end
	disabling = true
	CreateThread(function()
		while _dmg.loggedIn and _dmg.isDead do
			DisableControlAction(0, 30, true) -- disable left/right
			DisableControlAction(0, 31, true) -- disable forward/back
			DisableControlAction(0, 36, true) -- INPUT_DUCK
			DisableControlAction(0, 21, true) -- disable sprint
			DisableControlAction(0, 44, true) -- disable cover
			DisableControlAction(0, 63, true) -- veh turn left
			DisableControlAction(0, 64, true) -- veh turn right
			DisableControlAction(0, 71, true) -- veh forward
			DisableControlAction(0, 72, true) -- veh backwards
			DisableControlAction(0, 75, true) -- disable exit vehicle
			DisablePlayerFiring(PlayerId(), true) -- Disable weapon firing
			DisableControlAction(0, 24, true) -- disable attack
			DisableControlAction(0, 25, true) -- disable aim
			DisableControlAction(1, 37, true) -- disable weapon select
			DisableControlAction(0, 47, true) -- disable weapon
			DisableControlAction(0, 58, true) -- disable weapon
			DisableControlAction(0, 140, true) -- disable melee
			DisableControlAction(0, 141, true) -- disable melee
			DisableControlAction(0, 142, true) -- disable melee
			DisableControlAction(0, 143, true) -- disable melee
			DisableControlAction(0, 263, true) -- disable melee
			DisableControlAction(0, 264, true) -- disable melee
			DisableControlAction(0, 257, true) -- disable melee
			Wait(1)
		end
		disabling = false
	end)
end

function nearPlayer(dist)
	local peds = GetGamePool("CPed")
	local myCoords = GetEntityCoords(PlayerPedId())
	for _, ped in ipairs(peds) do
		if ped ~= PlayerPedId() and IsPedAPlayer(ped) then
			local entCoords = GetEntityCoords(ped)
			if #(entCoords - myCoords) <= dist then
				return true
			end
		end
	end

	return false
end
