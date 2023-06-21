---@class SpaceShip : HarvestableClass
SpaceShip = class()
SpaceShip.slowedSpeed = 20
SpaceShip.cruiseSpeed = 40
SpaceShip.lightBoost = 90
SpaceShip.heavyBoost = 150
SpaceShip.acceleration = 1.5
SpaceShip.turnLimit = 0.4
SpaceShip.rollSpeed = 50

SpaceShip.maxBoostFuel = 4
SpaceShip.boostFuelDrain = 1
SpaceShip.boostFuelGain = 0.5
SpaceShip.boostThreshold = 0.25

SpaceShip.flyToSpeed = 1
SpaceShip.flyToTurnSpeed = 5

SpaceShip.posLerpSpeed = 25
SpaceShip.rotLerpSpeed = 2.5
SpaceShip.rollLerpSpeed = 2.5
SpaceShip.camLerpSpeed = 15

dofile "$CONTENT_DATA/Scripts/util.lua"

local cam = sm.camera
local angleAxis = sm.quat.angleAxis
local clamp = sm.util.clamp
local vec3_lerp = sm.vec3.lerp
local quat_slerp = sm.quat.slerp
local vec3_getrot = sm.vec3.getRotation

function SpaceShip:server_onCreate()
    self.sv_beInSpace = false
    self.sv_controls = self:getDefaultControls()
    self.speed = 0
    self.boostFuel = self.maxBoostFuel
    self.blockBoost = false
    self.stunned = false
    self.dir = { x = 0, y = 0, z = 0 }

    self.knockback = VEC3_ZERO
    self.angularVelocity = VEC3_ZERO

    self.flyTo = {
        startPos = nil, startRot = nil,
        endPos = nil, endRot = nil,
        progress = 0
    }
end

function SpaceShip:server_onMelee()
    self.harvestable:destroy()
end

function SpaceShip:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    if not sm.exists(other) then return end

    local _type = type(other)
    if _type == "Character" then return end

    if _type == "Shape" then
        if (other:getBoundingBox() * 4):length() < 16 then return end
    end

    self.stunned = true
    self.speed = 0
    self.knockback = normal * 50
    --self.angularVelocity = normal:cross(self.harvestable.worldRotation * VEC3_RIGHT)

    --[[local pos, rot = self.harvestable.worldPosition, self.harvestable.worldRotation
    self.flyTo = {
        startPos = pos, startRot = rot,
        endPos = pos + normal * 5, endRot = rot,
        progress = 0
    }]]
end

