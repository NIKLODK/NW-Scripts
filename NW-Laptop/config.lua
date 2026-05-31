Config = {}

-- Inventory item names
Config.LaptopItem = 'laptop'
Config.SimcardItem = 'simcard'
Config.BaseTabletItem = 'tablet'
Config.RewardTabletItem = 'bande_tablet'

-- Placement and interaction
Config.LaptopProp = 'prop_laptop_lester2'
Config.PlaceOffset = 1.0
Config.OpenDistance = 2.0
Config.PickupDistance = 2.0
Config.MaxUseDistance = 3.0
Config.AllowAnyoneToPickup = false

-- Progress / install
Config.PlaceDuration = 1700
Config.InstallDuration = 7000
Config.AppName = 'bande_app'

-- UI mode
Config.PreferDui = true
Config.AllowNuiFallback = true
Config.DuiWidth = 640
Config.DuiHeight = 360

-- Visual size of DUI sprite on screen (overlay used for mouse interaction)
Config.DuiDrawWidth = 0.58
Config.DuiDrawHeight = 0.40
Config.DuiScreenX = 0.50
Config.DuiScreenY = 0.50
Config.DuiDrawOverlay = false
Config.DuiInputX = 0.50
Config.DuiInputY = 0.41
Config.DuiInputWidth = 0.58
Config.DuiInputHeight = 0.36
Config.DuiInputPadding = 0.01
Config.DuiCursorAlways = true

-- Optional render-target draw directly on laptop screen texture
Config.EnableLaptopRenderTarget = true
Config.LaptopRenderTargetName = 'tvscreen'

-- Camera when opening laptop UI
Config.UseLaptopCam = true
Config.CamOffset = vec3(0.0, -0.38, 0.23)
Config.CamLookAtOffset = vec3(0.0, 0.01, 0.10)
Config.CamFov = 46.0

-- Optional debug prints
Config.Debug = false

-- Fallback: register laptop as ESX usable item (helps if ox_inventory item lacks client.event)
Config.EnableEsxUsableFallback = true
