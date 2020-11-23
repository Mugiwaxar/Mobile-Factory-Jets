------------------------------------- JETS A.I. -------------------------------------

-- Available Jobs: --
--[[
    {job="Idle"}
    {job="Stop"}
    {job="MoveToPos", pos=position, radius=radius, distraction=distraction}
    {job="MoveToEnt", ent=entity, radius=radius, distraction=distraction}
    {job="TakeItem", item=item}
    {job="Mine", startedTick=tick}
    {job="Repair", startedTick=tick}
    {job="Construct"}
    {job="Remove"}
    {job="CheckMission"}
    {job="EnterMF"}
]]

-- Available Missions: --
--[[
    {mission="Mine", ent=orePath, priotiry=priority, jets=JetList[jet.ent.unit_number](Jet)}
    {mission="Repair", ent=entity, priotiry=priority, jets=JetList[jet.ent.unit_number](Jet)}
    {mission="Construct", ent=blueprint, priotiry=priority, jets=JetList[jet.ent.unit_number](Jet)}
    {mission="Remove", ent=entity, priotiry=priority, jets=JetList[jet.ent.unit_number](Jet)}
    {mission="Defend", surface=surface, pos=position, ent=enemy, priotiry=priority, count=EnemiesCount, jets=JetList[jet.ent.unit_number](Jet)}
]]

-- The Table --
Jet = {}

-- Max Jet Energy --
local maxJetEnergy = 100

-- The Time needed to Mine --
local miningTime = 60

-- The number of Ores mined per operation --
local miningAmount = 5

-- The Mining Energy cost --
local miningCost = 5

-- The health added to repaired Entity --
local repairAmount = 100

-- The Repair Energy Cost --
local repairCost = 5

-- The Repair Time --
local repairTime = 60

-- The Construction Cost --
local constructCost = 15

-- The Remove Cost --
local RemoveCost = 15

-- Create a Jet AI --
function Jet.create(user, MFEnt, mission, offset, ent)
    -- Create the Jet Entity --
    local entity = ent or MFEnt.surface.create_entity{name="MFBasicJet", position={MFEnt.position.x - 3 + (offset or 0), MFEnt.position.y}, force=MFEnt.force, player=game.players[user]}
    -- Register the Jet --
    local jetObj = {
    ent = entity,
    playerName = user,
    MFEnt = MFEnt,
    currentJob = {job="Idle"},
    jobsList = {},
    currentJobIndex = 1,
    mission = mission,
    inv = {}, -- [ItemName](Count) --
    energy = maxJetEnergy,
    surviveMode = false
    }
    return jetObj
end

-- Update the Jet AI --
function Jet.update(jetObj)

    --  Check the Jet --
    if jetObj.ent == nil or jetObj.ent.valid == false then return end

    -- Return if the Jet is moving --
    if jetObj.ent.command ~= nil and jetObj.ent.command.type == defines.command.go_to_location then
        return
    end

    -- Return if the Jet is Mining --
    if jetObj.currentJob.job == "Mine" and jetObj.currentJob.startedTick ~= nil and game.tick - jetObj.currentJob.startedTick < miningTime then
        return
    end

    -- Return if the Jet is Repairing --
    if jetObj.currentJob.job == "Repair" and jetObj.currentJob.startedTick ~= nil and game.tick - jetObj.currentJob.startedTick < repairTime then
        return
    end

    -- Construct the Job list if needed --
    if table_size(jetObj.jobsList) <= 0 then
        Jet.constructJobsList(jetObj)
    end

    -- Apply the next Job if possible --
    if jetObj.jobsList[jetObj.currentJobIndex] ~= nil then
        jetObj.currentJob = jetObj.jobsList[jetObj.currentJobIndex]
        Jet.applyJob(jetObj)
        jetObj.currentJobIndex = jetObj.currentJobIndex + 1
    else
        Jet.returnToMF(jetObj)
    end

end

