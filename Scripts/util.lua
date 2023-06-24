DEFAULTDIR = sm.vec3.new(0,1,0)
VEC3_UP = sm.vec3.new(0,0,1)
VEC3_FWD = sm.vec3.new(0,1,0)
VEC3_RIGHT = sm.vec3.new(1,0,0)
VEC3_ONE = sm.vec3.one()
VEC3_ZERO = sm.vec3.zero()
ROTADJUST = sm.quat.angleAxis(math.rad(90), VEC3_RIGHT) * sm.quat.angleAxis(math.rad(180), VEC3_FWD)
QUAT_ZERO = sm.quat.identity()
COLOR_WHITE = sm.color.new(1,1,1)
COLOR_OVERHEAT = sm.color.new("#ff7f00")

LANDABLESURFACES = {
    terrainSurface = true,
    terrainAsset = true,
    body = true
}
LANDRAYCASTFILTER = sm.physics.filter.terrainAsset + sm.physics.filter.terrainSurface + sm.physics.filter.staticBody + sm.physics.filter.harvestable
PROJECTILERAYCASTFILTER = sm.physics.filter.staticBody + sm.physics.filter.dynamicBody + sm.physics.filter.harvestable + sm.physics.filter.character

DAMAGESOURCE = {
    collision = 1,
    genericProjectile = 2,
    homingProjectile = 3,
    bomb = 4,
    projectile = 5,
    melee = 6
}

PROJECTILE = {
    ["default_primary"] = {
        graphics = {
            lineThickness = 1,
            lineLength = 2.5,
            lineColour = sm.color.new(1,1,1)
        },
        speed = 100,
        directDamage = 100,
        explosionStats = {},
        hasGravity = false,
        type = DAMAGESOURCE.genericProjectile
    },
    ["default_secondary"] = {
        graphics = {
            lineThickness = 1,
            lineLength = 2.5,
            lineColour = sm.color.new(0.5,0.5,0.5)
        },
        speed = 250,
        directDamage = 250,
        explosionStats = {
            level = 5,
            destructionRadius = 5,
            impulseRadius = 10,
            magnitude = 50,
            effect = "PropaneTank - ExplosionSmall"
        },
        hasGravity = false,
        type = DAMAGESOURCE.genericProjectile
    },
    ["TieFighter_primary"] = {
        graphics = {
            lineThickness = 1,
            lineLength = 2.5,
            lineColour = sm.color.new(0,1,0)
        },
        speed = 250,
        directDamage = 250,
        explosionStats = {},
        hasGravity = false,
        type = DAMAGESOURCE.genericProjectile
    },
    ["gravityTest"] = {
        graphics = {
            lineThickness = 1,
            lineLength = 2.5,
            lineColour = sm.color.new(1,0,0)
        },
        speed = 250,
        directDamage = 250,
        explosionStats = {
            level = 5,
            destructionRadius = 5,
            impulseRadius = 10,
            magnitude = 50,
            effect = "PropaneTank - ExplosionSmall"
        },
        hasGravity = true,
        type = DAMAGESOURCE.genericProjectile
    }
}

function bVal(bool)
    return bool and 1 or 0
end

function ColourLerp(c1, c2, t)
    local r = sm.util.lerp(c1.r, c2.r, t)
    local g = sm.util.lerp(c1.g, c2.g, t)
    local b = sm.util.lerp(c1.b, c2.b, t)
    return sm.color.new(r,g,b)
end



-- #region Thanks Questionable Mark
---@param vector Vec3
---@return Vec3 right
function calculateRightVector(vector)
    local yaw = math.atan(vector.y, vector.x) - math.pi / 2
    return sm.vec3.new(math.cos(yaw), math.sin(yaw), 0)
end

---@param vector Vec3
---@return Vec3 up
function calculateUpVector(vector)
    return calculateRightVector(vector):cross(vector)
end

function GetRotation(direction)
	local right = calculateRightVector(direction)
	return _GetRotation(direction, right, right:cross(direction))
end

