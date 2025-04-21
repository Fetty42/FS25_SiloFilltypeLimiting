-- Author: Fetty42
-- Date: 21.04.2025
-- Version: 1.0.1.0

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

SiloFilltypeLimiting.settings = {}

SiloFilltypeLimiting.timeOfLastNotification = {}
SiloFilltypeLimiting.knownStorageStations = {}	-- StationName = maxStoredFillTypes
SiloFilltypeLimiting.initDone = false
SiloFilltypeLimiting.isInitSettingUI = false


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

	InGameMenu.onMenuOpened = Utils.appendedFunction(InGameMenu.onMenuOpened, SiloFilltypeLimiting.initSettingUI)
	FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, SiloFilltypeLimiting.saveSettings)

	SiloFilltypeLimiting:loadSettings()
end


function SiloFilltypeLimiting:defaultSettings()
	dbPrintHeader("SiloFilltypeLimiting:defSettings")

	SiloFilltypeLimiting.settings.maxNoParallelFillTypesPerSilo = 4
	SiloFilltypeLimiting.settings.additionalNoParallelFillTypesPerSiloExtension = 2
end


function SiloFilltypeLimiting:saveSettings()
	dbPrintHeader("SiloFilltypeLimiting:saveSettings")

	local modSettingsDir = getUserProfileAppPath() .. "modSettings"
	local fileName = "SiloFilltypeLimiting.xml"
	local createXmlFile = modSettingsDir .. "/" .. fileName

	local xmlFile = createXMLFile("SiloFilltypeLimiting", createXmlFile, "SiloFilltypeLimiting")
	setXMLInt(xmlFile, "SiloFilltypeLimiting.settings#maxNoParallelFillTypesPerSilo",SiloFilltypeLimiting.settings.maxNoParallelFillTypesPerSilo)
	setXMLInt(xmlFile, "SiloFilltypeLimiting.settings#additionalNoParallelFillTypesPerSiloExtension",SiloFilltypeLimiting.settings.additionalNoParallelFillTypesPerSiloExtension)
	
	saveXMLFile(xmlFile)
	delete(xmlFile)
end


function SiloFilltypeLimiting:loadSettings()
	dbPrintHeader("SiloFilltypeLimiting:loadSettings")
	
	local modSettingsDir = getUserProfileAppPath() .. "modSettings"
	local fileName = "SiloFilltypeLimiting.xml"
	local fileNamePath = modSettingsDir .. "/" .. fileName
	
	if fileExists(fileNamePath) then
		local xmlFile = loadXMLFile("SiloFilltypeLimiting", fileNamePath)
		
		if xmlFile == 0 then
			dbPrintf("  Could not read the data from XML file (%s), maybe the XML file is empty or corrupted, using the default!", fileNamePath)
			SiloFilltypeLimiting:defaultSettings()
			return
		end

		local maxNoParallelFillTypesPerSilo = getXMLInt(xmlFile, "SiloFilltypeLimiting.settings#maxNoParallelFillTypesPerSilo")
		if maxNoParallelFillTypesPerSilo == nil or maxNoParallelFillTypesPerSilo == 0 then
			dbPrintf("  Could not parse the correct 'maxNoParallelFillTypesPerSilo' value from the XML file, maybe it is corrupted, using the default!")
			maxNoParallelFillTypesPerSilo = 4
		end
		SiloFilltypeLimiting.settings.maxNoParallelFillTypesPerSilo = maxNoParallelFillTypesPerSilo
		
		local additionalNoParallelFillTypesPerSiloExtension = getXMLInt(xmlFile, "SiloFilltypeLimiting.settings#additionalNoParallelFillTypesPerSiloExtension")
		if additionalNoParallelFillTypesPerSiloExtension == nil then
			dbPrintf("  Could not parse the correct 'additionalNoParallelFillTypesPerSiloExtension' value from the XML file, maybe it is corrupted, using the default!")
			additionalNoParallelFillTypesPerSiloExtension = 2
		end
		SiloFilltypeLimiting.settings.additionalNoParallelFillTypesPerSiloExtension = additionalNoParallelFillTypesPerSiloExtension

		delete(xmlFile)
	else
		SiloFilltypeLimiting:defaultSettings()
		dbPrintf("  NOT any File founded!, using the default settings.")
	end
end


