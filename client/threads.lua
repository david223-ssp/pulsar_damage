local config = load(LoadResourceFile(GetCurrentResourceName(), "config/shared.lua"))()

function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

local hasBled = false
AddEventHandler("Damage:Client:Triggers:EntityDamaged", function(victim, attacker, pWeapon, isMelee)
    if victim ~= PlayerPedId() then return end

    if plsr.State.flags.isAdmin and plsr.State.flags.isGodmode then
        return
    end

    local hit, bone = GetPedLastDamageBone(victim)

	-- HP lost on this hit, used by the bone injury system (server/injuries.lua)
	local hpNow = GetEntityHealth(victim)
	local hpLost = (_hpSnapshot or hpNow) - hpNow
	_hpSnapshot = hpNow

	-- reported per-hit (not batched) so the server always has a fresh cause-of-death fallback
	TriggerServerEvent("Damage:Server:BoneDamage", {
        hash = pWeapon,
        source = attacker,
        melee = isMelee,
        bone = bone,
        damage = hpLost > 0 and hpLost or nil,
    })

	local armor = GetPedArmour(PlayerPedId())

	if not hasBled and armor <= 0 then
		hasBled = true
		TriggerEvent('Evidence:Client:BleedOnFloor')
		SetTimeout(1000 * 30, function()
			hasBled = false
		end)
	end
end)

AddEventHandler("Keybinds:Client:KeyUp:secondary_action", function()
	if (_dmg.isDead and not plsr.State.flags.isHospitalized) and GetCloudTimeAsInt() > plsr.State.flags.releaseTime and not _respawning then
		_respawning = true
		TriggerServerEvent("Escort:Server:ForceStop")

        plsr.Hud.DeathTexts:Release()
		local deadData = plsr.State.flags.deadData
		if not (deadData and deadData.isMinor) then
			plsr.Progress:Progress({
				name = "hospital_action",
				duration = config.Medical.respawnDuration,
				label = "Respawning",
				useWhileDead = true,
				canCancel = true,
				ignoreModifier = true,
				controlDisables = {
					disableMovement = true,
					disableCarMovement = true,
					disableMouse = false,
					disableCombat = true,
				},
				animation = false,
			}, function(status)
				if not status then
					plsr.Callbacks:ServerCallback("Hospital:Respawn", {}, function(bedId)
						if bedId ~= nil then
							TriggerServerEvent("Escort:Server:ForceStop")
							_sendToHosp = bedId
							plsr.State:SetPublicClientFlag('isHospitalized', true)
							Wait(250)
							plsr.Hospital:SendToBed(config.Hospital.beds[_sendToHosp], false, bedId)
						else
							plsr.Notification:Error("Unable To Respawn Yet, Please Wait")
						end
					end)
				else
					local dd = plsr.State.flags.deadData
                    plsr.Hud.DeathTexts:Show(dd and dd.isMinor and "knockout" or "death", plsr.State.flags.isDeadTime, plsr.State.flags.releaseTime)
				end
				_respawning = false
			end)
		else
			plsr.Damage:Revive()
			_respawning = false
		end
	end
end)

RegisterNetEvent("Damage:Client:Ticks:Heal", function()
	plsr.Buffs:ApplyUniqueBuff("heal_ticks", #plsr.State.flags.healTicks * 10, false, {
		customMax = #plsr.State.flags.healTicks * 10,
	})
end)

RegisterNetEvent("Damage:Client:Ticks:Armor", function()
	plsr.Buffs:ApplyUniqueBuff("armor_ticks", #plsr.State.flags.armorTicks * 10, false, {
		customMax = #plsr.State.flags.armorTicks * 10,
	})
end)

