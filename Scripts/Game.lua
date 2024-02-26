--[[Game = class( CreativeGame )
Game.worldScriptFilename = "$GAME_DATA/Scripts/game/worlds/CreativeTerrainWorld.lua";
Game.worldScriptClass = "CreativeTerrainWorld";]]

dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/EffectManager.lua" )
dofile "util.lua"
dofile "databases/classes.lua"
dofile "databases/teams.lua"

---@class Game : GameClass
---@field sv table
---@field cl table
Game = class()

function Game.server_onCreate( self )
	print("Game.server_onCreate")

    g_unitManager = UnitManager()
	g_unitManager:sv_onCreate( nil, { aggroCreations = true } )

    self.sv = {}
	g_sv_gameState = GAMESTATES.Menu
	--self.sv.saved = self.storage:load()
    --if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/worlds/MainMenuWorld.lua", "MainMenuWorld" )
		--self.storage:save( self.sv.saved )
	--end

	self.network:setClientData(g_sv_gameState, 1)

	sm.scriptableObject.createScriptableObject(sm.uuid.new("c0da37df-2906-42ea-b314-e8336c01d247")) --LanguageManager
	sm.scriptableObject.createScriptableObject(sm.uuid.new("82d5ac44-b59c-4d57-ba65-340c8e78e2f2")) --PlayerManager
end

function Game:sv_OnMenuPlayButton()
	g_sv_gameState = GAMESTATES.Menu
	self.network:setClientData(g_sv_gameState, 1)

	sm.event.sendToGame("sv_LoadGameWorld")
end

function Game:sv_LoadGameWorld()
	self:sv_loadWorld("$CONTENT_DATA/Scripts/worlds/World.lua", "World", GAMESTATES.GameInProgress)
	--self:sv_loadWorld("$CONTENT_DATA/Scripts/worlds/MainMenuWorld.lua", "MainMenuWorld", GAMESTATES.GameInProgress)
end

function Game:sv_LoadMenuWorld()
	self:sv_loadWorld("$CONTENT_DATA/Scripts/worlds/MainMenuWorld.lua", "MainMenuWorld", GAMESTATES.Menu)
end


function Game:sv_loadWorld(path, cName, state)
	self.sv.saved.world:destroy()
	self.sv.saved.world = sm.world.createWorld(path, cName)
	if not sm.exists(self.sv.saved.world) then
		sm.world.loadWorld( self.sv.saved.world )
	end

	for k, v in pairs(sm.player.getAllPlayers()) do
		self.sv.saved.world:loadCell( 0, 0, v, "sv_createPlayerCharacter" )
	end

	g_sv_gameState = state
	self.network:setClientData(g_sv_gameState, 1)
end

function Game.server_onFixedUpdate( self, timeStep )
	g_unitManager:sv_onFixedUpdate()
end

---@param player Player
function Game.server_onPlayerJoined( self, player, isNewPlayer )
    print("Game.server_onPlayerJoined")
	if not sm.exists( self.sv.saved.world ) then
		sm.world.loadWorld( self.sv.saved.world )
	end
	self.sv.saved.world:loadCell( 0, 0, player, "sv_createPlayerCharacter" )

	g_unitManager:sv_onPlayerJoined( player )
end

function Game.sv_createPlayerCharacter( self, world, x, y, player, params )
    local character = sm.character.createCharacter( player, world, sm.vec3.new( 32, 32, 5 ), 0, 0 )
	player:setCharacter( character )

	sm.container.beginTransaction()
	local inv = sm.game.getLimitedInventory() and player:getInventory() or player:getHotbar()
	for i = 0, inv:getSize() - 1 do
		inv:setItem(i, sm.uuid.getNil(), 0)
	end
	sm.container.endTransaction()
end



function Game.client_onCreate( self )
	if g_unitManager == nil then
		assert( not sm.isHost )
		g_unitManager = UnitManager()
	end
	g_unitManager:cl_onCreate()

	g_effectManager = EffectManager()
	g_effectManager:cl_onCreate()

	self.cl = {}
	g_cl_gameState = GAMESTATES.Menu

	self:cl_registerCommands()
end

function Game:cl_registerCommands()
	sm.game.bindChatCommand("/menu", {}, "cl_openMenu", "Opens the mod's menu")
	sm.game.bindChatCommand("/team", {}, "cl_teamSelect", "Switch teams")
	sm.game.bindChatCommand("/class", {}, "cl_classSelect", "Switch classes")
end

function Game:cl_openMenu()
	self.menuGui:open()
end

function Game:cl_teamSelect()
	sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_OnPlayerStateChange", PLAYERSTATES.TeamSelect)
end

function Game:cl_classSelect()
	sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_OnPlayerStateChange", PLAYERSTATES.ClassSelect)
end

function Game:cl_OnGameStateChange(state)
    if state == GAMESTATES.Menu then
		sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_OnPlayerStateChange", PLAYERSTATES.Menu)

		self.menuGui = sm.gui.createGuiFromLayout("$GAME_DATA/Gui/Layouts/MainMenu/MainMenu.layout", false, { hidesHotbar = true })
		--self.menuGui:setOnCloseCallback("cl_onClose")
		self.menuGui:setButtonCallback("Play",      "cl_OnMenuPlayButton")
		self.menuGui:setButtonCallback("Character", "cl_OnMenuCharButton")
		self.menuGui:setButtonCallback("Options",   "cl_OnMenuOptionsButton")
		self.menuGui:setButtonCallback("Exit",      "cl_OnMenuExitButton")
		self.menuGui:open()
	elseif state == GAMESTATES.GameInProgress then
        self.menuGui:close()
		sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_OnPlayerStateChange", PLAYERSTATES.TeamSelect)
	end
end

function Game:cl_onClose()
    if not sm.exists(self.menuGui) then return end
    self.menuGui:open()
end

function Game:cl_OnMenuPlayButton()
	if g_cl_gameState ~= GAMESTATES.Menu then
		self.menuGui:close()
		return
	end

    self.network:sendToServer("sv_OnMenuPlayButton")
end

function Game:cl_OnMenuCharButton()
    print("char")
end

function Game:cl_OnMenuOptionsButton()
    print("options")
end

function Game:cl_OnMenuExitButton()
	if g_cl_gameState == GAMESTATES.Menu then
		sm.gui.exitToMenu()
	else
		self.menuGui:close()

		self.cl.confirmExitGui = sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout", false, { hidesHotbar = true } )
		self.cl.confirmExitGui:setButtonCallback( "Yes", "cl_onExitConfirmButtonClick" )
		self.cl.confirmExitGui:setButtonCallback( "No", "cl_onExitConfirmButtonClick" )
		self.cl.confirmExitGui:setText( "Title", "#{MENU_YN_TITLE_ARE_YOU_SURE}" )
		self.cl.confirmExitGui:setText( "Message", "Are you sure you want to exit to the menu?" )
		self.cl.confirmExitGui:open()
	end
end

function Game.cl_onExitConfirmButtonClick( self, name )
	if name == "Yes" then
		self.network:sendToServer( "sv_LoadMenuWorld" )
	end

	self.cl.confirmExitGui:close()
	self.cl.confirmExitGui = nil
end

function Game:client_onClientDataUpdate(data, channel)
	if channel == 1 then
		g_cl_gameState = data
		self:cl_OnGameStateChange(data)
	end
end

function Game.client_onLoadingScreenLifted( self )
	g_effectManager:cl_onLoadingScreenLifted()
end