function SpaceShip:server_onFixedUpdate(dt)
    local char = self.harvestable:getSeatCharacter()
    local destination = self.flyTo.endPos
    if destination then
        self.flyTo.progress = clamp(self.flyTo.progress + dt * self.flyToSpeed, 0, 1)
        local progress = sm.util.easing("easeInOutQuad", self.flyTo.progress)
        local newPos = vec3_lerp(self.flyTo.startPos, destination, progress)
        self.harvestable:setPosition(newPos)

        local endRot = self.flyTo.endRot
        if endRot then
            self.harvestable:setRotation(quat_slerp(self.flyTo.startRot, endRot, progress))
        else
            local norm_x, norm_y = self:clampTurnDir(self.dir.x, self.dir.y)
            local charDir = angleAxis(norm_x, VEC3_FWD) * angleAxis(norm_y, VEC3_RIGHT)
            local rot = self.harvestable.worldRotation
            self.harvestable:setRotation(quat_slerp(rot, rot * charDir, dt * self.flyToTurnSpeed))
        end

        if self.flyTo.progress >= 1 then
            self.harvestable:setPosition(destination)
            self.harvestable:setRotation(endRot or self.harvestable.worldRotation)

            self.flyTo = {
                startPos = nil, startRot = nil,
                endPos = nil, endRot = nil,
                progress = 0
            }
            self.sv_beInSpace = self.nextInSpace
            self.network:setClientData({ beInSpace = self.sv_beInSpace })
        end
    elseif char and self.sv_beInSpace then
        local pos, rot = self.harvestable.worldPosition, self.harvestable.worldRotation
        if self.stunned then
            self.harvestable:setPosition(vec3_lerp(pos, pos + self.knockback * dt, dt * self.posLerpSpeed))
            --self.harvestable:setRotation(quat_slerp(rot, rot * angleAxis(math.rad(5), self.angularVelocity), dt * self.posLerpSpeed))

            self.knockback = self.knockback - self.knockback * dt * 10
            --self.angularVelocity = self.angularVelocity - self.angularVelocity * dt * 10
            if self.knockback:length() <= 1 then
                self.stunned = false
            end
        else
            local speed = self.cruiseSpeed
            local canBoost = self.sv_controls[5] and not self.blockBoost
            if self.sv_controls[3] then
                if canBoost then
                    self.boostFuel = clamp(self.boostFuel - dt * self.boostFuelDrain, 0, self.maxBoostFuel)
                    if self.boostFuel > 0 then
                        speed = self.heavyBoost
                    else
                        self.blockBoost = true
                    end
                else
                    if self.boostFuel >= self.maxBoostFuel * self.boostThreshold then
                        self.blockBoost = false
                    end

                    speed = self.lightBoost
                end
            elseif self.sv_controls[4] then
                speed = self.slowedSpeed
            end

            self.speed = sm.util.lerp(self.speed, speed, dt * self.acceleration)

            if not canBoost then
                self.boostFuel = clamp(self.boostFuel + dt * self.boostFuelGain, 0, self.maxBoostFuel)
            end

            local newPos = pos + rot * VEC3_UP * round(self.speed) * dt
            self.harvestable:setPosition(vec3_lerp(pos, newPos, dt * self.posLerpSpeed))

            local norm_x, norm_y = self:clampTurnDir(self.dir.x, self.dir.y)
            self.dir.z = sm.util.lerp(self.dir.z, bVal(self.sv_controls[2]) - bVal(self.sv_controls[1]), dt * self.rollLerpSpeed)
            local charDir = angleAxis(norm_x, VEC3_FWD) * angleAxis(norm_y, VEC3_RIGHT) * angleAxis(math.rad(self.dir.z * self.rollSpeed), VEC3_UP)
            self.harvestable:setRotation(quat_slerp(rot, rot * charDir, dt * self.rotLerpSpeed))
        end
    end

    return char
end

---@param player Player
function SpaceShip:sv_dismount(args, player)
    if not self:verifyPacket(player) then return end

    if self:sv_takeOff(false, player) then
        local char = player.character
        self.harvestable:setSeatCharacter(char)

        local rot = self.harvestable.worldRotation
        player:setCharacter(
            sm.character.createCharacter(
                player,
                char:getWorld(),
                self.harvestable.worldPosition - rot * VEC3_FWD * 2,
                GetYawPitch(rot * VEC3_UP)
            )
        )

        self.network:sendToClient(player, "cl_dismount", true)
        self.sv_controls = self:getDefaultControls()
    end
end

function SpaceShip:sv_updateControls(controls, player)
    if not self:verifyPacket(player) then return end

    self.sv_controls = controls
end

function SpaceShip:sv_updateDir(dir, player)
    if not self:verifyPacket(player) --[[or not self.sv_beInSpace or not self.nextInSpace]] then return end

    self.dir.x = clamp(self.dir.x + dir.x, -self.turnLimit, self.turnLimit)
    self.dir.y = clamp(self.dir.y - dir.y, -self.turnLimit, self.turnLimit)
end

function SpaceShip:sv_takeOff(state, player)
    if not self:verifyPacket(player) or self.flyTo.endPos then return false end

    local new
    if state ~= nil then
        if not state and not self.nextInSpace and not self.sv_beInSpace then
            return true
        end

        new = state
    else
        new = not self.sv_beInSpace
    end

    local dir = (new and VEC3_UP or -VEC3_UP) * 25
    local pos = self.harvestable.worldPosition
    local hit, result = sm.physics.spherecast(pos, pos + dir, 2.5, self.harvestable, LANDRAYCASTFILTER)
    if new then
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
        --local fwd = rot * VEC3_UP; fwd.z = 0; fwd = fwd:normalize()
        self.flyTo = {
            startPos = pos, startRot = rot,
            endPos = result.pointWorld + normal * 2.54,
            endRot = LookRot(normal, rot * VEC3_FWD) * ROTADJUST, --vec3_getrot(VEC3_FWD, fwd) * ROTADJUST,
            progress = 0
        }

        self.speed = 0
        --self.dir = { x = 0, y = 0, z = 0 }
        self.sv_controls = self:getDefaultControls()
    end

    self.nextInSpace = new

    return true