-- Construct the Jobs list --
function Jet.constructJobsList(jetObj)

    -- Get the Mission --
    local mission = jetObj.mission

    -- Check the Surface --
    if mission.surface ~= nil and mission.surface ~= jetObj.ent.surface then
        Jet.checkMission(jetObj)
        return
    end
    if mission.ent ~= nil and mission.ent.valid == true and mission.ent.surface ~= jetObj.ent.surface then
        Jet.checkMission(jetObj)
        return
    end

    -- Check if an Item must be take from the Mobile Factory --
    if mission.mission == "Construct" then
        -- Check the Mission Ghost --
        if jetObj.mission.ent == nil or jetObj.mission.ent.valid == false then
            Jet.checkMission(jetObj)
            return
        end
        if jetObj.mission.ent.ghost_prototype == nil or jetObj.mission.ent.ghost_prototype.items_to_place_this == nil then
            Jet.checkMission(jetObj)
            return
        end
        -- Get the Mission Ghost Item --
        local item = jetObj.mission.ent.ghost_prototype.items_to_place_this[1]
        if item == nil or game.item_prototypes[item.name] == nil then
            Jet.checkMission(jetObj)
            return
        end
        -- Check if the Jet doesn't already have the needed Item --
        if jetObj.inv[item.name] ~= nil and jetObj.inv[item.name] > 0 then
            -- Print the Text --
            Jet.createFText(jetObj, game.item_prototypes[item.name].localised_name, 1, "+")
        else
            -- Check the Mobile Factory --
            if jetObj.MFEnt ~= nil or jetObj.MFEnt.valid == true then
                table.insert(jetObj.jobsList, {job="MoveToEnt", ent=jetObj.MFEnt, radius=1})
                table.insert(jetObj.jobsList, {job="TakeItem", item=item.name})
            else
                -- Print the Text --
                Jet.createFText(jetObj, "Mobile Factory??")
                return
            end
        end
    end

    -- Fly to the position --
    if mission.mission == "Defend" and mission.pos ~= nil then
        table.insert(jetObj.jobsList, {job="MoveToPos", pos=mission.pos, radius=1})
    else
        table.insert(jetObj.jobsList, {job="MoveToEnt", ent=mission.ent, radius=1})
    end

    -- Stop --
    if mission.mission ~= "Defend" then
        table.insert(jetObj.jobsList, {job="Stop"})
    end

    -- Check if the Mission is to Mine --
    if mission.mission == "Mine" then
        table.insert(jetObj.jobsList, {job="Mine"})
    end

    -- Check if the Mission is to Repair --
    if mission.mission == "Repair" then
        table.insert(jetObj.jobsList, {job="Repair"})
    end

    -- Check if the Mission is to Construct --
    if mission.mission == "Construct" then
        table.insert(jetObj.jobsList, {job="Construct"})
    end

    -- Check if the Mission is to Remove --
    if mission.mission == "Remove" then
        table.insert(jetObj.jobsList, {job="Remove"})
    end

    -- Check the Mission --
    table.insert(jetObj.jobsList, {job="CheckMission"})

    -- Return to the Mobile Factory --
    Jet.returnToMF(jetObj)

end

