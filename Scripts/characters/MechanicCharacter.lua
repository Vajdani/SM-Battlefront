dofile( "$SURVIVAL_DATA/Scripts/game/characters/BaseCharacter.lua" )

---@class MechanicCharacter : CharacterClass
---@field animations table
---@field FPanimations table
---@field isLocal boolean
---@field graphicsLoaded boolean
---@field animationsLoaded boolean
---@field diveEffect Effect
---@field koEffect Effect
---@field blendSpeed number
---@field blendTime number
---@field currentAnimation string
---@field currentFPAnimation string
MechanicCharacter = class()

function MechanicCharacter.server_onCreate( self )

end

function MechanicCharacter.client_onCreate( self )
	print( "-- MechanicCharacter created --" )
	self.animations = {}
	self.isLocal = false

	self:client_onRefresh()
end

function MechanicCharacter.client_onDestroy( self )
	print( "-- MechanicCharacter destroyed --" )
end

function MechanicCharacter.client_onRefresh( self )
	print( "-- MechanicCharacter refreshed --" )
end

function MechanicCharacter:cl_updateLook()
	local class = self.character:getPlayer().clientPublicData.class
	if not class then return end

	if self.class and self.class ~= class then
		self.character:removeRenderable(GetClassData(self.class).model)
	end

    self.character:addRenderable(GetClassData(class).model)
	self.class = class
end

function MechanicCharacter.client_onGraphicsLoaded( self )
	self.isLocal = self.character:getPlayer() == sm.localPlayer.getPlayer()
	self.diveEffect = sm.effect.createEffect( "Mechanic underwater", self.character, "jnt_head" )
	self.koEffect = sm.effect.createEffect( "Mechanic - KoLoop", self.character, "jnt_head" )

	self.graphicsLoaded = true

	-- Third person animations
	self.animations = {}

	self.blendSpeed = 5.0
	self.blendTime = 0.2

	self.currentAnimation = ""

	-- First person animations
	if self.isLocal then
		self.FPanimations = {}
		self.currentFPAnimation = ""
	end
	self.animationsLoaded = true

	self:cl_updateLook()
end

function MechanicCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false
	if self.diveEffect then
		self.diveEffect:destroy()
		self.diveEffect = nil
	end
	if self.koEffect then
		self.koEffect:destroy()
		self.koEffect = nil
	end
end

function MechanicCharacter.client_onUpdate( self, deltaTime )
	if not self.graphicsLoaded then
		return
	end

	if self.character:isDowned() and not self.koEffect:isPlaying() then
		sm.effect.playEffect( "Mechanic - Ko", self.character.worldPosition )
		self.koEffect:start()
	elseif not self.character:isDowned() and self.koEffect:isPlaying() then
		self.koEffect:stop()
	end

	-- Control diving effect
	if self.diveEffect then
		if self.character:isDiving() then
			if not self.diveEffect:isPlaying() then
				self.diveEffect:start()
			end
		elseif not self.character:isDiving() then
			if self.diveEffect:isPlaying() then
				self.diveEffect:stop()
			end
		end
	end

	-- Third person animations
	for name, animation in pairs(self.animations) do
		if animation.info then
			animation.time = animation.time + deltaTime

			if animation.info.looping == true then
				if animation.time >= animation.info.duration then
					animation.time = animation.time - animation.info.duration
				end
			end
			if name == self.currentAnimation then
				animation.weight = math.min(animation.weight+(self.blendSpeed * deltaTime), 1.0)
				if animation.time >= animation.info.duration then
					self.currentAnimation = ""
				end
			else
				animation.weight = math.max(animation.weight-(self.blendSpeed * deltaTime ), 0.0)
			end

			self.character:updateAnimation( animation.info.name, animation.time, animation.weight )
		end
	end

	-- First person animations
	if self.isLocal then
		for name, animation in pairs( self.FPanimations ) do
			if animation.info then
				animation.time = animation.time + deltaTime

				if animation.info.looping == true then
					if animation.time >= animation.info.duration then
						animation.time = animation.time - animation.info.duration
					end
				end
				if name == self.currentFPAnimation then
					animation.weight = math.min(animation.weight+(self.blendSpeed * deltaTime), 1.0)
					if animation.time >= animation.info.duration then
						self.currentFPAnimation = ""
					end
				else
					animation.weight = math.max(animation.weight-(self.blendSpeed * deltaTime ), 0.0)
				end
				sm.localPlayer.updateFpAnimation( animation.info.name, animation.time, animation.weight, animation.info.looping )
			end
		end
	end
end

function MechanicCharacter.client_onEvent( self, event )
	self:cl_handleEvent( event )
end

function MechanicCharacter.cl_e_onEvent( self, event )
	self:cl_handleEvent( event )
end

function MechanicCharacter.cl_handleEvent( self, event )
	if not self.animationsLoaded then
		return
	end
end