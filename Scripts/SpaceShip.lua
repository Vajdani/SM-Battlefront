---@class SpaceShip : HarvestableClass
SpaceShip = class()
SpaceShip.slowedSpeed = 20
SpaceShip.cruiseSpeed = 40
SpaceShip.lightBoost = 90
SpaceShip.heavyBoost = 150
SpaceShip.acceleration = 1.5
SpaceShip.turnLimit = 0.4
SpaceShip.rollSpeed = 50

SpaceShip.maxStamina = 4
SpaceShip.staminaDrain = 1
SpaceShip.staminaGain = 0.5
SpaceShip.boostThreshold = 0.25

SpaceShip.flyToSpeed = 1
SpaceShip.flyToTurnSpeed = 5
SpaceShip.landOffset = 0
SpaceShip.hasTakeOffAnim = false

SpaceShip.posLerpSpeed = 25
SpaceShip.rotLerpSpeed = 2.5
SpaceShip.rollLerpSpeed = 2.5
SpaceShip.camLerpSpeed = 15

SpaceShip.maxHealth = 1000
SpaceShip.healthRegen = 0

SpaceShip.fatalSpeedScale = 0.75

SpaceShip.collisionData = nil
SpaceShip.thrustEffectData = nil
SpaceShip.boostEffectData = nil

SpaceShip.destroyEffect = "PropaneTank - ExplosionBig"
SpaceShip.name = "Default"

dofile "$CONTENT_DATA/Scripts/util.lua"

local cam = sm.camera
local angleAxis = sm.quat.angleAxis
local clamp = sm.util.clamp
local vec3_lerp = sm.vec3.lerp
local quat_slerp = sm.quat.slerp

function SpaceShip:server_onCreate()
    self.sv_beInSpace = false
    self.sv_nextInSpace = false
    self.sv_controls = self:getDefaultControls()
    self.sv_speed = 0
    self.sv_stamina = self.maxStamina
    self.sv_blockBoost = false
    self.sv_stunned = false
    self.controlLost = false
    self.deathTimer = 0
    self.sv_dir = { x = 0, y = 0, z = 0 }

    self.knockback = VEC3_ZERO
    self.angularVelocity = VEC3_ZERO

    self.flyTo = {
        startPos = nil, startRot = nil,
        endPos = nil, endRot = nil,
        progress = 0
    }

    self.health = self.maxHealth
    self.harvestable.publicData = {
        health = self.health, maxHealth = self.maxHealth,
        stamina = self.sv_stamina, maxStamina = self.maxStamina
    }

    self.statTimer = Timer()
    self.statTimer:start(40)

    self.colTriggers = {}
    if not self.collisionData then return end

    local filter =  sm.areaTrigger.filter.harvestable + sm.areaTrigger.filter.staticBody
    local pos, rot = self.harvestable.worldPosition, self.harvestable.worldRotation
    for k, data in pairs(self.collisionData) do
        local _pos, _rot = data.getTransform(pos, rot)
        local trigger = sm.areaTrigger.createBox(data.scale, _pos, _rot, filter)
        trigger:bindOnEnter("sv_onCollision", self)

        self.colTriggers[#self.colTriggers+1] = {
            trigger = trigger,
            getTransform = data.getTransform
        }
    end
end

function SpaceShip:server_onDestroy()
    for k, v in pairs(self.colTriggers) do
        sm.areaTrigger.destroy(v.trigger)
    end
end

--[[function SpaceShip:server_onExplosion(center, destructionLevel)
	self:sv_takeDamage(destructionLevel * 4, "explosion")
end]]

function SpaceShip:server_onProjectile(position, airTime, velocity, projectileName, attacker, damage, customData, normal, uuid)
	self:sv_takeDamage(damage, DAMAGESOURCE.projectile)
end

function SpaceShip:server_onMelee(position, attacker, damage, power, direction, normal)
    self:sv_takeDamage(damage, DAMAGESOURCE.melee)
end

function SpaceShip:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    self:sv_handleCollision(other, normal)
end

function SpaceShip:sv_onCollision(trigger, result)
    if not sm.exists(self.harvestable) or self.sv_stunned then return end

    local shipPos = self.harvestable.worldPosition
    local colPos = trigger:getWorldPosition()
    local hit, rayResult = sm.physics.spherecast(
        colPos, colPos + self.harvestable.worldRotation * VEC3_UP * (trigger:getSize().y * 1.25), 1
    )
    local normal = hit and rayResult.normalWorld * 2

    for k, obj in pairs(result) do
        if obj ~= self.harvestable and self:sv_handleCollision(obj, normal or (shipPos - obj.worldPosition):normalize()) then
            break
        end
    end
end

function SpaceShip:sv_handleCollision(obj, normal)
    if self.controlLost then
        self:sv_explode()
        return
    end

    if not sm.exists(obj) then return false end

    local _type = type(obj)
    if _type == "Character" or _type == "Shape" and (obj:getBoundingBox() * 4):length() < 16 then return false end

    local speedScale = self.sv_speed / self.heavyBoost
    if speedScale >= self.fatalSpeedScale then
        self:sv_onDeath(DAMAGESOURCE.collision)
    else
        self:sv_takeDamage(self.velocity:length() * 10, DAMAGESOURCE.collision)
    end

    if self.sv_beInSpace then
        self.sv_stunned = true
        self.sv_speed = 0
        self.knockback = normal * 50
        --self.angularVelocity = normal:cross(self.harvestable.worldRotation * VEC3_RIGHT)

        self.network:setClientData( { beInSpace = self.sv_beInSpace, nextInSpace = self.sv_nextInSpace, stunned = self.sv_stunned }, 1 )
    end

    return true
