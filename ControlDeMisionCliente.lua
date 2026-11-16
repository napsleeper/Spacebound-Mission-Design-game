--[[
	CONTROL DE MISIÓN · Roblox · SCRIPT DEL JUGADOR · v5

	DÓNDE VA
	  StarterPlayer > StarterPlayerScripts > Insert Object > LocalScript
	  → pegá este archivo completo.

	ESTRUCTURA v5
	  Hijos de este LocalScript: "PanelRecursos" (masa, presupuesto, energía, propulsión, enlace),
	  "Cinematica" (despegue del Atlas V, órbita, aterrizaje en Marte y llegada a la sala), "Consolas" (pantallas
	  táctiles del escritorio, el laboratorio y la planificación; cámara remota; vista sentado) y
	  "Ensamblaje" (brazos robóticos del hangar).
	  Usa los módulos compartidos de ReplicatedStorage > ControlDeMisionCompartido.

	QUÉ HACE
	  - Portada y elección de misión a pantalla completa (no se ve al personaje:
	    la cámara muestra el hangar desde arriba).
	  - Barra de fases arriba y un cartel grande cada vez que cambia la fase.
	  - Pantalla limpia (v4): barra de fases, las dos barras de masa y presupuesto, un botón
	    chico y avisos breves que se apagan solos. Los datos se leen en los monitores del mundo.
	  - Escribe el texto de esos monitores y anima el gráfico de vuelo
	    (vista orbital GMAT de la sonda, perfil del cráter del vehículo).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- El servidor crea "MisionRemote" al arrancar. Si no aparece, el script del servidor no está corriendo.
local remote = ReplicatedStorage:WaitForChild("MisionRemote", 15)
if not remote then
	warn("[ControlDeMision] No encuentro el script del servidor. Va en ServerScriptService, dentro de un Script.")
	local errorGui = Instance.new("ScreenGui")
	errorGui.Name = "AvisoControlDeMision"
	errorGui.ResetOnSpawn = false
	local message = Instance.new("TextLabel")
	message.Position = UDim2.new(0, 12, 0, 12)
	message.Size = UDim2.new(0, 420, 0, 110)
	message.BackgroundColor3 = Color3.fromRGB(252, 61, 33)
	message.BorderSizePixel = 0
	message.TextColor3 = Color3.new(1, 1, 1)
	message.TextWrapped = true
	message.Font = Enum.Font.GothamBold
	message.TextSize = 16
	message.Text = "FALTA EL SCRIPT DEL SERVIDOR.\nPegá ControlDeMision.server.lua en un Script dentro de ServerScriptService y volvé a darle Play."
	message.Parent = errorGui
	errorGui.Parent = playerGui
	return
end
print("[ControlDeMision] Script del jugador conectado.")

local SPACE = Color3.fromRGB(5, 11, 31)
local NAVY = Color3.fromRGB(10, 22, 52)
local INK = Color3.fromRGB(10, 26, 68)
local BLUE = Color3.fromRGB(11, 61, 145)
local BLUE_HI = Color3.fromRGB(59, 123, 240)
local RED = Color3.fromRGB(252, 61, 33)
local WHITE = Color3.fromRGB(245, 247, 250)
local MUTED = Color3.fromRGB(157, 179, 222)
local GREEN = Color3.fromRGB(61, 255, 122)

local function make(className, props, parent)
	local obj = Instance.new(className)
	for name, value in pairs(props) do
		obj[name] = value
	end
	obj.Parent = parent
	return obj
end

-- Texto que se adapta al tamaño de la pantalla, con un máximo
local function label(parent, props, maxSize)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextScaled = true
	props.TextWrapped = true
	local item = make("TextLabel", props, parent)
	make("UITextSizeConstraint", { MaxTextSize = maxSize or 24, MinTextSize = 8 }, item)
	return item
end

local function button(parent, props, maxSize)
	props.BorderSizePixel = 0
	props.BackgroundColor3 = props.BackgroundColor3 or RED
	props.Font = Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	props.AutoButtonColor = true
	local item = make("TextButton", props, parent)
	make("UITextSizeConstraint", { MaxTextSize = maxSize or 26, MinTextSize = 8 }, item)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
	}, item)
	return item
