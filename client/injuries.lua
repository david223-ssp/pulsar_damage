-- Bone injuries (merged from Xoticz-health) - client effects.
-- The server owns the data (server/injuries.lua) and mirrors it to plsr.State.flags.injuries.
-- Limp is applied through ApplyLimp (client/functions.lua) so it shares pulsar_animations' limp.

local config = load(LoadResourceFile(GetCurrentResourceName(), "config/shared.lua"))()
local cfg = config.Injuries

function GetMyInjuries()
	return plsr.State.flags.injuries or {}
end

function GetBleedStacks()
	local total = 0
	for _, inj in pairs(GetMyInjuries()) do
		total = total + (inj.bleeding or 0)
	end
	return total
end

function HasLimpInjury()
	if not cfg.enabled then
		return false
	end
	for bone, inj in pairs(GetMyInjuries()) do
		if cfg.limpParts[bone] and (inj.damage or 0) >= cfg.limpThreshold then
			return true
		end
	end
	return false
end

-- Bleeding
CreateThread(function()
	local ticks = 0
	while true do
		Wait(cfg.bleed.tickInterval)

		if cfg.enabled and cfg.bleed.enabled and _dmg.loggedIn and not _dmg.isDead
			and not plsr.State.flags.isHospitalized
			and not (plsr.State.flags.isAdmin and plsr.State.flags.isGodmode) then
			local stacks = GetBleedStacks()

			if stacks > 0 then
				local ped = PlayerPedId()
				local hp = GetEntityHealth(ped)
				local newHp = math.max(cfg.bleed.minHealth, hp - stacks * cfg.bleed.damagePerTick)
				if newHp < hp then
					SetEntityHealth(ped, newHp)
					_hpSnapshot = newHp
				end

				ticks = ticks + 1
				if cfg.bleed.notifyEvery > 0 and ticks % cfg.bleed.notifyEvery == 1 then
					plsr.Notification:Error(cfg.text.bleeding_reminder)
				end
			else
				ticks = 0
			end
		else
			ticks = 0
		end
	end
end)