end

function SpaceShip:sv_takeDamage(damage, source)
    if type(damage) == "table" then
        source = damage.source
        damage = damage.damage
    end

    self.health = math.max(self.health - damage, 0)
	print(string.format("SpaceShip['%s'] %s took %s damage, current health: %s / %s", self.name, self.harvestable.id, damage, self.health, self.maxHealth))
    if sm.exists(self.harvestable) then
        self.harvestable.publicData.health = self.health
    end

    if self.health <= 0 then
        self:sv_onDeath(source)
    else
        self.network:setClientData(self.harvestable.publicData, 2)
    end
end

local DETONATE = {
    [DAMAGESOURCE.collision] = true,
    [DAMAGESOURCE.bomb] = true,
}
function SpaceShip:sv_onDeath(source)
    if not self.sv_beInSpace or DETONATE[source] == true then
	    self:sv_explode()
    else
        self.controlLost = true
        self.sv_dir.z = 1
        self.deathTimer = 2.5
    end
end

function SpaceShip:sv_explode()
    local pos = self.harvestable.worldPosition
    sm.physics.explode( pos, 10, 5, 10, 100 )
    sm.effect.playEffect( self.destroyEffect, pos, VEC3_ZERO, self.harvestable.worldRotation * ROTADJUST, VEC3_ONE, { Color = self.harvestable:getColor() } )

    local char = self.harvestable:getSeatCharacter()
    self.harvestable:destroy()

    if char then
        local player = char:getPlayer()
        sm.event.sendToPlayer(player, "sv_setSpaceShip", nil)
        sm.event.sendToPlayer(player, "sv_takeDamage", 101)
    end
end

function SpaceShip:server_onFixedUpdate(dt)
    local hvs = self.harvestable
    if not sm.exists(hvs) then return end

    local pos, rot = hvs.worldPosition, hvs.worldRotation
    local char = hvs:getSeatCharacter()
    local destination = self.flyTo.endPos

    if self.velocity:length2() > FLT_EPSILON then
        local pos_v = pos - self.velocity
        for k, v in pairs(self.colTriggers) do
            local _pos, _rot = v.getTransform(pos_v, rot)
            local trigger = v.trigger
            trigger:setWorldPosition(_pos)
            trigger:setWorldRotation(_rot * ROTADJUST)
        end
    end

    local canBoost
    if destination then
        self.flyTo.progress = clamp(self.flyTo.progress + dt * self.flyToSpeed, 0, 1)
        local progress = sm.util.easing("easeInOutQuad", self.flyTo.progress)
        local newPos = vec3_lerp(self.flyTo.startPos, destination, progress)
        hvs:setPosition(newPos)

        local endRot = self.flyTo.endRot
        if endRot then
            hvs:setRotation(quat_slerp(self.flyTo.startRot, endRot, progress))
        else
            local charDir = angleAxis(self.sv_dir.x, VEC3_FWD) * angleAxis(self.sv_dir.y, VEC3_RIGHT)
            hvs:setRotation(quat_slerp(rot, rot * charDir, dt * self.flyToTurnSpeed))
        end

        if self.flyTo.progress >= 1 then
            hvs:setPosition(destination)
            hvs:setRotation(endRot or hvs.worldRotation)

            self.flyTo = {
                startPos = nil, startRot = nil,
                endPos = nil, endRot = nil,
                progress = 0
            }
            self.sv_beInSpace = self.sv_nextInSpace
            self.network:setClientData({ beInSpace = self.sv_beInSpace, nextInSpace = self.sv_nextInSpace, stunned = self.sv_stunned }, 1)
        end
    elseif char then
        if self.sv_beInSpace then
            if self.sv_stunned then
                hvs:setPosition(vec3_lerp(pos, pos + self.knockback * dt, dt * self.posLerpSpeed))
                --hvs:setRotation(quat_slerp(rot, rot * angleAxis(math.rad(5), self.angularVelocity), dt * self.posLerpSpeed))

                self.knockback = self.knockback - self.knockback * dt * 5
                --self.angularVelocity = self.angularVelocity - self.angularVelocity * dt * 10
                if self.knockback:length() <= 1 then
                    self.sv_stunned = false
                    self.knockback = VEC3_ZERO
                    self.angularVelocity = VEC3_ZERO
                    self.network:setClientData({ beInSpace = self.sv_beInSpace, nextInSpace = self.sv_nextInSpace, stunned = self.sv_stunned }, 1)
                end
            elseif self.controlLost then
                self.sv_speed = clamp(self.sv_speed - dt * 10, self.cruiseSpeed, self.heavyBoost)
                local newPos = pos + rot * VEC3_UP * round(self.sv_speed) * dt
                hvs:setPosition(vec3_lerp(pos, newPos, dt * self.posLerpSpeed))

                local charDir = angleAxis(math.rad(-20), VEC3_FWD) * angleAxis(math.rad(self.sv_dir.z * self.rollSpeed), VEC3_UP)
                hvs:setRotation(quat_slerp(rot, rot * charDir, dt * self.rotLerpSpeed))

                self.sv_dir.z = clamp(self.sv_dir.z - dt, 0, 1)

                self.deathTimer = self.deathTimer - dt
                if self.deathTimer <= 0 then
                    self:sv_explode()
                end
            else
                local speed = self.cruiseSpeed
                canBoost = self.sv_controls[5] and not self.sv_blockBoost
                if self.sv_controls[3] then
                    if canBoost then
                        self.sv_stamina = clamp(self.sv_stamina - dt * self.staminaDrain, 0, self.maxStamina)
                        if self.sv_stamina > 0 then
                            speed = self.heavyBoost
                        else
                            self.sv_blockBoost = true
                        end
                    else
                        if self.sv_stamina >= self.maxStamina * self.boostThreshold then
                            self.sv_blockBoost = false
                        end

                        speed = self.lightBoost
                    end
                elseif self.sv_controls[4] then
                    speed = self.slowedSpeed
                end

                self.sv_speed = sm.util.lerp(self.sv_speed, speed, dt * self.acceleration)
                hvs.publicData.stamina = self.sv_stamina

                local newPos = pos + rot * VEC3_UP * round(self.sv_speed) * dt
                hvs:setPosition(vec3_lerp(pos, newPos, dt * self.posLerpSpeed))

                self.sv_dir.z = sm.util.lerp(self.sv_dir.z, bVal(self.sv_controls[2]) - bVal(self.sv_controls[1]), dt * self.rollLerpSpeed)
                local charDir = angleAxis(self.sv_dir.x, VEC3_FWD) * angleAxis(self.sv_dir.y, VEC3_RIGHT) * angleAxis(math.rad(self.sv_dir.z * self.rollSpeed), VEC3_UP)
                hvs:setRotation(quat_slerp(rot, rot * charDir, dt * self.rotLerpSpeed))
            end
        end
    end

    if not canBoost then
        self.sv_stamina = clamp(self.sv_stamina + dt * self.staminaGain, 0, self.maxStamina)
    end

    if self.healthRegen > 0 then
        self.health = clamp(self.health + dt * self.healthRegen, 0, self.maxHealth)
        hvs.publicData.health = self.health

        self.statTimer:tick()
        if self.statTimer:done() then
            self.statTimer:reset()
            self.network:setClientData(hvs.publicData, 2)
        end
    end

    return char
