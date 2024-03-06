---@class ControlPoint : ShapeClass
ControlPoint = class()
ControlPoint.captureTime = 5

local baseScale = sm.vec3.one() * 0.25

function ControlPoint:server_onCreate()
    self.team = nil
    self.prevStatus = CPSTATUS.Idle
    self.captureProgress = 0
    self.captureZone = sm.areaTrigger.createAttachedBox(self.interactable, sm.vec3.one() * 5, sm.vec3.zero(), sm.quat.identity(), sm.areaTrigger.filter.character)

    self.interactable.publicData = {
        isCaptured = false,
        ownerTeam = nil
    }
end

function ControlPoint:server_onFixedUpdate(dt)
    local contents = self.captureZone:getContents()
    local capturingTeam, currentStatus = nil, CPSTATUS.Idle
    for k, char in pairs(contents) do
        local player = char:getPlayer()
        if player then
            local public = player.publicData
            if not capturingTeam then
                capturingTeam = public.team
                currentStatus = CPSTATUS.Capturing
            elseif public.team ~= capturingTeam then
                currentStatus = CPSTATUS.CaptureConflict
                capturingTeam = nil
                break
            end
        end
    end

    --[[if self.prevStatus ~= currentStatus then
        self.prevStatus = currentStatus
        self:sv_CaptureStatusUpdate(currentStatus)
    end]]

    if currentStatus == CPSTATUS.Idle then
        
    end

    --[[for k, char in pairs(contents) do
        local player = char:getPlayer()
        if player then
            local public = player.publicData
            if not capturingTeam then
                capturingTeam = public.team
                currentStatus = CPSTATUS.Capturing
            elseif public.team ~= capturingTeam then
                currentStatus = CPSTATUS.CaptureConflict
                capturingTeam = nil
                break
            end
        end
    end

    if currentStatus == CPSTATUS.Capturing then
        if capturingTeam == self.team then
            self.captureProgress = math.min(self.captureProgress + dt, self.captureTime)
            if self.captureProgress == self.captureTime and not self.interactable.active then
                self:sv_captureUpdate(CPUPDATE.Captured)
            end
        else
            self.captureProgress = math.max(self.captureProgress - dt, 0)
            if self.captureProgress == 0 then
                self.team = capturingTeam
                self:sv_captureUpdate(CPUPDATE.NewTeam)
            end
        end
    elseif currentStatus == CPSTATUS.Idle then
        if not self.interactable.active then
            self.captureProgress = math.max(self.captureProgress - dt, 0)
            if self.captureProgress == 0 then
                self.team = nil
                self:sv_captureUpdate(CPUPDATE.Idle)
            end
        end
    end]]

    --print(self.interactable.active, self.interactable.power, self.captureProgress)
end

function ControlPoint:sv_CaptureStatusUpdate(status)
    if status == CPSTATUS.Idle then
        
    end
end

function ControlPoint:sv_captureUpdate(state)
    print("update:", state)
    if state == CPUPDATE.NewTeam then
        self.interactable.power = GetTeamIndex(self.team)
        self.interactable.active = false
    elseif state == CPUPDATE.Captured then
        self.interactable.active = true
    elseif state == CPUPDATE.Idle then
        self.interactable.power = 0
        self.interactable.active = false
    end
end



function ControlPoint:client_onCreate()
    self.logo = sm.effect.createEffect("ShapeRenderable", self.interactable)
    self.logo:setOffsetPosition(VEC3_FWD * 1.25)
    self.logo:setScale(baseScale)

    self.prevTeam = 0
    self.scaleProgress = 0
    self.spinProgress = 0
end

function ControlPoint:client_onUpdate(dt)
    self.logo:setScale(baseScale * self.scaleProgress)

    local currentTeam = self.interactable.power
    if currentTeam ~= self.prevTeam then
        self.scaleProgress = math.max(self.scaleProgress - dt, 0)
        if self.scaleProgress == 0 then
            self.prevTeam = currentTeam
            self.logo:stop()

            local uuid, colour = GetCPInfo(currentTeam)
            if uuid then
                print("a")
                self.logo:setParameter("uuid", uuid)
                self.logo:setParameter("color", colour)
                self.logo:start()
            end
        end
    else
        self.scaleProgress = math.min(self.scaleProgress + dt, 1)
    end

    self.spinProgress = self.spinProgress + dt
    self.logo:setOffsetRotation(sm.quat.angleAxis(math.rad(self.spinProgress), VEC3_FWD))
end