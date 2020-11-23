require("scripts/jet-AI.lua")

-- Jets list --
local jetsNameList = {MFBasicJet="MFBasicJet"}

-- Table of Entities type that can be repaired --
local rEntList = {"accumulator", "arithmetic-combinator", "artillery-turret", "artillery-wagon", "assembling-machine", "beacon",
"boiler", "burner-generator", "car", "cargo-wagon", "container", "curved-rail", "decider-combinator", "electric-energy-interface",
"electric-pole", "electric-turret", "fluid-turret", "fluid-wagon", "furnace", "gate", "generator", "heat-interface", "heat-pipe",
"infinity-container", "infinity-pipe ", "inserter", "lab", "lamp", "land-mine", "loader", "loader-1x1", "locomotive", "logistic-container",
"market", "mining-drill", "offshore-pump", "pipe", "pipe-to-ground", "power-switch", "programmable-speaker", "pump", "radar",
"rail-chain-signal", "rail-planner", "rail-signal", "reactor", "roboport", "rocket-silo", "solar-panel", "splitter", "storage-tank",
"straight-rail", "train-stop", "transport-belt", "turret", "underground-belt", "wall",
}

-- The amount of Energy needed to launch a Jet --
local energyNeededPerJet = 100000

-- Maximum number of Jets updated every Tick --
local maxJetUpdated = 100

-- Number of Ticks between each Mobile Factory Update --
local MFUpdate = 23

-- Minimum number of Ticks between two Mobile Factory Update --
local minMFUpdate = 5

-- Number of Ticks between each Missions Table Update --
local missionUpdate = 33

-- Minimum number of Ticks between two Users Missions Table Update --
local minMissionUpdate = 6

-- The maximum size of the Mission Table --
local maxMissionTableSize = 500

-- Max Ores Paths inside the Ore Table --
local maxOresPaths = 300

-- The area scanned to find Enemies when an attack begin --
local enemyScanSize = 15

-- Number of Ticks between each ActiveMissionsTable Check --
local activeMissionCheckUpdate = 289

-- Minimum number of Ticks between two Users ActiveMissionsTable Check --
local minActiveMissionCheckUpdate = 101

-- Number of Ticks between each Jet launch Check --
local launchCheckUpdate = 47

-- Minimum number of Ticks between two Users Jet Launch Check --
local minLaunchCheckUpdate = 7

-- Maximum Jet per Ores Path --
local maxOresPathJets = 3

-- Return the Mobile Factory Global object --
-- function getMFGlobal()
--     return remote.call("MFCom", "getGlobal")
-- end

-- Calcule the Distance between two Positions --
function distance(position1, position2)
	local x1 = position1[1] or position1.x
	local y1 = position1[2] or position1.y
	local x2 = position2[1] or position2.x
	local y2 = position2[2] or position2.y
	return ((x1 - x2) ^ 2 + (y1 - y2) ^ 2) ^ 0.5
end

