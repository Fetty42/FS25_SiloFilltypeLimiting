-- Author: Fetty42
-- Date: 29.01.2025
-- Version: 1.0.0.0

local dbPrintfOn = false
local dbInfoPrintfOn = false

local function dbInfoPrintf(...)
	if dbInfoPrintfOn then
    	print(string.format(...))
	end
end

local function dbPrintf(...)
	if dbPrintfOn then
    	print(string.format(...))
	end
end

local function dbPrint(...)
	if dbPrintfOn then
    	print(...)
	end
end

local function dbPrintHeader(funcName)
	if dbPrintfOn then
		if g_currentMission ~=nil and g_currentMission.missionDynamicInfo ~=nil then
			print(string.format("Call %s: isDedicatedServer=%s | isServer()=%s | isMasterUser=%s | isMultiplayer=%s | isClient()=%s | farmId=%s", 
							funcName, tostring(g_dedicatedServer~=nil), tostring(g_currentMission:getIsServer()), tostring(g_currentMission.isMasterUser), tostring(g_currentMission.missionDynamicInfo.isMultiplayer), tostring(g_currentMission:getIsClient()), tostring(g_currentMission:getFarmId())))
		else
			print(string.format("Call %s: isDedicatedServer=%s | g_currentMission=%s",
							funcName, tostring(g_dedicatedServer~=nil), tostring(g_currentMission)))
		end
	end
end

-- **************************************************

SiloFilltypeLimiting = {}; -- Class

SiloFilltypeLimiting.timeOfLastNotification = {}
SiloFilltypeLimiting.maxStoredFillTypesDefault = 4
SiloFilltypeLimiting.maxStoredFillTypesExtensionDefault = 2
SiloFilltypeLimiting.knownStorageStations = {}	-- StationName = maxStoredFillTypes
SiloFilltypeLimiting.initDone = false

SiloFilltypeLimiting.directory = g_currentModDirectory
SiloFilltypeLimiting.modName = g_currentModName
SiloFilltypeLimiting.confDirectory = getUserProfileAppPath().. "modSettings/"


addModEventListener(SiloFilltypeLimiting)

function SiloFilltypeLimiting:loadMap(name)
	dbPrintHeader("SiloFilltypeLimiting:loadMap");
	-- if g_currentMission:getIsClient() then
	-- 	SiloFilltypeLimiting:readConfig();
	-- end
	UnloadingStation.getFreeCapacity = Utils.overwrittenFunction(UnloadingStation.getFreeCapacity, SiloFilltypeLimiting.unloadingStation_getFreeCapacity)

	-- Save Configuration when saving savegame
	-- FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, SiloFilltypeLimiting.writeConfig)

	--load settings:
	-- SiloFilltypeLimiting:readConfig();
end


-- function SiloFilltypeLimiting:postLoadMap()
-- 	dbPrintHeader("SiloFilltypeLimiting:postLoadMap");
-- 	-- SiloFilltypeLimiting:getAllStorageStations()
-- end;
-- FSBaseMission.onFinishedLoading = Utils.appendedFunction(FSBaseMission.onFinishedLoading, SiloFilltypeLimiting.postLoadMap);


function SiloFilltypeLimiting:update(dt)
	-- dbPrintHeader("SiloFilltypeLimiting:update")
	if not SiloFilltypeLimiting.initDone then
		SiloFilltypeLimiting.initDone = true
		SiloFilltypeLimiting:getAllStorageStations()
	end
end


function SiloFilltypeLimiting:getAllStorageStations()
	dbPrintHeader("SiloFilltypeLimiting:getAllStorageStations()");

	for _, station in pairs(g_currentMission.storageSystem.unloadingStations) do
	
		local placeable = station.owningPlaceable
		local stationItentifier = SiloFilltypeLimiting:getStationItentifier(station)
		dbPrintf("  - Station: Name=%s | typeName=%s | categoryName=%s | isSellingPoint=%s | hasStoragePerFarm=%s | ownerFarmId=%s",
		stationItentifier, tostring(placeable.typeName), tostring(placeable.storeItem.categoryName), tostring(station.isSellingPoint), station.hasStoragePerFarm, placeable.ownerFarmId)

		if SiloFilltypeLimiting:isStationRelevant(station) then
			dbPrintf("    --> is relevant StorageStation")

			if SiloFilltypeLimiting.knownStorageStations[stationItentifier] == nil then
				dbPrintf("SiloFilltypeLimiting: New undefined storage station '%s'. Set max storage slots to %s (default)", stationItentifier, SiloFilltypeLimiting.maxStoredFillTypesDefault)
				SiloFilltypeLimiting.knownStorageStations[stationItentifier] = -1
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