end

local gui = make("ScreenGui", {
	Name = "ControlDeMisionGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5,
}, playerGui)

local PanelRecursos = require(script:WaitForChild("PanelRecursos"))
local Cinematica = require(script:WaitForChild("Cinematica"))
local Consolas = require(script:WaitForChild("Consolas"))
local Ensamblaje = require(script:WaitForChild("Ensamblaje"))
local Compartido = ReplicatedStorage:WaitForChild("ControlDeMisionCompartido")
local Educativo = require(Compartido:WaitForChild("Educativo"))
local Ingenieria = require(Compartido:WaitForChild("Ingenieria"))
local DatosGMAT = require(Compartido:WaitForChild("DatosGMAT"))

-- Contenedor de los paneles de datos: se oculta durante las cinemáticas
local panelHolder = make("Frame", { Name = "Paneles", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
local panel = PanelRecursos.new(panelHolder, remote)
local inGame = false

---------------------------------------------------------------------------
-- 1. MENÚ: PORTADA Y ELECCIÓN DE MISIÓN
---------------------------------------------------------------------------
local menu = make("Frame", {
	Name = "Menu", Size = UDim2.fromScale(1, 1), BackgroundColor3 = SPACE, BackgroundTransparency = 0.25,
	BorderSizePixel = 0, Visible = true,
}, gui)

-- Portada
local titlePage = make("Frame", { Name = "Portada", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, menu)
label(titlePage, {
	Position = UDim2.fromScale(0.06, 0.2), Size = UDim2.fromScale(0.6, 0.04),
	Text = "DIRECTIVA NPR 7120.5 · MISIONES ROBÓTICAS", TextColor3 = RED, Font = Enum.Font.GothamBold,
}, 20)
label(titlePage, {
	Position = UDim2.fromScale(0.06, 0.25), Size = UDim2.fromScale(0.6, 0.3),
	Text = "CONTROL\nDE MISIÓN", Font = Enum.Font.GothamBlack,
}, 120)
local stripe = make("Frame", {
	Position = UDim2.fromScale(0.06, 0.57), Size = UDim2.fromScale(0.3, 0.014), BackgroundTransparency = 1,
}, titlePage)
for index, color in ipairs({ RED, WHITE, BLUE_HI }) do
	make("Frame", {
		Position = UDim2.fromScale((index - 1) / 3, 0), Size = UDim2.fromScale(1 / 3, 1),
		BackgroundColor3 = color, BorderSizePixel = 0,
	}, stripe)
end
label(titlePage, {
	Position = UDim2.fromScale(0.06, 0.61), Size = UDim2.fromScale(0.5, 0.1),
	Text = "Armá la nave en el hangar, pasá la revisión de diseño crítico y dirigí el vuelo. Cada kilo y cada millón cuentan.",
	TextColor3 = MUTED, TextYAlignment = Enum.TextYAlignment.Top,
}, 24)
local startButton = button(titlePage, {
	Position = UDim2.fromScale(0.06, 0.75), Size = UDim2.fromScale(0.22, 0.09), Text = "INICIAR",
}, 34)

-- Elección de misión
local missionPage = make("Frame", {
	Name = "Misiones", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
}, menu)
label(missionPage, {
	Position = UDim2.fromScale(0.06, 0.08), Size = UDim2.fromScale(0.88, 0.04),
	Text = "FASE A · ESTUDIOS CONCEPTUALES", TextColor3 = RED, Font = Enum.Font.GothamBold,
}, 20)
label(missionPage, {
	Position = UDim2.fromScale(0.06, 0.12), Size = UDim2.fromScale(0.88, 0.08),
	Text = "ELEGÍ EL EXPEDIENTE DE MISIÓN", Font = Enum.Font.GothamBlack,
}, 44)

local function missionCard(xScale, key, tagText, name, description, specs)
	local card = make("Frame", {
		Position = UDim2.fromScale(xScale, 0.24), Size = UDim2.fromScale(0.42, 0.66),
		BackgroundColor3 = NAVY, BorderSizePixel = 0,
	}, missionPage)
	make("UIStroke", { Color = BLUE, Thickness = 2 }, card)
	local plate = make("Frame", { Size = UDim2.fromScale(1, 0.26), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, card)
	make("Frame", { Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = RED, BorderSizePixel = 0 }, plate)
	label(plate, {
		Position = UDim2.fromScale(0.05, 0.14), Size = UDim2.fromScale(0.9, 0.24),
		Text = tagText, TextColor3 = RED, Font = Enum.Font.GothamBold,
	}, 16)
	label(plate, {
		Position = UDim2.fromScale(0.05, 0.42), Size = UDim2.fromScale(0.9, 0.48),
		Text = name, TextColor3 = INK, Font = Enum.Font.GothamBlack,
	}, 34)
	label(card, {
		Position = UDim2.fromScale(0.05, 0.3), Size = UDim2.fromScale(0.9, 0.2),
		Text = description, TextColor3 = MUTED, TextYAlignment = Enum.TextYAlignment.Top,
	}, 20)
	label(card, {
		Position = UDim2.fromScale(0.05, 0.52), Size = UDim2.fromScale(0.9, 0.26),
		Text = specs, TextYAlignment = Enum.TextYAlignment.Top,
	}, 20)
	local choose = button(card, {
		Position = UDim2.fromScale(0.05, 0.82), Size = UDim2.fromScale(0.9, 0.13), Text = "ELEGIR ESTA MISIÓN",
	}, 26)
	choose.Activated:Connect(function()
		remote:FireServer("selectMission", key)
	end)
end

missionCard(0.06, "probe", "EXPEDIENTE 01 · ESPACIO PROFUNDO", "NEW HORIZONS · PLUTÓN",
	"Misión real de 2006. Sale en un Atlas V a 16,2 km/s, Júpiter la acelera y llega a Plutón en 2015.",
	"Presupuesto del juego: $100 M\nMasa al lanzar: menos de 480 kg (77 kg de hidracina)\nSubsistemas críticos: 4")
missionCard(0.52, "rover", "EXPEDIENTE 02 · SUPERFICIE DE MARTE", "PERSEVERANCE · MARTE",
	"Misión real de 2020. Lo llevás al Atlas V en un transportador; aterriza en el cráter Jezero con grúa celeste.",
	"Presupuesto del juego: $150 M\nMasa del rover: 1.025 kg\nSubsistemas críticos: 3")

startButton.Activated:Connect(function()
	titlePage.Visible = false
	missionPage.Visible = true
end)

---------------------------------------------------------------------------
-- 2. PANTALLA DE JUEGO: fases arriba y avisos abajo a la derecha
---------------------------------------------------------------------------
local hud = make("Frame", { Name = "Hud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)

-- Barra de fases
local PHASES = { { "A", "MISIÓN" }, { "BC", "HANGAR" }, { "DE", "VUELO" }, { "F", "INFORME" } }
local stepper = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0, 372, 0, 22),
	BackgroundTransparency = 1,
}, hud)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
}, stepper)
local chips = {}
for index, phase in ipairs(PHASES) do
	chips[index] = make("TextLabel", {
		LayoutOrder = index, Size = UDim2.new(0, 90, 1, 0), BackgroundColor3 = NAVY, BackgroundTransparency = 0.2, BorderSizePixel = 0,
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = MUTED, Text = index .. " · " .. phase[2],
	}, stepper)
end

local function showStepper(key)
	local current = 0
	for index, phase in ipairs(PHASES) do
		if phase[1] == key then
			current = index
		end
	end
	for index, chip in ipairs(chips) do
		if index < current then
			chip.BackgroundColor3, chip.TextColor3 = BLUE, WHITE
		elseif index == current then
			chip.BackgroundColor3, chip.TextColor3 = RED, WHITE
		else
			chip.BackgroundColor3, chip.TextColor3 = NAVY, MUTED
		end
	end
end

-- Cartel de cambio de fase: una sola línea bajo la barra, dura poco y se va solo
local banner = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.new(0, 460, 0, 24),
	BackgroundColor3 = NAVY, BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false,
}, hud)
make("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = RED, BorderSizePixel = 0 }, banner)
local bannerTitle = label(banner, {
	Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -16, 1, 0), Text = "",
	TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center,
}, 13)
local bannerToken = 0

