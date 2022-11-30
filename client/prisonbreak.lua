local currentGate = 0
local securityLockdown = false

-- Functions

--- This will be triggered once a hack is done on a gate
--- @param success boolean
--- @return nil
local function OnHackDone(success)
    Config.OnHackDone(success, currentGate, Config.Gates[currentGate])
end

RegisterNetEvent('electronickit:UseElectronickit', function()
    if currentGate ~= 0 and not securityLockdown and not Config.Gates[currentGate].hit then
        local hasItem = QBCore.Functions.HasItem("gatecrack")

        if hasItem then
            QBCore.Functions.Progressbar("hack_gate", Lang:t("info.connecting_device"), math.random(5000, 10000), false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true
            }, {
                animDict = "anim@gangops@facility@servers@",
                anim = "hotwire",
                flags = 16
            }, {}, {}, function() -- Done
                StopAnimTask(cache.ped, "anim@gangops@facility@servers@", "hotwire", 1.0)

                TriggerEvent("mhacking:show")
                TriggerEvent("mhacking:start", math.random(5, 9), math.random(10, 18), OnHackDone)
            end, function() -- Cancel
                StopAnimTask(cache.ped, "anim@gangops@facility@servers@", "hotwire", 1.0)

                lib.notify({
                    description = Lang:t("error.cancelled"),
                    type = 'error'
                })
            end)
        else
            lib.notify({
                description = Lang:t("error.item_missing"),
                type = 'error'
            })
        end
    end
end)

RegisterNetEvent('prison:client:SetLockDown', function(isLockdown)
    securityLockdown = isLockdown

    if not securityLockdown or not inJail then
        return
    end

    lib.notify({
        title = "HOSTAGE",
        description = Lang:t("error.security_activated"),
        type = 'error'
    })
end)

RegisterNetEvent('prison:client:PrisonBreakAlert', function()
    local coords = vec3(Config.Locations["middle"].coords.x, Config.Locations["middle"].coords.y, Config.Locations["middle"].coords.z)
    local alertData = {
        title = Lang:t("info.police_alert_title"),
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z
        },
        description = Lang:t("info.police_alert_description")
    }

    TriggerEvent("qb-phone:client:addPoliceAlert", alertData)
    TriggerEvent('police:client:policeAlert', coords, Lang:t("info.police_alert_description"))

    local BreakBlip = AddBlipForCoord(coords.x, coords.y, coords.z)

    TriggerServerEvent('prison:server:JailAlarm')

    SetBlipSprite(BreakBlip , 161)
    SetBlipScale(BreakBlip , 3.0)
    SetBlipColour(BreakBlip, 3)
    PulseBlip(BreakBlip)
    PlaySound(-1, "Lose_1st", "GTAO_FM_Events_Soundset", 0, 0, 1)

    Wait(100)

    PlaySoundFrontend( -1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)

    Wait(100)

    PlaySound(-1, "Lose_1st", "GTAO_FM_Events_Soundset", 0, 0, 1)

    Wait(100)

    PlaySoundFrontend( -1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)

    Wait((1000 * 60 * 5))

    RemoveBlip(BreakBlip)
end)

RegisterNetEvent('prison:client:SetGateHit', function(key, isHit)
    Config.Gates[key].hit = isHit
end)

RegisterNetEvent('prison:client:JailAlarm', function(toggle)
    if toggle then
        local alarmIpl = GetInteriorAtCoordsWithType(1787.004,2593.1984,45.7978, "int_prison_main")

        RefreshInterior(alarmIpl)
        EnableInteriorProp(alarmIpl, "prison_alarm")

        CreateThread(function()
            while not PrepareAlarm("PRISON_ALARMS") do
                Wait(100)
            end

            StartAlarm("PRISON_ALARMS", true)
        end)
    else
        local alarmIpl = GetInteriorAtCoordsWithType(1787.004,2593.1984,45.7978, "int_prison_main")

        RefreshInterior(alarmIpl)
        DisableInteriorProp(alarmIpl, "prison_alarm")

        CreateThread(function()
            while not PrepareAlarm("PRISON_ALARMS") do
                Wait(100)
            end

            StopAllAlarms(true)
        end)
    end
end)

-- Threads
CreateThread(function()
    while true do
        inRange = false
        currentGate = 0

        local sleep = 1000

        if LocalPlayer.state.isLoggedIn then
            if PlayerData.job.name ~= "police" then
                local pos = GetEntityCoords(cache.ped)

                for k, v in pairs(Config.Gates) do
                    local dist =  #(pos - v.coords)

                    if dist < 1.5 then
                        currentGate = k
                        inRange = true

                        if securityLockdown then
                            sleep = 0

                            DrawText3D(v.coords.x, v.coords.y, v.coords.z, "~r~SYSTEM LOCKDOWN")
                        elseif v.hit then
                            sleep = 0

                            DrawText3D(v.coords.x, v.coords.y, v.coords.z, "SYSTEM BREACH")
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local pos = GetEntityCoords(cache.ped, true)

        if #(pos.xy - vec2(Config.Locations["middle"].coords.x, Config.Locations["middle"].coords.y)) > 200 and inJail then
            inJail = false
            jailTime = 0

            RemoveBlip(currentBlip)
            RemoveBlip(CellsBlip)

            CellsBlip = nil

            RemoveBlip(TimeBlip)

            TimeBlip = nil

            RemoveBlip(ShopBlip)

            ShopBlip = nil

            TriggerServerEvent("prison:server:SecurityLockdown")
            TriggerEvent("prison:client:PrisonBreakAlert")
            TriggerServerEvent("prison:server:SetJailStatus", 0)
            TriggerServerEvent("prison:server:GiveJailItems", true)

            lib.notify({
                description = Lang:t("error.escaped"),
                type = 'error'
            })
        end

        Wait(1000)
    end
end)