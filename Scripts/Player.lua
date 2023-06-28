Player = class( nil )
Player.maxHealth = 100

Player.maxStamina = 5
Player.staminaDrain = 1
Player.staminaGain = 0.8
Player.sprintThreshold = 0.25

dofile "$CONTENT_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"

function Player.server_onCreate( self )
	print("Player.server_onCreate")

    self.health = self.maxHealth
    self.spaceShip = nil

    self:sv_updateClient()
end

function Player:sv_setSpaceShip(ship)
    self.spaceShip = ship
    self.network:sendToClient(self.player, "cl_setUIState", ship == nil)
end

function Player:sv_updateClient()
    self.network:setClientData(
        {
            health = self.health, maxHealth = self.maxHealth
        }
    )
end

function Player:server_onFixedUpdate(dt)

end

function Player:server_onExplosion(center, destructionLevel)
	self:sv_takeDamage(destructionLevel * 4, "explosive", "explosion")
end

function Player:server_onProjectile(position, airTime, velocity, projectileName, attacker, damage, customData, normal, uuid)
	self:sv_takeDamage(damage, projectileName, attacker)
end

function Player:server_onMelee(position, attacker, damage, power, direction, normal)
	self:sv_takeDamage(damage, "melee", attacker)
end

function Player:sv_takeDamage(damage, damageType, attacker)
    if self.spaceShip then return end

	self.health = math.max(self.health - damage, 0)
	print(string.format("Player %s took %s damage, current health: %s / %s", self.player.id, damage, self.health, self.maxHealth))

	local dead = self.health <= 0
	if dead then
		print(self.player, "KILLED BY", attacker)

		local character = self.player.character
		character:setTumbling(true)
		character:setDowned(true)
	end

    self:sv_updateClient()
end

function Player:sv_revive()
    if self.health > 0 then return end

    self.health = self.maxHealth
    local character = self.player.character
	character:setTumbling(false)
	character:setDowned(false)
    self:sv_updateClient()
end

function Player:sv_place(ship, player)
    local char = player.character
    local fwd = char.direction; fwd.z = 0; fwd = fwd:normalize()
    local pos = char.worldPosition + sm.vec3.new(0,0,1.80) + fwd * 5
    local rot = ROTADJUST
    local hit, result = sm.physics.raycast(pos, pos - VEC3_UP * 10)

    local data = {
        ["TIE Fighter"] = { uuid =  sm.uuid.new("45c52a91-cf19-4fc8-9e64-7b6f8078e68d"), landOffset = 2.475 },
        ["X-Wing"] = { uuid = sm.uuid.new("970d5247-9943-458a-bf48-de8a6cb089ee"), landOffset = 0.85 }
    }
    if hit then
        local normal = result.normalWorld
        pos = result.pointWorld + normal * data[ship].landOffset

        local up = ROTADJUST * VEC3_FWD
        if (normal - up):length2() > FLT_EPSILON then
            rot = LookRot(normal, up) * ROTADJUST
        end
    end

    sm.harvestable.create( data[ship].uuid, pos, rot * sm.quat.angleAxis(math.rad(180), VEC3_FWD) )
end



function Player:client_onCreate()
    self.isLocal = self.player == sm.localPlayer.getPlayer()

    if not self.isLocal then return end

    self.survivalHud = sm.gui.createSurvivalHudGui()
	self.survivalHud:setVisible("WaterBar", false)
	self.survivalHud:open()

    self.stamina = self.maxStamina
    self.blockSprint = false
end

function Player:client_onUpdate(dt)
    if not self.isLocal then return end

    local char = self.player.character
    if char then
        if char:isSprinting() and not self.blockSprint then
            self.stamina = sm.util.clamp(self.stamina - dt * self.staminaDrain, 0, self.maxStamina)
            if self.stamina <= 0 then
                self.blockSprint = true
            end
        else
            self.stamina = sm.util.clamp(self.stamina + dt * self.staminaGain, 0, self.maxStamina)
            if self.stamina >= self.maxStamina * self.sprintThreshold then
                self.blockSprint = false
            end
        end
    end

    sm.localPlayer.setBlockSprinting( self.blockSprint )
	self.survivalHud:setSliderData( "Food", self.maxStamina * 100, self.stamina * 100 )
end

function Player:client_onReload()
    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/SpawnMenu.layout", true)
    self.gui:setText("title", "Select ship")
    self.gui:setButtonCallback("cancel", "cl_onSpawnButton")
    self.gui:setButtonCallback("ok", "cl_onSpawnButton")

    local options = { "TIE Fighter", "X-Wing" }
    self.gui:createDropDown("dropdown", "cl_onSpawnSelect", options)
    self.selectedShip = options[1]

    self.gui:open()

    return true
end

function Player:cl_onSpawnButton(button)
    if button == "ok" then
        self.network:sendToServer("sv_place", self.selectedShip)
    end

    self.gui:close()
    self.selectedShip = nil
end

function Player:cl_onSpawnSelect(selected)
    self.selectedShip = selected
end

function Player:client_onInteract()
    self.network:sendToServer("sv_revive")
    return true
end

function Player:client_onClientDataUpdate(data)
    if not self.isLocal then return end

    local health = data.health
    self.survivalHud:setSliderData( "Health", data.maxHealth * 10, data.health * 10 )

    if health <= 0 then
		sm.camera.setCameraState( 4 )
	elseif not g_spaceShip and sm.camera.getCameraState() ~= 0 then
		sm.camera.setCameraState( 0 )
	end
end

function Player:cl_setUIState(state)
    if state then
        self.survivalHud:open()
    else
        self.survivalHud:close()
    end
end