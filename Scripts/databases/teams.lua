local teamDB = {
    team_clones = {
        displayName = "team_clones_name",
        classes = {
            "clones_soldier",
            "clones_heavy",
            "clones_sniper",
            "clones_engineer"
        }
    },
    team_cis = {
        displayName = "team_cis_name",
        classes = {
            "cis_soldier",
            "cis_heavy",
            "cis_sniper",
            "cis_engineer"
        }
    }
}

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



print("TEAMS LOADED")