function SiloFilltypeLimiting:initSettingUI()
	if not SiloFilltypeLimiting.isInitSettingUI then
		local uiSettings = SiloFilltypeLimitingUISettings.new(SiloFilltypeLimiting.settings,true)
		uiSettings:registerSettings()
		SiloFilltypeLimiting.isInitSettingUI = true
	end
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
		local stationIdentifier = SiloFilltypeLimiting:getStationIdentifier(station)
		dbPrintf("  - Station: Name=%s | typeName=%s | categoryName=%s | isSellingPoint=%s | hasStoragePerFarm=%s | ownerFarmId=%s",
		stationIdentifier, tostring(placeable.typeName), tostring(placeable.storeItem.categoryName), tostring(station.isSellingPoint), station.hasStoragePerFarm, placeable.ownerFarmId)

		if SiloFilltypeLimiting:isStationRelevant(station) then
			dbPrintf("    --> is relevant StorageStation")

			if SiloFilltypeLimiting.knownStorageStations[stationIdentifier] == nil then
				dbPrintf("SiloFilltypeLimiting: New undefined storage station '%s'. Set max storage slots to %s (default)", stationIdentifier, SiloFilltypeLimiting.settings.maxNoParallelFillTypesPerSilo)
				SiloFilltypeLimiting.knownStorageStations[stationIdentifier] = -1
			end
		end
	end

	-- Try to get more information for the owned storage extensions (e.g. mod name)
	-- dbPrintf("")
	-- dbPrintf("  Try to get more information for the owned storage extensions (e.g. mod name)")
	-- for _, station in pairs(g_currentMission.storageSystem.storageExtensions) do
    --     dbPrintf("    storageSystem.storageExtensions: id=%s | capacity=%s", station.id, station.capacity)
	-- end
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


function SiloFilltypeLimiting:isStationRelevant(station, farmId)	-- farmId == nil --> all station, independent of farmId
	-- dbPrintHeader("SiloFilltypeLimiting:isStationRelevant()");
	local placeable = station.owningPlaceable
	
	-- dbPrintf("  - Station: getName=%s | typeName=%s | categoryName=%s | isSellingPoint=%s | hasStoragePerFarm=%s | ownerFarmId=%s",
	-- placeable:getName(), tostring(placeable.typeName), tostring(placeable.storeItem.categoryName), tostring(station.isSellingPoint), station.hasStoragePerFarm, placeable.ownerFarmId)

	if ((station.isSellingPoint == nil or station.isSellingPoint == false) and (farmId == nil or placeable.ownerFarmId == farmId)) then
        if ((placeable.storeItem.categoryName == "SILOS" or placeable.storeItem.categoryName == "STORAGES") and placeable.typeName == "silo") or placeable.spec_silo ~= nil then
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

	local maxStoredFillTypes = SiloFilltypeLimiting.settings.maxNoParallelFillTypesPerSilo
	local stationIdentifier = SiloFilltypeLimiting:getStationIdentifier(station)


	if SiloFilltypeLimiting.knownStorageStations[stationIdentifier] == nil then
		dbPrintf("SiloFilltypeLimiting: New undefined storage station '%s'. Set max storage slots to %s (default)", stationIdentifier, SiloFilltypeLimiting.settings.maxNoParallelFillTypesPerSilo)
		SiloFilltypeLimiting.knownStorageStations[stationIdentifier] = -1
	else		
		maxStoredFillTypes = SiloFilltypeLimiting.knownStorageStations[stationIdentifier]
		if maxStoredFillTypes == -1 then
			maxStoredFillTypes = SiloFilltypeLimiting.settings.maxNoParallelFillTypesPerSilo
			if withOutput then
				dbPrintf("SiloFilltypeLimiting: Undefined storage station '%s'. Set max storage slots to %s (default)", stationIdentifier, SiloFilltypeLimiting.settings.maxNoParallelFillTypesPerSilo)
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
				dbPrintf("  Target-Storage: id=%s | capacity=%s", targetStorage.id, targetStorage.capacity)
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

    local maxStoredFillTypesOverAll = maxStoredFillTypes + (countTargetStorages-1) * SiloFilltypeLimiting.settings.additionalNoParallelFillTypesPerSiloExtension
	local isFilltypeAlreadyInUse = station:getFillLevel(fillTypeIndex, farmId) > 0.1

	local notificationText = "";
	local callSuperFunction = true
	local isNotAllowed = false
	if isFilltypeAlreadyInUse  then
		-- The storage space for this fill type is already in use
		if countStoredFillTypes <= maxStoredFillTypesOverAll then
			if withOutput then
				dbPrintf("  The filltype is already in use --> Unloading is allowed. Storage slots in use %s/%s", countStoredFillTypes, maxStoredFillTypesOverAll)
				notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_ExistingFilltype"), countStoredFillTypes, maxStoredFillTypesOverAll)
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
		g_currentMission:addIngameNotification(callSuperFunction and FSBaseMission.INGAME_NOTIFICATION_OK or FSBaseMission.INGAME_NOTIFICATION_CRITICAL, notificationText)
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


function SiloFilltypeLimiting:getStationIdentifier(station)
	-- dbPrintHeader("SiloFilltypeLimiting:getStationIdentifier")
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


-- function SiloFilltypeLimiting:onLoad(savegame)end;
-- function SiloFilltypeLimiting:onUpdate(dt)end;
-- function SiloFilltypeLimiting:deleteMap()end;
-- function SiloFilltypeLimiting:keyEvent(unicode, sym, modifier, isDown)end;
-- function SiloFilltypeLimiting:mouseEvent(posX, posY, isDown, isUp, button)end;