Cinematica.init(remote, function(visible)
	hud.Visible = visible and inGame
	panelHolder.Visible = visible
end)
Consolas.init({ remote = remote, Educativo = Educativo, Ingenieria = Ingenieria, DatosGMAT = DatosGMAT, Cinematica = Cinematica })
Ensamblaje.init()

local function showBanner(title, subtitle)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = (title or "") .. ((subtitle and subtitle ~= "") and ("  ·  " .. subtitle) or "")
	banner.Visible = true
	task.delay(2.5, function()
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

-- Botón chico para volver al menú
local menuButton = make("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UserInputService.TouchEnabled and UDim2.new(0, 12, 0, 120) or UDim2.new(0, 12, 1, -12),
	Size = UDim2.new(0, 96, 0, 22), BackgroundColor3 = NAVY, BackgroundTransparency = 0.45, BorderSizePixel = 0,
	Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = MUTED, Text = "← MISIONES",
}, hud)
menuButton.Activated:Connect(function()
	remote:FireServer("menu")
end)

-- TOUR DEL MAPA: planos de dron por el centro espacial (tecla T o este botón). No toca la portada.
local function startTour()
	if Cinematica.isTouring() then
		Cinematica.stopTour()
		return
	end
	local menuWasVisible = menu.Visible
	menu.Visible = false
	hud.Visible = false
	panelHolder.Visible = false
	Cinematica.tour(function()
		menu.Visible = menuWasVisible
		hud.Visible = inGame
		panelHolder.Visible = inGame
	end)
