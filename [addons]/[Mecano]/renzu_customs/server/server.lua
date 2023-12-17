ESX = nil
QBCore = nil
RegisterServerCallBack_ = {}
Initialized()
menu = false
Citizen.CreateThreadNow(function()
    Wait(1000)
    VehicleNames()
    for k, v in pairs(Config.Customs) do
        CustomsSQL(Config.Mysql, 'execute', 'INSERT IGNORE  INTO renzu_customs (shop) VALUES (@shop)', {
            ['@shop'] = k,
        })
    end
end)

RegisterServerCallBack_('renzu_customs:getinventory', function(source, cb, id, share)
    local source = source
    local xPlayer = GetPlayerFromId(source)
    local identifier = xPlayer.identifier
    if share then
        identifier = share.owner
    end
    local result = CustomsSQL(Config.Mysql, 'fetchAll', 'SELECT inventory FROM renzu_customs WHERE shop = @shop', {
        ['@shop'] = id
    })
    local inventory = {}
    if result[1] and result[1].inventory ~= nil then
        inventory = json.decode(result[1].inventory) or {}
    end
    cb(inventory)
end)

RegisterServerCallBack_('renzu_customs:itemavailable', function(source, cb, id, item, share)
    local source = source
    local xPlayer = GetPlayerFromId(source)
    local identifier = xPlayer.identifier
    if share then
        identifier = share.owner
    end
    local result = CustomsSQL(Config.Mysql, 'fetchAll', 'SELECT inventory FROM renzu_customs WHERE shop = @shop', {
        ['@shop'] = id
    })
    local inventory = false
    if json.decode(result[1].inventory) then
        inventory = json.decode(result[1].inventory) or {}
        if inventory[item] ~= nil and inventory[item] > 0 then
            inventory[item] = inventory[item] - 1
            CustomsSQL(Config.Mysql, 'execute', 'UPDATE renzu_customs SET inventory = @inventory WHERE shop = @shop', {
                ['@inventory'] = json.encode(inventory),
                ['@shop'] = id,
            })
            cb(true)
        else
            cb(false)
        end
    else
        cb(false)
    end
end)

RegisterServerEvent('renzu_customs:storemod')
AddEventHandler('renzu_customs:storemod', function(id, mod, lvl, newprop, share, save, savepartsonly)
    local src = source
    local xPlayer = GetPlayerFromId(src)
    local identifier = xPlayer.identifier
    if share then
        identifier = share.owner
    end
    local success = true
    local vehicles = nil
    local result = CustomsSQL(Config.Mysql, 'fetchAll', 'SELECT inventory FROM renzu_customs WHERE shop = @shop', {
        ['@shop'] = id
    })
    local inventory = json.decode(result[1].inventory) or {}
    if not save then
        local modname = mod.name .. '-' .. lvl
        if inventory[modname] == nil then
            inventory[modname] = 1
        else
            inventory[modname] = inventory[modname] + 1
        end
    end
    CustomsSQL(Config.Mysql, 'execute', 'UPDATE renzu_customs SET inventory = @inventory WHERE shop = @shop', {
        ['@inventory'] = json.encode(inventory),
        ['@shop'] = id,
    })
    TriggerClientEvent('renzu_notify:Notify', src, 'success', 'Garage',
        'You Successfully store the parts (' .. mod.name .. ')')
end)

local default_routing = {}
local current_routing = {}

function Jobmoney(job, xPlayer)
    local value = -1
    local job = job
    local count = 0
    if Config.UseRenzu_jobs then
        value = exports.renzu_jobs:JobMoney(job).money
    else
        if Config.framework == 'ESX' then
            TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. job, function(account)
                value = account.money
            end)
        else
            value = exports['qb-management']:GetAccount(job)
        end
        -- your owned job money here
    end
    while value == -1 and count < 550 do
        count = count + 1
        Wait(0)
    end
    return value
end

function IsPlayerInTable(table, player)
    for _, value in ipairs(table) do
        if value == player then
            return true
        end
    end
    return false
end

