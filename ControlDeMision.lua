--[[
	CONTROL DE MISIÓN · Roblox · SCRIPT DEL SERVIDOR · v5

	ESTRUCTURA (todo lo crea este archivo .rbxlx; si armás el lugar a mano, respetá los nombres)
	  ReplicatedStorage > ControlDeMisionCompartido (Folder)
	      Educativo · Componentes · Ingenieria · DatosGMAT   (ModuleScripts compartidos)
	  ServerScriptService > ControlDeMision (este Script)
	      Campus (ModuleScript)
	  StarterPlayer > StarterPlayerScripts > ControlDeMisionCliente (LocalScript)
	      PanelRecursos · Cinematica · Consolas · Ensamblaje (ModuleScripts)
	  Un solo RemoteEvent: ReplicatedStorage > MisionRemote (lo crea este script).

	REGLA DEL JUEGO: EL JUGADOR NUNCA VIAJA AL ESPACIO. Es un ingeniero en la Tierra.
	Arma y prueba en el centro espacial; durante la misión opera sentado en la sala de control.
	Las naves solo aparecen en cinemáticas y en la cámara remota.

	NOVEDADES v5
	  - Hangar: brazos robóticos que instalan cada pieza (animación normal, rápida u omitida),
	    retirar la última pieza (R), comparador A/B en cada sala, pantalla de especificaciones.
	  - Piezas, cohete y vehículo con más detalle.
	  - Laboratorio de Ingeniería configurable (atrio, este) y Centro de Planificación orbital
	    con Hohmann, vis-viva y datos GMAT (atrio, oeste).
	  - Sala de control: asiento, escritorio con 3 monitores (consola táctil en el centro),
	    pantalla gigante, gráfico orbital, cámara remota, historial, enlace y alertas.
	  - Evento 1 parametrizado: corrección orbital de la sonda (Δv, dirección, momento) y
	    ruta de descenso del vehículo (ángulo, velocidad), con predicción antes de enviar.
	  - Física revisada: masa seca, propelente, masa inicial y final, Isp, Δv y consumo.

	NOVEDADES v7
	  - Las dos naves viajan dentro de un ATLAS V (núcleo cobrizo, 4 propulsores sólidos y cofia
	    blanca con el logo de la NASA). La cofia se abre en dos mitades para cargar la nave.
	  - SONDA: se arma afuera, sobre un banco de integración; el brazo de la torre de servicio la
	    mete en la cofia. En el lanzamiento se abre el techo y el Atlas V sale al cielo estrellado.
	  - ROVER: va a MARTE (cráter Jezero). Los brazos lo cargan en un transportador que maneja el
	    jugador hasta la plataforma exterior; ahí el brazo de la torre lo mete en el Atlas V.
	    Llega a Marte con escudo térmico, paracaídas y grúa celeste (como Curiosity y Perseverance).
	  - Las naves se arman a escala reducida (VEHICLE_SCALE) para que entren en la cofia.

	AGREGAR UNA MISIÓN (por ejemplo Marte): sumá una entrada en MISSIONS con sus subsistemas,
	las fichas en Componentes, sus pruebas en Ingenieria, sus eventos en EVENTS/MIDDLE/ADVICE,
	un ORIGINS propio y su cinemática en Cinematica. Nada de lo existente se borra.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local remote = Instance.new("RemoteEvent")
remote.Name = "MisionRemote"
remote.Parent = ReplicatedStorage

local Campus = require(script:WaitForChild("Campus"))
local Compartido = ReplicatedStorage:WaitForChild("ControlDeMisionCompartido", 10)
if not Compartido then
	error("[ControlDeMision] Falta ReplicatedStorage > ControlDeMisionCompartido con Educativo, Componentes, Ingenieria y DatosGMAT.")
end
local Educativo = require(Compartido:WaitForChild("Educativo"))
local Componentes = require(Compartido:WaitForChild("Componentes"))
local Ingenieria = require(Compartido:WaitForChild("Ingenieria"))
local DatosGMAT = require(Compartido:WaitForChild("DatosGMAT"))


---------------------------------------------------------------------------
-- 1. DATOS DEL JUEGO (los mismos números que la versión web)
---------------------------------------------------------------------------
-- v8: misiones REALES. Las masas salen de la NASA/JPL/JHUAPL o, si no están publicadas por pieza,
-- son estimaciones marcadas (ver Componentes y DATOS_REALES.md). La masa de cada misión incluye la
-- plataforma (Componentes.BASE). Los COSTOS son del juego: la NASA no publica el costo de cada pieza.
-- La configuración real (★) usa exactamente el presupuesto y queda dentro del límite de masa.
local MISSIONS = {
	probe = {
		-- New Horizons: 401 kg secos + 77 kg de hidracina = 478 kg; la NASA exigía menos de 480 kg en total
		name = "NEW HORIZONS · SONDA A PLUTÓN", short = "NEW HORIZONS", budget = 100, massMax = 403, delay = "4 H 25 MIN", goalMB = 70,
		brief = "llegar a Plutón con ayuda de Júpiter y recibir en la Tierra al menos 70 MB de datos, con la nave sana.",
		meta = "Llegar a Plutón y mandar 70 MB a la Tierra",
		massNote = "masa seca: 480 kg − 77 kg de hidracina",
		subsystems = {
			{ key = "power", title = "ENERGÍA",
				A = { name = "Paneles solares gigantes", cost = 45, mass = 1030, note = "≈ 515 m² para tener 180 W en Plutón" },
				B = { name = "Generador RTG ★", cost = 35, mass = 57, note = "240 W al despegar · 200 W en Plutón" } },
			{ key = "propulsion", title = "PROPULSIÓN",
				A = { name = "Hidracina · 16 propulsores ★", cost = 15, mass = 25, note = "77 kg · 4 × 4,4 N + 12 × 0,8 N" },
				B = { name = "Motor bipropelente", cost = 25, mass = 45, note = "Isp ≈ 310 s, más pesado" } },
			{ key = "comms", title = "COMUNICACIONES",
				A = { name = "Antena media de 0,3 m", cost = 8, mass = 3, note = "≈ 0,02 kbps desde Plutón" },
				B = { name = "Antena grande de 2,1 m ★", cost = 20, mass = 15, note = "≈ 1 kbps desde Plutón" } },
			{ key = "science", title = "INSTRUMENTOS CIENTÍFICOS",
				A = { name = "Solo la cámara LORRI", cost = 12, mass = 9, note = "+30 MB por sector" },
				B = { name = "Los 7 instrumentos ★", cost = 30, mass = 30, note = "< 30 kg y < 30 W · +75 MB" } },
		},
	},
	rover = {
		-- Perseverance: 1.025 kg. Costo real de la misión: unos US$ 2.700 M (JPL); el rover es más caro que la sonda.
		name = "PERSEVERANCE · ROVER DE MARTE", short = "PERSEVERANCE", budget = 150, massMax = 1025, delay = "11 MIN 22 SEG", goalMB = 45,
		brief = "aterrizar en el cráter Jezero, explorarlo y enviar al orbitador de relevo al menos 45 MB de datos.",
		meta = "Aterrizar en el cráter Jezero y mandar 45 MB a la Tierra",
		massNote = "masa real de Perseverance",
		subsystems = {
			{ key = "mobility", title = "RUEDAS Y SUSPENSIÓN",
				A = { name = "Rocker-bogie de 6 ruedas ★", cost = 40, mass = 150, note = "Aguanta 45° · máx. 152 m/h" },
				B = { name = "Ruedas de malla metálica", cost = 25, mass = 80, note = "Livianas pero frágiles" } },
			{ key = "power", title = "ENERGÍA Y BATERÍAS",
				A = { name = "Paneles solares", cost = 35, mass = 52, note = "No andan de noche ni con polvo" },
				B = { name = "MMRTG + 2 baterías ★", cost = 75, mass = 72, note = "110 W día y noche · 2 × 43 Ah" } },
			{ key = "science", title = "INSTRUMENTOS CIENTÍFICOS",
				A = { name = "Mastcam-Z y SuperCam", cost = 20, mass = 15, note = "+30 MB por parada" },
				B = { name = "7 instrumentos y taladro ★", cost = 35, mass = 59, note = "43 tubos de muestras · +75 MB" } },
		},
	},
}

local BLUE = Color3.fromRGB(11, 61, 145)
local BLUE_HI = Color3.fromRGB(59, 123, 240)
local RED = Color3.fromRGB(252, 61, 33)
local WHITE = Color3.fromRGB(245, 247, 250)
local NAVY = Color3.fromRGB(10, 22, 52)
local DARK = Color3.fromRGB(38, 42, 54)
local STEEL = Color3.fromRGB(128, 136, 150)
local GREEN = Color3.fromRGB(61, 255, 122)
local GOLD = Color3.fromRGB(205, 165, 70)
local MARS_RED = Color3.fromRGB(176, 92, 56)
local ATLAS_COPPER = Color3.fromRGB(184, 108, 58)        -- aislante naranja-cobrizo del núcleo del Atlas V
local SCREEN_BG = Color3.fromRGB(4, 12, 32)
local YELLOW = Color3.fromRGB(255, 200, 40)
local ORANGE = Color3.fromRGB(255, 120, 30)
local WOOD = Color3.fromRGB(150, 110, 70)

local METAL = Enum.Material.Metal
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

-- Cada misión tiene su complejo: un hangar de armado y, 90 studs al norte, su sala de decisiones
local ORIGINS = {
	probe = Vector3.new(-100, 200, 0),
	rover = Vector3.new(100, 200, 0),
}
local WINDOW_SIDE = { probe = -1, rover = 1 }      -- pared del ventanal (-1 oeste, 1 este)

-- Las naves se arman a escala reducida para que entren en la cofia del Atlas V (las piezas de las
-- salas se ven en tamaño grande; al instalarlas se achican). v8: el rover quedó un poco más alto
-- que el jugador (~5,5 studs con el mástil), como Perseverance (2,2 m) al lado de una persona.
local VEHICLE_SCALE = { probe = 0.6, rover = 0.68 }
local PAYLOAD_Y = 33.6          -- altura del adaptador de carga sobre la base del Atlas V (a escala 1)
-- El Atlas V del rover está afuera (no tiene techo encima): se arma 1,3 veces más grande para que
-- el rover entre en la cofia. Atlas V 541 (Perseverance): 4 propulsores; 551 (New Horizons): 5.
local ROCKET = {
	probe = { scale = 1, srbs = 5, armL = 11, model = "ATLAS V 551" },      -- + tercera etapa Star 48B (no se dibuja)
	rover = { scale = 1.3, srbs = 4, armL = 18, model = "ATLAS V 541" },
}
local HANGAR_HEIGHT = 60        -- el hangar es alto para que el Atlas V entre de pie
local ROVER_ON_BED = CFrame.new(0, 0, 2) * CFrame.Angles(0, math.rad(90), 0)    -- lugar del rover en la caja del transportador

---------------------------------------------------------------------------
-- 2. UTILIDADES DE CONSTRUCCIÓN
---------------------------------------------------------------------------
local function make(className, props, parent)
	local obj = Instance.new(className)
	for name, value in pairs(props) do
		obj[name] = value
	end
	obj.Parent = parent
	return obj
end

local world = make("Folder", { Name = "ControlDeMision" }, workspace)
local decor = make("Folder", { Name = "Decorado" }, world)
local piecesFolder = make("Folder", { Name = "Piezas" }, world)
local screensFolder = make("Folder", { Name = "Pantallas" }, world)     -- monitores cuyo texto cambia
local graphsFolder = make("Folder", { Name = "Graficos" }, world)       -- pantallas con el gráfico de vuelo
local consolesFolder = make("Folder", { Name = "Consolas" }, world)    -- monitores táctiles y pantallas que dibuja el cliente
local armsFolder = make("Folder", { Name = "Brazos" }, world)          -- brazos robóticos y mesas de transferencia

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))      -- pone de pie un cilindro (su eje es X)
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)      -- acuesta un cilindro a lo largo de Z

local function box(parent, size, cf, color, material)
	return make("Part", {
		Anchored = true, Size = size, CFrame = cf, Color = color, Material = material or PLASTIC,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
	}, parent)
end

local function tube(parent, length, diameter, cf, color, material)      -- cilindro con eje en X
	return make("Part", {
		Anchored = true, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter),
		CFrame = cf, Color = color, Material = material or PLASTIC,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
	}, parent)
end

local function cyl(parent, height, diameter, cf, color, material)       -- cilindro vertical
	return tube(parent, height, diameter, cf * UPRIGHT, color, material)
end

local function ball(parent, diameter, cf, color, material)
	return make("Part", {
		Anchored = true, Shape = Enum.PartType.Ball, Size = Vector3.new(diameter, diameter, diameter),
		CFrame = cf, Color = color, Material = material or PLASTIC,
	}, parent)
end

local function light(position, range, brightness)
	local holder = make("Part", {
		Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(1, 1, 1), Position = position,
	}, decor)
	make("PointLight", { Range = range, Brightness = brightness * Campus.LUZ.focos, Color = WHITE, Shadows = false }, holder)
end

-- Texto pintado sobre una cara: siempre iluminado (LightInfluence 0) para que se lea en cualquier rincón
local function surfaceText(part, face, text, textColor, background, maxSize)
	local gui = make("SurfaceGui", {
		Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0,
	}, part)
	local label = make("TextLabel", {
		Name = "Texto", Size = UDim2.fromScale(1, 1), BackgroundColor3 = background or SCREEN_BG, BorderSizePixel = 0,
		Text = text, TextColor3 = textColor or WHITE, TextScaled = true, TextWrapped = true, Font = Enum.Font.GothamBold,
	}, gui)
	make("UIPadding", {
		PaddingLeft = UDim.new(0.04, 0), PaddingRight = UDim.new(0.04, 0),
		PaddingTop = UDim.new(0.06, 0), PaddingBottom = UDim.new(0.06, 0),
	}, label)
	make("UITextSizeConstraint", { MaxTextSize = maxSize or 100, MinTextSize = 10 }, label)
	return label
end

-- Monitor cuyo texto actualiza el script del jugador (se busca por nombre en la carpeta Pantallas)
local function screen(name, size, cf, face, textColor, maxSize)
	local part = make("Part", {
		Name = name, Anchored = true, Size = size, CFrame = cf, Color = SCREEN_BG, Material = NEON,
	}, screensFolder)
	surfaceText(part, face, "", textColor, SCREEN_BG, maxSize)
	return part
end

local function prompt(part, actionText, objectText, distance)
	return make("ProximityPrompt", {
		ActionText = actionText, ObjectText = objectText,
		HoldDuration = 0.2, MaxActivationDistance = distance or 11, RequiresLineOfSight = false,
	}, part)
end

---------------------------------------------------------------------------
-- 3. UN MODELO DISTINTO PARA CADA PIEZA (v5: con placa de montaje, bulones, cables y rótulo)
--    Cada función arma la pieza sobre "b", el centro de su base. El frente de la pieza es -Z.
---------------------------------------------------------------------------
local BUILDERS = {}
local CABLE = Color3.fromRGB(28, 30, 36)
local COPPER = Color3.fromRGB(190, 110, 60)

local function bolts(m, cf, w, d)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			cyl(m, 0.16, 0.24, cf * CFrame.new(sx * (w / 2 - 0.3), 0.08, sz * (d / 2 - 0.3)), STEEL, METAL)
		end
	end
end

local function mountPlate(m, b, w, d)
	box(m, Vector3.new(w, 0.2, d), b * CFrame.new(0, 0.1, 0), DARK, METAL)
	box(m, Vector3.new(w + 0.1, 0.06, 0.12), b * CFrame.new(0, 0.2, -d / 2), YELLOW)
	bolts(m, b * CFrame.new(0, 0.2, 0), w, d)
end

-- Cable entre dos puntos del mundo
local function cable(m, a, c, color, thick)
	local length = (c - a).Magnitude
	if length < 0.05 then
		return
	end
	local t = thick or 0.12
	return make("Part", {
		Anchored = true, CanCollide = false, Size = Vector3.new(t, t, length),
		CFrame = CFrame.lookAt((a + c) / 2, c), Color = color or CABLE, Material = PLASTIC,
	}, m)
end

-- Rótulo de la pieza (texto en la cara frontal)
local function plate(m, cf, text, color)
	local p = box(m, Vector3.new(1.8, 0.55, 0.05), cf, color or WHITE)
	surfaceText(p, Enum.NormalId.Front, text, NAVY, color or WHITE, 40)
	return p
end

BUILDERS["probe-power-A"] = function(m, b)          -- pack de tres baterías primarias
	mountPlate(m, b, 5.8, 3.4)
	for i = 0, 2 do
		local x = -1.7 + i * 1.7
		box(m, Vector3.new(1.4, 2.4, 2.6), b * CFrame.new(x, 1.4, 0), WHITE)
		box(m, Vector3.new(1.45, 0.3, 2.65), b * CFrame.new(x, 2.0, 0), GREEN, NEON)
		box(m, Vector3.new(1.45, 0.12, 2.65), b * CFrame.new(x, 0.75, 0), STEEL, METAL)
		box(m, Vector3.new(0.45, 0.3, 0.45), b * CFrame.new(x, 2.75, -0.6), RED)
		box(m, Vector3.new(0.45, 0.3, 0.45), b * CFrame.new(x, 2.75, 0.6), DARK, METAL)
		if i < 2 then
			cable(m, (b * CFrame.new(x, 2.95, 0.6)).Position, (b * CFrame.new(x + 1.7, 2.95, -0.6)).Position, COPPER)
		end
	end
	box(m, Vector3.new(0.6, 0.6, 0.8), b * CFrame.new(2.9, 0.6, 1), DARK, METAL)          -- conector de salida
	cable(m, (b * CFrame.new(1.7, 2.95, 0.6)).Position, (b * CFrame.new(2.9, 0.9, 1)).Position, CABLE)
	plate(m, b * CFrame.new(0, 1.2, -1.33), "Li-SOCl₂ · 3,6 kWh")
end

BUILDERS["probe-power-B"] = function(m, b)          -- generador de radioisótopos con aletas
	mountPlate(m, b, 4.2, 4.2)
	cyl(m, 0.4, 1.9, b * CFrame.new(0, 0.4, 0), STEEL, METAL)
	cyl(m, 3.8, 1.6, b * CFrame.new(0, 2.4, 0), DARK, METAL)
	for i = 0, 3 do
		box(m, Vector3.new(0.15, 3.2, 3.6), b * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, math.rad(45 * i), 0), STEEL, METAL)
	end
	for _, y in ipairs({ 1.0, 2.4, 3.8 }) do
		cyl(m, 0.12, 1.75, b * CFrame.new(0, y, 0), GOLD, Enum.Material.Foil)
	end
	cyl(m, 0.3, 1.9, b * CFrame.new(0, 4.45, 0), STEEL, METAL)
	ball(m, 1.0, b * CFrame.new(0, 4.9, 0), RED, NEON)
	local placard = box(m, Vector3.new(1.4, 0.9, 0.05), b * CFrame.new(0, 2.4, -1.82), YELLOW)
	surfaceText(placard, Enum.NormalId.Front, "☢ RTG", DARK, YELLOW, 40)
	cable(m, (b * CFrame.new(0.9, 0.6, 0)).Position, (b * CFrame.new(1.9, 0.3, 1.6)).Position, CABLE, 0.18)
end

BUILDERS["probe-propulsion-A"] = function(m, b)     -- tanque esférico de hidracina
	mountPlate(m, b, 4.2, 4.2)
	for i = 0, 3 do
		local a = math.rad(90 * i + 45)
		cable(m, (b * CFrame.new(math.cos(a) * 1.7, 0.2, math.sin(a) * 1.7)).Position,
			(b * CFrame.new(math.cos(a) * 1.4, 2.6, math.sin(a) * 1.4)).Position, STEEL, 0.2)
	end
	ball(m, 3.4, b * CFrame.new(0, 2.8, 0), WHITE)
	cyl(m, 0.35, 3.5, b * CFrame.new(0, 2.8, 0), RED)
	cyl(m, 0.7, 0.25, b * CFrame.new(0, 4.7, 0), STEEL, METAL)
	box(m, Vector3.new(0.7, 0.5, 0.7), b * CFrame.new(0, 5.2, 0), DARK, METAL)               -- válvula
	box(m, Vector3.new(0.2, 0.2, 0.9), b * CFrame.new(0.5, 5.2, 0), RED)                     -- palanca
	for _, sx in ipairs({ -1, 1 }) do
		tube(m, 0.7, 0.55, b * CFrame.new(sx * 2.0, 1.0, 0), DARK, METAL)                    -- propulsores de control
		tube(m, 0.2, 0.3, b * CFrame.new(sx * 2.4, 1.0, 0), Color3.fromRGB(255, 150, 60), NEON)
	end
	plate(m, b * CFrame.new(0, 0.85, -1.9), "N₂H₄ · Isp 220 s")
end

BUILDERS["probe-propulsion-B"] = function(m, b)     -- motor bipropelente con dos tanques
	mountPlate(m, b, 5.4, 4)
	cyl(m, 1.2, 2.6, b * CFrame.new(0, 0.8, 0), DARK, METAL)                                 -- campana
	cyl(m, 0.12, 2.7, b * CFrame.new(0, 0.3, 0), COPPER, METAL)
	cyl(m, 0.9, 1.3, b * CFrame.new(0, 1.85, 0), STEEL, METAL)                               -- cámara de combustión
	ball(m, 2.3, b * CFrame.new(-1.4, 3.4, 0), BLUE)
	ball(m, 2.3, b * CFrame.new(1.4, 3.4, 0), RED)
	box(m, Vector3.new(1.2, 0.4, 0.6), b * CFrame.new(0, 3.4, 0), STEEL, METAL)
	cable(m, (b * CFrame.new(-1.4, 2.3, 0)).Position, (b * CFrame.new(-0.4, 2.2, 0)).Position, STEEL, 0.2)
	cable(m, (b * CFrame.new(1.4, 2.3, 0)).Position, (b * CFrame.new(0.4, 2.2, 0)).Position, STEEL, 0.2)
	for _, sx in ipairs({ -1, 1 }) do
		cable(m, (b * CFrame.new(sx * 2.4, 0.2, 0)).Position, (b * CFrame.new(sx * 2.0, 2.6, 0)).Position, STEEL, 0.25)
	end
	local tagA = box(m, Vector3.new(0.9, 0.4, 0.05), b * CFrame.new(-1.4, 3.4, -1.18), WHITE)
	surfaceText(tagA, Enum.NormalId.Front, "MMH", BLUE, WHITE, 40)
	local tagB = box(m, Vector3.new(0.9, 0.4, 0.05), b * CFrame.new(1.4, 3.4, -1.18), WHITE)
	surfaceText(tagB, Enum.NormalId.Front, "N₂O₄", RED, WHITE, 40)
	plate(m, b * CFrame.new(0, 0.8, -1.95), "Bipropelente · Isp 320 s")
end

BUILDERS["probe-comms-A"] = function(m, b)          -- antena de ganancia media sobre cardán
	mountPlate(m, b, 2.6, 2.6)
	cyl(m, 2.6, 0.3, b * CFrame.new(0, 1.5, 0), STEEL, METAL)
	box(m, Vector3.new(0.6, 0.6, 0.6), b * CFrame.new(0, 2.9, 0), DARK, METAL)
	local dish = b * CFrame.new(0, 3.2, 0) * CFrame.Angles(math.rad(-30), 0, 0)
	cyl(m, 0.3, 2.4, dish, WHITE)
	cyl(m, 0.12, 2.5, dish * CFrame.new(0, 0.12, 0), BLUE)
	local feed = (dish * CFrame.new(0, 1.0, 0)).Position
	for i = 0, 2 do
		local a = math.rad(120 * i)
		cable(m, (dish * CFrame.new(math.cos(a) * 1.15, 0.15, math.sin(a) * 1.15)).Position, feed, STEEL, 0.08)
	end
	ball(m, 0.45, CFrame.new(feed), RED, NEON)
	cable(m, (b * CFrame.new(0.2, 2.6, 0)).Position, (b * CFrame.new(1.1, 0.25, 0.8)).Position, CABLE)
	plate(m, b * CFrame.new(0, 0.6, -1.33), "Ganancia media · 5 MB/min")
end

BUILDERS["probe-comms-B"] = function(m, b)          -- plato de alta ganancia
	mountPlate(m, b, 3.2, 3.2)
	cyl(m, 2.2, 0.5, b * CFrame.new(0, 1.3, 0), STEEL, METAL)
	box(m, Vector3.new(0.9, 0.9, 0.9), b * CFrame.new(0, 2.6, 0), DARK, METAL)
	local dish = b * CFrame.new(0, 3.4, 0) * CFrame.Angles(math.rad(-40), 0, 0)
	cyl(m, 0.35, 5, dish, WHITE)
	cyl(m, 0.12, 5.2, dish * CFrame.new(0, -0.15, 0), BLUE)
	for i = 0, 5 do                                                                           -- nervaduras
		box(m, Vector3.new(0.08, 0.06, 2.3), dish * CFrame.Angles(0, math.rad(30 * i), 0) * CFrame.new(0, 0.2, 0), STEEL, METAL)
	end
	local feed = (dish * CFrame.new(0, 1.7, 0)).Position
	for i = 0, 2 do
		local a = math.rad(120 * i)
		cable(m, (dish * CFrame.new(math.cos(a) * 2.3, 0.2, math.sin(a) * 2.3)).Position, feed, STEEL, 0.1)
	end
	cyl(m, 0.15, 0.9, CFrame.new(feed) * (dish - dish.Position), WHITE)
	ball(m, 0.5, CFrame.new(feed), RED, NEON)
	plate(m, b * CFrame.new(0, 0.6, -1.63), "Alta ganancia · 15 MB/min")
