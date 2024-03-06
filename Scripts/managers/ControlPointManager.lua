---@class ControlPointManager : ScriptableObjectClass
ControlPointManager = class()

function ControlPointManager:server_onCreate()
    g_cpManager = self

    self.scriptableObject.publicData = {
        points = {}
    }
end

---@param shape Shape
function ControlPointManager:sv_registerPoint(shape)
    self.scriptableObject.publicData.points[shape.id] = {
        isCaptured = false,
        ownerTeam = nil
    }
end




function ControlPointManager:client_onCreate()
    g_cpManager = self
end