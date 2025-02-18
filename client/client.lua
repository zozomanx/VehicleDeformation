-- Function to get all damage data (deformation + visual damage)
function GetVehicleDamageData(vehicle)
    local deformation = GetVehicleDeformation(vehicle)
    local brokenWindows = {}
    local brokenDoors = {}
    local dirtLevel = GetVehicleDirtLevel(vehicle)

    -- Check for broken windows
    for i = 0, 7 do -- There are 8 windows in GTA V
        if IsVehicleWindowIntact(vehicle, i) == false then
            table.insert(brokenWindows, i)
        end
    end

    -- Check for broken doors
    for i = 0, 5 do -- There are 6 doors in GTA V
        if IsVehicleDoorDamaged(vehicle, i) then
            table.insert(brokenDoors, i)
        end
    end

    return {
        deformation = deformation,
        brokenWindows = brokenWindows,
        brokenDoors = brokenDoors,
        dirtLevel = dirtLevel
    }
end

-- Function to apply all damage data (deformation + visual damage)
function SetVehicleDamageData(vehicle, damageData)
    -- Apply deformation
    if damageData.deformation and #damageData.deformation > 0 then
        SetVehicleDeformation(vehicle, damageData.deformation)
    end

    -- Apply broken windows
    for _, windowIndex in ipairs(damageData.brokenWindows) do
        SmashVehicleWindow(vehicle, windowIndex)
    end

    -- Apply broken doors
    for _, doorIndex in ipairs(damageData.brokenDoors) do
        SetVehicleDoorBroken(vehicle, doorIndex, true)
    end

    -- Apply dirt level
    SetVehicleDirtLevel(vehicle, damageData.dirtLevel)
end

-- Serialize deformation data to JSON
function SerializeDeformation(deformation)
    return json.encode(deformation)
end

-- Deserialize deformation data from JSON
function DeserializeDeformation(data)
    return json.decode(data)
end

-- Command to save damage data to the database
RegisterCommand("garagein", function()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)
        local damageData = GetVehicleDamageData(vehicle)

        if damageData then
            local damageDataJson = SerializeDeformation(damageData)

            -- Trigger server event to save damage data
            TriggerServerEvent("VD:saveDeformation", plate, damageDataJson)
        else
            print("[DEBUG] No damage data found for vehicle with plate: " .. plate)
        end
    else
        print("[DEBUG] Player is not in a valid vehicle.")
    end
end, false)

-- Command to reapply damage data from the database
RegisterCommand("garageout", function()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)

        -- Trigger server event to retrieve damage data
        TriggerServerEvent("VD:getDeformation", plate)
    else
        print("[DEBUG] Player is not in a valid vehicle.")
    end
end, false)

-- Event to receive damage data from the server
RegisterNetEvent("VD:receiveDeformation", function(damageDataJson)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle) then
        if damageDataJson then
            local damageData = DeserializeDeformation(damageDataJson)

            -- Apply damage data to the vehicle
            SetVehicleDamageData(vehicle, damageData)
            print("[DEBUG] Damage data reapplied for vehicle with plate: " .. GetVehicleNumberPlateText(vehicle))
        else
            print("[DEBUG] No damage data found for the vehicle.")
        end
    else
        print("[DEBUG] Player is not in a valid vehicle.")
    end
end)

function IsVehicleBlacklisted(vehicle)
	if (#typeBlacklist > 0) then
		local vehicleType = GetVehicleType(vehicle)
		for i = 1, #typeBlacklist do
			if (typeBlacklist[i] == vehicleType) then
				return true
			end
		end
	end

	if (#modelBlacklist > 0) then
		local vehicleModel = GetEntityModel(vehicle)
		for i = 1, #modelBlacklist do
			if (modelBlacklist[i] == vehicleModel) then
				return true
			end
		end
	end

	if (#plateBlacklist > 0) then
		local vehiclePlate = GetVehicleNumberPlateText(vehicle)
		for i = 1, #plateBlacklist do
			if (vehiclePlate:find(plateBlacklist[i]:upper())) then
				return true
			end
		end
	end

	return false
end

local function ApplyDeformation(vehicle, deformation)
	if (not DoesEntityExist(vehicle)) then
		local endTime = GetGameTimer() + 5000
		while (not DoesEntityExist(vehicle) and GetGameTimer() < endTime) do
			Wait(0)
		end

		if (not DoesEntityExist(vehicle)) then
			return
		end
	end
	if (not IsEntityAVehicle(vehicle)) then return end

	if (deformation and #deformation > 0) then
		SetVehicleDeformation(vehicle, deformation)
	else
		SetVehicleDeformationFixed(vehicle)
	end
end

local damageUpdate = {}
local function HandleDeformationUpdate(vehicle)
	if (damageUpdate[vehicle]) then
		damageUpdate[vehicle] = GetGameTimer() + 1000
		return
	end

	damageUpdate[vehicle] = GetGameTimer() + 1000

	while (damageUpdate[vehicle] > GetGameTimer()) do
		Wait(0)
	end

	damageUpdate[vehicle] = nil

	if (not DoesEntityExist(vehicle) or NetworkGetEntityOwner(vehicle) ~= PlayerId()) then return end

	local deformation = GetVehicleDeformation(vehicle)
	if (deformation and #deformation > 0) then
		Entity(vehicle).state:set("deformation", deformation, true)
	end
end

-- state bag handler to apply any deformation
AddStateBagChangeHandler("deformation", nil, function(bagName, key, value, _unused, replicated)
	if (bagName:find("entity") == nil) then return end

	ApplyDeformation(GetEntityFromStateBagName(bagName), value)
end)

-- update state bag on taking damage
AddEventHandler("gameEventTriggered", function (name, args)
	if (name ~= "CEventNetworkEntityDamage") then return end

	local entity = args[1]
	if (not IsEntityAVehicle(entity) or IsVehicleBlacklisted(entity)) then return end

	HandleDeformationUpdate(entity)
end)

-- fix deformation on vehicle
local function FixVehicleDeformation(vehicle)
	assert(DoesEntityExist(vehicle) and NetworkGetEntityIsNetworked(vehicle), "Parameter \"vehicle\" must be a valid and networked vehicle entity!")

	TriggerServerEvent("VD:fixDeformation", NetworkGetNetworkIdFromEntity(vehicle))
end

exports("FixVehicleDeformation", FixVehicleDeformation)
