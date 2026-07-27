local config = load(LoadResourceFile(GetCurrentResourceName(), "config/shared.lua"))()

_curBed = nil
_done = false

_healEnd = nil
_leavingBed = false

CreateThread(function()
	Init()

	while GlobalState["HiddenHospital"] == nil do
		Wait(5)
	end

	plsr.PedInteraction:Add("HiddenHospital", `s_m_m_doctor_01`, GlobalState["HiddenHospital"].coords, GlobalState["HiddenHospital"].heading, 25.0, {
		{
			icon = "heart-pulse",
			text = "Revive Escort (" .. config.Medical.reviveEscortPrice .. " $MALD)",
			event = "Hospital:Client:HiddenRevive",
			data = plsr.State.flags.isEscorting or {},
			isEnabled = function()
				if plsr.State.flags.isEscorting ~= nil and not _dmg.isDead then
					local otherDead = plsr.State:GetPublicFlag(plsr.State.flags.isEscorting, 'isDead')
					local otherDeadData = plsr.State:GetPublicFlag(plsr.State.flags.isEscorting, 'deadData')
					return otherDead and not (otherDeadData and otherDeadData.isMinor)
				else
					return false
				end
			end,
		},
	}, 'suitcase-medical', false, true, {
		animDict = "mp_prison_break",
		anim = "hack_loop",
	})

	plsr.Polyzone.Create:Box('hospital-check-in-zone-1', vector3(1146.37, -1538.66, 35.03), 2.8, 1.2, {
		heading = 0,
		--debugPoly=true,
		minZ = 32.63,
			maxZ = 36.63
	}, {})

	plsr.Polyzone.Create:Box('hospital-check-in-zone-2', vector3(1129.59, -1534.96, 35.03), 2.8, 1.2, {
		heading = 3,
		--debugPoly=true,
		minZ = 32.63,
		maxZ = 36.63
	}, {})

	plsr.Polyzone.Create:Box('hospital-check-in-zone-3', vector3(1142.82, -1537.74, 39.5), 2.8, 1.2, {
		heading = 88,
		--debugPoly=true,
		minZ = 37.1,
		maxZ = 41.1
	}, {})

	plsr.Targeting.Zones:AddBox("icu-checkout", "bell-concierge", vector3(1147.83, -1542.54, 39.5), 2.8, 0.8, {
		name = "hospital",
		heading = 0,
		--debugPoly=true,
		minZ = 38.5,
		maxZ = 41.1
	}, {
		{
			icon = "bell-concierge",
			text = "Request Personnel",
			event = "Hospital:Client:RequestEMS",
			isEnabled = function()
				local icu = plsr.State.character.ICU
				return (icu ~= nil and not icu.Released) and (not _done or _done < GetCloudTimeAsInt())
			end,
		}
	})

	plsr.Polyzone.Create:Poly("hospital-icu-area", {
		vector2(1144.3436279297, -1541.1220703125),
		vector2(1144.3024902344, -1560.3250732422),
		vector2(1148.193359375, -1560.3918457031),
		vector2(1154.2583007812, -1560.4184570312),
		vector2(1154.3413085938, -1555.5563964844),
		vector2(1154.4481201172, -1548.7468261719),
		vector2(1154.1629638672, -1540.7801513672)
	}, {
		--debugPoly=true,
		minZ = 38.50,
		maxZ = 40.53
	})
end)

AddEventHandler("Hospital:Client:RequestEMS", function()
	if not _done or _done < GetCloudTimeAsInt() then
		TriggerServerEvent("EmergencyAlerts:Server:DoPredefined", "icurequest")
		_done = GetCloudTimeAsInt() + config.Medical.icuAlertCooldown
	end
end)

AddEventHandler('Proxy:Shared:RegisterReady', function()
    exports['pulsar_core']:RegisterComponent('Hospital', HOSPITAL)
end)

