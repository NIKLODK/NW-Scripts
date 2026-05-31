--- optional file for elevator functionality - can be removed if not needed
--- this file works in conjunction with ipl.lua to provide elevator functionality
local points = {}
local floors = {
    {
        coords = vec4(613.0143, -10.9418, 75.0452, 342.9560),
        label = "Floor -1",
    },
    {
        coords = vec4(613.0391, -10.8466, 83.6421, 342.4904),
        label = "Floor 1",
    },
    {
        coords = vec4(613.0683, -10.7495, 87.8023, 340.4964),
        label = "Lobby",
    },
    {
        coords = vec4(602.4723, -18.2419, 101.3443, 342.6026),
        label = "Floor 4",
    },
}

function onElevatorEnter(self)
    lib.showTextUI('[ E ] Elevator')
end
 
function onElevatorExit(self)
    lib.hideTextUI()
end
 
function ElevatorNearby(self)
    if self.currentDistance < self.distance and IsControlJustReleased(0, 38) then
        local elements = {}
        local pedcoords = GetEntityCoords(cache.ped)
        for i = 1, #floors do
            local floor = floors[i]
            local currentFloor = #(pedcoords - vec3(floor.coords.x, floor.coords.y, floor.coords.z)) < 1.0
            elements[#elements + 1] = {
                title = floor.label,
                description = currentFloor and 'You are here' or 'Go to ' .. floor.label,
                disabled = currentFloor,
                onSelect = function()
                    DoScreenFadeOut(800)
                    Wait(1000)
                    SetEntityCoords(cache.ped, floor.coords.x, floor.coords.y, floor.coords.z - 1.0, false, false, false, false)
                    SetEntityHeading(cache.ped, floor.coords.w)
                    Wait(500)
                    DoScreenFadeIn(800)
                end,
            }
        end
        if #elements <= 0 then return end 
        lib.registerContext({
            id = 'wiwang_menu',
            title = 'Elevator Menu',
            options = elements,
        })
        lib.showContext('wiwang_menu')
    end
end

for i = 1, #floors do
    local floor = floors[i]
    points[i] = lib.points.new({
        coords = floor.coords,
        distance = 1,
        onEnter = onElevatorEnter,
        onExit = onElevatorExit,
        nearby = ElevatorNearby,
        label = floor.label,
        teleport = floor.coords,
    })
end