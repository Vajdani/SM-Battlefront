dofile "$CONTENT_DATA/Scripts/util.lua"

---@class LaserProjectile
---@field pos Vec3
---@field dir Vec3
---@field owner Character|Shape

---@class ProjectileManager : ToolClass
ProjectileManager = class()
ProjectileManager.lineStats = {
	thickness = 1,
	colour = sm.color.new(0,1,0)
}
ProjectileManager.laserSpeed = 250
ProjectileManager.laserLength = 2.5
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

function ProjectileManager:sv_onLaserHit( pos )
	sm.physics.explode( pos, 5, 2.5, 5, 50, "PropaneTank - ExplosionSmall" )
end



function ProjectileManager:client_onCreate()
    self.cl_projectiles = {}
end

---@param args LaserProjectile
function ProjectileManager:cl_createProjectile(args)
    local dir = args.dir
	local pos = args.pos + dir

	local laser = {
		line = Line_beam(),
		pos = pos,
		dir = dir,
		owner = args.owner,
		lifeTime = 15,
	}

	laser.line:init( self.lineStats.thickness, self.lineStats.colour )
	laser.line:update( pos, pos + laser.dir * self.laserLength, 0.16 )
	self.cl_projectiles[#self.cl_projectiles+1] = laser
end

function ProjectileManager:client_onUpdate(dt)
    for k, laser in pairs(self.cl_projectiles) do
		laser.lifeTime = laser.lifeTime - dt

		local currentPos, dir = laser.pos, laser.dir
		local hit, result = sm.physics.spherecast( currentPos, currentPos + dir * 2.5, 1 )
		if hit or laser.lifeTime <= 0 then
			if self.sv_host == true then
				self.network:sendToServer("sv_onLaserHit", result.pointWorld)
			end

			laser.line:destroy()
			self.cl_projectiles[k] = nil
		else
			local newPos = currentPos + dir * dt * self.laserSpeed * (hit and 0.1 or 1)
			laser.pos = newPos
			laser.line:update(newPos, newPos + dir * self.laserLength, dt)
		end
	end
end