end

function SpaceShip:sv_seat(args, player)
    local char = self.harvestable:getSeatCharacter()
    if char then
        if self:sv_takeOff(false, player) then
            self.harvestable:setSeatCharacter(char)

            local rot = self.harvestable.worldRotation
            player:setCharacter(
                sm.character.createCharacter(
                    player,
                    char:getWorld(),
                    self:getExitPos(),
                    GetYawPitch(rot * VEC3_UP)
                )
            )

            sm.event.sendToPlayer(player, "sv_setSpaceShip", nil)
            self.network:sendToClient(player, "cl_seat")

            self.sv_controls = self:getDefaultControls()
        end
    else
        sm.event.sendToPlayer(player, "sv_setSpaceShip", self.harvestable)
        self.network:sendToClient(player, "cl_seat", self.harvestable.publicData)
    end
end

function SpaceShip:sv_updateControls(controls, player)
    --if not self:verifyPacket(player) then return end

    self.sv_controls = controls
    self.network:sendToClients("cl_updateControls", controls)
end

function SpaceShip:sv_updateDir(dir, player)
    if self.controlLost --[[not self:verifyPacket(player)]] --[[or not self.sv_beInSpace or not self.sv_nextInSpace]] then return end

    self.sv_dir.x, self.sv_dir.y = self:clampTurnDir(self.sv_dir.x + dir.x, self.sv_dir.y - dir.y)
end

function SpaceShip:sv_takeOff(state, player)
    if --[[not self:verifyPacket(player) or]] self.flyTo.endPos then return false end

    local nextInSpace
    if state ~= nil then
        if not state and not self.sv_nextInSpace and not self.sv_beInSpace then
            return true
        end

        nextInSpace = state
    else
        nextInSpace = not self.sv_beInSpace
    end

    local dir = (nextInSpace and VEC3_UP or -VEC3_UP) * 25
    local pos = self.harvestable.worldPosition
    local hit, result = sm.physics.spherecast(pos, pos + dir, 2.5, self.harvestable, LANDRAYCASTFILTER)
    if nextInSpace then
        local endPos
        if hit then
            local point = result.pointWorld
            local dirTo = point - pos
            if dirTo:length() < 2.5 then
                return false
            end

            endPos = point - dirTo:normalize() * 3.5
        else
            endPos = pos + VEC3_UP * 10
        end

        self.flyTo = {
            startPos = pos, startRot = nil,
            endPos = endPos, endRot = nil,
            progress = 0
        }
    else
        if not hit or LANDABLESURFACES[result.type] == nil then return false end

        local rot = self.harvestable.worldRotation
        local normal = result.normalWorld
        self.flyTo = {
            startPos = pos, startRot = rot,
            endPos = result.pointWorld + normal * self.landOffset,
            endRot = LookRot(normal, rot * VEC3_FWD) * ROTADJUST,
            progress = 0
        }

        self.sv_speed = 0
        --self.sv_dir = { x = 0, y = 0, z = 0 }
        self.sv_controls = self:getDefaultControls()
    end

    self.sv_nextInSpace = nextInSpace
    self.network:setClientData({ beInSpace = self.sv_beInSpace, nextInSpace = self.sv_nextInSpace, stunned = self.sv_stunned }, 1)

    return true
