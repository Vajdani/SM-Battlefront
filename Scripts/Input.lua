---@class Input : ToolClass
Input = class()

function Input:client_onCreate()
    g_input = self.tool
end

function Input:client_onFixedUpdate()
    if g_spaceShip and not self.forced then
        sm.tool.forceTool(self.tool)
        self.forced = true
    elseif self.forced then
        sm.tool.forceTool(nil)
        self.forced = false
    end
end

function Input:client_onEquippedUpdate(lmb, rmb, f)
    local primary = lmb == 1 or lmb == 2
    local secondary = rmb == 1 or rmb == 2
    if primary ~= self.prevPrimary or secondary ~= self.prevSecondary then
        self.prevPrimary = primary
        self.prevSecondary = secondary

        if g_spaceShip and sm.exists(g_spaceShip) then
            sm.event.sendToHarvestable(g_spaceShip, "cl_mouseClick", { [19] = primary, [18] = secondary })
        end
    end

    return true, true
end