end
local tourButton = make("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UserInputService.TouchEnabled and UDim2.new(0, 112, 0, 120) or UDim2.new(0, 112, 1, -12),
	Size = UDim2.new(0, 110, 0, 22), BackgroundColor3 = NAVY, BackgroundTransparency = 0.45, BorderSizePixel = 0,
	Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = MUTED, Text = "🎬 TOUR (T)",
}, hud)
tourButton.Activated:Connect(startTour)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.T or UserInputService:GetFocusedTextBox() then
		return
	end
	if Cinematica.isActive() then
		return
	end
	startTour()
end)

-- Mensajes abajo a la derecha
local messageLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, UserInputService.TouchEnabled and -150 or -12),
	Size = UDim2.new(0, 280, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = SPACE, BackgroundTransparency = 0.3, BorderSizePixel = 0, Visible = false,
	Font = Enum.Font.Code, TextSize = 14, TextColor3 = GREEN, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, hud)
make("UIPadding", {
	PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
	PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
}, messageLabel)
local messageToken = 0

---------------------------------------------------------------------------
-- 3. CÁMARA DEL MENÚ Y MONITORES DEL MUNDO
---------------------------------------------------------------------------
local menuCamera = nil          -- CFrame que manda el servidor; mientras exista, la cámara queda fija

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if menuCamera and camera and not Cinematica.isTouring() then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = menuCamera
	end
end)

local function releaseCamera()
	menuCamera = nil
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- El servidor dice qué va en cada monitor; acá se escribe en la pieza con ese nombre.
-- Puede ser texto o una TARJETA (tabla con ícono grande, título, frase y fichas: ver Consolas.tarjeta).
-- Se reintenta cada medio segundo porque una sala lejana puede tardar en cargarse.
local screenTexts = {}
local screenVersions = {}       -- sube cada vez que cambia el contenido, para redibujar la tarjeta una sola vez

local function applyScreens()
	local folder = workspace:FindFirstChild("ControlDeMision")
	local screens = folder and folder:FindFirstChild("Pantallas")
	if not screens then
		return
	end
	for name, value in pairs(screenTexts) do
		local part = screens:FindFirstChild(name)
		local surface = part and part:FindFirstChildOfClass("SurfaceGui")
		local textLabel = surface and surface:FindFirstChild("Texto")
		if textLabel then
			local current = surface:FindFirstChild("Tarjeta")
			if type(value) == "table" then
				if not current or current:GetAttribute("Version") ~= screenVersions[name] then
					if current then
						current:Destroy()
					end
					Consolas.tarjeta(surface, value):SetAttribute("Version", screenVersions[name])
				end
				textLabel.Visible = false
			else
				if current then
					current:Destroy()
				end
				textLabel.Visible = true
				if textLabel.Text ~= value then
					textLabel.Text = value
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		applyScreens()
		task.wait(0.5)
	end