end



function SpaceShip:client_onCreate()
    self.cl_controls = self:getDefaultControls()
    self.cl_beInSpace = false
    self.cl_dir = { x = 0, y = 0 }
    self.camMode = 2

    self.effect1 = sm.effect.createEffect("Thruster - Level 5", self.harvestable)
    self.effect2 = sm.effect.createEffect("Thruster - Level 5", self.harvestable)

    local fwd = VEC3_UP * -1
    local right = VEC3_RIGHT * 0.5
    self.effect1:setOffsetPosition(fwd + right)
    self.effect2:setOffsetPosition(fwd - right)

    local effectRot = vec3_getrot(VEC3_UP, fwd)
    self.effect1:setOffsetRotation(effectRot)
    self.effect2:setOffsetRotation(effectRot)

    self.indicator = Line_indicator()
    self.indicator:init(0.05, sm.color.new(0,1,0))

    self.lastPos = self.harvestable.worldPosition
end

function SpaceShip:client_onDestroy()
    self:cl_dismount(true)
    self.indicator:destroy()
end

function SpaceShip:client_onClientDataUpdate(data)
    self.cl_beInSpace = data.beInSpace
end

function SpaceShip:client_onUpdate(dt)
    local char = self.harvestable:getSeatCharacter()
    local playing = self.effect1:isPlaying()
    local shouldPlay = false --char and self.cl_beInSpace
    if shouldPlay and not playing then
        self.effect1:start()
        self.effect2:start()
    elseif not shouldPlay and playing then
        self.effect1:stop()
        self.effect2:stop()
    end

    if not char or char:getPlayer() ~= sm.localPlayer.getPlayer() then
        self.indicator:stop()
        return
    end

    local pos = self.harvestable.worldPosition
    --local vel = pos - self.lastPos
    --self.lastPos = pos
    --print(vel, vel:length())

    local rot = self.harvestable.worldRotation
    local shipRot = rot * ROTADJUST
    local lerpSpeed = dt * self.camLerpSpeed
    --local newPos = self:getCamPos(pos, rot)
    --cam.setPosition(vec3_lerp(cam.getPosition(), newPos, lerpSpeed))
    --cam.setRotation(nlerp(cam.getRotation(), rot * ROTADJUST, lerpSpeed))

    local fwd = rot * VEC3_UP
    local up = rot * VEC3_FWD
    local camPos = cam.getPosition()
    local newPos
    local newRot
    if self.camMode == 1 then
        newPos = vec3_lerp(camPos, pos + fwd * 2, lerpSpeed)
        newRot = nlerp(cam.getRotation(), shipRot, lerpSpeed)
    else
        local camDir = pos - camPos
        local distance = camDir:length()
        if self.cl_beInSpace then
            if distance > 5 then
                self.camPos = pos - camDir:normalize() * 4 + up
            end
        else
            self.camPos = pos - fwd * 5 + up * 2
        end

        newPos = vec3_lerp(camPos, self.camPos, dt * (distance / 6.25) * 3 )
        local lookAt = pos + fwd * 10
        newRot = nlerp(cam.getRotation(), LookRot(lookAt - self.camPos, up) * ROTADJUST, lerpSpeed)
    end

    cam.setPosition(newPos)
    cam.setRotation(newRot)

    --[[local lerpSpeed = dt * self.camLerpSpeed
    local camPos, camRot = cam.getPosition(), cam.getRotation()
    local newPos, newRot, pos, rot, fwd, up, shipRot = self:getCamTransForm(camPos, camRot)
    newPos = vec3_lerp(camPos, newPos, lerpSpeed)
    cam.setPosition(newPos)
    cam.setRotation(nlerp(camRot, newRot, lerpSpeed))]]

    cam.setFov(sm.util.lerp(sm.camera.getFov(), cam.getDefaultFov() * (1 + (self.speed / self.heavyBoost) * 0.25), lerpSpeed))
    sm.gui.displayAlertText(tostring(round(self.speed)).." | ".. tostring(string.format("%0.3f",self.boostFuel)), 1)

    local norm_x, norm_y = self:clampTurnDir(self.cl_dir.x, self.cl_dir.y)
    local camFwd = cam.getDirection()
    local charDir = angleAxis(norm_x, up) * angleAxis(norm_y, rot * VEC3_RIGHT) * camFwd
    local mul = 1
    self.indicator:update(newPos + camFwd * mul, newPos + charDir * mul, newRot)
