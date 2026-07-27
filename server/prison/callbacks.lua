local config = load(LoadResourceFile(GetCurrentResourceName(), "config/shared.lua"))()

function PrisonHospitalCallbacks()
	plsr.Callbacks:RegisterServerCallback("Hospital:PrisonHospitalRevive", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		local cost = config.Prison.checkInPrice

		plsr.Billing:Charge(source, cost, "Medical Services", "Use of facilities at Bolingbroke Infirmary")

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

		local tChar = plsr.Fetch:CharacterSource(source)
		if tChar ~= nil then
			plsr.Callbacks:ClientCallback(tChar:GetData("Source"), "Damage:Heal", true)
		else
			plsr.Execute:Client(source, "Notification", "Error", "An error has occured. Please report this.")
		end

		cb(true)
	end)
end
