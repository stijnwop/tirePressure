----------------------------------------------------------------------------------------------------
-- TirePressure
----------------------------------------------------------------------------------------------------
-- Purpose: allows setting tire pressure on the wheels.
--
-- Copyright (c) Wopster, 2019
----------------------------------------------------------------------------------------------------

--[[
Add the following (besides the specialization entry) to the your modDesc:

<actions>
    <action name="TP_AXIS_PRESSURE" axisType="FULL"/>
    <action name="TP_TOGGLE_PRESSURE" axisType="HALF"/>
</actions>

<inputBinding>
    <actionBinding action="TP_TOGGLE_PRESSURE">
        <binding device="KB_MOUSE_DEFAULT" input="KEY_lctrl KEY_p"/>
    </actionBinding>
    <actionBinding action="TP_AXIS_PRESSURE">
        <binding device="KB_MOUSE_DEFAULT" input="KEY_lctrl KEY_pageup" axisComponent="+"/>
        <binding device="KB_MOUSE_DEFAULT" input="KEY_lctrl KEY_pagedown" axisComponent="-"/>
    </actionBinding>
</inputBinding>

<l10n>
    <text name="information_tirePressure">
        <en>Tire pressure [target: %1.2f bar] [current: %1.2f bar]</en>
        <de>Reifenluftdruck [Soll: %1.2f bar] [Ist: %1.2f bar]</de>
    </text>
    <text name="action_toggleTirePressure">
        <en>Toggle pressure</en>
        <de>Druck ändern</de>
    </text>
    <text name="input_TP_TOGGLE_PRESSURE">
        <en>Update pressure</en>
        <de>Druck aktualisieren</de>
    </text>
    <text name="input_TP_AXIS_PRESSURE_1">
        <en>Inflate</en>
        <de>Aufpumpen</de>
    </text>
    <text name="input_TP_AXIS_PRESSURE_2">
        <en>Deflate</en>
        <de>Ablassen</de>
    </text>
</l10n>

Example entry for the vehicle XML:
If you only want to active it for a specific configuration/configurations you will have to set the configurationName and configurationIndices attributes.
<tirePressure min="X (DEFAULT 80)" max="X (DEFAULT 180)" configurationName="wheels (OPTIONAL)" configurationIndices="2 8 9 (INDEXES OF THE CONFIGURATION)">
    <sounds>
        <air template="DEFAULT_SOWING_AIR_BLOWER">
        <volume indoor="0.4" outdoor="0.85" />
            <pitch indoor="1.0" outdoor="1.0" >
                <modifier type="VALVE_LOAD" value="0.00" modifiedValue="0.80" />
                <modifier type="VALVE_LOAD" value="1.00" modifiedValue="1.20" />
            </pitch>
        </air>
    </sounds>
</tirePressure>
]]

---@class TirePressure
TirePressure = {}
TirePressure.MOD_NAME = g_currentModName

TirePressure.PRESSURE_MIN = 80 -- kPa
TirePressure.PRESSURE_LOW = 80 -- kPa
TirePressure.PRESSURE_NORMAL = 180 -- kPa
TirePressure.PRESSURE_MAX = 180 -- kPa

TirePressure.INCREASE = 1.15
TirePressure.FLATE_MULTIPLIER = 0.005

TirePressure.MAX_INPUT_MULTIPLIER = 10
TirePressure.INPUT_MULTIPLIER_STEP = 0.01

function TirePressure.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Wheels, specializations)
end

function TirePressure.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "updateInflation", TirePressure.updateInflation)
    SpecializationUtil.registerFunction(vehicleType, "updateInflationPressure", TirePressure.updateInflationPressure)
    SpecializationUtil.registerFunction(vehicleType, "getInflationPressure", TirePressure.getInflationPressure)
    SpecializationUtil.registerFunction(vehicleType, "setInflationPressure", TirePressure.setInflationPressure)
    SpecializationUtil.registerFunction(vehicleType, "getInflationPressureTarget", TirePressure.getInflationPressureTarget)
    SpecializationUtil.registerFunction(vehicleType, "setInflationPressureTarget", TirePressure.setInflationPressureTarget)
end

function TirePressure.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", TirePressure)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", TirePressure)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", TirePressure)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", TirePressure)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", TirePressure)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", TirePressure)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", TirePressure)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", TirePressure)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", TirePressure)
end

function TirePressure.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeSelected", TirePressure.getCanBeSelected)
end