-- When the Mod Init --
function onInit()

    -- The MF Users List --
    global.MFUsersList = {NoOne="NoOne"}

    -- Create the Jets Table --
    global.jetsTable = {} -- [k](Jet) --

    -- Create the Jets Table Index --
    global.jetsTableIndex = nil

    -- Create the Jets update per Tick variable --
    global.jetsUpdatePerTick = maxJetUpdated

    -- Create the MFTable Index --
    global.MFTableIndex = 1

    -- The maximum Jet distance --
    global.maxJetDistance = 50

    -- The Ores Table --
    global.oresTable = {} -- [MFUserName](OresTable) --

    -- The reparable Entities Table --
    global.repairTable = {} -- [MFUserName](EntsTable) --

    -- The Ghosts Table --
    global.ghostsTable = {} -- [MFUserName](GhostsTable) --

    -- The Deconstruction Table --
    global.removeTable = {} -- [MFUserName](RemoveTable) --

    -- The Enemies Table --
    global.enemiesTable = {} -- [MFUserName](NearestEnemy) --

    -- The Mission Table --
    global.missionsTable = {} -- [MFUserName](MissionsTable) --

    -- The Mission Table Index --
    global.missionTableIndex = 1

    -- The Active Missions Table --
    global.activeMissionsTable = {} --  [MFUserName](ActiveMissionsTable[entity.unit_number](mission))

    -- The Active Missions Table Index --
    global.activeMissionsTableIndex = 1

    -- The Launch Check Index --
    global.launchCheckIndex = 1

    -------------- Tell to all old Jets to go back home --------------
    local MFGlobal = remote.call("MFCom", "getGlobal")

    -- Mining Jets --
    for _, jet in pairs(MFGlobal.miningJetTable or {}) do
        local jetObj = Jet.create(jet.player, jet.MF.ent, nil, 0, jet.ent)
        table.insert(global.jetsTable, jetObj)
        Jet.returnToMF(jetObj)
        if jet.inventoryItem ~= nil then
            jetObj.inv[jet.inventoryItem] = jet.inventoryCount
        end
    end

    -- Repair Jets --
    for _, jet in pairs(MFGlobal.repairJetTable or {}) do
        local jetObj = Jet.create(jet.player, jet.MF.ent, nil, 0, jet.ent)
        table.insert(global.jetsTable, jetObj)
        Jet.returnToMF(jetObj)
    end

    -- Construction Jets --
    for _, jet in pairs(MFGlobal.constructionJetTable or {}) do
        local jetObj = Jet.create(jet.player, jet.MF.ent, nil, 0, jet.ent)
        table.insert(global.jetsTable, jetObj)
        Jet.returnToMF(jetObj)
        if jet.inventoryItem ~= nil then
            jetObj.inv[jet.inventoryItem] = jet.inventoryCount
        end
    end

    -- Combat Jets --
    for _, jet in pairs(MFGlobal.combatJetTable or {}) do
        local jetObj = Jet.create(jet.player, jet.MF.ent, nil, 0, jet.ent)
        table.insert(global.jetsTable, jetObj)
        Jet.returnToMF(jetObj)
    end

end