end)

-- Gráfico de vuelo: el servidor dibuja la pantalla y acá se mueve el marcador.
-- Las medidas son las mismas que usa el script del servidor.
local PROFILE = { left = 0.08, right = 0.97, top = 0.26, depth = 0.46 }
local roverTarget, roverNow = 0.20, 0.20
local PROBE_STOPS = { 0.04, 0.35, 0.97, 1 }          -- TCM-1 · Júpiter · Plutón · fin
local probeTarget, probeNow = PROBE_STOPS[1], 0
local markers = {}

local function findMarker(missionKey)
	local cached = markers[missionKey]
	if cached and cached.Parent then
		return cached
	end
	local folder = workspace:FindFirstChild("ControlDeMision")
	local graphs = folder and folder:FindFirstChild("Graficos")
	local part = graphs and graphs:FindFirstChild(missionKey)
	local surface = part and part:FindFirstChild("Grafico")
	local canvas = surface and surface:FindFirstChild("Lienzo")
	local found = canvas and canvas:FindFirstChild("Marcador")
	markers[missionKey] = found
	return found
end

RunService.RenderStepped:Connect(function(dt)
	local probe = findMarker("probe")
	if probe then
		-- v8: New Horizons avanza por su trayectoria real (Tierra → Júpiter → Plutón) evento a evento
		probeNow += (probeTarget - probeNow) * math.min(1, dt * 0.6)
		local x, y = Educativo.trayectoriaGrafico(probeNow)
		probe.Position = UDim2.fromScale(x, y)
	end
	local rover = findMarker("rover")
	if rover then
		roverNow += (roverTarget - roverNow) * math.min(1, dt * 0.8)        -- avanza de a poco hasta la parada
		local n = roverNow + math.sin(os.clock() * 2) * 0.004
		local x = PROFILE.left + n * (PROFILE.right - PROFILE.left)
		local y = PROFILE.top + math.exp(-((n - 0.55) * 5) ^ 2) * PROFILE.depth
		rover.Position = UDim2.fromScale(x, y - 0.035)
	end
end)

---------------------------------------------------------------------------
-- 4. MENSAJES DEL SERVIDOR
---------------------------------------------------------------------------
remote.OnClientEvent:Connect(function(action, a, b, c)
	if action == "showMenu" then
		Cinematica.cancel()
		inGame = false
		Consolas.setMission(nil)
		panel:update({ visible = false })
		menuCamera = a
		hud.Visible = false
		menu.Visible = true
		titlePage.Visible = b == true          -- la portada solo al entrar al juego
		missionPage.Visible = b ~= true
	elseif action == "enterGame" then
		Consolas.setMission(a)
		Cinematica.cancel()
		inGame = true
		panelHolder.Visible = true
		releaseCamera()
		menu.Visible = false
		hud.Visible = true
		messageLabel.Visible = false
	elseif action == "phase" then
		showStepper(a)
		showBanner(b, c)
	elseif action == "track" then
		if a == "probe" then
			local index = math.clamp(math.floor(tonumber(b) or 0), 0, 3)
			probeTarget = PROBE_STOPS[index + 1]
			if index == 0 then
				probeNow = 0
			end
			Consolas.setStage(index)
		elseif a == "rover" then
			roverTarget = 0.20 + math.clamp(b, 0, 3) * 0.175
			if b == 0 then
				roverNow = 0.20
			end
		end
	elseif action == "screen" then
		screenTexts[a] = b
		screenVersions[a] = (screenVersions[a] or 0) + 1
		applyScreens()
	elseif action == "say" then
		messageToken += 1
		local token = messageToken
		messageLabel.Text = a
		messageLabel.Visible = true
		task.delay(6, function()
			if token == messageToken then
				messageLabel.Visible = false
			end
		end)
	elseif action == "resources" then
		panel:update(a)
		Consolas.onResources(a)
	elseif action == "console" then
		Consolas.onConsole(a)
	elseif action == "alert" then
		Consolas.onAlert(a)
	elseif action == "maneuverResult" then
		Consolas.onManeuverResult(a)
	elseif action == "labResult" then
		Consolas.onLabResult(a)
	elseif action == "install" then
		Ensamblaje.install(a)
	elseif action == "installed" then
		Ensamblaje.installed(a)
	elseif action == "insert" then
		Ensamblaje.insert(a)
	elseif action == "removing" then
		Ensamblaje.removing(a)
	elseif action == "tip" then
		if type(a) == "string" and a ~= "" then
			panel:toast(a)
		end
	elseif action == "cinematic" then
		panel:update({ visible = false })
		Cinematica.play(a)
	elseif action == "arrive" then
		Cinematica.arrive(a, b)
	end
end)

