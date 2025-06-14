local rewardRegistry = {}
local activeMission = {}

-- Volá se třeba při zahájení mise (z clientu)
RegisterNetEvent('sg_locator:setMission', function(state)
    local src = source
    activeMission[src] = state
end)

lib.callback.register('sg_locator:giveItem', function(source, item, count)
    local playerId = tostring(source)

    -- Zkontroluj, zda má hráč aktivní misi
    if not activeMission[source] then
        return false -- hráč nemá spuštěnou misi
    end

    local rewardId = ('%s_%s'):format(playerId, item)

    if rewardRegistry[rewardId] then
        return false -- hráč už reward dostal
    end

    rewardRegistry[rewardId] = true

    local success = exports.ox_inventory:AddItem(source, item, count)
    if not success then return false end

    -- Ukončení mise
    activeMission[source] = nil

    return rewardId
end)