-- Called every Tick --
function onTick()

    -- The Users List Table size --
    local usersNumber = table_size(global.MFUsersList)
	if usersNumber == 0 then
		if game.tick%300 == 0 then
			global.MFUsersList = remote.call("MFCom", "getMFUsersList")
			return
		end
	end
    ----------------------------------- Update Jets -----------------------------------

    -- Check the Index --
    if global.jetsTable[global.jetsTableIndex] == nil or global.jetsTableIndex == nil then
        -- Calcule how many Jets must be updated per Tick --
        global.jetsUpdatePerTick = math.min(maxJetUpdated, math.ceil( table_size(global.jetsTable)/60 ))
        -- Start to the beginning of the Table --
        global.jetsTableIndex = nil
    end

    -- Itinerate the Jets Table --
    for i=1, global.jetsUpdatePerTick do

        -- Get the next non-nil Item --
        local k, jetObj = next(global.jetsTable, global.jetsTableIndex)

        -- Save the current Key --
        global.jetsTableIndex = k

        -- Check the Jet --
        if jetObj ~= nil and jetObj.ent ~= nil and jetObj.ent.valid == true then
            Jet.update(jetObj)
        elseif k ~= nil then
            global.jetsTableIndex = next(global.jetsTable, global.jetsTableIndex)
            global.jetsTable[k] = nil
        end

    end


    ----------------------------------- Update Mobile Factory -----------------------------------
    -- Calcule the Number of Ticks between each Mobile Factory Update --
    local MFUpdateTick = math.max(minMFUpdate, math.ceil(MFUpdate/usersNumber))
    -- Check if a MF have to be updated --
    if game.tick%MFUpdateTick == 0 then

        -- Get the MFUserList --
        global.MFUsersList = remote.call("MFCom", "getMFUsersList")

        -- Check the Index --
        if global.MFTableIndex > table_size(global.MFUsersList) then
            global.MFTableIndex = 1
        end

        -- Get the User to Update --
        local MFUser = global.MFUsersList[global.MFTableIndex]

        -- Increment the Index --
        global.MFTableIndex = global.MFTableIndex + 1

        -- Check the MFUser --
        if MFUser == nil then goto noMFUpdate end

        -- Get the Mobile Factory Entity --
        local MFEnt = remote.call("MFCom", "getMFEnt", MFUser)

        -- Check the Mobile Factory --
        if MFEnt == nil or MFEnt.valid == false then goto noMFUpdate end

        -- Update the OresTable --  
        global.oresTable[MFUser] = MFEnt.surface.find_entities_filtered{position=MFEnt.position, radius=global.maxJetDistance, type="resource", limit=maxOresPaths} or {}

        -- Update the RepairTable --
        global.repairTable[MFUser] = MFEnt.surface.find_entities_filtered{position=MFEnt.position, radius=global.maxJetDistance, type=rEntList, force=MFEnt.force} or {}

        -- Update the Ghosts Table --
        global.ghostsTable[MFUser] = MFEnt.surface.find_entities_filtered{position=MFEnt.position, radius=global.maxJetDistance, type="entity-ghost", force=MFEnt.force} or {}

        -- Update the Remove Table --
        global.removeTable[MFUser] = MFEnt.surface.find_entities_filtered{position=MFEnt.position, radius=global.maxJetDistance, to_be_deconstructed=true, force=MFEnt.force} or {}

        -- Get the nearest Enemy if there are one --
        global.enemiesTable[MFUser] = MFEnt.surface.find_nearest_enemy{position=MFEnt.position, max_distance=global.maxJetDistance}

        -- End of the Mobile Factory Update --
        ::noMFUpdate::

    end

    ----------------------------------- Update the Missions Table -----------------------------------

    -- Calcule the number of Ticks between each User Missions Table Update --
    local missionUpdateTick = math.max(minMissionUpdate, math.ceil(missionUpdate/usersNumber))

    -- Check if the Mission Table have to be Updated --
    if game.tick%missionUpdateTick == 0 then

        -- Get the MFUserList --
        global.MFUsersList = remote.call("MFCom", "getMFUsersList")
        -- Index Update --
		global.missionTableIndex = global.missionTableIndex + 1
        if global.missionTableIndex > table_size(global.MFUsersList) then
            global.missionTableIndex = 1
        end

        -- Get the User to Update --
        local MFUser = global.MFUsersList[global.missionTableIndex]

        -- Check the MFUser --
        if MFUser == nil then
			goto noMissionUpdate
		end

        -- Empty the Table --
        global.missionsTable[MFUser] = {}

        -- Create the Active Mission Table if needed --
        global.activeMissionsTable[MFUser] = global.activeMissionsTable[MFUser] or {}

        -- Add priotity 5 Missions (Attack) --
        local enemy = global.enemiesTable[MFUser]
        if enemy ~= nil and enemy.valid == true then
            -- Get the Enemy count --
            local count = enemy.surface.count_entities_filtered{position=enemy.position, radius=enemyScanSize, force=game.players[MFUser].force, invert=true}
            -- Register the Mission --
            local activeMissionNumber = enemy.unit_number ~= nil and tostring(enemy.unit_number) or tostring(enemy.position.x) .. tostring(enemy.position.y)
            if global.activeMissionsTable[MFUser][activeMissionNumber] == nil then
                table.insert(global.missionsTable[MFUser], {mission="Defend", surface=enemy.surface, pos=enemy.position, ent=enemy, priority=5, count=count})
            elseif global.activeMissionsTable[MFUser][activeMissionNumber].jets ~= nil and table_size(global.activeMissionsTable[MFUser][activeMissionNumber].jets) < count then
                table.insert(global.missionsTable[MFUser], global.activeMissionsTable[MFUser][activeMissionNumber])
            end
        end

        -- Add priotity 4 Missions (Repair) --
        for _, ent in pairs(global.repairTable[MFUser] or {}) do
            -- Stop if the Table size is too big --
            if table_size(global.missionsTable[MFUser]) > maxMissionTableSize then break end
            -- Check the Entity --
            if ent ~= nil and ent.valid == true and ent.health < ent.prototype.max_health then
                -- Add the Mission --
                local activeMissionNumber = ent.unit_number ~= nil and tostring(ent.unit_number) or tostring(ent.position.x) .. tostring(ent.position.y)
                if global.activeMissionsTable[MFUser][activeMissionNumber] == nil then
                    table.insert(global.missionsTable[MFUser], {mission="Repair", ent=ent, priority=4})
                end
            end
        end

        -- Add priority 3 Missions (Remove) --
        for _, ent in pairs(global.removeTable[MFUser] or {}) do
            -- Stop if the Table size is too big --
            if table_size(global.missionsTable[MFUser]) > maxMissionTableSize then break end
            -- Check the Entity --
            if ent ~= nil and ent.valid == true and ent.to_be_deconstructed() == true then
                -- Add the Mission --
                local activeMissionNumber = ent.unit_number ~= nil and tostring(ent.unit_number) or tostring(ent.position.x) .. tostring(ent.position.y)
                if global.activeMissionsTable[MFUser][activeMissionNumber] == nil then
                    table.insert(global.missionsTable[MFUser], {mission="Remove", ent=ent, priority=3})
                end
            end
        end

        -- Add priotity 2 Missions (Construct) --
        for _, ent in pairs(global.ghostsTable[MFUser] or {}) do
            -- Stop if the Table size is too big --
            if table_size(global.missionsTable[MFUser]) > maxMissionTableSize then break end
            -- Check the Entity --
            if ent ~= nil and ent.valid == true then
                -- Check if the Mobile Factory has the Item --
                if ent.ghost_prototype ~= nil and ent.ghost_prototype.items_to_place_this ~= nil and ent.ghost_prototype.items_to_place_this[1] ~= nil then
                    local item = ent.ghost_prototype.items_to_place_this[1]
                        if remote.call("MFCom", "hasItems", MFUser, item.name, 1) > 0 then
                        -- Add the Mission --
                        local activeMissionNumber = ent.unit_number ~= nil and tostring(ent.unit_number) or tostring(ent.position.x) .. tostring(ent.position.y)
                        if global.activeMissionsTable[MFUser][activeMissionNumber] == nil then
                            table.insert(global.missionsTable[MFUser], {mission="Construct", ent=ent, priority=2})
                        end
                    end
                end
            end
        end

        -- Add priority 1 Missions (Mine) --
        for _, ent in pairs(global.oresTable[MFUser] or {}) do
            -- Stop if the Table size is too big --
            if table_size(global.missionsTable[MFUser]) > maxMissionTableSize then break end
            -- Check the Entity --
            if ent ~= nil and ent.valid == true and ent.prototype.mineable_properties.products[1].type == "item" then
                -- Add the Mission --
                local activeMissionNumber = ent.unit_number ~= nil and tostring(ent.unit_number) or tostring(ent.position.x) .. tostring(ent.position.y)
                if global.activeMissionsTable[MFUser][activeMissionNumber] == nil then
                    table.insert(global.missionsTable[MFUser], {mission="Mine", ent=ent, priority=1, count=maxOresPathJets})
                elseif global.activeMissionsTable[MFUser][activeMissionNumber].jets ~= nil and table_size(global.activeMissionsTable[MFUser][activeMissionNumber].jets) < maxOresPathJets then
                    table.insert(global.missionsTable[MFUser], global.activeMissionsTable[MFUser][activeMissionNumber])
                end
            end
        end

        -- End of the Update --
        ::noMissionUpdate::

    end

    ----------------------------------- Check the Active Missions Table -----------------------------------
    -- Calcule the number of Ticks between each Active Missions Table Check --
    local activeMissionTableUpdateTick = math.max(minActiveMissionCheckUpdate, math.ceil(activeMissionCheckUpdate/usersNumber))

    -- Check if a Active Missions Table have to be checked --
    if game.tick%activeMissionTableUpdateTick == 0 then

        -- Get the MFUserList --
        global.MFUsersList = remote.call("MFCom", "getMFUsersList")

        -- Check the Index --
        if global.activeMissionsTableIndex > table_size(global.activeMissionsTable) then
            global.activeMissionsTableIndex = 1
        end

        -- Get the User to Update --
        local MFUser = global.MFUsersList[global.activeMissionsTableIndex]

        -- Check the MFUser --
        if MFUser == nil then goto noActiveMissionTableCheck end

        -- Itinerate the Active Missions Table --
        for k, mission in pairs(global.activeMissionsTable[MFUser] or {}) do
            -- Itinerate the Jets List --
            for k2, jet in pairs(mission.jets or {}) do
                if jet.ent.valid == false then
                    mission.jets[k2] = nil
                end
            end
            -- Check if the Mission is abandoned --
            if table_size(mission.jets) <= 0 then
                global.activeMissionsTable[MFUser][k] = nil
            end
        end

        -- End of the Check --
        ::noActiveMissionTableCheck::

    end


    ----------------------------------- Update Jet Launch Check -----------------------------------
    -- Calcule the number of Ticks between each Jet Launch Check --
    local launchCheckUpdateTick = math.max(minLaunchCheckUpdate, math.ceil(launchCheckUpdate/usersNumber))

    -- Check if the Launch Check have to be started --
    if game.tick%launchCheckUpdateTick == 0 then
        -- Get the MFUserList --
        global.MFUsersList = remote.call("MFCom", "getMFUsersList")

        -- Check the Index --
        if global.launchCheckIndex > table_size(global.MFUsersList) then
            global.launchCheckIndex = 1
        end

        -- Get the User to Update --
        local MFUser = global.MFUsersList[global.missionTableIndex]

        -- Check the MFUser --
        if MFUser == nil then
			goto noLaunchCheck
		end

        -- Check if the User need to be Updated --
        if table_size(global.missionsTable[MFUser] or {}) <= 0 then
			goto noLaunchCheck
		end

        -- Get the Mobile Factory Entity --
        local MFEnt = remote.call("MFCom", "getMFEnt", MFUser)

        -- Check the Entity --
        if MFEnt == nil or MFEnt.valid == false then
			return
		end

        -- Get the Mobile Factory Trunk --
        local inv = MFEnt.get_inventory(defines.inventory.car_trunk)

        -- Check the Inventory --
        if inv == nil or inv.valid == false then
			goto noLaunchCheck
		end

        -- Create the Jet launch offset --
        local offset = 0

        -- Itinerate the Missions Table --
        for k, mission in pairs(global.missionsTable[MFUser] or {}) do

            -- Check the Mobile Factory Energy --
            local energy = remote.call("MFCom", "removeMFEnergy", MFUser, energyNeededPerJet)
            if energy < energyNeededPerJet then break end

            -- Check if there are Jet left --
            if inv.get_item_count("MFBasicJet") <= 0 then break end

            -- Check the Mission --
            if mission.ent == nil or mission.ent.valid == false or mission.ent.surface ~= MFEnt.surface then goto continue end

            -- Check the distance --
            if distance(MFEnt.position, mission.ent.position) > global.maxJetDistance then goto continue end

            -- Check if the Mission is already active and need more Jets --
            local activeMissionNumber = mission.ent.unit_number ~= nil and tostring(mission.ent.unit_number) or tostring(mission.ent.position.x) .. tostring(mission.ent.position.y)
            mission = global.activeMissionsTable[MFUser][activeMissionNumber] or mission
            if mission.ent == nil or mission.ent.valid == false or mission.ent.surface ~= MFEnt.surface then goto continue end
            if mission.jets ~= nil and table_size(mission.jets) >= (mission.count or 1) then goto continue end
            if mission.ent == nil or mission.ent.valid == false or mission.ent.surface ~= MFEnt.surface then goto continue end

            -- Create the Mission Jets Table --
            mission.jets = mission.jets or {}
            
            -- Send the needed amount of Jets --
            local securI = 0
            while table_size(mission.jets) < (mission.count or 1) and securI < 100 do

                -- Check if the Mobile Factory has the Item to Construct --
                local item = nil
                if mission.mission == "Construct" and mission.ent.ghost_prototype ~= nil and mission.ent.ghost_prototype.items_to_place_this ~= nil and mission.ent.ghost_prototype.items_to_place_this[1] ~= nil then
                    item = mission.ent.ghost_prototype.items_to_place_this[1]
                    if remote.call("MFCom", "takeItems", MFUser, item.name, 1) <= 0 then goto continue end
                elseif mission.mission == "Construct" then
                    goto continue
                end

                -- Check if there are Jets left --
                local removed = inv.remove({name="MFBasicJet", count=1})
                if removed <= 0 then break end

                -- Create the Jet --
                local jetObj = Jet.create(MFUser, MFEnt, mission, offset)
                offset = math.min(offset + 1, 6)

                -- Give the Item to the Jet if needed --
                if mission.mission == "Construct" and item ~= nil then
                    Jet.addItems(jetObj, item.name, 1)
                end

                -- Add the Jet to the Mission Table --
                mission.jets[jetObj.ent.unit_number] = jetObj

                -- Add the Jet to the Jets Table --
                table.insert(global.jetsTable, jetObj)

                -- Increment the loop security number --
                securI = securI + 1

            end

            -- Add the Mission to the Active Mission Table --
            global.activeMissionsTable[MFUser][activeMissionNumber] = mission

            -- Remove the Mission from the Missions Table --
            global.missionsTable[MFUser][k] = nil

            -- End of the loop --
            ::continue::

        end

        -- End of the Update --
        ::noLaunchCheck::

    end

