---@class BFPlayer : PlayerClass
---@field maxHealth number
Player = class( nil )
Player.maxStamina = 5
Player.staminaDrain = 1
Player.staminaGain = 0.8
Player.sprintThreshold = 0.25

dofile "$CONTENT_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"

function Player.server_onCreate( self )
	print("Player.server_onCreate")

    self.maxHealth = 100
    self.health = self.maxHealth
    self.spaceShip = nil

    self:sv_updateClient()

    self.player.publicData = {}
end

function Player:sv_setMaxHealth(health)
    self.maxHealth = health
    self.health = health
    self:sv_updateClient()
end

function Player:sv_OnTeamSelect(team, player)
    PlayerManager.JoinTeam(player, team)
end

function Player:sv_OnClassSelect(class, player)
    PlayerManager.SelectClass(player, class)
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
    self.player.clientPublicData = {}

    self.isLocal = self.player == sm.localPlayer.getPlayer()

    if not self.isLocal then return end

    self.stamina = self.maxStamina
    self.blockSprint = false

    g_localPlayerState = PLAYERSTATES.Menu
end

function Player:client_onUpdate(dt)
    if not self.isLocal then return end

    self:cl_updatePlayer(dt)
end

function Player:cl_OnPlayerStateChange(state)
    if state == PLAYERSTATES.Menu then
        if g_survivalHud then
			g_survivalHud:destroy()
		end

        sm.camera.setCameraState(3)
        sm.camera.setPosition(sm.vec3.new(0,0,5))
        sm.camera.setRotation(sm.quat.identity())
        sm.localPlayer.setLockedControls(true)
    elseif state == PLAYERSTATES.TeamSelect then
        self.teamSelect = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/ClassSelect.layout", false, { hidesHotbar = true })
        self.teamSelect:setText("Name", language_tag("teamSelect"))
        self.teamSelect:setText("SubTitle", language_tag("teamSelect_sub"))

        local pData = self.player.clientPublicData
        local teams = pData.team and {} or { "" }
        for k, team in pairs(GetTeams()) do
            teams[team] = language_tag(team.."_name")
        end

		self.teamSelect:createDropDown("Options", "cl_OnTeamSelect", teams)

        if pData.team then
            self.teamSelect:setSelectedDropDownItem("Options", teams[pData.team])
        end

        self.teamSelect:open()
    elseif state == PLAYERSTATES.ClassSelect then
        self.classSelect = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/ClassSelect.layout", false, { hidesHotbar = true })
        self.classSelect:setText("Name", language_tag("classSelect"))
        self.classSelect:setText("SubTitle", language_tag("classSelect_sub"))

        local pData = self.player.clientPublicData
        print(IsClassInTeam(pData.class, pData.team), pData.class, pData.team)
        local classes = IsClassInTeam(pData.class, pData.team) and {} or { "" }
        for k, class in pairs(GetClassesForTeam(self.team)) do
            classes[class] = language_tag(class.."_name")
        end

		self.classSelect:createDropDown("Options", "cl_OnClassSelect", classes)

        if pData.class then
            local class = classes[pData.class]
            if class then
                self.classSelect:setSelectedDropDownItem("Options", class)
            end
        end

        self.classSelect:open()
    elseif state == PLAYERSTATES.IsPlaying then
        sm.camera.setCameraState(0)

        g_survivalHud = sm.gui.createSurvivalHudGui()
	    g_survivalHud:setVisible("WaterBar", false)
	    g_survivalHud:open()

		sm.localPlayer.setLockedControls(false)
    end

    g_localPlayerState = state
end

function Player:cl_OnTeamSelect(option)
    local currentTeam = self.player.clientPublicData.team
    if option == "" or currentTeam and language_tag(currentTeam.."_name") == option then return end

    self.teamSelect:close()
    self.teamSelect = nil

    local teams = {}
    for k, team in pairs(GetTeams()) do
        teams[language_tag(team.."_name")] = team
    end

    self.team = teams[option]
    self.network:sendToServer("sv_OnTeamSelect", self.team)
end

function Player:cl_OnClassSelect(option)
    local currentClass = self.player.clientPublicData.class
    if option == "" or currentClass and language_tag(currentClass.."_name") == option then return end

    self.classSelect:close()
    self.classSelect = nil

    local classes = {}
    for k, class in pairs(GetClassesForTeam(self.team)) do
        classes[language_tag(class.."_name")] = class
    end

    self.network:sendToServer("sv_OnClassSelect", classes[option])
end

function Player:cl_updatePlayer(dt)
    if g_cl_gameState ~= GAMESTATES.GameInProgress or g_localPlayerState ~= PLAYERSTATES.IsPlaying then return end

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
	g_survivalHud:setSliderData( "Food", self.maxStamina * 100, self.stamina * 100 )
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
    if not self.isLocal or g_cl_gameState == GAMESTATES.Menu then return end

    local health = data.health
    g_survivalHud:setSliderData( "Health", data.maxHealth * 10, data.health * 10 )

    if health <= 0 then
		sm.camera.setCameraState( 4 )
	elseif not g_spaceShip and sm.camera.getCameraState() ~= 0 then
		sm.camera.setCameraState( 0 )
	end
end

function Player:cl_setUIState(state)
    if state then
        g_survivalHud:open()
    else
        g_survivalHud:close()
    end
end