function RegisterChatCommands()
	plsr.Chat:RegisterStaffCommand("heal", function(source, args, rawCommand)
        if args[1] ~= nil then
            local admin = plsr.Fetch:Source(source)
            local char = plsr.Fetch:SID(tonumber(args[1]))
            if char ~= nil and ((char:GetData("Source") ~= admin:GetData("Source")) or admin.Permissions:IsAdmin()) then
                plsr.Callbacks:ClientCallback(char:GetData("Source"), "Damage:Heal", true)
                plsr.Status:Set(source, "PLAYER_STRESS", 0)
            else
                plsr.Chat.Send.System:Single(source, "Invalid State ID")
            end
        else
            local char = plsr.Fetch:CharacterSource(source)
            if char ~= nil then
                plsr.Callbacks:ClientCallback(source, "Damage:Heal", true)
                plsr.Status:Set(source, "PLAYER_STRESS", 0)
            end
        end
	end, {
		help = "Heals Player",
		params = {
			{
				name = "Target (Optional)",
				help = "State ID of Who You Want To Heal",
			},
		},
	}, -1)

	plsr.Chat:RegisterStaffCommand("healrange", function(source, args, rawCommand)
        local radius = args[1] and tonumber(args[1]) or 25.0

        local myPed = GetPlayerPed(source)
        for k, v in pairs(plsr.Fetch:AllCharacters()) do
            if v ~= nil then
                local src = v:GetData("Source")
                if plsr.State:Player(src).isDead then
                    local ped = GetPlayerPed(src)
                    if #(GetEntityCoords(ped) - GetEntityCoords(myPed)) <= radius then
                        plsr.Callbacks:ClientCallback(src, "Damage:Heal", true)
                    end
                end
            end
        end

        plsr.Callbacks:ClientCallback(source, "Damage:Heal", true)
        plsr.Status:Set(source, "PLAYER_STRESS", 0)
	end, {
		help = "Heals Player",
		params = {
			{
				name = "Radius (Optional)",
				help = "Radius To Heal Players (If Empty, Default Is 25 Meters)",
			},
		},
	}, -1)

	plsr.Chat:RegisterAdminCommand("god", function(source, args, rawCommand)
        if plsr.State:Player(source).isGodmode then
            SetPlayerInvincible(source, false)
            plsr.State:Player(source).isGodmode = false
            plsr.Execute:Client(source, "Notification", "Info", "God Mode Disabled")
            plsr.Callbacks:ClientCallback(source, "Damage:Admin:Godmode", false)
        else
            SetPlayerInvincible(source, true)
            plsr.State:Player(source).isGodmode = true
            plsr.Execute:Client(source, "Notification", "Info", "God Mode Enabled")
            plsr.Callbacks:ClientCallback(source, "Damage:Admin:Godmode", true)
        end
	end, {
		help = "Toggle God Mode",
	}, -1)

	plsr.Chat:RegisterAdminCommand("die", function(source, args, rawCommand)
        if not plsr.State:Player(source).isDead then
            plsr.Callbacks:ClientCallback(source, "Damage:Kill")
        end
	end, {
		help = "Kill Yourself",
	})
end