function _GetRotation(forward, right, up)
    forward = forward:safeNormalize(sm.vec3.new(1, 0, 0))
    right   = right:safeNormalize(sm.vec3.new(0, 0, 1))
    up      = up:safeNormalize(sm.vec3.new(0, 1, 0))

    local m11 = right.x; local m12 = right.y; local m13 = right.z
    local m21 = forward.x; local m22 = forward.y; local m23 = forward.z
    local m31 = up.x; local m32 = up.y; local m33 = up.z

    local biggestIndex = 0
    local fourBiggestSquaredMinus1 = m11 + m22 + m33

    local fourXSquaredMinus1 = m11 - m22 - m33
    if fourXSquaredMinus1 > fourBiggestSquaredMinus1 then
        fourBiggestSquaredMinus1 = fourXSquaredMinus1
        biggestIndex = 1
    end

    local fourYSquaredMinus1 = m22 - m11 - m33
    if fourYSquaredMinus1 > fourBiggestSquaredMinus1 then
        fourBiggestSquaredMinus1 = fourYSquaredMinus1
        biggestIndex = 2
    end

    local fourZSquaredMinus1 = m33 - m11 - m22
    if fourZSquaredMinus1 > fourBiggestSquaredMinus1 then
        fourBiggestSquaredMinus1 = fourZSquaredMinus1
        biggestIndex = 3
    end

    local biggestVal = math.sqrt(fourBiggestSquaredMinus1 + 1.0) * 0.5
    local mult = 0.25 / biggestVal

    if biggestIndex == 1 then
        return sm.quat.new(biggestVal, (m12 + m21) * mult, (m31 + m13) * mult, (m23 - m32) * mult)
    elseif biggestIndex == 2 then
        return sm.quat.new((m12 + m21) * mult, biggestVal, (m23 + m32) * mult, (m31 - m13) * mult)
    elseif biggestIndex == 3 then
        return sm.quat.new((m31 + m13) * mult, (m23 + m32) * mult, biggestVal, (m12 - m21) * mult)
    end

    return sm.quat.new((m23 - m32) * mult, (m31 - m13) * mult, (m12 - m21) * mult, biggestVal)
end
-- #endregion

--Thanks TechnologicNick
function GetYawPitch( direction )
    return math.atan2(direction.y, direction.x) - math.pi/2, math.asin(direction.z)
end

function TargetRot(PosHun,PosTar)
    local relativeX = PosTar.x - PosHun.x
    local relativeY = -PosTar.y + PosHun.y
    local relativeZ = PosTar.z - PosHun.z
    local angleradY = math.atan2(relativeX, relativeZ)
    local relativeangY = math.deg(angleradY)
    local relativehori = math.sqrt(relativeX*relativeX+relativeZ*relativeZ)
    local angleradX = math.atan2(relativeY, relativehori)
    local relativeangX = math.deg(angleradX)
    local relativetot= sm.vec3.new(relativeangX,relativeangY,0)
    return relativetot
end

---@param forward Vec3
---@param up Vec3
function LookRot( forward, up )
    local vector = sm.vec3.normalize( forward )
    local vector2 = sm.vec3.normalize( sm.vec3.cross( up, vector ) )
    local vector3 = sm.vec3.cross( vector, vector2 )
    local m00 = vector2.x
    local m01 = vector2.y
    local m02 = vector2.z
    local m10 = vector3.x
    local m11 = vector3.y
    local m12 = vector3.z
    local m20 = vector.x
    local m21 = vector.y
    local m22 = vector.z
    local num8 = (m00 + m11) + m22
	local quaternion = sm.quat.identity()
    if num8 > 0 then
        local num = math.sqrt(num8 + 1)
        quaternion.w = num * 0.5
        num = 0.5 / num
        quaternion.x = (m12 - m21) * num
        quaternion.y = (m20 - m02) * num
        quaternion.z = (m01 - m10) * num
        return quaternion
    end
    if (m00 >= m11) and (m00 >= m22) then
        local num7 = math.sqrt(((1 + m00) - m11) - m22)
        local num4 = 0.5 / num7
        quaternion.x = 0.5 * num7
        quaternion.y = (m01 + m10) * num4
        quaternion.z = (m02 + m20) * num4
        quaternion.w = (m12 - m21) * num4
        return quaternion
    end
    if m11 > m22 then
        local num6 = math.sqrt(((1 + m11) - m00) - m22)
		local num3 = 0.5 / num6
        quaternion.x = (m10+ m01) * num3
        quaternion.y = 0.5 * num6
        quaternion.z = (m21 + m12) * num3
        quaternion.w = (m20 - m02) * num3
        return quaternion
    end
    local num5 = math.sqrt(((1 + m22) - m00) - m11)
    local num2 = 0.5 / num5
    quaternion.x = (m20 + m02) * num2
    quaternion.y = (m21 + m12) * num2
    quaternion.z = 0.5 * num5;
    quaternion.w = (m01 - m10) * num2
    return quaternion
end

-- #region quat lerp
-- https://stackoverflow.com/questions/46156903/how-to-lerp-between-two-quaternions
function dot(a, b)
    return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w;
end

function negate(a)
    return sm.quat.new(-a.x, -a.y, -a.z, -a.w);
end

function normalise(a)
    local l = 1.0 / math.sqrt(dot(a, a));
    return sm.quat.new(l*a.x, l*a.y, l*a.z, l*a.w);
end

function quat_lerp(a, b,t)
    -- negate second quat if dot product is negative
    local l2 = dot(a, b);
    if(l2 < 0.0) then
        b = negate(b);
    end
    local c = sm.quat.identity();
    -- c = a + t(b - a)  -->   c = a - t(a - b)
    -- the latter is slightly better on x64
    c.x = a.x - t*(a.x - b.x);
    c.y = a.y - t*(a.y - b.y);
    c.z = a.z - t*(a.z - b.z);
    c.w = a.w - t*(a.w - b.w);
    return c;
end

