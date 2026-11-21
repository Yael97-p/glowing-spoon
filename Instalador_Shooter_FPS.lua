--[[
	INSTALADOR SHOOTER FPS
	Cómo usarlo:
	1) Abre tu juego en Roblox Studio
	2) Menú View > Command Bar (barra de comandos)
	3) Pega TODO este archivo en la barra de comandos y presiona Enter
	4) Listo: crea todos los scripts en su lugar. Prueba con Play.
]]

local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local StarterCharacterScripts = StarterPlayer:WaitForChild("StarterCharacterScripts")
local StarterPack = game:GetService("StarterPack")
local StarterGui = game:GetService("StarterGui")
local ServerScriptService = game:GetService("ServerScriptService")

local function limpiar(padre, nombre)
	local viejo = padre:FindFirstChild(nombre)
	if viejo then viejo:Destroy() end
end

local function crear(clase, nombre, padre, codigo)
	limpiar(padre, nombre)
	local obj = Instance.new(clase)
	obj.Name = nombre
	if codigo then obj.Source = codigo end
	obj.Parent = padre
	return obj
end

---------------------------------------------------------------------
-- 1) PRIMERA PERSONA
---------------------------------------------------------------------
crear("LocalScript", "PrimeraPersona", StarterPlayerScripts, [==[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG = {
	MostrarBrazos = true,
	FOV = 80,
	FOVCorrer = 92,
	FOVSuavizado = 8,
	VelocidadCaminar = 16,
	VelocidadCorrer = 26,
	TeclaCorrer = Enum.KeyCode.LeftShift,
	Cabeceo = true,
	CabeceoFrecuencia = 0.6,
	CabeceoAmplitud = 0.12,
	Inclinacion = true,
	InclinacionMax = 2.5,
	ImpactoAterrizaje = 0.5,
}

local BRAZOS = {
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	["Left Arm"] = true, ["Right Arm"] = true,
}

local esMovil = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if esMovil then
	CONFIG.CabeceoAmplitud = 0.08
	CONFIG.InclinacionMax = 1.5
	CONFIG.FOV = 85
end

player.CameraMode = Enum.CameraMode.LockFirstPerson
camera.FieldOfView = CONFIG.FOV

local function lerp(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end

local sprinting = false
local tilt = 0
local currentHumanoid = nil

UserInputService.InputBegan:Connect(function(input, gpe)
	if not gpe and input.KeyCode == CONFIG.TeclaCorrer then
		sprinting = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == CONFIG.TeclaCorrer then
		sprinting = false
	end
end)

if esMovil then
	local gui = Instance.new("ScreenGui")
	gui.Name = "FP_Controles"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local boton = Instance.new("TextButton")
	boton.Name = "BotonCorrer"
	boton.Size = UDim2.fromOffset(80, 80)
	boton.AnchorPoint = Vector2.new(1, 1)
	boton.Position = UDim2.new(1, -30, 1, -140)
	boton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	boton.BackgroundTransparency = 0.4
	boton.Text = "CORRER"
	boton.TextColor3 = Color3.new(1, 1, 1)
	boton.TextScaled = true
	boton.Font = Enum.Font.GothamBold
	boton.AutoButtonColor = false
	boton.Parent = gui
	Instance.new("UICorner", boton).CornerRadius = UDim.new(1, 0)

	local function pintar()
		boton.BackgroundColor3 = sprinting and Color3.fromRGB(0, 170, 90) or Color3.fromRGB(30, 30, 30)
	end

	boton.Activated:Connect(function()
		sprinting = not sprinting
		pintar()
	end)

	RunService.Heartbeat:Connect(function()
		local hum = currentHumanoid
		if sprinting and hum and hum.MoveDirection.Magnitude == 0 then
			sprinting = false
			pintar()
		end
	end)
end

RunService:BindToRenderStep("FP_Tilt", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local hum = currentHumanoid
	local target = 0
	if CONFIG.Inclinacion and hum and hum.Health > 0 then
		local strafe = hum.MoveDirection:Dot(camera.CFrame.RightVector)
		target = -strafe * CONFIG.InclinacionMax
	end
	tilt = lerp(tilt, target, dt * 8)
	camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, math.rad(tilt))
end)

local function configurarPersonaje(character)
	local humanoid = character:WaitForChild("Humanoid")
	currentHumanoid = humanoid

	local partes = {}

	local function registrar(obj)
		if not obj:IsA("BasePart") or obj.Name == "HumanoidRootPart" then return end
		if obj:FindFirstAncestorOfClass("Tool") then return end
		partes[obj] = CONFIG.MostrarBrazos and BRAZOS[obj.Name] == true
	end

	for _, obj in ipairs(character:GetDescendants()) do
		registrar(obj)
	end
	character.DescendantAdded:Connect(registrar)
	character.DescendantRemoving:Connect(function(obj)
		partes[obj] = nil
	end)

	local bobTime, bobOffset, landOffset = 0, Vector3.zero, 0

	humanoid.StateChanged:Connect(function(_, nuevo)
		if nuevo == Enum.HumanoidStateType.Landed then
			landOffset = -CONFIG.ImpactoAterrizaje
		end
	end)

	local conexion
	conexion = RunService.RenderStepped:Connect(function(dt)
		if not character.Parent or humanoid.Health <= 0 then
			conexion:Disconnect()
			if currentHumanoid == humanoid then currentHumanoid = nil end
			return
		end

		for parte, visible in pairs(partes) do
			parte.LocalTransparencyModifier = visible and 0 or 1
		end

		local root = humanoid.RootPart
		local vel = root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude or 0
		local corriendo = sprinting and humanoid.MoveDirection.Magnitude > 0

		humanoid.WalkSpeed = corriendo and CONFIG.VelocidadCorrer or CONFIG.VelocidadCaminar
		camera.FieldOfView = lerp(camera.FieldOfView, corriendo and CONFIG.FOVCorrer or CONFIG.FOV, dt * CONFIG.FOVSuavizado)

		local objetivo = Vector3.zero
		local enSuelo = humanoid.FloorMaterial ~= Enum.Material.Air
		if CONFIG.Cabeceo and vel > 1 and enSuelo then
			bobTime += dt * vel * CONFIG.CabeceoFrecuencia
			objetivo = Vector3.new(
				math.cos(bobTime * 0.5) * CONFIG.CabeceoAmplitud,
				math.abs(math.sin(bobTime)) * CONFIG.CabeceoAmplitud,
				0
			)
		end

		bobOffset = bobOffset:Lerp(objetivo, math.clamp(dt * 10, 0, 1))
		landOffset = lerp(landOffset, 0, dt * 8)
		humanoid.CameraOffset = bobOffset + Vector3.new(0, landOffset, 0)
	end)
end

if player.Character then configurarPersonaje(player.Character) end
player.CharacterAdded:Connect(configurarPersonaje)
]==])

