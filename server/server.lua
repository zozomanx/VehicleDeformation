-- Function to fix vehicle deformation
local function FixVehicleDeformation(vehicle)
    assert(vehicle and DoesEntityExist(vehicle), "Parameter \"vehicle\" must be a valid vehicle entity!")
    Entity(vehicle).state:set("deformation", nil, true)
end

-- Event to fix deformation from client
RegisterNetEvent("VD:fixDeformation", function(networkId)
    FixVehicleDeformation(NetworkGetEntityFromNetworkId(networkId))
end)

-- Event to save deformation data to the database
RegisterNetEvent("VD:saveDeformation", function(plate, deformationJson)
    -- Save deformation data to the database
    MySQL.Async.execute('INSERT INTO vehicle_deformation (plate, deformation_data) VALUES (@plate, @deformation) ON DUPLICATE KEY UPDATE deformation_data = @deformation', {
        ['@plate'] = plate,
        ['@deformation'] = deformationJson
    }, function(rowsChanged)
        if rowsChanged > 0 then
            print("[DEBUG] Deformation saved for vehicle with plate: " .. plate)
        else
            print("[DEBUG] Failed to save deformation for vehicle with plate: " .. plate)
        end
    end)
end)

-- Event to retrieve deformation data from the database
RegisterNetEvent("VD:getDeformation", function(plate)
    local src = source -- Get the source (player) who triggered the event

    -- Retrieve deformation data from the database
    MySQL.Async.fetchScalar('SELECT deformation_data FROM vehicle_deformation WHERE plate = @plate', {
        ['@plate'] = plate
    }, function(deformationJson)
        if deformationJson then
            -- Send the deformation data back to the client
            TriggerClientEvent("VD:receiveDeformation", src, deformationJson)
        else
            -- Send nil if no data is found
            TriggerClientEvent("VD:receiveDeformation", src, nil)
        end
    end)
end)

exports("FixVehicleDeformation", FixVehicleDeformation)