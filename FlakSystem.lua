
-- FlakSystem.lua VERSION 1.1.0
-- Modular flak + corridor library for DCS World
-- Requires MIST
-- Supports:
--  * Dynamic or fixed altitude flak
--  * Flag-controlled OR enemy-presence-controlled zones
--  * Zone scanning by prefix
--  * Corridor generation
--  * Debug/log system

FlakSystem = {}
FlakSystem.__index = FlakSystem


--------------------------------------------------
-- GLOBAL CONFIGURATION
--------------------------------------------------

FlakSystem.debug = false  -- set true for in-game messages

-- Hold Fire Flag
-- Add a flag name for the option to trigger on and off the entire system.
-- "nil" is the default option; The flag will be unset and thus ignored.

FlakSystem.holdFireFlag = nil  -- Set to flag name string, e.g. "HoldFire"

-- 🧮 Density settings
-- Controls how many flak bursts are generated per layer per zone
-- Actual bursts = floor((zone.radius / densityFactor) * densityMultiplier)

FlakSystem.densityFactor = 500         -- meters per burst; higher = fewer explosions
FlakSystem.densityMultiplier = 0.5     -- scales burst count down for performance

-- 🎯 Recommended zone radius guidelines:
-- • 500–800m  → Light to medium flak, low system load
-- • 1000–1500m → Dense flak, medium load
-- • 1500–2000m → Heavy flak zones, significant performance cost
-- • 2000m+     → Not recommended unless using 1–2 zones total

-- 🎯 Example:
-- radius = 1000 → 2 bursts per layer
-- radius = 1500 → 3 bursts per layer
-- radius = 2000 → 4 bursts per layer × # of altitude layers

-- ☁️ Layering
-- Offsets from center altitude (fixed or dynamic)
-- Use wider spread for area denial; tighter spread for precision

FlakSystem.layerOffsets = { -150, 0, 150}

-- ⏱ Flak tick interval (seconds)
-- How often each zone executes a flak barrage cycle
-- Lower = more rapid volleys; higher = less frequent fire
-- Suggested range: 0.5 to 1.0

FlakSystem.interval = 0.6

-- 📡 Altitude binning
-- Used for dynamic altitude tracking; groups aircraft into vertical bands
-- Smaller = more precision but more CPU-intensive

FlakSystem.altitudeBinSize = 150

--------------------------------------------------
-- LOGGING
--------------------------------------------------

function FlakSystem:log(msg, duration)
    env.info("[FlakSystem] " .. tostring(msg))
    if self.debug then
        trigger.action.outText("[Flak] " .. tostring(msg), duration or 5)
    end
end

--------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------

function FlakSystem:newZone(name, opts)
    opts = opts or {}

    local zone = trigger.misc.getZone(name)

    if not zone and mist and mist.DBs and mist.DBs.zonesByName then
        zone = mist.DBs.zonesByName[name]
    end

    if not zone then
        self:log("Zone not found: " .. tostring(name))
        return nil
    end

    local obj = {
        name          = name,
        zone          = zone,
        controlFlag   = opts.flag,
        useDynamicAlt = opts.dynamicAltitude or false,
        fixedAltitude = opts.altitude,
        enabled       = false
    }

    setmetatable(obj, self)
    return obj
end

--------------------------------------------------
-- DYNAMIC ALTITUDE
--------------------------------------------------

function FlakSystem:getDominantAltitude()
    local bands = {}
    local found = false

    for _, group in pairs(coalition.getGroups(coalition.side.BLUE, Group.Category.AIRPLANE)) do
        for _, unit in pairs(group:getUnits()) do
            if unit and unit:isExist() then
                local alt = unit:getPoint().y
                local band = math.floor(alt / self.altitudeBinSize)

                bands[band] = bands[band] or {count = 0, total = 0}
                bands[band].count = bands[band].count + 1
                bands[band].total = bands[band].total + alt
                found = true
            end
        end
    end

    if not found then return nil end

    local bestBand, bestCount = nil, 0
    for band, data in pairs(bands) do
        if data.count > bestCount then
            bestBand = band
            bestCount = data.count
        end
    end

    if bestBand then
        return bands[bestBand].total / bands[bestBand].count
    end

    return nil
end

--------------------------------------------------
-- SPAWN FLAK
--------------------------------------------------

