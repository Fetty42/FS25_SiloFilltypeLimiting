-- Author: Fetty42
-- Date: 21.04.2025
-- Version: 1.0.1.0

local dbPrintfOn = true
local dbInfoPrintfOn = true

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
SiloFilltypeLimiting.knownSiloExtensions = {}		-- extension placeable identifier = additional fill types
SiloFilltypeLimiting.extensionStorageToIdentifier = {}	-- Storage -> extension placeable identifier
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

	SiloFilltypeLimiting.settings.maxNumParallelFillTypesPerSilo = 3
	SiloFilltypeLimiting.settings.additionalNumParallelFillTypesPerSiloExtension = 1
	SiloFilltypeLimiting.settings.useConfiguredSettingsPerSilo = false
end


function SiloFilltypeLimiting:saveSettings()
	dbPrintHeader("SiloFilltypeLimiting:saveSettings")

	SiloFilltypeLimiting:getAllStorageStations()
	SiloFilltypeLimiting:getAllSiloExtensions()

	local modSettingsDir = getUserProfileAppPath() .. "modSettings"
	if not fileExists(modSettingsDir) then
		createFolder(modSettingsDir)
	end
	local fileName = "SiloFilltypeLimiting.xml"
	local createXmlFile = modSettingsDir .. "/" .. fileName
	local key = "SiloFilltypeLimiting";

	local xmlFile = createXMLFile(key, createXmlFile, key)

	if xmlFile > 0 then
		setXMLInt(xmlFile, key.."#version", 2)
		setXMLInt(xmlFile, key..".settings#maxNumParallelFillTypesPerSilo",SiloFilltypeLimiting.settings.maxNumParallelFillTypesPerSilo)
		setXMLInt(xmlFile, key..".settings#additionalNumParallelFillTypesPerSiloExtension",SiloFilltypeLimiting.settings.additionalNumParallelFillTypesPerSiloExtension)
	setXMLBool(xmlFile, key..".settings#useConfiguredSettingsPerSilo",SiloFilltypeLimiting.settings.useConfiguredSettingsPerSilo)
	
		local i = 0
		for identifier, maxNumParallelFillTypesPerSilo in pairs(SiloFilltypeLimiting.knownStorageStations) do
			local posKey = string.format("%s.knownStorageStations(%d)", key, i)
			setXMLString(xmlFile, posKey.."#identifier", identifier)
			setXMLInt(xmlFile, posKey.."#maxNumParallelFillTypesPerSilo", maxNumParallelFillTypesPerSilo)
			i = i + 1
		end

		i = 0
		for identifier, additionalNumParallelFillTypesPerSiloExtension in pairs(SiloFilltypeLimiting.knownSiloExtensions) do
			local posKey = string.format("%s.knownSiloExtensions(%d)", key, i)
			setXMLString(xmlFile, posKey.."#identifier", identifier)
			setXMLInt(xmlFile, posKey.."#additionalNumParallelFillTypesPerSiloExtension", additionalNumParallelFillTypesPerSiloExtension)
			i = i + 1
		end

	saveXMLFile(xmlFile)
	delete(xmlFile)
	end
end