end

BUILDERS["probe-science-A"] = function(m, b)        -- cámara multiespectral
	mountPlate(m, b, 3, 2.8)
	cyl(m, 1, 0.6, b * CFrame.new(0, 0.7, 0), STEEL, METAL)
	box(m, Vector3.new(2.4, 1.7, 2), b * CFrame.new(0, 2.05, 0), WHITE)
	for _, sx in ipairs({ -1, 1 }) do
		box(m, Vector3.new(0.05, 1.5, 1.8), b * CFrame.new(sx * 1.23, 2.05, 0), GOLD, Enum.Material.Foil)
	end
	for i = 0, 2 do
		box(m, Vector3.new(2.2, 0.08, 1.8), b * CFrame.new(0, 3.0 + i * 0.22, 0), STEEL, METAL)  -- radiador
	end
	tube(m, 1.1, 1.3, b * CFrame.new(0, 2.05, -1.5) * ALONG_Z, DARK, METAL)
	tube(m, 0.15, 1.45, b * CFrame.new(0, 2.05, -1.95) * ALONG_Z, STEEL, METAL)
	tube(m, 0.12, 1.0, b * CFrame.new(0, 2.05, -2.08) * ALONG_Z, BLUE_HI, NEON)
	cable(m, (b * CFrame.new(1.0, 1.3, 1.0)).Position, (b * CFrame.new(1.3, 0.25, 1.2)).Position, CABLE)
	plate(m, (b * CFrame.new(1.26, 1.5, 0)) * CFrame.Angles(0, math.rad(-90), 0), "Multiespectral")
end

BUILDERS["probe-science-B"] = function(m, b)        -- espectrómetro y radar de apertura sintética
	mountPlate(m, b, 4.4, 3)
	box(m, Vector3.new(2.8, 1.6, 2.4), b * CFrame.new(-0.6, 1.0, 0), GOLD, Enum.Material.Foil)
	box(m, Vector3.new(2.9, 0.12, 2.5), b * CFrame.new(-0.6, 1.85, 0), WHITE)
	tube(m, 0.5, 0.75, b * CFrame.new(-0.6, 1.1, -1.4) * ALONG_Z, DARK, METAL)
	tube(m, 0.1, 0.5, b * CFrame.new(-0.6, 1.1, -1.66) * ALONG_Z, GREEN, NEON)
	cyl(m, 1.4, 0.24, b * CFrame.new(0.6, 2.4, 0), STEEL, METAL)
	tube(m, 3.4, 0.22, b * CFrame.new(2.0, 3.0, 0), STEEL, METAL)
	box(m, Vector3.new(0.2, 1.4, 2.0), b * CFrame.new(3.7, 3.0, 0), WHITE)                   -- antena del radar
	for i = -2, 2 do
		box(m, Vector3.new(0.22, 0.06, 1.9), b * CFrame.new(3.7, 3.0 + i * 0.25, 0), DARK)
	end
	ball(m, 0.5, b * CFrame.new(-1.6, 2.1, 0.8), GREEN, NEON)
	cable(m, (b * CFrame.new(0.6, 1.7, 0.3)).Position, (b * CFrame.new(2.0, 2.9, 0.15)).Position, CABLE)
	plate(m, b * CFrame.new(-0.6, 0.55, -1.23), "Espectrómetro · SAR")
end

BUILDERS["rover-mobility-A"] = function(m, b)       -- balancín rocker-bogie con tres ruedas
	mountPlate(m, b, 6.4, 2)
	box(m, Vector3.new(3.4, 0.35, 0.5), b * CFrame.new(-1.2, 2.3, 0) * CFrame.Angles(0, 0, math.rad(-10)), STEEL, METAL)
	box(m, Vector3.new(3.4, 0.35, 0.5), b * CFrame.new(1.2, 2.3, 0) * CFrame.Angles(0, 0, math.rad(10)), STEEL, METAL)
	tube(m, 0.8, 0.6, b * CFrame.new(0, 2.55, 0) * ALONG_Z, DARK, METAL)                     -- pivote
	for _, x in ipairs({ -2.4, 0, 2.4 }) do
		tube(m, 0.9, 1.7, b * CFrame.new(x, 1.05, 0) * ALONG_Z, DARK)
		tube(m, 0.95, 1.2, b * CFrame.new(x, 1.05, 0) * ALONG_Z, STEEL, METAL)
		tube(m, 1.0, 0.55, b * CFrame.new(x, 1.05, 0) * ALONG_Z, RED)
		box(m, Vector3.new(0.3, 1.2, 0.3), b * CFrame.new(x, 1.75, 0), STEEL, METAL)
		for g = 0, 3 do                                                                       -- garras de la rueda
			box(m, Vector3.new(0.12, 1.78, 0.95), b * CFrame.new(x, 1.05, 0) * CFrame.Angles(0, 0, math.rad(45 * g)), Color3.fromRGB(60, 62, 70), METAL)
		end
	end
	plate(m, b * CFrame.new(0, 0.55, -1.03), "Rocker-bogie · 30°")
end

BUILDERS["rover-mobility-B"] = function(m, b)       -- rueda de malla metálica tipo Apolo
	mountPlate(m, b, 4.4, 2.2)
	box(m, Vector3.new(0.5, 1.2, 0.5), b * CFrame.new(0, 0.8, 0.6), STEEL, METAL)
	tube(m, 1.1, 3.8, b * CFrame.new(0, 2.2, 0) * ALONG_Z, STEEL, Enum.Material.DiamondPlate)
	tube(m, 1.25, 1.1, b * CFrame.new(0, 2.2, 0) * ALONG_Z, RED)
	for i = 0, 5 do                                                                           -- chevrones de titanio
		box(m, Vector3.new(0.5, 0.12, 1.15), b * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(60 * i)) * CFrame.new(0, 1.9, 0), GOLD, METAL)
	end
	for i = 0, 2 do
		box(m, Vector3.new(3.4, 0.2, 1.15), b * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(60 * i)), DARK, METAL)
	end
	plate(m, b * CFrame.new(0, 0.55, -1.13), "Malla de alambre · 20°")
end

BUILDERS["rover-power-A"] = function(m, b)          -- paneles solares con baterías
	mountPlate(m, b, 4, 3.4)
	box(m, Vector3.new(3, 1, 2.4), b * CFrame.new(0, 0.7, 0), WHITE)                         -- caja de baterías
	box(m, Vector3.new(0.8, 0.3, 0.8), b * CFrame.new(1, 1.35, 0), GREEN, NEON)
	cyl(m, 1, 0.3, b * CFrame.new(0, 1.7, 0), STEEL, METAL)                                   -- soporte
	for _, sx in ipairs({ -1, 1 }) do                                                       -- dos alas de paneles
		local wing = b * CFrame.new(sx * 1.9, 2.25, 0) * CFrame.Angles(0, 0, math.rad(-sx * 8))
		box(m, Vector3.new(3.6, 0.12, 3.2), wing, Color3.fromRGB(20, 40, 110), Enum.Material.Glass)
		box(m, Vector3.new(3.7, 0.08, 3.3), wing * CFrame.new(0, -0.08, 0), STEEL, METAL)
		for i = -1, 1 do
			box(m, Vector3.new(3.6, 0.13, 0.05), wing * CFrame.new(0, 0.01, i * 0.8), Color3.fromRGB(150, 160, 190), METAL)
		end
	end
	plate(m, b * CFrame.new(0, 0.7, -1.23), "Solar · 120 W")
end

BUILDERS["rover-power-B"] = function(m, b)          -- generador compacto
	mountPlate(m, b, 3.6, 3.6)
	cyl(m, 2.2, 2.4, b * CFrame.new(0, 1.3, 0), DARK, METAL)
	for i = 0, 5 do
		box(m, Vector3.new(0.15, 1.8, 3.6), b * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, math.rad(30 * i), 0), STEEL, METAL)
	end
	cyl(m, 0.12, 2.5, b * CFrame.new(0, 2.0, 0), GOLD, Enum.Material.Foil)
	cyl(m, 0.3, 1.5, b * CFrame.new(0, 2.55, 0), RED, NEON)
	local placard = box(m, Vector3.new(1.2, 0.7, 0.05), b * CFrame.new(0, 1.0, -1.82), YELLOW)
	surfaceText(placard, Enum.NormalId.Front, "☢ RTG", DARK, YELLOW, 40)
	cable(m, (b * CFrame.new(1.1, 0.5, 0.4)).Position, (b * CFrame.new(1.6, 0.25, 1.4)).Position, CABLE, 0.16)
end

BUILDERS["rover-science-A"] = function(m, b)        -- mástil con cámaras y espectrómetro
	mountPlate(m, b, 2.6, 2.6)
	cyl(m, 3.2, 0.35, b * CFrame.new(0, 1.8, 0), STEEL, METAL)
	box(m, Vector3.new(0.6, 0.5, 0.6), b * CFrame.new(0, 3.5, 0), DARK, METAL)
	box(m, Vector3.new(2, 1, 1), b * CFrame.new(0, 4.0, 0), WHITE)
	for _, sx in ipairs({ -0.55, 0.55 }) do
		tube(m, 0.3, 0.6, b * CFrame.new(sx, 4.0, -0.6) * ALONG_Z, DARK, METAL)
		tube(m, 0.12, 0.45, b * CFrame.new(sx, 4.0, -0.78) * ALONG_Z, BLUE_HI, NEON)
	end
	box(m, Vector3.new(0.5, 0.4, 0.3), b * CFrame.new(0, 4.6, 0), GOLD, Enum.Material.Foil)  -- espectrómetro
	local target = box(m, Vector3.new(0.8, 0.05, 0.8), b * CFrame.new(0.8, 0.25, -0.8), WHITE)
	for i = 0, 3 do                                                                           -- blanco de calibración
		box(m, Vector3.new(0.18, 0.06, 0.18), target.CFrame * CFrame.new(-0.2 + (i % 2) * 0.4, 0.02, -0.2 + math.floor(i / 2) * 0.4),
			({ RED, GREEN, BLUE_HI, YELLOW })[i + 1])
	end
	cable(m, (b * CFrame.new(0.2, 3.4, 0)).Position, (b * CFrame.new(0.9, 0.25, 0.9)).Position, CABLE)
end

BUILDERS["rover-science-B"] = function(m, b)        -- taladro de núcleo con laboratorio
	mountPlate(m, b, 3.2, 3.2)
	box(m, Vector3.new(2.2, 1.1, 2.2), b * CFrame.new(0, 4.0, 0), WHITE)
	box(m, Vector3.new(0.8, 0.6, 0.8), b * CFrame.new(0, 4.85, 0), DARK, METAL)              -- motor
	cyl(m, 3.2, 0.4, b * CFrame.new(0, 1.9, 0), STEEL, METAL)
	for i = 0, 7 do                                                                           -- hélice de la broca
		box(m, Vector3.new(0.55, 0.08, 0.12), b * CFrame.new(0, 0.6 + i * 0.38, 0) * CFrame.Angles(0, math.rad(45 * i), 0), DARK, METAL)
	end
	cyl(m, 0.6, 0.6, b * CFrame.new(0, 0.5, 0), RED, NEON)
	box(m, Vector3.new(0.25, 3.6, 0.25), b * CFrame.new(-1.3, 1.9, 0) * CFrame.Angles(0, 0, math.rad(-14)), DARK, METAL)
	box(m, Vector3.new(0.25, 3.6, 0.25), b * CFrame.new(1.3, 1.9, 0) * CFrame.Angles(0, 0, math.rad(14)), DARK, METAL)
	cyl(m, 0.5, 1.6, b * CFrame.new(-1.0, 4.85, 0.4), BLUE, METAL)                          -- carrusel de muestras
	plate(m, b * CFrame.new(0, 4.0, -1.13), "Taladro de núcleo")
end

local PIECES = {}        -- plantillas: "probe-power-A" → Model en exhibición

---------------------------------------------------------------------------
-- 4. ESTADO POR JUGADOR
---------------------------------------------------------------------------
local states = {}
local COMPLEX = {}       -- datos de cada complejo: apariciones, plataforma, brazos, sala de control...

local function newState(mission)
	return {
		phase = mission and "hangar" or "menu",      -- "menu", "hangar", "transport" (rover), "launching" o "flight"
		mission = mission,
		mods = {},                                   -- piezas ya colocadas: mods.power = "A"
		carry = nil,                                 -- pieza en las manos: { index = 1, code = "A" }
		carried = nil, folder = nil, vehicle = nil,
		power = 100, integrity = 100, thermal = 100, fuel = 0,
		data = 0, sent = 0, event = 1, busy = false,
		labDone = {},                                -- pruebas del laboratorio hechas sobre ESTE diseño
		log = {},                                    -- revisión de cada decisión (informe final)
		history = {},                                -- historial de eventos de la sala de control
		anim = "normal",                             -- animación del brazo: "normal", "rapida" u "omitir"
		flightStart = 0, labCooldown = 0,
	}
end

local function placedCount(state)
	local count = 0
	for _, sub in ipairs(MISSIONS[state.mission].subsystems) do
		if state.mods[sub.key] then
			count += 1
		else
			break
		end
	end
	return count
end

-- Costo de las piezas y masa de la nave (plataforma + piezas)
local function totals(state)
	local cost, mass = 0, Componentes.masaBase(state.mission)
	for _, sub in ipairs(MISSIONS[state.mission].subsystems) do
		local code = state.mods[sub.key]
		if code then
			cost += sub[code].cost
			mass += sub[code].mass
		end
	end
	return cost, mass
end

-- Propelente que carga la sonda: los 77 kg de hidracina reales de New Horizons (el tanque es fijo)
local function fuelFor(_mass)
	return Educativo.REAL.newHorizons.hidracina
end

local function labCount(state)
	local n = 0
	for _ in pairs(state.labDone) do
		n += 1
	end
	return n
end

-- Resumen de ingeniería del diseño: energía, propulsión (Tsiolkovsky) y enlace.
-- En vuelo usa el propelente que queda; en el hangar, el que cargaría al lanzar.
local function designSummary(state)
	local _, mass = totals(state)
	local fuel = 0
	if state.mission == "probe" then
		fuel = state.phase == "flight" and state.fuel or fuelFor(mass)
	end
	return Componentes.resumen(state.mission, state.mods, mass, fuel, Educativo), mass, fuel
end

local function deltaV(state)
	local r = designSummary(state)
	return r.propulsion and r.propulsion.dv or 0
end

local function say(player, text)
	remote:FireClient(player, "say", text)
end

local function setScreen(player, name, text)
	remote:FireClient(player, "screen", name, text)
end

local function setPhase(player, key, title, subtitle)
	remote:FireClient(player, "phase", key, title, subtitle)
end

local function sendConsole(player, data)
	remote:FireClient(player, "console", data)
end

local function stamp(state)
	local t = state.flightStart > 0 and math.floor(os.clock() - state.flightStart) or 0
	return string.format("T+%02d:%02d", math.floor(t / 60), t % 60)
end

local function logEvent(player, text)
	local state = states[player]
	if not state then
		return
	end
	table.insert(state.history, stamp(state) .. "  " .. text)
	while #state.history > 9 do
		table.remove(state.history, 1)
	end
end

local function hoursText(h)
	if h == math.huge then
		return "sin límite (el generador cubre el consumo)"
	end
	return string.format("%.1f h", h)
end

-- Pantalla de especificaciones técnicas del hangar
local function specText(state)
	local mission = MISSIONS[state.mission]
	local r, mass = designSummary(state)
	local lines = { "ESPECIFICACIONES · " .. mission.short, "" }
	table.insert(lines, string.format("ENERGÍA  producción %d W · consumo %d W · %d Wh", r.produccionW, r.consumoW, r.almacenamientoWh))
	table.insert(lines, "AUTONOMÍA  " .. hoursText(r.autonomiaH))
	if state.mission == "probe" then
		local p = r.propulsion
		local NH = Educativo.REAL.newHorizons
		if p then
			table.insert(lines, string.format("MASA SECA %d kg + HIDRACINA %.0f kg = %.0f kg al lanzar (límite %d · real %d)", p.seca, p.propelente, p.m0, NH.limiteMasa, NH.masaLanzamiento))
			table.insert(lines, string.format("Isp %d s · Δv IDEAL %d m/s (la NASA informa ~%d m/s útiles)", p.isp, math.floor(p.dv + 0.5), NH.dvNasa))
			table.insert(lines, string.format("Δv PLANIFICADO  %d m/s (TCM-1 real: 5 + 13,3 m/s)", Educativo.MANIOBRA.requerido))
			table.insert(lines, string.format("SALIDA DE LA TIERRA %s km/s: la da el ATLAS V, no la sonda", Componentes.num(NH.velocidadSalida)))
		else
			table.insert(lines, string.format("MASA SECA %d kg · falta la propulsión", mass))
		end
	else
		local P = Educativo.REAL.perseverance
		table.insert(lines, string.format("MASA %d kg (real %d) · gravedad de Marte %.2f m/s²", mass, P.masaRover, Educativo.GRAVEDAD_MARTE))
		table.insert(lines, string.format("PESO EN MARTE %d N · en la Tierra %d N", math.floor(mass * Educativo.GRAVEDAD_MARTE + 0.5), math.floor(mass * Educativo.G0 + 0.5)))
		local mob = state.mods.mobility and Componentes.ficha("rover", "mobility", state.mods.mobility)
		table.insert(lines, mob and string.format("PENDIENTE MÁX. %d° · VUELCO %d° · máx. 4,2 cm/s", mob.pendienteMax, mob.vuelco) or "Falta la locomoción")
	end
	table.insert(lines, string.format("ENLACE  %s MB/min · %s MB por ventana (escala del juego)%s", Componentes.num(r.tasaMBmin or 0), Componentes.num(r.maxMB or 0),
		(r.kbps and r.kbps > 0) and string.format(" · real ≈ %s kbps", Componentes.num(r.kbps)) or ""))
	if r.mbPorUnidad > 0 then
		table.insert(lines, string.format("CIENCIA  +%d MB por %s", r.mbPorUnidad, state.mission == "probe" and "sector" or "parada"))
	end
	table.insert(lines, "")
	table.insert(lines, string.format("PRUEBAS DE LABORATORIO  %d de 3%s", labCount(state), labCount(state) >= 3 and "  ★" or ""))
	return table.concat(lines, "\n")
end

-- Alertas de la sala de control: dependen del estado real de la nave
local function alertsFor(state)
	local list = {}
	if state.power <= 25 then
		table.insert(list, "⚠ ENERGÍA BAJA")
	end
	if state.integrity <= 30 then
		table.insert(list, "⚠ INTEGRIDAD CRÍTICA")
	end
	if state.mission == "probe" and state.fuel < 15 then
		table.insert(list, "⚠ PROPELENTE BAJO")
	end
	if state.mission == "rover" and state.thermal <= 40 then
		table.insert(list, "⚠ MARGEN TÉRMICO BAJO")
	end
	local r = designSummary(state)
	if state.data - state.sent > (r.maxMB or 0) then
		table.insert(list, "⚠ DATOS A BORDO SUPERAN LA VENTANA DE ENLACE")
	end
	return list, r
end