function GetDistance(coords1, coords2)
    return math.sqrt((coords1.x - coords2.x) ^ 2 + (coords1.y - coords2.y) ^ 2 + (coords1.z - coords2.z) ^ 2)
end

-- Fonction pour trouver l'ID du joueur le plus proche dans une zone
function GetNearestPlayerIdInZone(sourceCoords, zoneRadius, source)
    local allPlayers = {} -- Tableau pour stocker tous les joueurs

    for _, otherPlayerId in ipairs(ESX.GetPlayers()) do
        table.insert(allPlayers, tonumber(otherPlayerId)) -- Convertir en nombre et ajouter le joueur à la table
    end

    local nearestPlayerId = nil
    local nearestDistance = zoneRadius

    if IsPlayerInTable(allPlayers, tonumber(source)) then
        nearestPlayerId = nil -- Réinitialiser à nil si le joueur source est dans la table
    else
        for _, playerId in ipairs(allPlayers) do
            local otherPlayerPed = GetPlayerPed(playerId)
            local otherPlayerCoords = GetEntityCoords(otherPlayerPed, false)
            local distance = GetDistance(otherPlayerCoords, sourceCoords)

            if nearestPlayerId == nil or (distance > 0 and distance < nearestDistance) then
                nearestPlayerId = playerId
                nearestDistance = distance
            end
        end
    end

    print('allPlayers =', json.encode(allPlayers))
    print('nearestPlayerId =', nearestPlayerId)
    print('nearestDistance =', nearestDistance)

    return nearestPlayerId, nearestDistance
end

-- Fonction pour obtenir les informations sur le job depuis la base de données
function GetJobInfo(job, callback)
    MySQL.Async.fetchAll("SELECT pourcentage, label FROM addon_account WHERE name = @job", {
        ['@job'] = 'society_' .. job
    }, function(result)
        if result and #result > 0 then
            local jobInfo = {
                percentage = tonumber(result[1].pourcentage) or 0.2,
                label = result[1].label or 'Unknown Society'
            }
            callback(jobInfo)
        else
            callback(nil)
        end
    end)
end

-- Fonction principale pour gérer les transactions de la société
Society = function(job, baseAmount, method, source)
    if Config.framework == 'ESX' then
        TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. job, function(account)
            if account then
                if method == 'remove' then
                    local sourcePed = GetPlayerPed(source)
                    local sourceCoords = GetEntityCoords(sourcePed, false)
                    local zoneRadius = 30

                    local nearestPlayerId = GetNearestPlayerIdInZone(sourceCoords, zoneRadius, source)

                    if nearestPlayerId then
                        local nearestPlayer = ESX.GetPlayerFromId(nearestPlayerId)
                        print('nearestPlayerId =', nearestPlayerId)
                        GetJobInfo(job, function(jobInfo)
                            if jobInfo then
                                local totalAmount = baseAmount + (baseAmount * jobInfo.percentage)
                                local societyName = jobInfo.label

                                local nearestPlayerBankMoney = nearestPlayer.getAccount('bank').money

                                if nearestPlayerBankMoney >= totalAmount then
                                    nearestPlayer.removeAccountMoney('bank', totalAmount)
                                    TriggerClientEvent("k5_notify:notify", nearestPlayerId, societyName,
                                        ('Vous avez bien reçu %s de la part de %s'):format(totalAmount, societyName),
                                        'bennys', 10000)

                                    account.removeMoney(baseAmount)
                                    account.addMoney(totalAmount)
                                else
                                    local nearestPlayerCashMoney = nearestPlayer.getMoney()

                                    if nearestPlayerCashMoney >= totalAmount then
                                        nearestPlayer.removeMoney(totalAmount)
                                        TriggerClientEvent("k5_notify:notify", nearestPlayerId, societyName,
                                            ('Vous avez bien reçu %s de la part de %s'):format(totalAmount, societyName),
                                            'bennys', 10000)

                                        account.removeMoney(baseAmount)
                                        account.addMoney(totalAmount)
                                    else
                                        -- NOTIFICATION : PAS ASSEZ D'ARGENT
                                        TriggerClientEvent("k5_notify:notify", nearestPlayerId, societyName,
                                            ('Pas assez d\'argent en banque ni en liquide !'):format(societyName),
                                            'bennys', 10000)
                                        -- NOTIFICATION : SOURCE N'A PAS ASSEZ D'ARGENT
                                        TriggerClientEvent("k5_notify:notify", source, societyName,
                                            ('La Personne n\'a pas les fonds nécessaires pour effectuer la transaction avec %s.')
                                            :format(societyName),
                                            'bennys', 10000)
                                    end
                                end
                            end
                        end)
                    else
                        -- NOTIFICATION : AUCUNE PERSONNE PROCHE
                        TriggerClientEvent("k5_notify:notify", source, 'Société',
                            'Aucune personne proche dans la zone.', 'error', 10000)
                    end
                elseif method == 'add' then
                    account.addMoney(baseAmount)
                end
            end
        end)
    end