-- Apply a Job --
function Jet.applyJob(jetObj)

    -- Stop --
    if jetObj.currentJob.job == "Stop" then
        Jet.stop(jetObj)
        return
    end

    -- Go to a Position --
    if jetObj.currentJob.job == "MoveToPos" then
        Jet.moveToPosition(jetObj, jetObj.currentJob.pos, jetObj.currentJob.radius, jetObj.currentJob.distraction)
        return
    end

    -- Go to a Entity --
    if jetObj.currentJob.job == "MoveToEnt" then
        Jet.moveToEntity(jetObj, jetObj.currentJob.ent, jetObj.currentJob.radius, jetObj.currentJob.distraction)
        return
    end

    -- Enter the Mobile Factory --
    if jetObj.currentJob.job == "EnterMF" then
        Jet.enterMF(jetObj)
        return
    end

    -- Check the Mission --
    if jetObj.currentJob.job == "CheckMission" then
        Jet.checkMission(jetObj)
        return
    end

    -- Mine --
    if jetObj.currentJob.job == "Mine" then
        Jet.mine(jetObj)
        return
    end

    -- Repair --
    if jetObj.currentJob.job == "Repair" then
        Jet.repair(jetObj)
        return
    end

    -- Take Item --
    if jetObj.currentJob.job == "TakeItem" then
        Jet.takeItem(jetObj, jetObj.currentJob.item)
        return
    end

    -- Construct --
    if jetObj.currentJob.job == "Construct" then
        Jet.construct(jetObj)
        return
    end

    -- Remove --
    if jetObj.currentJob.job == "Remove" then
        Jet.remove(jetObj)
        return
    end

end

-- Add Items to the Inventory --
function Jet.addItems(jetObj, itemName, count)
    if jetObj.inv[itemName] ~= nil then
        jetObj.inv[itemName] = jetObj.inv[itemName] + count
    else
        jetObj.inv[itemName] = count
    end
end

-- Check the Current Mission --
function Jet.checkMission(jetObj)

    -- Check if the Jet still have Energy --
    if jetObj.energy < 5 then
        Jet.returnToMF(jetObj)
        return
    end

    -- Get the current Mission --
    local mission = jetObj.mission

    -- Check the Mobile Factory --
    if jetObj.MFEnt == nil or jetObj.MFEnt.valid == false then
        -- Print the Text --
        Jet.createFText(jetObj, "Mobile Factory??")
        return
    end

    -- Check the distance --
    if distance(jetObj.MFEnt.position, jetObj.ent.position) > global.maxJetDistance then
        Jet.returnToMF(jetObj)
        return
    end

    -- Get the first Mission of the Mission List --
    local firstMission = global.missionsTable[jetObj.playerName][1]
    -- Check the Mission --
    if firstMission ~= nil and firstMission.ent ~= nil and firstMission.ent.valid == true and firstMission.ent.surface == jetObj.MFEnt.surface then
        -- Check if the Mission is still available --
        local activeMissionNumber = firstMission.ent.unit_number ~= nil and tostring(firstMission.ent.unit_number) or tostring(firstMission.ent.position.x) .. tostring(firstMission.ent.position.y)
        local activeMission = global.activeMissionsTable[jetObj.playerName][activeMissionNumber]
        -- Check if the Mission need More Jets --
        if activeMission ~= nil and activeMission.jets ~= nil and table_size(activeMission.jets) >= (activeMission.count or 1) then
            firstMission = nil
        elseif activeMission ~= nil then
            firstMission = activeMission
        end
    else
        firstMission = nil
    end

    -- Check if this is a Construct Mission --
    if firstMission ~= nil and firstMission.mission == "Construct" then
        -- Check if the Mobile Factory has the needed Item --
        if firstMission.ent.ghost_prototype ~= nil and firstMission.ent.ghost_prototype.items_to_place_this ~= nil and firstMission.ent.ghost_prototype.items_to_place_this[1] ~= nil then
            local item = firstMission.ent.ghost_prototype.items_to_place_this[1]
            if remote.call("MFCom", "hasItems", jetObj.playerName, item.name, 1) <= 0 then
                firstMission = nil
            end
        end
    end

    -- Check if there are an highest priority Mission --
    if firstMission ~= nil and firstMission.priority > mission.priority then
        -- Change the Mission --
        Jet.changeMission(jetObj, firstMission, 1)
        return
    end

    -- Check if the mining Mission is still possible --
    if mission.mission == "Mine" and mission.ent ~= nil and mission.ent.valid == true and mission.ent.amount > 0 then
        -- Reset the Jet --
        jetObj.currentJob = {}
        jetObj.jobsList = {{job="Mine"},{job="CheckMission"}}
        jetObj.currentJobIndex = 0
        Jet.returnToMF(jetObj)
        return
    end

    -- Check if the repair Mission is still possible --
    if mission.mission == "Repair" and mission.ent ~= nil and mission.ent.valid == true and mission.ent.health < mission.ent.prototype.max_health then
        -- Reset the Jet --
        jetObj.currentJob = {}
        jetObj.jobsList = {{job="Repair"},{job="CheckMission"}}
        jetObj.currentJobIndex = 0
        Jet.returnToMF(jetObj)
        return
    end

    -- Check if a Mission with the same Priority is possible --
    if firstMission ~= nil then
        Jet.changeMission(jetObj, firstMission, 1)
        return
    end

    -- Return to the Mobile Factory --
    Jet.returnToMF(jetObj)

