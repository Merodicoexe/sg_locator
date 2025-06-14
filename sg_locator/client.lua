local hasMission = false
local hasKey = false
local spawnedVehicle = nil

CreateThread(function()
    exports.ox_target:addSphereZone({
        coords = Config.StartCoords,
        radius = 1.5,
        options = {
            {
                name = 'sg_locator_start',
                icon = 'fa-solid fa-map-pin',
                label = 'Začít sledování',
                onSelect = function()
                    if hasMission then return end
                    hasMission = true
                    SetNewWaypoint(Config.GarageList.x, Config.GarageList.y)
                    lib.notify({ title = 'Lokátor', description = 'Cíl označen na mapě.', type = 'inform' })
                    TriggerServerEvent('sg_locator:setMission', true)
                end
            }
        }
    })
end)

CreateThread(function()
    exports.ox_target:addBoxZone({
        coords = Config.Interior.enter,
        size = vec3(1.5, 1.5, 2.0),
        rotation = 0,
        options = {
            {
                name = 'sg_locator_enter',
                icon = 'fa-solid fa-door-open',
                label = 'Vstoupit dovnitř',
                onSelect = function()
                    if not hasMission then return end
                    DoScreenFadeOut(500)
                    Wait(500)
                    SetEntityCoords(cache.ped, Config.Interior.inside.x, Config.Interior.inside.y, Config.Interior.inside.z)
                    Wait(500)
                    DoScreenFadeIn(500)

                    -- Spawn vehicle
                    local model = joaat(Config.VehicleSpawn.model)
                    RequestModel(model)
                    while not HasModelLoaded(model) do Wait(0) end
                    spawnedVehicle = CreateVehicle(model, Config.VehicleSpawn.coords.xyz, Config.VehicleSpawn.coords.w, false, false)
                    SetEntityAsMissionEntity(spawnedVehicle, true, true)
                    FreezeEntityPosition(spawnedVehicle, true)

                            --Dispatch
                            local data = {
                                displayCode = '10-68',
                                description = 'Vykradaní Garaže',
                                isImportant = 0,
                                recipientList = {'police', 'sheriff'},
                                length = '10000',
                                infoM = 'fa-info-circle',
                                info = 'Vykradaní Garaže'
                            }

                            local playerPed = GetPlayerPed(source)
                            local coords = GetEntityCoords(playerPed)
    
                            local dispatchData = {
                                dispatchData = data,
                                caller = 'Alarm',
                                coords = coords
                            }
                            TriggerEvent('wf-alerts:svNotify', dispatchData)
                end
            }
        }
    })
end)

CreateThread(function()
    for i, coords in ipairs(Config.KeySearchPoints) do
        exports.ox_target:addBoxZone({
            coords = coords,
            size = vec3(1.0, 1.0, 1.0),
            rotation = 0,
            options = {
                {
                    name = 'sg_locator_search_' .. i,
                    icon = 'fa-solid fa-key',
                    label = 'Prohledat místo',
                    onSelect = function()
                        if hasKey then
                            lib.notify({ title = 'Lokátor', description = 'Už máš klíče.', type = 'error' })
                            return
                        end

                        lib.progressBar({
                            duration = 3000,
                            label = 'Hledání klíče...',
                            useWhileDead = false,
                            canCancel = false,
                            disable = { move = true, car = true },
                        })

                        if math.random(1, 4) == i then
                            hasKey = true
                            lib.notify({ title = 'Lokátor', description = 'Našel jsi klíče!', type = 'success' })
                        else
                            lib.notify({ title = 'Lokátor', description = 'Nic tady není.', type = 'error' })
                        end
                    end
                }
            }
        })
    end
end)

CreateThread(function()
    while true do
        Wait(0)

        if hasKey and spawnedVehicle and DoesEntityExist(spawnedVehicle) then
            local ped = cache.ped
            local veh = GetVehiclePedIsIn(ped, false)

            -- Hráč je ve správném vozidle a je řidičem
            if veh == spawnedVehicle and GetPedInVehicleSeat(veh, -1) == ped then
                local coords = GetEntityCoords(veh)
                local distance = #(coords - Config.VehicleSpawn.coords.xyz)

                -- Jsme v radiusu výjezdu a stiskne W
                if distance <= 10.0 and IsControlJustPressed(0, 71) then -- 71 = W
                    DoScreenFadeOut(500)
                    Wait(500)
                
                    SetEntityCoords(spawnedVehicle, Config.ExitVehicle.xyz)
                    SetEntityHeading(spawnedVehicle, Config.ExitVehicle.w)
                    FreezeEntityPosition(spawnedVehicle, false)
                    Wait(250)
                    SetPedIntoVehicle(ped, spawnedVehicle, -1)
                    DoScreenFadeIn(500)
                
                    lib.notify({ title = 'Lokátor', description = 'Opustil jsi lokaci.', type = 'success' })
                    StartEscapeTimer()
                    -- Reset
                    hasKey = false
                    hasMission = false
                    spawnedVehicle = nil
                end                
            end
        end
    end
end)