end

RegisterServerCallBack_('renzu_customs:pay', function(source, cb, t, shop, vclass)
    local src = source
    local xPlayer = GetPlayerFromId(src)
    local identifier = xPlayer.identifier
    local prop = t.prop
    local cost = tonumber(t.cost)
    local jobmoney = 0
    if cost == 1 then
        cost = 0
        t.cost = 0
    end
    local vclass = tonumber(vclass)
    if not menu and not Config.FreeUpgradeToClass[vclass] and not Config.JobPermissionAll and xPlayer.getMoney() >= t.cost or not menu and not Config.FreeUpgradeToClass[vclass] and Config.JobPermissionAll and Config.Customs[shop].job == xPlayer.job.name and Jobmoney(xPlayer.job.name, xPlayer) >= t.cost or menu then
        local result = CustomsSQL(Config.Mysql, 'fetchAll',
            'SELECT * FROM ' .. vehicletable .. ' WHERE UPPER(plate) = @plate', {
                ['@plate'] = prop.plate:upper()
            })
        if result[1] or menu then
            CustomsSQL(Config.Mysql, 'execute',
                'UPDATE ' .. vehicletable .. ' SET `' .. vehiclemod ..
                '` = @' .. vehiclemod .. ' WHERE UPPER(plate) = @plate', {
                    ['@' .. vehiclemod .. ''] = json.encode(prop),
                    ['@plate'] = prop.plate:upper()
                })
            if not Config.JobPermissionAll and not menu then                              --if other player
                xPlayer.removeMoney(cost)
            elseif Config.JobPermissionAll and not Config.UseRenzu_jobs and not menu then -- job owned without renzu_jobs
                xPlayer.removeMoney(cost)                                                 -- replace it with your job money
            end
            if menu then
                TriggerClientEvent('renzu_notify:Notify', src, 'success', 'Customs', 'MENU - Upgrade has been Installed')
            else
                TriggerClientEvent('renzu_notify:Notify', src, 'success', 'Customs',
                    'Payment Success - Upgrade has been Installed')
            end
            if shop and not Config.JobPermissionAll and not menu then
                if Config.UseRenzu_jobs then
                    addmoney = exports.renzu_jobs:addMoney(tonumber(t.cost), Config.Customs[shop].job, source, 'money',
                        true)
                else
                    Society(Config.Customs[shop].job, tonumber(t.cost), 'add', source)
                end
            elseif shop and Config.JobPermissionAll and Config.Customs[shop].job == xPlayer.job.name and not menu then
                if Config.UseRenzu_jobs then
                    removemoney = exports.renzu_jobs:removeMoney(tonumber(t.cost), Config.Customs[shop].job, source,
                        'money', true)
                else
                    Society(Config.Customs[shop].job, tonumber(t.cost), 'remove', source)
                end
            end
            cb(true)
        elseif not Config.OwnedVehiclesOnly or menu then
            CustomsSQL(Config.Mysql, 'execute',
                'UPDATE ' .. vehicletable .. ' SET `' .. vehiclemod ..
                '` = @' .. vehiclemod .. ' WHERE UPPER(plate) = @plate', {
                    ['@' .. vehiclemod .. ''] = json.encode(prop),
                    ['@plate'] = prop.plate:upper()
                })
            if shop and not Config.JobPermissionAll and xPlayer.getMoney() >= tonumber(t.cost) or Config.JobPermissionAll and Config.Customs[shop].job == xPlayer.job.name and Jobmoney(xPlayer.job.name, xPlayer) >= tonumber(t.cost) then
                if not Config.JobPermissionAll and not menu then --if other player
                    xPlayer.removeMoney(cost)
                    -- elseif Config.JobPermissionAll and not Config.UseRenzu_jobs and not menu then -- job owned without renzu_jobs
                    --     xPlayer.removeMoney(cost) -- replace it with your job money
                end
                if shop and not Config.JobPermissionAll and not menu then
                    if Config.UseRenzu_jobs then
                        addmoney = exports.renzu_jobs:addMoney(tonumber(t.cost), Config.Customs[shop].job, source,
                            'money', true)
                    else
                        Society(Config.Customs[shop].job, tonumber(t.cost), 'add', source)
                    end
                elseif shop and Config.JobPermissionAll and Config.Customs[shop].job == xPlayer.job.name and not menu then
                    if Config.UseRenzu_jobs then
                        removemoney = exports.renzu_jobs:removeMoney(tonumber(t.cost), Config.Customs[shop].job, source,
                            'money', true)
                    else
                        Society(Config.Customs[shop].job, tonumber(t.cost), 'remove', source)
                    end
                end
                TriggerClientEvent('renzu_notify:Notify', src, 'success', 'Customs',
                    'Payment Success - Upgrade has been Installed')
                cb(true)
            else
                TriggerClientEvent('renzu_notify:Notify', src, 'error', 'Customs', 'Not Enough Money Cabron')
                cb(false)
            end
        else
            TriggerClientEvent('renzu_notify:Notify', src, 'error', 'Customs', 'Vehicle is not Owned')
            cb(false)
        end
    elseif Config.FreeUpgradeToClass[vclass] then
        TriggerClientEvent('renzu_notify:Notify', src, 'success', 'Customs', 'FREE Upgrade has been Installed')
        local result = CustomsSQL(Config.Mysql, 'fetchAll',
            'SELECT * FROM ' .. vehicletable .. ' WHERE UPPER(plate) = @plate', {
                ['@plate'] = prop.plate:upper()
            })
        if result[1] then
            CustomsSQL(Config.Mysql, 'execute',
                'UPDATE ' .. vehicletable .. ' SET `' .. vehiclemod ..
                '` = @' .. vehiclemod .. ' WHERE UPPER(plate) = @plate', {
                    ['@' .. vehiclemod .. ''] = json.encode(prop),
                    ['@plate'] = prop.plate:upper()
                })
        end
        cb(true)
    else
        TriggerClientEvent('renzu_notify:Notify', src, 'error', 'Customs', 'Not Enough Money Cabron')
        cb(false)
    end
    menu = false
end)