end



function SpaceShip:client_onCreate()
    self.cl_controls = self:getDefaultControls()
    self.cl_beInSpace = false
    self.cl_nextInSpace = false
    self.cl_stunned = false
    self.cl_dir = { x = 0, y = 0 }
    self.cl_speed = 0
    self.cl_blockBoost = false
    self.cl_stamina = self.maxStamina
    self.camMode = 2
    self.animProgress = 0

    local col = sm.color.new(1,1,1)
    --self.indicator = Line_indicator()
    --self.indicator:init(0.05, col)
    self.crosshair = sm.effect.createEffect("ShapeRenderable")
    self.crosshair:setParameter("uuid", sm.uuid.new("ae27acb9-3eff-4530-bd4d-a8c3396430f5"))
    self.crosshair:setParameter("color", col)
    self.crosshair:setScale(sm.vec3.new(0.035, 0, 0.035))

    self.lastPos = self.harvestable.worldPosition
    self.velocity = VEC3_ZERO

    self.survivalHud = sm.gui.createSurvivalHudGui()
	self.survivalHud:setVisible("WaterBar", false)
    self.hotbar = sm.gui.createSeatGui(false)

    self.thrustEffects = {}
    if self.thrustEffectData then
        for k, v in pairs(self.thrustEffectData) do
            local effect = sm.effect.createEffect(v.effect, self.harvestable)
            local pos, rot = v.getOffsets()
            effect:setOffsetPosition(pos)
            effect:setOffsetRotation(rot)
            self.thrustEffects[#self.thrustEffects+1] = effect
        end
    end

    self.boostEffects = {}
    if self.boostEffectData then
        for k, v in pairs(self.boostEffectData) do
            local effect = sm.effect.createEffect("Boost_line", self.harvestable)
            effect:setOffsetPosition(v())
            self.boostEffects[#self.boostEffects+1] = effect
        end
    end
end

function SpaceShip:client_onDestroy()
    if g_spaceShip == self.harvestable then
        self:cl_seat()
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_setUIState", true)
    end

    --self.indicator:destroy()
    self.crosshair:destroy()
    self.survivalHud:destroy()
    self.hotbar:destroy()
end

function SpaceShip:client_onClientDataUpdate(data, channel)
    if channel == 1 then
        self.cl_beInSpace = data.beInSpace
        self.cl_nextInSpace = data.nextInSpace
        self.cl_stunned = data.stunned

        if not data.beInSpace then
            self.cl_speed = 0
        end
    elseif g_spaceShip == self.harvestable then
        self:cl_updateUI(data)
    end
end

function SpaceShip:cl_updateUI(data)
    self.survivalHud:setSliderData( "Health", data.maxHealth * 10, data.health * 10 )
    self.survivalHud:setSliderData( "Food", data.maxStamina * 10, data.stamina * 10 )
end

function SpaceShip:cl_updateControls(controls)
    self.cl_controls = controls
end

function SpaceShip:client_onUpdate(dt)
    local char = self.harvestable:getSeatCharacter()
    local isLocal = char and char:getPlayer() == sm.localPlayer.getPlayer()

    local canPlayFx = not isLocal or self.camMode ~= 1
    local playing = self.thrustEffects[1]:isPlaying()
    local shouldPlay = char and self.cl_beInSpace and self.cl_nextInSpace and canPlayFx
    if shouldPlay and not playing then
        self:cl_setEffectsState(self.thrustEffects, true)
    elseif not shouldPlay and playing then
        self:cl_setEffectsState(self.thrustEffects, false)
    end

    local shipSpeed = round(self.cl_speed)
    local displayBoost = self.cl_controls[5] and shipSpeed > self.lightBoost and canPlayFx
    local boostDisplayed = self.boostEffects[1]:isPlaying()
    if displayBoost and not boostDisplayed then
        self:cl_setEffectsState(self.boostEffects, true)
    elseif not displayBoost and boostDisplayed then
        self:cl_setEffectsState(self.boostEffects, false)
    end

    if self.hasTakeOffAnim then
        self.animProgress = clamp(self.animProgress + dt * (self.cl_nextInSpace and 1 or -1), 0, 1)
        self.harvestable:setPoseWeight(0, self.animProgress)
    end

    if not isLocal then
        --self.indicator:stop()
        self.crosshair:stop()
        return char, isLocal
    end

    local lerpSpeed = dt * self.camLerpSpeed
    local camPos, camRot = cam.getPosition(), cam.getRotation()
    local newPos, newRot, pos, rot, fwd, up, shipRot = self:getCamTransForm(camPos, camRot, dt)
    cam.setPosition(newPos)
    cam.setRotation(newRot)
    cam.setFov(sm.util.lerp(sm.camera.getFov(), cam.getDefaultFov() * (1 + (shipSpeed / self.heavyBoost) * 0.35), lerpSpeed))

    local camFwd = cam.getDirection()
    local charDir = rot * VEC3_RIGHT * self.cl_dir.x - up * self.cl_dir.y + camFwd
    --self.indicator:update(newPos + camFwd, newPos + charDir, newRot)
    local crosshair = newPos + charDir
    self.crosshair:setPosition(crosshair)
    self.crosshair:setRotation(newRot)
    self.crosshair:start()

    return char, isLocal
end

function SpaceShip:client_onFixedUpdate(dt)
    local pos = self.harvestable.worldPosition
    self.velocity = pos - self.lastPos
    self.lastPos = pos

    local canBoost
    if self.cl_beInSpace then
        local speed = self.cruiseSpeed
        canBoost = self.cl_controls[5] and not self.cl_blockBoost
        if self.cl_controls[3] then
            if canBoost then
                self.cl_stamina = clamp(self.cl_stamina - dt * self.staminaDrain, 0, self.maxStamina)
                if self.cl_stamina > 0 then
                    speed = self.heavyBoost
                else
                    self.cl_blockBoost = true
                end
            else
                if self.cl_stamina >= self.maxStamina * self.boostThreshold then
                    self.cl_blockBoost = false
                end

                speed = self.lightBoost
            end
        elseif self.cl_controls[4] then
            speed = self.slowedSpeed
        end

        self.cl_speed = sm.util.lerp(self.cl_speed, speed, dt * self.acceleration)
    end

    local char = self.harvestable:getSeatCharacter()
    local isLocal = char and char:getPlayer() == sm.localPlayer.getPlayer()
    if not isLocal then
        return char, isLocal
    end

    local x, y = sm.localPlayer.getMouseDelta()
    if x ~= 0 or y ~= 0 then
        self.network:sendToServer("sv_updateDir", { x = x, y = y })

        self.cl_dir.x, self.cl_dir.y = self:clampTurnDir(self.cl_dir.x + x, self.cl_dir.y - y)
    end

    if not canBoost then
        self.cl_stamina = clamp(self.cl_stamina + dt * self.staminaGain, 0, self.maxStamina)
    end
    self.survivalHud:setSliderData( "Food", self.maxStamina * 100, self.cl_stamina * 100 )

    return char, isLocal
end

function SpaceShip:client_canInteract()
    local can = self.harvestable:getSeatCharacter() == nil
    if can then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), "#{INTERACTION_USE}")
    end

    return can