end

-- Change the Current Mission --
function Jet.changeMission(jetObj, mission, k)
    -- Check the Mission --
    if mission.ent == nil or mission.ent.valid == false then return end
    -- Reset the Jet --
    jetObj.currentJob = {}
    jetObj.jobsList = {}
    jetObj.currentJobIndex = 0
    -- Add the Mission to the active Missions Table --
    local activeMissionNumber = mission.ent.unit_number ~= nil and tostring(mission.ent.unit_number) or tostring(mission.ent.position.x) .. tostring(mission.ent.position.y)
    global.activeMissionsTable[jetObj.playerName][activeMissionNumber] = mission
    -- Save the Jet inside the Mission Table --
    mission.jets = mission.jets or {}
    mission.jets[jetObj.ent.unit_number] = jetObj
    -- Save the Mission to the Jet --
    jetObj.mission = mission
    -- Remove the Mission from the Missions Table --
    global.missionsTable[jetObj.playerName][k] = nil
    -- Build the Mission --
    Jet.constructJobsList(jetObj)
end

-- Create a Flying Text --
function Jet.createFText(jetObj, locName, count, calcule, string)
    -- Check the Entity --
    if jetObj.ent == nil or jetObj.ent.valid == false then return end
    -- Check the Player --
	if not jetObj.playerName then return end
	local player = game.players[jetObj.playerName]
	if player == nil or player.valid == false then return end
    -- Get the Localized Text --
    local locString = {"", locName, " ", calcule, count, " ", string}
    -- Print the Message --
    player.create_local_flying_text{text=locString, position=jetObj.ent.position}
end

-- Return to the Mobile Factory --
function Jet.returnToMF(jetObj, distraction)
    -- Check if the Mobile Factory exist and try to find a new one if no --
    if jetObj.MFEnt == nil or jetObj.MFEnt.valid == false then
        jetObj.MFEnt = remote.call("MFCom", "getMFEnt", jetObj.playerName)
    end
    -- Return to the Mobile Factory position --
    table.insert(jetObj.jobsList, {job="MoveToEnt", ent=jetObj.MFEnt, radius=1, distraction=distraction})
    -- Enter the Mobile Factory --
    table.insert(jetObj.jobsList, {job="EnterMF"})
end

-- Stop the Jet from moving --
function Jet.stop(jetObj)
    jetObj.ent.set_command({type=defines.command.stop})
end

-- Move to a Position --
function Jet.moveToPosition(jetObj, position, radius, distraction)
    jetObj.ent.set_command({type=defines.command.go_to_location, destination=position, radius=radius or 0, distraction=distraction})
end

-- Move to an Entity --
function Jet.moveToEntity(jetObj, entity, radius, distraction)
    if entity ~= nil and entity.valid == true then
        jetObj.ent.set_command({type=defines.command.go_to_location, destination_entity=entity, radius=radius or 0, distraction=distraction})
    end
end