function SiloFilltypeLimiting:loadSettings()
	dbPrintHeader("SiloFilltypeLimiting:loadSettings")
	
	local key = "SiloFilltypeLimiting"
	local fileName = "SiloFilltypeLimiting.xml"
	local modDefaultsPath = Utils.getFilename(fileName, SiloFilltypeLimiting.directory)
	local modSettingsPath = getUserProfileAppPath() .. "modSettings/" .. fileName
	
	SiloFilltypeLimiting:defaultSettings()
	SiloFilltypeLimiting.knownStorageStations = {}
	SiloFilltypeLimiting.knownSiloExtensions = {}
	SiloFilltypeLimiting.extensionStorageToIdentifier = {}
		
	local function loadFromXmlFile(filePath, sourceName)
		if not fileExists(filePath) then
			return false
		end

		local xmlFile = loadXMLFile(key, filePath)
		if xmlFile == 0 then
			dbPrintf("  Could not read %s XML file (%s), using current settings.", sourceName, filePath)
			return false
		end

		local xmlVersion = getXMLInt(xmlFile, key.."#version") or 1

		local maxNumParallelFillTypesPerSilo = xmlVersion >= 2
			and getXMLInt(xmlFile, key..".settings#maxNumParallelFillTypesPerSilo")
			or  getXMLInt(xmlFile, key..".settings#maxNoParallelFillTypesPerSilo")
		if maxNumParallelFillTypesPerSilo ~= nil and maxNumParallelFillTypesPerSilo > 0 then
			SiloFilltypeLimiting.settings.maxNumParallelFillTypesPerSilo = maxNumParallelFillTypesPerSilo
		else
			dbPrintf("  Could not parse 'maxNumParallelFillTypesPerSilo' from %s XML (%s), using current value.", sourceName, filePath)
		end
		
		local additionalNumParallelFillTypesPerSiloExtension = xmlVersion >= 2
			and getXMLInt(xmlFile, key..".settings#additionalNumParallelFillTypesPerSiloExtension")
			or  getXMLInt(xmlFile, key..".settings#additionalNoParallelFillTypesPerSiloExtension")
		if additionalNumParallelFillTypesPerSiloExtension ~= nil then
			SiloFilltypeLimiting.settings.additionalNumParallelFillTypesPerSiloExtension = additionalNumParallelFillTypesPerSiloExtension
		else
			dbPrintf("  Could not parse 'additionalNumParallelFillTypesPerSiloExtension' from %s XML (%s), using current value.", sourceName, filePath)
		end

		local useConfiguredSettingsPerSilo = getXMLBool(xmlFile, key..".settings#useConfiguredSettingsPerSilo")
		if useConfiguredSettingsPerSilo ~= nil then
			SiloFilltypeLimiting.settings.useConfiguredSettingsPerSilo = useConfiguredSettingsPerSilo
		else
			dbPrintf("  Could not parse 'useConfiguredSettingsPerSilo' from %s XML (%s), using current value.", sourceName, filePath)
		end

		local i = 0
		while true do
			local posKey = string.format("%s.knownStorageStations(%d)", key, i)
			if not hasXMLProperty(xmlFile, posKey) then
				break
			end

			local maxNumParallelFillTypesPerSiloForStation = xmlVersion >= 2
				and getXMLInt(xmlFile, posKey.."#maxNumParallelFillTypesPerSilo")
				or  getXMLInt(xmlFile, posKey.."#maxNoParallelFillTypesPerSilo")
			local identifier = getXMLString(xmlFile, posKey.."#identifier")

			if identifier ~= nil and identifier ~= "" and maxNumParallelFillTypesPerSiloForStation ~= nil then
				-- Merge by identifier. Later file reads override previous values.
				SiloFilltypeLimiting.knownStorageStations[identifier] = maxNumParallelFillTypesPerSiloForStation
			end

			i = i + 1
		end

		i = 0
		while true do
			local posKey = string.format("%s.knownSiloExtensions(%d)", key, i)
			if not hasXMLProperty(xmlFile, posKey) then
				break
			end

			local additionalNumParallelFillTypesPerSiloExtension = xmlVersion >= 2
				and getXMLInt(xmlFile, posKey.."#additionalNumParallelFillTypesPerSiloExtension")
				or  getXMLInt(xmlFile, posKey.."#additionalNoParallelFillTypesPerSiloExtension")
			local identifier = getXMLString(xmlFile, posKey.."#identifier")

			if identifier ~= nil and identifier ~= "" and additionalNumParallelFillTypesPerSiloExtension ~= nil then
				SiloFilltypeLimiting.knownSiloExtensions[identifier] = additionalNumParallelFillTypesPerSiloExtension
			end

			i = i + 1
		end

		delete(xmlFile)
		return true
	end

	loadFromXmlFile(modDefaultsPath, "mod default")

	if not loadFromXmlFile(modSettingsPath, "modSettings") then
		dbPrintf("  No usable modSettings XML found (%s), using defaults from mod XML/code.", modSettingsPath)
	end
end


function SiloFilltypeLimiting:initSettingUI()
	if not SiloFilltypeLimiting.isInitSettingUI then
		local uiSettings = SiloFilltypeLimitingUISettings.new(SiloFilltypeLimiting.settings,true)
		-- uiSettings:registerSettings() will be called in the next line, but we need to register the UI before to avoid that the onFrameOpen event is triggered before the UI is registered which would lead to an error since the onFrameOpen event calls a method of the UI
		SiloFilltypeLimitingUISettings.registerSettings(uiSettings)
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
		SiloFilltypeLimiting:getAllSiloExtensions()
	end