end

function SpaceShip:client_onInteract(char, state)
    if not state then return end

    self.harvestable:setSeatCharacter(char)
    self.network:sendToServer("sv_seat")
end

function SpaceShip:client_onAction(action, state)
    if self.cl_controls[action] ~= nil then
        self.cl_controls[action] = state
        self.network:sendToServer("sv_updateControls", self.cl_controls)
        return true
    end

    if not state then return true end

    if action == 6 then
        self.camMode = self.camMode < 2 and self.camMode + 1 or 1
        cam.setCameraState(self.camMode == 1 and 2 or 3)
        local pos, rot = self:getCamTransForm(cam.getPosition(), cam.getRotation())
        cam.setPosition(pos)
        cam.setRotation(rot)
    elseif action == 9 then
        self.network:sendToServer("sv_onDeath", DAMAGESOURCE.genericProjectile)
    elseif action == 10 then
        self.network:sendToServer(
            "sv_takeDamage",
            {
                damage = self.maxHealth * 0.1,
                source = DAMAGESOURCE.genericProjectile
            }
        )
    elseif action == 15 then
        self.network:sendToServer("sv_seat")
    elseif action == 16 then
        self.network:sendToServer("sv_takeOff")
    end

    return true
end

function SpaceShip:cl_seat(data)
    if data then
        cam.setCameraState(self.camMode == 1 and 2 or 3)
        local pos, rot = self:getCamTransForm(cam.getPosition(), cam.getRotation())
        cam.setPosition(pos)
        cam.setRotation(rot)
        cam.setFov(cam.getDefaultFov())

        g_spaceShip = self.harvestable
        self:cl_updateUI(data)
        self.survivalHud:open()
        self.hotbar:open()
    else
        g_spaceShip = nil
        cam.setCameraState(0)
        self.survivalHud:close()
        self.hotbar:close()
        self.cl_controls = self:getDefaultControls()
    end
end

function SpaceShip:cl_setEffectsState(effects, state)
    for k, v in pairs(effects) do
        if state then
            v:start()
        else
            v:stop()
        end
    end
end



function SpaceShip:getDefaultControls()
    return {
        [1] = false, --A
        [2] = false, --D
        [3] = false, --W
        [4] = false, --S
        [5] = false, --1 - Boost
                     --2 - Change Cam
        [7] = false, --3 - Primary
        [8] = false, --4 - Secondary
    }
end

function SpaceShip:verifyPacket(player)
    local char = self.harvestable:getSeatCharacter()
    return char and char:getPlayer() == player
end

