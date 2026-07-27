local config = load(LoadResourceFile(GetCurrentResourceName(), "config/shared.lua"))()

function PrisonVisitation()
	plsr.Polyzone.Create:Box("prison_visitation", vector3(1831.24, 2585.78, 46.01), 12.4, 8.2, {
		heading = 0,
		--debugPoly=true,
		minZ = 44.21,
		maxZ = 49.01,
	}, {
		disableEscorting = true,
		disableInventory = true,
		allowJobs = { "ems", "prison", "police" },
	})
end

function PrisonHospitalInit()
	plsr.PedInteraction:Add(
		"PrisonHospital",
		`s_m_m_doctor_01`,
		vector3(1769.832, 2571.891, 44.730),
		138.556,
		config.Prison.location.radius,
		{},
		"suitcase-medical",
		"WORLD_HUMAN_CLIPBOARD"
	)

	plsr.Polyzone.Create:Box(
		"prison-hospital-check-in-zone",
		config.Prison.location.coords,
		config.Prison.location.width,
		config.Prison.location.length,
		{
			heading = config.Prison.location.heading,
			--debugPoly=true,
			minZ = config.Prison.location.coords.z - 1.0,
			maxZ = config.Prison.location.coords.z + 1.0,
		},
		{}
	)
end

local _inCheckInZone = false

AddEventHandler("Polyzone:Enter", function(id, point, insideZone, data)
	if id == "prison-hospital-check-in-zone" then
		_inCheckInZone = true
		if plsr.State.flags.myEscorter == nil then
			plsr.Action:Show(
				"medical",
				"{keybind}primary_action{/keybind} Check In {key}$" .. config.Prison.checkInPrice .. "{/key}"
			)
		end
	end

	if id == "prison_visitation" and not hasValue(data.allowJobs, plsr.State.flags.onDuty) then
		if data.disableEscorting then
			plsr.State.flags.AllowEscorting = false
		end
		if data.disableInventory then
			plsr.Inventory:Disable()
		end
	end
end)

AddEventHandler("Polyzone:Exit", function(id, point, insideZone, data)
	if id == "prison-hospital-check-in-zone" then
		_inCheckInZone = false
		plsr.Action:Hide("medical")
	end
	if id == "prison_visitation" then
		if data.disableEscorting then
			plsr.State.flags.AllowEscorting = true
		end
		if data.disableInventory then
			plsr.Inventory:Enable()
		end
	end
end)

AddEventHandler("Keybinds:Client:KeyUp:primary_action", function()
	if _inCheckInZone then
		if not plsr.State.flags.doingAction and not plsr.State.flags.myEscorter ~= nil then
			TriggerEvent("Hospital:Client:PrisonHospitalRevive")
		end
	end
end)

AddEventHandler("Hospital:Client:PrisonHospitalRevive", function(entity, data)
	local _animDict = "move_m@_idles@shake_off"
	local _anim = "shakeoff_1"
	local _animFlag = 49
	local _animTask = ""
	local _animObj = {}

	_animObj = {
		animDict = _animDict,
		anim = _anim,
		flags = _animFlag,
	}

	if _dmg.isDead then
		_animObj = {
			animDict = "dead",
			anim = "dead_d",
			flags = 1,
		}
	end

	plsr.Progress:Progress({
		name = "prison_hospital_revive_action",
		duration = (math.random(config.Prison.healingDuration.variance) + config.Prison.healingDuration.base) * 1000,
		label = "Healing",
		useWhileDead = true,
		canCancel = true,
		ignoreModifier = true,
		controlDisables = {
			disableMovement = true,
			disableCarMovement = false,
			disableMouse = false,
			disableCombat = true,
		},
		animation = {
			animDict = _animObj.animDict,
			anim = _animObj.anim,
			flags = _animObj.flag,
		},
	}, function(status)
		if not status then
			plsr.Callbacks:ServerCallback("Hospital:PrisonHospitalRevive", {}, function(s)
				if s then
					plsr.Escort:StopEscort()
				end
			end)
		end
	end)
end)