function StartThreads()
	plsr.State.flags.regenRate = 0.0
	plsr.State.flags.isLimping = false
	plsr.State.flags.wasOnPainKillers = false
	plsr.State.flags.wasOnDrugs = false

    CreateThread(function()
        while _dmg.loggedIn do
            if GetPedStealthMovement(PlayerPedId()) then
                SetPedStealthMovement(PlayerPedId(), 0, 0)
            end
            Wait(20)
        end
    end)

	-- HP snapshot so each hit can measure how much HP it took (see EntityDamaged handler)
	CreateThread(function()
		while _dmg.loggedIn do
			_hpSnapshot = GetEntityHealth(PlayerPedId())
			Wait(250)
		end
	end)

	local lastHp = 0
	local lastArmor = 0
    CreateThread(function()
        local sid = plsr.State.character.SID
        while _dmg.loggedIn do
            Wait((1000 * 60) * 1)
            if sid == plsr.State.character.SID then
				local hp = GetEntityHealth(PlayerPedId())
				local armor = GetPedArmour(PlayerPedId())
				if hp ~= lastHp or armor ~= lastArmor then
					lastHp = hp
					lastArmor = armor
					TriggerServerEvent("Damage:Server:StoreHealth", hp, armor)
				end
            end
        end
    end)

	CreateThread(function()
		while _dmg.loggedIn do
			if not plsr.State.flags.inCreator then
				Wait(10000)
				local max = GetEntityMaxHealth(PlayerPedId()) - 100

				local s10 = math.ceil(max * config.Vitals.flashThresholds.s10)
				local s25 = math.ceil(max * config.Vitals.flashThresholds.s25)
				local s50 = math.ceil(max * config.Vitals.flashThresholds.s50)

				local myhp = GetEntityHealth(PlayerPedId()) - 100
				if myhp <= s10 then
					SetFlash(0, 0, 500, math.random(10) * 1000, 500)
				elseif myhp <= s25 then
					SetFlash(0, 0, 500, math.random(5) * 1000, 500)
				elseif myhp <= s50 then
					SetFlash(0, 0, 500, math.random(2) * 1000, 500)
				else
					SetFlash(0, 0, 1, 0, 1)
				end
			else
				Wait(30000)
			end
		end
	end)

    CreateThread(function()
		if _healTickRunning then
			return
		end
		_healTickRunning = true
		while _dmg.loggedIn do
			if plsr.State.flags.healTicks ~= nil then
				local chp = GetEntityHealth(PlayerPedId())
				local max = GetEntityMaxHealth(PlayerPedId())

				if chp >= max then
					plsr.Buffs:RemoveBuffType("heal_ticks")
					plsr.State.flags.healTicks = nil
				else
					local heal = plsr.State.flags.healTicks[1] or 0
					if chp + heal > max then
						heal = max - chp
					end

					if chp + heal <= max then
						plsr.Logger:Trace(
							"Damage",
							string.format("Heal Tick: %s (Original: %s)", heal, plsr.State.flags.healTicks[1])
						)
						SetEntityHealth(PlayerPedId(), chp + heal)

						if chp + heal >= max then
							plsr.Buffs:RemoveBuffType("heal_ticks")
						end
					end

					local t = plsr.State.flags.healTicks
					table.remove(t, 1)
					if #t > 0 then
						plsr.State.flags.healTicks = t
					else
						plsr.Buffs:RemoveBuffType("heal_ticks")
						plsr.State.flags.healTicks = nil
					end
				end
				Wait(10000)
			else
				Wait(2000)
			end
		end
		_healTickRunning = false
	end)

	CreateThread(function()
		if _armrTickRunning then
			return
		end
		_armrTickRunning = true
		while _dmg.loggedIn do
			if plsr.State.flags.armorTicks ~= nil then
				local car = GetPedArmour(PlayerPedId())
				local max = GetPlayerMaxArmour(plsr.State.flags.PlayerID)

				if car >= max then
					plsr.Buffs:RemoveBuffType("armor_ticks")
					plsr.State.flags.armorTicks = nil
				else
					local gen = plsr.State.flags.armorTicks[1] or 0
					if car + gen > max then
						gen = max - car
					end

					if car + gen <= max then
						plsr.Logger:Trace(
							"Damage",
							string.format("Armor Tick: %s (Original: %s)", gen, plsr.State.flags.armorTicks[1])
						)
						SetPedArmour(PlayerPedId(), car + gen)

						if car + gen >= max then
							plsr.Buffs:RemoveBuffType("armor_ticks")
						end
					end

					local t = plsr.State.flags.armorTicks
					table.remove(t, 1)
					if #t > 0 then
						plsr.State.flags.armorTicks = t
					else
						plsr.Buffs:RemoveBuffType("armor_ticks")
						plsr.State.flags.armorTicks = nil
					end
				end
				Wait(10000)
			else
				Wait(2000)
			end
		end
		_armrTickRunning = false
	end)

	CreateThread(function()
		while _dmg.loggedIn do
			if plsr.State.flags.isLimping then
				local luck = math.random(100)
				if
					(IsPedJumping(PlayerPedId()) and luck <= config.Vitals.ragdollChance.jumping)
					or (IsPedSprinting(PlayerPedId()) and luck <= config.Vitals.ragdollChance.sprinting)
				then
					SetPedToRagdoll(PlayerPedId(), 1500, 2000, 3, true, true, false)
				end

				Wait(100)
			else
				Wait(2500)
			end
		end
	end)

    CreateThread(function()
		while _dmg.loggedIn do
            if plsr.State.flags.onPainKillers ~= nil and plsr.State.flags.onPainKillers > 0 then
				plsr.State.flags.onPainKillers = plsr.State.flags.onPainKillers - 1
			elseif plsr.State.flags.wasOnPainKillers then
				plsr.State.flags.wasOnPainKillers = false
			end

			if plsr.State.flags.onDrugs ~= nil and plsr.State.flags.onDrugs > 0 then
				plsr.State.flags.onDrugs = plsr.State.flags.onDrugs - 1
			elseif plsr.State.flags.wasOnDrugs then
				plsr.State.flags.wasOnDrugs = false
			end

			ApplyLimp(PlayerPedId())
			Wait(200)
		end
	end)

    CreateThread(function()
        while _dmg.loggedIn do
            SetPlayerHealthRechargeMultiplier(plsr.State.flags.PlayerID, plsr.State.flags.regenRate)
            Wait(250)
        end
    end)
end
