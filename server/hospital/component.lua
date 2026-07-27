local config = load(LoadResourceFile(GetCurrentResourceName(), "config/shared.lua"))()

BED_LIMIT = #config.Hospital.beds
_inBed = {}
_inBedChar = {}

local _medsForSale = {
	{ item = "firstaid", coin = "MALD", price = config.Medical.blackmarketMeds.firstaid, qty = -1, vpn = false, requireCurrency = false },
	{ item = "ifak", coin = "MALD", price = config.Medical.blackmarketMeds.ifak, qty = -1, vpn = false, requireCurrency = true },
}


CreateThread(function()
	HospitalCallbacks()
	HospitalMiddleware()

	GlobalState["HiddenHospital"] = {
		coords = vector3(2810.023, 5977.588, 349.919),
		heading = 146.641,
	}

	plsr.Vendor:Create("BlackmarketMeds", "ped", "Medical Supplies", `S_M_M_Paramedic_01`, {
		coords = vector3(2815.044, 5980.179, 349.928),
		heading = 277.889,
		scenario = "WORLD_HUMAN_CLIPBOARD",
	}, _medsForSale, "pump-medical", "View Supplies", false, false, true)

	plsr.Chat:RegisterAdminCommand("clearbeds", function(source, args, rawCommand)
		_inBed = {}
	end, {
		help = "Force Clear All Hospital Beds",
		params = {},
	}, -1)
end)

HOSPITAL = {
	RequestBed = function(self, source)
		--return math.random(#config.Hospital.beds)
		for k, v in ipairs(config.Hospital.beds) do
			if _inBed[k] == nil then
				return k
			end
		end
		return nil
	end,
	FindBed = function(self, source, location)
		for k, v in ipairs(config.Hospital.beds) do
			if (#(vector3(v.x, v.y, v.z) - vector3(location.x, location.y, location.z)) <= 2.0) and not _inBed[k] then
				return k
			end
		end
		return nil
	end,
	OccupyBed = function(self, source, bedId)
		local char = plsr.Fetch:CharacterSource(source)
		if char and config.Hospital.beds[bedId] ~= nil then
			if _inBed[bedId] == nil then
				_inBedChar[char:GetData("ID")] = bedId
				_inBed[bedId] = char:GetData("ID")
				return true
			else
				return false
			end
		else
			return false
		end
	end,
	LeaveBed = function(self, source)
		local char = plsr.Fetch:CharacterSource(source)
		if char ~= nil then
			local inBedId = _inBedChar[char:GetData("ID")]
			if inBedId ~= nil then
				_inBed[inBedId] = nil
				_inBedChar[char:GetData("ID")] = nil
				return true
			end
		end
		return false
	end,
	ICU = {
		Send = function(self, target)
			local char = plsr.Fetch:CharacterSource(target)
			if char ~= nil then
				if char:GetData("ICU") ~= nil and not char:GetData("ICU").Released then
					return false
				end

				plsr.Labor.Jail:Sentenced(target)

				char:SetData("ICU", {
					Released = false,
				})

				CreateThread(function()
					plsr.Jobs.Duty:Off(target, plsr.State:Player(target).onDuty)
					plsr.Handcuffs:UncuffTarget(-1, target)
					plsr.Ped.Mask:UnequipNoItem(target)
					plsr.Inventory.Holding:Put(target)
				end)

				plsr.Pwnzor.Players:TempPosIgnore(target)
				TriggerClientEvent("Hospital:Client:ICU:Sent", target)
				TriggerClientEvent("Hospital:Client:ICU:Enter", target)
				plsr.Execute:Client(target, "Notification", "Info", "You Were Admitted To ICU")
			else
				return false
			end
		end,
		Release = function(self, target)
			local char = plsr.Fetch:CharacterSource(target)
			if char ~= nil then
				char:SetData("ICU", {
					Released = true,
					Items = false,
				})
				plsr.Execute:Client(target, "Notification", "Info", "You Were Released From ICU")
			else
				return false
			end
		end,
		GetItems = function(self, target)
			local char = plsr.Fetch:CharacterSource(target)
			if char ~= nil then
				char:SetData("ICU", {
					Released = true,
					Items = true,
				})
				plsr.Inventory.Holding:Take(target)
			else
				return false
			end
		end,
	},
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Hospital", HOSPITAL)
end)
