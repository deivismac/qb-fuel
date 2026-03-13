-- ====================|| VARIABLES || ==================== --

QBCore = exports["qb-core"]:GetCoreObject()

-- ====================|| CORE BUSINESS HELPERS || ==================== --

local function getPlayerCoords(source)
    local ped = GetPlayerPed(source)
    return ped and GetEntityCoords(ped)
end

local function coreBusinessRemoveFuel(source, litres)
    if not Config.CoreBusiness or not Config.CoreBusiness.enabled then return true end

    local coords = getPlayerCoords(source)
    if not coords then return true end

    local fuelItem = Config.CoreBusiness.fuelItem
    local fuelPerLiter = Config.CoreBusiness.fuelPerLiter or 1
    local itemsNeeded = math.max(1, math.ceil(litres * fuelPerLiter))

    local itemCount = exports['core_business']:closestPropertyItemCount(coords, fuelItem)
    if itemCount == 1000.0 then return true end

    local removed = exports['core_business']:closestPropertyRemoveItem(coords, fuelItem, itemsNeeded)
    return removed
end

local function coreBusinessRegisterSale(source, price, logMsg)
    if not Config.CoreBusiness or not Config.CoreBusiness.enabled or not Config.CoreBusiness.registerSales then return end

    local coords = getPlayerCoords(source)
    if not coords then return end

    exports['core_business']:closestPropertyRegisterSale(coords, math.floor(price), logMsg or "Fuel sale")
end

-- ====================|| EVENTS || ==================== --

QBCore.Functions.CreateCallback('qb-fuel:server:refillVehicle', function (src, cb, litres)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not litres then return end

    local finalPrice = litres * Config.FuelPrice

    if not coreBusinessRemoveFuel(src, litres) then
        Player.Functions.Notify('Not enough fuel in stock', 'error')
        cb(false)
        return
    end

    local useCorePay = Config.CoreBusiness and Config.CoreBusiness.enabled and Config.CoreBusiness.useCorePay
    local coords = useCorePay and getPlayerCoords(src)
    local businessId = coords and exports['core_business']:closestPropertyGetBusinessId(coords)

    if useCorePay and businessId then
        exports['core_business']:requestCorePay(src, businessId, finalPrice, string.format("Fuel: %d litres", litres), function(success)
            if success then
                cb(true)
            else
                cb(false)
            end
        end)
    else
        if Player.PlayerData.money[Config.MoneyType] >= finalPrice then
            local success = Player.Functions.RemoveMoney(Config.MoneyType, finalPrice, 'refuel-vehicle')
            if success then
                coreBusinessRegisterSale(src, finalPrice, string.format("Fuel sale: $%d (%d litres)", finalPrice, litres))
            end
            cb(success)
        else
            cb(false)
        end
    end
end)

RegisterServerEvent('qb-fuel:server:buyJerryCan', function ()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not coreBusinessRemoveFuel(src, Config.JerryCanLitre) then
        Player.Functions.Notify('Not enough fuel in stock', 'error')
        return
    end

    if Player.Functions.RemoveMoney(Config.MoneyType, Config.JerryCanCost, 'buy-jerry-can') then
        Player.Functions.AddItem('weapon_petrolcan', 1, nil, { fuel = Config.JerryCanLitre, ammo = Config.JerryCanLitre })
        coreBusinessRegisterSale(src, Config.JerryCanCost, string.format("Jerry can purchase: $%d", Config.JerryCanCost))
    end
end)

RegisterServerEvent('qb-fuel:server:refillJerryCan', function ()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local jerryCan = Player.Functions.GetItemByName('weapon_petrolcan')
    if not jerryCan then return Player.Functions.Notify(Lang:t('error.no_jerrycan'), 'error') end

    if not coreBusinessRemoveFuel(src, Config.JerryCanLitre) then
        Player.Functions.Notify('Not enough fuel in stock', 'error')
        return
    end

    if Player.Functions.RemoveMoney(Config.MoneyType, Config.JerryCanRefillCost, 'refill-jerry-can') then
        jerryCan.info.fuel = Config.JerryCanLitre
        jerryCan.info.ammo = Config.JerryCanLitre
        Player.Functions.RemoveItem('weapon_petrolcan', 1, jerryCan.slot)
        Player.Functions.AddItem('weapon_petrolcan', 1, nil, jerryCan.info)
        coreBusinessRegisterSale(src, Config.JerryCanRefillCost, string.format("Jerry can refill: $%d", Config.JerryCanRefillCost))
    end
end)

RegisterServerEvent('qb-fuel:server:setCanFuel', function (fuel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local jerryCan = Player.Functions.GetItemByName('weapon_petrolcan')
    if not jerryCan then return Player.Functions.Notify(Lang:t('error.no_jerrycan'), 'error') end

    jerryCan.info.fuel = fuel
    jerryCan.info.ammo = fuel
    Player.Functions.RemoveItem('weapon_petrolcan', 1, jerryCan.slot)
    Player.Functions.AddItem('weapon_petrolcan', 1, nil, jerryCan.info)
end)