end


function SiloFilltypeLimiting:getAllStorageStations()
	dbPrintHeader("SiloFilltypeLimiting:getAllStorageStations()");

	for _, station in pairs(g_currentMission.storageSystem.unloadingStations) do
	
		local placeable = station.owningPlaceable
		local stationIdentifier = SiloFilltypeLimiting:getStationIdentifier(station)
		local categoryName = placeable ~= nil and placeable.storeItem ~= nil and placeable.storeItem.categoryName or "n/a"
		dbPrintf("  - Station: Name=%s | typeName=%s | categoryName=%s | isSellingPoint=%s | hasStoragePerFarm=%s | ownerFarmId=%s",
		stationIdentifier, tostring(placeable ~= nil and placeable.typeName or "n/a"), tostring(categoryName), tostring(station.isSellingPoint), station.hasStoragePerFarm, placeable ~= nil and placeable.ownerFarmId or "n/a")

		if SiloFilltypeLimiting:isStationRelevant(station) then
			dbPrintf("    --> is relevant StorageStation")

			if SiloFilltypeLimiting.knownStorageStations[stationIdentifier] == nil then
			dbPrintf("SiloFilltypeLimiting: New undefined storage station '%s'. Set max storage slots to %s (default)", stationIdentifier, SiloFilltypeLimiting.settings.maxNumParallelFillTypesPerSilo)
				SiloFilltypeLimiting.knownStorageStations[stationIdentifier] = -1
			end
		end
	end
end


function SiloFilltypeLimiting:getAllSiloExtensions()
	dbPrintHeader("SiloFilltypeLimiting:getAllSiloExtensions()")

	SiloFilltypeLimiting.extensionStorageToIdentifier = {}

	local placeableSystem = g_currentMission ~= nil and g_currentMission.placeableSystem or nil
	if placeableSystem == nil or placeableSystem.placeables == nil then
		return
	end

	for _, placeable in ipairs(placeableSystem.placeables) do
		local spec = placeable.spec_siloExtension
		if spec ~= nil and spec.storage ~= nil then
			local extensionIdentifier = SiloFilltypeLimiting:getPlaceableIdentifier(placeable)
			SiloFilltypeLimiting.extensionStorageToIdentifier[spec.storage] = extensionIdentifier

			dbPrintf("  - SiloExtension: identifier=%s | typeName=%s",
				extensionIdentifier, tostring(placeable.typeName))

			if SiloFilltypeLimiting.knownSiloExtensions[extensionIdentifier] == nil then
				dbPrintf("SiloFilltypeLimiting: New undefined silo extension '%s'. Set additional fill types to default", extensionIdentifier)
				SiloFilltypeLimiting.knownSiloExtensions[extensionIdentifier] = -1
			end
		end
	end
end


function SiloFilltypeLimiting:getAdditionalFillTypesForExtensionStorage(targetStorage)
	local defaultAdditional = SiloFilltypeLimiting.settings.additionalNumParallelFillTypesPerSiloExtension
	local extensionIdentifier = SiloFilltypeLimiting.extensionStorageToIdentifier[targetStorage]

	if extensionIdentifier == nil then
		return defaultAdditional
	end

	if SiloFilltypeLimiting.knownSiloExtensions[extensionIdentifier] == nil then
		SiloFilltypeLimiting.knownSiloExtensions[extensionIdentifier] = -1
	end

	if not SiloFilltypeLimiting.settings.useConfiguredSettingsPerSilo then
		return defaultAdditional
	end

	local configuredAdditional = SiloFilltypeLimiting.knownSiloExtensions[extensionIdentifier]
	if configuredAdditional == -1 then
		return defaultAdditional
	end

	return configuredAdditional
end


