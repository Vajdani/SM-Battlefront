dofile "$CONTENT_DATA/Scripts/util.lua"

---@class HitData
---@field pos Vec3
---@field ship Harvestable
---@field properties ProjectileProperties

---@class ProjectileGraphics
---@field effect string
---@field lineThickness number
---@field lineLength number
---@field lineColour number

---@class ExplosionStats
---@field level number
---@field destructionRadius number
---@field impulseRadius number
---@field magnitude number
---@field effect string

---@class ProjectileProperties
---@field graphics ProjectileGraphics
---@field speed number
---@field directDamage number
---@field explosionStats ExplosionStats
---@field hasGravity boolean
---@field type number

---@class Projectile
---@field pos Vec3
---@field dir Vec3
---@field line Line_beam
---@field effect Effect
---@field properties ProjectileProperties
---@field owner Character|Shape|Harvestable
---@field target Harvestable

---@class ProjectileManager : ToolClass
---@field cl_projectiles Projectile[]
ProjectileManager = class()
ProjectileManager.lineStats = {
	thickness = 1,
	colour = sm.color.new(0,1,0)
}
ProjectileManager.projLength = 2.5
ProjectileManager.killTypes = {
	terrainSurface = true,
	terrainAsset = true,
	limiter = true
}

function ProjectileManager:server_onCreate()
    g_pManager = self.tool

    self.sv_host = true
end

function ProjectileManager:sv_createProjectile(args)
    self.network:sendToClients("cl_createProjectile", args)
end

---@param args HitData
function ProjectileManager:sv_onProjectileHit( args )
	local properties = args.properties
	local _type = properties.type

	local pos = args.pos
	local explode = properties.explosionStats
	local level = explode.level
	if level then
		local destRadius = explode.destructionRadius
		sm.physics.explode(
			pos, level,
			destRadius,
			explode.impulseRadius,
			explode.magnitude,
			explode.effect
		)

		local harvestables = sm.physics.getSphereContacts(pos, destRadius).harvestables
		for k, v in pairs(harvestables) do
			if v:hasSeat() then
				sm.event.sendToHarvestable(
					v, "sv_takeDamage",
					{
						damage = (destRadius / (v.worldPosition - pos):length()) * level,
						source = _type
					}
				)
			end
		end
	end

	if args.ship then
		sm.event.sendToHarvestable(
			args.ship, "sv_takeDamage",
			{
				damage = properties.directDamage,
				source = _type
			}
		)
	end
end



function ProjectileManager:client_onCreate()
    self.cl_projectiles = {}
end

---@param args Projectile
function ProjectileManager:cl_createProjectile(args)
    local dir = args.dir
	local pos = args.pos + dir
	local properties = args.properties

	local proj = {
		pos = pos,
		dir = dir,
		properties = properties,
		owner = args.owner,
		target = args.target,
		lifeTime = 15,
	}

	local graphics = properties.graphics
	if graphics.effect then
		local effect = sm.effect.createEffect(graphics.effect)
		effect:setPosition(pos)
		effect:setRotation(sm.vec3.getRotation(VEC3_UP, dir * -1))
		effect:start()
		proj.effect = effect
	else
		local line = Line_beam()
		line:init( graphics.lineThickness, graphics.lineColour )
		line:update( pos, pos + proj.dir * graphics.lineLength, 0.16 )

		proj.line = line
	end

	self.cl_projectiles[#self.cl_projectiles+1] = proj
end

function ProjectileManager:client_onUpdate(dt)
    for k, proj in pairs(self.cl_projectiles) do
		local properties = proj.properties
		proj.lifeTime = proj.lifeTime - dt

		local currentPos, dir = proj.pos, proj.dir
		if properties.hasGravity then
			local gravity = dt * 0.25
			currentPos = currentPos - VEC3_UP * gravity
			dir.z = sm.util.clamp(dir.z - gravity, -1, 1)
			dir = dir:normalize()
		end

		local hit, result = sm.physics.spherecast( currentPos, currentPos + dir * 2.5, 1, proj.owner )
		if hit or proj.lifeTime <= 0 then
			if self.sv_host == true then
				self.network:sendToServer(
					"sv_onProjectileHit",
					{
						pos = result.pointWorld,
						ship = result:getHarvestable(),
						properties = properties
					}
				)
			end

			if proj.effect then
				proj.effect:destroy()
			else
				proj.line:destroy()
			end

			self.cl_projectiles[k] = nil
		else
			local newPos = currentPos + dir * dt * properties.speed
			proj.pos = newPos

			local effect = proj.effect
			if effect then
				effect:setPosition(newPos)
				effect:setRotation(sm.vec3.getRotation(VEC3_UP, dir * -1))
			else
				proj.line:update(newPos, newPos + dir * properties.graphics.lineLength, dt)
			end
		end
	end
end