function SpaceShip:clampTurnDir(x, y)
    local norm_x, norm_y = x, y
    local length = math.sqrt(norm_x^2 + norm_y^2)
    if length > self.turnLimit then
        local mult = self.turnLimit / length
        norm_x, norm_y = norm_x * mult, norm_y * mult
    end

    return norm_x, norm_y
end

function SpaceShip:getCamTransForm(camPos, camRot, dt)
    local pos, rot = self.harvestable.worldPosition, self.harvestable.worldRotation
    local fwd = rot * VEC3_UP
    local up = rot * VEC3_FWD
    local shipRot = rot * ROTADJUST

    if dt then
        local lerpSpeed = dt * self.camLerpSpeed
        return vec3_lerp(camPos, pos, lerpSpeed), nlerp(camRot, shipRot, lerpSpeed), pos, rot, fwd, up, shipRot
    end

    return pos, shipRot, pos, rot, fwd, up, shipRot
end

function SpaceShip:getExitPos()
    return self.harvestable.worldPosition
end



---@class Fighter : SpaceShip
Fighter = class(SpaceShip)
Fighter.name = "Fighter"

Fighter.maxPrimaryAmmo = 20
Fighter.primaryRechargeTicks = 8
Fighter.primaryCooldownTicks = 10
Fighter.primaryProjectile = PROJECTILE["default_primary"]

Fighter.maxSecondaryAmmo = 4
Fighter.secondaryRechargeTicks = 60
Fighter.secondaryCooldownTicks = 20
Fighter.secondaryProjectile = PROJECTILE["default_secondary"]

Fighter.aimAssistDistance = 250
Fighter.aimAssistRadius = 1

function Fighter:sv_fireProjectile(args, player)
    --if not self:verifyPacket(player) then return end

    local pos = args.pos
    sm.event.sendToTool(
        g_pManager,
        "sv_createProjectile",
        {
            pos = pos,
            dir = args.dir,
            properties = args.projectile,
            owner = args.owner
        }
    )
    sm.effect.playEffect("Beam_shoot", pos)
end



function Fighter:client_onCreate()
    SpaceShip.client_onCreate(self)

    self.primaryTimer = Timer()
    self.primaryTimer:start(self.primaryCooldownTicks)
    self.primaryTimer.count = self.primaryTimer.ticks
    self.primaryRechargeTimer = Timer()
    self.primaryRechargeTimer:start(self.primaryRechargeTicks)
    self.primaryAmmo = self.maxPrimaryAmmo
    self.canFirePrimary = true

    self.secondaryTimer = Timer()
    self.secondaryTimer:start(self.secondaryCooldownTicks)
    self.secondaryTimer.count = self.secondaryTimer.ticks
    self.secondaryRechargeTimer = Timer()
    self.secondaryRechargeTimer:start(self.secondaryRechargeTicks)
    self.secondaryAmmo = self.maxSecondaryAmmo
    self.canFireSecondary = true

    self.primaryCounter = 0
end

function Fighter:client_onFixedUpdate(dt)
    local char, isLocal = SpaceShip.client_onFixedUpdate(self, dt)
    if not isLocal then return end

    self.primaryTimer:tick()
    self.secondaryTimer:tick()

    local primary, secondary = self.cl_controls[7], self.cl_controls[8]
    local canFirePrimary = primary and self.primaryTimer:done() and self.canFirePrimary
    local canFireSecondary = secondary and self.secondaryTimer:done() and self.canFireSecondary
    if self.cl_beInSpace then
        if canFirePrimary then
            local dir, right, up = cam.getDirection(), cam.getRight(), cam.getUp()
            local firePos = self:getPrimaryFirePos(dir, right, up)
            local camPos = cam.getPosition() + self.velocity
            local hit, result = sm.physics.spherecast(
                camPos, camPos + dir * self.aimAssistDistance,
                self.aimAssistRadius, self.harvestable,
                PROJECTILERAYCASTFILTER
            )

            if hit then
                dir = (result.pointWorld - firePos):normalize()
            end

            self.network:sendToServer(
                "sv_fireProjectile",
                {
                    pos = firePos, dir = dir,
                    owner = self.harvestable, projectile = self.primaryProjectile
                }
            )

            self.primaryTimer:reset()
            self.primaryAmmo = self.primaryAmmo - 1
            self.canFirePrimary = self.primaryAmmo > 0

            self.primaryCounter = self.primaryCounter + 1
        end

        if canFireSecondary then
            local dir, right, up = cam.getDirection(), cam.getRight(), cam.getUp()
            local firePos = self:getSecondaryFirePos(dir, right, up)

            self.network:sendToServer(
                "sv_fireProjectile",
                {
                    pos = firePos, dir = dir,
                    owner = self.harvestable, projectile = self.secondaryProjectile
                }
            )

            self.secondaryTimer:reset()
            self.secondaryAmmo = self.secondaryAmmo - 1
            self.canFireSecondary = self.secondaryAmmo > 0
        end
    end

    if not primary or not self.canFirePrimary then
        self.primaryRechargeTimer:tick()
        if self.primaryRechargeTimer:done() then
            self.primaryRechargeTimer:reset()
            self.primaryAmmo = sm.util.clamp(self.primaryAmmo + 1, 0, self.maxPrimaryAmmo)

            if self.primaryAmmo >= self.maxPrimaryAmmo then
                self.canFirePrimary = true
            end
        end
    end

    if not secondary or not self.canFireSecondary then
        self.secondaryRechargeTimer:tick()
        if self.secondaryRechargeTimer:done() then
            self.secondaryRechargeTimer:reset()
            self.secondaryAmmo = sm.util.clamp(self.secondaryAmmo + 1, 0, self.maxSecondaryAmmo)

            if self.secondaryAmmo >= self.maxSecondaryAmmo then
                self.canFireSecondary = true
            end
        end
    end
