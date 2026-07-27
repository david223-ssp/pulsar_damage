local config = load(LoadResourceFile(GetCurrentResourceName(), "config/shared.lua"))()

function HospitalCallbacks()
	plsr.Chat:RegisterCommand(
		"icu",
		function(source, args, rawCommand)
			if tonumber(args[1]) then
				local char = plsr.Fetch:SID(tonumber(args[1]))
				if char ~= nil then
					plsr.Hospital.ICU:Send(char:GetData("Source"))
					plsr.Chat.Send.System:Single(source, string.format("%s Has Been Admitted To ICU", args[1]))
				else
					plsr.Chat.Send.System:Single(source, "State ID Not Logged In")
				end
			else
				plsr.Chat.Send.System:Single(source, "Invalid Arguments")
			end
		end,
		{
			help = "Sends Patient To ICU, Where They Will Remain Until Released By Medical Staff",
			params = {
				{
					name = "Target",
					help = "State ID of target",
				},
			},
		},
		1,
		{
			{
				Id = "ems",
			},
		}
	)
	plsr.Chat:RegisterCommand(
		"release",
		function(source, args, rawCommand)
			if tonumber(args[1]) then
				local char = plsr.Fetch:SID(tonumber(args[1]))
				if char ~= nil and char:GetData("ICU") ~= nil and not char:GetData("ICU").Released then
					plsr.Hospital.ICU:Release(char:GetData("Source"))
					plsr.Chat.Send.System:Single(source, string.format("%s Has Been Released From ICU", args[1]))
				else
					plsr.Chat.Send.System:Single(source, "State ID Not Logged In")
				end
			else
				plsr.Chat.Send.System:Single(source, "Invalid Arguments")
			end
		end,
		{
			help = "Releases a patient from ICU",
			params = {
				{
					name = "Target",
					help = "State ID of target",
				},
			},
		},
		1,
		{
			{
				Id = "ems",
			},
		}
	)

	plsr.Callbacks:RegisterServerCallback("Hospital:Treat", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		local bed = plsr.Hospital:RequestBed(source)

		local cost = config.Medical.checkInPrice
		-- if not GlobalState["Duty:ems"] or GlobalState["Duty:ems"] == 0 then
		-- 	cost = 150
		-- end

		plsr.Billing:Charge(source, cost, "Medical Services", "Use of facilities at St. Fiacre Medical Center")

		local f = plsr.Banking.Accounts:GetOrganization("ems")
		plsr.Banking.Balance:Deposit(f.Account, cost / 2, {
			type = "deposit",
			title = "Medical Treatment",
			description = string.format("Medical Bill For %s %s", char:GetData("First"), char:GetData("Last")),
			data = {},
		}, true)

		f = plsr.Banking.Accounts:GetOrganization("government")
		plsr.Banking.Balance:Deposit(f.Account, cost / 2, {
			type = "deposit",
			title = "Medical Treatment",
			description = string.format("Medical Bill For %s %s", char:GetData("First"), char:GetData("Last")),
			data = {},
		}, true)

		cb(bed)
	end)

	plsr.Callbacks:RegisterServerCallback("Hospital:Respawn", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		local deadEntry = char ~= nil and _deadCunts[char:GetData("SID")] or nil
		if deadEntry ~= nil and os.time() >= deadEntry.releaseTime then
			plsr.Pwnzor.Players:TempPosIgnore(source)
			local bed = plsr.Hospital:RequestBed(source)

			local cost = config.Medical.checkInPrice
			-- if not GlobalState["Duty:ems"] or GlobalState["Duty:ems"] == 0 then
			-- 	cost = 150
			-- end

			plsr.Billing:Charge(source, cost, "Medical Services", "Use of facilities at St. Fiacre Medical Center")
			plsr.Logger:Info(
				"Robbery",
				string.format(
					"%s %s (%s) Respawned Via Local EMS",
					char:GetData("First"),
					char:GetData("Last"),
					char:GetData("SID")
				),
				{
					console = true,
					file = true,
					database = true,
					discord = {
						embed = true,
						type = "info",
						webhook = GetConvar("discord_log_webhook", ""),
					},
				}
			)

			local f = plsr.Banking.Accounts:GetOrganization("ems")
			plsr.Banking.Balance:Deposit(f.Account, cost / 2, {
				type = "deposit",
				title = "Medical Treatment",
				description = string.format("Medical Bill For %s %s", char:GetData("First"), char:GetData("Last")),
				data = {},
			}, true)

			f = plsr.Banking.Accounts:GetOrganization("government")
			plsr.Banking.Balance:Deposit(f.Account, cost / 2, {
				type = "deposit",
				title = "Medical Treatment",
				description = string.format("Medical Bill For %s %s", char:GetData("First"), char:GetData("Last")),
				data = {},
			}, true)

			cb(bed)
		else
			cb(nil)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Hospital:FindBed", function(source, data, cb)
		cb(plsr.Hospital:FindBed(source, data))
	end)

	plsr.Callbacks:RegisterServerCallback("Hospital:OccupyBed", function(source, data, cb)
		cb(plsr.Hospital:OccupyBed(source, data))
	end)

	plsr.Callbacks:RegisterServerCallback("Hospital:LeaveBed", function(source, data, cb)
		cb(plsr.Hospital:LeaveBed(source))
	end)

	plsr.Callbacks:RegisterServerCallback("Hospital:RetreiveItems", function(source, data, cb)
		plsr.Hospital.ICU:GetItems(source)
	end)

	plsr.Callbacks:RegisterServerCallback("Hospital:HiddenRevive", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		local isEscorting = plsr.Escort:GetEscorting(source)
		if isEscorting ~= nil then
			if plsr.State:Player(isEscorting).isDead then
				if plsr.Crypto.Exchange:Remove("MALD", char:GetData("CryptoWallet"), config.Medical.reviveEscortPrice) then
					cb(true)
					local tChar = plsr.Fetch:CharacterSource(isEscorting)
					if tChar ~= nil then
						plsr.Callbacks:ClientCallback(tChar:GetData("Source"), "Damage:Heal", true)
					else
						plsr.Execute:Client(source, "Notification", "Error", "Invalid Target")
					end
				else
					cb(false)
					plsr.Execute:Client(source, "Notification", "Error", "Not Enough Crypto")
				end
			end
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Hospital:SpawnICU", function(source, data, cb)
		plsr.Routing:RoutePlayerToGlobalRoute(source)
		local char = plsr.Fetch:CharacterSource(source)
		TriggerClientEvent("Hospital:Client:ICU:Enter", source)
		cb(true)
	end)
end