function TirePressure:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_tirePressure
        self:clearActionEventsTable(spec.actionEvents)

        if spec.isActive then
            if isActiveForInput then
                local _, actionEventIdInflate = self:addActionEvent(spec.actionEvents, InputAction.TP_AXIS_PRESSURE, self, TirePressure.actionEventInflatePressure, false, true, true, true, nil, nil, true)
                local _, actionEventIdTogglePressure = self:addActionEvent(spec.actionEvents, InputAction.TP_TOGGLE_PRESSURE, self, TirePressure.actionEventTogglePressure, false, true, false, true, nil, nil, true)

                g_inputBinding:setActionEventText(actionEventIdTogglePressure, g_i18n:getText("action_toggleTirePressure"))
                g_inputBinding:setActionEventTextVisibility(actionEventIdTogglePressure, true)
                g_inputBinding:setActionEventTextPriority(actionEventIdTogglePressure, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventActive(actionEventIdInflate, true)
                g_inputBinding:setActionEventActive(actionEventIdTogglePressure, true)
            end
        end
    end
end

---Checks whether or not the configuration allows the tire pressure to be active.
function TirePressure.isEnabledByConfiguration(configuration, configurationIndices)
    if configuration ~= nil then
        for _, configurationIndex in pairs(configurationIndices) do
            if configuration == configurationIndex then
                return true
            end
        end
    end

    return false
end

function TirePressure:onLoad(savegame)
    self.spec_tirePressure = self[("spec_%s.tirePressure"):format(TirePressure.MOD_NAME)]
    local spec = self.spec_tirePressure
    spec.isActive = true -- default enabled.

    local configurationName = getXMLString(self.xmlFile, "vehicle.tirePressure#configurationName")
    if configurationName ~= nil then
        local configurationIndices = Utils.getNoNil(StringUtil.getVectorNFromString(getXMLString(self.xmlFile, "vehicle.tirePressure#configurationIndices")), { 1 })
        if configurationIndices ~= nil then
            spec.isActive = TirePressure.isEnabledByConfiguration(self.configurations[configurationName], configurationIndices)
        end
    end

    spec.inflationPressure = TirePressure.PRESSURE_NORMAL
    spec.inflationPressureTarget = TirePressure.PRESSURE_NORMAL
    spec.isInflating = false
    spec.allWheelsAreCrawlers = true
    spec.pressureMax = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.tirePressure#max"), TirePressure.PRESSURE_MAX)
    spec.pressureMin = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.tirePressure#min"), TirePressure.PRESSURE_MIN)

    spec.lastInputChangePressureValue = 0
    spec.lastPressureValue = 0
    spec.changeCurrentDelay = 0
    spec.changeMultiplier = 1
    spec.changePushUpdate = false

    local tireTypeCrawler = WheelsUtil.getTireType("crawler")
    for _, wheel in ipairs(self:getWheels()) do
        if wheel.tireType ~= tireTypeCrawler then
            spec.allWheelsAreCrawlers = false
        end
    end

    spec.inflationDirtyFlag = self:getNextDirtyFlag()

    if self.isClient then
        spec.samples = {}
        spec.samples.air = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.tirePressure.sounds", "air", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
    end
end

function TirePressure:onPostLoad(savegame)
    local spec = self.spec_tirePressure
    if spec.isActive and savegame ~= nil and not savegame.resetVehicles then
        local key = savegame.key .. "." .. TirePressure.MOD_NAME .. ".tirePressure"
        local tirePressure = Utils.getNoNil(getXMLFloat(savegame.xmlFile, key .. "#inflationPressure"), spec.inflationPressure)

        if tirePressure ~= nil then
            self:setInflationPressure(tirePressure)
        end
    end
end

function TirePressure:onDelete()
    local spec = self.spec_tirePressure
    if self.isClient then
        g_soundManager:deleteSamples(spec.samples)
    end
end

function TirePressure:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_tirePressure
    setXMLFloat(xmlFile, key .. "#inflationPressure", spec.inflationPressure)
end

function TirePressure:onReadStream(streamId, connection)
    local spec = self.spec_tirePressure
    spec.isInflating = streamReadBool(streamId)
    local inflationPressure = streamReadFloat32(streamId)
    self:setInflationPressure(inflationPressure)
end

function TirePressure:onWriteStream(streamId, connection)
    local spec = self.spec_tirePressure
    streamWriteBool(streamId, spec.isInflating)
    streamWriteFloat32(streamId, spec.inflationPressure)
end

function TirePressure:onReadUpdateStream(streamId, timestamp, connection)
    local spec = self.spec_tirePressure
    if connection:getIsServer() then
        if streamReadBool(streamId) then
            local inflationPressure = streamReadFloat32(streamId)
            self:setInflationPressure(inflationPressure)
        end
    end
end

function TirePressure:onWriteUpdateStream(streamId, connection, dirtyMask)
    local spec = self.spec_tirePressure

    if not connection:getIsServer() then
        if streamWriteBool(streamId, bitAND(dirtyMask, spec.inflationDirtyFlag) ~= 0) then
            streamWriteFloat32(streamId, spec.inflationPressure)
        end
    end
end

function TirePressure:onUpdate(dt)
    local spec = self.spec_tirePressure

    if self.isClient then
        local actionEventPressure = spec.actionEvents[InputAction.TP_AXIS_PRESSURE]
        if actionEventPressure ~= nil then
            g_inputBinding:setActionEventActive(actionEventPressure.actionEventId, spec.isActive)
        end
        local actionEventToggle = spec.actionEvents[InputAction.TP_TOGGLE_PRESSURE]
        if actionEventToggle ~= nil then
            g_inputBinding:setActionEventActive(actionEventToggle.actionEventId, spec.isActive)
        end
    end

    if spec.allWheelsAreCrawlers or not spec.isActive then
        return
    end

    local pressure = self:getInflationPressure()

    if self.isClient then
        local lastInputChangePressureValue = spec.lastInputChangePressureValue
        spec.lastInputChangePressureValue = 0

        if lastInputChangePressureValue ~= 0 then
            spec.changeCurrentDelay = spec.changeCurrentDelay - (dt * spec.changeMultiplier)
            spec.changeMultiplier = math.min(spec.changeMultiplier + (dt * TirePressure.INPUT_MULTIPLIER_STEP), TirePressure.MAX_INPUT_MULTIPLIER)

            if spec.changeCurrentDelay < 0 then
                spec.changeCurrentDelay = 250
                local dir = MathUtil.sign(lastInputChangePressureValue)
                local pressureChange = dt * spec.changeMultiplier * TirePressure.FLATE_MULTIPLIER
                pressureChange = pressureChange * dir
                spec.inflationPressureTarget = MathUtil.clamp(spec.inflationPressureTarget + pressureChange, spec.pressureMin, spec.pressureMax)
                spec.changePushUpdate = true
            end
        else
            spec.changeCurrentDelay = 0
            spec.changeMultiplier = 1

            if spec.changePushUpdate then
                spec.changePushUpdate = false
                g_client:getServerConnection():sendEvent(SetInflationPressureEvent:new(self, spec.isInflating, spec.inflationPressureTarget))
            end
        end
    end

    if self.isServer then
        if spec.isInflating then
            local diff = spec.inflationPressureTarget - pressure
            if math.abs(diff) > 0.05 then
                local dir = MathUtil.sign(diff)
                local pressureChange = dt * TirePressure.FLATE_MULTIPLIER
                self:setInflationPressure(pressure + (pressureChange * dir))
            else
                self:updateInflation(false)
            end
        end

        if pressure == self:getInflationPressure() and spec.isInflating then
            self:updateInflation(false)
        end
    end

    if self.isClient then
        local isCapped = pressure == spec.pressureMin or pressure == spec.inflationPressureTarget

        if spec.isInflating and not isCapped then
            if not g_soundManager:getIsSamplePlaying(spec.samples.air) then
                g_soundManager:playSample(spec.samples.air)
            end
        else
            if g_soundManager:getIsSamplePlaying(spec.samples.air) then
                g_soundManager:stopSample(spec.samples.air)
            end
        end

        --Due to a vanilla bug (with calling onDraw on attached implements to implements) we have to render it in the update frame instead of onDraw.
        if not spec.allWheelsAreCrawlers and spec.isActive and self:getIsActiveForInput() then
            g_currentMission:addExtraPrintText(g_i18n:getText("information_tirePressure"):format(self:getInflationPressureTarget() / 100, self:getInflationPressure() / 100))
        end
    end
end

function TirePressure:updateInflationPressure()
    local spec = self.spec_tirePressure
    local tireTypeCrawler = WheelsUtil.getTireType("crawler")

    for _, wheel in pairs(self:getWheels()) do
        if wheel.tireType ~= tireTypeCrawler then
            if wheel.tpMaxDeformation == nil then
                wheel.tpMaxDeformation = Utils.getNoNil(wheel.maxDeformation, 0)
                wheel.tpSuspTravel = wheel.suspTravel
                wheel.tpFrictionScale = wheel.frictionScale
            end

            local deformation = MathUtil.clamp((wheel.deltaY + 0.04 - (wheel.tpSuspTravel * 0.5)) * (TirePressure.INCREASE - (spec.inflationPressure - TirePressure.PRESSURE_LOW) / 100), 0, wheel.maxDeformation)
            wheel.suspTravel = wheel.tpSuspTravel - deformation
            local delta = TirePressure.PRESSURE_NORMAL / spec.inflationPressure
            wheel.maxDeformation = wheel.tpMaxDeformation * delta
            wheel.frictionScale = wheel.tpFrictionScale * delta - 0.5

            self:setWheelPositionDirty(wheel)
            self:setWheelTireFrictionDirty(wheel)
        end
    end
end

function TirePressure:updateInflation(isInflating, noEventSend)
    local spec = self.spec_tirePressure
    if isInflating ~= spec.isInflating then
        SetInflationPressureEvent.sendEvent(self, isInflating, noEventSend)
        spec.isInflating = isInflating
    end
end

function TirePressure:getInflationPressure()
    return self.spec_tirePressure.inflationPressure
end

function TirePressure:setInflationPressure(pressure)
    local spec = self.spec_tirePressure
    local inflationPressure = MathUtil.clamp(pressure, spec.pressureMin, spec.pressureMax)

    if spec.inflationPressure ~= inflationPressure then
        spec.inflationPressure = inflationPressure
        self:updateInflationPressure()

        if self.isServer then
            self:raiseDirtyFlags(spec.inflationDirtyFlag)
            spec.inflationPressureSent = inflationPressure
        end
    end
end

function TirePressure:setInflationPressureTarget(target)
    self.spec_tirePressure.inflationPressureTarget = target
end

function TirePressure:getInflationPressureTarget()
    return self.spec_tirePressure.inflationPressureTarget
end

function TirePressure:getValveLoadPercentage()
    if self.spec_tirePressure ~= nil then
        local spec = self.spec_tirePressure
        return MathUtil.sign(spec.inflationPressureTarget - spec.inflationPressure) > 0 and 1 or 0
    end

    return 0
end

g_soundManager:registerModifierType("VALVE_LOAD", TirePressure.getValveLoadPercentage)

function TirePressure:getCanBeSelected(superFunc)
    return true
end

function TirePressure.actionEventInflatePressure(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_tirePressure

    if not spec.allWheelsAreCrawlers and spec.isActive then
        spec.lastInputChangePressureValue = inputValue
        spec.lastPressureValue = inputValue
    end
end

function TirePressure.actionEventTogglePressure(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_tirePressure

    if not spec.allWheelsAreCrawlers and spec.isActive then
        self:updateInflation(not spec.isInflating)
    end
end

SetInflationPressureEvent = {}
SetInflationPressureEvent_mt = Class(SetInflationPressureEvent, Event)

InitEventClass(SetInflationPressureEvent, "SetInflationPressureEvent")

function SetInflationPressureEvent:emptyNew()
    local event = Event:new(SetInflationPressureEvent_mt)
    return event
end

function SetInflationPressureEvent:new(object, isInflating, inflationPressureTarget)
    local event = SetInflationPressureEvent:emptyNew()

    event.object = object
    event.isInflating = isInflating
    event.inflationPressureTarget = inflationPressureTarget

    return event
end

function SetInflationPressureEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.isInflating = streamReadBool(streamId)

    if streamReadBool(streamId) then
        self.inflationPressureTarget = streamReadFloat32(streamId)
    end

    self:run(connection)
end

function SetInflationPressureEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.isInflating)
    local hasTarget = self.inflationPressureTarget ~= nil
    streamWriteBool(streamId, hasTarget)
    if hasTarget then
        streamWriteFloat32(streamId, self.inflationPressureTarget)
    end
end

function SetInflationPressureEvent:run(connection)
    self.object:updateInflation(self.isInflating, true)

    if self.inflationPressureTarget ~= nil then
        self.object:setInflationPressureTarget(self.inflationPressureTarget)
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function SetInflationPressureEvent.sendEvent(object, isInflating, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SetInflationPressureEvent:new(object, isInflating), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(SetInflationPressureEvent:new(object, isInflating))
        end
    end
end