RegisterServerCallBack_('renzu_customs:repair', function(source, cb, shop)
    local src = source
    local xPlayer = GetPlayerFromId(src)
    local jobmoney = 0
    if xPlayer.getMoney() >= Config.RepairCost and not menu then
        if Config.UseRenzu_jobs and Config.Customs[shop].job ~= xPlayer.job.name then -- job permission access is free repair
            addmoney = exports.renzu_jobs:addMoney(tonumber(Config.RepairCost), Config.Customs[shop].job, source, 'money',
                true)
        end
        if Config.Customs[shop].job ~= xPlayer.job.name then
            xPlayer.removeMoney(Config.RepairCost)
        end
        cb(true)
    elseif menu then
        cb(true)
    else
        cb(false)
    end
end)

local inshop = {}
RegisterServerCallBack_('renzu_customs:getmoney', function(source, cb, net, props)
    local src = source
    local xPlayer = GetPlayerFromId(src)
    inshop[source] = { net = net, props = props }
    local money = 0
    if Config.UseRenzu_jobs and Config.JobPermissionAll then
        money = Jobmoney(xPlayer.job.name, xPlayer)
    else
        money = xPlayer.getMoney()
    end
    cb(money)
end)

RegisterServerEvent('playerDropped')
AddEventHandler('playerDropped', function(reason)
    for k, v in pairs(inshop) do
        if tonumber(source) == tonumber(k) then
            TriggerClientEvent('renzu_customs:restoremod', -1, v.net, v.props)
            --DeleteEntity(v)
        end
    end
end)

