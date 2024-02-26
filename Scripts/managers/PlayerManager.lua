---@class PlayerManager : ScriptableObjectClass
PlayerManager = class()

function PlayerManager:server_onCreate()
    g_playerManager = self

    self.sv = {}

    --define classes in map data later
    self.sv.teams = {
        team_clones = {},
        team_cis = {}
    }

    self.network:setClientData(self.sv.teams, 1)
end



---@param player Player
---@param team string
function PlayerManager.JoinTeam(player, team)
    if g_playerManager then
        sm.event.sendToScriptableObject(g_playerManager.scriptableObject, "joinTeam", { player = player, team = team})
    end
end

---@param args { player: Player, team: string }
function PlayerManager:joinTeam(args)
    local player, team = args.player, args.team
    local currentTeam = player.publicData.team
    if currentTeam == team then return end

    if currentTeam then
        self:leaveTeam(player, player.publicData.team)
    end

    player.publicData.team = team
    table.insert(self.sv.teams[team], player)

    self.network:sendToClients("cl_OnTeamSelect", { player = player, team = team })

    print(("[PlayerManager] %s joined %s!"):format(player:getName(), team))
end

---@param player Player
---@param team string
function PlayerManager.LeaveTeam(player, team)
    if g_playerManager then
        g_playerManager:leaveTeam(player, team)
    end
end

---@param player Player
---@param team string
function PlayerManager:leaveTeam(player, team)
    player.publicData.team = nil

    for k, v in pairs(self.sv.teams[team]) do
        if v == player then
            table.remove(self.sv.teams[team], k)
            break
        end
    end

    print(("[PlayerManager] %s left %s!"):format(player:getName(), team))
end


---@param player Player
---@param class string
function PlayerManager.SelectClass(player, class)
    if g_playerManager then
        sm.event.sendToScriptableObject(g_playerManager.scriptableObject, "selectClass", { player = player, class = class})
    end
end

---@param args { player: Player, class: string }
function PlayerManager:selectClass(args)
    local player, class = args.player, args.class
    local classData = GetClassData(class)
    player.character.movementSpeedFraction = classData.speed
    player.publicData.class = class
    sm.event.sendToPlayer(player, "sv_setMaxHealth", classData.health)

    sm.container.beginTransaction()
    local inv = sm.game.getLimitedInventory() and player:getInventory() or player:getHotbar()
    inv:setItem(0, sm.uuid.new(classData.weapons.primary), 1)
    inv:setItem(1, sm.uuid.new(classData.weapons.secondary), 1)
    inv:setItem(2, sm.uuid.new(classData.weapons.equipment1), 1)
    inv:setItem(3, sm.uuid.new(classData.weapons.equipment2), 1)

	for i = 4, inv:getSize() - 1 do
		inv:setItem(i, sm.uuid.getNil(), 0)
	end
	sm.container.endTransaction()

    self.network:sendToClients("cl_OnClassSelect", { player = player, class = class })
    print(("[PlayerManager] %s selected the %s class!"):format(player:getName(), class))
end


function PlayerManager:client_onCreate()
    self.cl = {}
    self.cl.teams = {}
end

---@param args { player: Player, team: string }
function PlayerManager:cl_OnTeamSelect(args)
    local player = args.player
    player.clientPublicData.team = args.team
    --player.clientPublicData.class = nil

    if player == sm.localPlayer.getPlayer() then
        sm.event.sendToPlayer(player, "cl_OnPlayerStateChange", PLAYERSTATES.ClassSelect)
    end
end


---@param args { player: Player, class: string }
function PlayerManager:cl_OnClassSelect(args)
    local player = args.player
    player.clientPublicData.class = args.class
    sm.event.sendToCharacter(player.character, "cl_updateLook")

    if player == sm.localPlayer.getPlayer() then
        sm.event.sendToPlayer(player, "cl_OnPlayerStateChange", PLAYERSTATES.IsPlaying)
    end
end

function PlayerManager:client_onClientDataUpdate(data, channel)
    if channel == 1 then
        self.cl.teams = data
    end
end