end

function SpaceShip:client_onFixedUpdate()
    local char = self.harvestable:getSeatCharacter()
    if not char or char:getPlayer() ~= sm.localPlayer.getPlayer() then
        return
    end

    local x, y = sm.localPlayer.getMouseDelta()
    if x ~= 0 or y ~= 0 then
        self.network:sendToServer("sv_updateDir", { x = x, y = y })

        self.cl_dir.x = clamp(self.cl_dir.x + x, -self.turnLimit, self.turnLimit)
        self.cl_dir.y = clamp(self.cl_dir.y - y, -self.turnLimit, self.turnLimit)
    end
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
    cam.setCameraState(3)

    local pos, rot = self:getCamTransForm(cam.getPosition(), cam.getRotation())
    cam.setPosition(pos)
    cam.setRotation(rot)

    cam.setFov(cam.getDefaultFov())

    g_spaceShip = self.harvestable
    sm.tool.forceTool(g_input)
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
    elseif action == 15 then
        self.network:sendToServer("sv_dismount")
    elseif action == 16 then
        self.network:sendToServer("sv_takeOff")
    end

    return true
end

function SpaceShip:cl_dismount(exit)
    cam.setCameraState(0)

    if exit == true then
        g_spaceShip = false
        sm.tool.forceTool(nil)
        self.cl_controls = self:getDefaultControls()
    end
end

function SpaceShip:cl_mouseClick(args)
    self.cl_controls[18] = args[18]
    self.cl_controls[19] = args[19]
    self.network:sendToServer("sv_updateControls", self.cl_controls)
end



