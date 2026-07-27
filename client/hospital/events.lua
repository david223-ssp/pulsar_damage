local config = load(LoadResourceFile(GetCurrentResourceName(), "config/shared.lua"))()

local hospitalCheckin = {
	{
		icon = "clipboard-list",
		text = "Go On Duty",
		event = "EMS:Client:OnDuty",
		jobPerms = {
			{
				job = "ems",
				reqOffDuty = true,
			},
		},
	},
	{
		icon = "clipboard-list",
		text = "Go Off Duty",
		event = "EMS:Client:OffDuty",
		jobPerms = {
			{
				job = "ems",
				reqDuty = true,
			},
		},
	},
	{
		icon = "clipboard-list",
		text = "Check ICU Patients",
		event = "EMS:Client:CheckICUPatients",
		jobPerms = {
			{
				job = "ems",
			},
		},
	},
	{
		icon = "clipboard-list",
		text = "Check In - $" .. config.Medical.checkInPrice,
		event = "Hospital:Client:CheckIn",
		isEnabled = function()
			if not GlobalState["Duty:ems"] or GlobalState["Duty:ems"] == 0 then
				return plsr.State.flags.myEscorter == nil
					and (GlobalState["ems:pmc:doctor"] == nil or GlobalState["ems:pmc:doctor"] == 0)
			end
			return false
		end,
	},
	{
		icon = "clipboard-list",
		text = "Check In - $" .. config.Medical.checkInPrice,
		event = "Hospital:Client:CheckIn",
		isEnabled = function()
			if GlobalState["Duty:ems"] and GlobalState["Duty:ems"] > 0 then
				return plsr.State.flags.myEscorter == nil
					and (GlobalState["ems:pmc:doctor"] == nil or GlobalState["ems:pmc:doctor"] == 0)
			end
			return false
		end,
	},
	{
		icon = "hands-holding",
		text = "Retrieve Items",
		event = "Hospital:Client:RetreiveItems",
		isEnabled = function()
			local icu = plsr.State.character.ICU
			return icu == nil or not icu.Items
		end,
	},
}

function Init()
	plsr.PedInteraction:Add(
		"hospital-check-in-1",
		`u_f_m_miranda_02`,
		vector3(1125.869, -1531.991, 34.033),
		344.011,
		25.0,
		hospitalCheckin,
		"notes-medical",
		"WORLD_HUMAN_CLIPBOARD"
	)
	plsr.PedInteraction:Add(
		"hospital-check-in-2",
		`s_f_y_scrubs_01`,
		vector3(1144.530, -1543.017, 34.033),
		274.930,
		25.0,
		hospitalCheckin,
		"notes-medical",
		"WORLD_HUMAN_CLIPBOARD"
	)
	plsr.PedInteraction:Add(
		"hospital-check-in-3",
		`s_f_y_scrubs_01`,
		vector3(1135.842, -1539.658, 38.504),
		2.759,
		25.0,
		hospitalCheckin,
		"notes-medical",
		"WORLD_HUMAN_CLIPBOARD"
	)

	for k, v in ipairs(config.Hospital.bedModels) do
		plsr.Targeting:AddObject(v, "bed-pulse", {
			{
				icon = "bed-pulse",
				text = "Lay in Bed",
				event = "Hospital:Client:FindBed",
				minDist = 1.5,
				isEnabled = function()
					return plsr.State.flags.isEscorting == nil
						and plsr.State.flags.myEscorter == nil
						and not plsr.State.flags.isHospitalized
				end,
			},
		}, 1.5)
	end

	for k, v in ipairs(config.Hospital.bedPolys) do
		plsr.Targeting.Zones:AddBox(
			string.format("hospitalbed-%s", k),
			"bed-pulse",
			v.center,
			v.length,
			v.width,
			v.options,
			{
				{
					icon = "bed-pulse",
					text = "Lay Down",
					event = "Hospital:Client:LaydownAnimation",
					data = v.laydown,
				},
			},
			1.5,
			true
		)
	end
end

AddEventHandler("Hospital:Client:LaydownAnimation", function(hitting, coords)
	SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
	SetEntityHeading(PlayerPedId(), coords.w)
	plsr.Animations.Emotes:Play("passout3", true)
	plsr.State:SetPublicClientFlag('isHospitalized', true)

	while plsr.Animations.Emotes:Get() == "passout3" do
		Wait(250)
	end

	-- print("Out of Bed")
	plsr.State:SetPublicClientFlag('isHospitalized', false)
end)

AddEventHandler("Hospital:Client:RetreiveItems", function()
	plsr.Callbacks:ServerCallback("Hospital:RetreiveItems")
end)

AddEventHandler("Hospital:Client:HiddenRevive", function(entity, data)
	plsr.Progress:Progress({
		name = "ammo_action",
		duration = (math.random(config.Medical.reviveEscortDuration.variance) + config.Medical.reviveEscortDuration.base) * 1000,
		label = "Reviving",
		useWhileDead = false,
		canCancel = true,
		ignoreModifier = true,
		controlDisables = {
			disableMovement = false,
			disableCarMovement = false,
			disableMouse = false,
			disableCombat = true,
		},
		animation = {
			task = "CODE_HUMAN_MEDIC_KNEEL",
		},
	}, function(status)
		if not status then
			plsr.Callbacks:ServerCallback("Hospital:HiddenRevive", {}, function(s)
				if s then
					plsr.Escort:StopEscort()
				end
			end)
		end
	end)
end)

RegisterNetEvent("Characters:Client:Logout", function()
	if plsr.State.flags.isHospitalized then
		plsr.State:SetPublicClientFlag('isHospitalized', false)
	end
end)

AddEventHandler("Hospital:Client:CheckIn", function()
	plsr.Progress:ProgressWithStartEvent({
		name = "hospital_action",
		duration = config.Medical.checkInDuration,
		label = "Checking In",
		useWhileDead = true,
		canCancel = true,
		ignoreModifier = true,
		controlDisables = {
			disableMovement = true,
			disableCarMovement = true,
			disableMouse = false,
			disableCombat = true,
		},
		animation = {
			anim = "clipboard_still",
		},
		disarm = true,
	}, function()
		plsr.State:SetPublicClientFlag('isHospitalized', true)
	end, function(status)
		if not status then
			plsr.Hospital:CheckIn()
		else
			plsr.State:SetPublicClientFlag('isHospitalized', false)
		end
	end)
end)

RegisterNetEvent("Hospital:Client:GetOut", function()
	plsr.Callbacks:ServerCallback("Hospital:LeaveBed", {}, function()
		_doing = false
		LeaveBed()
	end)
end)

AddEventHandler("Hospital:Client:FindBed", function(event, data)
	if not event then
		return
	end
	plsr.Hospital:FindBed(event.entity)
end)

RegisterNetEvent("Hospital:Client:ICU:Enter", function()
	if not IsScreenFadedOut() then
		DoScreenFadeOut(1000)
		while not IsScreenFadedOut() do
			Wait(10)
		end
	end

	local room = config.Hospital.icuBeds[math.random(#config.Hospital.icuBeds)]

	SetEntityCoords(PlayerPedId(), room[1], room[2], room[3], 0, 0, 0, false)
	Wait(100)
	SetEntityHeading(PlayerPedId(), room[4])
	_disabled = false

	Wait(1000)

	DoScreenFadeIn(1000)
	while not IsScreenFadedIn() do
		Wait(10)
	end
end)