-- Enter the Mobile Factory --
function Jet.enterMF(jetObj)

    -- Check the Mobile Factory --
    if jetObj.MFEnt == nil or jetObj.MFEnt.valid == false then
        -- Print the Text --
        Jet.createFText(jetObj, "Mobile Factory??")
        return
    end

    -- Store the Inventory --
    for item, count in pairs(jetObj.inv) do
        -- Check the Item --
        if game.item_prototypes[item] ~= nil then
            -- Send the Items --
            local sent = remote.call("MFCom", "addItems", jetObj.playerName, item, count)
            -- Remove the Items from the Jet Inventory --
            jetObj.inv[item] = jetObj.inv[item] - sent
            if jetObj.inv[item] <= 0 then jetObj.inv[item] = nil end
            -- Print the Text --
            if sent < 0 then
                Jet.createFText(jetObj, game.item_prototypes[item].localised_name, count, "-")
            end
        else
            jetObj.inv[item] = nil
        end
    end

    -- Check if the Inventory is empty --
    if table_size(jetObj.inv) > 0 then
        -- Print a Text for all Items left --
        for item, _ in pairs(jetObj.inv) do
            Jet.createFText(jetObj, game.item_prototypes[item].localised_name, nil, "?")
        end
        return
    end

    -- Get the Trunk --
    local inv = jetObj.MFEnt.get_inventory(defines.inventory.car_trunk)

    -- Check the Inventory --
    if inv == nil or inv.valid == false then return end
    
    -- Stock the Jet --
    local stocked = inv.insert({name="MFBasicJet", count=1})
    
    -- Return if the Jet was not stocked --
    if stocked == 0 then
        -- Print the Text --
        Jet.createFText(jetObj, "Mobile Factory trunk full?")
        return
    end

    -- Destroy the Jet --
    jetObj.ent.destroy()

end

-- Start Mining --
function Jet.mine(jetObj)
    
    -- Get the Ore Path --
    local orePath = jetObj.mission.ent

    -- Check the Ore Path --
    if orePath == nil or orePath.valid == false or orePath.amount <= 0 then
        return
    end
    
    -- Extract Ores --
    local extracted = math.min(miningAmount, orePath.amount)

    -- Add the Ores to the Inventory --
    Jet.addItems(jetObj, orePath.prototype.mineable_properties.products[1].name, extracted)

    -- Print the Text --
    local locName = orePath.prototype.mineable_properties.products[1].name
    locName = game.item_prototypes[locName].localised_name
    Jet.createFText(jetObj, locName, extracted, "+")

    -- Remove the Ores from the OrePath --
    orePath.amount = math.max(orePath.amount - extracted, 1)

    -- Create the Beam --
    jetObj.ent.surface.create_entity{name="GreenBeam", duration=miningTime, position=jetObj.ent.position, target=orePath.position, source=jetObj.ent.position}

    -- Remove the Energy cost --
    jetObj.energy = jetObj.energy - miningCost

    -- Remove the Ores Path if empty --
    if orePath.amount <= 1 then
        orePath.destroy()
    end

    -- Add the Started Tick to the Job --
    jetObj.currentJob.startedTick = game.tick

end

function Jet.repair(jetObj)

    -- Get the Entity to repair --
    local ent = jetObj.mission.ent

    -- Check the Entity --
    if ent == nil or ent.valid == false or ent.health >= ent.prototype.max_health then return end

    -- Add health to the Entity --
    local heal = math.min(ent.prototype.max_health - ent.health, repairAmount)
    ent.health = ent.health + heal

    -- Print the Text --
    Jet.createFText(jetObj, ent.prototype.localised_name, heal, "+", "HP")

    -- Create the Beam --
    jetObj.ent.surface.create_entity{name="GreenBeam", duration=repairTime, position=jetObj.ent.position, target=ent.position, source=jetObj.ent.position}

    -- Remove the Energy cost --
    jetObj.energy = jetObj.energy - repairCost

    -- Add the Started Tick to the Job --
    jetObj.currentJob.startedTick = game.tick

    -- Remove the Mission from the Actual Mission List if the Entity is full health --
    if ent.health >= ent.prototype.max_health then
        global.activeMissionsTable[jetObj.playerName][tostring(ent.unit_number)] = nil
    end

