dofile( "$GAME_DATA/Scripts/game/managers/CreativePathNodeManager.lua")
dofile( "$GAME_DATA/Scripts/game/worlds/CreativeBaseWorld.lua")
dofile( "$SURVIVAL_DATA/Scripts/game/managers/WaterManager.lua" )

World = class( CreativeBaseWorld )

World.terrainScript = "$GAME_DATA/Scripts/terrain/terrain_creative.lua"
World.isStatic = true
World.enableSurface = true
World.enableAssets = true
World.enableClutter = true
World.enableNodes = true
World.enableCreations = false
World.enableHarvestables = true
World.enableKinematics = false
World.cellMinX = -15
World.cellMaxX = 14
World.cellMinY = -15
World.cellMaxY = 14

function World.server_onCreate( self )
	CreativeBaseWorld.server_onCreate( self )

	self.waterManager = WaterManager()
	self.waterManager:sv_onCreate( self )

	self.sv = {}
	self.sv.pathNodeManager = CreativePathNodeManager()
	self.sv.pathNodeManager:sv_onCreate( self )
end

function World.client_onCreate( self )
	CreativeBaseWorld.client_onCreate( self )

	if self.waterManager == nil then
		assert( not sm.isHost )
		self.waterManager = WaterManager()
	end
	self.waterManager:cl_onCreate()
end

function World.server_onFixedUpdate( self )
	CreativeBaseWorld.server_onFixedUpdate( self )
	self.waterManager:sv_onFixedUpdate()
end

function World.client_onFixedUpdate( self )
	self.waterManager:cl_onFixedUpdate()
end

function World.client_onUpdate( self )
	g_effectManager:cl_onWorldUpdate( self )
end

function World.server_onCellCreated( self, x, y )
	self.waterManager:sv_onCellLoaded( x, y )
	self.sv.pathNodeManager:sv_loadPathNodesOnCell( x, y )
end

function World.client_onCellLoaded( self, x, y )
	self.waterManager:cl_onCellLoaded( x, y )
	g_effectManager:cl_onWorldCellLoaded( self, x, y )
end

function World.server_onCellLoaded( self, x, y )
	self.waterManager:sv_onCellReloaded( x, y )
end

function World.server_onCellUnloaded( self, x, y )
	self.waterManager:sv_onCellUnloaded( x, y )
end

function World.client_onCellUnloaded( self, x, y )
	self.waterManager:cl_onCellUnloaded( x, y )
	g_effectManager:cl_onWorldCellUnloaded( self, x, y )
end

--[[dofile( "$SURVIVAL_DATA/Scripts/game/managers/PesticideManager.lua" )

World = class()
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.worldBorder = true
World.isStatic = true

local size = 16
World.cellMinX = -size
World.cellMaxX = size - 1
World.cellMinY = -size
World.cellMaxY = size - 1


function World.server_onCreate( self )
	self.pesticideManager = PesticideManager()
	self.pesticideManager:sv_onCreate()
end

function World.client_onCreate( self )
	if self.pesticideManager == nil then
		assert( not sm.isHost )
		self.pesticideManager = PesticideManager()
	end
	self.pesticideManager:cl_onCreate()
end

function World.server_onFixedUpdate( self )
	self.pesticideManager:sv_onWorldFixedUpdate( self )
end

function World.cl_n_pesticideMsg( self, msg )
	self.pesticideManager[msg.fn]( self.pesticideManager, msg )
end

function World.server_onInteractableCreated( self, interactable )
	g_unitManager:sv_onInteractableCreated( interactable )
end

function World.server_onInteractableDestroyed( self, interactable )
	g_unitManager:sv_onInteractableDestroyed( interactable )
end

function World.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )
	-- Notify units about projectile hit
	if isAnyOf( projectileUuid, g_potatoProjectiles ) then
		local units = sm.unit.getAllUnits()
		for i, unit in ipairs( units ) do
			if InSameWorld( self.world, unit ) then
				sm.event.sendToUnit( unit, "sv_e_worldEvent", { eventName = "projectileHit", hitPos = hitPos, hitTime = hitTime, hitVelocity = hitVelocity, attacker = attacker, damage = damage })
			end
		end
	end

	if projectileUuid == projectile_pesticide then
		local forward = sm.vec3.new( 0, 1, 0 )
		local randomDir = forward:rotateZ( math.random( 0, 359 ) )
		local effectPos = hitPos
		local success, result = sm.physics.raycast( hitPos + sm.vec3.new( 0, 0, 0.1 ), hitPos - sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 ), nil, sm.physics.filter.static + sm.physics.filter.dynamicBody )
		if success then
			effectPos = result.pointWorld + sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 )
		end
		self.pesticideManager:sv_addPesticide( self, effectPos, sm.vec3.getRotation( forward, randomDir ) )
	end

	if projectileUuid == projectile_glowstick then
		sm.harvestable.createHarvestable( hvs_remains_glowstick, hitPos, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), hitVelocity:normalize() ) )
	end

	if projectileUuid == projectile_explosivetape then
		sm.physics.explode( hitPos, 7, 2.0, 6.0, 25.0, "RedTapeBot - ExplosivesHit" )
	end
end

function World.server_onCollision( self, objectA, objectB, collisionPosition, objectAPointVelocity, objectBPointVelocity, collisionNormal )
	g_unitManager:sv_onWorldCollision( self, objectA, objectB, collisionPosition, objectAPointVelocity, objectBPointVelocity, collisionNormal )
end]]