function SiloFilltypeLimiting:isStationRelevant(station, farmId)	-- farmId == nil --> all station, independent of farmId
	-- dbPrintHeader("SiloFilltypeLimiting:isStationRelevant()");
	if station == nil then
		return false
	end

	local placeable = station.owningPlaceable
	if placeable == nil then
		return false
	end

	local storeItem = placeable.storeItem
	local categoryName = storeItem ~= nil and storeItem.categoryName or nil
	
	-- dbPrintf("  - Station: getName=%s | typeName=%s | categoryName=%s | isSellingPoint=%s | hasStoragePerFarm=%s | ownerFarmId=%s",
	-- placeable:getName(), tostring(placeable.typeName), tostring(categoryName), tostring(station.isSellingPoint), station.hasStoragePerFarm, placeable.ownerFarmId)

	if ((station.isSellingPoint == nil or station.isSellingPoint == false) and (farmId == nil or placeable.ownerFarmId == farmId)) then
		if ((categoryName == "SILOS" or categoryName == "STORAGES") and placeable.typeName == "silo") or placeable.spec_silo ~= nil then
			-- dbPrintf("    --> is own relevant StorageStation")
            return true
        end
	end
	
	if (station.isSellingPoint == nil or station.isSellingPoint == false) and categoryName == "PLACEABLEMISC" and station.hasStoragePerFarm then
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

	local maxStoredFillTypes = SiloFilltypeLimiting.settings.maxNumParallelFillTypesPerSilo
	local stationIdentifier = SiloFilltypeLimiting:getStationIdentifier(station)


	if SiloFilltypeLimiting.knownStorageStations[stationIdentifier] == nil then
		dbPrintf("SiloFilltypeLimiting: New undefined storage station '%s'. Set max storage slots to %s (default)", stationIdentifier, maxStoredFillTypes)
		SiloFilltypeLimiting.knownStorageStations[stationIdentifier] = -1
	elseif SiloFilltypeLimiting.settings.useConfiguredSettingsPerSilo and SiloFilltypeLimiting.knownStorageStations[stationIdentifier] ~= nil then
		if SiloFilltypeLimiting.knownStorageStations[stationIdentifier] == -1 then
			if withOutput then
				dbPrintf("SiloFilltypeLimiting: Undefined storage station '%s'. Set max storage slots to %s (default)", stationIdentifier, maxStoredFillTypes)
			end
		else
			maxStoredFillTypes = SiloFilltypeLimiting.knownStorageStations[stationIdentifier]
			if withOutput then
				dbPrintf("SiloFilltypeLimiting: Already known storage station '%s' with %s storage slots", stationIdentifier, maxStoredFillTypes)
			end
		end
	end

	-- Number of stored fill types
	local storedFillTypes = {}
	local numStoredFillTypes = 0
    local numTargetStorages = 0
	local extensionFillTypeBonus = 0
	local numIdentifiedExtensionStorages = 0
	for _, targetStorage in pairs(station.targetStorages) do
        if farmId == nil or station:hasFarmAccessToStorage(farmId, targetStorage) then
            numTargetStorages = numTargetStorages + 1

			local extensionIdentifier = SiloFilltypeLimiting.extensionStorageToIdentifier[targetStorage]
			if withOutput then
				dbPrintf("  Target-Storage: id=%s | capacity=%s | isExtension=%s | extensionIdentifier=%s",
					targetStorage.id, targetStorage.capacity, tostring(targetStorage.isExtension), tostring(extensionIdentifier))
			end

			if extensionIdentifier ~= nil then
				numIdentifiedExtensionStorages = numIdentifiedExtensionStorages + 1
				if SiloFilltypeLimiting.settings.useConfiguredSettingsPerSilo then
					extensionFillTypeBonus = extensionFillTypeBonus + SiloFilltypeLimiting:getAdditionalFillTypesForExtensionStorage(targetStorage)
				end
			end

			for fillTypeIndex1, _ in pairs(targetStorage.fillTypes) do
				local ftName = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex1).name
				if station:getFillLevel(fillTypeIndex1, farmId) > 0.1 and storedFillTypes[ftName] == nil then
					storedFillTypes[ftName] = true
					numStoredFillTypes = numStoredFillTypes + 1
					if withOutput then
						dbPrintf("  Storage-%s: ftName=%s(%s) | ftFillLevel=%s | numStoredFillTypes=%s", numTargetStorages, ftName, fillTypeIndex1, station:getFillLevel(fillTypeIndex1, farmId), numStoredFillTypes)
					end
				end
			end
		end
	end

	if SiloFilltypeLimiting.settings.useConfiguredSettingsPerSilo then
		-- Fallback for multi-compartment silos without separate extension placeables
		if numIdentifiedExtensionStorages == 0 and numTargetStorages > 1 then
			extensionFillTypeBonus = (numTargetStorages - 1) * SiloFilltypeLimiting.settings.additionalNumParallelFillTypesPerSiloExtension
		end
	else
		-- Original behaviour: one global bonus per extra storage slot (not per isExtension flag)
		if numTargetStorages > 1 then
			extensionFillTypeBonus = (numTargetStorages - 1) * SiloFilltypeLimiting.settings.additionalNumParallelFillTypesPerSiloExtension
		end
	end

    local maxStoredFillTypesOverAll = maxStoredFillTypes + extensionFillTypeBonus
	local isFilltypeAlreadyInUse = station:getFillLevel(fillTypeIndex, farmId) > 0.1

	local notificationText = "";
	local callSuperFunction = true
	local isNotAllowed = false
	if isFilltypeAlreadyInUse  then
		-- The storage space for this fill type is already in use
		if withOutput then
			dbPrintf("  The filltype is already in use --> Unloading is allowed. Storage slots in use %s/%s", numStoredFillTypes, maxStoredFillTypesOverAll)
			notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_ExistingFilltype"), numStoredFillTypes, maxStoredFillTypesOverAll)
		end
	elseif numStoredFillTypes < maxStoredFillTypesOverAll then
		if withOutput then
			dbPrintf("  New filltype and still free storage slots --> Unloading is allowed. Storage slots in use %s/%s", numStoredFillTypes, maxStoredFillTypesOverAll)
			notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_NewFilltype"), numStoredFillTypes, maxStoredFillTypesOverAll)
		end
	else
		notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_UnloadingNotAllowed"), numStoredFillTypes, maxStoredFillTypesOverAll)
		dbPrintf(notificationText)
		callSuperFunction = false
	end

	-- info output, but not every call
	if withOutput and  notificationText ~= "" then
		dbPrintf("  SiloFilltypeLimiting: numTargetStorages=%s | maxStoredFillTypesOverAll=%s | Msg=%s", numTargetStorages, maxStoredFillTypesOverAll, notificationText)
		g_currentMission:addIngameNotification(callSuperFunction and FSBaseMission.INGAME_NOTIFICATION_OK or FSBaseMission.INGAME_NOTIFICATION_CRITICAL, notificationText)
		if not callSuperFunction then
			g_currentMission:showBlinkingWarning(notificationText, 3000, "SiloFilltypeLimiting_UnloadingBlocked")
		end
	end
	
	if callSuperFunction then
		dbPrintf("End: call superFunc")
		return superFunc(station, fillTypeIndex, farmId)
	else
    	return 0
	end