end

-- Take an Item from the Mobile Factory --
function Jet.takeItem(jetObj, item)

    -- Check the Mobile Factory --
    if jetObj.MFEnt == nil or jetObj.MFEnt.valid == false then
        -- Print the Text --
        Jet.createFText(jetObj, "Mobile Factory??")
        return
    end

    -- Check the Item --
    if item == nil or game.item_prototypes[item] == nil then
        Jet.checkMission(jetObj)
        return
    end

    -- Take the Item from the Mobile Factory --
    local count = remote.call("MFCom", "takeItems", jetObj.playerName, item, 1)

    -- Check if an Item was removed --
    if count <= 0 then
        Jet.checkMission(jetObj)
        return
    end

    -- Add the Item to the Jet Inventory --
    Jet.addItems(jetObj, item, count)

    -- Print the Text --
    Jet.createFText(jetObj, game.item_prototypes[item].localised_name, count, "+")

end

-- Construct a Ghost --
function Jet.construct(jetObj)

    -- Check the Mission Ghost --
    if jetObj.mission.ent == nil or jetObj.mission.ent.valid == false then
        Jet.checkMission(jetObj)
        return
    end
    if jetObj.mission.ent.ghost_prototype == nil or jetObj.mission.ent.ghost_prototype.items_to_place_this == nil then
        Jet.checkMission(jetObj)
        return
    end

    -- Get the Mission Ghost Item --
    local item = jetObj.mission.ent.ghost_prototype.items_to_place_this[1]
    if item == nil or game.item_prototypes[item.name] == nil then
        Jet.checkMission(jetObj)
        return
    end

    -- Check if the Item is inside the Jet Inventory --
    if jetObj.inv[item.name] == nil or jetObj.inv[item.name] == 0 then
        Jet.checkMission(jetObj)
        return
    end

    -- Revive the Ghost --
    local revived = jetObj.mission.ent.revive({raise_revive=true})

    -- Check if the Ghost was revived --
    if revived == nil then
        Jet.checkMission(jetObj)
        return
    end

    -- Remove the Item from the Inventory --
    jetObj.inv[item.name] = jetObj.inv[item.name] - 1
    if jetObj.inv[item.name] <= 0 then jetObj.inv[item.name] = nil end

    -- Print the Text --
    Jet.createFText(jetObj, game.item_prototypes[item.name].localised_name, 1, "-")

    -- Remove the Energy cost --
    jetObj.energy = jetObj.energy - constructCost

end

-- Remove an Entity --
function Jet.remove(jetObj)

    -- Check the Entity --
    if jetObj.mission.ent == nil or jetObj.mission.ent.valid == false then
        Jet.checkMission(jetObj)
        return
    end
    if jetObj.mission.ent.prototype == nil or jetObj.mission.ent.prototype.items_to_place_this == nil then
        Jet.checkMission(jetObj)
        return
    end

    -- Get the Item returned when the Entity is removed --
    local item = jetObj.mission.ent.prototype.items_to_place_this[1]
    if item == nil or game.item_prototypes[item.name] == nil then
        Jet.checkMission(jetObj)
        return
    end

    -- Remove the Entity --
    local destroyed = jetObj.mission.ent.destroy({raise_destroy=true})

    -- Check if the Entity was destroyed --
    if destroyed == false then
        Jet.checkMission(jetObj)
        return
    end

    -- Add the Item the the Jet Inventory --
    Jet.addItems(jetObj, item.name, 1)

    -- Print the Text --
    Jet.createFText(jetObj, game.item_prototypes[item.name].localised_name, 1, "+")

    -- Remove the Energy cost --
    jetObj.energy = jetObj.energy - RemoveCost

end