RegisterServerEvent('renzu_customs:leaveshop')
AddEventHandler('renzu_customs:leaveshop', function()
    inshop[source] = nil
end)

function GetVehicleNetWorkIdByPlate(plate, source, dist)
    local source = source
    for k, v in ipairs(GetAllVehicles()) do
        if GetVehicleNumberPlateText(v) == plate and #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(v)) < 5 then -- support only near vehicle , means spawn and teleport the ped to vehicle seat
            return NetworkGetNetworkIdFromEntity(v)
        end
    end
    for k, v in ipairs(GetAllVehicles()) do
        if GetVehicleNumberPlateText(v) == plate then -- no range restriction if above loop does not find (but this does not support multiple duplicated plates in area)
            return NetworkGetNetworkIdFromEntity(v)
        end
    end
    return -1
end

RegisterServerEvent('renzu_customs:syncdel')
AddEventHandler('renzu_customs:syncdel', function(net)
    local source = source
    local entity = NetworkGetEntityFromNetworkId(net)
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end)

local customengine = {}
RegisterServerEvent('renzu_customs:custom_engine')
AddEventHandler('renzu_customs:custom_engine', function(netid, plate, model)
    customengine[plate] = model
    local source = source
    if model == 'Default' then customengine[plate] = nil end
    Wait(1500) -- added wait for other garage script compatibility (setprop before ped is in vehicle)
    TriggerClientEvent('renzu_customs:receivenetworkid', -1, GetVehicleNetWorkIdByPlate(plate, source), model)
    SetResourceKvp('engine', json.encode(customengine))
end)

local customturbo = {}
RegisterServerEvent('renzu_customs:custom_turbo')
AddEventHandler('renzu_customs:custom_turbo', function(plate, turbo)
    customturbo[plate] = turbo
    if turbo == 'Default' then customturbo[plate] = nil end
    TriggerClientEvent('renzu_customs:receiveturboupgrade', -1, customturbo)
    SetResourceKvp('turbo', json.encode(customturbo))
end)

local customtire = {}
RegisterServerEvent('renzu_customs:custom_tire')
AddEventHandler('renzu_customs:custom_tire', function(plate, tire)
    customtire[plate] = tire
    local source = source
    if tire == 'Default' then customtire[plate] = nil end
    Wait(1500) -- added wait for other garage script compatibility (setprop before ped is in vehicle)
    TriggerClientEvent('renzu_customs:custom_tire', -1, customtire, GetVehicleNetWorkIdByPlate(plate, source), tire)
    SetResourceKvp('tire', json.encode(customtire))
end)

RegisterServerEvent('renzu_customs:soundsync')
AddEventHandler('renzu_customs:soundsync', function(table)
    TriggerClientEvent('renzu_customs:soundsync', -1, table)
end)

RegisterServerEvent('renzu_customs:loaded')
AddEventHandler('renzu_customs:loaded', function()
    local source = source
    TriggerClientEvent('renzu_customs:receivedata', source, customturbo, customengine, vehiclesname)
end)

RegisterCommand('freecustoms', function(source, args)
    local source = tonumber(source)
    local xPlayer = GetPlayerFromId(source)
    local playerGroup = xPlayer.getGroup(source)
    menu = true
    if Config.framework == 'ESX' and playerGroup == "superadmin" or playerGroup == "mod" or playerGroup == "admin" or Config.framework == 'QBCORE' and playerGroup then
        TriggerClientEvent('renzu_customs:openmenu', source, true)
    end
end)