-- Los datos se muestran en monitores del mundo
local function refreshScreens(player)
	local state = states[player]
	if not state or state.phase == "menu" then
		return
	end
	local mission = MISSIONS[state.mission]
	local m = state.mission

	if state.phase == "hangar" then
		local cost, mass = totals(state)
		local count = placedCount(state)
		local total = #mission.subsystems
		-- Tablero corto: ✓ hecho, ▶ la que sigue, ○ pendiente
		local board = { mission.short, "🎯 " .. mission.meta, "" }
		for index, sub in ipairs(mission.subsystems) do
			local code = state.mods[sub.key]
			if code then
				table.insert(board, string.format("✓ %d · %s", index, sub[code].name))
			elseif index == count + 1 then
				table.insert(board, string.format("▶ %d · %s", index, sub.title))
			else
				table.insert(board, string.format("○ %d · %s", index, sub.title))
			end
		end
		table.insert(board, "")
		table.insert(board, string.format("💰 $%d / $%d M    ⚖️ %d / %d kg", cost, mission.budget, mass, mission.massMax))
		if state.carry then
			table.insert(board, "✋ Llevá la pieza al brazo robótico (E)")
		elseif cost > mission.budget or mass > mission.massMax then
			table.insert(board, "✗ Te pasaste: cambiá una pieza")
		elseif count == total then
			table.insert(board, labCount(state) >= 3 and "🚀 ¡LISTA PARA LANZAR! ★" or "🚀 ¡LISTA! Probala en el laboratorio 🔬")
		end
		setScreen(player, m .. "-hall", table.concat(board, "\n"))
		setScreen(player, m .. "-spec", specText(state))
		for index, sub in ipairs(mission.subsystems) do
			setScreen(player, m .. "-cmp-" .. index,
				Componentes.comparar(m, sub, cost, mass, mission.budget, mission.massMax, state.mods[sub.key]))
		end
	elseif state.phase == "flight" then
		-- Monitores del escritorio: los mismos datos reales, con íconos y sin frases largas
		local alerts, r = alertsFor(state)
		local third = m == "probe"
			and string.format("⛽ %.1f kg\n🚀 Δv %d m/s", state.fuel, math.floor(deltaV(state) + 0.5)):gsub("%.", ",", 1)
			or string.format("🌡️ %d %%", state.thermal)
		setScreen(player, m .. "-stats", string.format("⚡ %d %%\n🛡️ %d %%\n%s\n💾 %d MB\n%s",
			state.power, state.integrity, third, state.data, #alerts > 0 and table.concat(alerts, "\n") or "✓ Sin alertas"))
		local pending = math.max(0, state.data - state.sent)
		local recent = {}
		for i = math.max(1, #state.history - 3), #state.history do
			table.insert(recent, state.history[i])
		end
		setScreen(player, m .. "-log", string.format("📡 %s · ⏱ %s\n📦 %d / %d MB por ventana\n\n%s",
			state.busy and "TRANSMITIENDO" or "ENLACE OK", mission.delay:lower(), pending, r.maxMB or 0, table.concat(recent, "\n")))
		remote:FireClient(player, "alert", #alerts > 0)
	end
end

-- Masa y presupuesto mínimos que todavía hacen falta para completar las salas siguientes
local function minRemaining(missionKey, fromIndex)
	local cost, mass = 0, 0
	local subs = MISSIONS[missionKey].subsystems
	for index = fromIndex, #subs do
		cost += math.min(subs[index].A.cost, subs[index].B.cost)
		mass += math.min(subs[index].A.mass, subs[index].B.mass)
	end
	return cost, mass
end

-- Datos reales para el panel de recursos del jugador (hangar o vuelo)
local function sendResources(player)
	local state = states[player]
	if not state or (state.phase ~= "hangar" and state.phase ~= "flight") then
		remote:FireClient(player, "resources", { visible = false })
		return
	end
	local mission = MISSIONS[state.mission]
	local r = designSummary(state)

	if state.phase == "flight" then
		local _, alertsR = alertsFor(state)
		remote:FireClient(player, "resources", {
			visible = true, mode = "flight", mission = state.mission, missionName = mission.short,
			power = state.power, integrity = state.integrity, thermal = state.thermal,
			fuel = state.fuel, maxFuel = state.maxFuel or state.fuel, dv = deltaV(state), dvReq = Educativo.MANIOBRA.requerido,
			pending = math.max(0, state.data - state.sent), capacity = alertsR.maxMB or 0, sent = state.sent, goal = mission.goalMB,
		})
		return
	end

	local cost, mass = totals(state)
	local count = placedCount(state)
	local data = {
		visible = true, mode = "hangar", mission = state.mission, missionName = mission.short,
		budget = mission.budget, massMax = mission.massMax, cost = cost, mass = mass, items = {},
		energia = {
			prod = r.produccionW, cons = r.consumoW, wh = r.almacenamientoWh,
			autonomia = r.autonomiaH == math.huge and -1 or r.autonomiaH,
		},
		enlace = { tasa = r.tasaMBmin or 0, max = r.maxMB or 0, generado = (r.mbPorUnidad or 0) * 3 },
		lab = labCount(state), anim = state.anim,
	}
	if state.mission == "probe" then
		local p = r.propulsion
		data.propulsion = {
			prop = p and p.propelente or 0, dv = p and p.dv or 0, isp = p and p.isp or 0,
			seca = mass, m0 = p and p.m0 or mass, req = Educativo.MANIOBRA.requerido,
		}
	end
	for index, sub in ipairs(mission.subsystems) do
		local code = state.mods[sub.key]
		local item = { title = sub.title, status = code and "done" or (index == count + 1 and "next" or "pending") }
		if code then
			item.name, item.cost, item.mass = sub[code].name, sub[code].cost, sub[code].mass
		end
		data.items[index] = item
	end
	if state.carry then
		local sub = mission.subsystems[state.carry.index]
		local option = sub[state.carry.code]
		local oldCode = state.mods[sub.key]
		local old = oldCode and sub[oldCode] or nil
		data.carry = { name = option.name, cost = option.cost, mass = option.mass }
		data.projCost = cost - (old and old.cost or 0) + option.cost
		data.projMass = mass - (old and old.mass or 0) + option.mass
	end
	if count < #mission.subsystems then
		local index = count + 1
		local sub = mission.subsystems[index]
		local restCost, restMass = minRemaining(state.mission, index + 1)
		local options = { index = index, title = sub.title }
		for _, code in ipairs({ "A", "B" }) do
			local option = sub[code]
			local newCost, newMass = cost + option.cost, mass + option.mass
			options[code] = {
				name = option.name, cost = option.cost, mass = option.mass, note = option.note,
				fits = newCost <= mission.budget and newMass <= mission.massMax,
				finishable = newCost + restCost <= mission.budget and newMass + restMass <= mission.massMax,
			}
		end
		data.options = options
	end
	remote:FireClient(player, "resources", data)
end

local function refresh(player)
	refreshScreens(player)
	sendResources(player)
end

-- Tablero de misiones del atrio
local function refreshAtrium(player)
	local state = states[player]
	local stats = player:FindFirstChild("leaderstats")
	local lines = { "MISIONES", "" }
	for index, key in ipairs({ "probe", "rover" }) do
		local mission = MISSIONS[key]
		local current = state and state.mission == key
		table.insert(lines, string.format("%s %d · %s", current and "▶" or "○", index, mission.short))
		table.insert(lines, "🎯 " .. mission.meta)
	end
	if stats then
		table.insert(lines, "")
		table.insert(lines, string.format("🏆 %d puntos · rango %s", stats.Puntaje.Value, stats.Rango.Value))
	end
	setScreen(player, "atrio-misiones", table.concat(lines, "\n"))
end

---------------------------------------------------------------------------
-- 5. PERSONAJE: movimiento y traslados
---------------------------------------------------------------------------
local function setFrozen(player, frozen)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.UseJumpPower = false
		humanoid.WalkSpeed = frozen and 0 or 16
		humanoid.JumpHeight = frozen and 0 or 7.2
	end
end

local function teleport(player, cf)
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position)     -- carga la zona antes de llegar
	end)
	local character = player.Character
	if character then
		character:PivotTo(cf)
	end
end

-- Sienta al jugador en el puesto de la sala de control de su misión
local function sitAtDesk(player)
	local state = states[player]
	local complex = state and state.mission and COMPLEX[state.mission]
	local seat = complex and complex.seat
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if seat and humanoid and humanoid.Health > 0 and (not seat.Occupant or seat.Occupant == humanoid) then
		seat:Sit(humanoid)
	end
end

-- Devuelve el transportador del rover a su lugar, cierra el portón y baja al que esté manejando
local function resetTransport(missionKey)
	local complex = COMPLEX[missionKey]
	if not complex or not complex.truck then
		return
	end
	complex.truckSeat.Disabled = true                 -- deshabilitar el asiento también baja al ocupante
	complex.truck:PivotTo(complex.truckHome)
	complex.truckSpeed = 0
	if complex.door and complex.doorHome then
		complex.door:PivotTo(complex.doorHome)
	end
end

---------------------------------------------------------------------------
-- 6. LA NAVE: estructura, piezas en las manos y piezas colocadas
---------------------------------------------------------------------------
local function slotCF(missionKey, index)
	local stand = COMPLEX[missionKey].standCF
	if missionKey == "probe" then
		-- Cuatro lugares alrededor del núcleo de la sonda, sobre la cubierta inferior, mirando hacia afuera
		return stand * CFrame.Angles(0, math.rad(90 * (index - 1)), 0) * CFrame.new(0, 1.2, -4.4)
	end
	if index == 1 then
		return stand * CFrame.new(0, 2.7, 0)                                -- las ruedas van debajo del chasis
	end
	return stand * CFrame.new(index == 2 and -4.5 or 4.5, 2.7, 0)       -- sobre el chasis
end

local function named(part, name)
	part.Name = name
	return part
end

-- La nave vacía, en tamaño grande (después se achica con VEHICLE_SCALE):
--   SONDA: bus con cubierta inferior y superior, núcleo dorado y anillo adaptador abajo.
--          Se arma AFUERA del cohete, sobre el banco de integración.
--   ROVER: chasis sobre soportes.
local function buildVehicle(missionKey, parent)
	local stand = COMPLEX[missionKey].standCF
	local model = make("Model", { Name = "Nave" }, parent)
	if missionKey == "probe" then
		cyl(model, 0.8, 6, stand * CFrame.new(0, 0.4, 0), DARK, METAL)                         -- anillo adaptador
		cyl(model, 0.4, 12.4, stand * CFrame.new(0, 1.0, 0), STEEL, METAL)                     -- cubierta inferior
		cyl(model, 7, 3, stand * CFrame.new(0, 4.7, 0), DARK, METAL)                           -- núcleo (tanques)
		cyl(model, 7, 3.1, stand * CFrame.new(0, 4.7, 0) * CFrame.Angles(0, math.rad(45), 0), GOLD, Enum.Material.Foil).Transparency = 0.3
		for i = 0, 3 do                                                                         -- montantes entre lugares
			box(model, Vector3.new(0.35, 7, 0.35), stand * CFrame.Angles(0, math.rad(90 * i + 45), 0) * CFrame.new(0, 4.7, -6.1), STEEL, METAL)
		end
		cyl(model, 0.4, 12.4, stand * CFrame.new(0, 8.4, 0), WHITE, METAL)                     -- cubierta superior
		cyl(model, 1.4, 0.3, stand * CFrame.new(0, 9.3, 0), STEEL, METAL)                      -- mástil
		ball(model, 0.6, stand * CFrame.new(0, 10.1, 0), RED, NEON)
		local nameplate = box(model, Vector3.new(3.4, 1.0, 0.1), stand * CFrame.Angles(0, math.rad(45), 0) * CFrame.new(0, 8.4, -6.25), WHITE)
		surfaceText(nameplate, Enum.NormalId.Front, "NEW HORIZONS", NAVY, WHITE, 60)
	else
		box(model, Vector3.new(18, 0.6, 8), stand * CFrame.new(0, 2.4, 0), WHITE, METAL)
		box(model, Vector3.new(18.05, 0.3, 1), stand * CFrame.new(0, 2.4, 0), RED)
		box(model, Vector3.new(18.05, 0.15, 8.05), stand * CFrame.new(0, 2.05, 0), DARK, METAL)
		box(model, Vector3.new(2, 1.4, 6), stand * CFrame.new(8, 3.4, 0), BLUE, METAL)                  -- frente
		for _, z in ipairs({ -2, 2 }) do                                                                 -- faros y cámaras de navegación
			box(model, Vector3.new(0.1, 0.5, 0.8), stand * CFrame.new(9.05, 3.5, z), Color3.fromRGB(255, 240, 200), NEON)
		end
		box(model, Vector3.new(1.4, 1.2, 6.5), stand * CFrame.new(-8.2, 3.3, 0), STEEL, METAL)          -- radiador trasero
		for i = -2, 2 do
			box(model, Vector3.new(1.45, 0.1, 6.4), stand * CFrame.new(-8.2, 3.3 + i * 0.2, 0), DARK, METAL)
		end
		cyl(model, 4, 0.25, stand * CFrame.new(-6.5, 4.7, 3), STEEL, METAL)                             -- antena UHF
		ball(model, 0.4, stand * CFrame.new(-6.5, 6.8, 3), RED, NEON)
		local side = box(model, Vector3.new(7, 1, 0.08), stand * CFrame.new(0, 3.3, -4.05), WHITE)
		surfaceText(side, Enum.NormalId.Front, "PERSEVERANCE", NAVY, WHITE, 60)
		for _, x in ipairs({ -7, 7 }) do
			for _, z in ipairs({ -3, 3 }) do
				local jack = cyl(model, 2.1, 0.7, stand * CFrame.new(x, 1.05, z), STEEL, METAL)
				jack.Name = "Soporte"
			end
		end
	end
	model.WorldPivot = stand
	return model
end

-- Ruedas del vehículo según la pieza de locomoción elegida (code = nil las quita y repone los soportes)
local function setWheels(model, missionKey, code)
	local stand = COMPLEX[missionKey].standCF
	for _, child in ipairs(model:GetChildren()) do
		if child.Name == "Soporte" or child.Name == "Rueda" then
			child:Destroy()
		end
	end
	if not code then
		for _, x in ipairs({ -7, 7 }) do
			for _, z in ipairs({ -3, 3 }) do
				named(cyl(model, 2.1, 0.7, stand * CFrame.new(x, 1.05, z), STEEL, METAL), "Soporte")
			end
		end
		return
	end
	for _, z in ipairs({ -4.7, 4.7 }) do
		if code == "A" then                                                   -- vigas del balancín a cada lado
			named(box(model, Vector3.new(7, 0.4, 0.4), stand * CFrame.new(-3.2, 2.0, z * 0.82) * CFrame.Angles(0, 0, math.rad(8)), STEEL, METAL), "Rueda")
			named(box(model, Vector3.new(7, 0.4, 0.4), stand * CFrame.new(3.2, 2.0, z * 0.82) * CFrame.Angles(0, 0, math.rad(-8)), STEEL, METAL), "Rueda")
		end
		for _, x in ipairs({ -6.5, 0, 6.5 }) do
			if code == "B" then
				named(tube(model, 1.1, 3.2, stand * CFrame.new(x, 1.6, z) * ALONG_Z, STEEL, Enum.Material.DiamondPlate), "Rueda")
				named(tube(model, 1.2, 1, stand * CFrame.new(x, 1.6, z) * ALONG_Z, RED), "Rueda")
				for i = 0, 2 do
					named(box(model, Vector3.new(0.45, 0.1, 1.15), stand * CFrame.new(x, 1.6, z) * CFrame.Angles(0, 0, math.rad(120 * i)) * CFrame.new(0, 1.6, 0), GOLD, METAL), "Rueda")
				end
			else
				named(tube(model, 1, 2.6, stand * CFrame.new(x, 1.3, z) * ALONG_Z, DARK), "Rueda")
				named(tube(model, 1.05, 1.8, stand * CFrame.new(x, 1.3, z) * ALONG_Z, STEEL, METAL), "Rueda")
				named(tube(model, 1.1, 0.9, stand * CFrame.new(x, 1.3, z) * ALONG_Z, RED), "Rueda")
			end
		end
	end
end

local function dropCarried(state)
	if state.carried then
		state.carried:Destroy()
		state.carried = nil
	end
	state.carry = nil
end

-- Copia de la pieza soldada al personaje, delante del pecho
local function carryPiece(player, state, index, code)
	dropCarried(state)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local sub = MISSIONS[state.mission].subsystems[index]
	local copy = PIECES[state.mission .. "-" .. sub.key .. "-" .. code]:Clone()
	copy.Name = "PiezaEnMano"
	copy:PivotTo(root.CFrame * CFrame.new(0, -1.5, -4.5))
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			make("WeldConstraint", { Part0 = root, Part1 = part }, part)
			part.Anchored = false
		end
	end
	copy.Parent = state.folder
	state.carried = copy
	state.carry = { index = index, code = code }
	return true
end

-- La nave se edita siempre en tamaño grande y en el banco: se agranda, se cambia y se vuelve a achicar.
-- (Model:ScaleTo escala alrededor del pivote, que es el centro del banco.)
local function editVehicle(state, change)
	local model = state.vehicle
	model:PivotTo(COMPLEX[state.mission].standCF)
	model:ScaleTo(1)
	change(model)
	model:ScaleTo(VEHICLE_SCALE[state.mission])
end

-- Lugar real de una pieza en la nave achicada (para la animación del brazo)
local function scaledSlot(missionKey, index)
	local stand = COMPLEX[missionKey].standCF
	local slot = slotCF(missionKey, index)
	local localSlot = stand:ToObjectSpace(slot)
	return stand * (CFrame.new(localSlot.Position * VEHICLE_SCALE[missionKey]) * localSlot.Rotation)
end

local function placePiece(state, index, code)
	local missionKey = state.mission
	local sub = MISSIONS[missionKey].subsystems[index]
	state.mods[sub.key] = code
	state.labDone = {}                     -- un diseño nuevo hay que volver a ensayarlo

	editVehicle(state, function(vehicle)
		local old = vehicle:FindFirstChild("Pieza" .. index)
		if old then
			old:Destroy()
		end
		if missionKey == "rover" and index == 1 then
			setWheels(vehicle, missionKey, code)
		else
			local copy = PIECES[missionKey .. "-" .. sub.key .. "-" .. code]:Clone()
			copy.Name = "Pieza" .. index
			copy:PivotTo(slotCF(missionKey, index))
			copy.Parent = vehicle
		end
	end)
end

local function unplacePiece(state, index)
	local missionKey = state.mission
	local sub = MISSIONS[missionKey].subsystems[index]
	state.mods[sub.key] = nil
	state.labDone = {}
	editVehicle(state, function(vehicle)
		if missionKey == "rover" and index == 1 then
			setWheels(vehicle, missionKey, nil)
		else
			local old = vehicle:FindFirstChild("Pieza" .. index)
			if old then
				old:Destroy()
			end
		end
	end)
end

local function cleanup(player)
	local state = states[player]
	if state and state.folder then
		state.folder:Destroy()
	end
end

local function parkCharacter(player)
	teleport(player, COMPLEX.probe.parkCF)
	setFrozen(player, true)
end

local function goToMenu(player, showTitle)
	cleanup(player)
	states[player] = newState(nil)
	resetTransport("rover")
	parkCharacter(player)
	remote:FireClient(player, "showMenu", COMPLEX.probe.menuCamera, showTitle == true)
	refreshAtrium(player)
end

local function goToHangar(player, missionKey, previousMods, previousAnim)
	cleanup(player)
	local state = newState(missionKey)
	states[player] = state
	state.anim = previousAnim or "normal"
	state.folder = make("Folder", { Name = "Jugador_" .. player.UserId }, world)
	state.vehicle = buildVehicle(missionKey, state.folder)
	state.vehicle:ScaleTo(VEHICLE_SCALE[missionKey])
	resetTransport(missionKey)
	if previousMods then                              -- al reintentar, la nave vuelve armada como estaba
		for index, sub in ipairs(MISSIONS[missionKey].subsystems) do
			if previousMods[sub.key] then
				placePiece(state, index, previousMods[sub.key])
			end
		end
	end
	teleport(player, COMPLEX[missionKey].spawnCF)
	setFrozen(player, false)
	remote:FireClient(player, "enterGame", missionKey)
	setPhase(player, "BC", "FASE B/C · HANGAR DE ARMADO", MISSIONS[missionKey].name)
	for _, name in ipairs({ "-main", "-stats", "-log" }) do
		setScreen(player, missionKey .. name, "")
	end
	setScreen(player, "lab-report", "🔬 LABORATORIO\n\nElegí una prueba en la consola")
	sendConsole(player, { mission = missionKey, mode = "idle", text = "EN ESPERA\nSe activa cuando la nave despegue" })
	remote:FireClient(player, "track", missionKey, 0)
	refresh(player)
	refreshAtrium(player)
end

---------------------------------------------------------------------------
-- 7. EVENTOS DE VUELO: situación, dos opciones y resultado
---------------------------------------------------------------------------
local function scienceGain(state)
	return state.mods.science == "B" and 75 or 30
end

local EVENTS = {
	probe = {
		{
			-- (el evento 1 real se juega con la consola: maniobra TCM parametrizada)
			title = "EVENTO 1 · CORRECCIÓN TCM-1",
			brief = function()
				return "Día 9 después del lanzamiento: hay que corregir el rumbo hacia Júpiter (la NASA corrigió 18 m/s).",
					"CORREGIR\nGasta hidracina\nApunta bien a Júpiter",
					"NO CORREGIR\nAhorra hidracina\nSe desvía"
			end,
			resolve = function(state, choice)
				local gain = scienceGain(state)
				state.data += gain
				if choice == 1 then
					local burn = Educativo.propelenteParaDv(220, 478, Educativo.MANIOBRA.requerido)
					state.fuel = math.max(0, state.fuel - burn)
					return string.format("Corrección hecha (−%.1f kg).\n+%d MB de datos.", burn, gain)
				end
				state.integrity -= 30
				return "Sin corregir, el desvío crece día a día.\n-30% · +" .. gain .. " MB."
			end,
		},
		{
			-- Real: 28/2/2007, a 2,3 millones de km de Júpiter; ganó casi 4 km/s y el viaje se acortó 3 años.
			-- New Horizons aprovechó para probar sus instrumentos observando Júpiter y sus lunas.
			title = "EVENTO 2 · SOBREVUELO DE JÚPITER",
			brief = function(state)
				return "Pasás a 2,3 millones de km de Júpiter: su gravedad te da casi 4 km/s gratis. Hay mucha radiación.",
					"OBSERVAR JÚPITER\n+" .. (scienceGain(state) + 40) .. " MB\nComo hizo la NASA",
					"HIBERNAR\nTodo apagado\nSin datos"
			end,
			resolve = function(state, choice)
				local gain = scienceGain(state) + 40
				if choice == 1 then
					state.data += gain
					state.integrity -= 4                                   -- la radiación de Júpiter castiga los circuitos
					if state.mods.power ~= "B" then
						state.power -= 40
						return "Sin RTG la energía no alcanza para todo.\n-40% de energía · +" .. gain .. " MB."
					end
					state.power -= 6
					return "Júpiter y sus lunas fotografiados.\n+" .. gain .. " MB · -4% por radiación."
				end
				return "Pasaste dormido: Júpiter igual te aceleró.\nNo hay datos nuevos."
			end,
		},
		{
			-- Real: 14/7/2015, a 12.500 km de la superficie, a 13,78 km/s. La señal tarda 4 h 25 min.
			-- La NASA bajó primero un paquete comprimido de prioridad y el resto durante ~16 meses.
			title = "EVENTO 3 · PLUTÓN Y ENLACE CON LA TIERRA",
			brief = function(state)
				return "¡Pasaste a 12.500 km de Plutón! Tenés " .. state.data .. " MB a bordo y la señal tarda 4 h 25 min.",
					"PAQUETE PRIORITARIO\nComprimido\nComo hizo la NASA",
					"VOLCADO TOTAL\nMáxima potencia\nPide más de 35% de energía"
			end,
			resolve = function(state, choice)
				local high = state.mods.comms == "B"
				local band = high and 213 or 4
				if choice == 1 then
					state.sent = math.min(state.data, math.round(band * 0.75))
					state.power -= high and 14 or 8
					return "Enlace prioritario completado.\n" .. state.sent .. " MB recibidos en Tierra."
				elseif state.power < 35 then
					state.sent = math.min(state.data, math.round(band * 0.35))
					state.power = 0
					return "Caída de tensión a mitad de la transmisión.\nSolo llegaron " .. state.sent .. " MB."
				end
				state.sent = math.min(state.data, band)
				state.power -= high and 30 or 16
				state.integrity -= high and 12 or 5
				return "Volcado completo.\n" .. state.sent .. " MB recibidos en Tierra."
			end,
		},
	},
	rover = {
		{
			title = "EVENTO 1 · BORDE DEL CRÁTER",
			brief = function()
				return "Borde del cráter Jezero: pendiente de 24,5° y 420 m de desnivel. Riesgo de atasco en los ejes.",
					"RODEAR EL CRÁTER\nRuta larga\nGasta energía extra",
					"DESCENSO DIRECTO\nPor la pendiente\nRiesgo mecánico"
			end,
			resolve = function(state, choice)
				local gain = scienceGain(state)
				state.data += gain
				if choice == 1 then
					state.power -= (state.mods.power == "B") and 8 or 26
					return "Cráter rodeado sin esfuerzo mecánico.\n+" .. gain .. " MB de datos."
				elseif state.mods.mobility == "A" then
					state.power -= 10
					return "La suspensión articulada absorbió el desnivel.\n+" .. gain .. " MB de datos."
				end
				state.integrity -= 32
				return "Atasco parcial contra roca basáltica.\n-32% de integridad · +" .. gain .. " MB."
			end,
		},
		{
			title = "EVENTO 2 · TORMENTA DE POLVO",
			brief = function(state)
				return "Una tormenta de polvo tapa el Sol y llega la noche marciana: −90 °C afuera.",
					"CALEFACCIONAR\nApaga instrumentos\nProtege los circuitos",
					"FORZAR EL MUESTREO\n+" .. scienceGain(state) .. " MB\nAlto consumo"
			end,
			resolve = function(state, choice)
				local gain = scienceGain(state)
				if choice == 1 then
					if state.mods.power == "B" then
						return "El generador nuclear estabilizó el chasis sin pérdidas."
					end
					state.power -= 25
					state.thermal -= 30
					return "Reserva eléctrica drenada.\n-25% de energía. Circuitos a salvo."
				end
				state.data += gain
				if state.mods.power == "B" then
					return "Muestreo completado.\n+" .. gain .. " MB de datos."
				end
				state.power -= 46
				state.thermal -= 45
				return "Sobrecarga en calefacción e instrumento.\n-46% de energía · +" .. gain .. " MB."
			end,
		},
		{
			title = "EVENTO 3 · RELEVO ORBITAL",
			brief = function(state)
				return "El orbitador de relevo pasa sobre el rover por 8 minutos y la antena está torcida. Tenés " .. state.data .. " MB para mandar.",
					"PAQUETE COMPRIMIDO\n75% de los datos\nSeguro",
					"RECALIBRAR Y ENVIAR TODO\n100% de los datos\nPide más de 30% de energía"
			end,
			resolve = function(state, choice)
				if choice == 1 then
					state.sent = math.round(state.data * 0.75)
					state.power -= 10
					return "Paquete comprimido recibido por el relevo.\n" .. state.sent .. " MB en Tierra."
				elseif state.power < 30 then
					state.sent = math.round(state.data * 0.45)
					state.power = 0
					return "Caída de tensión durante la recalibración.\nSolo subieron " .. state.sent .. " MB."
				end
				state.sent = state.data
				state.power -= 22
				return "Recalibración y subida completa.\n" .. state.sent .. " MB en Tierra."
			end,
		},
	},
}


-- Tercera decisión de cada evento: el camino intermedio (ni lo más seguro, ni lo más arriesgado)
local MIDDLE = {
	probe = {
		{
			text = "CORRECCIÓN PARCIAL\nMitad de la quema\nError residual",
			resolve = function(state)
				local gain = scienceGain(state)
				local burn = Educativo.propelenteParaDv(220, 478, Educativo.MANIOBRA.requerido) * 0.5
				state.data += gain
				state.fuel = math.max(0, state.fuel - burn)
				state.integrity -= 14
				return string.format("Quema parcial (-%.1f kg). Queda un error residual.\n-14%% · +%d MB.", burn, gain)
			end,
		},
		{
			text = "OBSERVAR DE A UNO\nUn instrumento por vez\nMenos de 12 W",
			resolve = function(state)
				local gain = math.round((scienceGain(state) + 40) / 2)
				state.data += gain
				state.integrity -= 2
				if state.mods.power ~= "B" then
					state.power -= 20
					return "Sin RTG, ni de a uno alcanza la energía.\n-20% de energía · +" .. gain .. " MB."
				end
				return "Observaste de a un instrumento, como se hizo en Plutón.\n+" .. gain .. " MB de datos."
			end,
		},
		{
			text = "PAQUETE ESTÁNDAR\n90% de la banda\nCalor moderado",
			resolve = function(state)
				local high = state.mods.comms == "B"
				local band = high and 213 or 4
				local cost = high and 22 or 12
				if state.power < cost then
					state.sent = math.min(state.data, math.round(band * 0.5))
					state.power = 0
					return "Energía insuficiente a mitad del envío.\nSolo llegaron " .. state.sent .. " MB."
				end
				state.sent = math.min(state.data, math.round(band * 0.9))
				state.power -= cost
				state.integrity -= high and 4 or 1
				return "Paquete estándar enviado.\n" .. state.sent .. " MB recibidos en Tierra."
			end,
		},
	},
	rover = {
		{
			text = "DESCENSO EN ZIGZAG\nPendiente suave\nEnergía moderada",
			resolve = function(state)
				local gain = scienceGain(state)
				state.data += gain
				state.power -= (state.mods.power == "B") and 6 or 16
				if state.mods.mobility == "B" then
					state.integrity -= 14
					return "El zigzag evitó el atasco, pero las ruedas sufrieron.\n-14% de integridad · +" .. gain .. " MB."
				end
				return "Descenso controlado en zigzag.\n+" .. gain .. " MB de datos."
			end,
		},
		{
			text = "CALEFACCIÓN PARCIAL\nInstrumento al 50%\nEquilibrio",
			resolve = function(state)
				local gain = math.round(scienceGain(state) / 2)
				state.data += gain
				if state.mods.power == "B" then
					return "El generador sostuvo calefacción e instrumento.\n+" .. gain .. " MB de datos."
				end
				state.power -= 30
				state.thermal -= 32
				return "Calefacción parcial con las baterías de los paneles.\n-30% de energía · +" .. gain .. " MB."
			end,
		},
		{
			text = "PAQUETE MEDIANO\n90% de los datos\nEnergía moderada",
			resolve = function(state)
				if state.power < 16 then
					state.sent = math.round(state.data * 0.5)
					state.power = 0
					return "Energía insuficiente para el envío.\nSolo subieron " .. state.sent .. " MB."
				end
				state.sent = math.round(state.data * 0.9)
				state.power -= 16
				return "Paquete mediano recibido por el relevo.\n" .. state.sent .. " MB en Tierra."
			end,
		},
	},
}

-- Revisión de cada decisión para el informe final: qué se eligió y qué se podía mejorar
local ADVICE = {
	probe = {
		function(_, c)
			if c == 1 then
				return "Corregir temprano es lo más barato: la NASA lo hizo el día 9."
			elseif c == 2 then
				return "Sin corregir, el error crece con el tiempo y Júpiter queda lejos."
			end
			return "La corrección parcial ahorró hidracina, pero dejó error."
		end,
		function(s, c)
			local rtg = s.mods.power == "B"
			if c == 1 then
				return rtg and "Observar Júpiter fue el gran ensayo antes de Plutón, como en 2007."
					or "Sin RTG la energía no alcanza lejos del Sol."
			elseif c == 2 then
				return "Hibernar es seguro (New Horizons hibernó casi todo el viaje), pero perdiste a Júpiter."
			end
			return "De a un instrumento: menos datos y casi sin riesgo."
		end,
		function(s, c, before)
			if c == 1 then
				return "Paquete prioritario: lo que hizo la NASA. El resto se baja en meses."
			elseif c == 2 then
				if s.power <= 0 and before.power < 35 then
					return "Sin energía suficiente, la transmisión se cortó a mitad."
				end
				return s.mods.comms == "B" and "La antena de alta ganancia exprimió toda la ventana."
					or "El volcado completo exprimió la antena, a costa de energía."
			end
			return "Paquete estándar: equilibrio entre datos y energía."
		end,
	},
	rover = {
		function(s, c)
			if c == 1 then
				return s.mods.power == "A" and "Rodeaste el cráter: seguro, pero los paneles no alcanzaron para la ruta larga."
					or "Rodeaste el cráter y el generador absorbió el gasto."
			elseif c == 2 then
				return s.mods.mobility == "A" and "La suspensión articulada absorbió la pendiente: gran decisión."
					or "Las ruedas de malla no aguantan la bajada directa."
			end
			return s.mods.mobility == "B" and "El zigzag evitó lo peor, aunque las ruedas sufrieron."
				or "Zigzag prudente, aunque la suspensión permitía bajar directo."
		end,
		function(s, c)
			local nuclear = s.mods.power == "B"
			if c == 1 then
				return nuclear and "El generador nuclear mantuvo todo caliente sin costo."
					or "Sin Sol, calefaccionar vació las baterías, pero salvó los circuitos."
			elseif c == 2 then
				return nuclear and "Con generador nuclear muestreaste sin costo."
					or "Sin Sol, forzar el muestreo casi agota las baterías."
			end
			return "Calefacción parcial: mitad de datos y riesgo moderado."
		end,
		function(s, c, before)
			if c == 1 then
				return "Paquete comprimido: seguro, pero dejaste datos en el rover."
			elseif c == 2 then
				if s.power <= 0 and before.power < 30 then
					return "Sin energía para recalibrar: subió menos de la mitad."
				end
				return "Recalibraste y subiste todo: máximo rendimiento."
			end
			return "Paquete del 90%: buen equilibrio entre datos y energía."
		end,
	},
}

-- Cómo salió cada decisión. El primer carácter es el ícono (la consola colorea según ✓ / ✗).
local MARK = { bien = "✓ ¡BIEN HECHO!", regular = "! SE PUEDE MEJORAR", mal = "✗ SALIÓ MAL" }
local MARK_LOOK = {
	[MARK.bien] = { icono = "✓", color = "verde", titulo = "¡BIEN HECHO!" },
	[MARK.regular] = { icono = "!", color = "amarillo", titulo = "SE PUEDE MEJORAR" },
	[MARK.mal] = { icono = "✗", color = "rojo", titulo = "SALIÓ MAL" },
}

-- Tarjeta para los monitores y la consola: ícono grande, título, una frase y fichas.
-- El cliente la dibuja (Consolas.tarjeta). chips = { { texto = "⚡ −34 %", ok = false }, ... }
local function card(icono, color, titulo, linea, chips)
	return { tarjeta = true, icono = icono, color = color, titulo = titulo, linea = linea or "", chips = chips or {} }
end

-- Foto del estado antes de una decisión, para mostrar qué cambió
local function snapshot(state)
	return { power = state.power, integrity = state.integrity, thermal = state.thermal, fuel = state.fuel, data = state.data, sent = state.sent }
end

local function changeChips(state, before)
	local chips = {}
	local function add(icon, delta, unit, decimals)
		if math.abs(delta) < 0.05 then
			return
		end
		local number = string.format("%." .. (decimals or 0) .. "f", math.abs(delta)):gsub("%.", ",")
		table.insert(chips, { texto = string.format("%s %s%s%s", icon, delta > 0 and "+" or "−", number, unit), ok = delta > 0, cambio = true })
	end
	add("⚡", state.power - before.power, " %")
	add("🛡️", state.integrity - before.integrity, " %")
	if state.mission == "probe" then
		add("⛽", state.fuel - before.fuel, " kg", 1)
	else
		add("🌡️", state.thermal - before.thermal, " %")
	end
	add("💾", state.data - before.data, " MB")
	add("📡", state.sent - before.sent, " MB")
	return chips
end

local function reviewDecision(state, index, choice, before)
	local lostIntegrity = before.integrity - state.integrity
	local lostPower = before.power - state.power
	local mark = MARK.bien
	if lostIntegrity >= 20 or state.power <= 0 then
		mark = MARK.mal
	elseif lostIntegrity >= 8 or lostPower >= 30 then
		mark = MARK.regular
	end
	return mark, ADVICE[state.mission][index](state, choice, before)
end

-- Parámetros que usa la predicción (y el resultado real) de los eventos interactivos
local function maneuverParams(state)
	local _, mass = totals(state)
	local f = Componentes.ficha("probe", "propulsion", state.mods.propulsion)
	return { m0 = mass + state.fuel, isp = f.isp, combustible = state.fuel, bateriasLitio = false }    -- New Horizons no usa baterías
end

local function routeParams(state)
	local mob = Componentes.ficha("rover", "mobility", state.mods.mobility)
	local r = designSummary(state)
	return {
		pendienteMax = mob.pendienteMax, potenciaTraccion = mob.consumoW, produccion = r.produccionW,
		almacenamiento = r.almacenamientoWh, consumoBase = Componentes.BASE.rover.consumoW + Componentes.RADIO_ROVER.consumoW,
	}
end

local function clampState(state)
	state.power = math.clamp(state.power, 0, 100)
	state.integrity = math.clamp(state.integrity, 0, 100)
	state.thermal = math.clamp(state.thermal, 0, 100)
	state.fuel = math.max(0, state.fuel)
end

local function showEvent(player)
	local state = states[player]
	local m = state.mission
	local index = state.event
	remote:FireClient(player, "track", m, index - 1)          -- mueve el marcador del gráfico
	if index == 1 then
		if m == "probe" then
			-- (v8: el plan es la TCM-1 real de la NASA; el JSON de GMAT es un ejemplo sintético y ya no se usa acá)
			setScreen(player, m .. "-main", card("⚠", "amarillo", "CORRECCIÓN TCM-1",
				"Salimos a 16,2 km/s. Para llegar justo a Júpiter hay que corregir 18 m/s.", { { texto = "▼ Configurá la maniobra en la consola" } }))
			sendConsole(player, {
				mission = m, mode = "maneuver", title = "EVENTO 1 · CORRECCIÓN TCM-1", params = maneuverParams(state),
			})
			logEvent(player, "⚠ EVENTO 1 · corrección de 18 m/s hacia Júpiter")
		else
			setScreen(player, m .. "-main", card("⚠", "amarillo", "BAJADA AL CRÁTER",
				"Hay que bajar 420 m. Muy empinado se atasca; muy suave gasta energía.", { { texto = "▼ Elegí ángulo y velocidad en la consola" } }))
			sendConsole(player, { mission = m, mode = "route", title = "EVENTO 1 · RUTA DE DESCENSO", params = routeParams(state) })
			logEvent(player, "⚠ EVENTO 1 · ruta al cráter")
		end
	else
		local event = EVENTS[m][index]
		local situation, option1, option2 = event.brief(state)
		setScreen(player, m .. "-main", card("⚠", "amarillo", (event.title:gsub("^EVENTO %d · ", "")), situation,
			{ { texto = "▼ Elegí una opción en la consola" } }))
		sendConsole(player, {
			mission = m, mode = "decision", title = event.title, situation = situation,
			options = {
				{ label = "OPCIÓN 1", text = option1 },
				{ label = "OPCIÓN 2", text = option2 },
				{ label = "OPCIÓN 3", text = MIDDLE[m][index].text },
			},
		})
		logEvent(player, "⚠ " .. event.title)
	end
	state.busy = false
	refresh(player)
end

local function finishMission(player, failReason)
	local state = states[player]
	local mission = MISSIONS[state.mission]
	local m = state.mission
	local cost = totals(state)
	local letter, title, score

	if failReason then
		letter, title = "X", "SEÑAL PERDIDA · " .. failReason
		score = state.sent * 5
	else
		if state.sent >= 130 and state.integrity >= 70 then
			letter, title = "S", "RETORNO CIENTÍFICO EJEMPLAR"
		elseif state.sent >= 70 then
			letter, title = "A", "MISIÓN CUMPLIDA"
		else
			letter, title = "B", "RETORNO CIENTÍFICO LIMITADO"
		end
		score = state.sent * 10 + state.integrity * 5 + state.power * 3 + (mission.budget - cost) * 10
	end

	local goals = {
		{ ok = state.sent >= mission.goalMB, text = string.format("Recibir %d MB en Tierra", mission.goalMB), chip = string.format("📡 %d MB", mission.goalMB) },
		{ ok = state.integrity >= 70, text = "Terminar con integridad de 70% o más", chip = "🛡️ Nave sana" },
		{ ok = labCount(state) >= 3, text = "Validar el diseño con las 3 pruebas del laboratorio", chip = "🔬 3 pruebas" },
	}
	local stars = 0
	for _, goal in ipairs(goals) do
		if goal.ok then
			stars += 1
		end
	end
	if not failReason then
		score += stars * 150
	end

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Rango.Value = letter
		if score > stats.Puntaje.Value then
			stats.Puntaje.Value = score
		end
	end

	setPhase(player, "F", "FASE F · INFORME FINAL", "Rango " .. letter)
	remote:FireClient(player, "track", m, 3)
	logEvent(player, "FIN DE MISIÓN · RANGO " .. letter)
	-- Informe: una X roja gigante si se perdió la nave; si no, la letra del rango y las estrellas
	local chips = {}
	for _, goal in ipairs(goals) do
		table.insert(chips, { texto = goal.chip, ok = goal.ok })
	end
	local starText = string.rep("★", stars) .. string.rep("☆", 3 - stars)
	local report
	if failReason then
		local why = failReason == "SIN ENERGÍA" and "La nave se quedó sin energía." or "La nave se rompió."
		report = card("✗", "rojo", "MISIÓN FALLIDA", why .. "  " .. starText, chips)
	else
		local colors = { S = "verde", A = "verde", B = "amarillo" }
		report = card(letter, colors[letter], title, string.format("%s   ·   %d puntos", starText, score), chips)
	end
	setScreen(player, m .. "-main", report)
	local review = { "LO QUE APRENDISTE", "" }
	for index = 1, 3 do
		local entry = state.log[index]
		if entry then
			table.insert(review, string.format("%s  %s", entry.mark:match("^(%S+)") or "", entry.tip))
		end
	end
	setScreen(player, m .. "-log", table.concat(review, "\n\n"))
	sendConsole(player, { mission = m, mode = "report", card = report, text = string.format("RANGO %s · %s", letter, title) })
	refreshAtrium(player)
	say(player, "Mirá el monitor derecho: ahí está lo que aprendiste. Volvés al hangar en 25 s.")
	task.wait(25)
	if states[player] == state then
		goToHangar(player, state.mission, state.mods, state.anim)
		say(player, "De vuelta en el hangar. Cambiá piezas y probá otra estrategia.")
	end
end

-- Muestra el resultado, actualiza el historial y pasa al evento siguiente (o al informe)
local function afterResult(player, state, index, result, mark, tip, before)
	clampState(state)
	state.log[index] = { mark = mark, tip = tip }
	local failReason = nil
	if state.integrity <= 0 then
		failReason = "FALLO ESTRUCTURAL"
	elseif state.power <= 0 and index < 3 then
		failReason = "SIN ENERGÍA"
	end
	local m = state.mission
	-- Resultado en una tarjeta: ✓ / ! / ✗ grande, una frase que explica y lo que cambió
	local look = MARK_LOOK[mark] or MARK_LOOK[MARK.regular]
	local resultCard = card(look.icono, look.color, look.titulo, tip, changeChips(state, before))
	setScreen(player, m .. "-main", resultCard)
	sendConsole(player, { mission = m, mode = "result", card = resultCard, text = result, mark = mark })
	logEvent(player, "RESULTADO EVENTO " .. index .. " · " .. mark)
	state.busy = false
	refresh(player)
	state.busy = true
	task.wait(5)
	if states[player] ~= state then
		return
	end
	if failReason or index == 3 then
		finishMission(player, failReason)
	else
		state.event += 1
		showEvent(player)
	end
end

-- Envía un comando y espera el retraso de señal (abreviado)
local function transmit(player, state, label)
	state.busy = true
	local m = state.mission
	setScreen(player, m .. "-main", card("📡", "azul", "TRANSMITIENDO…", label, { { texto = "⏱ La señal tarda " .. MISSIONS[m].delay:lower() } }))
	sendConsole(player, { mission = m, mode = "wait", text = label })
	logEvent(player, "COMANDO · " .. label)
	refresh(player)
	task.wait(2)
	return states[player] == state
end

local function decide(player, choice)
	local state = states[player]
	choice = tonumber(choice)
	if not state or state.phase ~= "flight" or state.busy or state.event == 1 then
		return
	end
	if choice ~= 1 and choice ~= 2 and choice ~= 3 then
		return
	end
	local m = state.mission
	local index = state.event
	if not transmit(player, state, "OPCIÓN " .. choice) then
		return
	end
	local before = snapshot(state)
	local result
	if choice == 3 then
		result = MIDDLE[m][index].resolve(state)
	else
		result = EVENTS[m][index].resolve(state, choice)
	end
	clampState(state)
	local mark, tip = reviewDecision(state, index, choice, before)
	afterResult(player, state, index, result, mark, tip, before)
end

-- EVENTO 1 DE LA SONDA: corrección orbital configurada por el jugador
local function maneuver(player, data)
	local state = states[player]
	if not state or state.phase ~= "flight" or state.busy or state.mission ~= "probe" or state.event ~= 1 or type(data) ~= "table" then
		return
	end
	local M = Educativo.MANIOBRA
	local dv = math.clamp(math.floor((tonumber(data.dv) or 0) / M.paso + 0.5) * M.paso, 0, M.maxDv)
	local dir = data.dir == "pro" and "pro" or "retro"
	local momento = math.clamp(math.floor(tonumber(data.momento) or 1), 1, #M.momentos)
	local pred = Educativo.prediccionManiobra(maneuverParams(state), dv, dir, momento)
	local label = string.format("Δv %d m/s %s · %s", dv, dir == "retro" and "RETRÓGRADA" or "PROGRADA", pred.momento.nombre)
	if not transmit(player, state, label) then
		return
	end
	local before = snapshot(state)
	state.fuel -= pred.consumo
	state.integrity -= pred.danio
	state.power -= pred.energia
	local gain = scienceGain(state)
	if math.abs(pred.error) > 15 then
		gain = math.floor(gain / 2)
	end
	state.data += gain
	remote:FireClient(player, "maneuverResult", { escala = pred.escala, error = pred.error, consumo = pred.consumo, estado = pred.estado })

	local estados = { nominal = "dentro de la tolerancia", insuficiente = "corrección insuficiente", excesiva = "corrección excesiva" }
	local result = string.format("Maniobra: %s\nPropelente consumido: %.1f kg · quema de %.0f s con 4 × 4,4 N\nError respecto de la ruta a Júpiter: %+.0f m/s (%s)\n%s+%d MB de datos.",
		label, pred.consumo, pred.duracion, pred.error, estados[pred.estado], pred.danio > 0 and string.format("-%d%% de integridad · ", pred.danio) or "", gain)
	local mark, tip
	if pred.estado == "nominal" then
		mark = MARK.bien
		tip = pred.momento.clave == "dia9" and "Corregiste el día 9, como la NASA: 18 m/s y el mínimo de hidracina."
			or string.format("Corregiste, pero más tarde cada m/s rinde %d %%: gastaste más hidracina.", math.floor(pred.momento.rendimiento * 100))
	elseif math.abs(pred.error) <= 8 then
		mark = MARK.regular
		tip = string.format("Quedó un error de %+.0f m/s. El Δv efectivo debía ser 18 m/s.", pred.error)
	else
		mark = MARK.mal
		if not pred.alcanza then
			tip = "Faltó propelente para completar la quema."
		elseif dir == "pro" then
			tip = "Acelerar (prograda) empeoró el error: en este escenario había que frenar."
		elseif pred.estado == "insuficiente" then
			tip = string.format("Quema corta: faltaron %.0f m/s efectivos.", pred.error)
		else
			tip = string.format("Te pasaste %.0f m/s: hidracina desperdiciada y rumbo desviado.", -pred.error)
		end
	end
	afterResult(player, state, 1, result, mark, tip, before)
end

-- EVENTO 1 DEL VEHÍCULO: ruta de descenso configurada por el jugador
local function route(player, data)
	local state = states[player]
	if not state or state.phase ~= "flight" or state.busy or state.mission ~= "rover" or state.event ~= 1 or type(data) ~= "table" then
		return
	end
	local R = Educativo.RUTA
	local angle = math.clamp(R.minAngulo + math.floor(((tonumber(data.angulo) or 16) - R.minAngulo) / R.paso + 0.5) * R.paso, R.minAngulo, R.maxAngulo)
	local vel = (tonumber(data.vel) == 2) and 2 or 1
	local pred = Educativo.prediccionRuta(routeParams(state), angle, vel)
	local label = string.format("RUTA %d° · velocidad %s", pred.angulo, pred.vel.nombre)
	if not transmit(player, state, label) then
		return
	end
	local before = snapshot(state)
	state.power -= pred.energiaPct
	state.integrity -= pred.danio
	local gain = scienceGain(state)
	if pred.estado == "atasco" then
		gain = math.floor(gain / 2)
	end
	state.data += gain
	local estados = { ok = "descenso sin incidentes", patinaje = "patinó en la pendiente", atasco = "quedó atascado y hubo que maniobrar" }
	local result = string.format("%s\nRecorrido: %.2f km en %.1f h de manejo (%d soles) · batería -%d%% por sol\nRiesgo estimado: %d%% · %s\n%s+%d MB de datos.",
		label, pred.distancia / 1000, pred.horas, pred.soles, pred.energiaPct, math.floor(pred.riesgo * 100 + 0.5), estados[pred.estado],
		pred.danio > 0 and string.format("-%d%% de integridad · ", pred.danio) or "", gain)
	local mark, tip
	if pred.estado == "atasco" then
		mark = MARK.mal
		tip = string.format("%d° supera los %d° que aguanta la locomoción.", pred.angulo, routeParams(state).pendienteMax)
	elseif pred.estado == "patinaje" then
		mark = MARK.regular
		tip = "Riesgo alto de patinar: bajá el ángulo o la velocidad."
	elseif pred.energiaPct > 35 then
		mark = MARK.regular
		tip = "A velocidad máxima cada sol vacía mucho las baterías."
	elseif pred.soles > 6 then
		mark = MARK.regular
		tip = string.format("Ruta segura pero muy larga: %d soles de manejo.", pred.soles)
	else
		mark = MARK.bien
		tip = "Buen equilibrio entre distancia, energía y riesgo."
	end
	afterResult(player, state, 1, result, mark, tip, before)
end

---------------------------------------------------------------------------
-- 8. DECORADO REUTILIZABLE
---------------------------------------------------------------------------
local function buildComputer(cf, screenText)
	local m = make("Model", { Name = "Computadora" }, decor)
	box(m, Vector3.new(7, 0.4, 3.4), cf * CFrame.new(0, 3, 0), WHITE)
	box(m, Vector3.new(0.4, 2.8, 3), cf * CFrame.new(-3.1, 1.4, 0), STEEL, METAL)
	box(m, Vector3.new(0.4, 2.8, 3), cf * CFrame.new(3.1, 1.4, 0), STEEL, METAL)
	box(m, Vector3.new(0.5, 1, 0.4), cf * CFrame.new(0, 3.7, -1), DARK, METAL)
	box(m, Vector3.new(4, 2.6, 0.3), cf * CFrame.new(0, 5.2, -1), DARK, METAL)
	local display = box(m, Vector3.new(3.7, 2.3, 0.05), cf * CFrame.new(0, 5.2, -0.83), SCREEN_BG, NEON)
	surfaceText(display, Enum.NormalId.Back, screenText, GREEN, SCREEN_BG, 40)
	box(m, Vector3.new(2.4, 0.15, 0.9), cf * CFrame.new(0, 3.28, 0.5), DARK)
	box(m, Vector3.new(1.4, 2.4, 2.6), cf * CFrame.new(2.4, 4.4, -0.2), DARK, METAL)
	cyl(m, 2, 0.4, cf * CFrame.new(0, 1, 3.2), STEEL, METAL)
	cyl(m, 0.4, 2.4, cf * CFrame.new(0, 2.1, 3.2), BLUE)
	box(m, Vector3.new(2.2, 2.4, 0.3), cf * CFrame.new(0, 3.5, 4.3), BLUE)
end

local function buildRoomShell(point, width, depth, height)
	box(decor, Vector3.new(width, 2, depth), CFrame.new(point(0, -1, 0)), NAVY, METAL)
	box(decor, Vector3.new(width + 4, 2, depth + 4), CFrame.new(point(0, height + 1, 0)), DARK, METAL)
	box(decor, Vector3.new(width + 4, height, 2), CFrame.new(point(0, height / 2, depth / 2 + 1)), DARK, METAL)
	box(decor, Vector3.new(width + 4, height, 2), CFrame.new(point(0, height / 2, -depth / 2 - 1)), DARK, METAL)
end

-- Maqueta animada: la sonda orbita un planeta, el rover recorre un trozo de Marte
local dioramas = {}

local function buildDiorama(missionKey, center)
	local base = CFrame.new(center)
	cyl(decor, 2.6, 14, base * CFrame.new(0, 1.3, 0), DARK, METAL)
	cyl(decor, 0.2, 14.4, base * CFrame.new(0, 2.6, 0), BLUE_HI, NEON)

	local mover = make("Model", { Name = "Maqueta_" .. missionKey }, decor)
	local origin = base * CFrame.new(0, 12, 0)
	if missionKey == "probe" then
		ball(decor, 5.5, base * CFrame.new(0, 7.5, 0), Color3.fromRGB(24, 70, 150), NEON)
		box(mover, Vector3.new(1.3, 1.2, 1.8), origin, GOLD, Enum.Material.Foil)
		box(mover, Vector3.new(3, 0.1, 1.2), origin * CFrame.new(-2.2, 0, 0), BLUE_HI)
		box(mover, Vector3.new(3, 0.1, 1.2), origin * CFrame.new(2.2, 0, 0), BLUE_HI)
		cyl(mover, 0.15, 1.4, origin * CFrame.new(0, 0.8, 0), WHITE)
		ball(mover, 0.35, origin * CFrame.new(0, 0, -1), RED, NEON)
		mover.WorldPivot = origin
		table.insert(dioramas, {
			model = mover, speed = 0.7, radius = 5.6,
			frame = base * CFrame.new(0, 7.5, 0) * CFrame.Angles(math.rad(22), 0, 0),
		})
	else
		cyl(decor, 0.8, 13.6, base * CFrame.new(0, 3, 0), MARS_RED, Enum.Material.Sand)
		local random = Random.new(3)
		for _ = 1, 9 do
			local angle = random:NextNumber(0, math.pi * 2)
			local distance = random:NextNumber(0, 2.6)
			ball(decor, random:NextNumber(0.5, 1.3), base * CFrame.new(math.cos(angle) * distance, 3.5, math.sin(angle) * distance), Color3.fromRGB(120, 64, 44), Enum.Material.Basalt)
		end
		box(mover, Vector3.new(1.5, 0.6, 2.4), origin * CFrame.new(0, 0.7, 0), WHITE)
		box(mover, Vector3.new(1.55, 0.2, 0.5), origin * CFrame.new(0, 0.7, 0), RED)
		for _, z in ipairs({ -0.9, 0, 0.9 }) do
			for _, x in ipairs({ -0.9, 0.9 }) do
				tube(mover, 0.3, 0.8, origin * CFrame.new(x, 0.4, z), DARK)
			end
		end
		cyl(mover, 1.2, 0.12, origin * CFrame.new(0, 1.6, -0.8), STEEL, METAL)
		box(mover, Vector3.new(0.7, 0.35, 0.35), origin * CFrame.new(0, 2.3, -0.8), WHITE)
		mover.WorldPivot = origin
		table.insert(dioramas, {
			model = mover, speed = 0.5, radius = 4.6,
			frame = base * CFrame.new(0, 3.4, 0),
		})
	end
end

local function buildWorkbench(cf)
	box(decor, Vector3.new(8, 0.5, 3), cf * CFrame.new(0, 3, 0), STEEL, METAL)
	for _, x in ipairs({ -3.6, 3.6 }) do
		box(decor, Vector3.new(0.4, 2.8, 2.6), cf * CFrame.new(x, 1.4, 0), DARK, METAL)
	end
	box(decor, Vector3.new(8, 3, 0.3), cf * CFrame.new(0, 4.8, -1.4), DARK, METAL)
	box(decor, Vector3.new(1.6, 0.8, 1), cf * CFrame.new(-2.4, 3.65, 0), RED)
	box(decor, Vector3.new(1.2, 0.3, 0.4), cf * CFrame.new(1, 3.4, 0.4), YELLOW)
	cyl(decor, 1, 0.5, cf * CFrame.new(2.8, 3.75, -0.4), BLUE_HI)
	for i = -1, 1 do
		box(decor, Vector3.new(0.3, 1.6, 0.1), cf * CFrame.new(i * 1.6, 5, -1.2), STEEL, METAL)      -- herramientas colgadas
	end
end

local function buildToolCart(cf)
	box(decor, Vector3.new(3, 3, 2), cf * CFrame.new(0, 2.1, 0), RED, METAL)
	for i = 0, 2 do
		box(decor, Vector3.new(2.6, 0.1, 0.1), cf * CFrame.new(0, 1.2 + i * 0.9, 1.02), STEEL, METAL)
	end
	for _, x in ipairs({ -1.2, 1.2 }) do
		for _, z in ipairs({ -0.7, 0.7 }) do
			ball(decor, 0.6, cf * CFrame.new(x, 0.3, z), DARK)
		end
	end
end

local function buildBarrel(position, color)
	local cf = CFrame.new(position)
	cyl(decor, 4, 2.6, cf * CFrame.new(0, 2, 0), color, METAL)
	cyl(decor, 0.3, 2.7, cf * CFrame.new(0, 1.2, 0), DARK, METAL)
	cyl(decor, 0.3, 2.7, cf * CFrame.new(0, 2.8, 0), DARK, METAL)
end

local function buildCone(position)
	local cf = CFrame.new(position)
	box(decor, Vector3.new(1.6, 0.2, 1.6), cf * CFrame.new(0, 0.1, 0), DARK)
	cyl(decor, 1.2, 1, cf * CFrame.new(0, 0.8, 0), ORANGE)
	cyl(decor, 0.3, 0.85, cf * CFrame.new(0, 1.3, 0), WHITE)
	cyl(decor, 0.9, 0.6, cf * CFrame.new(0, 1.8, 0), ORANGE)
end

local function buildLockers(cf)
	for i = -1, 1 do
		box(decor, Vector3.new(2.4, 8, 2), cf * CFrame.new(i * 2.5, 4, 0), i == 0 and BLUE or STEEL, METAL)
		box(decor, Vector3.new(0.2, 0.8, 0.1), cf * CFrame.new(i * 2.5 + 0.8, 4.4, -1.05), DARK)
	end
end

local function buildForklift(cf)
	box(decor, Vector3.new(4, 2.4, 6), cf * CFrame.new(0, 2, 0), YELLOW, METAL)
	for _, x in ipairs({ -1.7, 1.7 }) do
		for _, z in ipairs({ -0.5, 2.5 }) do
			box(decor, Vector3.new(0.3, 3.6, 0.3), cf * CFrame.new(x, 5, z), DARK, METAL)
		end
		box(decor, Vector3.new(0.4, 8, 0.4), cf * CFrame.new(x * 0.7, 4.4, -3.3), DARK, METAL)
		box(decor, Vector3.new(0.5, 0.25, 4), cf * CFrame.new(x * 0.6, 0.6, -5.2), STEEL, METAL)
		for _, z in ipairs({ -2, 2 }) do
			tube(decor, 1, 2, cf * CFrame.new(x * 1.25, 1, z), DARK)
		end
	end
	box(decor, Vector3.new(3.8, 0.3, 3.6), cf * CFrame.new(0, 6.9, 1), DARK, METAL)
	box(decor, Vector3.new(4, 0.4, 4), cf * CFrame.new(0, 0.95, -5.4), WOOD, Enum.Material.WoodPlanks)
	box(decor, Vector3.new(3.4, 3, 3.4), cf * CFrame.new(0, 2.65, -5.4), STEEL, Enum.Material.DiamondPlate)
end

local function buildBeacon(position)
	local base = cyl(decor, 0.5, 1.2, CFrame.new(position), DARK, METAL)
	local lamp = ball(decor, 1.2, CFrame.new(position + Vector3.new(0, 0.7, 0)), ORANGE, NEON)
	make("PointLight", { Range = 18, Brightness = 1.5 * Campus.LUZ.focos, Color = ORANGE, Shadows = false }, lamp)
	return base
end

local function buildCrateStack(position)
	local cf = CFrame.new(position)
	for _, spot in ipairs({ { 0, 2.5, 0 }, { 5.6, 2.5, 0 }, { 2.8, 7.5, 0 } }) do
		local crate = box(decor, Vector3.new(5, 5, 5), cf * CFrame.new(spot[1], spot[2], spot[3]), STEEL, Enum.Material.DiamondPlate)
		box(decor, Vector3.new(5.05, 1, 5.05), CFrame.new(crate.Position), BLUE)
	end
end

-- Pared a lo largo de X con vanos de puerta (los vanos van ordenados de izquierda a derecha)
local function wallWithDoors(point, z, halfWidth, height, doors)
	local edges = { -halfWidth - 2 }
	for _, door in ipairs(doors) do
		table.insert(edges, door.x - door.width / 2)
		table.insert(edges, door.x + door.width / 2)
		local lintel = height - door.height
		box(decor, Vector3.new(door.width, lintel, 2), CFrame.new(point(door.x, door.height + lintel / 2, z)), DARK, METAL)
	end
	table.insert(edges, halfWidth + 2)
	for i = 1, #edges, 2 do
		local left, right = edges[i], edges[i + 1]
		if right - left > 0.1 then
			box(decor, Vector3.new(right - left, height, 2), CFrame.new(point((left + right) / 2, height / 2, z)), DARK, METAL)
		end
	end
end


-- Brazo robótico articulado. El servidor lo arma en reposo; el cliente lo anima (Ensamblaje).
-- Partes con nombre fijo: Torreta, Brazo, Codo, Antebrazo, Muneca, Pinza, DedoA, DedoB.
local ARM_L1, ARM_L2, ARM_SHOULDER = 11, 11, 6.4

local function buildRoboticArm(name, basePos, length)
	local m = make("Model", { Name = name }, armsFolder)
	m:SetAttribute("Base", basePos)
	m:SetAttribute("Hombro", ARM_SHOULDER)
	local ARM_L1, ARM_L2 = length or ARM_L1, length or ARM_L2         -- el brazo de la torre del rover es más largo
	m:SetAttribute("L1", ARM_L1)
	m:SetAttribute("L2", ARM_L2)
	local base = CFrame.new(basePos)
	cyl(m, 1, 4.2, base * CFrame.new(0, 0.5, 0), DARK, METAL)
	cyl(m, 0.15, 4.3, base * CFrame.new(0, 1.0, 0), YELLOW, NEON)
	cyl(m, 4.2, 1.8, base * CFrame.new(0, 3.1, 0), YELLOW, METAL)
	for i = 0, 3 do
		local a = math.rad(90 * i)
		cable(m, (base * CFrame.new(math.cos(a) * 1.0, 1.2, math.sin(a) * 1.0)).Position,
			(base * CFrame.new(math.cos(a) * 0.95, 4.9, math.sin(a) * 0.95)).Position, CABLE, 0.18)
	end
	named(box(m, Vector3.new(2.6, 1.6, 2.6), base * CFrame.new(0, 5.8, 0), DARK, METAL), "Torreta")
	local shoulder = base.Position + Vector3.new(0, ARM_SHOULDER, 0)
	local elbow = shoulder + Vector3.new(0, ARM_L1 * 0.7, ARM_L1 * 0.7)
	local wrist = elbow + Vector3.new(0, -ARM_L2 * 0.6, ARM_L2 * 0.8)
	named(box(m, Vector3.new(1.3, 1.3, ARM_L1), CFrame.lookAt((shoulder + elbow) / 2, elbow), YELLOW, METAL), "Brazo")
	named(ball(m, 1.7, CFrame.new(elbow), DARK, METAL), "Codo")
	named(box(m, Vector3.new(1.0, 1.0, ARM_L2), CFrame.lookAt((elbow + wrist) / 2, wrist), YELLOW, METAL), "Antebrazo")
	named(ball(m, 1.1, CFrame.new(wrist), DARK, METAL), "Muneca")
	named(box(m, Vector3.new(0.9, 1.2, 0.9), CFrame.new(wrist - Vector3.new(0, 1.1, 0)), DARK, METAL), "Pinza")
	named(box(m, Vector3.new(0.25, 1.2, 0.7), CFrame.new(wrist - Vector3.new(0.45, 2.1, 0)), STEEL, METAL), "DedoA")
	named(box(m, Vector3.new(0.25, 1.2, 0.7), CFrame.new(wrist - Vector3.new(-0.45, 2.1, 0)), STEEL, METAL), "DedoB")
	for _, part in ipairs(m:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	local status = box(m, Vector3.new(0.1, 0.8, 1.2), base * CFrame.new(0.92, 3.4, 0), SCREEN_BG, NEON)
	surfaceText(status, Enum.NormalId.Right, name:match("Brazo(%a)$") or "", YELLOW, SCREEN_BG, 40)
	return m
end

-- Mesa donde el brazo toma la pieza que trae el jugador
local function buildTransferTable(name, pos)
	local cf = CFrame.new(pos)
	local top = box(armsFolder, Vector3.new(5, 0.4, 5), cf * CFrame.new(0, 3, 0), STEEL, Enum.Material.DiamondPlate)
	top.Name = name
	box(decor, Vector3.new(5.1, 0.12, 5.1), cf * CFrame.new(0, 3.24, 0), YELLOW, NEON).Transparency = 0.6
	for _, sx in ipairs({ -2.1, 2.1 }) do
		for _, sz in ipairs({ -2.1, 2.1 }) do
			box(decor, Vector3.new(0.4, 2.8, 0.4), cf * CFrame.new(sx, 1.4, sz), DARK, METAL)
		end
	end
	local sign = box(decor, Vector3.new(4.6, 0.9, 0.1), cf * CFrame.new(0, 2.3, -2.55), YELLOW)
	surfaceText(sign, Enum.NormalId.Front, "MESA DE TRANSFERENCIA", DARK, YELLOW, 40)
	return top
end

-- Lámpara industrial colgante con luz cenital (el cable llega hasta el techo)
local function buildHighBayLamp(pos, ceilingY)
	local cableLength = math.max(1, ceilingY - pos.Y - 0.6)
	cyl(decor, cableLength, 0.15, CFrame.new(pos + Vector3.new(0, 0.6 + cableLength / 2, 0)), STEEL, METAL)
	cyl(decor, 1.2, 3.2, CFrame.new(pos), DARK, METAL)
	local lens = cyl(decor, 0.15, 2.8, CFrame.new(pos - Vector3.new(0, 0.65, 0)), WHITE, NEON)
	make("SpotLight", { Face = Enum.NormalId.Left, Range = 50, Angle = 70, Brightness = 2.2 * Campus.LUZ.focos, Color = Color3.fromRGB(255, 244, 225), Shadows = false }, lens)
end

---------------------------------------------------------------------------
-- ATLAS V (maqueta: más ancho que el real para que entre la nave; las proporciones de color
-- y partes siguen al cohete de verdad: núcleo cobrizo, propulsores sólidos blancos, interetapa
-- blanca con la bandera y cofia blanca con el logo de la NASA).
--   cf = base del cohete (arriba de la mesa de lanzamiento). Su +X local mira a la torre.
--   Partes "Etapa" (núcleo, propulsores e interetapa: se separan en órbita), "Bahia"
--   (adaptador de carga, la nave apoya arriba, a PAYLOAD_Y) y dos modelos de cofia:
--   "CofiaA" (mitad de adelante, -Z) y "CofiaB" (mitad de atrás, +Z), hechos de duelas "Cofia".
--   Las mitades se separan en Z: así el brazo de la torre entra por el costado (+X).
---------------------------------------------------------------------------
local FAIRING_R = 5.2

-- Logo de la NASA dibujado (círculo azul, letras blancas, trazo rojo). Si subís el logo oficial,
-- pegá su id en Campus.IMAGENES.logoNasa y se usa la imagen.
local function drawNasaLogo(part, face)
	local gui = make("SurfaceGui", { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50, LightInfluence = 0.3 }, part)
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	local id = Campus.IMAGENES.logoNasa
	if id and id ~= "" then
		make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = id, ScaleType = Enum.ScaleType.Fit }, root)
		return
	end
	local circle = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(11, 61, 145), BorderSizePixel = 0 }, root)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, circle)
	for _, p in ipairs({ { 0.24, 0.22 }, { 0.68, 0.18 }, { 0.3, 0.76 }, { 0.6, 0.8 }, { 0.8, 0.62 }, { 0.16, 0.5 } }) do
		make("Frame", { Position = UDim2.fromScale(p[1], p[2]), Size = UDim2.fromScale(0.035, 0.035), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, circle)
	end
	local swoosh = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(1.08, 0.09),
		Rotation = -22, BackgroundColor3 = RED, BorderSizePixel = 0,
	}, circle)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, swoosh)
	make("TextLabel", {
		Position = UDim2.fromScale(0.08, 0.3), Size = UDim2.fromScale(0.84, 0.4), BackgroundTransparency = 1,
		Text = "NASA", TextColor3 = WHITE, Font = Enum.Font.GothamBlack, TextScaled = true,
	}, circle)
