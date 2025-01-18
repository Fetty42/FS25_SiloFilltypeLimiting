-- Author: Fetty42
-- Date: 08.12.2024
-- Version: 1.0.0.0

local dbPrintfOn = false

local function dbPrintf(...)
	if dbPrintfOn then
    	print(string.format(...))
	end
end

local function Printf(...)
    	print(string.format(...))
end

-- **************************************************

StorageLimit = {}; -- Class

StorageLimit.timeOfLastNotification = {}
StorageLimit.maxStoredFillTypesDefault = 4
StorageLimit.maxStoredFillTypesExtensionDefault = 2
StorageLimit.knownStorageStations = {}	-- StationName = maxStoredFillTypes
StorageLimit.initDone = false

StorageLimit.directory = g_currentModDirectory
StorageLimit.modName = g_currentModName
StorageLimit.confDirectory = getUserProfileAppPath().. "modSettings/"


addModEventListener(StorageLimit)

function StorageLimit:loadMap(name)
	dbPrintf("call StorageLimit:loadMap");
	UnloadingStation.getFreeCapacity = Utils.overwrittenFunction(UnloadingStation.getFreeCapacity, StorageLimit.unloadingStation_getFreeCapacity)	

	-- Save Configuration when saving savegame
	FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, StorageLimit.writeConfig)

	--load settings:
	StorageLimit:readConfig();
end


-- function StorageLimit:postLoadMap()
-- 	dbPrintf("call StorageLimit:postLoadMap");
-- 	-- StorageLimit:getAllStorageStations()
-- end;
-- FSBaseMission.onFinishedLoading = Utils.appendedFunction(FSBaseMission.onFinishedLoading, StorageLimit.postLoadMap);


function StorageLimit:update(dt)
	-- dbPrintf("call StorageLimit:update")
	if g_currentMission:getIsClient() and not StorageLimit.initDone then
		StorageLimit.initDone = true
		StorageLimit:getAllStorageStations()
	end
end


function StorageLimit:getAllStorageStations()
	dbPrintf("call StorageLimit:getAllStorageStations()");

	for _, station in pairs(g_currentMission.storageSystem.unloadingStations) do
	
		local placeable = station.owningPlaceable
		local stationItentifier = StorageLimit:getStationItentifier(station)
		dbPrintf("  - Station: Name=%s | typeName=%s | categoryName=%s | isSellingPoint=%s | hasStoragePerFarm=%s | ownerFarmId=%s",
		stationItentifier, tostring(placeable.typeName), tostring(placeable.storeItem.categoryName), tostring(station.isSellingPoint), station.hasStoragePerFarm, placeable.ownerFarmId)

		if StorageLimit:isStationRelevant(station) then
			dbPrintf("    --> is relevant StorageStation")

			if StorageLimit.knownStorageStations[stationItentifier] == nil then
				dbPrintf("StorageLimit: New undefined storage station '%s'. Set max storage slots to %s (default)", stationItentifier, StorageLimit.maxStoredFillTypesDefault)
				StorageLimit.knownStorageStations[stationItentifier] = -1
			end
		end
	end

	-- Try to get more information for the owned storage extensions (e.g. mod name)
	dbPrintf("")
	dbPrintf("  Try to get more information for the owned storage extensions (e.g. mod name)")
	for _, station in pairs(g_currentMission.storageSystem.storageExtensions) do
        dbPrintf("    storageSystem.storageExtensions: id=%s | capacity=%s", station.id, station.capacity)
	end
	-- for _, station in pairs(g_currentMission.storageSystem.extendableLoadingStations) do
    --     print(tostring(station))
	-- end
	-- for _, station in pairs(g_currentMission.storageSystem.extendableUnloadingStations) do
    --     print(tostring(station))
	-- end
	-- for _, station in pairs(g_currentMission.storageSystem.storages) do
    --     print(tostring(station))
	-- end
end