function SiloFilltypeLimiting:isStationRelevant(station, farmId)	-- farmId == nil --> all station, undependent of farmId
	-- dbPrintHeader("SiloFilltypeLimiting:isStationRelevant()");
	local placeable = station.owningPlaceable
	
	-- dbPrintf("  - Station: getName=%s | typeName=%s | categoryName=%s | isSellingPoint=%s | hasStoragePerFarm=%s | ownerFarmId=%s",
	-- placeable:getName(), tostring(placeable.typeName), tostring(placeable.storeItem.categoryName), tostring(station.isSellingPoint), station.hasStoragePerFarm, placeable.ownerFarmId)

	-- ~= PRODUCTIONPOINTS, ANIMALPENS
	-- == SILOS
	-- getName=Railroad Silo North | typeName=silo | categoryName=PLACEABLEMISC | isSellingPoint=nil | hasStoragePerFarm=true | ownerFarmId=0
	-- getName=Farma 400 + Obi 1000 | typeName=silo | categoryName=SILOS | isSellingPoint=nil | hasStoragePerFarm=false | ownerFarmId=1			--> is own relevant StorageStation
	-- getName=Medium Petrol Tank | typeName=silo | categoryName=DIESELTANKS | isSellingPoint=nil | hasStoragePerFarm=false | ownerFarmId=1 	--> is own relevant StorageStation
	-- getName=Liquidmanure Tank | typeName=silo | categoryName=SILOS | isSellingPoint=nil | hasStoragePerFarm=false | ownerFarmId=1 			--> is own relevant StorageStation

	if ((station.isSellingPoint == nil or station.isSellingPoint == false) and (farmId == nil or placeable.ownerFarmId == farmId)) then
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
		return true
	end
	return false
end