end

local function drawFlag(part, face)
	local gui = make("SurfaceGui", { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 60, LightInfluence = 0.3 }, part)
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, gui)
	for i = 0, 6 do                                                                  -- 7 franjas rojas de 13
		make("Frame", { Position = UDim2.fromScale(0, i * 2 / 13), Size = UDim2.fromScale(1, 1 / 13), BackgroundColor3 = Color3.fromRGB(178, 34, 52), BorderSizePixel = 0 }, root)
	end
	make("Frame", { Size = UDim2.fromScale(0.4, 7 / 13), BackgroundColor3 = Color3.fromRGB(60, 59, 110), BorderSizePixel = 0 }, root)
end

-- opts = ROCKET[misión]: escala, cantidad de propulsores sólidos y nombre del modelo
local function buildAtlasV(cf, parent, opts)
	local m = make("Model", { Name = "AtlasV" }, parent)
	local function stage(part)
		part.Name = "Etapa"
		return part
	end
	local srbs = opts.srbs or 4
	for _, x in ipairs({ -0.9, 0.9 }) do                                            -- motor RD-180: dos toberas
		stage(cyl(m, 1.8, 1.5, cf * CFrame.new(x, 0.9, 0), DARK, METAL))
	end
	stage(cyl(m, 1.2, 6.2, cf * CFrame.new(0, 2.4, 0), WHITE))                     -- faldón
	stage(cyl(m, 26, 6, cf * CFrame.new(0, 16, 0), ATLAS_COPPER, METAL))           -- núcleo cobrizo
	for _, y in ipairs({ 9, 16, 23 }) do
		stage(cyl(m, 0.25, 6.08, cf * CFrame.new(0, y, 0), Color3.fromRGB(140, 80, 40), METAL))
	end
	for i = 0, srbs - 1 do                                                          -- propulsores sólidos (541: 4 · 551: 5)
		local a = cf * CFrame.Angles(0, math.rad(45 + 360 / srbs * i), 0) * CFrame.new(0, 0, -4.3)
		stage(cyl(m, 17, 2.2, a * CFrame.new(0, 11, 0), WHITE))
		stage(cyl(m, 1.2, 1.7, a * CFrame.new(0, 20.1, 0), WHITE))
		stage(ball(m, 1.7, a * CFrame.new(0, 20.7, 0), WHITE))
		stage(cyl(m, 1.6, 1.5, a * CFrame.new(0, 1.7, 0), DARK, METAL))
		stage(box(m, Vector3.new(0.4, 0.4, 0.5), a * CFrame.new(0, 17, 1.2), STEEL, METAL))
	end
	stage(cyl(m, 3, 6.2, cf * CFrame.new(0, 30.5, 0), WHITE))                      -- interetapa
	local flag = stage(box(m, Vector3.new(2.2, 1.3, 0.05), cf * CFrame.new(0, 30.6, -3.16), WHITE))
	drawFlag(flag, Enum.NormalId.Front)
	named(cyl(m, 1.6, 4, cf * CFrame.new(0, PAYLOAD_Y - 0.8, 0), STEEL, METAL), "Bahia") -- adaptador de carga

	local halves = {}
	for _, info in ipairs({ { name = "CofiaA", from = math.pi }, { name = "CofiaB", from = 0 } }) do
		local half = make("Model", { Name = info.name }, m)
		-- anillo de duelas entre el radio r0 (abajo) y r1 (arriba)
		local function ring(r0, r1, y0, y1)
			local n = 9
			local h = y1 - y0
			local rm = (r0 + r1) / 2
			local tilt = math.atan2(r0 - r1, h)
			local length = math.sqrt(h * h + (r0 - r1) ^ 2)
			local width = 2 * rm * math.sin(math.pi / (2 * n)) * 1.12
			for i = 0, n - 1 do
				local phi = info.from + (i + 0.5) * math.pi / n
				local pos = Vector3.new(math.cos(phi) * rm, (y0 + y1) / 2, math.sin(phi) * rm)
				local stave = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)) * CFrame.Angles(-tilt, 0, 0)
				named(box(half, Vector3.new(width, length, 0.35), cf * stave, WHITE), "Cofia")
			end
		end
		ring(3.2, FAIRING_R, 32, PAYLOAD_Y)
		ring(FAIRING_R, FAIRING_R, PAYLOAD_Y, 46)
		ring(FAIRING_R, 4.6, 46, 48)
		ring(4.6, 3.6, 48, 50)
		ring(3.6, 2.2, 50, 51.8)
		ring(2.2, 0.8, 51.8, 53.2)
		half.WorldPivot = cf
		halves[info.name] = half
	end
	named(ball(halves.CofiaA, 1.4, cf * CFrame.new(0, 53.4, 0), WHITE), "Cofia")       -- punta
	local logo = named(box(halves.CofiaA, Vector3.new(3.6, 3.6, 0.05), cf * CFrame.new(0, 42, -(FAIRING_R + 0.24)), WHITE), "Cofia")
	logo.Transparency = 1
	drawNasaLogo(logo, Enum.NormalId.Front)
	local name = named(box(halves.CofiaA, Vector3.new(4.4, 1.2, 0.05), cf * CFrame.new(0, 38, -(FAIRING_R + 0.24)), WHITE), "Cofia")
	surfaceText(name, Enum.NormalId.Front, opts.model or "ATLAS V", BLUE, WHITE, 60)
	m.WorldPivot = cf
	if (opts.scale or 1) ~= 1 then
		m:ScaleTo(opts.scale)
	end
	return m
