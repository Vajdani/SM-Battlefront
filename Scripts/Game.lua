--[[Game = class( CreativeGame )
Game.worldScriptFilename = "$GAME_DATA/Scripts/game/worlds/CreativeTerrainWorld.lua";
Game.worldScriptClass = "CreativeTerrainWorld";]]

dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/EffectManager.lua" )

---@class Game : GameClass
---@field sv table
Game = class()

function Game.server_onCreate( self )
	print("Game.server_onCreate")

    g_unitManager = UnitManager()
	g_unitManager:sv_onCreate( nil, { aggroCreations = true } )

    self.sv = {}
	self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
		--self.sv.saved.world = sm.world.createWorld( "$GAME_DATA/Scripts/game/worlds/CreativeTerrainWorld.lua", "CreativeTerrainWorld" )
		self.storage:save( self.sv.saved )
	end
end

function Game.server_onFixedUpdate( self, timeStep )
	g_unitManager:sv_onFixedUpdate()
end

function Game.server_onPlayerJoined( self, player, isNewPlayer )
    print("Game.server_onPlayerJoined")
    if isNewPlayer then
        if not sm.exists( self.sv.saved.world ) then
            sm.world.loadWorld( self.sv.saved.world )
        end
        self.sv.saved.world:loadCell( 0, 0, player, "sv_createPlayerCharacter" )
    end

	g_unitManager:sv_onPlayerJoined( player )
end

function Game.sv_createPlayerCharacter( self, world, x, y, player, params )
    local character = sm.character.createCharacter( player, world, sm.vec3.new( 32, 32, 5 ), 0, 0 )
	player:setCharacter( character )
end



function Game.client_onCreate( self )
	if g_unitManager == nil then
		assert( not sm.isHost )
		g_unitManager = UnitManager()
	end
	g_unitManager:cl_onCreate()

	g_effectManager = EffectManager()
	g_effectManager:cl_onCreate()
end

function Game.client_onLoadingScreenLifted( self )
	g_effectManager:cl_onLoadingScreenLifted()
end