function SiloFilltypeLimiting.unloadingStation_getFreeCapacity(station, superFunc, fillTypeIndex, farmId)
	dbPrintHeader("SiloFilltypeLimiting:unloadingStation_getFreeCapacity")
	dbPrintf("call SiloFilltypeLimiting:unloadingStation_getFreeCapacity: station=%s | fillTypeIndex=%s | farmId=%s", station, fillTypeIndex, farmId)

	-- don't handle
	if not SiloFilltypeLimiting:isStationRelevant(station, farmId) or fillTypeIndex == nil or farmId == nil then
		dbPrintf("Start: call superFunc")
		return superFunc(station, fillTypeIndex, farmId)
	end

	-- info output, but not every call --> todo: much to complex :)
	local withOutput = false
	if SiloFilltypeLimiting.timeOfLastNotification[farmId] == nil
	or SiloFilltypeLimiting.timeOfLastNotification[farmId][station] == nil
	or SiloFilltypeLimiting.timeOfLastNotification[farmId][station][fillTypeIndex] == nil
	or g_currentMission.environment.dayTime/(1000*60) > SiloFilltypeLimiting.timeOfLastNotification[farmId][station][fillTypeIndex] + 6
	or g_currentMission.environment.dayTime/(1000*60) < SiloFilltypeLimiting.timeOfLastNotification[farmId][station][fillTypeIndex]
	then
		-- dbPrintf(string.format("  dayTime=%s", tostring(g_currentMission.environment.dayTime/(1000*60))))
		if SiloFilltypeLimiting.timeOfLastNotification[farmId] == nil then
			SiloFilltypeLimiting.timeOfLastNotification[farmId] = {}
		end
		if SiloFilltypeLimiting.timeOfLastNotification[farmId][station] == nil then
			SiloFilltypeLimiting.timeOfLastNotification[farmId][station] = {}
		end
		SiloFilltypeLimiting.timeOfLastNotification[farmId][station][fillTypeIndex] = g_currentMission.environment.dayTime/(1000*60)
		-- dbPrintf(tostring(SiloFilltypeLimiting.timeOfLastNotification[farmId][station][fillTypeIndex]))
		withOutput = true
	end

	if withOutput then
		local fillTypeName = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex).name
		dbPrintf("call2 SiloFilltypeLimiting.unloadingStation_getFreeCapacity: station=%s | fillTypeIndex=%s | fillTypeName=%s | farmId=%s",
			tostring(station), tostring(fillTypeIndex), tostring(fillTypeName), tostring(farmId))
		dbPrintf("  Station: getName=%s | typeName=%s | categoryName=%s", station.owningPlaceable:getName(), station.owningPlaceable.typeName, station.owningPlaceable.storeItem.categoryName)
	end

	local maxStoredFillTypes = SiloFilltypeLimiting.maxStoredFillTypesDefault
	local stationIdentifier = SiloFilltypeLimiting:getStationItentifier(station)


	if SiloFilltypeLimiting.knownStorageStations[stationIdentifier] == nil then
		dbPrintf("SiloFilltypeLimiting: New undefined storage station '%s'. Set max storage slots to %s (default)", stationIdentifier, SiloFilltypeLimiting.maxStoredFillTypesDefault)
		SiloFilltypeLimiting.knownStorageStations[stationIdentifier] = -1
	else		
		maxStoredFillTypes = SiloFilltypeLimiting.knownStorageStations[stationIdentifier]
		if maxStoredFillTypes == -1 then
			maxStoredFillTypes = SiloFilltypeLimiting.maxStoredFillTypesDefault
			if withOutput then
				dbPrintf("SiloFilltypeLimiting: Undefined storage station '%s'. Set max storage slots to %s (default)", stationIdentifier, SiloFilltypeLimiting.maxStoredFillTypesDefault)
			end
		else
			if withOutput then
				dbPrintf("SiloFilltypeLimiting: Already known storage station '%s' with %s storage slots", stationIdentifier, maxStoredFillTypes)
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

    local maxStoredFillTypesOverAll = maxStoredFillTypes + (countTargetStorages-1) * SiloFilltypeLimiting.maxStoredFillTypesExtensionDefault
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
			dbPrintf(notificationText)
			callSuperFunction = false
		end
	elseif countStoredFillTypes < maxStoredFillTypesOverAll then
		if withOutput then
			dbPrintf("  New filltype and still free storage slots --> Unloading is allowed. Storage slots in use %s/%s", countStoredFillTypes, maxStoredFillTypesOverAll)
			notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_NewFilltype"), countStoredFillTypes, maxStoredFillTypesOverAll)
		end
	else
		notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_UnloadingNotAllowed"), countStoredFillTypes, maxStoredFillTypesOverAll)
		dbPrintf(notificationText)
		callSuperFunction = false
	end

	-- info output, but not every call
	if withOutput and  notificationText ~= "" then
		dbPrintf("  SiloFilltypeLimiting: countTargetStorages=%s | maxStoredFillTypesOverAll=%s | Msg=%s", countTargetStorages, maxStoredFillTypesOverAll, notificationText)
		g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, notificationText)
		-- g_currentMission.hud:addSideNotification(FSBaseMission.INGAME_NOTIFICATION_OK, notificationText, 3000);
		if not callSuperFunction then
			g_currentMission:showBlinkingWarning(notificationText, 8000)
		end
	end
	
	if callSuperFunction then
		dbPrintf("End: call superFunc")
		return superFunc(station, fillTypeIndex, farmId)
	else
    	return 0
	end
end


-- function SiloFilltypeLimiting:saveSavegame()
-- 	dbPrintHeader("SiloFilltypeLimiting:saveSavegame")

-- 	SiloFilltypeLimiting:writeConfig();
-- end;


-- function SiloFilltypeLimiting:writeConfig()
-- 	dbPrintHeader("SiloFilltypeLimiting:writeConfig")

-- 	-- skip on dedicated servers
-- 	if g_dedicatedServerInfo ~= nil then
-- 		return
-- 	end
	
-- 	createFolder(SiloFilltypeLimiting.confDirectory);

-- 	local fileName = SiloFilltypeLimiting.confDirectory .. SiloFilltypeLimiting.modName .. ".xml"
-- 	local key = "SiloFilltypeLimiting";
-- 	local xmlFile = createXMLFile(key, fileName, key);		

-- 	if xmlFile > 0 then
-- 		setXMLString(xmlFile, key.."#XMLFileVersion", "1.0");

