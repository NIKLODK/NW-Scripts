local UI = lib.require('shared.ui')

local CoordPicker = {}

local function RotationToDirection(rotation)
  local adjustedRotation = {
    x = (math.pi / 180) * rotation.x,
    y = (math.pi / 180) * rotation.y,
    z = (math.pi / 180) * rotation.z
  }

  return {
    x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
    y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
    z = math.sin(adjustedRotation.x)
  }
end

local function RayCastGamePlayCamera(distance)
  local cameraRotation = GetGameplayCamRot()
  local cameraCoord = GetGameplayCamCoord()
  local direction = RotationToDirection(cameraRotation)

  local destination = {
    x = cameraCoord.x + direction.x * distance,
    y = cameraCoord.y + direction.y * distance,
    z = cameraCoord.z + direction.z * distance
  }

  local _, hit, endCoords, _, entityHit = GetShapeTestResult(
    StartShapeTestRay(
      cameraCoord.x, cameraCoord.y, cameraCoord.z,
      destination.x, destination.y, destination.z,
      -1, PlayerPedId(), 0
    )
  )

  return hit == 1, endCoords, entityHit
end

-- One-shot 3D coord picker (ex-3dcoord style):
-- - Aim with your camera
-- - Press E to select
-- - Press Backspace to cancel
function CoordPicker.pick3D(provider)
  local p = promise.new()
  local active = true

  CreateThread(function()
    UI.textShow(provider, { description = 'Peg og tryk [E] for at vælge. Backspace for at annullere.', keybind = 'E' })

    while active do
      local ped = PlayerPedId()
      local plyCoords = GetEntityCoords(ped)
      local hit, coords = RayCastGamePlayCamera(1000.0)

      if hit and coords then
        DrawLine(plyCoords.x, plyCoords.y, plyCoords.z, coords.x, coords.y, coords.z, 0, 255, 0, 100)
        DrawSphere(coords.x, coords.y, coords.z, 0.1, 0, 255, 0, 0.8)
      end

      -- E (38) select
      if IsControlJustPressed(0, 38) and coords then
        active = false
        UI.textHide(provider)
        local vec = vec3(coords.x, coords.y, coords.z)
        lib.setClipboard(('vec3(%.2f, %.2f, %.2f)'):format(vec.x, vec.y, vec.z))
        UI.notify('Koordinater kopieret til clipboard.', 'success', provider)
        p:resolve(vec)
        break
      end

      -- Backspace (177) cancel
      if IsControlJustPressed(0, 177) then
        active = false
        UI.textHide(provider)
        p:resolve(nil)
        break
      end

      Wait(0)
    end
  end)

  return Citizen.Await(p)
end

return CoordPicker
