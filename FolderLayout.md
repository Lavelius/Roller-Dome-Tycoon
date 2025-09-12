ServerStorage/
  Templates/
    PlayerPodium
    CannonTemplate
    DiceTemplates/
      D4

ReplicatedStorage/
  Remotes/
    TycoonBuy (RemoteEvent)
    CannonRequestFire (RemoteEvent)
    UIToast (RemoteEvent)
    StationAssigned (RemoteEvent)
  Shared/
    Config (ModuleScript)
    Util   (ModuleScript)

ServerScriptService/
  Controllers/
    PlayerJoinLeaveController.server.lua
    PlayerTycoonController.server.lua
    PlayerCurrencyController.server.lua
  Services/
    PlayerDataService.lua
    StationService.lua
    CannonService.lua
    DiceService.lua

StarterPlayer/
  StarterPlayerScripts/
    PlayerUIController.client.lua

StarterGui/
  MainUI (ScreenGui + assets)