end

-- Torre de integración: estructura roja con una plataforma y el brazo que mete la nave en la cofia.
-- Va a 10,5 studs del cohete, sobre su +X local. floorY = altura del piso; deckTop = altura de la plataforma.
local function buildServiceTower(missionKey, rocketCF, floorY, deckTop)
	local opts = ROCKET[missionKey]
	local spot = (rocketCF * CFrame.new(10.5 * opts.scale, 0, 0)).Position
	local tcf = CFrame.new(Vector3.new(spot.X, floorY, spot.Z)) * rocketCF.Rotation
	for _, sx in ipairs({ -2.6, 2.6 }) do
		for _, sz in ipairs({ -2.6, 2.6 }) do
			box(decor, Vector3.new(0.6, deckTop, 0.6), tcf * CFrame.new(sx, deckTop / 2, sz), RED, METAL)
		end
	end
	for y = 4, deckTop - 2, 5 do                                                     -- travesaños en cruz
		box(decor, Vector3.new(0.3, 0.3, 7.4), tcf * CFrame.new(2.6, y, 0) * CFrame.Angles(math.rad(35), 0, 0), RED, METAL)
		box(decor, Vector3.new(0.3, 0.3, 7.4), tcf * CFrame.new(-2.6, y, 0) * CFrame.Angles(math.rad(-35), 0, 0), RED, METAL)
		box(decor, Vector3.new(5.8, 0.3, 0.3), tcf * CFrame.new(0, y, 2.6), STEEL, METAL)
		box(decor, Vector3.new(5.8, 0.3, 0.3), tcf * CFrame.new(0, y, -2.6), STEEL, METAL)
	end
	box(decor, Vector3.new(7, 0.6, 7), tcf * CFrame.new(0, deckTop - 0.3, 0), STEEL, Enum.Material.DiamondPlate)
	box(decor, Vector3.new(7.1, 0.25, 7.1), tcf * CFrame.new(0, deckTop - 0.65, 0), YELLOW, METAL)
	for _, sz in ipairs({ -3.4, 3.4 }) do                                            -- barandas
		box(decor, Vector3.new(7, 0.25, 0.25), tcf * CFrame.new(0, deckTop + 2.2, sz), YELLOW, METAL)
	end
	box(decor, Vector3.new(0.25, 0.25, 7), tcf * CFrame.new(3.4, deckTop + 2.2, 0), YELLOW, METAL)
	for rung = 1, math.floor(deckTop / 2) do                                         -- escalera
		box(decor, Vector3.new(0.3, 0.3, 2.4), tcf * CFrame.new(3.2, rung * 2, 0), STEEL, METAL)
	end
	local sign = box(decor, Vector3.new(0.3, 1.6, 6.4), tcf * CFrame.new(3.5, deckTop - 2.2, 0), WHITE)
	surfaceText(sign, Enum.NormalId.Right, "TORRE DE INTEGRACIÓN", NAVY, WHITE, 40)
	local armBase = (tcf * CFrame.new(-0.6, deckTop, 0)).Position
	local arm = buildRoboticArm(missionKey .. "-BrazoC", armBase, opts.armL)
	arm:SetAttribute("Centro", rocketCF.Position)
	return { name = arm.Name, base = armBase }
end

-- Transportador del rover. Lo maneja el jugador (asiento de vehículo).
-- El pivote es el centro de la caja de carga (ahí apoya el rover); el frente es -Z.
local function buildTransporter(cf)
	local m = make("Model", { Name = "TransportadorRover" }, decor)
	-- v8: caja de carga más larga (el rover ahora mide ~12 studs de largo)
	box(m, Vector3.new(8.5, 0.6, 14), cf * CFrame.new(0, -0.3, 2), STEEL, Enum.Material.DiamondPlate)
	for _, sx in ipairs({ -4.1, 4.1 }) do
		box(m, Vector3.new(0.3, 0.6, 14), cf * CFrame.new(sx, 0.3, 2), YELLOW, METAL)
	end
	box(m, Vector3.new(7, 1, 20), cf * CFrame.new(0, -1.1, 0), DARK, METAL)
	box(m, Vector3.new(7.2, 0.35, 20.2), cf * CFrame.new(0, -0.9, 0), RED)
	box(m, Vector3.new(7.4, 3.2, 0.5), cf * CFrame.new(0, 1.0, -5.3), WHITE)                    -- respaldo de la cabina
	box(m, Vector3.new(7.4, 1.8, 1.4), cf * CFrame.new(0, 0.3, -9.4), WHITE)                    -- tablero
	local glass = box(m, Vector3.new(6.8, 2, 0.2), cf * CFrame.new(0, 2.3, -9.9) * CFrame.Angles(math.rad(-15), 0, 0), BLUE_HI, Enum.Material.Glass)
	glass.Transparency = 0.5
	box(m, Vector3.new(7.4, 0.3, 4.8), cf * CFrame.new(0, 3.9, -7.6), WHITE)                    -- techo
	for _, sx in ipairs({ -3.5, 3.5 }) do
		for _, sz in ipairs({ -5.4, -9.8 }) do
			box(m, Vector3.new(0.3, 3.6, 0.3), cf * CFrame.new(sx, 2.1, sz), STEEL, METAL)
		end
	end
	ball(m, 0.8, cf * CFrame.new(0, 4.3, -7.6), ORANGE, NEON)                                   -- baliza
	for _, sz in ipairs({ -8, -1, 7 }) do
		for _, sx in ipairs({ -3.9, 3.9 }) do
			tube(m, 1.1, 2.6, cf * CFrame.new(sx, -1.4, sz), DARK)
			tube(m, 1.15, 1.2, cf * CFrame.new(sx, -1.4, sz), STEEL, METAL)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local sign = box(m, Vector3.new(0.1, 0.8, 7), cf * CFrame.new(side * 3.56, -1.1, 2.5), WHITE)
		surfaceText(sign, side == 1 and Enum.NormalId.Right or Enum.NormalId.Left, "TRANSPORTE DE NAVES · NASA", NAVY, WHITE, 40)
	end
	local seat = make("VehicleSeat", {
		Name = "rover-Transportador", Anchored = true, Size = Vector3.new(2.4, 0.5, 2.4), Color = BLUE, Material = PLASTIC,
		CFrame = cf * CFrame.new(0, -0.1, -7.4), MaxSpeed = 0, Torque = 0, HeadsUpDisplay = false, Disabled = true,
		TopSurface = Enum.SurfaceType.Smooth,
	}, m)
	m.WorldPivot = cf
	return m, seat
end

-- Torre de servicio y plataforma de lanzamiento (decorado fijo)
local function buildLaunchPad(cf)
	box(decor, Vector3.new(26, 2, 26), cf * CFrame.new(0, 0, 0), Color3.fromRGB(120, 124, 132), Enum.Material.Concrete)
	box(decor, Vector3.new(10, 0.3, 10), cf * CFrame.new(0, 1.1, 0), DARK, METAL)
	box(decor, Vector3.new(8, 2.2, 30), cf * CFrame.new(0, -0.2, -20), Color3.fromRGB(70, 72, 78), Enum.Material.Concrete)  -- foso de llamas
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			box(decor, Vector3.new(0.7, 52, 0.7), cf * CFrame.new(10 + sx * 2.5, 27, sz * 2.5), RED, METAL)
		end
	end
	for y = 4, 50, 6 do
		box(decor, Vector3.new(5.7, 0.4, 5.7), cf * CFrame.new(10, y, 0), STEEL, METAL)
		box(decor, Vector3.new(0.3, 6, 7.2), cf * CFrame.new(10, y + 3, 0) * CFrame.Angles(math.rad(40), 0, 0), RED, METAL)
	end
	box(decor, Vector3.new(2.6, 0.6, 1.2), cf * CFrame.new(8.2, 38, 0), STEEL, METAL)         -- brazo umbilical (no toca la cofia)
	local lamp = ball(decor, 1.2, cf * CFrame.new(10, 53.5, 0), RED, NEON)
	make("PointLight", { Range = 30, Brightness = 2 * Campus.LUZ.focos, Color = RED, Shadows = false }, lamp)