function SpaceShip:getDefaultControls()
    return {
        false, false, false, false,
        [5] = false,
        [7] = false,
        [8] = false,
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

function SpaceShip:getCamPos(pos, rot)
    local newPos
    if self.camMode == 1 then
        newPos = pos + rot * VEC3_UP * 2
    else
        newPos = pos - rot * VEC3_UP * 7.5 + rot * VEC3_FWD * 2.5
    end

    return newPos
end

function SpaceShip:getCamTransForm(camPos, camRot)
    local pos, rot = self.harvestable.worldPosition, self.harvestable.worldRotation
    local fwd = rot * VEC3_UP
    local up = rot * VEC3_FWD
    local shipRot = rot * ROTADJUST

    local newPos, newRot
    if self.camMode == 1 then
        newPos = pos + fwd * 2
        newRot = shipRot
    else
        local camDir = pos - camPos
        local distance = camDir:length()
        if self.cl_beInSpace then
            if distance > 5 then
                self.camPos = pos - camDir:normalize() * 4 + up
            end
        else
            self.camPos = pos - fwd * 5 + up * 2
        end

        newPos = self.camPos
        local lookAt = pos + fwd * 10
        newRot = LookRot(lookAt - self.camPos, up) * ROTADJUST
    end

    return newPos, newRot, pos, rot, fwd, up, shipRot
end



---@class Fighter : SpaceShip
Fighter = class(SpaceShip)

function Fighter:server_onCreate()
    SpaceShip.server_onCreate(self)

    self.primaryTimer = Timer()
    self.primaryTimer:start(10)
    self.primaryCounter = 0

    local pos, rot = self.harvestable.worldPosition, self.harvestable.worldRotation
    local wingOffset = rot * VEC3_RIGHT * 2
    local filter = sm.areaTrigger.filter.harvestable + sm.areaTrigger.filter.staticBody
    self.colTrig = sm.areaTrigger.createBox(sm.vec3.new(0.25, 3.75, 5), pos + wingOffset, QUAT_ZERO, filter)
    self.colTrig2 = sm.areaTrigger.createBox(sm.vec3.new(0.25, 3.75, 5), pos - wingOffset, QUAT_ZERO, filter)
    self.colTrig3 = sm.areaTrigger.createBox(sm.vec3.new(4, 1.9, 1.9), pos, QUAT_ZERO, filter)

    self.colTrig:bindOnEnter("sv_onCollision")
    self.colTrig2:bindOnEnter("sv_onCollision")
    self.colTrig3:bindOnEnter("sv_onCollision")
end

function Fighter:sv_onCollision(trigger, result)
    local colPos = trigger:getWorldPosition()
    for k, obj in pairs(result) do
        if obj ~= self.harvestable then
            if sm.exists(obj) and type(obj) ~= "Shape" or (obj:getBoundingBox() * 4):length() >= 16 then
                self.stunned = true
                self.speed = 0
                self.knockback = (self.harvestable.worldPosition - obj.worldPosition):normalize() * 50
            end
        end
    end
end

function Fighter:server_onFixedUpdate(dt)
    local pos, rot = self.harvestable.worldPosition, self.harvestable.worldRotation
    local wingOffset = rot * VEC3_RIGHT * 2
    self.colTrig:setWorldPosition(pos + wingOffset)
    self.colTrig2:setWorldPosition(pos - wingOffset)
    self.colTrig3:setWorldPosition(pos)

    local shipRot = rot * ROTADJUST
    self.colTrig:setWorldRotation(shipRot)
    self.colTrig2:setWorldRotation(shipRot)
    self.colTrig3:setWorldRotation(shipRot)

    local char = SpaceShip.server_onFixedUpdate(self, dt)
    if not char then return end

    if self.sv_beInSpace or true then
        self.primaryTimer:tick()
        if self.sv_controls[7] then
            if self.primaryTimer:done() then
                local rot = self.harvestable.worldRotation
                local dir, right, up = rot * VEC3_UP, rot * VEC3_RIGHT, rot * VEC3_FWD
                local firePos = self.harvestable.worldPosition - up + right * (self.primaryCounter%2 == 0 and 1 or -1) * 0.75

                local hit, result = sm.physics.spherecast(firePos, firePos + dir * 100, 1, self.harvestable, LANDRAYCASTFILTER)
                if hit then
                    dir = (result.pointWorld - firePos):normalize()
                end

                sm.event.sendToTool(
                    g_pManager,
                    "sv_createProjectile",
                    {
                        pos = firePos,
                        dir = dir,
                        owner = char
                    }
                )
                sm.effect.playEffect("Beam_shoot", firePos)

                self.primaryTimer:reset()
                self.primaryCounter = self.primaryCounter + 1
            end
        else
            --self.primaryCounter = 0
        end

        if self.sv_controls[8] then
            print("pow")
        end
    end
end



--[[function Fighter:client_onCreate()
    SpaceShip.client_onCreate(self)

    self.visTrig = CreateVisualizedTrigger(
        self.harvestable.worldPosition + self.harvestable.worldRotation * VEC3_RIGHT * 2,
        sm.vec3.new(0.25, 3.75, 5)
    )
    self.visTrig.trigger:bindOnEnter("cl_onEnter", self)

    self.visTrig2 = CreateVisualizedTrigger(
        self.harvestable.worldPosition - self.harvestable.worldRotation * VEC3_RIGHT * 2,
        sm.vec3.new(0.25, 3.75, 5)
    )
    self.visTrig2.trigger:bindOnEnter("cl_onEnter", self)

    self.visTrig3 = CreateVisualizedTrigger(
        self.harvestable.worldPosition,
        sm.vec3.new(4, 1.9, 1.9)
    )
    self.visTrig3.trigger:bindOnEnter("cl_onEnter", self)
end

function Fighter:cl_onEnter(trigger, result)
    print(result)
end

function Fighter:client_onDestroy()
    SpaceShip.client_onDestroy(self)

    self.visTrig:destroy()
    self.visTrig2:destroy()
    self.visTrig3:destroy()
end

function Fighter:client_onUpdate(dt)
    SpaceShip.client_onUpdate(self, dt)

    local pos, rot = self.harvestable.worldPosition, self.harvestable.worldRotation
    local wingOffset = rot * VEC3_RIGHT * 2
    self.visTrig:setPosition(pos + wingOffset)
    self.visTrig2:setPosition(pos - wingOffset)
    self.visTrig3:setPosition(pos)

    local shipRot = rot * ROTADJUST
    self.visTrig:setRotation(shipRot)
    self.visTrig2:setRotation(shipRot)
    self.visTrig3:setRotation(shipRot)
end]]



---@class Bomber : SpaceShip
Bomber = class(SpaceShip)

---@class Carrier : SpaceShip
Carrier = class(SpaceShip)