-- this is the method you want
function nlerp(a, b, t)
    return normalise(quat_lerp(a, b, t));
end
-- #endregion

-- #region Line_indicator
Line_indicator = class()
---@class Line_indicator
---@field init function
---@field update function
---@field stop function
---@field destroy function
function Line_indicator:init( thickness, colour )
    self.line = sm.effect.createEffect("ShapeRenderable")
	self.line:setParameter("uuid", sm.uuid.new("5827d49c-c710-4897-b75c-39792623a6b8"))
    self.line:setParameter("color", colour)
    self.line:setScale( VEC3_ONE * thickness )

    self.base = sm.effect.createEffect("ShapeRenderable")
	self.base:setParameter("uuid", sm.uuid.new("6ab9cd3f-2a8c-48d8-ac1a-514f87927604"))
    self.base:setParameter("color", colour)
    self.base:setScale( VEC3_ONE * thickness * 0.75 )

    self.thickness = thickness
end


---@param startPos Vec3
---@param endPos Vec3
function Line_indicator:update( startPos, endPos, shipRot )
	local delta = endPos - startPos
    local length = delta:length()

    if length < 0.0001 then
        self.line:stop()
    else
        self.line:setPosition(startPos + delta * 0.5)
	    self.line:setRotation(sm.vec3.getRotation(VEC3_RIGHT, delta))
	    self.line:setScale(sm.vec3.new(length, self.thickness, self.thickness))

        if not self.line:isPlaying() then
            self.line:start()
        end
	end

    self.base:setPosition(startPos)
	self.base:setRotation(shipRot)

    if not self.base:isPlaying() then
        self.base:start()
    end
end

function Line_indicator:stop()
	self.line:stopImmediate()
	self.base:stopImmediate()
end

function Line_indicator:destroy()
    self.line:destroy()
	self.base:destroy()
end
-- #endregion

-- #region Line_beam
---@class Line_beam
---@field init function
---@field update function
---@field stop function
---@field destroy function
Line_beam = class()
function Line_beam:init( thickness, colour )
    self.effect = sm.effect.createEffect("ShapeRenderable")
	self.effect:setParameter("uuid", sm.uuid.new("8ea315c3-23bc-448c-9feb-9a32ce39b7de"))
    self.effect:setParameter("color", colour)
    self.effect:setScale( VEC3_ONE * thickness )
	self.sound = sm.effect.createEffect( "Cutter_beam_sound" )

	self.colour = colour
    self.thickness = thickness
end


---@param startPos Vec3
---@param endPos Vec3
function Line_beam:update( startPos, endPos )
	local delta = endPos - startPos
    local length = delta:length()

    if length < 0.0001 then
        return
	end

	local rot = sm.vec3.getRotation(VEC3_RIGHT, delta)
	local distance = sm.vec3.new(length, self.thickness, self.thickness)
	self.effect:setPosition(startPos + delta * 0.5)
	self.effect:setScale(distance)
	self.effect:setRotation(rot)

	--this shit kills my gpu if its done every frame
	--[[if sm.game.getCurrentTick() % 2 == 0 then
		sm.particle.createParticle( "beam_impact", endPos, QUAT_ZERO, self.colour )
	end]]

	self.sound:setPosition(startPos)

    if not self.effect:isPlaying() then
        self.effect:start()
		self.sound:start()
    end
end

function Line_beam:stop()
	self.effect:stopImmediate()
	self.sound:stopImmediate()
end

function Line_beam:destroy()
	self.effect:destroy()
	self.sound:destroy()
end
-- #endregion

---@class VisualizedTrigger
---@field trigger AreaTrigger
---@field effect Effect
---@field setPosition function
---@field setRotation function
---@field setScale function
---@field destroy function
---@field setVisible function
---@field show function
---@field hide function

---Create an AreaTrigger that has a visualization
---@param position Vec3
---@param scale Vec3
---@return VisualizedTrigger
function CreateVisualizedTrigger(position, scale)
    local effect = sm.effect.createEffect("ShapeRenderable")
    effect:setParameter("uuid", blk_glass)
    effect:setParameter("visualization", true)
    effect:setScale(scale)
    effect:setPosition(position)
    effect:start()

    return {
        trigger = sm.areaTrigger.createBox(scale * 0.5, position),
        effect = effect,
        setPosition = function(self, position)
            self.trigger:setWorldPosition(position)
            self.effect:setPosition(position)
        end,
        setRotation = function(self, rotation)
            self.trigger:setWorldRotation(rotation)
            self.effect:setRotation(rotation)
        end,
        setScale = function(self, scale)
            self.trigger:setScale(scale * 0.5)
            self.effect:setScale(scale)
        end,
        destroy = function(self)
            sm.areaTrigger.destroy(self.trigger)
            self.effect:destroy()
        end,
        setVisible = function(self, state)
            if state then
                self.effect:start()
            else
                self.effect:stop()
            end
        end,
        show = function(self)
            self.effect:start()
        end,
        hide = function(self)
            self.effect:stop()
        end
    }
end