end

function Fighter:client_onUpdate(dt)
    local char, isLocal = SpaceShip.client_onUpdate(self, dt)
    if not isLocal then return end

    self:displayAmmo()
end



function Fighter:getPrimaryFirePos(fwd, right, up)
    return self.harvestable.worldPosition + self.harvestable.worldRotation * VEC3_UP + self.velocity
end

function Fighter:getSecondaryFirePos(fwd, right, up)
    return self.harvestable.worldPosition + self.harvestable.worldRotation * VEC3_UP + self.velocity
end

function Fighter:displayAmmo()
    local max = self.maxPrimaryAmmo
    local fraction = (max - self.primaryAmmo)/max
    sm.gui.setProgressFraction(fraction)

    if not self.canFirePrimary then
        local col = ColourLerp(COLOR_WHITE, COLOR_OVERHEAT, fraction)
        sm.gui.displayAlertText(string.format("#%sOVERHEATED!", col:getHexStr():sub(1,6)), 1)
    end
end



---@class Bomber : SpaceShip
Bomber = class(SpaceShip)
Bomber.name = "Bomber"

---@class Carrier : SpaceShip
Carrier = class(SpaceShip)
Carrier.name = "Carrier"



---@class TieFighter : Fighter
TieFighter = class(Fighter)
TieFighter.name = "TIE Fighter"
TieFighter.destroyEffect = "TieFighter_explode"
TieFighter.landOffset = 2.54
TieFighter.primaryProjectile = PROJECTILE["TieFighter_primary"]
TieFighter.collisionData = {
    {
        scale = sm.vec3.new(0.25, 3.75, 5),
        getTransform = function(pos, rot)
            return pos + rot * VEC3_RIGHT * 2, rot
        end
    },
    {
        scale = sm.vec3.new(0.25, 3.75, 5),
        getTransform = function(pos, rot)
            return pos - rot * VEC3_RIGHT * 2, rot
        end
    },
    {
        scale = sm.vec3.new(4, 1.9, 1.9),
        getTransform = function(pos, rot)
            return pos, rot
        end
    }
}
TieFighter.thrustEffectData = {
    {
        effect = "Thruster - Level 5",
        getOffsets = function()
            return -VEC3_UP * 0.5 - VEC3_FWD * 0.4, ROT_FWD_BWD
        end
    },
    {
        effect = "Thruster - Level 5",
        getOffsets = function()
            return -VEC3_UP * 0.5 + VEC3_FWD * 0.4, ROT_FWD_BWD
        end
    }
}
TieFighter.boostEffectData = {
    function() return VEC3_RIGHT *  2 + VEC3_FWD * 2.5 - VEC3_UP * 1.5 end,
    function() return VEC3_RIGHT * -2 + VEC3_FWD * 2.5 - VEC3_UP * 1.5 end,
    function() return VEC3_RIGHT *  2 - VEC3_FWD * 2.5 - VEC3_UP * 1.5 end,
    function() return VEC3_RIGHT * -2 - VEC3_FWD * 2.5 - VEC3_UP * 1.5 end,
}

function TieFighter:getExitPos()
    return self.harvestable.worldPosition - self.harvestable.worldRotation * VEC3_UP * 1.5
end

function TieFighter:getCamTransForm(camPos, camRot, dt)
    local pos, rot = self.harvestable.worldPosition + self.velocity, self.harvestable.worldRotation
    local fwd = rot * VEC3_UP
    local up = rot * VEC3_FWD
    local shipRot = rot * ROTADJUST

    local newPos, newRot
    local lerpSpeed = (dt or 0) * self.camLerpSpeed
    if self.camMode == 1 then
        local nextPos = pos + fwd * 0.25 --2
        newPos = dt and vec3_lerp(camPos, nextPos, lerpSpeed) or nextPos
    else
        local camDir = pos - camPos
        local distance = camDir:length()
        if self.cl_beInSpace and self.cl_nextInSpace and not self.cl_stunned then
            self.camPos = pos - camDir:normalize() * 5 + up * 2
        else
            self.camPos = pos - fwd * 5 + up * 2
        end

        local hit, result = sm.physics.raycast(pos, self.camPos, self.harvestable, CAMERAFILTER)
        if hit then
            newPos = result.pointWorld + result.normalWorld * 0.5
        else
            newPos = dt and vec3_lerp(camPos, self.camPos, dt * (distance / 6.25) * 3 ) or self.camPos
        end
    end
    newRot = dt and nlerp(camRot, shipRot, lerpSpeed) or shipRot

    return newPos, newRot, pos, rot, fwd, up, shipRot
end

function TieFighter:getPrimaryFirePos(fwd, right, up)
    local origin = self.harvestable.worldPosition + self.harvestable.worldRotation * VEC3_UP + self.velocity
    return origin - up + right * (self.primaryCounter%2 == 0 and 1 or -1) * 0.75
