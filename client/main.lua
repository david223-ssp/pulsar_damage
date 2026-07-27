_reductions = 0

-- isDead/deadData/isDeadTime/releaseTime are server-authoritative now (see pulsar_damage/server/main.lua's
-- health-monitor loop) - this local mirrors the confirmed server state, it never decides death itself
_dmg = {
	loggedIn = false,
	isDead = false,
}

CreateThread(function()
	plsr.State.flags.isHospitalized = false
	plsr.State.flags.isDeadTime = false
	plsr.State.flags.releaseTime = false
	plsr.State.flags.isDead = false
	plsr.State.flags.deadData = false
	plsr.State.flags.isGodmode = false

	plsr.State:Watch('flags', 'isDead', function(value)
		_dmg.isDead = value
	end)

	plsr.Callbacks:RegisterClientCallback("Damage:Client:OnDeath", function(data)
		if _dmg.isDead or not _dmg.loggedIn then
			return
		end
		_dmg.isDead = true
		plsr.State.flags.isDeadTime = data.deadTime
		plsr.State.flags.releaseTime = data.releaseTime
		plsr.Hud.DeathTexts:Show(data.isMinor and "knockout" or "death", data.deadTime, data.releaseTime)
		plsr.Hud:Dead(true)
		DoDeadEvent()

		if plsr.Jail:IsJailed() or not nearPlayer(100.0) then
			TriggerServerEvent("EmergencyAlerts:Server:DoPredefined", "injuredPerson")
		end
	end)

	plsr.Callbacks:RegisterClientCallback("Damage:Heal", function(s)
		if s then
			plsr.State.flags.deadData = {}
			plsr.Damage.Reductions:Reset()
		end
		plsr.Damage:Revive()
	end)

	plsr.Callbacks:RegisterClientCallback("Damage:FieldStabalize", function(s)
		plsr.Damage:Revive(true)
	end)

	plsr.Callbacks:RegisterClientCallback("Damage:Kill", function()
		ApplyDamageToPed(PlayerPedId(), 10000)
	end)

	plsr.Callbacks:RegisterClientCallback("Damage:Admin:Godmode", function(s)
		if s then
			plsr.Buffs:ApplyBuff("godmode")
		else
			plsr.Buffs:RemoveBuffType("godmode")
		end
	end)
end)

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Damage", DAMAGE)
end)

RegisterNetEvent("Characters:Client:Spawned", function()
	_dmg.loggedIn = true
	StartThreads()

	plsr.Buffs:RegisterBuff("weakness", "suitcase-medical", "#FF0049", -1, "permanent")
	plsr.Buffs:RegisterBuff("godmode", "shield-quartered", "#FFBB04", -1, "permanent")

	_reductions = plsr.State.character.HPReductions or 0
	if _reductions > 0 then
		plsr.Buffs:ApplyUniqueBuff("weakness", -1)
	else
		plsr.Buffs:RemoveBuffType("weakness")
	end
	plsr.Damage:CalculateMaxHp()

	if plsr.State.flags.isDead then
		local deadData = plsr.State.flags.deadData
		plsr.Hud.DeathTexts:Show(
			deadData and deadData.isMinor and "knockout" or "death",
			plsr.State.flags.isDeadTime,
			plsr.State.flags.releaseTime
		)
		plsr.Hud:Dead(true)
		DoDeadEvent()
	end
end)

RegisterNetEvent("Characters:Client:Logout", function()
	_dmg.loggedIn = false
	if plsr.State.flags.isDead then
		AnimpostfxStop("DeathFailMPIn")
		plsr.Hud.DeathTexts:Hide()
		ClearPedTasksImmediately(PlayerPedId())
	end

	plsr.Buffs:RemoveBuffType("weakness")
end)

RegisterNetEvent('UI:Client:Reset', function(apps)
	if not plsr.State.flags.isDead and not plsr.State.flags.isHospitalized then
		plsr.Hud.DeathTexts:Hide()
		plsr.Hud:Dead(false)
		if _reductions > 0 then
			plsr.Buffs:ApplyUniqueBuff("weakness", -1)
		else
			plsr.Buffs:RemoveBuffType("weakness")
		end
	end
end)

DAMAGE = {
	Reductions = {
		Increase = function(self, amt)
			_reductions += amt
			plsr.Buffs:ApplyUniqueBuff("weakness", -1)
			plsr.Callbacks:ServerCallback("Damage:SyncReductions", _reductions)
			plsr.Damage:CalculateMaxHp()
		end,
		Reset = function(self)
			_reductions = 0
			plsr.Buffs:RemoveBuffType("weakness")
			plsr.Callbacks:ServerCallback("Damage:SyncReductions", _reductions)
			plsr.Damage:CalculateMaxHp()
		end,
	},
	CalculateMaxHp = function(self)
		local ped = PlayerPedId()
		local curr = GetEntityHealth(ped)
		local currMax = GetEntityMaxHealth(ped)

		local mod = 0.25 * _reductions
		if mod > 0.8 then
			mod = 0.8
		end

		local newMax = 100 + math.ceil(100 * (1.0 - mod))

		SetEntityMaxHealth(ped, newMax)

		local newHp = curr
		if curr > newMax then
			SetEntityHealth(ped, newMax)
		end

		plsr.Hud:ForceHP()
	end,
	Revive = function(self, fieldTreat)
		local player = PlayerPedId()

		if plsr.State.flags.isDead then
			DoScreenFadeOut(1000)
			while not IsScreenFadedOut() do
				Wait(10)
			end
		end

		local wasDead = plsr.State.flags.isDead
		local deadData = plsr.State.flags.deadData
		local wasMinor = deadData and deadData.isMinor

		_dmg.isDead = false

		local veh = GetVehiclePedIsIn(player)
		local seat = 0
		if veh ~= 0 then
			local m = GetEntityModel(veh)
			for k = -1, GetVehicleModelNumberOfSeats(m) do
				if GetPedInVehicleSeat(veh, k) == player then
					seat = k
				end
			end
		end

		if veh == 0 then
			--ClearPedTasksImmediately(player)
		else
			Wait(300)
			TaskWarpPedIntoVehicle(player, veh, seat)
			Wait(300)
		end

		TriggerServerEvent("Damage:Server:Revived", wasMinor, fieldTreat)
		plsr.Hud:Dead(false)

		if not plsr.State.flags.isHospitalized and wasDead then
			plsr.Hud.DeathTexts:Hide()
			SetEntityInvincible(player, plsr.State.flags.isAdmin and plsr.State.flags.isGodmode or false)
		end

		if _reductions > 0 then
			plsr.Buffs:ApplyUniqueBuff("weakness", -1)
		else
			plsr.Buffs:RemoveBuffType("weakness")
		end

		local mod = 0.25 * _reductions
		if mod > 0.8 then
			mod = 0.8
		end
		local newMax = 100 + math.ceil(100 * (1.0 - mod))

		SetEntityHealth(player, newMax)
		SetPlayerSprint(PlayerId(), true)
		ClearPedBloodDamage(player)

		if not fieldTreat then
			plsr.Status:Reset()
		end

		DoScreenFadeIn(1000)

		if not plsr.State.flags.isHospitalized and wasDead and veh == 0 then
			plsr.Animations.Emotes:Play("reviveshit", false, 1750, true)
		end
	end,
	Died = function(self) end,
	Apply = {
		StandardDamage = function(self, value, armorFirst, forceKill)
			ApplyDamageToPed(PlayerPedId(), value, armorFirst)
		end,
	},
}
