local isInZone = false
local isPannelOpen = false

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = GetPlayerPed(-1)
        local coords = GetEntityCoords(playerPed)

        -- Remplacez ces coordonnées par celles de votre point d'interaction
        local interactionCoords = vector3(221.0566, -891.6845, 30.6920)
        local distance = GetDistanceBetweenCoords(coords, interactionCoords, true)

        if distance < 2.0 then
            DisplayHelpText("Appuyez sur ~INPUT_CONTEXT~ pour ouvrir/fermer le panneau")
            if IsControlJustReleased(0, 38) then -- Touche "E"
                TriggerEvent('togglePanneau')
            end
        end
    end
end)

function DisplayHelpText(text)
    SetTextComponentFormat("STRING")
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

RegisterNUICallback('closePanel', function(data, cb)
    SetNuiFocus(false, false)
    isPannelOpen = false
    cb('ok')
end)

RegisterNUICallback('escape', function(data, cb)
    SetNuiFocus(false, false)
    isPannelOpen = false
    cb('ok')
end)

RegisterNetEvent('togglePanneau')
AddEventHandler('togglePanneau', function()
    print('Callback togglePanneau déclenché')
    isPannelOpen = not isPannelOpen

    print('togglePanneau déclenché. isPannelOpen:', isPannelOpen)

    if isPannelOpen then
        TriggerEvent('showPanneau', 'spaziacity')
    else
        TriggerEvent('hidePanneau')
    end
end)

RegisterNUICallback('togglePanneau', function(data, cb)
    TriggerClientEvent('togglePanneau', data.target, data.text)
    cb('ok')
end)

RegisterNUICallback('showPanneau', function(data, cb)
    TriggerClientEvent('showPanneau', data.target, data.text)
    cb('ok')
end)

RegisterNUICallback('hidePanneau', function(data, cb)
    TriggerClientEvent('hidePanneau', data.target)
    cb('ok')
end)


-- Gérer la touche "ESC"
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if isPannelOpen and IsControlJustReleased(0, 322) then -- Touche "ESC"
            TriggerEvent('togglePanneau')
        end
    end
end)