local _bedId = nil
HOSPITAL = {
	CheckIn = function(self)
		plsr.Callbacks:ServerCallback('Hospital:Treat', {}, function(bed)
			if bed ~= nil then
				plsr.State:SetPublicClientFlag('isHospitalized', true)
				plsr.Hospital:SendToBed(config.Hospital.beds[bed], false, bed)
			else
				plsr.Notification:Error('No Beds Available')
			end
		end)
	end,
	SendToBed = function(self, bed, isRp, bedId)
		local fuck = false

		if bedId then
			local p = promise.new()
			plsr.Callbacks:ServerCallback('Hospital:OccupyBed', bedId, function(s)
				p:resolve(s)
			end)

			fuck = Citizen.Await(p)
		else
			fuck = true
		end

		_bedId = bedId

		if bed ~= nil and fuck then
			SetBedCam(bed)
			if isRp then
				_healEnd = GetCloudTimeAsInt()
				plsr.Hud.DeathTexts:Show("hospital_rp", GetCloudTimeAsInt(), _healEnd, "primary_action")
			else
				_healEnd = GetCloudTimeAsInt() + config.Medical.bedRecoveryTime
				plsr.Hud.DeathTexts:Show("hospital", GetCloudTimeAsInt(), _healEnd, "primary_action")
				Citizen.SetTimeout(((_healEnd - GetCloudTimeAsInt()) - 10) * 1000, function()
					if _dmg.loggedIn and plsr.State.flags.isHospitalized then
						plsr.State.flags.deadData = {}
						plsr.Damage.Reductions:Reset()
						plsr.Damage:Revive()
					end
				end)
			end
		else
			plsr.Notification:Error('Invalid Bed or Bed Occupied')
		end
	end,
	FindBed = function(self, object)
		local coords = GetEntityCoords(object)
		plsr.Callbacks:ServerCallback('Hospital:FindBed', coords, function(bed)
			if bed ~= nil then
				plsr.Hospital:SendToBed(config.Hospital.beds[bed], true, bed)
			else
				plsr.Hospital:SendToBed({
					x = coords.x,
					y = coords.y,
					z = coords.z,
					h = GetEntityHeading(object),
					freeBed = true,
				}, true)
			end
		end)
	end,
	LeaveBed = function(self)
		plsr.Callbacks:ServerCallback('Hospital:LeaveBed', _bedId, function()
			_bedId = nil
		end)
	end,
}

local _inCheckInZone = false

AddEventHandler('Polyzone:Enter', function(id, point, insideZone, data)
    if id == 'hospital-check-in-zone-1' or id == 'hospital-check-in-zone-2' or id == 'hospital-check-in-zone-3' then
        _inCheckInZone = true

		if plsr.State.flags.myEscorter == nil and (GlobalState["ems:pmc:doctor"] == nil or GlobalState["ems:pmc:doctor"] == 0) then
			if not GlobalState["Duty:ems"] or GlobalState["Duty:ems"] == 0 then
				plsr.Action:Show("medical", '{keybind}primary_action{/keybind} Check In {key}$' .. config.Medical.checkInPrice .. '{/key}')
			else
				plsr.Action:Show("medical", '{keybind}primary_action{/keybind} Check In {key}$' .. config.Medical.checkInPrice .. '{/key}')
			end
		end
    end
end)

AddEventHandler('Polyzone:Exit', function(id, point, insideZone, data)
    if id == 'hospital-check-in-zone-1' or id == 'hospital-check-in-zone-2' or id == 'hospital-check-in-zone-3' then
        _inCheckInZone = false
		plsr.Action:Hide("medical")
	elseif id == "hospital-icu-area" and _dmg.loggedIn then
		local icu = plsr.State.character.ICU
		if icu and not icu.Released then
			TriggerEvent("Hospital:Client:ICU:Enter")
		end
    end
end)

AddEventHandler('Keybinds:Client:KeyUp:primary_action', function()
    if _inCheckInZone then
		if not plsr.State.flags.doingAction and plsr.State.flags.myEscorter == nil and (GlobalState["ems:pmc:doctor"] == nil or GlobalState["ems:pmc:doctor"] == 0) then
			TriggerEvent('Hospital:Client:CheckIn')
		end
	else
		if _curBed ~= nil and plsr.State.flags.isHospitalized and GetCloudTimeAsInt() > _healEnd and not _leavingBed then
			_leavingBed = true
			plsr.Hud.DeathTexts:Release()
			LeaveBed()
		end
	end
end)