end

-- Called when an Entity is damaged --
function entityDamaged(event)

    -- Check the Entity --
    local ent = event.entity
    if ent == nil or ent.valid == false then return end

    -- Check if this is a Jet --
    if jetsNameList[ent.name] == nil then return end

    -- Check if the Jet will die --
    if event.final_health > 1 then return end

    -- Set the Jet heal to 1 --
    ent.health = 1

    -- Get the Jet Object --
    local jetObj = nil
    for _, jet in pairs(global.jetsTable) do
        if jet.ent ~= nil and jet.ent.valid == true and jet.ent == ent then
            jetObj = jet
        end
    end

    -- Check the Jet Object --
    if jetObj == nil then return end

    -- Say the Jet to return home --
    if jetObj.surviveMode ~= true then
        ent.set_command({type=defines.command.stop})
        jetObj.currentJobIndex = 1
        jetObj.jobsList = {}
        jetObj.surviveMode = true
        Jet.returnToMF(jetObj, defines.distraction.none)
        ent.speed = 0.1
        ent.destructible = false
        rendering.draw_animation{animation="mfShield", target=ent, x_scale=0.15, y_scale=0.15, tint={63,176,255}, surface=ent.surface, render_layer=134}
    end

end

-- Called when the Player placed something --
-- function somethingWasPlaced(event)

--     -- Get the Entity and the last User and check --
--     local entity = event.created_entity or event.entity
--     local lastUser = entity.last_user
--     if entity == nil or lastUser == nil then return end

-- end





-- Event --
script.on_init(onInit)
script.on_event(defines.events.on_tick, onTick)
script.on_event(defines.events.on_entity_damaged, entityDamaged)
-- script.on_event(defines.events.on_built_entity, somethingWasPlaced)
-- script.on_event(defines.events.script_raised_built, somethingWasPlaced)
-- script.on_event(defines.events.script_raised_revive, somethingWasPlaced)
-- script.on_event(defines.events.on_robot_built_entity, somethingWasPlaced)
-- script.on_event(defines.events.on_entity_cloned, somethingWasPlaced)