end

-- Poste de iluminación exterior
local function buildFloodlight(pos, lookAt)
	cyl(decor, 18, 0.6, CFrame.new(pos + Vector3.new(0, 9, 0)), STEEL, METAL)
	local head = box(decor, Vector3.new(3, 1.6, 1), CFrame.lookAt(pos + Vector3.new(0, 18, 0), lookAt), DARK, METAL)
	local lens = box(decor, Vector3.new(2.6, 1.2, 0.1), head.CFrame * CFrame.new(0, 0, -0.55), WHITE, NEON)
	make("SpotLight", { Face = Enum.NormalId.Front, Range = 60, Angle = 60, Brightness = 2.5 * Campus.LUZ.focos, Shadows = false }, lens)
end

---------------------------------------------------------------------------
-- 8b. GRÁFICOS DE VUELO (se dibujan con marcos sobre una pantalla)
--     El marcador "Marcador" lo anima el script del jugador con estas mismas medidas.
---------------------------------------------------------------------------
local GRAPH_BG = Color3.fromRGB(2, 6, 15)
local PROFILE = { left = 0.08, right = 0.97, top = 0.26, depth = 0.46 }             -- perfil del cráter

local function profilePoint(n)
	return PROFILE.left + n * (PROFILE.right - PROFILE.left), PROFILE.top + math.exp(-((n - 0.55) * 5) ^ 2) * PROFILE.depth
end

local function gdot(parent, x, y, size, color)
	local dot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color, BorderSizePixel = 0,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
	return dot
end

local function gtext(parent, x, y, width, height, text, color, align)
	return make("TextLabel", {
		Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(width, height), BackgroundTransparency = 1,
		Text = text, TextColor3 = color, Font = Enum.Font.Code, TextScaled = true,
		TextXAlignment = align or Enum.TextXAlignment.Left,
	}, parent)
end

local function graphCanvas(missionKey, size, cf, title, corner)
	local part = make("Part", {
		Name = missionKey, Anchored = true, Size = size, CFrame = cf, Color = GRAPH_BG, Material = NEON,
	}, graphsFolder)
	local gui = make("SurfaceGui", {
		Name = "Grafico", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40, LightInfluence = 0, ClipsDescendants = true,
	}, part)
	local canvas = make("Frame", { Name = "Lienzo", Size = UDim2.fromScale(1, 1), BackgroundColor3 = GRAPH_BG, BorderSizePixel = 0 }, gui)
	local gridColor = Color3.fromRGB(13, 33, 71)
	for i = 1, 23 do
		make("Frame", { Position = UDim2.fromScale(i / 24, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = gridColor, BorderSizePixel = 0 }, canvas)
	end
	for i = 1, 11 do
		make("Frame", { Position = UDim2.fromScale(0, i / 12), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = gridColor, BorderSizePixel = 0 }, canvas)
	end
	local bar = make("Frame", { Size = UDim2.fromScale(1, 0.09), BackgroundColor3 = BLUE, BorderSizePixel = 0 }, canvas)
	make("Frame", { Size = UDim2.new(0, 10, 1, 0), BackgroundColor3 = RED, BorderSizePixel = 0 }, bar)
	gtext(bar, 0.02, 0.15, 0.56, 0.7, title, WHITE)
	gtext(bar, 0.6, 0.15, 0.38, 0.7, corner, WHITE, Enum.TextXAlignment.Right)
	return canvas
end

local function marker(canvas, width, height, text)
	local frame = make("Frame", {
		Name = "Marcador", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height), BackgroundColor3 = WHITE, BorderSizePixel = 0,
	}, canvas)
	make("UIStroke", { Color = RED, Thickness = 4 }, frame)
	make("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 12, 0.5, 0), Size = UDim2.fromOffset(240, 34),
		BackgroundTransparency = 1, Text = text, TextColor3 = WHITE, Font = Enum.Font.Code, TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)
end