---------------------------------------------------------------------------
-- 5. TRANSPORTADOR DEL ROVER: manda al servidor los mandos del asiento (W/S y A/D)
--    El módulo de control de Roblox llena ThrottleFloat/SteerFloat del asiento en este cliente
--    (teclado, joystick táctil o gamepad); si no, se leen las teclas directamente.
---------------------------------------------------------------------------
local lastDrive, lastDriveAt = nil, 0
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat or not seat:IsA("VehicleSeat") or seat.Name ~= "rover-Transportador" then
		lastDrive = nil
		return
	end
	local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
	if throttle == 0 and steer == 0 and not UserInputService:GetFocusedTextBox() then
		local function key(code)
			return UserInputService:IsKeyDown(code) and 1 or 0
		end
		throttle = key(Enum.KeyCode.W) + key(Enum.KeyCode.Up) - key(Enum.KeyCode.S) - key(Enum.KeyCode.Down)
		steer = key(Enum.KeyCode.D) + key(Enum.KeyCode.Right) - key(Enum.KeyCode.A) - key(Enum.KeyCode.Left)
	end
	local now = os.clock()
	local value = string.format("%.2f|%.2f", throttle, steer)
	if (value ~= lastDrive and now - lastDriveAt > 0.05) or now - lastDriveAt > 0.25 then
		lastDrive, lastDriveAt = value, now
		remote:FireServer("drive", { t = throttle, s = steer })
	end
end)

---------------------------------------------------------------------------
-- INTRO "SPACEBOUND": pantalla de apertura animada (antes de la portada).
-- Lluvia de asteroides 3D, un jet que cruza dejando la estela azul y el logo que entra letra
-- por letra con un brillo. Se saltea con un clic, un toque o cualquier tecla.
-- LOGO OFICIAL: subí la imagen del logo a Roblox (Creator Hub > Assets > Images) y pegá el id
-- acá (por ejemplo "rbxassetid://123456789"): se usa la imagen en vez del logo dibujado.
---------------------------------------------------------------------------
local INTRO_LOGO = ""