function StorageLimit:isStationRelevant(station)
	-- dbPrintf("call StorageLimit:isStationRelevant()");
	local placeable = station.owningPlaceable
	
	-- dbPrintf("  - Station: getName=%s | typeName=%s | categoryName=%s | isSellingPoint=%s | hasStoragePerFarm=%s | ownerFarmId=%s",
	-- placeable:getName(), tostring(placeable.typeName), tostring(placeable.storeItem.categoryName), tostring(station.isSellingPoint), station.hasStoragePerFarm, placeable.ownerFarmId)

	-- ~= PRODUCTIONPOINTS, ANIMALPENS
	-- == SILOS
	-- getName=Railroad Silo North | typeName=silo | categoryName=PLACEABLEMISC | isSellingPoint=nil | hasStoragePerFarm=true | ownerFarmId=0
	-- getName=Farma 400 + Obi 1000 | typeName=silo | categoryName=SILOS | isSellingPoint=nil | hasStoragePerFarm=false | ownerFarmId=1			--> is own relevant StorageStation
	-- getName=Medium Petrol Tank | typeName=silo | categoryName=DIESELTANKS | isSellingPoint=nil | hasStoragePerFarm=false | ownerFarmId=1 	--> is own relevant StorageStation
	-- getName=Liquidmanure Tank | typeName=silo | categoryName=SILOS | isSellingPoint=nil | hasStoragePerFarm=false | ownerFarmId=1 			--> is own relevant StorageStation

	if ((station.isSellingPoint == nil or station.isSellingPoint == false) and placeable.ownerFarmId == g_currentMission:getFarmId()) then
        if ((placeable.storeItem.categoryName == "SILOS" or placeable.storeItem.categoryName == "STORAGES") and placeable.typeName == "silo")
            or (placeable.typeName == "FS22_HofBergmann.mapSiloSystem")
            or (placeable.typeName == "FS22_Franconian_Farm.chickenHusbandrySilo") then
		-- placeable.storeItem.categoryName ~= "ANIMALPENS" and placeable.storeItem.categoryName ~= "PRODUCTIONPOINTS"
		-- dbPrintf("    --> is own relevant StorageStation")
            return true
        end
	end
	
	if station.isSellingPoint == nil and placeable.storeItem.categoryName == "PLACEABLEMISC" and station.hasStoragePerFarm then
		-- dbPrintf("    --> is general relevant StorageStation")
		-- print("")
		-- print("unloadingStations: " .. station.owningPlaceable:getName())
		-- print("**** DebugUtil.printTableRecursively() **********************************************************************************************")
		-- DebugUtil.printTableRecursively(station,".",0,0)
		-- print("**** End DebugUtil.printTableRecursively() ******************************************************************************************")
		return true
	end
	return false
end