---------------------------------------------------------------------
-- 2) PISTOLA (Tool + Handle + Script + LocalScript)
---------------------------------------------------------------------
limpiar(StarterPack, "Pistola")
local tool = Instance.new("Tool")
tool.Name = "Pistola"
tool.RequiresHandle = true
tool.CanBeDropped = false
tool.ToolTip = "Pistola"

local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.4, 0.8, 2)
handle.Color = Color3.fromRGB(35, 35, 40)
handle.Material = Enum.Material.Metal
handle.Parent = tool

local servidor = Instance.new("Script")
servidor.Name = "PistolaServidor"
servidor.Source = [==[
local Debris = game:GetService("Debris")
local tool = script.Parent
local handle = tool:WaitForChild("Handle")

local remote = Instance.new("RemoteEvent")
remote.Name = "Accion"
remote.Parent = tool

local CFG = {
	Dano = 25,
	Alcance = 500,
	Cadencia = 0.15,
	Cargador = 12,
	Recarga = 1.5,
	Dispersion = 0.01,
}

tool:SetAttribute("Ammo", CFG.Cargador)
local ultimo, recargando = 0, false

local sonido = Instance.new("Sound")
sonido.SoundId = "" -- pon aquí tu sonido: "rbxassetid://ID"
sonido.Parent = handle

local luz = Instance.new("PointLight")
luz.Color = Color3.fromRGB(255, 170, 60)
luz.Range, luz.Brightness, luz.Enabled = 12, 4, false
luz.Parent = handle

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude

local function recargar()
	if recargando or tool:GetAttribute("Ammo") == CFG.Cargador then return end
	recargando = true
	task.wait(CFG.Recarga)
	tool:SetAttribute("Ammo", CFG.Cargador)
	recargando = false
end

remote.OnServerEvent:Connect(function(plr, accion, destino)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or tool.Parent ~= char then return end

	if accion == "R" then
		return recargar()
	end
	if accion ~= "F" or typeof(destino) ~= "Vector3" or recargando then return end

	local ammo = tool:GetAttribute("Ammo")
	if ammo <= 0 or os.clock() - ultimo < CFG.Cadencia * 0.9 then return end
	ultimo = os.clock()
	tool:SetAttribute("Ammo", ammo - 1)

	local origen = char.Head.Position
	local dir = (destino - origen).Unit
	dir += Vector3.new(math.random() - .5, math.random() - .5, math.random() - .5) * CFG.Dispersion * 2
	rp.FilterDescendantsInstances = {char}

	local res = workspace:Raycast(origen, dir.Unit * CFG.Alcance, rp)
	local fin = res and res.Position or origen + dir.Unit * CFG.Alcance

	if res then
		local modelo = res.Instance:FindFirstAncestorOfClass("Model")
		local h = modelo and modelo:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then
			local viejo = h:FindFirstChild("creator")
			if viejo then viejo:Destroy() end
			local tag = Instance.new("ObjectValue")
			tag.Name, tag.Value, tag.Parent = "creator", plr, h
			Debris:AddItem(tag, 3)

			local headshot = res.Instance.Name == "Head"
			h:TakeDamage(headshot and CFG.Dano * 2 or CFG.Dano)
			remote:FireClient(plr, "Hit", headshot)
		end
	end

	local ini = handle.Position
	local dist = (fin - ini).Magnitude
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Color = Enum.Material.Neon, Color3.fromRGB(255, 220, 100)
	p.Size = Vector3.new(0.06, 0.06, dist)
	p.CFrame = CFrame.lookAt(ini, fin) * CFrame.new(0, 0, -dist / 2)
	p.Parent = workspace
	Debris:AddItem(p, 0.06)

	luz.Enabled = true
	task.delay(0.05, function() luz.Enabled = false end)
	sonido:Play()
end)
]==]
servidor.Parent = tool

