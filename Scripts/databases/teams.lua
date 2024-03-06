local teamDB = {
    team_clones = {
        displayName = "team_clones_name",
        teamColour = sm.color.new("#0000ff"),
        controlPointLogo = sm.uuid.new("b7e42cd5-7371-4503-ba24-172a8e9a2888"),
        classes = {
            "clones_soldier",
            "clones_heavy",
            "clones_sniper",
            "clones_engineer"
        }
    },
    team_cis = {
        displayName = "team_cis_name",
        teamColour = sm.color.new("#df7f00"),
        controlPointLogo = sm.uuid.new("b7e42cd5-7371-4503-ba24-172a8e9a2888"),
        classes = {
            "cis_soldier",
            "cis_heavy",
            "cis_sniper",
            "cis_engineer"
        }
    }
}

local indexToTeam = {}
local count = 0
for k, v in pairs(teamDB) do
    count = count + 1
    indexToTeam[k] = count
end

function GetClassesForTeam(team)
    local teamData = teamDB[team]
    return teamData and teamData.classes or {}
end

function GetTeams()
    local teams = {}
    for team, v in pairs(teamDB) do
        table.insert(teams, team)
    end

    return teams
end

function IsClassInTeam(class, team)
    return isAnyOf(class, teamDB[team].classes)
end

---@param team number
---@return Uuid
---@return Color
function GetCPInfo(team)
    local teamData = teamDB[indexToTeam[team]]
    return teamData and teamData.controlPointLogo, teamData and teamData.teamColour
end

function GetTeamIndex(team)
    return indexToTeam[team]
end



print("TEAMS LOADED")