function FlakSystem:spawnFlak()
    if not self.enabled then return end

    local zone = self.zone
    local radius = zone.radius or 500
    local count = math.max(1, math.floor((radius / self.densityFactor) * self.densityMultiplier))

    local centerAlt = nil
    if self.useDynamicAlt then
        centerAlt = self:getDominantAltitude()
    else
        centerAlt = self.fixedAltitude
    end

    if not centerAlt then return end

    for _, offset in ipairs(self.layerOffsets) do
        local layerAlt = centerAlt + offset

        for i = 1, count do
            mist.scheduleFunction(function()
                if not self.enabled then return end
                if FlakSystem.holdFireFlag and trigger.misc.getUserFlag(FlakSystem.holdFireFlag) == 1 then
                    return  -- Hold fire active
                end

                local angle = math.random() * 2 * math.pi
                local dist = math.random() * radius

                local x = zone.point.x + math.cos(angle) * dist
                local z = zone.point.z + math.sin(angle) * dist
                local y = layerAlt + math.random(-50, 50)

                trigger.action.explosion({x = x, y = y, z = z}, math.random(1,3))
            end, {}, timer.getTime() + (i * 0.1))
        end
    end

    mist.scheduleFunction(function() self:spawnFlak() end, {}, timer.getTime() + self.interval)
end

--------------------------------------------------
-- UPDATE LOOP (FLAG OR ENEMY CONTROLLED)
--------------------------------------------------

function FlakSystem:update()
    local zonePos = self.zone.point
    local radius = self.zone.radius or 500

    local enemyPresent = false
    for _, group in pairs(coalition.getGroups(coalition.side.BLUE, Group.Category.AIRPLANE)) do
        for _, unit in pairs(group:getUnits()) do
            if unit and unit:isExist() then
                local pos = unit:getPoint()
                local dx = pos.x - zonePos.x
                local dz = pos.z - zonePos.z
                if math.sqrt(dx*dx + dz*dz) <= radius then
                    enemyPresent = true
                    break
                end
            end
        end
        if enemyPresent then break end
    end

    local shouldEnable = false

    if self.controlFlag then
        shouldEnable = (trigger.misc.getUserFlag(self.controlFlag) == 1)
    else
        shouldEnable = enemyPresent
    end

    if shouldEnable and not self.enabled then
        self.enabled = true
        self:spawnFlak()
    elseif not shouldEnable and self.enabled then
        self.enabled = false
    end

    mist.scheduleFunction(function() self:update() end, {}, timer.getTime() + 1)
end

--------------------------------------------------
-- SCAN ZONES BY PREFIX
--------------------------------------------------

function FlakSystem:scanZonesByPrefix(prefix, params)
    params = params or {}

    if not mist or not mist.DBs or not mist.DBs.zonesByName then
        self:log("MIST zone DB not available")
        return
    end

    local count = 0

    for name, _ in pairs(mist.DBs.zonesByName) do
        if string.lower(name):sub(1, #prefix) == string.lower(prefix) then
            local flag = nil
            if params.flagPrefix then
                flag = params.flagPrefix .. tostring(count + 1)
            elseif params.flag then
                flag = params.flag
            end

            local zone = self:newZone(name, {
                dynamicAltitude = params.dynamicAltitude,
                altitude = params.altitude,
                flag = flag
            })

            if zone then
                zone:update()
                count = count + 1
                self:log("Registered zone: " .. name)
            end
        end
    end

    self:log("scanZonesByPrefix complete. Zones: " .. count)
end

--------------------------------------------------
-- BUILD FLAK CORRIDOR
--------------------------------------------------

function FlakSystem:buildCorridor(startZoneName, endZoneName, spacingMeters, params)
    params = params or {}

    local z1 = trigger.misc.getZone(startZoneName)
    local z2 = trigger.misc.getZone(endZoneName)

    if not z1 or not z2 then
        self:log("Corridor zones invalid: " .. tostring(startZoneName) .. ", " .. tostring(endZoneName))
        return
    end

    if not mist.DBs or not mist.DBs.zonesByName then
        self:log("MIST zone DB missing")
        return
    end

    local p1, p2 = z1.point, z2.point
    local dx, dz = p2.x - p1.x, p2.z - p1.z
    local distance = math.sqrt(dx*dx + dz*dz)

    local num = math.max(1, math.floor(distance / spacingMeters))

    for i = 0, num do
        local t = i / num
        local x = p1.x + dx * t
        local z = p1.z + dz * t

        local zoneName = (params.namePrefix or "FlakCorridor_") .. tostring(i+1)

        mist.DBs.zonesByName[zoneName] = {
            point = {x = x, y = 0, z = z},
            radius = params.zoneRadius or 800
        }

        local flag = nil
        if params.flagPrefix then
            flag = params.flagPrefix .. tostring(i+1)
        end

        local zone = self:newZone(zoneName, {
            dynamicAltitude = params.dynamicAltitude,
            altitude = params.altitude,
            flag = flag
        })

        if zone then
            zone:update()
            self:log("Corridor zone created: " .. zoneName)
        end
    end

    self:log("Corridor build complete")
end