local function playIntro()
	local TweenService = game:GetService("TweenService")
	local LOGO_BLUE = Color3.fromRGB(22, 8, 170)
	local intro = make("ScreenGui", { Name = "IntroSpacebound", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100 }, playerGui)
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(9, 14, 18), BorderSizePixel = 0 }, intro)
	local function tw(obj, time, goal, style, dir)
		local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
		t:Play()
		return t
	end

	-- 1. Asteroides 3D que flotan y giran (ViewportFrame)
	local view = make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ImageTransparency = 1,
		Ambient = Color3.fromRGB(70, 74, 82), LightColor = Color3.fromRGB(255, 226, 190), LightDirection = Vector3.new(-0.6, -0.4, -1),
	}, root)
	local camera = make("Camera", { FieldOfView = 55, CFrame = CFrame.new(0, 0, 30) }, view)
	view.CurrentCamera = camera
	local random = Random.new(42)
	local rocks = {}
	for i = 1, 34 do
		local size = i <= 8 and random:NextNumber(4, 7) or random:NextNumber(0.6, 2.6)
		local model = make("Model", {}, view)
		for _ = 1, 3 do                                           -- tres bultos por roca: forma irregular
			make("Part", {
				Shape = Enum.PartType.Ball, Anchored = true, Material = Enum.Material.Slate,
				Color = Color3.fromRGB(random:NextInteger(48, 70), random:NextInteger(50, 70), random:NextInteger(52, 72)),
				Size = Vector3.new(size * random:NextNumber(0.7, 1.1), size * random:NextNumber(0.6, 0.95), size * random:NextNumber(0.7, 1.1)),
				CFrame = CFrame.new(random:NextNumber(-0.3, 0.3) * size, random:NextNumber(-0.3, 0.3) * size, random:NextNumber(-0.3, 0.3) * size),
			}, model)
		end
		model.WorldPivot = CFrame.new()
		table.insert(rocks, {
			model = model,
			pos = Vector3.new(random:NextNumber(-34, 34), random:NextNumber(-18, 18), random:NextNumber(-40, 8)),
			vel = Vector3.new(random:NextNumber(-0.8, 0.8), random:NextNumber(-0.5, 0.5), random:NextNumber(0.6, 2.2)),
			spin = Vector3.new(random:NextNumber(-0.6, 0.6), random:NextNumber(-0.6, 0.6), random:NextNumber(-0.4, 0.4)),
		})
	end
	local vignette = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0 }, root)
	make("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0.2) }),
	}, vignette)

	-- 2. Estela azul en diagonal y el jet que la dibuja
	local stage = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromScale(0.86, 0.36), BackgroundTransparency = 1 }, root)
	make("UIAspectRatioConstraint", { AspectRatio = 4 }, stage)
	local A, B = Vector2.new(0.03, 0.78), Vector2.new(0.97, 0.12)            -- de abajo a la izquierda hasta arriba a la derecha
	local angle = math.deg(math.atan2((B.Y - A.Y) * 0.25, B.X - A.X))         -- el lienzo es 4 veces más ancho que alto
	local trail = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(A.X, A.Y), Size = UDim2.new(0, 0, 0.035, 0),
		Rotation = angle, BackgroundColor3 = LOGO_BLUE, BorderSizePixel = 0, ZIndex = 2,
	}, stage)
	make("UIGradient", { Transparency = NumberSequence.new(0.85, 0) }, trail)
	local jet = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(A.X, A.Y), Size = UDim2.fromScale(0.05, 0.2), Rotation = angle, BackgroundTransparency = 1, ZIndex = 5 }, stage)
	local WHITE_JET = Color3.fromRGB(235, 238, 245)
	make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.16), BackgroundColor3 = WHITE_JET, BorderSizePixel = 0, ZIndex = 5 }, jet)
	make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.45, 0.5), Size = UDim2.fromScale(0.22, 0.95), BackgroundColor3 = WHITE_JET, BorderSizePixel = 0, ZIndex = 5 }, jet)
	make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.06, 0.5), Size = UDim2.fromScale(0.1, 0.5), BackgroundColor3 = WHITE_JET, BorderSizePixel = 0, ZIndex = 5 }, jet)

	-- 3. Logo: letra por letra (o la imagen oficial si está el id)
	local letters, logoImage = {}, nil
	local shine
	if INTRO_LOGO ~= "" then
		logoImage = make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = INTRO_LOGO, ImageTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 4 }, stage)
		make("UIScale", { Scale = 1.6 }, logoImage)
	else
		local word = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 0.62), BackgroundTransparency = 1, ZIndex = 4 }, stage)
		local text = "SPACEBOUND"
		for i = 1, #text do
			local label = make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((i - 0.5) / #text, 0.5), Size = UDim2.fromScale(1 / #text * 1.08, 1),
				BackgroundTransparency = 1, Text = text:sub(i, i), TextScaled = true, TextColor3 = LOGO_BLUE, TextTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Heavy), Rotation = -4, ZIndex = 4,
			}, word)
			local stroke = make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, Transparency = 1 }, label)
			local scale = make("UIScale", { Scale = 2.2 }, label)
			table.insert(letters, { label = label, stroke = stroke, scale = scale })
		end
		-- brillo que cruza las letras
		shine = make("UIGradient", {
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 170, 255)), ColorSequenceKeypoint.new(0.55, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) }),
			Offset = Vector2.new(-1, 0), Rotation = 20,
		}, word)
	end
	local tagline = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(0.6, 0.04), BackgroundTransparency = 1,
		Text = "CONTROL DE MISIÓN · NEW HORIZONS Y PERSEVERANCE", TextColor3 = Color3.fromRGB(170, 190, 230), TextTransparency = 1, TextScaled = true,
		Font = Enum.Font.GothamBold,
	}, root)
	local hint = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0.5, 0, 0, 20), BackgroundTransparency = 1,
		Text = "Tocá o hacé clic para continuar", TextColor3 = Color3.fromRGB(120, 135, 170), TextTransparency = 1, TextScaled = true,
		Font = Enum.Font.GothamMedium,
	}, root)
	local curtain = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 20 }, root)

	-- Animación
	local finished = false
	local t0 = os.clock()
	local step = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		for _, rock in ipairs(rocks) do                      -- las rocas avanzan hacia la cámara y vuelven al fondo
			rock.pos += rock.vel * dt
			if rock.pos.Z > 24 then
				rock.pos = Vector3.new(rock.pos.X, rock.pos.Y, -40)
			end
			rock.model:PivotTo(CFrame.new(rock.pos) * CFrame.Angles(rock.spin.X * t, rock.spin.Y * t, rock.spin.Z * t))
		end
		camera.CFrame = CFrame.new(math.sin(t * 0.3) * 1.5, math.cos(t * 0.25) * 0.8, 30)
		-- el jet cruza entre 0,9 s y 2,3 s y deja la estela
		local k = math.clamp((t - 0.9) / 1.4, 0, 1)
		k = 1 - (1 - k) ^ 3
		local p = A:Lerp(B, k)
		jet.Position = UDim2.fromScale(p.X, p.Y)
		local len = (Vector2.new((B.X - A.X), (B.Y - A.Y) * 0.25)).Magnitude * k
		trail.Size = UDim2.new(len, 0, 0.035, 0)
		jet.Visible = t > 0.9 and k < 1
		if shine then
			shine.Offset = Vector2.new(math.clamp((t - 3.2) / 0.9, 0, 1) * 2 - 1, 0)
		end
	end)

	tw(curtain, 0.8, { BackgroundTransparency = 1 })
	tw(view, 1.2, { ImageTransparency = 0 })
	task.delay(1.9, function()
		if logoImage then
			tw(logoImage, 0.5, { ImageTransparency = 0 })
			tw(logoImage:FindFirstChildOfClass("UIScale"), 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		for i, letter in ipairs(letters) do                    -- cada letra cae y rebota en su lugar
			task.delay((i - 1) * 0.07, function()
				tw(letter.label, 0.25, { TextTransparency = 0 })
				tw(letter.stroke, 0.25, { Transparency = 0 })
				tw(letter.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
	end)
	task.delay(2.9, function()                                  -- golpe: un leve temblor del logo
		for i = 1, 6 do
			stage.Position = UDim2.new(0.5, (i % 2 == 0 and 1 or -1) * (7 - i), 0.48, 0)
			task.wait(0.03)
		end
		stage.Position = UDim2.fromScale(0.5, 0.48)
	end)
	task.delay(3.6, function()
		tw(tagline, 0.6, { TextTransparency = 0 })
	end)
	task.delay(4.4, function()
		tw(hint, 0.6, { TextTransparency = 0.2 })
	end)

	local function finish()
		if finished then
			return
		end
		finished = true
		tw(curtain, 0.6, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
		step:Disconnect()
		root.Visible = false
		intro:Destroy()
	end
	local input = UserInputService.InputBegan:Connect(function(io)
		if os.clock() - t0 > 0.8 and (io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch
			or io.UserInputType == Enum.UserInputType.Keyboard or io.UserInputType == Enum.UserInputType.Gamepad1) then
			task.spawn(finish)
		end
	end)
	task.delay(8, finish)                                        -- si no tocan nada, sigue sola
	repeat
		task.wait(0.1)
	until finished and not intro.Parent
	input:Disconnect()
end

-- Al entrar: primero la intro animada y después la portada. El servidor responde con la cámara del hangar.
titlePage.Visible = true
missionPage.Visible = false
task.spawn(playIntro)
remote:FireServer("ready")