-- Vista heliocéntrica de la trayectoria de New Horizons (datos NASA; el marcador lo mueve el cliente)
local function buildGmatScreen(size, cf)
	-- v8: vista heliocéntrica de New Horizons (escala NO lineal: radio ∝ √distancia). Fechas y distancias reales.
	local canvas = graphCanvas("probe", size, cf, "TRAYECTORIA · TIERRA → JÚPITER → PLUTÓN", "ESCALA NO LINEAL · DATOS NASA")
	local green = Color3.fromRGB(51, 255, 102)
	local cyan = Color3.fromRGB(56, 189, 248)
	local soft = Color3.fromRGB(158, 192, 245)
	local G = Educativo.GRAFICO
	local function toCanvas(u, v)
		return u / G.aspecto, v
	end
	local sx, sy = toCanvas(G.solU, G.solV)
	gdot(canvas, sx, sy, 34, YELLOW)
	gtext(canvas, sx - 0.03, sy + 0.05, 0.08, 0.05, "SOL", YELLOW)
	-- órbitas (arcos dentro del lienzo)
	for _, info in ipairs({ { 1, cyan, "TIERRA" }, { 5.203, ORANGE, "JÚPITER" }, { 33, soft, "PLUTÓN (2015)" } }) do
		local r = Educativo.radioGrafico(info[1])
		for i = 0, 119 do
			local a = i / 120 * math.pi * 2
			local x, y = toCanvas(G.solU + r * math.cos(a), G.solV - r * math.sin(a))
			if x > 0.01 and x < 0.99 and y > 0.1 and y < 0.92 then
				gdot(canvas, x, y, 3, info[2])
			end
		end
	end
	-- trayectoria real de New Horizons
	for i = 0, 140 do
		local x, y = Educativo.trayectoriaGrafico(i / 140)
		gdot(canvas, x, y, 6, green)
	end
	local labels = {
		{ 0, cyan, "TIERRA · 19/1/2006 · 16,2 km/s" },
		{ 0.35, ORANGE, "JÚPITER · 28/2/2007 · +4 km/s" },
		{ 1, WHITE, "PLUTÓN · 14/7/2015" },
	}
	for _, item in ipairs(labels) do
		local x, y = Educativo.trayectoriaGrafico(item[1])
		gdot(canvas, x, y, item[1] == 0.35 and 26 or 16, item[2])
		gtext(canvas, math.min(x + 0.02, 0.68), y - 0.07, 0.3, 0.045, item[3], item[2])
	end
	local tx, ty = Educativo.trayectoriaGrafico(0.04)
	gdot(canvas, tx, ty, 14, RED)
	gtext(canvas, tx + 0.02, ty + 0.01, 0.2, 0.045, "TCM-1 · 18 m/s", RED)

	local strip = make("Frame", { Position = UDim2.fromScale(0, 0.93), Size = UDim2.fromScale(1, 0.07), BackgroundColor3 = Color3.fromRGB(6, 16, 36), BorderSizePixel = 0 }, canvas)
	gtext(strip, 0.02, 0.15, 0.3, 0.7, "478 KG · 77 KG DE HIDRACINA", soft)
	gtext(strip, 0.35, 0.15, 0.3, 0.7, "VIAJE: 9,5 AÑOS", soft)
	gtext(strip, 0.68, 0.15, 0.3, 0.7, "SEÑAL: 4 H 25 MIN", soft)

	for i, item in ipairs({ { green, "TRAYECTORIA REAL" }, { YELLOW, "RESULTANTE (tras tu maniobra)" } }) do
		gdot(canvas, 0.715, 0.78 + i * 0.045, 10, item[1])
		gtext(canvas, 0.73, 0.76 + i * 0.045, 0.26, 0.04, item[2], item[1])
	end
	make("Frame", { Name = "Resultado", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, canvas)
	marker(canvas, 18, 18, "NEW HORIZONS")
end

-- Perfil altimétrico del cráter Shackleton con la posición del vehículo
local function buildProfileScreen(size, cf)
	local canvas = graphCanvas("rover", size, cf, "PERFIL DEL TERRENO · MARTE", "CRÁTER JEZERO // PENDIENTE 24,5°")
	local green = Color3.fromRGB(51, 255, 102)
	local soft = Color3.fromRGB(158, 192, 245)
	local span = PROFILE.right - PROFILE.left

	make("Frame", {
		Position = UDim2.fromScale(PROFILE.left + 0.34 * span, 0.14), Size = UDim2.fromScale(0.42 * span, 0.72),
		BackgroundColor3 = BLUE, BackgroundTransparency = 0.55, BorderSizePixel = 0,
	}, canvas)
	gtext(canvas, PROFILE.left + 0.35 * span, 0.15, 0.4 * span, 0.05, "ANTIGUO DELTA DE UN RÍO (ROCAS CON AGUA)", WHITE)

	make("Frame", { Position = UDim2.fromScale(PROFILE.left, 0.14), Size = UDim2.new(0, 3, 0.72, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, canvas)
	make("Frame", { Position = UDim2.fromScale(PROFILE.left, 0.86), Size = UDim2.new(span, 0, 0, 3), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, canvas)
	gtext(canvas, 0.005, PROFILE.top - 0.025, 0.07, 0.05, "0 M", soft)
	gtext(canvas, 0.005, PROFILE.top + PROFILE.depth / 2 - 0.025, 0.07, 0.05, "-210 M", soft)
	gtext(canvas, 0.005, PROFILE.top + PROFILE.depth - 0.025, 0.07, 0.05, "-420 M", soft)
	gtext(canvas, 0.6, 0.875, 0.37, 0.05, "DISTANCIA RECORRIDA (KM) >>", soft, Enum.TextXAlignment.Right)

	for i = 0, 220 do
		local x, y = profilePoint(i / 220)
		gdot(canvas, x, y + math.sin(i / 220 * 34) * 0.004, 7, green)
	end
	gtext(canvas, PROFILE.left + 0.16 * span, PROFILE.top + 0.14, 0.2, 0.05, "PENDIENTE: 24,5°", RED)
	for index, n in ipairs({ 0.20, 0.375, 0.55 }) do                        -- paradas de los tres eventos
		local x, y = profilePoint(n)
		gdot(canvas, x, y, 16, YELLOW)
		gtext(canvas, x - 0.02, y + 0.03, 0.06, 0.05, "E" .. index, YELLOW)
	end

	marker(canvas, 30, 18, "PERSEVERANCE")
end

---------------------------------------------------------------------------
-- 8c. ENSAMBLAJE CON BRAZOS ROBÓTICOS
--     El servidor decide; el cliente anima. Si la animación se omite, la pieza se coloca al instante.
---------------------------------------------------------------------------
local ANIM_TIME = { normal = 3.4, rapida = 1.3, omitir = 0 }

local function nearestArm(missionKey, target)
	local best, bestDistance
	for _, arm in ipairs(COMPLEX[missionKey].arms) do
		local distance = (arm.base - target).Magnitude
		if not bestDistance or distance < bestDistance then
			best, bestDistance = arm, distance
		end
	end
	return best
end

local function installPiece(player, missionKey)
	local state = states[player]
	if not state or state.phase ~= "hangar" or state.mission ~= missionKey or state.busy then
		return
	end
	if not state.carry then
		say(player, "No llevás ninguna pieza. Buscala en la sala que sigue.")
		return
	end
	local mission = MISSIONS[missionKey]
	local index, code = state.carry.index, state.carry.code
	local sub = mission.subsystems[index]
	dropCarried(state)
	local target = scaledSlot(missionKey, index)
	local arm = nearestArm(missionKey, target.Position)
	local duration = ANIM_TIME[state.anim] or ANIM_TIME.normal
	state.busy = true
	refresh(player)
	if duration > 0 then
		remote:FireClient(player, "install", {
			arm = arm.name, table = arm.table, template = missionKey .. "-" .. sub.key .. "-" .. code,
			to = target, duration = duration, scale = VEHICLE_SCALE[missionKey],
		})
		task.wait(duration)
		if states[player] ~= state then
			return
		end
	end
	placePiece(state, index, code)
	state.busy = false
	remote:FireClient(player, "installed", { index = index, mission = missionKey })
	local placed = placedCount(state)
	if placed < #mission.subsystems then
		say(player, string.format("%s instalado. Sigue la SALA %d: %s.", sub[code].name, placed + 1, mission.subsystems[placed + 1].title))
	else
		say(player, missionKey == "probe"
			and "Sonda completa. Validala en el LABORATORIO (atrio) o andá a la consola roja: el brazo de la torre la mete en el Atlas V."
			or "Rover completo. Validalo en el LABORATORIO (atrio) o andá a la consola roja para cargarlo en el transportador.")
	end
	refresh(player)
end

-- Un brazo toma la nave entera y la lleva a otro lugar (al Atlas V o al transportador).
-- El cliente anima el brazo y abre la cofia; acá se espera y después se mueve la nave de verdad.
local INSERT_TIME = { normal = 6, rapida = 2.6, omitir = 0 }

local function moveVehicleWithArm(player, state, armName, target, rocket)
	local duration = INSERT_TIME[state.anim] or INSERT_TIME.normal
	if duration > 0 then
		remote:FireClient(player, "insert", {
			arm = armName, model = state.vehicle, from = state.vehicle:GetPivot(), to = target,
			duration = duration, rocket = rocket,
		})
		task.wait(duration)
		if states[player] ~= state then
			return false
		end
	end
	state.vehicle:PivotTo(target)
	return true
end

local function removePiece(player, missionKey)
	local state = states[player]
	if not state or state.phase ~= "hangar" or state.mission ~= missionKey or state.busy then
		return
	end
	local count = placedCount(state)
	if count == 0 then
		say(player, "No hay piezas para retirar.")
		return
	end
	local sub = MISSIONS[missionKey].subsystems[count]
	local name = sub[state.mods[sub.key]].name
	state.busy = true
	remote:FireClient(player, "removing", { index = count, mission = missionKey })
	task.wait(state.anim == "omitir" and 0 or 0.7)
	if states[player] ~= state then
		return
	end
	unplacePiece(state, count)
	state.busy = false
	say(player, "Retiraste: " .. name .. ". Podés elegir otra opción en la SALA " .. count .. ".")
	refresh(player)
end

---------------------------------------------------------------------------
-- 9. UN COMPLEJO POR MISIÓN: hangar de armado + sala de decisiones
---------------------------------------------------------------------------
Campus.setupLighting()

local function buildComplex(missionKey)
	local mission = MISSIONS[missionKey]
	local origin = ORIGINS[missionKey]
	local side = WINDOW_SIDE[missionKey]        -- lado del ventanal
	local solid = -side                         -- lado de la pared ciega (monitor y consola)
	local count = #mission.subsystems

	local function hall(x, y, z)                -- punto del hangar medido desde el centro del piso
		return Vector3.new(origin.X + x, origin.Y + 1 + y, origin.Z + z)
	end
	local function room(x, y, z)                -- punto de la sala de decisiones
		return Vector3.new(origin.X + x, origin.Y + 1 + y, origin.Z + 130 + z)
	end

	-- HANGAR (110 x 90 de planta, 60 de alto: entra el Atlas V de pie) -------------
	local HEIGHT = HANGAR_HEIGHT
	box(decor, Vector3.new(110, 2, 90), CFrame.new(hall(0, -1, 0)), NAVY, METAL)
	-- Techo en dos mitades: en el lanzamiento de la sonda se abre (la cinemática lo desliza)
	local roofParts = {}
	for _, sign in ipairs({ -1, 1 }) do
		local half = box(decor, Vector3.new(114, 2, 47), CFrame.new(hall(0, HEIGHT + 1, sign * 23.5)), DARK, METAL)
		half.Name = missionKey .. "-TechoRetractil"
		table.insert(roofParts, half)
	end

	-- Salas de piezas: 1 y 2 sobre la pared norte, 3 y 4 sobre la sur
	local ROOMS = { { x = -27, dir = 1 }, { x = 27, dir = 1 }, { x = -27, dir = -1 }, { x = 27, dir = -1 } }
	local northDoors = { { x = -27, width = 12, height = 12 }, { x = 27, width = 12, height = 12 } }
	local southDoors = { { x = -27, width = 12, height = 12 }, { x = 0, width = 22, height = 20 } }
	if count >= 4 then
		table.insert(southDoors, { x = 27, width = 12, height = 12 })
	end
	wallWithDoors(hall, 46, 55, HEIGHT, northDoors)
	wallWithDoors(hall, -46, 55, HEIGHT, southDoors)

	-- Pared ciega y pared con ventanal
	-- Pared interior con puerta al ATRIO CENTRAL (vano de z = -26 a -16, 14 de alto)
	box(decor, Vector3.new(2, HEIGHT, 19), CFrame.new(hall(solid * 56, HEIGHT / 2, -35.5)), DARK, METAL)
	box(decor, Vector3.new(2, HEIGHT, 61), CFrame.new(hall(solid * 56, HEIGHT / 2, 14.5)), DARK, METAL)
	box(decor, Vector3.new(2, HEIGHT - 14, 10), CFrame.new(hall(solid * 56, 14 + (HEIGHT - 14) / 2, -21)), DARK, METAL)
	for _, dz in ipairs({ -5.4, 5.4 }) do
		box(decor, Vector3.new(0.8, 14, 0.8), CFrame.new(hall(solid * 54.8, 7, -21 + dz)), YELLOW, METAL)
	end
	box(decor, Vector3.new(0.8, 0.8, 11), CFrame.new(hall(solid * 54.8, 14.4, -21)), YELLOW, NEON)
	local atriumSign = box(decor, Vector3.new(10, 2.6, 0.4), CFrame.new(hall(solid * 54.6, 17.4, -21)) * CFrame.Angles(0, math.rad(90 * solid), 0), WHITE)
	surfaceText(atriumSign, Enum.NormalId.Front, "ATRIO CENTRAL · LABORATORIOS", NAVY, WHITE, 60)
	box(decor, Vector3.new(2, 8, 90), CFrame.new(hall(side * 56, 4, 0)), DARK, METAL)
	box(decor, Vector3.new(2, 12, 90), CFrame.new(hall(side * 56, 34, 0)), DARK, METAL)
	box(decor, Vector3.new(2, HEIGHT - 40, 90), CFrame.new(hall(side * 56, 40 + (HEIGHT - 40) / 2, 0)), DARK, METAL)
	local glass = box(decor, Vector3.new(1, 20, 90), CFrame.new(hall(side * 56, 18, 0)), BLUE_HI, Enum.Material.Glass)
	glass.Transparency = 0.75
	for _, z in ipairs({ -30, -10, 10, 30 }) do
		box(decor, Vector3.new(1.5, 20, 1.5), CFrame.new(hall(side * 56, 18, z)), STEEL, METAL)
	end
	-- (v8: sale el planeta gigante del ventanal; ahora por la ventana se ve el paisaje del centro espacial)

	-- Techo: cerchas, tiras de luz y puente grúa (lejos del eje del Atlas V, z = 0)
	for _, z in ipairs({ -36, -18, 18, 36 }) do
		box(decor, Vector3.new(110, 1.2, 1.2), CFrame.new(hall(0, HEIGHT - 1.4, z)), STEEL, METAL)
	end
	for _, z in ipairs({ -27, 12, 27 }) do
		box(decor, Vector3.new(96, 0.4, 2), CFrame.new(hall(0, HEIGHT - 0.3, z)), WHITE, NEON)
	end
	for _, z in ipairs({ -28, 0, 28 }) do
		for _, x in ipairs({ -36, 0, 36 }) do
			light(hall(x, 30, z), 62, 1.5)
		end
	end
	box(decor, Vector3.new(110, 1.8, 2.4), CFrame.new(hall(0, HEIGHT - 3.6, -14)), YELLOW, METAL)
	box(decor, Vector3.new(5, 1.6, 4), CFrame.new(hall(solid * 16, HEIGHT - 5.2, -14)), DARK, METAL)
	cyl(decor, 7, 0.3, CFrame.new(hall(solid * 16, HEIGHT - 9.5, -14)), STEEL, METAL)
	box(decor, Vector3.new(1.4, 1.6, 0.6), CFrame.new(hall(solid * 16, HEIGHT - 13.6, -14)), YELLOW, METAL)

	-- Cañerías sobre la pared norte y balizas en las esquinas
	for index, color in ipairs({ RED, WHITE, BLUE_HI }) do
		tube(decor, 110, 1, CFrame.new(hall(0, 31 + index * 2, 44.2)), color, METAL)
	end
	for _, z in ipairs({ -42, 42 }) do
		buildBeacon(hall(side * 53, 30, z))
		buildBeacon(hall(solid * 53, 30, z))
	end

	-- Piso: zona de seguridad alrededor de la nave y franjas
	cyl(decor, 0.3, 36, CFrame.new(hall(0, 0.1, 0)), YELLOW)
	cyl(decor, 0.32, 33, CFrame.new(hall(0, 0.1, 0)), NAVY, METAL)
	box(decor, Vector3.new(110, 0.1, 1.2), CFrame.new(hall(0, 0.05, 30)), RED)
	box(decor, Vector3.new(110, 0.1, 1.2), CFrame.new(hall(0, 0.05, 31.6)), WHITE)
	box(decor, Vector3.new(110, 0.1, 1.2), CFrame.new(hall(0, 0.05, 33.2)), BLUE_HI)
	for _, spot in ipairs({ { -13, -14 }, { 13, -14 }, { -13, 14 }, { 13, 14 } }) do
		buildCone(hall(spot[1], 0, spot[2]))
	end

	-- Cartel del hangar y puestos de trabajo bajo el cartel
	local header = box(decor, Vector3.new(38, 5, 0.6), CFrame.new(hall(0, 25, 44.6)), WHITE)
	surfaceText(header, Enum.NormalId.Front, "HANGAR · " .. mission.short, NAVY, WHITE)
	local towardNorth = CFrame.Angles(0, math.pi, 0)
	buildComputer(CFrame.new(hall(-9, 0, 41)) * towardNorth, "TELEMETRÍA\nENLACE ACTIVO")
	buildComputer(CFrame.new(hall(0, 0, 41)) * towardNorth, "SALA LIMPIA\nCLASE 100")
	buildComputer(CFrame.new(hall(9, 0, 41)) * towardNorth, "MASA Y\nPRESUPUESTO")

	-- Portón del hangar (el transportador del rover sale por acá)
	local door = make("Model", { Name = "Porton" }, decor)
	box(door, Vector3.new(22, 20, 0.8), CFrame.new(hall(0, 10, -46)), STEEL, Enum.Material.DiamondPlate)
	for i = 0, 10 do
		box(door, Vector3.new(2, 2, 0.9), CFrame.new(hall(-10 + i * 2, 1, -46)), i % 2 == 0 and YELLOW or DARK)
	end
	for _, y in ipairs({ 6, 11, 16 }) do
		box(door, Vector3.new(22, 0.4, 0.95), CFrame.new(hall(0, y, -46)), DARK, METAL)
	end
	local doorSign = box(decor, Vector3.new(20, 3, 0.4), CFrame.new(hall(0, 23, -44.6)), YELLOW)
	surfaceText(doorSign, Enum.NormalId.Back, "PORTÓN 1 · SALIDA DE VEHÍCULOS", DARK, YELLOW)
	-- Pasillo exterior detrás del portón
	box(decor, Vector3.new(22, 2, 46), CFrame.new(hall(0, -1, -70)), DARK, METAL)
	box(decor, Vector3.new(26, 2, 46), CFrame.new(hall(0, 21, -70)), DARK, METAL)
	box(decor, Vector3.new(2, 20, 46), CFrame.new(hall(-12, 10, -70)), DARK, METAL)
	box(decor, Vector3.new(2, 20, 46), CFrame.new(hall(12, 10, -70)), DARK, METAL)
	light(hall(0, 15, -66), 40, 1.2)

	-- ATLAS V, torre de integración y (solo rover) plataforma exterior y transportador ----------------
	local rocket, rocketCF, towerArm, truck, truckSeat, truckHome, parkSpot
	if missionKey == "rover" then
		-- Plataforma exterior: el jugador trae el rover en el transportador hasta la ZONA DE ENTREGA
		box(decor, Vector3.new(90, 2, 130), CFrame.new(hall(0, -1, -158)), Color3.fromRGB(96, 100, 108), Enum.Material.Concrete)
		for _, x in ipairs({ -7.5, 7.5 }) do
			box(decor, Vector3.new(0.6, 0.1, 18), CFrame.new(hall(x, 0.05, -100)), YELLOW)
		end
		buildLaunchPad(CFrame.new(hall(0, 0, -180)))
		-- girado 180°: el logo mira al hangar y la torre queda del lado oeste (x negativo)
		rocketCF = CFrame.new(hall(0, 1, -180)) * CFrame.Angles(0, math.pi, 0)
		rocket = buildAtlasV(rocketCF, decor, ROCKET.rover)
		-- cohete 1,3 veces más grande: la plataforma de la torre sube para que el brazo llegue a la cofia
		towerArm = buildServiceTower(missionKey, rocketCF, hall(0, 0, 0).Y, 27.7)
		parkSpot = hall(-21, 0, -180)
		local mark = box(decor, Vector3.new(11, 0.1, 18), CFrame.new(parkSpot + Vector3.new(0, 0.06, 0)), YELLOW)
		mark.Transparency = 0.35
		surfaceText(mark, Enum.NormalId.Top, "ZONA DE ENTREGA", DARK, YELLOW, 80)
		for _, spot in ipairs({ { -32, -125, -112 }, { 32, -125, -112 }, { -38, -205, -180 }, { 32, -195, -180 } }) do
			buildFloodlight(hall(spot[1], 0, spot[2]), hall(0, 6, spot[3]))
		end
		local padSign = box(decor, Vector3.new(24, 3, 0.4), CFrame.new(hall(0, 4, -94.5)) * CFrame.Angles(0, math.pi, 0), YELLOW)
		surfaceText(padSign, Enum.NormalId.Front, "PLATAFORMA ATLAS V · ROVER A MARTE", DARK, YELLOW, 60)
		-- Transportador estacionado entre el banco de armado y el portón, mirando al portón (-Z)
		truckHome = CFrame.new(hall(0, 2.7, -20))
		truck, truckSeat = buildTransporter(truckHome)
	else
		box(decor, Vector3.new(26, 22, 2), CFrame.new(hall(0, 10, -94)), DARK, METAL)        -- fin del pasillo
		-- Atlas V dentro del hangar, junto al ventanal, sobre su mesa de lanzamiento
		local padPos = hall(side * 29, 0, 0)
		box(decor, Vector3.new(14, 1.5, 14), CFrame.new(padPos + Vector3.new(0, 0.75, 0)), DARK, METAL)
		box(decor, Vector3.new(14.2, 0.2, 14.2), CFrame.new(padPos + Vector3.new(0, 1.4, 0)), YELLOW, METAL)
		-- +X local hacia el centro del hangar (donde está la torre)
		rocketCF = CFrame.new(padPos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, side == -1 and 0 or math.pi, 0)
		rocket = buildAtlasV(rocketCF, decor, ROCKET.probe)
		towerArm = buildServiceTower(missionKey, rocketCF, padPos.Y, 19.1)
	end

	-- Esquinas: tanques, servidores, barriles, cajas, armarios y autoelevador
	for i = 0, 1 do
		local base = CFrame.new(hall(side * (49 - i * 7), 0, 40))
		cyl(decor, 12, 5, base * CFrame.new(0, 6, 0), WHITE)
		cyl(decor, 1.2, 5.1, base * CFrame.new(0, 8, 0), RED)
		ball(decor, 5, base * CFrame.new(0, 12, 0), WHITE)
	end
	for _, x in ipairs({ 44, 49 }) do
		box(decor, Vector3.new(4, 12, 4), CFrame.new(hall(solid * x, 6, 42)), DARK, METAL)
		for row = 1, 8 do
			box(decor, Vector3.new(2.8, 0.25, 0.1), CFrame.new(hall(solid * x, row * 1.3, 39.95)), row % 3 == 0 and RED or GREEN, NEON)
		end
	end
	buildBarrel(hall(side * 50, 0, -41), BLUE)
	buildBarrel(hall(side * 46.6, 0, -41), RED)
	buildBarrel(hall(side * 48.4, 0, -37.6), YELLOW)
	buildCrateStack(hall(side * 44, 0, -24) + Vector3.new(0, 0, 0))
	buildForklift(CFrame.new(hall(side * (missionKey == "probe" and 26 or 38), 0, missionKey == "probe" and -34 or -10))
		* CFrame.Angles(0, math.rad(25 * side), 0))
	local inward = CFrame.Angles(0, math.rad(90 * solid), 0)      -- la cara frontal mira hacia el centro
	buildLockers(CFrame.new(hall(solid * 53.5, 0, 30)) * inward)
	buildWorkbench(CFrame.new(hall(solid * 52.5, 0, -30)) * CFrame.Angles(0, math.rad(-90 * solid), 0))
	buildToolCart(CFrame.new(hall(solid * 8, 0, 24)))
	buildToolCart(CFrame.new(hall(side * 26, 0, -20)) * CFrame.Angles(0, math.rad(40), 0))

	-- Junto al ventanal: motor de repuesto (sonda) o módulo de descenso y neumáticos (rover)
	if missionKey == "probe" then
		local nozzle = CFrame.new(hall(side * 44, 0, 24))                -- motor de repuesto sobre un carro
		box(decor, Vector3.new(6, 1, 6), nozzle * CFrame.new(0, 0.8, 0), STEEL, METAL)
		cyl(decor, 3, 4.6, nozzle * CFrame.new(0, 2.8, 0), DARK, METAL)
		cyl(decor, 2.4, 2.4, nozzle * CFrame.new(0, 5.5, 0), STEEL, METAL)
	else
		local showLander = CFrame.new(hall(side * 40, 0, 6))
		cyl(decor, 4.5, 10, showLander * CFrame.new(0, 6, 0), GOLD, Enum.Material.Foil)
		cyl(decor, 3, 6, showLander * CFrame.new(0, 9.7, 0), STEEL, METAL)
		for leg = 0, 3 do
			local legCF = showLander * CFrame.Angles(0, math.rad(90 * leg + 45), 0)
			box(decor, Vector3.new(0.5, 6.5, 0.5), legCF * CFrame.new(5.6, 2.8, 0) * CFrame.Angles(0, 0, math.rad(-28)), STEEL, METAL)
			cyl(decor, 0.3, 2.4, legCF * CFrame.new(7.1, 0.15, 0), STEEL, METAL)
		end
		box(decor, Vector3.new(4, 0.4, 9), showLander * CFrame.new(0, 2, -8) * CFrame.Angles(math.rad(-22), 0, 0), STEEL, Enum.Material.DiamondPlate)
		for tire = 0, 3 do                                                -- pila de neumáticos
			cyl(decor, 1, 3, CFrame.new(hall(side * 22, 0.5 + tire, 14)), DARK)
		end
		cyl(decor, 1, 3, CFrame.new(hall(side * 25.4, 0.5, 15)), DARK)
	end

	-- Banco de integración: la nave se arma AFUERA del cohete (sonda: cerca de la torre; rover: en el centro)
	local standX = missionKey == "probe" and side * 6 or 0
	local standPos = hall(standX, 0, 0)
	cyl(decor, 2, 7.5, CFrame.new(standPos + Vector3.new(0, 1, 0)), DARK, METAL)
	cyl(decor, 0.2, 7.7, CFrame.new(standPos + Vector3.new(0, 1.95, 0)), YELLOW, NEON).Transparency = 0.4
	local standSign = box(decor, Vector3.new(5.5, 1, 0.2), CFrame.new(standPos + Vector3.new(0, 1, -3.9)) * CFrame.Angles(math.rad(-10), 0, 0), WHITE)
	surfaceText(standSign, Enum.NormalId.Front, "BANCO DE INTEGRACIÓN", NAVY, WHITE, 40)

	-- Brazos robóticos del piso y mesas de transferencia, a los dos lados del banco
	local arms = {
		{ name = missionKey .. "-BrazoA", base = standPos + Vector3.new(-8, 0, -9), table = missionKey .. "-MesaA", tablePos = standPos + Vector3.new(-14, 0, -15) },
		{ name = missionKey .. "-BrazoB", base = standPos + Vector3.new(8, 0, 9), table = missionKey .. "-MesaB", tablePos = standPos + Vector3.new(14, 0, 15) },
	}
	for _, arm in ipairs(arms) do
		buildRoboticArm(arm.name, arm.base)
		buildTransferTable(arm.table, arm.tablePos)
	end
	for _, x in ipairs({ -32, 0, 32 }) do
		for _, z in ipairs({ -22, 22 }) do
			buildHighBayLamp(hall(x, 40, z), hall(0, HEIGHT, 0).Y)
		end
	end

	-- Una sala por subsistema ---------------------------------------------------
	for index, sub in ipairs(mission.subsystems) do
		local doorX, dir = ROOMS[index].x, ROOMS[index].dir
		local zc = dir * 61
		local rot = dir == 1 and CFrame.new() or CFrame.Angles(0, math.pi, 0)      -- las piezas miran hacia el hangar
		local face = dir == 1 and Enum.NormalId.Front or Enum.NormalId.Back

		box(decor, Vector3.new(30, 2, 28), CFrame.new(hall(doorX, -1, zc)), NAVY, METAL)
		box(decor, Vector3.new(34, 2, 30), CFrame.new(hall(doorX, 17, zc)), DARK, METAL)
		box(decor, Vector3.new(34, 16, 2), CFrame.new(hall(doorX, 8, dir * 76)), DARK, METAL)
		box(decor, Vector3.new(2, 16, 28), CFrame.new(hall(doorX - 16, 8, zc)), DARK, METAL)
		box(decor, Vector3.new(2, 16, 28), CFrame.new(hall(doorX + 16, 8, zc)), DARK, METAL)
		box(decor, Vector3.new(20, 0.3, 1.2), CFrame.new(hall(doorX, 15.8, zc)), WHITE, NEON)
		light(hall(doorX, 12, zc), 42, 1.8)

		local board = box(decor, Vector3.new(26, 4, 0.4), CFrame.new(hall(doorX, 12.5, dir * 74.7)), BLUE)
		surfaceText(board, face, index .. ". " .. sub.title, WHITE, BLUE)
		local doorBoard = box(decor, Vector3.new(16, 3.4, 0.4), CFrame.new(hall(doorX, 14.2, dir * 44.6)), WHITE)
		surfaceText(doorBoard, face, "SALA " .. index .. " · " .. sub.title, NAVY, WHITE)
		local floorMark = box(decor, Vector3.new(8, 0.1, 8), CFrame.new(hall(doorX, 0.05, dir * 38)) * rot, BLUE)
		surfaceText(floorMark, Enum.NormalId.Top, tostring(index), WHITE, BLUE)

		-- Decorado de la sala
		buildWorkbench(CFrame.new(hall(doorX + 13, 0, zc)) * CFrame.Angles(0, math.rad(-90), 0))
		buildToolCart(CFrame.new(hall(doorX - 12.5, 0, dir * 52)))
		buildBarrel(hall(doorX - 13, 0, dir * 72), index % 2 == 0 and RED or BLUE)
		buildBeacon(hall(doorX, 15.3, dir * 49))

		-- Comparador A/B de la sala (lo actualiza refreshScreens con los totales del jugador)
		local cmpCF = CFrame.new(hall(doorX - 14.9, 8.5, dir * 61)) * CFrame.Angles(0, math.rad(-90), 0)
		box(decor, Vector3.new(15, 8.6, 0.4), cmpCF * CFrame.new(0, 0, 0.25), DARK, METAL)
		screen(missionKey .. "-cmp-" .. index, Vector3.new(14.4, 8, 0.1), cmpCF, Enum.NormalId.Front, WHITE, 40)

		for _, code in ipairs({ "A", "B" }) do
			local option = sub[code]
			local px = doorX + (code == "A" and -6.5 or 6.5)
			local color = code == "A" and BLUE_HI or RED
			local pedestal = box(decor, Vector3.new(7, 1.5, 7), CFrame.new(hall(px, 0.75, dir * 67)), DARK, METAL)
			box(decor, Vector3.new(7.1, 0.4, 7.1), CFrame.new(hall(px, 1.1, dir * 67)), color)

			local pieceName = missionKey .. "-" .. sub.key .. "-" .. code
			local model = make("Model", { Name = pieceName }, piecesFolder)
			local base = CFrame.new(hall(px, 1.5, dir * 67)) * rot
			BUILDERS[pieceName](model, base)
			model.WorldPivot = base
			PIECES[pieceName] = model
			Campus.priceTag(decor, hall(px, 9, dir * 67), option, color, code)

			-- Ficha inclinada delante de la pieza
			box(decor, Vector3.new(0.5, 2, 0.5), CFrame.new(hall(px, 1, dir * 59.4)), STEEL, METAL)
			local card = box(decor, Vector3.new(9, 5, 0.3), CFrame.new(hall(px, 2.9, dir * 59)) * rot * CFrame.Angles(math.rad(50), 0, 0), color)
			surfaceText(card, Enum.NormalId.Front,
				string.format("[%s] %s\n$%d M · %d kg\n%s", code, option.name, option.cost, option.mass, option.note),
				WHITE, SCREEN_BG, 60)

			prompt(pedestal, "Agarrar pieza " .. code, option.name, 14).Triggered:Connect(function(player)
				local state = states[player]
				if not state or state.phase ~= "hangar" or state.mission ~= missionKey or state.busy then
					return
				end
				local placed = placedCount(state)
				if index > placed + 1 then
					say(player, string.format("Todavía no. Primero va la SALA %d: %s.", placed + 1, mission.subsystems[placed + 1].title))
					return
				end
				if carryPiece(player, state, index, code) then
					say(player, "Llevás: " .. option.name .. ". Colocala en la nave.")
					remote:FireClient(player, "tip", Educativo.TIPS[pieceName] or "")
					refresh(player)
				end
			end)
		end
	end

	-- La nave se arma arriba del banco de integración
	local standCF = CFrame.new(standPos + Vector3.new(0, 2, 0))
	if missionKey == "rover" then
		standCF = standCF * CFrame.Angles(0, math.rad(90), 0)      -- el frente del rover apunta al portón
	end
	local dock = make("Part", {
		Name = "PlataformaDeArmado", Anchored = true, CanCollide = false, Transparency = 1,
		Size = Vector3.new(2, 2, 2), Position = standPos + Vector3.new(0, 4, 0),
	}, decor)
	prompt(dock, "Entregar al brazo robótico", "Plataforma de ensamblaje", 22).Triggered:Connect(function(player)
		installPiece(player, missionKey)
	end)
	local removePrompt = prompt(dock, "Retirar última pieza", "Plataforma de ensamblaje", 22)
	removePrompt.KeyboardKeyCode = Enum.KeyCode.R
	removePrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	removePrompt.HoldDuration = 0.8
	removePrompt.UIOffset = Vector2.new(0, 90)
	removePrompt.Triggered:Connect(function(player)
		removePiece(player, missionKey)
	end)

	-- Monitor grande del hangar, en la pared ciega
	box(decor, Vector3.new(30, 18, 0.6), CFrame.new(hall(solid * 54.6, 16, 0)) * inward, DARK, METAL)
	screen(missionKey .. "-hall", Vector3.new(28, 16, 0.2), CFrame.new(hall(solid * 54.2, 16, 0)) * inward, Enum.NormalId.Front, WHITE, 64)

	-- Pantalla de especificaciones técnicas (energía, propulsión, enlace), sobre los armarios
	box(decor, Vector3.new(15, 11, 0.6), CFrame.new(hall(solid * 54.6, 21, 30)) * inward, DARK, METAL)
	screen(missionKey .. "-spec", Vector3.new(14, 10, 0.2), CFrame.new(hall(solid * 54.2, 21, 30)) * inward, Enum.NormalId.Front, Color3.fromRGB(120, 220, 255), 48)

	-- Consola de lanzamiento
	local consoleCF = CFrame.new(hall(solid * 24, 0, 0)) * inward
	box(decor, Vector3.new(12, 3.4, 3), consoleCF * CFrame.new(0, 1.7, 0), DARK, METAL)
	local consoleTop = box(decor, Vector3.new(12, 0.4, 3.4), consoleCF * CFrame.new(0, 3.6, 0) * CFrame.Angles(math.rad(-18), 0, 0), RED, NEON)
	local consoleSign = box(decor, Vector3.new(10, 3.4, 0.3), consoleCF * CFrame.new(0, 6.6, -1.2), SCREEN_BG, NEON)
	surfaceText(consoleSign, Enum.NormalId.Back, "REVISIÓN CRÍTICA\nY LANZAMIENTO", WHITE, RED, 70)

	-- Banco de pruebas del hangar (decorado): las pruebas se configuran en el Laboratorio de Ingeniería del atrio
	local benchCF = CFrame.new(hall(solid * 38, 0, 20)) * inward
	box(decor, Vector3.new(16, 0.6, 12), benchCF * CFrame.new(0, 0.3, 0), DARK, METAL)
	for _, dz in ipairs({ -6, 6 }) do
		box(decor, Vector3.new(16.2, 0.2, 0.6), benchCF * CFrame.new(0, 0.65, dz), YELLOW, NEON)
	end
	box(decor, Vector3.new(7, 0.5, 8), benchCF * CFrame.new(-3, 1.2, 0) * CFrame.Angles(0, 0, math.rad(14)), STEEL, Enum.Material.DiamondPlate)
	box(decor, Vector3.new(4, 1.2, 8), benchCF * CFrame.new(5, 1.2, 0), STEEL, Enum.Material.Slate)
	for _, dx in ipairs({ -7, 7 }) do
		box(decor, Vector3.new(0.5, 8, 0.5), benchCF * CFrame.new(dx, 4, 6.2), STEEL, METAL)
	end
	local labSign = box(decor, Vector3.new(14, 3, 0.4), benchCF * CFrame.new(0, 8, 6.2), WHITE)
	surfaceText(labSign, Enum.NormalId.Front, "PRUEBAS ▶ LABORATORIO DE INGENIERÍA (ATRIO)", NAVY, WHITE, 60)

	-- SALA DE CONTROL (56 x 44 de planta, 22 de alto) --------------------------
	-- Pared del frente: gráfico de vuelo, pantalla gigante y cámara remota.
	-- Escritorio del jugador con asiento y 3 monitores; detrás, puestos de apoyo.
	buildRoomShell(room, 56, 44, 22)
	box(decor, Vector3.new(2, 22, 44), CFrame.new(room(-29, 11, 0)), DARK, METAL)
	box(decor, Vector3.new(2, 22, 44), CFrame.new(room(29, 11, 0)), DARK, METAL)
	for _, x in ipairs({ -16, 16 }) do
		light(room(x, 17, -6), 50, 1.3)
	end
	light(room(0, 15, 12), 40, 1.1)
	box(decor, Vector3.new(40, 0.3, 1.6), CFrame.new(room(0, 21.8, -6)), WHITE, NEON)
	box(decor, Vector3.new(56, 0.2, 0.6), CFrame.new(room(0, 0.1, 13)), BLUE_HI, NEON)            -- línea de luz al pie de las pantallas
	box(decor, Vector3.new(52, 1, 6), CFrame.new(room(0, 0.5, -17)), NAVY, METAL)                  -- tarima de la fila de atrás

	local roomSign = box(decor, Vector3.new(36, 2.6, 0.4), CFrame.new(room(0, 20.3, 21.6)), WHITE)
	surfaceText(roomSign, Enum.NormalId.Front, "SALA DE CONTROL · " .. mission.short, NAVY, WHITE)

	-- Pantalla gigante central
	box(decor, Vector3.new(26, 14.4, 0.6), CFrame.new(room(0, 11.4, 21.5)), DARK, METAL)
	screen(missionKey .. "-main", Vector3.new(24.8, 13.2, 0.2), CFrame.new(room(0, 11.4, 21.1)), Enum.NormalId.Front, WHITE, 60)
	local alertLamp = make("Part", {
		Name = missionKey .. "-alerta", Anchored = true, Size = Vector3.new(26, 0.5, 0.4), Color = RED, Material = NEON,
		CFrame = CFrame.new(room(0, 18.8, 21.1)), Transparency = 0.85,
	}, consolesFolder)
	make("PointLight", { Range = 22, Brightness = 0, Color = RED, Shadows = false }, alertLamp)

	-- Laterales inclinados hacia el centro: gráfico de vuelo (izq.) y cámara remota (der.)
	local leftCF = CFrame.new(room(-20.5, 11, 19.8)) * CFrame.Angles(0, math.rad(-22), 0)
	local rightCF = CFrame.new(room(20.5, 11, 19.8)) * CFrame.Angles(0, math.rad(22), 0)
	box(decor, Vector3.new(15.6, 10, 0.5), leftCF * CFrame.new(0, 0, 0.35), DARK, METAL)
	box(decor, Vector3.new(15.6, 10, 0.5), rightCF * CFrame.new(0, 0, 0.35), DARK, METAL)
	if missionKey == "probe" then
		buildGmatScreen(Vector3.new(14.8, 9.2, 0.2), leftCF)
	else
		buildProfileScreen(Vector3.new(14.8, 9.2, 0.2), leftCF)
	end
	make("Part", {
		Name = missionKey .. "-camara", Anchored = true, Size = Vector3.new(14.8, 9.2, 0.2), Color = SCREEN_BG, Material = NEON,
		CFrame = rightCF,
	}, consolesFolder)
	for _, info in ipairs({ { leftCF, "GRÁFICO DE VUELO" }, { rightCF, "CÁMARA REMOTA" } }) do
		local tag = box(decor, Vector3.new(8, 1, 0.2), info[1] * CFrame.new(0, 5.6, 0.1), BLUE)
		surfaceText(tag, Enum.NormalId.Front, info[2], WHITE, BLUE, 40)
	end

	-- Escritorio del jugador
	local deskZ = 5
	box(decor, Vector3.new(17, 0.5, 4.6), CFrame.new(room(0, 3, deskZ)), WHITE)
	box(decor, Vector3.new(17.1, 0.15, 4.7), CFrame.new(room(0, 3.3, deskZ)), Color3.fromRGB(40, 46, 60), METAL)
	for _, x in ipairs({ -8.2, 8.2 }) do
		box(decor, Vector3.new(0.5, 2.8, 4.4), CFrame.new(room(x, 1.4, deskZ)), DARK, METAL)
	end
	box(decor, Vector3.new(16, 2.4, 0.3), CFrame.new(room(0, 1.6, deskZ + 2.1)), DARK, METAL)
	box(decor, Vector3.new(16, 0.15, 0.2), CFrame.new(room(0, 3.05, deskZ - 2.35)), BLUE_HI, NEON)
	-- teclado, mouse, auriculares, taza, carpeta y teléfono
	box(decor, Vector3.new(3.2, 0.15, 1.1), CFrame.new(room(0, 3.45, deskZ - 1.2)), DARK)
	for i = 0, 3 do
		box(decor, Vector3.new(2.9, 0.05, 0.12), CFrame.new(room(0, 3.55, deskZ - 1.55 + i * 0.24)), STEEL)
	end
	box(decor, Vector3.new(0.5, 0.15, 0.8), CFrame.new(room(2.4, 3.45, deskZ - 1.2)), DARK)
	cyl(decor, 0.6, 0.55, CFrame.new(room(-6.6, 3.7, deskZ - 1.0)), WHITE)
	cyl(decor, 0.08, 0.45, CFrame.new(room(-6.6, 4.0, deskZ - 1.0)), Color3.fromRGB(70, 40, 20))
	box(decor, Vector3.new(1.6, 0.1, 2.1), CFrame.new(room(5.6, 3.42, deskZ - 0.8)) * CFrame.Angles(0, math.rad(12), 0), Color3.fromRGB(230, 220, 190))
	box(decor, Vector3.new(1.0, 0.3, 1.2), CFrame.new(room(7.2, 3.5, deskZ + 0.8)), DARK)
	tube(decor, 1.6, 0.25, CFrame.new(room(-3.2, 3.55, deskZ + 0.4)), DARK)                        -- auriculares
	ball(decor, 0.6, CFrame.new(room(-4.0, 3.6, deskZ + 0.4)), DARK)
	ball(decor, 0.6, CFrame.new(room(-2.4, 3.6, deskZ + 0.4)), DARK)

	-- Tres monitores: telemetría (izq.), consola táctil (centro), enlace e historial (der.)
	-- El pie y el poste van DETRÁS de la pantalla (antes el poste asomaba delante y tapaba la consola)
	local function monitorStand(x, yaw)
		local base = CFrame.new(room(x, 3.4, deskZ + 1.9)) * CFrame.Angles(0, math.rad(yaw), 0)
		box(decor, Vector3.new(1.4, 0.15, 0.8), base, DARK, METAL)
		box(decor, Vector3.new(0.3, 1.6, 0.3), base * CFrame.new(0, 0.85, 0.1), STEEL, METAL)
		return CFrame.new(room(x, 5.6, deskZ + 1.4)) * CFrame.Angles(0, math.rad(yaw), 0)
	end
	local leftMon = monitorStand(-6.2, -24)
	local midMon = monitorStand(0, 0)
	local rightMon = monitorStand(6.2, 24)
	for _, cf in ipairs({ leftMon, midMon, rightMon }) do
		box(decor, Vector3.new(cf == midMon and 6.8 or 5.6, cf == midMon and 4.2 or 3.6, 0.3), cf * CFrame.new(0, 0, 0.2), DARK, METAL)
	end
	screen(missionKey .. "-stats", Vector3.new(5.2, 3.2, 0.1), leftMon * CFrame.new(0, 0, 0.02), Enum.NormalId.Front, GREEN, 40)
	screen(missionKey .. "-log", Vector3.new(5.2, 3.2, 0.1), rightMon * CFrame.new(0, 0, 0.02), Enum.NormalId.Front, WHITE, 40)
	make("Part", {
		Name = missionKey .. "-consola", Anchored = true, Size = Vector3.new(6.4, 3.8, 0.1), Color = SCREEN_BG, Material = NEON,
		CFrame = midMon * CFrame.new(0, 0, 0.02),
	}, consolesFolder)

	-- Silla: el Seat sienta al jugador mirando a las pantallas
	local seatPos = room(0, 1.7, 0.6)
	local seat = make("Seat", {
		Name = missionKey .. "-Asiento", Anchored = true, Size = Vector3.new(2.4, 0.5, 2.4), Color = BLUE, Material = PLASTIC,
		CFrame = CFrame.lookAt(seatPos, seatPos + Vector3.new(0, 0, 1)), TopSurface = Enum.SurfaceType.Smooth,
	}, decor)
	cyl(decor, 1.2, 0.45, CFrame.new(room(0, 0.9, 0.6)), STEEL, METAL)
	for i = 0, 4 do
		local a = math.rad(72 * i)
		box(decor, Vector3.new(0.3, 0.2, 1.4), CFrame.new(room(math.sin(a) * 0.7, 0.2, 0.6 + math.cos(a) * 0.7)) * CFrame.Angles(0, a, 0), DARK, METAL)
	end
	box(decor, Vector3.new(2.4, 2.8, 0.4), CFrame.new(room(0, 3.4, -0.75)) * CFrame.Angles(math.rad(-8), 0, 0), BLUE, PLASTIC)
	for _, sx in ipairs({ -1.25, 1.25 }) do
		box(decor, Vector3.new(0.25, 0.25, 1.8), CFrame.new(room(sx, 2.7, 0.6)), DARK, METAL)
	end
	local sitPrompt = prompt(seat, "Sentarse en el puesto", "Consola de operaciones", 9)

	-- Puestos de apoyo detrás (decorado con funciones reales de un centro de control)
	local roles = { { -4, -9, "FIDO\nTrayectoria" }, { 9, -9, "EECOM\nEnergía" }, { 9, -17, "GNC\nGuiado" }, { 22, -17, "DSN\nRed del espacio profundo" } }
	for _, role in ipairs(roles) do
		local y = role[2] < -12 and 1 or 0
		buildComputer(CFrame.new(room(role[1], y, role[2])) * CFrame.Angles(0, math.pi, 0), role[3])
	end
	buildDiorama(missionKey, room(-19, 0, -14))
	box(decor, Vector3.new(4, 12, 4), CFrame.new(room(25.5, 6, 2)), DARK, METAL)
	for row = 1, 8 do
		box(decor, Vector3.new(0.1, 0.25, 2.8), CFrame.new(room(23.45, row * 1.3, 2)), row % 3 == 0 and RED or GREEN, NEON)
	end
	-- Panel de instrucciones (pared izquierda)
	local help = box(decor, Vector3.new(0.3, 8, 13), CFrame.new(room(-27.7, 10, 4)), SCREEN_BG, NEON)
	surfaceText(help, Enum.NormalId.Right, "CÓMO OPERAR\n\n1. Sentate en el puesto (E).\n2. La consola del centro es táctil:\n   tocá los botones con el mouse.\n3. V alterna escritorio / pantallas.\n4. Saltar (espacio) te levanta.\n\nCada comando tarda el retraso\nde señal en llegar a la nave.", GREEN, SCREEN_BG, 40)
	buildBeacon(room(-26, 20, 20))
	buildBeacon(room(26, 20, 20))
	sitPrompt.Triggered:Connect(function(player)
		sitAtDesk(player)
	end)

	COMPLEX[missionKey] = {
		standCF = standCF,
		spawnCF = CFrame.lookAt(hall(0, 3, -32), hall(0, 3, 30)),
		flightCF = CFrame.lookAt(room(0, 3, -4), room(0, 3, 20)),
		parkCF = CFrame.new(hall(solid * 50, 3, -40)),
		menuCamera = CFrame.lookAt(hall(solid * 46, 28, -40), hall(side * 8, 10, 6)),
		consoleTop = consoleTop,
		door = door,
		roof = roofParts,
		seat = seat,
		arms = arms,
		rocket = rocket, rocketCF = rocketCF, towerArm = towerArm,
		payloadCF = rocketCF * CFrame.new(0, PAYLOAD_Y * ROCKET[missionKey].scale, 0) * (missionKey == "rover" and CFrame.Angles(0, math.rad(90), 0) or CFrame.new()),
		doorHome = door:GetPivot(),
		truck = truck, truckSeat = truckSeat, truckHome = truckHome, truckSpeed = 0,
		dropCF = parkSpot and CFrame.new(parkSpot + Vector3.new(0, 2.7, 0)) or nil,     -- donde se deja el transportador
		origin = origin,
	}
	if truckSeat then
		prompt(truckSeat, "Manejar el transportador", "Transportador del rover", 10).Triggered:Connect(function(player)
			local state = states[player]
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if state and state.phase == "transport" and humanoid and not truckSeat.Disabled and not truckSeat.Occupant then
				truckSeat:Sit(humanoid)
				say(player, "W/S: avanzar y frenar · A/D: girar. Salí por el PORTÓN 1 y dejá el rover en la ZONA DE ENTREGA, junto al Atlas V.")
			end
		end)
	end
end

buildComplex("probe")
buildComplex("rover")

-- Atrio central que une los dos hangares (ver módulo Campus)
Campus.build({
	world = world, decor = decor, make = make, box = box, tube = tube, cyl = cyl, ball = ball,
	surfaceText = surfaceText, light = light, METAL = METAL, NEON = NEON, PLASTIC = PLASTIC,
	screen = screen, screensFolder = screensFolder, consolesFolder = consolesFolder,
	C = {
		RED = RED, WHITE = WHITE, BLUE = BLUE, BLUE_HI = BLUE_HI, NAVY = NAVY, DARK = DARK, STEEL = STEEL,
		GREEN = GREEN, GOLD = GOLD, YELLOW = YELLOW, ORANGE = ORANGE, SCREEN_BG = SCREEN_BG,
	},
})

-- v8: exterior del centro espacial (suelo, mar, rejas, edificios de la NASA, banderas, palmeras)
Campus.buildExterior({
	world = world, make = make, box = box, cyl = cyl, ball = ball, surfaceText = surfaceText,
	drawFlag = drawFlag, drawNasaLogo = drawNasaLogo, METAL = METAL, NEON = NEON,
	C = { RED = RED, WHITE = WHITE, BLUE = BLUE, NAVY = NAVY, DARK = DARK, STEEL = STEEL, GOLD = GOLD, YELLOW = YELLOW },
})

-- Punto de aparición dentro del hangar de la sonda; se anulan los demás
for _, item in ipairs(workspace:GetDescendants()) do
	if item:IsA("SpawnLocation") then
		item.Enabled = false
	end
end
make("SpawnLocation", {
	Name = "AparicionHangar", Anchored = true, Size = Vector3.new(6, 1, 6), Transparency = 1, CanCollide = false,
	CFrame = COMPLEX.probe.parkCF * CFrame.new(0, -3.4, 0), Neutral = true, Duration = 0,
}, world)

-- Las maquetas giran sin parar
local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	for _, item in ipairs(dioramas) do
		item.model:PivotTo(item.frame * CFrame.Angles(0, clock * item.speed, 0) * CFrame.new(item.radius, 0, 0))
	end
end)

---------------------------------------------------------------------------
-- 9b. LABORATORIO DE INGENIERÍA: pruebas configurables (consola en el atrio, ala este)
---------------------------------------------------------------------------
local function labRun(player, data)
	local state = states[player]
	if not state or state.phase ~= "hangar" or state.busy or type(data) ~= "table" then
		return
	end
	if os.clock() < state.labCooldown then
		return
	end
	state.labCooldown = os.clock() + 1
	local prueba = Ingenieria.buscar(state.mission, data.test)
	if not prueba then
		return
	end
	if placedCount(state) < #MISSIONS[state.mission].subsystems then
		remote:FireClient(player, "labResult", { error = "Primero armá la nave completa: el laboratorio ensaya tu diseño real." })
		return
	end
	local values = Ingenieria.ajustar(prueba, data.values)
	local r, mass, fuel = designSummary(state)
	local ok, res = pcall(Ingenieria.ejecutar, state.mission, prueba.clave, values,
		{ mods = state.mods, masa = mass, propelente = fuel, resumen = r }, Educativo, Componentes)
	if not ok then
		warn("[ControlDeMision] Error en la prueba " .. prueba.clave .. ": " .. tostring(res))
		remote:FireClient(player, "labResult", { error = "La prueba falló por un error interno. Mirá la ventana Output." })
		return
	end
	state.labDone[prueba.clave] = true
	local verdicts = { ok = "✓ APROBADA", riesgo = "~ CON RIESGO", falla = "✗ NO APROBADA" }
	setScreen(player, "lab-report", res.titulo .. "  ·  " .. verdicts[res.veredicto] .. "\n\n" .. table.concat(res.lineas, "\n")
		.. string.format("\n\nPruebas hechas sobre este diseño: %d de 3", labCount(state)))
	remote:FireClient(player, "labResult", { test = prueba.clave, veredicto = res.veredicto, visual = res.visual, count = labCount(state) })
	say(player, string.format("Prueba de %s: %s. Informe en la pantalla del laboratorio.", prueba.nombre:lower(), verdicts[res.veredicto]))
	refresh(player)
end

---------------------------------------------------------------------------
-- 10. LANZAMIENTO: revisión, cinemática y traspaso a la sala de control
---------------------------------------------------------------------------
local flyMission       -- se define más abajo (la usan launch y la llegada del transportador)

local function launch(player, missionKey)
	local state = states[player]
	if not state or state.phase ~= "hangar" or state.mission ~= missionKey or state.busy then
		return
	end
	local mission = MISSIONS[missionKey]
	local total = #mission.subsystems
	local placed = placedCount(state)
	if placed < total then
		say(player, string.format("Faltan piezas: van %d de %d. Sigue la %d: %s.", placed, total, placed + 1, mission.subsystems[placed + 1].title))
		return
	end
	local cost, mass = totals(state)
	if cost > mission.budget or mass > mission.massMax then
		local reasons = {}
		if cost > mission.budget then
			table.insert(reasons, "presupuesto excedido en $" .. (cost - mission.budget) .. " M")
		end
		if mass > mission.massMax then
			table.insert(reasons, string.format("masa excedida en %d kg (%s)", mass - mission.massMax, mission.massNote or "límite"))
		end
		say(player, "Lanzamiento rechazado: " .. table.concat(reasons, " y ") .. ". Cambiá alguna pieza.")
		return
	end

	state.busy = true
	dropCarried(state)
	state.phase = "launching"
	refresh(player)
	setFrozen(player, true)
	local complex = COMPLEX[missionKey]

	if missionKey == "probe" then
		-- La sonda se armó afuera: el brazo de la torre la levanta del banco y la mete en la cofia
		setPhase(player, "BC", "REVISIÓN APROBADA", "Integración en el Atlas V")
		say(player, "Diseño aprobado. El brazo de la torre mete la sonda en la cofia del Atlas V.")
		if moveVehicleWithArm(player, state, complex.towerArm.name, complex.payloadCF, complex.rocket) then
			flyMission(player, state)
		end
		return
	end

	-- ROVER: los brazos lo cargan en el transportador y el jugador lo lleva hasta el Atlas V
	setPhase(player, "BC", "REVISIÓN APROBADA", "Carga en el transportador")
	say(player, "Diseño aprobado. El brazo carga el rover en el transportador.")
	local bedCF = complex.truck:GetPivot() * ROVER_ON_BED
	if not moveVehicleWithArm(player, state, missionKey .. "-BrazoA", bedCF, nil) then
		return
	end
	state.phase = "transport"
	state.busy = false
	state.drive = nil
	complex.truckSeat.Disabled = false
	complex.door:PivotTo(complex.doorHome + Vector3.new(0, 20, 0))       -- se abre el portón
	setFrozen(player, false)
	setPhase(player, "BC", "TRANSPORTE AL ATLAS V", "Llevá el rover a la plataforma")
	say(player, "Subite al transportador (E en la cabina) y llevá el rover a la ZONA DE ENTREGA, junto al Atlas V.")
	refresh(player)
end

-- Cinemática de lanzamiento y traspaso a la sala de control (la nave ya está dentro del Atlas V)
flyMission = function(player, state)
	local missionKey = state.mission
	local mission = MISSIONS[missionKey]
	local complex = COMPLEX[missionKey]
	local _, mass = totals(state)
	state.phase = "launching"
	state.busy = true
	state.blackout = false
	setFrozen(player, true)
	local calls = {}
	for _, sub in ipairs(mission.subsystems) do
		table.insert(calls, string.format("%s · %s: GO", sub.title, sub[state.mods[sub.key]].name))
	end
	setPhase(player, "BC", "LISTOS PARA EL LANZAMIENTO", "Atlas V")
	pcall(function()                         -- que el cohete esté cargado en el cliente
		player:RequestStreamAroundAsync(complex.rocketCF.Position)
	end)
	remote:FireClient(player, "cinematic", {
		kind = missionKey, vehicle = state.vehicle, stand = complex.rocketCF, calls = calls,
		roof = missionKey == "probe" and complex.roof or nil, rocket = complex.rocket, rocketCF = complex.rocketCF,
	})

	-- El cliente anima todo y avisa cuando la pantalla está en negro (máx. 90 s de margen)
	local deadline = os.clock() + 90
	while not state.blackout and os.clock() < deadline and states[player] == state do
		task.wait(0.1)
	end
	if states[player] ~= state then
		return
	end

	state.phase = "flight"
	state.event = 1
	state.flightStart = os.clock()
	state.history = {}
	if missionKey == "probe" then
		state.fuel = fuelFor(mass)
		state.maxFuel = state.fuel
	end
	logEvent(player, "ENLACE ESTABLECIDO · " .. mission.short)
	teleport(player, complex.flightCF)
	remote:FireClient(player, "arrive", complex.flightCF, mission.delay)
	setPhase(player, "DE", "FASE D/E · OPERACIONES", "Sala de control")
	setScreen(player, missionKey .. "-main", card("📡", "azul", "CONECTANDO CON LA NAVE", "Esperando la primera señal…"))
	sendConsole(player, { mission = missionKey, mode = "wait", text = "Estableciendo enlace con la nave…" })
	refresh(player)
	task.wait(7)                         -- dura lo mismo que el travelling de llegada
	if states[player] ~= state then
		return
	end
	setFrozen(player, false)
	sitAtDesk(player)
	say(player, "Estás en tu puesto. Operá la misión desde la consola táctil del escritorio.")
	showEvent(player)
end

for missionKey, complex in pairs(COMPLEX) do
	local action = missionKey == "probe" and "Revisión crítica y meter en el Atlas V" or "Revisión crítica y cargar en el transportador"
	prompt(complex.consoleTop, action, "Consola de lanzamiento").Triggered:Connect(function(player)
		launch(player, missionKey)
	end)
end

---------------------------------------------------------------------------
-- 10b. TRANSPORTADOR DEL ROVER: lo maneja el jugador del hangar a la plataforma del Atlas V
--      El asiento de vehículo no tiene ruedas con física: el servidor mueve el modelo (anclado)
--      con lo que el cliente informa de W/S y A/D. Solo puede andar por el hangar, el pasillo y
--      la plataforma exterior, sin atravesar el banco ni el cohete.
---------------------------------------------------------------------------
local DRIVE = { speed = 18, accel = 14, turn = 1.3 }
local DRIVE_AREAS = { { -46, 46, -38, 40 }, { -6, 6, -100, -36 }, { -40, 40, -216, -96 } }    -- x1, x2, z1, z2 (hangar)
local DRIVE_BLOCKS = { { -20, 20, -18, 18 }, { -16, 16, -196, -164 } }                         -- banco, brazos y plataforma

local function insideRect(rel, r)
	return rel.X >= r[1] and rel.X <= r[2] and rel.Z >= r[3] and rel.Z <= r[4]
end

local function canDrive(complex, position)
	local rel = position - complex.origin
	local inside = false
	for _, r in ipairs(DRIVE_AREAS) do
		if insideRect(rel, r) then
			inside = true
			break
		end
	end
	if not inside then
		return false
	end
	for _, r in ipairs(DRIVE_BLOCKS) do
		if insideRect(rel, r) then
			return false
		end
	end
	return true
end

-- Llegó a la zona de entrega: se estaciona solo, baja al jugador y el brazo de la torre carga el rover
local function arriveAtPad(player, state)
	local complex = COMPLEX.rover
	state.phase = "launching"
	state.busy = true
	complex.truckSpeed = 0
	complex.truckSeat.Disabled = true
	complex.truck:PivotTo(complex.dropCF)
	state.vehicle:PivotTo(complex.dropCF * ROVER_ON_BED)
	task.spawn(function()
		task.wait(0.3)
		if states[player] ~= state then
			return
		end
		teleport(player, CFrame.lookAt(complex.dropCF.Position + Vector3.new(-6, 1, 16), complex.rocketCF.Position + Vector3.new(0, 20, 0)))
		setFrozen(player, true)
		setPhase(player, "BC", "INTEGRACIÓN EN EL ATLAS V", "Brazo de la torre")
		say(player, "¡Llegaste! El brazo de la torre mete el rover en la cofia del Atlas V.")
		if moveVehicleWithArm(player, state, complex.towerArm.name, complex.payloadCF, complex.rocket) then
			flyMission(player, state)
		end
	end)
end

local function driveStep(player, state, complex, dt)
	local seat = complex.truckSeat
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local throttle, steer = 0, 0
	local input = state.drive
	if humanoid and seat.Occupant == humanoid and input and os.clock() - input.t < 0.6 then
		throttle, steer = input.throttle, input.steer
	end
	local v = complex.truckSpeed
	v += math.clamp(throttle * DRIVE.speed - v, -DRIVE.accel * dt, DRIVE.accel * dt)
	local cf = complex.truck:GetPivot()
	local turn = -steer * DRIVE.turn * dt * (v < -0.5 and -1 or 1)
	local turned = cf * CFrame.Angles(0, turn, 0)
	local nextCF = turned + turned.LookVector * v * dt
	if not canDrive(complex, nextCF.Position) then
		nextCF = canDrive(complex, turned.Position) and turned or cf
		v = 0
	end
	complex.truckSpeed = v
	if nextCF ~= cf then
		complex.truck:PivotTo(nextCF)
		state.vehicle:PivotTo(nextCF * ROVER_ON_BED)
	end
	if (nextCF.Position - complex.dropCF.Position).Magnitude < 6 and math.abs(v) < 3 then
		arriveAtPad(player, state)
	end
end

RunService.Heartbeat:Connect(function(dt)
	local complex = COMPLEX.rover
	if not complex or not complex.truck then
		return
	end
	for player, state in pairs(states) do
		if state.phase == "transport" and state.mission == "rover" and state.vehicle then
			driveStep(player, state, complex, dt)
		end
	end
end)

---------------------------------------------------------------------------
-- 11. JUGADORES, MENÚ Y COMANDOS DEL CLIENTE (todos validados acá)
---------------------------------------------------------------------------
local clientReady = {}

local function warnMissingClient(player)
	warn("[ControlDeMision] El LocalScript de " .. player.Name .. " no respondió. Revisá StarterPlayer > StarterPlayerScripts.")
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui or playerGui:FindFirstChild("AvisoControlDeMision") then
		return
	end
	local gui = make("ScreenGui", { Name = "AvisoControlDeMision", ResetOnSpawn = false }, playerGui)
	make("TextLabel", {
		Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 420, 0, 110),
		BackgroundColor3 = RED, BorderSizePixel = 0, TextColor3 = WHITE, TextWrapped = true,
		Font = Enum.Font.GothamBold, TextSize = 16,
		Text = "FALTA EL SCRIPT DEL JUGADOR.\nEl menú no puede aparecer. Revisá que ControlDeMisionCliente sea un LocalScript dentro de StarterPlayer > StarterPlayerScripts.",
	}, gui)
	setFrozen(player, false)
end

local ACTIONS = {}

ACTIONS.ready = function(player, state)
	clientReady[player] = true
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local notice = playerGui and playerGui:FindFirstChild("AvisoControlDeMision")
	if notice then
		notice:Destroy()
	end
	if state.phase == "menu" then
		goToMenu(player, true)
	end
end

ACTIONS.selectMission = function(player, state, value)
	if state.phase == "menu" and (value == "probe" or value == "rover") then
		goToHangar(player, value, nil)
		say(player, "Entrá a la SALA 1, agarrá una pieza (E) y entregala al brazo robótico de la nave (E).")
	end
end

ACTIONS.cinematicBlack = function(_, state)
	if state.phase == "launching" then
		state.blackout = true
	end
end

ACTIONS.menu = function(player, state)
	if not state.busy then
		goToMenu(player, false)
	end
end

ACTIONS.decide = function(player, _, value)
	task.spawn(decide, player, value)
end

ACTIONS.maneuver = function(player, _, value)
	task.spawn(maneuver, player, value)
end

ACTIONS.route = function(player, _, value)
	task.spawn(route, player, value)
end

ACTIONS.labRun = function(player, _, value)
	labRun(player, value)
end

ACTIONS.anim = function(player, state, value)
	if ANIM_TIME[value] ~= nil then
		state.anim = value
		refresh(player)
	end
end

-- Mandos del transportador: el cliente lee W/S y A/D del asiento y los manda acá
ACTIONS.drive = function(_, state, value)
	if state.phase ~= "transport" or type(value) ~= "table" then
		return
	end
	local throttle, steer = tonumber(value.t), tonumber(value.s)
	if not throttle or not steer or throttle ~= throttle or steer ~= steer then      -- descarta NaN
		return
	end
	state.drive = { throttle = math.clamp(throttle, -1, 1), steer = math.clamp(steer, -1, 1), t = os.clock() }
end

ACTIONS.sit = function(player, state)
	if state.phase == "flight" then
		sitAtDesk(player)
	end
end

remote.OnServerEvent:Connect(function(player, action, value)
	local state = states[player]
	local handler = type(action) == "string" and ACTIONS[action]
	if not state or not handler then
		return
	end
	local ok, err = pcall(handler, player, state, value)
	if not ok then
		warn("[ControlDeMision] Error en la acción " .. action .. ": " .. tostring(err))
	end
end)

-- Traje de astronauta para el avatar: cuerpo blanco, casco con visor dorado, mochila y parche de la NASA.
-- No usa assets subidos: son partes soldadas al personaje (sirve para R6 y R15).
local SUIT_WHITE = Color3.fromRGB(240, 242, 245)
local function dressAstronaut(player, character)
	local deadline = os.clock() + 6
	while not player:HasAppearanceLoaded() and os.clock() < deadline and character.Parent do
		task.wait(0.2)
	end
	if not character.Parent or character:FindFirstChild("TrajeAstronauta") then
		return
	end
	local function strip(item)
		if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
			item:Destroy()
		end
	end
	for _, item in ipairs(character:GetChildren()) do
		strip(item)
	end
	character.ChildAdded:Connect(function(item)
		task.defer(strip, item)
	end)
	local colors = character:FindFirstChildOfClass("BodyColors") or make("BodyColors", {}, character)
	for _, prop in ipairs({ "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }) do
		colors[prop] = SUIT_WHITE
	end
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = SUIT_WHITE
			part.Material = Enum.Material.Fabric
		end
	end
	local suit = make("Folder", { Name = "TrajeAstronauta" }, character)
	local function attach(to, size, offset, color, material, shape)
		local p = make("Part", {
			Size = size, Color = color, Material = material or PLASTIC, Shape = shape or Enum.PartType.Block,
			CanCollide = false, CanTouch = false, CanQuery = false, Massless = true, Anchored = false,
			CFrame = to.CFrame * offset, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
		}, suit)
		make("WeldConstraint", { Part0 = to, Part1 = p }, p)
		return p
	end
	local head = character:FindFirstChild("Head")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if head then
		attach(head, Vector3.new(1.95, 1.95, 1.95), CFrame.new(0, 0.1, 0), SUIT_WHITE, PLASTIC, Enum.PartType.Ball)          -- casco
		local visor = attach(head, Vector3.new(1.5, 1.2, 1.5), CFrame.new(0, 0.1, -0.42), Color3.fromRGB(214, 160, 50), Enum.Material.Glass, Enum.PartType.Ball)
		visor.Reflectance = 0.45
		attach(head, Vector3.new(0.25, 1.6, 1.6), CFrame.new(0, -0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(160, 166, 176), METAL, Enum.PartType.Cylinder)   -- cuello del casco
	end
	if torso then
		local back = torso.Size.Z / 2
		attach(torso, Vector3.new(1.8, 2, 0.8), CFrame.new(0, 0.05, back + 0.4), SUIT_WHITE, PLASTIC)                       -- mochila (soporte vital)
		for _, x in ipairs({ -0.45, 0.45 }) do
			attach(torso, Vector3.new(0.5, 0.5, 0.2), CFrame.new(x, 0.55, back + 0.85), Color3.fromRGB(90, 96, 108), METAL)
		end
		attach(torso, Vector3.new(1.2, 0.5, 0.2), CFrame.new(0, -0.35, -(back + 0.08)), Color3.fromRGB(60, 64, 74), METAL)   -- panel del pecho
		attach(torso, Vector3.new(0.16, 0.12, 0.05), CFrame.new(-0.3, -0.35, -(back + 0.19)), RED, NEON)
		attach(torso, Vector3.new(0.16, 0.12, 0.05), CFrame.new(0, -0.35, -(back + 0.19)), GREEN, NEON)
		local patch = attach(torso, Vector3.new(0.5, 0.5, 0.05), CFrame.new(0.45, 0.45, -(back + 0.03)), WHITE, PLASTIC)
		patch.Transparency = 1
		drawNasaLogo(patch, Enum.NormalId.Front)
		local flag = attach(torso, Vector3.new(0.55, 0.3, 0.05), CFrame.new(-0.45, 0.5, -(back + 0.03)), WHITE, PLASTIC)
		drawFlag(flag, Enum.NormalId.Front)
	end
end

local function onCharacter(player, character)
	character:WaitForChild("HumanoidRootPart")
	character:WaitForChild("Humanoid")
	task.spawn(dressAstronaut, player, character)
	task.wait(0.3)
	local state = states[player]
	if not state then
		return
	end
	if state.phase == "menu" then
		parkCharacter(player)
	else
		goToHangar(player, state.mission, state.mods, state.anim)      -- si reaparece, vuelve al hangar con lo ya armado
	end
end

local function onPlayer(player)
	local stats = make("Folder", { Name = "leaderstats" }, player)
	make("IntValue", { Name = "Puntaje", Value = 0 }, stats)
	make("StringValue", { Name = "Rango", Value = "-" }, stats)
	states[player] = newState(nil)
	task.delay(15, function()
		if states[player] and not clientReady[player] then
			warnMissingClient(player)
		end
	end)

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	cleanup(player)
	states[player] = nil
	clientReady[player] = nil
end)

print("[ControlDeMision] Servidor v7 listo: Atlas V, torres de integración, transportador del rover y misión a Marte.")

