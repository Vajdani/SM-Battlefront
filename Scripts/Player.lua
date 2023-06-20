Player = class( nil )

dofile "$CONTENT_DATA/Scripts/util.lua"

function Player.server_onCreate( self )
	print("Player.server_onCreate")
end

function Player:sv_place(args, player)
    local char = player.character
    local fwd = char.direction; fwd.z = 0; fwd = fwd:normalize()
    sm.harvestable.create(
        sm.uuid.new("45c52a91-cf19-4fc8-9e64-7b6f8078e68d"),
        char.worldPosition + sm.vec3.new(0,0,1.80) + fwd * 2.5,
        ROTADJUST * sm.quat.angleAxis(math.rad(180), VEC3_FWD)
    )
end



function Player:client_onReload()
    self.network:sendToServer("sv_place")

    return true
end

function Player:client_onInteract()
    return true
end