function StorageLimit.unloadingStation_getFreeCapacity(station, superFunc, fillTypeIndex, farmId)
	-- dbPrintf("call StorageLimit:unloadingStation_getFreeCapacity")
	-- dbPrintf("call StorageLimit:unloadingStation_getFreeCapacity: station=%s | fillTypeIndex=%s | farmId=%s", station, fillTypeIndex, farmId)

	-- don't handle
	if not StorageLimit:isStationRelevant(station) or fillTypeIndex == nil or farmId == nil then
		return superFunc(station, fillTypeIndex, farmId)
	end

	-- info output, but not every call
	local withOutput = false
	if StorageLimit.timeOfLastNotification[farmId] == nil
	or StorageLimit.timeOfLastNotification[farmId][station] == nil
	or StorageLimit.timeOfLastNotification[farmId][station][fillTypeIndex] == nil
	or g_currentMission.environment.dayTime/(1000*60) > StorageLimit.timeOfLastNotification[farmId][station][fillTypeIndex] + 6
	or g_currentMission.environment.dayTime/(1000*60) < StorageLimit.timeOfLastNotification[farmId][station][fillTypeIndex]
	then
		-- dbPrintf(string.format("  dayTime=%s", tostring(g_currentMission.environment.dayTime/(1000*60))))
		if StorageLimit.timeOfLastNotification[farmId] == nil then
			StorageLimit.timeOfLastNotification[farmId] = {}
		end
		if StorageLimit.timeOfLastNotification[farmId][station] == nil then
			StorageLimit.timeOfLastNotification[farmId][station] = {}
		end
		StorageLimit.timeOfLastNotification[farmId][station][fillTypeIndex] = g_currentMission.environment.dayTime/(1000*60)
		-- dbPrintf(tostring(StorageLimit.timeOfLastNotification[farmId][station][fillTypeIndex]))
		withOutput = true
	end

	if withOutput then
		local fillTypeName = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex).name
		dbPrintf("call2 StorageLimit.unloadingStation_getFreeCapacity: station=%s | fillTypeIndex=%s | fillTypeName=%s | farmId=%s",
			tostring(station), tostring(fillTypeIndex), tostring(fillTypeName), tostring(farmId))
		dbPrintf("  Station: getName=%s | typeName=%s | categoryName=%s", station.owningPlaceable:getName(), station.owningPlaceable.typeName, station.owningPlaceable.storeItem.categoryName)
	end

	local maxStoredFillTypes = StorageLimit.maxStoredFillTypesDefault
	local stationIdentifier = StorageLimit:getStationItentifier(station)


	if StorageLimit.knownStorageStations[stationIdentifier] == nil then
		dbPrintf("StorageLimit: New undefined storage station '%s'. Set max storage slots to %s (default)", stationIdentifier, StorageLimit.maxStoredFillTypesDefault)
		StorageLimit.knownStorageStations[stationIdentifier] = -1
	else		
		maxStoredFillTypes = StorageLimit.knownStorageStations[stationIdentifier]
		if maxStoredFillTypes == -1 then
			maxStoredFillTypes = StorageLimit.maxStoredFillTypesDefault
			if withOutput then
				dbPrintf("StorageLimit: Undefined storage station '%s'. Set max storage slots to %s (default)", stationIdentifier, StorageLimit.maxStoredFillTypesDefault)
			end
		else
			if withOutput then
				dbPrintf("StorageLimit: Already known storage station '%s' with %s storage slots", stationIdentifier, maxStoredFillTypes)
			end
		end
	end

	-- Number of stored fill types
	local storedFillTypes = {}
	local countStoredFillTypes = 0
    local countTargetStorages = 0
	for _, targetStorage in pairs(station.targetStorages) do
        if farmId == nil or station:hasFarmAccessToStorage(farmId, targetStorage) then
            countTargetStorages = countTargetStorages + 1

			if withOutput then
				dbPrintf("  Target-Storagess: id=%s | capacity=%s", targetStorage.id, targetStorage.capacity)
			end

			for fillTypeIndex1, _ in pairs(targetStorage.fillTypes) do
				local ftName = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex1).name
				if station:getFillLevel(fillTypeIndex1, farmId) > 0.1 and storedFillTypes[ftName] == nil then
					storedFillTypes[ftName] = true
					countStoredFillTypes = countStoredFillTypes + 1
					if withOutput then
						dbPrintf("  Storage-%s: ftName=%s(%s) | ftFillLevel=%s | countStoredFillTypes=%s", countTargetStorages, ftName, fillTypeIndex1, station:getFillLevel(fillTypeIndex1, farmId), countStoredFillTypes)
					end
				end
			end
		end
	end

    local maxStoredFillTypesOverAll = maxStoredFillTypes + (countTargetStorages-1) * StorageLimit.maxStoredFillTypesExtensionDefault
	local isFilltypeAlreadyInUse = station:getFillLevel(fillTypeIndex, farmId) > 0.1

	local notificationText = "";
	local callSuperFunction = true
	local isNotAllowed = false
	if isFilltypeAlreadyInUse  then
		-- The storage space for this fill type is already in use
		if countStoredFillTypes <= maxStoredFillTypesOverAll then
			if withOutput then
				dbPrintf("  The filltype is already in use --> Unloading is allowed. Storage slots in use %s/%s", countStoredFillTypes, maxStoredFillTypesOverAll)
				notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_ExistingFiltype"), countStoredFillTypes, maxStoredFillTypesOverAll)
			end
		else
			notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_UnloadingNotAllowed"), countStoredFillTypes, maxStoredFillTypesOverAll)
			callSuperFunction = false
		end
	elseif countStoredFillTypes < maxStoredFillTypesOverAll then
		if withOutput then
			dbPrintf("  New filltype and still free storage slots --> Unloading is allowed. Storage slots in use %s/%s", countStoredFillTypes, maxStoredFillTypesOverAll)
			notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_NewFilltype"), countStoredFillTypes, maxStoredFillTypesOverAll)
		end
	else
		notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_UnloadingNotAllowed"), countStoredFillTypes, maxStoredFillTypesOverAll)
		callSuperFunction = false
	end

	-- info output, but not every call
	if withOutput and  notificationText ~= "" then
		dbPrintf("  StorageLimit: countTargetStorages=%s | maxStoredFillTypesOverAll=%s | Msg=%s", countTargetStorages, maxStoredFillTypesOverAll, notificationText)
		g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, notificationText)
		-- g_currentMission.hud:addSideNotification(FSBaseMission.INGAME_NOTIFICATION_OK, notificationText, 3000);
		if not callSuperFunction then
			g_currentMission:showBlinkingWarning(notificationText, 8000)
		end
	end
	
	if callSuperFunction then
		return superFunc(station, fillTypeIndex, farmId)
	else
    	return 0
	end
end


-- function StorageLimit:saveSavegame()
-- 	Printf("StorageLimit:saveSavegame")

-- 	StorageLimit:writeConfig();
-- end;