-- 		local settingKey = string.format("%s.Settings", key)
-- 		setXMLInt(xmlFile, settingKey..".maxStoredFillTypesDefault", SiloFilltypeLimiting.maxStoredFillTypesDefault)
-- 		setXMLInt(xmlFile, settingKey..".maxStoredFillTypesExtensionDefault", SiloFilltypeLimiting.maxStoredFillTypesExtensionDefault)

-- 		local i = 0
-- 		for stationName, maxStoredFillTypes in pairs(SiloFilltypeLimiting.knownStorageStations) do
-- 			local posKey = string.format("%s.StorageStations.StationName(%d)", key, i)
-- 			setXMLString(xmlFile, posKey.."#stationName", stationName)
-- 			setXMLInt(xmlFile, posKey.."#maxStoredFillTypes", maxStoredFillTypes)
-- 			i = i + 1
-- 		end

-- 		saveXMLFile(xmlFile)
-- 		delete(xmlFile)
-- 	end
-- end


-- function SiloFilltypeLimiting:readConfig()
-- 	dbPrintHeader("SiloFilltypeLimiting:readConfig")

-- 	-- skip on dedicated servers
-- 	-- if g_dedicatedServerInfo ~= nil then
-- 	-- 	return
-- 	-- end

-- 	local fileName = SiloFilltypeLimiting.confDirectory .. SiloFilltypeLimiting.modName .. ".xml"
-- 	local key = "SiloFilltypeLimiting";
-- 	if fileExists(fileName) then
-- 		-- load existing XML file
-- 		local xmlFile = loadXMLFile(key, fileName, key)

-- 		local XMLFileVersion = getXMLString(xmlFile, key.."#XMLFileVersion")
-- 		if XMLFileVersion == "1.0" then

-- 			local settingKey = string.format("%s.Settings", key)
-- 			SiloFilltypeLimiting.maxStoredFillTypesDefault = Utils.getNoNil(getXMLInt(xmlFile, settingKey..".maxStoredFillTypesDefault"), SiloFilltypeLimiting.maxStoredFillTypesDefault)
-- 			SiloFilltypeLimiting.maxStoredFillTypesExtensionDefault = Utils.getNoNil(getXMLInt(xmlFile, settingKey..".maxStoredFillTypesExtensionDefault"), SiloFilltypeLimiting.maxStoredFillTypesExtensionDefault)

-- 			local i = 0
-- 			while true do
-- 				local posKey = string.format("%s.StorageStations.StationName(%d)", key, i)
-- 				if hasXMLProperty(xmlFile, posKey) then
-- 					local stationName = getXMLString(xmlFile, posKey.."#stationName")
-- 					local maxStoredFillTypes= getXMLInt(xmlFile, posKey.."#maxStoredFillTypes")
-- 					SiloFilltypeLimiting.knownStorageStations[stationName] = maxStoredFillTypes
-- 					i = i + 1
-- 				else
-- 					break
-- 				end
-- 			end
-- 		end
-- 	end
-- end


function SiloFilltypeLimiting:getStationItentifier(station)
	-- dbPrintHeader("SiloFilltypeLimiting:getStationItentifier")
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


-- function SiloFilltypeLimiting:init()
-- 	dbPrintHeader("SiloFilltypeLimiting:init")
-- 	local fileName = SiloFilltypeLimiting.confDirectory .. SiloFilltypeLimiting.modName .. ".xml"
-- 	if not fileExists(fileName) then
-- 		SiloFilltypeLimiting:writeConfig()
-- 	end
-- end

-- station.owningPlaceable.baseDirectory
-- station.owningPlaceable.configFileName
-- station.owningPlaceable.customEnvironment
-- C:/Users/Dirk/Documents/My Games/FarmingSimulator2022/pdlc/premiumExpansion/
-- C:/Users/Dirk/Documents/My Games/FarmingSimulator2022/pdlc/premiumExpansion/placeables/sellingPoints/railroadStorageSilo01/railroadStorageSilo01.xml
-- pdlc_premiumExpansion


-- function SiloFilltypeLimiting:onLoad(savegame)end;
-- function SiloFilltypeLimiting:onUpdate(dt)end;
-- function SiloFilltypeLimiting:deleteMap()end;
-- function SiloFilltypeLimiting:keyEvent(unicode, sym, modifier, isDown)end;
-- function SiloFilltypeLimiting:mouseEvent(posX, posY, isDown, isUp, button)end;

-- SiloFilltypeLimiting:init()