local cliente = Instance.new("LocalScript")
cliente.Name = "PistolaCliente"
cliente.Source = [==[
local tool = script.Parent
local plr = game.Players.LocalPlayer
local cam = workspace.CurrentCamera
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local remote = tool:WaitForChild("Accion")

local CADENCIA, RETROCESO = 0.15, 0.02
local retro, disparando = 0, false

local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn, gui.IgnoreGuiInset = false, true

local mira = Instance.new("Frame", gui)
mira.Size, mira.AnchorPoint, mira.Position = UDim2.fromOffset(6, 6), Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
mira.BackgroundColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", mira).CornerRadius = UDim.new(1, 0)

local txt = Instance.new("TextLabel", gui)
txt.Size, txt.AnchorPoint, txt.Position = UDim2.fromOffset(160, 36), Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -20)
txt.BackgroundTransparency, txt.TextColor3, txt.Font, txt.TextSize = 1, Color3.new(1, 1, 1), Enum.Font.GothamBold, 28

local marca = Instance.new("TextLabel", gui)
marca.Size, marca.AnchorPoint, marca.Position = UDim2.fromOffset(40, 40), Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
marca.BackgroundTransparency, marca.Text, marca.Font, marca.TextSize, marca.Visible = 1, "✕", Enum.Font.GothamBold, 36, false

local function actualizar()
	txt.Text = "🔫 " .. (tool:GetAttribute("Ammo") or 0)
end
tool:GetAttributeChangedSignal("Ammo"):Connect(actualizar)
actualizar()

remote.OnClientEvent:Connect(function(accion, headshot)
	if accion ~= "Hit" then return end
	marca.TextColor3 = headshot and Color3.fromRGB(255, 60, 60) or Color3.new(1, 1, 1)
	marca.Visible = true
	task.delay(0.12, function() marca.Visible = false end)
end)

tool.Equipped:Connect(function()
	gui.Parent = plr:WaitForChild("PlayerGui")
end)
tool.Unequipped:Connect(function()
	gui.Parent = nil
	disparando = false
end)

local function disparar()
	local rayo = cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = {plr.Character}
	local res = workspace:Raycast(rayo.Origin, rayo.Direction * 500, rp)
	remote:FireServer("F", res and res.Position or rayo.Origin + rayo.Direction * 500)
	retro = math.min(retro + RETROCESO, 0.12)
end

tool.Activated:Connect(function()
	disparando = true
	while disparando and tool.Parent == plr.Character do
		if (tool:GetAttribute("Ammo") or 0) > 0 then
			disparar()
		else
			remote:FireServer("R")
		end
		task.wait(CADENCIA)
	end
end)
tool.Deactivated:Connect(function()
	disparando = false
end)

UIS.InputBegan:Connect(function(i, gpe)
	if not gpe and i.KeyCode == Enum.KeyCode.R then
		remote:FireServer("R")
	end
end)

RS:BindToRenderStep("Retroceso", Enum.RenderPriority.Camera.Value + 1, function(dt)
	retro -= retro * math.min(dt * 10, 1)
	cam.CFrame *= CFrame.Angles(retro, 0, 0)
end)
]==]
cliente.Parent = tool