function StorageLimit:writeConfig()
	dbPrintf("StorageLimit:writeConfig")

	-- skip on dedicated servers
	if g_dedicatedServerInfo ~= nil then
		return
	end
	
	createFolder(StorageLimit.confDirectory);

	local fileName = StorageLimit.confDirectory .. StorageLimit.modName .. ".xml"
	local key = "StorageLimit";
	local xmlFile = createXMLFile(key, fileName, key);		

	if xmlFile > 0 then
		setXMLString(xmlFile, key.."#XMLFileVersion", "1.0");

		local settingKey = string.format("%s.Settings", key)
		setXMLInt(xmlFile, settingKey..".maxStoredFillTypesDefault", StorageLimit.maxStoredFillTypesDefault)
		setXMLInt(xmlFile, settingKey..".maxStoredFillTypesExtensionDefault", StorageLimit.maxStoredFillTypesExtensionDefault)

		local i = 0
		for stationName, maxStoredFillTypes in pairs(StorageLimit.knownStorageStations) do
			local posKey = string.format("%s.StorageStations.StationName(%d)", key, i)
			setXMLString(xmlFile, posKey.."#stationName", stationName)
			setXMLInt(xmlFile, posKey.."#maxStoredFillTypes", maxStoredFillTypes)
			i = i + 1
		end

		saveXMLFile(xmlFile)
		delete(xmlFile)
	end
end


function StorageLimit:readConfig()
	dbPrintf("StorageLimit:readConfig")

	-- skip on dedicated servers
	-- if g_dedicatedServerInfo ~= nil then
	-- 	return
	-- end

	local fileName = StorageLimit.confDirectory .. StorageLimit.modName .. ".xml"
	local key = "StorageLimit";
	if fileExists(fileName) then
		-- load existing XML file
		local xmlFile = loadXMLFile(key, fileName, key)

		local XMLFileVersion = getXMLString(xmlFile, key.."#XMLFileVersion")
		if XMLFileVersion == "1.0" then

			local settingKey = string.format("%s.Settings", key)
			StorageLimit.maxStoredFillTypesDefault = Utils.getNoNil(getXMLInt(xmlFile, settingKey..".maxStoredFillTypesDefault"), StorageLimit.maxStoredFillTypesDefault)
			StorageLimit.maxStoredFillTypesExtensionDefault = Utils.getNoNil(getXMLInt(xmlFile, settingKey..".maxStoredFillTypesExtensionDefault"), StorageLimit.maxStoredFillTypesExtensionDefault)

			local i = 0
			while true do
				local posKey = string.format("%s.StorageStations.StationName(%d)", key, i)
				if hasXMLProperty(xmlFile, posKey) then
					local stationName = getXMLString(xmlFile, posKey.."#stationName")
					local maxStoredFillTypes= getXMLInt(xmlFile, posKey.."#maxStoredFillTypes")
					StorageLimit.knownStorageStations[stationName] = maxStoredFillTypes
					i = i + 1
				else
					break
				end
			end
		end
	end
end


function StorageLimit:getStationItentifier(station)
	-- dbPrintf("StorageLimit:getStationItentifier")
    -- local placeableTitle = station.owningPlaceable:getName()

    local placeableCustomEnvironment = station.owningPlaceable.customEnvironment
	local baseDirectory = station.owningPlaceable.baseDirectory
	local configFileName = station.owningPlaceable.configFileName
	local relativeConfigFileName = configFileName
	if baseDirectory ~= "" then
		relativeConfigFileName = string.sub(configFileName, string.len(baseDirectory))
	end
	if placeableCustomEnvironment ~= nil then
		relativeConfigFileName = placeableCustomEnvironment .. relativeConfigFileName
	end
    return relativeConfigFileName
end


function StorageLimit:init()
	local fileName = StorageLimit.confDirectory .. StorageLimit.modName .. ".xml"
	if not fileExists(fileName) then
		StorageLimit:writeConfig()
	end
end

-- station.owningPlaceable.baseDirectory
-- station.owningPlaceable.configFileName
-- station.owningPlaceable.customEnvironment
-- C:/Users/Dirk/Documents/My Games/FarmingSimulator2022/pdlc/premiumExpansion/
-- C:/Users/Dirk/Documents/My Games/FarmingSimulator2022/pdlc/premiumExpansion/placeables/sellingPoints/railroadStorageSilo01/railroadStorageSilo01.xml
-- pdlc_premiumExpansion


-- function StorageLimit:onLoad(savegame)end;
-- function StorageLimit:onUpdate(dt)end;
-- function StorageLimit:deleteMap()end;
-- function StorageLimit:keyEvent(unicode, sym, modifier, isDown)end;
-- function StorageLimit:mouseEvent(posX, posY, isDown, isUp, button)end;

StorageLimit:init()