end


function SiloFilltypeLimiting:getPlaceableIdentifier(placeable)
	if placeable == nil then return nil end

	local placeableCustomEnvironment = placeable.customEnvironment
	local baseDirectory = placeable.baseDirectory
	local configFileName = placeable.configFileName
	if configFileName == nil or configFileName == "" then
		return string.format("placeable:%s:%s", tostring(placeable.typeName), tostring(placeable.nodeId))
	end

	local relativeConfigFileName = configFileName
	if baseDirectory ~= nil and baseDirectory ~= "" and string.sub(configFileName, 1, string.len(baseDirectory)) == baseDirectory then
		relativeConfigFileName = string.sub(configFileName, string.len(baseDirectory) + 1)
	end
	if placeableCustomEnvironment ~= nil then
		relativeConfigFileName = placeableCustomEnvironment .. ":" .. relativeConfigFileName
	end

	if relativeConfigFileName == nil or relativeConfigFileName == "" then
		return string.format("placeable:%s:%s", tostring(placeable.typeName), tostring(placeable.nodeId))
	end
	
    return relativeConfigFileName
end


function SiloFilltypeLimiting:getStationIdentifier(station)
	-- dbPrintHeader("SiloFilltypeLimiting:getStationIdentifier")
    local placeable = station ~= nil and station.owningPlaceable or nil
	if placeable == nil then
		return tostring(station)
	end
    return SiloFilltypeLimiting:getPlaceableIdentifier(placeable)
end


-- function SiloFilltypeLimiting:onLoad(savegame)end;
-- function SiloFilltypeLimiting:onUpdate(dt)end;
-- function SiloFilltypeLimiting:deleteMap()end;
-- function SiloFilltypeLimiting:keyEvent(unicode, sym, modifier, isDown)end;
-- function SiloFilltypeLimiting:mouseEvent(posX, posY, isDown, isUp, button)end;