end



---@class XWing : Fighter
XWing = class(Fighter)
XWing.name = "X-Wing"
XWing.destroyEffect = "XWing_explode"
XWing.primaryProjectile = PROJECTILE["TieFighter_primary"]
XWing.landOffset = 0.9
XWing.hasTakeOffAnim = true
XWing.poseWeightCount = 1

XWing.healthRegen = 10

local anglePlus = angleAxis(math.rad(12), VEC3_UP)
local angleMinu = angleAxis(math.rad(-12), VEC3_UP)
XWing.collisionData = {
    {
        scale = sm.vec3.new(4.25, 2.5, 0.5),
        getTransform = function(pos, rot)
            return pos + rot * VEC3_RIGHT * 2.75 - rot * VEC3_UP * 3, rot
        end
    },
    {
        scale = sm.vec3.new(1.25, 10.25, 1.25),
        getTransform = function(pos, rot)
            return pos - rot * VEC3_UP * 0.25, rot
        end
    },
    {
        scale = sm.vec3.new(4.25, 2.5, 0.5),
        getTransform = function(pos, rot)
            return pos - rot * VEC3_RIGHT * 2.75 - rot * VEC3_UP * 3, rot
        end
    }
}
XWing.thrustEffectData = {
    {
        effect = "Thruster - Level 5",
        getOffsets = function()
            return anglePlus * (-VEC3_UP * 5.15 + VEC3_RIGHT * 1.225 + VEC3_FWD * 0.45), ROT_FWD_BWD
        end
    },
    {
        effect = "Thruster - Level 5",
        getOffsets = function()
            return anglePlus * (-VEC3_UP * 5.15 - VEC3_RIGHT * 1.225 - VEC3_FWD * 0.45), ROT_FWD_BWD
        end
    },
    {
        effect = "Thruster - Level 5",
        getOffsets = function()
            return angleMinu * (-VEC3_UP * 5.15 + VEC3_RIGHT * 1.225 - VEC3_FWD * 0.45), ROT_FWD_BWD
        end
    },
    {
        effect = "Thruster - Level 5",
        getOffsets = function()
            return angleMinu * (-VEC3_UP * 5.15 - VEC3_RIGHT * 1.225 + VEC3_FWD * 0.45), ROT_FWD_BWD
        end
    }
}
XWing.boostEffectData = {
    function() return anglePlus * (VEC3_RIGHT *  4.69 + VEC3_FWD * 0.185 - VEC3_UP * 4) end,
    function() return anglePlus * (VEC3_RIGHT * -4.69 - VEC3_FWD * 0.185 - VEC3_UP * 4) end,
    function() return angleMinu * (VEC3_RIGHT *  4.69 - VEC3_FWD * 0.185 - VEC3_UP * 4) end,
    function() return angleMinu * (VEC3_RIGHT * -4.69 + VEC3_FWD * 0.185 - VEC3_UP * 4) end,
}


function XWing:getExitPos()
    return self.harvestable.worldPosition - self.harvestable.worldRotation * VEC3_RIGHT * 2
end

function XWing:getCamTransForm(camPos, camRot, dt)
    local pos, rot = self.harvestable.worldPosition + self.velocity, self.harvestable.worldRotation
    local fwd = rot * VEC3_UP
    local up = rot * VEC3_FWD
    local shipRot = rot * ROTADJUST

    local newPos, newRot
    local lerpSpeed = (dt or 0) * self.camLerpSpeed
    if self.camMode == 1 then
        local nextPos = pos + up * 0.5 - fwd * 0.5 - self.velocity * 0.75
        newPos = dt and vec3_lerp(camPos, nextPos, lerpSpeed) or nextPos
    else
        local camDir = pos - camPos
        local distance = camDir:length()
        if self.cl_beInSpace and self.cl_nextInSpace and not self.cl_stunned then
            self.camPos = pos - camDir:normalize() * 10 + up
        else
            self.camPos = pos - fwd * 10 + up * 1.5
        end

        local hit, result = sm.physics.raycast(pos, self.camPos, self.harvestable, CAMERAFILTER)
        if hit then
            newPos = result.pointWorld + result.normalWorld * 0.5
        else
            newPos = dt and vec3_lerp(camPos, self.camPos, dt * (distance / 6.25) * 3 ) or self.camPos
        end
    end
    newRot = dt and nlerp(camRot, shipRot, lerpSpeed) or shipRot

    return newPos, newRot, pos, rot, fwd, up, shipRot
end

function XWing:getPrimaryFirePos(fwd, right, up)
    if self.primaryCounter >= 5 then self.primaryCounter = 1 end

    local origin = self.harvestable.worldPosition + self.harvestable.worldRotation * VEC3_UP + self.velocity
    if self.primaryCounter%4 == 0 then
        return origin - anglePlus * (up * 0.75 + right * 4.69)
    elseif self.primaryCounter%3 == 0 then
        return origin + anglePlus * (up * 0.75 + right * 4.69)
    elseif self.primaryCounter%2 == 0 then
        return origin - angleMinu * (up * 0.75 - right * 4.69)
    end

    return origin + angleMinu * (up * 0.75 - right * 4.69)
end