function StartEscapeTimer()
    local timeLeft = Config.Timer * 60 -- v sekundách
    local showTimer = true

    -- Zapne vykreslení timeru
    CreateThread(function()
        while showTimer and timeLeft > 0 do
            Wait(1000)
            timeLeft -= 1
        end

        if timeLeft <= 0 then
            showTimer = false
            local pos = Config.DorucitVozidlo[math.random(1, #Config.DorucitVozidlo)]
            SetNewWaypoint(pos.x, pos.y)
            lib.notify({ title = 'Lokátor', description = 'Cíl označen na mapě!', type = 'info' })
        
            SpawnDeliveryNPC()
        end        
    end)

    -- Vykreslování na obrazovku
    CreateThread(function()
        while showTimer do
            Wait(0)
            local minutes = math.floor(timeLeft / 60)
            local seconds = timeLeft % 60
            local text = string.format("📦 Lokátor: %02d:%02d", minutes, seconds)

            SetTextFont(0)
            SetTextScale(0.5, 0.5)
            SetTextColour(255, 255, 255, 255)
            SetTextOutline()
            SetTextCentre(true)
            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName(text)
            EndTextCommandDisplayText(0.5, 0.95)
        end
    end)

    -- Viditelnost pro policii
    CreateThread(function()
        local blip = AddBlipForEntity(spawnedVehicle)
        SetBlipSprite(blip, 161)
        SetBlipScale(blip, 1.2)
        SetBlipColour(blip, 1)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Hledané vozidlo")
        EndTextCommandSetBlipName(blip)

        while showTimer do
            Wait(5000)
            -- Udržuj blip aktivní jen pro police joby
            local playerJob = exports['es_extended']:getSharedObject().PlayerData.job.name
            if not IsJobAllowed(playerJob) then
                RemoveBlip(blip)
            end
        end

        RemoveBlip(blip)
    end)
end

function IsJobAllowed(job)
    for _, allowedJob in pairs(Config.Jobs) do
        if job == allowedJob then return true end
    end
    return false
end

function SpawnDeliveryNPC()
    for i, loc in pairs(Config.DorucitVozidlo) do
        local model = Config.NPCModel
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(0) end

        local ped = CreatePed(0, model, loc.x, loc.y, loc.z - 1.0, 0.0, false, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        exports.ox_target:addBoxZone({
            coords = loc,
            size = vec3(2, 2, 2),
            rotation = 0,
            debug = false,
            options = {
                {
                    name = 'odezdatvozidlo_' .. i,
                    icon = 'fa-solid fa-car',
                    label = 'Odevzdat vozidlo',
                    distance = 2.5,
                    onSelect = function()
                        TriggerEvent('sg_locator:odevzdejVozidlo')
                    end
                }
            }
        })        
    end
end

RegisterNetEvent('sg_locator:odevzdejVozidlo', function()
    local ped = cache.ped
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 then
        local model = GetEntityModel(veh)
        local targetModel = joaat(Config.VehicleSpawn.model)

        if model == targetModel then
            local vehCoords = GetEntityCoords(veh)
            local inRange = false

            for _, loc in pairs(Config.DorucitVozidlo) do
                if #(vehCoords - loc) <= 10.0 then
                    inRange = true
                    break
                end
            end

            if inRange then
                DeleteEntity(veh)

                local rewardItem = 'money' -- nastav si podle potřeby
                local rewardCount = math.random(1, 2)
                local rewardId = ('%s_%s_%d'):format(cache.serverId, rewardItem, math.random(1000, 9999))

                lib.callback('sg_locator:giveItem', false, function(rewardId)
                    if rewardId then
                        lib.notify({
                            title = 'Lokátor',
                            description = ('Dokončil si Praci tu maš penize.'),
                            type = 'success'
                        })
                    else
                        lib.notify({
                            title = 'Lokátor',
                            description = 'Nastala chyba nebyl startej missions.',
                            type = 'error'
                        })
                    end
                end, rewardItem, rewardCount)
                TriggerServerEvent('sg_locator:setMission', false)   
            else
                lib.notify({ title = 'Lokátor', description = 'Jsi příliš daleko od cílové lokace.', type = 'error' })
            end
        else
            lib.notify({ title = 'Lokátor', description = 'To není správné vozidlo!', type = 'error' })
        end
    else
        lib.notify({ title = 'Lokátor', description = 'Musíš být ve vozidle!', type = 'error' })
    end
end)



RegisterCommand("testgive", function()
    SpawnDeliveryNPC()
end, false)