tool.Parent = StarterPack

---------------------------------------------------------------------
-- 3) PARTIDA (bajas, muertes, escudo, regeneración)
---------------------------------------------------------------------
crear("Script", "Partida", ServerScriptService, [==[
local Players = game:GetService("Players")

local CFG = {
	Respawn = 3,
	Escudo = 3,
	RegenDelay = 5,
	Regen = 5,
}

Players.RespawnTime = CFG.Respawn

local function crearStats(plr)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = plr
	for _, nombre in {"Kills", "Muertes"} do
		local v = Instance.new("IntValue")
		v.Name = nombre
		v.Parent = ls
	end
end

local function configurarPersonaje(plr, char)
	local hum = char:WaitForChild("Humanoid")

	local ff = Instance.new("ForceField")
	ff.Parent = char
	task.delay(CFG.Escudo, function() ff:Destroy() end)

	hum.Died:Connect(function()
		plr.leaderstats.Muertes.Value += 1
		local tag = hum:FindFirstChild("creator")
		local asesino = tag and tag.Value
		if asesino and asesino ~= plr and asesino.Parent then
			asesino.leaderstats.Kills.Value += 1
		end
	end)

	local ultimoDano, vidaPrev = 0, hum.Health
	hum.HealthChanged:Connect(function(h)
		if h < vidaPrev then ultimoDano = os.clock() end
		vidaPrev = h
	end)

	task.spawn(function()
		while hum.Parent and hum.Health > 0 do
			task.wait(1)
			if os.clock() - ultimoDano > CFG.RegenDelay and hum.Health < hum.MaxHealth then
				hum.Health = math.min(hum.Health + CFG.Regen, hum.MaxHealth)
			end
		end
	end)
end

Players.PlayerAdded:Connect(function(plr)
	crearStats(plr)
	plr.CharacterAdded:Connect(function(char)
		configurarPersonaje(plr, char)
	end)
end)
]==])

-- Script vacío "Health" para desactivar la regeneración por defecto de Roblox
crear("Script", "Health", StarterCharacterScripts, "-- vacío a propósito: desactiva la regeneración por defecto de Roblox\n")

---------------------------------------------------------------------
-- 4) HUD (barra de vida + pantalla roja)
---------------------------------------------------------------------
crear("LocalScript", "HUD", StarterGui, [==[
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local plr = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "HUD", false, true
gui.Parent = plr:WaitForChild("PlayerGui")

local dano = Instance.new("Frame", gui)
dano.Size, dano.BorderSizePixel = UDim2.fromScale(1, 1), 0
dano.BackgroundColor3, dano.BackgroundTransparency = Color3.fromRGB(200, 0, 0), 1

local fondo = Instance.new("Frame", gui)
fondo.Size, fondo.Position = UDim2.fromOffset(240, 18), UDim2.new(0, 20, 1, -40)
fondo.BackgroundColor3, fondo.BackgroundTransparency = Color3.fromRGB(20, 20, 20), 0.3
Instance.new("UICorner", fondo)

local barra = Instance.new("Frame", fondo)
barra.Size = UDim2.fromScale(1, 1)
Instance.new("UICorner", barra)

local function enlazar(char)
	local hum = char:WaitForChild("Humanoid")
	local previa = hum.Health

	local function actualizar(h)
		local p = math.clamp(h / hum.MaxHealth, 0, 1)
		barra.Size = UDim2.fromScale(p, 1)
		barra.BackgroundColor3 = Color3.fromRGB(220, 60, 60):Lerp(Color3.fromRGB(80, 220, 100), p)
		if h < previa then
			dano.BackgroundTransparency = 0.6
			TweenService:Create(dano, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
		end
		previa = h
	end

	actualizar(hum.Health)
	hum.HealthChanged:Connect(actualizar)
end

if plr.Character then enlazar(plr.Character) end
plr.CharacterAdded:Connect(enlazar)
]==])

print("✅ Shooter FPS instalado. Presiona Play para probar.")
