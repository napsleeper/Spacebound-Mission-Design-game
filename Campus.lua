--[[
	CAMPUS · ModuleScript (hijo del Script "ControlDeMision" en ServerScriptService)

	Construye el ATRIO CENTRAL del centro espacial: la plaza que une el hangar de la sonda
	(oeste) con el hangar del rover de Marte (este).

	v5: el ala norte tiene dos salas con función de juego:
	  · CENTRO DE PLANIFICACIÓN (oeste): visualizador orbital y consola (los dibuja el cliente).
	  · LABORATORIO DE INGENIERÍA (este): consola de pruebas, pantalla de informe y rampa de movilidad.
	Además: mapa del complejo, tablero de misiones, directorios junto a las puertas, guías de luz
	en el piso y dos exhibiciones nuevas (telescopio y vehículo explorador).

	CUADROS CON FOTOS: subí tus imágenes a Roblox (Creator Hub > Assets > Images) y pegá los
	ids en Campus.IMAGENES, por ejemplo:  IMAGENES.apollo11 = "rbxassetid://123456789"
	Mientras estén vacíos, cada cuadro muestra un recuadro de "ESPACIO PARA IMAGEN".
]]

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Campus = {}

Campus.IMAGENES = {
	-- Museo de Misiones (línea de tiempo)
	sputnik = "", apollo11 = "", voyager1 = "", hubble = "", cassini = "", curiosity = "", webb = "", artemis = "",
	-- galería norte del atrio
	norte1 = "", norte2 = "", norte3 = "", norte4 = "",
	-- logo de la NASA para la cofia del Atlas V (vacío = se dibuja uno simple)
	logoNasa = "",
}

-- Mientras no haya imagen subida, el cuadro muestra este dibujo grande en vez de un cartel de texto
Campus.ICONOS = {
	sputnik = "🛰️", apollo11 = "🌕", voyager1 = "📡", hubble = "🔭", cassini = "🪐", curiosity = "🚙", webb = "✨", artemis = "🌙",
	norte1 = "🌍", norte2 = "🌑", norte3 = "🚀", norte4 = "🖥️",
}

-- BRILLO GENERAL. Bajá o subí estos números para ajustar todo el centro espacial de una vez.
--   focos: multiplica el brillo de todas las luces del decorado (1 = como el v5, 0,6 = 40 % menos)
--   exposicion: brillo de la cámara (negativo = más oscuro)
--   resplandor: cuánto "brilla" el neón alrededor de las luces y pantallas
Campus.LUZ = { focos = 0.6, exposicion = -0.35, resplandor = 0.25 }

local PUERTA_Z = -21        -- debe coincidir con la puerta que abre el script principal en cada hangar
local PISO_Y = 201          -- altura de la cara superior del piso (ORIGINS.Y + 1)

---------------------------------------------------------------------------
-- ILUMINACIÓN Y AMBIENTE GLOBAL
---------------------------------------------------------------------------
-- v8: atardecer en la costa de Florida (antes era medianoche y, sin suelo, afuera se veía todo negro).
-- Para el despegue, la cinemática pone el cielo del anochecer con estrellas; en el espacio, negro.
Campus.HORA = 17.4

function Campus.setupLighting()
	Lighting.ClockTime = Campus.HORA
	Lighting.GeographicLatitude = 28.5          -- Cabo Cañaveral
	Lighting.Brightness = 1.8
	Lighting.Ambient = Color3.fromRGB(58, 66, 92)
	Lighting.OutdoorAmbient = Color3.fromRGB(112, 112, 128)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.45
	Lighting.ExposureCompensation = Campus.LUZ.exposicion

	local function ensure(className, name, props)
		local obj = Lighting:FindFirstChild(name)
		if not obj then
			obj = Instance.new(className)
			obj.Name = name
			obj.Parent = Lighting
		end
		for key, value in pairs(props) do
			obj[key] = value
		end
	end

	ensure("Atmosphere", "AtmosferaEspacial", {
		Density = 0.3, Offset = 0.15, Color = Color3.fromRGB(214, 196, 178),
		Decay = Color3.fromRGB(120, 96, 132), Glare = 0.35, Haze = 1.2,
	})
	ensure("BloomEffect", "ResplandorNeon", { Intensity = Campus.LUZ.resplandor, Size = 20, Threshold = 1.5 })
	ensure("ColorCorrectionEffect", "TonoNASA", {
		Contrast = 0.08, Saturation = 0.12, TintColor = Color3.fromRGB(236, 243, 255),
	})
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Name = "CieloEstrellado"
		sky.Parent = Lighting
	end
	-- fondo de cielo: el skybox clásico de Roblox (viene con el programa, no hace falta subir nada)
	if sky.SkyboxBk == "" then
		for _, face in ipairs({ "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }) do
			sky["Skybox" .. face] = "rbxasset://textures/sky/sky512_" .. face:lower() .. ".tex"
		end
	end
	sky.StarCount = 4000
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Parent = workspace.Terrain
	end
	clouds.Cover = 0.42
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(255, 236, 222)
end

---------------------------------------------------------------------------
-- CARTEL DE PRECIO SOBRE CADA PIEZA (se ve desde lejos, sin acercarse a la ficha)
---------------------------------------------------------------------------
function Campus.priceTag(parent, position, option, color, code)
	local holder = Instance.new("Part")
	holder.Name = "EtiquetaPrecio"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = position
	holder.Parent = parent

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(230, 74)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Adornee = holder
	gui.Parent = holder

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(4, 12, 32)
	back.BackgroundTransparency = 0.12
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = back

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(8, 4)
	name.Size = UDim2.new(1, -16, 0, 24)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = "[" .. code .. "] " .. option.name
	name.Parent = back

	local price = Instance.new("TextLabel")
	price.BackgroundTransparency = 1
	price.Position = UDim2.fromOffset(8, 32)
	price.Size = UDim2.new(1, -16, 0, 34)
	price.Font = Enum.Font.GothamBlack
	price.TextScaled = true
	price.TextColor3 = Color3.fromRGB(255, 200, 40)
	price.Text = string.format("$%d M  ·  %d kg", option.cost, option.mass)
	price.Parent = back
end

---------------------------------------------------------------------------
-- ATRIO CENTRAL
---------------------------------------------------------------------------
function Campus.build(env)
	local make, box, tube, cyl, ball = env.make, env.box, env.tube, env.cyl, env.ball
	local surfaceText, light = env.surfaceText, env.light
	local C = env.C
	local METAL, NEON, PLASTIC = env.METAL, env.NEON, env.PLASTIC

	local folder = make("Folder", { Name = "Atrio" }, env.world)

	local function P(x, y, z)
		return Vector3.new(x, PISO_Y + y, z)
	end

	-- Dibuja con "env.box" pero en la carpeta del atrio
	local function b(size, cf, color, material)
		return box(folder, size, cf, color, material)
	end

	-- Texto/imagen sobre una cara: tarjeta de museo
	local function txt(parent, props, maxSize)
		props.BackgroundTransparency = props.BackgroundTransparency or 1
		props.BorderSizePixel = 0
		props.Font = props.Font or Enum.Font.GothamBold
		props.TextColor3 = props.TextColor3 or C.WHITE
		props.TextScaled = true
		props.TextWrapped = true
		local label = make("TextLabel", props, parent)
		make("UITextSizeConstraint", { MaxTextSize = maxSize or 40, MinTextSize = 6 }, label)
		return label
	end

	-- Cuadro de pared. inward = dirección hacia donde mira (hacia el visitante)
	local function wallPanel(pos, inward, width, height, accent, title, body, imageKey, textWidth)
		local tw = textWidth or 0.9
		local frame = b(Vector3.new(width + 0.8, height + 0.8, 0.3), CFrame.lookAt(pos, pos + inward), C.DARK, METAL)
		frame.Name = "MarcoCuadro"
		local canvas = b(Vector3.new(width, height, 0.2), CFrame.lookAt(pos + inward * 0.2, pos + inward * 2), C.SCREEN_BG, NEON)
		canvas.Name = "Cuadro"
		local gui = make("SurfaceGui", {
			Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 40, LightInfluence = 0,
		}, canvas)
		local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.SCREEN_BG, BorderSizePixel = 0 }, gui)
		make("Frame", { Size = UDim2.fromScale(1, 0.035), BackgroundColor3 = accent, BorderSizePixel = 0 }, root)
		local textTop = 0.08
		if imageKey then
			local slot = make("Frame", {
				Position = UDim2.fromScale(0.05, 0.07), Size = UDim2.fromScale(0.9, 0.5),
				BackgroundColor3 = Color3.fromRGB(14, 28, 60), BorderSizePixel = 0, Name = "RanuraImagen",
			}, root)
			make("UIStroke", { Color = accent, Thickness = 1 }, slot)
			local id = Campus.IMAGENES[imageKey]
			if id and id ~= "" then
				make("ImageLabel", {
					Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = id,
					ScaleType = Enum.ScaleType.Crop,
				}, slot)
			elseif Campus.ICONOS[imageKey] then
				txt(slot, { Size = UDim2.fromScale(1, 1), Text = Campus.ICONOS[imageKey], Font = Enum.Font.GothamBlack }, 200)
			else
				txt(slot, { Size = UDim2.fromScale(1, 1), Text = "ESPACIO PARA IMAGEN\n(" .. imageKey .. ")", TextColor3 = Color3.fromRGB(110, 140, 200) }, 22)
			end
			textTop = 0.6
		end
		txt(root, {
			Position = UDim2.fromScale(0.05, textTop), Size = UDim2.fromScale(tw, imageKey and 0.1 or 0.16),
			Text = title, TextColor3 = accent, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left,
		}, 36)
		if body and body ~= "" then
			txt(root, {
				Position = UDim2.fromScale(0.05, textTop + (imageKey and 0.11 or 0.18)),
				Size = UDim2.fromScale(tw, imageKey and 0.27 or 0.7),
				Text = body, TextColor3 = Color3.fromRGB(205, 218, 245), Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
			}, 24)
		end
		return canvas, root
	end

	local function fr(parent, x, y, w, h, color, transparency)
		return make("Frame", {
			Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundColor3 = color,
			BackgroundTransparency = transparency or 0, BorderSizePixel = 0,
		}, parent)
	end

	-----------------------------------------------------------------------
	-- Estructura: piso, techo, paredes norte y sur
	-----------------------------------------------------------------------
	b(Vector3.new(90, 2, 92), CFrame.new(P(0, -1, 0)), Color3.fromRGB(26, 32, 50), METAL).Name = "PisoAtrio"
	b(Vector3.new(86, 2, 92), CFrame.new(P(0, 41, 0)), C.DARK, METAL).Name = "TechoAtrio"
	-- pared norte con la puerta al Museo de Misiones (vano de 10 de ancho y 14 de alto en x = 0)
	b(Vector3.new(38, 40, 2), CFrame.new(P(-24, 20, 46)), C.DARK, METAL)
	b(Vector3.new(38, 40, 2), CFrame.new(P(24, 20, 46)), C.DARK, METAL)
	b(Vector3.new(10, 26, 2), CFrame.new(P(0, 27, 46)), C.DARK, METAL)
	b(Vector3.new(86, 40, 2), CFrame.new(P(0, 20, -46)), C.DARK, METAL)

	-- Franjas del piso en los colores de la misión (azul oeste, rojo este) hacia cada hangar
	for _, side in ipairs({ -1, 1 }) do
		local color = side == -1 and C.BLUE_HI or C.RED
		b(Vector3.new(30, 0.1, 1), CFrame.new(P(side * 29, 0.05, PUERTA_Z - 2.5)), color, NEON)
		b(Vector3.new(30, 0.1, 1), CFrame.new(P(side * 29, 0.05, PUERTA_Z + 2.5)), color, NEON)
		-- marco de la puerta en el lado del atrio
		for _, dz in ipairs({ -5.5, 5.5 }) do
			b(Vector3.new(0.6, 15, 0.8), CFrame.new(P(side * 42.7, 7.5, PUERTA_Z + dz)), C.STEEL, METAL)
		end
		b(Vector3.new(0.6, 0.8, 12), CFrame.new(P(side * 42.7, 15, PUERTA_Z)), color, NEON)
		local sign = b(Vector3.new(0.5, 3.4, 18), CFrame.new(P(side * 42.5, 19, PUERTA_Z)), C.WHITE)
		surfaceText(sign, side == -1 and Enum.NormalId.Right or Enum.NormalId.Left,
			side == -1 and "◀ HANGAR 1 · NEW HORIZONS" or "HANGAR 2 · PERSEVERANCE ▶", C.NAVY, C.WHITE, 60)
	end

	-- Anillos de luz en el techo y focos
	cyl(folder, 0.4, 44, CFrame.new(P(0, 39.6, 0)), C.WHITE, NEON)
	cyl(folder, 0.5, 42, CFrame.new(P(0, 39.5, 0)), C.DARK, METAL)
	for i = 0, 7 do
		local angle = math.rad(45 * i)
		light(P(math.cos(angle) * 20, 30, math.sin(angle) * 20), 55, 1.1)
	end
	light(P(0, 15, 0), 60, 1.4)
	for _, x in ipairs({ -30, 30 }) do
		for _, z in ipairs({ -30, 30 }) do
			b(Vector3.new(12, 0.4, 1.4), CFrame.new(P(x, 39.7, z)), C.WHITE, NEON)
			light(P(x, 32, z), 50, 1.1)
		end
	end
	-- Cerchas del techo
	for _, x in ipairs({ -30, -10, 10, 30 }) do
		b(Vector3.new(1.2, 1.2, 90), CFrame.new(P(x, 38.4, 0)), C.STEEL, METAL)
	end

	-----------------------------------------------------------------------
	-- Plaza central: emblema en el piso, holograma y satélite colgante
	-----------------------------------------------------------------------
	cyl(folder, 0.2, 40, CFrame.new(P(0, 0.1, 0)), C.NAVY, METAL)
	cyl(folder, 0.25, 36, CFrame.new(P(0, 0.12, 0)), C.BLUE, NEON).Transparency = 0.45
	cyl(folder, 0.3, 30, CFrame.new(P(0, 0.14, 0)), C.NAVY, METAL)
	cyl(folder, 0.34, 24, CFrame.new(P(0, 0.16, 0)), C.WHITE, NEON).Transparency = 0.6
	cyl(folder, 0.4, 20, CFrame.new(P(0, 0.18, 0)), C.NAVY, METAL)
	-- el "vector" rojo estilo logo
	b(Vector3.new(34, 0.15, 1.2), CFrame.new(P(0, 0.2, 0)) * CFrame.Angles(0, math.rad(-28), 0), C.RED, NEON)
	cyl(folder, 2.0, 16, CFrame.new(P(0, 1, 0)), C.DARK, METAL)
	cyl(folder, 0.3, 16.4, CFrame.new(P(0, 2.1, 0)), C.BLUE_HI, NEON)

	local spinners = {}
	local function spinner(model, baseCF, axis, speed)
		table.insert(spinners, { model = model, base = baseCF, axis = axis, speed = speed })
	end

	-- Holograma: núcleo + discos orbitales con satélites
	local holo = make("Model", { Name = "HologramaOrbital" }, folder)
	local core = ball(holo, 5.5, CFrame.new(P(0, 9, 0)), Color3.fromRGB(30, 90, 200), NEON)
	core.Transparency = 0.35
	ball(holo, 5.7, CFrame.new(P(0, 9, 0)), Color3.fromRGB(90, 200, 255), Enum.Material.ForceField)
	holo.WorldPivot = CFrame.new(P(0, 9, 0))
	spinner(holo, CFrame.new(P(0, 9, 0)), "Y", 0.35)
	local rings = {
		{ radius = 7.5, tilt = 20, speed = 0.9, color = C.BLUE_HI },
		{ radius = 9.5, tilt = -35, speed = -0.6, color = C.WHITE },
		{ radius = 11.5, tilt = 62, speed = 0.45, color = C.RED },
	}
	for i, ring in ipairs(rings) do
		local model = make("Model", { Name = "Orbita" .. i }, folder)
		local center = CFrame.new(P(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(ring.tilt))
		local disc = cyl(model, 0.08, ring.radius * 2, center, ring.color, NEON)
		disc.Transparency = 0.82
		ball(model, 0.9, center * CFrame.new(ring.radius, 0, 0), ring.color, NEON)
		model.WorldPivot = center
		spinner(model, center, "Y", ring.speed)
	end
	local holoLabel = b(Vector3.new(12, 2, 0.3), CFrame.new(P(0, 3.8, -6.6)) * CFrame.Angles(math.rad(25), 0, 0), C.SCREEN_BG, NEON)
	surfaceText(holoLabel, Enum.NormalId.Front, "ÓRBITA DE ESTUDIO", C.GREEN, C.SCREEN_BG, 50)

	-- Satélite colgante sobre la plaza
	local sat = make("Model", { Name = "SateliteColgante" }, folder)
	local satBase = CFrame.new(P(0, 29, 0))
	b(Vector3.new(4, 4, 5), satBase, C.GOLD, Enum.Material.Foil).Parent = sat
	local panelL = box(sat, Vector3.new(10, 0.2, 4), satBase * CFrame.new(-7.5, 0, 0), C.BLUE, Enum.Material.Glass)
	local panelR = box(sat, Vector3.new(10, 0.2, 4), satBase * CFrame.new(7.5, 0, 0), C.BLUE, Enum.Material.Glass)
	cyl(sat, 5, 0.3, satBase * CFrame.new(0, 4, 0), C.STEEL, METAL)
	local dish = cyl(sat, 0.3, 4, satBase * CFrame.new(0, 6.6, 0) * CFrame.Angles(math.rad(-30), 0, 0), C.WHITE)
	ball(sat, 0.5, satBase * CFrame.new(0, 7.2, 1), C.RED, NEON)
	sat.WorldPivot = satBase
	for _, dx in ipairs({ -1.5, 1.5 }) do
		cyl(folder, 12, 0.15, CFrame.new(P(dx, 35, 0)), C.STEEL, METAL)
	end
	spinner(sat, satBase, "Y", 0.25)

	-----------------------------------------------------------------------
	-- Exhibición de motor y lanzador (sin escala, solo ilustrativos)
	-----------------------------------------------------------------------
	local engine = CFrame.new(P(-31, 0, -6))
	cyl(folder, 1.2, 9, engine * CFrame.new(0, 0.6, 0), C.DARK, METAL)
	cyl(folder, 4, 1.6, engine * CFrame.new(0, 3.2, 0), C.STEEL, METAL)
	cyl(folder, 5, 5.4, engine * CFrame.new(0, 6.7, 0), C.GOLD, Enum.Material.Foil)
	cyl(folder, 3, 3.2, engine * CFrame.new(0, 10.7, 0), C.STEEL, METAL)
	for i = 0, 3 do
		local a = math.rad(90 * i + 45)
		cyl(folder, 8, 0.4, engine * CFrame.new(math.cos(a) * 2.2, 5.5, math.sin(a) * 2.2), C.DARK, METAL)
	end
	local engineSign = b(Vector3.new(8, 2.2, 0.3), CFrame.new(P(-31, 2.6, -10)) * CFrame.Angles(math.rad(20), 0, 0), C.RED)
	surfaceText(engineSign, Enum.NormalId.Front, "TOBERA DE MOTOR COHETE", C.WHITE, C.RED, 60)

	local launcher = CFrame.new(P(31, 0, -6))
	cyl(folder, 1.2, 9, launcher * CFrame.new(0, 0.6, 0), C.DARK, METAL)
	cyl(folder, 17, 3.4, launcher * CFrame.new(0, 10, 0), C.WHITE)
	cyl(folder, 1, 3.5, launcher * CFrame.new(0, 6, 0), C.RED)
	cyl(folder, 1, 3.5, launcher * CFrame.new(0, 14, 0), C.BLUE)
	ball(folder, 3.4, launcher * CFrame.new(0, 18.5, 0), C.RED)
	for i = 0, 3 do
		b(Vector3.new(0.3, 4, 2.6), launcher * CFrame.Angles(0, math.rad(90 * i + 45), 0) * CFrame.new(0, 3.6, 3.1), C.BLUE, METAL)
	end
	local launcherSign = b(Vector3.new(9, 2.2, 0.3), CFrame.new(P(31, 2.6, -10)) * CFrame.Angles(math.rad(20), 0, 0), C.BLUE)
	surfaceText(launcherSign, Enum.NormalId.Front, "MODELO DE LANZADOR", C.WHITE, C.BLUE, 60)

	-----------------------------------------------------------------------
	-- Zona de control (plataforma elevada con consolas, mirando a la pantalla grande)
	-----------------------------------------------------------------------
	b(Vector3.new(44, 2.4, 22), CFrame.new(P(0, 1.2, -34)), C.DARK, METAL).Name = "PlataformaControl"
	b(Vector3.new(44, 0.3, 0.8), CFrame.new(P(0, 2.5, -23.2)), C.YELLOW, NEON)
	b(Vector3.new(14, 0.8, 1.6), CFrame.new(P(0, 0.4, -21)), C.STEEL, Enum.Material.DiamondPlate)
	b(Vector3.new(14, 1.6, 1.6), CFrame.new(P(0, 0.8, -22.6)), C.STEEL, Enum.Material.DiamondPlate)
	local bigScreen = b(Vector3.new(40, 14, 0.5), CFrame.new(P(0, 12, -44.6)), C.DARK, METAL)
	local missionScreen = make("Part", {
		Name = "PantallaMisiones", Anchored = true, Size = Vector3.new(38, 12.4, 0.2), Color = C.SCREEN_BG, Material = NEON,
		CFrame = CFrame.lookAt(P(0, 12, -44.2), P(0, 12, -40)),
	}, folder)
	local screenLabel = surfaceText(missionScreen, Enum.NormalId.Front, "", C.GREEN, C.SCREEN_BG, 60)

	local roles = {
		{ "FLIGHT", "Director de vuelo: toma la decisión final" },
		{ "CAPCOM", "Único que habla con la tripulación" },
		{ "FIDO", "Dinámica de vuelo: la trayectoria" },
		{ "GNC", "Guiado, navegación y control" },
		{ "EECOM", "Energía y sistemas de a bordo" },
		{ "DSN", "Enlace con la Red del Espacio Profundo" },
	}
	for i, role in ipairs(roles) do
		local col = (i - 1) % 3
		local row = math.floor((i - 1) / 3)
		local x = -13 + col * 13
		local z = -31 - row * 7
		b(Vector3.new(9, 2.6, 3.2), CFrame.new(P(x, 3.7 + 0.1, z)) , C.WHITE, PLASTIC)
		b(Vector3.new(8.6, 0.3, 3), CFrame.new(P(x, 5.1, z)) * CFrame.Angles(math.rad(-12), 0, 0), C.DARK, METAL)
		local monitor = make("Part", {
			Name = "Consola_" .. role[1], Anchored = true, Size = Vector3.new(7.2, 3.4, 0.2), Color = C.SCREEN_BG, Material = NEON,
			CFrame = CFrame.lookAt(P(x, 7.4, z - 1.3), P(x, 6.2, z + 10)),
		}, folder)
		surfaceText(monitor, Enum.NormalId.Front, role[1] .. "\n" .. role[2], C.GREEN, C.SCREEN_BG, 46)
		b(Vector3.new(0.6, 2.6, 0.6), CFrame.new(P(x, 6.4, z - 1.1)), C.STEEL, METAL)
		cyl(folder, 1.8, 2.2, CFrame.new(P(x, 3.3, z + 4.4)), C.BLUE, METAL)         -- silla
		cyl(folder, 0.3, 2.2, CFrame.new(P(x, 4.4, z + 4.4)), C.DARK, METAL)
	end
	light(P(0, 14, -34), 38, 1.4)

	-----------------------------------------------------------------------
	-- Laboratorios (pared norte): CENTRO DE PLANIFICACIÓN (oeste) y LABORATORIO DE INGENIERÍA (este)
	-----------------------------------------------------------------------
	local function labShell(cx, name, accent)
		-- piso, techo bajo, paredes de vidrio con puerta al frente
		b(Vector3.new(26, 0.3, 22), CFrame.new(P(cx, 0.15, 34)), Color3.fromRGB(210, 220, 235), PLASTIC)
		b(Vector3.new(26, 1, 22), CFrame.new(P(cx, 15.5, 34)), C.DARK, METAL)
		b(Vector3.new(26, 0.4, 1), CFrame.new(P(cx, 15, 23.2)), accent, NEON)
		for _, dx in ipairs({ -13, 13 }) do
			local g = b(Vector3.new(0.4, 15, 22), CFrame.new(P(cx + dx, 7.5, 34)), C.BLUE_HI, Enum.Material.Glass)
			g.Transparency = 0.7
		end
		for _, dx in ipairs({ -8.5, 8.5 }) do                         -- frente de vidrio con puerta de 9 de ancho
			local g = b(Vector3.new(8, 15, 0.4), CFrame.new(P(cx + dx, 7.5, 23)), C.BLUE_HI, Enum.Material.Glass)
			g.Transparency = 0.7
		end
		b(Vector3.new(9, 4.5, 0.4), CFrame.new(P(cx, 12.75, 23)), C.DARK, METAL)
		local sign = b(Vector3.new(24, 3, 0.4), CFrame.new(P(cx, 19, 22.6)), C.WHITE)
		surfaceText(sign, Enum.NormalId.Front, name, C.NAVY, C.WHITE, 60)
		light(P(cx, 13, 34), 34, 1.6)
		b(Vector3.new(24, 0.3, 1), CFrame.new(P(cx, 14.7, 34)), C.WHITE, NEON)
	end

	-- Escritorio con una consola táctil (el cliente dibuja los controles en la parte "nombreConsola")
	local function consoleDesk(pos, consoleName, accent)
		b(Vector3.new(9, 0.5, 3.6), CFrame.new(pos + Vector3.new(0, 3, 0)), C.WHITE, PLASTIC)
		b(Vector3.new(9.1, 0.12, 3.7), CFrame.new(pos + Vector3.new(0, 3.3, 0)), Color3.fromRGB(40, 46, 60), METAL)
		for _, dx in ipairs({ -4.2, 4.2 }) do
			b(Vector3.new(0.5, 2.8, 3.4), CFrame.new(pos + Vector3.new(dx, 1.4, 0)), C.DARK, METAL)
		end
		b(Vector3.new(0.4, 1.5, 0.4), CFrame.new(pos + Vector3.new(0, 4.1, 1.1)), C.STEEL, METAL)
		b(Vector3.new(7.4, 4.4, 0.3), CFrame.new(pos + Vector3.new(0, 6.0, 1.35)), C.DARK, METAL)
		b(Vector3.new(7.6, 0.15, 0.32), CFrame.new(pos + Vector3.new(0, 8.25, 1.35)), accent, NEON)
		make("Part", {
			Name = consoleName, Anchored = true, Size = Vector3.new(7, 4, 0.1), Color = C.SCREEN_BG, Material = NEON,
			CFrame = CFrame.new(pos + Vector3.new(0, 6.0, 1.17)),
		}, env.consolesFolder)
	end

	-- CENTRO DE PLANIFICACIÓN DE MISIONES: visualizador orbital (lo dibuja el cliente) y consola
	labShell(-24, "CENTRO DE PLANIFICACIÓN DE MISIONES", C.GREEN)
	b(Vector3.new(21, 11, 0.4), CFrame.new(P(-24, 8.6, 44.7)), C.DARK, METAL)
	make("Part", {
		Name = "plan-pantalla", Anchored = true, Size = Vector3.new(20, 10, 0.1), Color = C.SCREEN_BG, Material = NEON,
		CFrame = CFrame.new(P(-24, 8.6, 44.45)),
	}, env.consolesFolder)
	consoleDesk(P(-24, 0, 34), "plan-consola", C.GREEN)
	-- maqueta: Tierra con dos órbitas y una elipse de transferencia
	cyl(folder, 2.4, 4, CFrame.new(P(-33.5, 1.2, 30)), C.DARK, METAL)
	local planetModel = make("Model", { Name = "MaquetaHohmann" }, folder)
	ball(planetModel, 2.2, CFrame.new(P(-33.5, 5.4, 30)), Color3.fromRGB(30, 100, 210), NEON)
	local inner = cyl(planetModel, 0.06, 4.4, CFrame.new(P(-33.5, 5.4, 30)), C.BLUE_HI, NEON)
	inner.Transparency = 0.4
	local outer = cyl(planetModel, 0.06, 7.4, CFrame.new(P(-33.5, 5.4, 30)), C.WHITE, NEON)
	outer.Transparency = 0.5
	ball(planetModel, 0.5, CFrame.new(P(-33.5 + 3.7, 5.4, 30)), C.RED, NEON)
	planetModel.WorldPivot = CFrame.new(P(-33.5, 5.4, 30))
	local planTag = b(Vector3.new(5, 1.2, 0.2), CFrame.new(P(-33.5, 2.8, 27.9)) * CFrame.Angles(math.rad(20), 0, 0), C.SCREEN_BG, NEON)
	surfaceText(planTag, Enum.NormalId.Front, "TRANSFERENCIA DE HOHMANN", C.GREEN, C.SCREEN_BG, 40)
	for i = 0, 2 do                                                  -- archivo de planos
		b(Vector3.new(2.4, 5, 2), CFrame.new(P(-14.5, 2.5, 41 - i * 2.6)), C.STEEL, METAL)
	end

	-- LABORATORIO DE INGENIERÍA: consola, informe, rampa de movilidad y banco de propulsión
	labShell(24, "LABORATORIO DE INGENIERÍA · PRUEBAS", C.RED)
	b(Vector3.new(12.6, 8.2, 0.4), CFrame.new(P(17.5, 8.6, 44.7)), C.DARK, METAL)
	env.screen("lab-report", Vector3.new(12, 7.6, 0.1), CFrame.new(P(17.5, 8.6, 44.45)), Enum.NormalId.Front, C.WHITE, 40)
	consoleDesk(P(17, 0, 35), "lab-consola", C.RED)

	-- Rampa de movilidad: el cliente la inclina según la prueba
	local rig = make("Model", { Name = "lab-rampa" }, env.consolesFolder)
	local hinge = P(27, 1.2, 27.5)
	box(rig, Vector3.new(9, 1, 4), CFrame.new(P(31, 0.5, 27.5)), C.DARK, METAL)
	box(rig, Vector3.new(9.1, 0.12, 4.1), CFrame.new(P(31, 1.0, 27.5)), C.YELLOW, NEON).Transparency = 0.5
	local ramp = box(rig, Vector3.new(8, 0.3, 3), CFrame.new(hinge) * CFrame.new(4, 0, 0), C.STEEL, Enum.Material.DiamondPlate)
	ramp.Name = "Rampa"
	ramp:SetAttribute("Largo", 8)
	rig:SetAttribute("Bisagra", hinge)
	local mini = make("Model", { Name = "MiniRover" }, rig)
	local miniBase = CFrame.new(hinge + Vector3.new(1.2, 0.5, 0))
	box(mini, Vector3.new(1.6, 0.4, 1.2), miniBase, C.WHITE)
	for _, dx in ipairs({ -0.6, 0, 0.6 }) do
		for _, dz in ipairs({ -0.7, 0.7 }) do
			tube(mini, 0.2, 0.5, miniBase * CFrame.new(dx, -0.25, dz) * CFrame.Angles(0, math.rad(90), 0), C.DARK)
		end
	end
	cyl(mini, 0.7, 0.08, miniBase * CFrame.new(-0.4, 0.5, 0), C.STEEL, METAL)
	mini.WorldPivot = miniBase
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	local rigTag = b(Vector3.new(6, 1.2, 0.2), CFrame.new(P(31, 2.4, 25.3)) * CFrame.Angles(math.rad(25), 0, 0), C.SCREEN_BG, NEON)
	surfaceText(rigTag, Enum.NormalId.Front, "RAMPA DE MOVILIDAD", C.GREEN, C.SCREEN_BG, 40)

	-- Banco de propulsión (decorado, con llama que parpadea)
	local stand = CFrame.new(P(31.5, 0, 38))
	for _, sx in ipairs({ -3.5, 3.5 }) do
		for _, sz in ipairs({ -2.5, 2.5 }) do
			b(Vector3.new(0.6, 12, 0.6), stand * CFrame.new(sx, 6, sz), C.YELLOW, METAL)
		end
	end
	b(Vector3.new(8, 0.6, 6), stand * CFrame.new(0, 11.8, 0), C.STEEL, Enum.Material.DiamondPlate)
	cyl(folder, 3, 2, stand * CFrame.new(0, 10, 0), C.DARK, METAL)
	cyl(folder, 3.4, 4, stand * CFrame.new(0, 7.2, 0), C.GOLD, Enum.Material.Foil)
	local testFlame = cyl(folder, 3.8, 2.6, stand * CFrame.new(0, 3.9, 0), C.ORANGE, NEON)
	testFlame.Transparency = 0.7
	local testFlame2 = cyl(folder, 2.4, 1.4, stand * CFrame.new(0, 3.3, 0), Color3.fromRGB(255, 240, 160), NEON)
	testFlame2.Transparency = 0.6
	cyl(folder, 0.4, 7, stand * CFrame.new(0, 0.5, 0), C.DARK, METAL)
	local propMonitor = b(Vector3.new(5, 2.8, 0.2), CFrame.new(P(31.5, 13.5, 44.6)), C.SCREEN_BG, NEON)
	surfaceText(propMonitor, Enum.NormalId.Front, "Δv = Isp · g0 · ln(m0/mf)\nHidracina ~220 s · Bipropelente ~320 s", C.GREEN, C.SCREEN_BG, 40)
	-- cámara térmica (ensayos de sombra lunar)
	local chamber = cyl(folder, 6, 4, CFrame.new(P(13.5, 3.2, 28)), Color3.fromRGB(180, 220, 255), Enum.Material.Glass)
	chamber.Transparency = 0.6
	cyl(folder, 0.5, 4.4, CFrame.new(P(13.5, 0.3, 28)), C.DARK, METAL)
	cyl(folder, 0.5, 4.4, CFrame.new(P(13.5, 6.3, 28)), C.DARK, METAL)
	ball(folder, 1.4, CFrame.new(P(13.5, 3.2, 28)), Color3.fromRGB(120, 200, 255), NEON)
	spinner(planetModel, CFrame.new(P(-33.5, 5.4, 30)), "Y", 0.5)

	-----------------------------------------------------------------------
	-- Señalización, mapa del complejo, tablero de misiones y directorios
	-----------------------------------------------------------------------
	local mapPart = b(Vector3.new(14, 9, 0.2), CFrame.lookAt(P(-32, 10, -44.6), P(-32, 10, 0)), C.SCREEN_BG, NEON)
	b(Vector3.new(14.8, 9.8, 0.3), CFrame.lookAt(P(-32, 10, -44.85), P(-32, 10, 0)), C.DARK, METAL)
	local mapGui = make("SurfaceGui", { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0 }, mapPart)
	local map = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.SCREEN_BG, BorderSizePixel = 0 }, mapGui)
	txt(map, { Position = UDim2.fromScale(0.03, 0.02), Size = UDim2.fromScale(0.94, 0.09), Text = "MAPA DEL COMPLEJO", TextColor3 = C.WHITE }, 30)
	-- coordenadas del mundo (x de -160 a 160, z de -230 a 160) llevadas al mapa (z hacia arriba)
	local function area(x1, x2, z1, z2, color, label)
		local u1, u2 = (x1 + 160) / 320, (x2 + 160) / 320
		local v1, v2 = 1 - (z2 + 230) / 390, 1 - (z1 + 230) / 390
		local f = fr(map, 0.04 + u1 * 0.92, 0.12 + v1 * 0.84, (u2 - u1) * 0.92, (v2 - v1) * 0.84, color, 0.35)
		make("UIStroke", { Color = color, Thickness = 2 }, f)
		txt(f, { Size = UDim2.fromScale(1, 1), Text = label, TextColor3 = C.WHITE }, 18)
	end
	area(-155, -45, -46, 46, C.BLUE_HI, "HANGAR 1\nNEW HORIZONS")
	area(45, 155, -46, 46, C.RED, "HANGAR 2\nVEHÍCULO")
	area(-43, 43, -46, 46, C.STEEL, "ATRIO")
	area(-37, -11, 23, 45, C.GREEN, "PLANIF.")
	area(11, 37, 23, 45, C.RED, "LAB.")
	area(-30, 30, 47, 95, C.GOLD, "MUSEO")
	area(-128, -72, 108, 152, C.BLUE_HI, "CONTROL\nNEW HORIZONS")
	area(72, 128, 108, 152, C.RED, "CONTROL\nVEHÍCULO")
	area(55, 145, -223, -93, C.YELLOW, "PLATAFORMA\nATLAS V")
	local here = fr(map, 0.04 + 0.5 * 0.92 - 0.012, 0.12 + (1 - 230 / 390) * 0.84 - 0.02, 0.024, 0.04, C.YELLOW)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, here)
	txt(map, { Position = UDim2.fromScale(0.52, 0.12 + (1 - 230 / 390) * 0.84 - 0.03), Size = UDim2.fromScale(0.3, 0.05), Text = "USTED ESTÁ AQUÍ", TextColor3 = C.YELLOW, TextXAlignment = Enum.TextXAlignment.Left }, 18)

	b(Vector3.new(14.8, 9.8, 0.3), CFrame.lookAt(P(32, 10, -44.85), P(32, 10, 0)), C.DARK, METAL)
	env.screen("atrio-misiones", Vector3.new(14, 9, 0.2), CFrame.lookAt(P(32, 10, -44.6), P(32, 10, 0)), Enum.NormalId.Front, C.WHITE, 30)

	-- Directorios junto a cada puerta de hangar
	for _, side in ipairs({ -1, 1 }) do
		local pos = P(side * 33, 0, -31)
		b(Vector3.new(3, 0.4, 3), CFrame.new(pos + Vector3.new(0, 0.2, 0)), C.DARK, METAL)
		b(Vector3.new(1, 8, 1), CFrame.new(pos + Vector3.new(0, 4, 0)), C.STEEL, METAL)
		local panel = b(Vector3.new(0.3, 5, 6), CFrame.new(pos + Vector3.new(0, 6.5, 0)), C.SCREEN_BG, NEON)
		surfaceText(panel, side == -1 and Enum.NormalId.Left or Enum.NormalId.Right,
			"▲ Museo · Planificación · Laboratorio\n◀ Hangar 1 · New Horizons\n▶ Hangar 2 · Perseverance",
			C.GREEN, C.SCREEN_BG, 30)
	end
	-- Guías de luz en el piso hacia cada laboratorio
	for _, x in ipairs({ -24, 24 }) do
		b(Vector3.new(0.6, 0.08, 36), CFrame.new(P(x, 0.05, 4)), x < 0 and C.GREEN or C.RED, NEON).Transparency = 0.3
	end

	-- Exhibiciones: telescopio espacial (dentro del Museo, junto al cuadro del Hubble, así la
	-- entrada al museo queda libre) y vehículo explorador (modelos ilustrativos)
	local scope = CFrame.new(P(-16, 0, 84))
	cyl(folder, 1.6, 7, scope * CFrame.new(0, 0.8, 0), C.DARK, METAL)
	local tele = make("Model", { Name = "TelescopioEspacial" }, folder)
	tube(tele, 8, 3.2, scope * CFrame.new(0, 8, 0), C.STEEL, METAL)
	tube(tele, 0.3, 3.4, scope * CFrame.new(-4.1, 8, 0), C.DARK, METAL)
	box(tele, Vector3.new(0.15, 6, 2.4), scope * CFrame.new(0, 8, 2.6), C.BLUE, Enum.Material.Glass)
	box(tele, Vector3.new(0.15, 6, 2.4), scope * CFrame.new(0, 8, -2.6), C.BLUE, Enum.Material.Glass)
	tele.WorldPivot = scope * CFrame.new(0, 8, 0)
	cyl(folder, 6.5, 0.4, scope * CFrame.new(0, 4.4, 0), C.STEEL, METAL)
	spinner(tele, scope * CFrame.new(0, 8, 0), "Y", 0.15)
	local scopeSign = b(Vector3.new(8, 1.6, 0.3), scope * CFrame.new(0, 2.2, -3.6) * CFrame.Angles(math.rad(20), 0, 0), C.BLUE)
	surfaceText(scopeSign, Enum.NormalId.Front, "TELESCOPIO ESPACIAL (MODELO)", C.WHITE, C.BLUE, 40)

	local roverBase = CFrame.new(P(-31, 0, 13))
	cyl(folder, 1.2, 9, roverBase * CFrame.new(0, 0.6, 0), C.DARK, METAL)
	b(Vector3.new(5, 0.6, 3.4), roverBase * CFrame.new(0, 2.6, 0), C.WHITE, METAL)
	for _, dx in ipairs({ -1.9, 0, 1.9 }) do
		for _, dz in ipairs({ -2, 2 }) do
			tube(folder, 0.6, 1.4, roverBase * CFrame.new(dx, 1.9, dz) * CFrame.Angles(0, math.rad(90), 0), C.DARK)
		end
	end
	cyl(folder, 2.6, 0.25, roverBase * CFrame.new(-1.5, 4.2, 0), C.STEEL, METAL)
	b(Vector3.new(1.2, 0.6, 0.6), roverBase * CFrame.new(-1.5, 5.6, 0), C.WHITE)
	local roverSign = b(Vector3.new(7, 1.6, 0.3), CFrame.new(P(-31, 2.2, 8.4)) * CFrame.Angles(math.rad(20), 0, 0), C.RED)
	surfaceText(roverSign, Enum.NormalId.Front, "VEHÍCULO EXPLORADOR (MODELO)", C.WHITE, C.RED, 40)

	-----------------------------------------------------------------------
	-- MUSEO DE MISIONES (detrás de la pared norte, entre los dos laboratorios)
	-- Sala de 60 x 48 (x de -30 a 30, z de 47 a 95). Los cuadros siguen el orden de la
	-- historia: pared oeste → pared del fondo → pared este.
	-----------------------------------------------------------------------
	local MUSEO_Z = 71                                             -- centro de la sala en z
	local WALL_COLOR = Color3.fromRGB(22, 30, 56)
	b(Vector3.new(62, 2, 50), CFrame.new(P(0, -1, MUSEO_Z)), Color3.fromRGB(70, 52, 40), Enum.Material.WoodPlanks).Name = "PisoMuseo"
	b(Vector3.new(62, 1, 50), CFrame.new(P(0, 18.5, MUSEO_Z)), C.DARK, METAL).Name = "TechoMuseo"
	b(Vector3.new(2, 18, 50), CFrame.new(P(-31, 9, MUSEO_Z)), WALL_COLOR)
	b(Vector3.new(2, 18, 50), CFrame.new(P(31, 9, MUSEO_Z)), WALL_COLOR)
	b(Vector3.new(62, 18, 2), CFrame.new(P(0, 9, 96)), WALL_COLOR)
	-- zócalo dorado y luz tenue en el techo
	for _, side in ipairs({ -1, 1 }) do
		b(Vector3.new(0.3, 0.6, 48), CFrame.new(P(side * 29.9, 0.3, MUSEO_Z)), C.GOLD, METAL)
	end
	b(Vector3.new(60, 0.6, 0.3), CFrame.new(P(0, 0.3, 94.9)), C.GOLD, METAL)
	for _, z in ipairs({ 60, 82 }) do
		local strip = b(Vector3.new(36, 0.2, 0.8), CFrame.new(P(0, 17.9, z)), C.WHITE, NEON)
		strip.Transparency = 0.45
	end
	for _, x in ipairs({ -16, 16 }) do
		for _, z in ipairs({ 58, 84 }) do
			light(P(x, 14, z), 30, 0.9)
		end
	end

	-- Puerta desde el atrio: marco dorado y cartel arriba
	for _, dx in ipairs({ -5.4, 5.4 }) do
		b(Vector3.new(0.8, 14, 0.8), CFrame.new(P(dx, 7, 44.8)), C.STEEL, METAL)
	end
	b(Vector3.new(11.6, 0.6, 0.8), CFrame.new(P(0, 14.3, 44.8)), C.GOLD, NEON)
	local museumSign = b(Vector3.new(16, 3, 0.4), CFrame.new(P(0, 17, 44.7)), C.WHITE)
	surfaceText(museumSign, Enum.NormalId.Front, "🏛️ MUSEO DE MISIONES", C.NAVY, C.WHITE, 60)

	-- Línea de tiempo en el piso: une los cuadros en orden
	local floorLine = b(Vector3.new(0.6, 0.08, 40), CFrame.new(P(0, 0.05, MUSEO_Z - 2)), C.BLUE_HI, NEON)
	floorLine.Transparency = 0.4
	local inside = b(Vector3.new(30, 2.6, 0.4), CFrame.new(P(0, 15.6, 94.7)), C.WHITE)
	surfaceText(inside, Enum.NormalId.Front, "LÍNEA DE TIEMPO DE LA EXPLORACIÓN", C.NAVY, C.WHITE, 60)

	-- Un cuadro por misión: dibujo grande (o foto), nombre con el año y una sola frase
	local history = {
		{ "sputnik", "1957 · SPUTNIK 1", "El primer satélite artificial. Daba una vuelta a la Tierra cada 96 minutos." },
		{ "apollo11", "1969 · APOLLO 11", "Las primeras personas en caminar sobre la Luna." },
		{ "voyager1", "1977 · VOYAGER 1", "La nave más lejana: ya viaja por el espacio entre las estrellas." },
		{ "hubble", "1990 · HUBBLE", "Telescopio en órbita: arriba del aire, ve las estrellas sin borrones." },
		{ "cassini", "1997 · CASSINI", "Estudió Saturno 13 años. Para quedarse en órbita tuvo que frenar." },
		{ "curiosity", "2012 · CURIOSITY", "Un rover del tamaño de un auto que explora Marte." },
		{ "webb", "2021 · JAMES WEBB", "Telescopio infrarrojo a 1,5 millones de km de la Tierra." },
		{ "artemis", "2022 · ARTEMIS I", "La nave Orion dio la vuelta a la Luna sin tripulación." },
	}
	local spots = {
		{ P(-29.6, 7.5, 56), Vector3.new(1, 0, 0) },              -- pared oeste, de la entrada hacia el fondo
		{ P(-29.6, 7.5, 69), Vector3.new(1, 0, 0) },
		{ P(-29.6, 7.5, 82), Vector3.new(1, 0, 0) },
		{ P(-10, 7.5, 94.6), Vector3.new(0, 0, -1) },             -- pared del fondo
		{ P(10, 7.5, 94.6), Vector3.new(0, 0, -1) },
		{ P(29.6, 7.5, 82), Vector3.new(-1, 0, 0) },              -- pared este, del fondo hacia la entrada
		{ P(29.6, 7.5, 69), Vector3.new(-1, 0, 0) },
		{ P(29.6, 7.5, 56), Vector3.new(-1, 0, 0) },
	}
	local accents = { C.BLUE_HI, C.WHITE, C.RED }
	for i, item in ipairs(history) do
		local spot = spots[i]
		wallPanel(spot[1], spot[2], 7, 9.4, accents[(i - 1) % 3 + 1], item[2], item[3], item[1])
	end

	-- En el centro: maqueta de Saturno que gira y dos bancos para mirar los cuadros
	cyl(folder, 3, 5, CFrame.new(P(0, 1.5, MUSEO_Z + 4)), C.DARK, METAL)
	local saturn = make("Model", { Name = "MaquetaSaturno" }, folder)
	local saturnCF = CFrame.new(P(0, 7, MUSEO_Z + 4))
	ball(saturn, 4.4, saturnCF, Color3.fromRGB(214, 184, 130))
	local ring = cyl(saturn, 0.1, 9, saturnCF * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(230, 210, 160), NEON)
	ring.Transparency = 0.35
	saturn.WorldPivot = saturnCF
	spinner(saturn, saturnCF, "Y", 0.3)
	for _, x in ipairs({ -11, 11 }) do
		b(Vector3.new(2.2, 1.2, 8), CFrame.new(P(x, 0.6, MUSEO_Z)), C.NAVY, METAL).CanCollide = true
	end

	-- Planos (pared este): hay que dibujar con marcos sobre un lienzo azul
	local function blueprint(z, title, body, drawer)
		local canvas, root = wallPanel(P(42.6, 10, z), Vector3.new(-1, 0, 0), 9.6, 8.6, C.WHITE, title, body, nil, 0.46)
		root.BackgroundColor3 = Color3.fromRGB(10, 50, 120)
		local grid = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, root)
		for g = 1, 9 do
			fr(grid, g / 10, 0, 0.003, 1, Color3.fromRGB(80, 130, 220), 0.6)
			fr(grid, 0, g / 10, 1, 0.004, Color3.fromRGB(80, 130, 220), 0.6)
		end
		drawer(root)
	end
	local W = Color3.fromRGB(235, 244, 255)
	blueprint(8, "PLANO · LANZADOR", "Ecuación de Tsiolkovsky:\nΔv = ve · ln(m0 / mf)\nMás propelente = más Δv.", function(root)
		fr(root, 0.72, 0.18, 0.07, 0.5, W)
		fr(root, 0.735, 0.1, 0.04, 0.09, W)
		fr(root, 0.67, 0.55, 0.05, 0.14, W)
		fr(root, 0.79, 0.55, 0.05, 0.14, W)
		fr(root, 0.725, 0.69, 0.06, 0.04, Color3.fromRGB(255, 140, 60))
	end)
	blueprint(18.5, "PLANO · PERSEVERANCE", "1.025 kg · 3 × 2,7 × 2,2 m\nEn Marte pesa 3.803 N (g = 3,71 m/s²).", function(root)
		fr(root, 0.58, 0.4, 0.34, 0.1, W)
		fr(root, 0.66, 0.28, 0.02, 0.12, W)
		fr(root, 0.64, 0.24, 0.08, 0.05, W)
		for _, x in ipairs({ 0.6, 0.72, 0.84 }) do
			local wheel = fr(root, x, 0.5, 0.08, 0.14, W)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, wheel)
		end
	end)
	blueprint(29, "PLANO · NEW HORIZONS", "478 kg con 77 kg de hidracina.\nSalió a 16,2 km/s: el Δv lo puso el cohete.", function(root)
		fr(root, 0.66, 0.3, 0.1, 0.2, W)
		fr(root, 0.5, 0.37, 0.15, 0.05, Color3.fromRGB(120, 180, 255))
		fr(root, 0.77, 0.37, 0.15, 0.05, Color3.fromRGB(120, 180, 255))
		local dish = fr(root, 0.68, 0.18, 0.06, 0.1, W)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, dish)
	end)
	local eastTitle = b(Vector3.new(0.4, 3, 20), CFrame.new(P(42.6, 18.6, 18.5)), C.WHITE)
	surfaceText(eastTitle, Enum.NormalId.Left, "PLANOS DE INGENIERÍA", C.NAVY, C.WHITE, 60)

	-- Galería norte con espacio para fotos de misiones
	local gallery = {
		{ "norte1", "LA TIERRA DESDE ARRIBA", "" },
		{ "norte2", "SUPERFICIE LUNAR", "" },
		{ "norte3", "LANZAMIENTO", "" },
		{ "norte4", "CONTROL DE MISIÓN", "" },
	}
	for i, item in ipairs(gallery) do
		local x = -33 + (i - 1) * 22
		wallPanel(P(x, 28, 44.8), Vector3.new(0, 0, -1), 9, 7.4, C.RED, item[2], item[3], item[1])
	end

	-----------------------------------------------------------------------
	-- Detalles: bancos, cajas de equipo, extintores, torres de servidores
	-----------------------------------------------------------------------
	for _, spot in ipairs({ { -14, -1 }, { 14, -1 }, { -14, 1 }, { 14, 1 } }) do
		b(Vector3.new(8, 1.2, 2.2), CFrame.new(P(spot[1], 0.6 + 0, spot[2] * 14)) , C.NAVY, METAL).CanCollide = true
	end
	for _, z in ipairs({ -40, -6 }) do                         -- carteles de seguridad
		local sign = b(Vector3.new(0.3, 2.4, 7), CFrame.new(P(-42.6, 6, z)), C.YELLOW)
		surfaceText(sign, Enum.NormalId.Right, "ZONA DE SEGURIDAD", C.DARK, C.YELLOW, 40)
	end

	-----------------------------------------------------------------------
	-- Animación (throttled, 15 Hz) y reloj de misión
	-----------------------------------------------------------------------
	local startClock = os.time()
	local acc, clockAcc = 0, 1
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		clockAcc += dt
		if acc >= 1 / 15 then
			local t = os.clock()
			for _, s in ipairs(spinners) do
				s.model:PivotTo(s.base * CFrame.Angles(0, t * s.speed, 0))
			end
			-- el banco de pruebas parpadea como un motor encendido
			local flicker = 0.55 + math.abs(math.sin(t * 18)) * 0.3
			testFlame.Transparency = flicker
			testFlame2.Transparency = flicker - 0.1
			acc = 0
		end
		if clockAcc >= 1 then
			clockAcc = 0
			local elapsed = os.time() - startClock
			screenLabel.Text = string.format(
				"CENTRO DE CONTROL DE MISIONES\n\nT+ %02d:%02d:%02d\n\nHANGAR 1 · NEW HORIZONS\nHANGAR 2 · PERSEVERANCE\nENLACE: ACTIVO",
				math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60, elapsed % 60)
		end
	end)

	return folder
end

---------------------------------------------------------------------------
-- v8 · EXTERIOR DEL CENTRO ESPACIAL (Florida, junto al mar)
-- Antes el complejo flotaba en el vacío y en el despegue se veía todo negro. Ahora hay suelo,
-- mar al este, rejas alrededor, edificios de la NASA, banderas de EE. UU., palmeras, calles,
-- autos, plataformas de lanzamiento lejanas y una línea de árboles en el horizonte.
-- Todo es decorado anclado con semilla fija (Random.new(7)): siempre sale igual.
-- env = { world, make, box, cyl, ball, surfaceText, drawFlag, drawNasaLogo, C, METAL, NEON }
---------------------------------------------------------------------------
Campus.CERCA = { x1 = -215, x2 = 215, z1 = -265, z2 = 205, puerta = 26 }   -- rejas (coordenadas del mundo)

function Campus.buildExterior(env)
	local make, box, cyl, ball = env.make, env.box, env.cyl, env.ball
	local surfaceText, C = env.surfaceText, env.C
	local METAL, NEON = env.METAL, env.NEON
	-- Modelo persistente: con StreamingEnabled se carga siempre (se ve desde lejos en el tour y en los despegues)
	local folder = make("Model", { Name = "Exterior", ModelStreamingMode = Enum.ModelStreamingMode.Persistent }, env.world)
	local Y = PISO_Y - 0.2                        -- el suelo queda apenas debajo de los pisos de los edificios
	local random = Random.new(7)

	local GRASS = Color3.fromRGB(92, 124, 62)
	local ASPHALT = Color3.fromRGB(46, 48, 52)
	local CONCRETE = Color3.fromRGB(170, 170, 164)
	local SAND = Color3.fromRGB(214, 196, 150)
	local OCEAN = Color3.fromRGB(28, 84, 128)
	local BUILDING = Color3.fromRGB(226, 228, 230)
	local GLASS = Color3.fromRGB(70, 130, 190)

	local function part(size, cf, color, material, collide)
		local p = box(folder, size, cf, color, material)
		p.CanCollide = collide == true
		p.CastShadow = false
		return p
	end
	local function at(x, y, z)
		return CFrame.new(x, Y + y, z)
	end

	-- 1. SUELO: pasto hasta la playa (x = 560), arena y mar ---------------------------------
	for _, zc in ipairs({ -2000, 0, 2000 }) do
		part(Vector3.new(1560, 4, 2000), at(-220, -2, zc), GRASS, Enum.Material.Grass, true)
		part(Vector3.new(1800, 4, 2000), at(-1900, -2, zc), GRASS, Enum.Material.Grass, true)
		part(Vector3.new(70, 4, 2000), at(595, -2.2, zc), SAND, Enum.Material.Sand, true)
		local sea = part(Vector3.new(2000, 2, 2000), at(1630, -1.6, zc), OCEAN, Enum.Material.SmoothPlastic, false)
		sea.Reflectance = 0.25
	end
	-- explanada de cemento debajo de los edificios del campus
	part(Vector3.new(330, 0.2, 260), at(0, 0.05, -20), CONCRETE, Enum.Material.Concrete, true)

	-- 2. CALLES -----------------------------------------------------------------------------
	local function road(x1, z1, x2, z2, width)
		local a, b = Vector3.new(x1, Y + 0.12, z1), Vector3.new(x2, Y + 0.12, z2)
		local length = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		part(Vector3.new(width, 0.2, length), cf, ASPHALT, Enum.Material.Asphalt, true)
		for d = 6, length - 6, 16 do                                               -- línea amarilla punteada
			part(Vector3.new(0.5, 0.05, 7), cf * CFrame.new(0, 0.12, -length / 2 + d), C.YELLOW, Enum.Material.SmoothPlastic)
		end
	end
	road(0, 205, 0, 900, 22)                       -- avenida de entrada (norte)
	road(-240, 225, 240, 225, 16)                  -- calle paralela a la reja norte
	road(240, 225, 240, -320, 16)                  -- hacia la costa y las plataformas
	road(240, -320, 470, -480, 16)
	road(-240, 225, -240, -60, 16)                 -- hacia el edificio de ensamblaje

	-- 3. REJAS alrededor de todo el complejo (barrotes, postes, alambre arriba) ------------
	local F = Campus.CERCA
	local STEEL_FENCE = Color3.fromRGB(120, 124, 130)
	local function fence(x1, z1, x2, z2)
		local a, b = Vector3.new(x1, Y, z1), Vector3.new(x2, Y, z2)
		local length = (b - a).Magnitude
		local dir = (b - a).Unit
		local cf = CFrame.lookAt((a + b) / 2, b)
		for _, h in ipairs({ 0.6, 4, 7.6 }) do                                      -- travesaños
			part(Vector3.new(0.25, 0.25, length), cf + Vector3.new(0, h, 0), STEEL_FENCE, METAL, false)
		end
		for _, h in ipairs({ 8.4, 9.0 }) do                                         -- alambre de púas
			part(Vector3.new(0.08, 0.08, length), cf + Vector3.new(0, h, 0), C.DARK, METAL, false)
		end
		local wall = part(Vector3.new(0.3, 9, length), cf + Vector3.new(0, 4.5, 0), STEEL_FENCE, METAL, true)
		wall.Transparency = 1                                                        -- pared invisible: no se cruza la reja
		for d = 0, length, 10 do                                                     -- postes
			local p = a + dir * d
			part(Vector3.new(0.5, 9.4, 0.5), CFrame.new(p + Vector3.new(0, 4.7, 0)), C.DARK, METAL, false)
		end
		for d = 1.25, length, 2.5 do                                                 -- barrotes
			local p = a + dir * d
			part(Vector3.new(0.14, 7.2, 0.14), CFrame.new(p + Vector3.new(0, 4.1, 0)), STEEL_FENCE, METAL, false)
		end
	end
	local gap = F.puerta / 2
	fence(F.x1, F.z2, -gap, F.z2)
	fence(gap, F.z2, F.x2, F.z2)
	fence(F.x2, F.z2, F.x2, F.z1)
	fence(F.x2, F.z1, F.x1, F.z1)
	fence(F.x1, F.z1, F.x1, F.z2)

	-- Portón de entrada: garita, barrera y cartel con el logo
	for _, side in ipairs({ -1, 1 }) do
		part(Vector3.new(2, 12, 2), at(side * (gap + 1), 6, F.z2), C.WHITE, Enum.Material.SmoothPlastic, true)
	end
	local booth = part(Vector3.new(8, 8, 8), at(gap + 8, 4, F.z2 + 8), BUILDING, Enum.Material.SmoothPlastic, true)
	booth.Name = "Garita"
	part(Vector3.new(8.2, 2.2, 8.2), at(gap + 8, 5.5, F.z2 + 8), GLASS, Enum.Material.Glass).Transparency = 0.3
	part(Vector3.new(9, 0.6, 9), at(gap + 8, 8.3, F.z2 + 8), C.BLUE, Enum.Material.SmoothPlastic)
	part(Vector3.new(gap * 2 - 2, 0.4, 0.4), at(0, 3.5, F.z2 + 2), C.RED, Enum.Material.SmoothPlastic)    -- barrera
	local gateSign = part(Vector3.new(30, 7, 0.6), at(0, 16, F.z2), C.WHITE, Enum.Material.SmoothPlastic)
	surfaceText(gateSign, Enum.NormalId.Back, "CENTRO ESPACIAL · NASA", C.NAVY, C.WHITE, 90)
	local gateLogo = part(Vector3.new(6, 6, 0.1), at(-11, 16, F.z2 + 0.4), C.WHITE, Enum.Material.SmoothPlastic)
	gateLogo.Transparency = 1
	env.drawNasaLogo(gateLogo, Enum.NormalId.Back)

	-- 4. BANDERAS DE EE. UU. (avenida de banderas en la entrada y junto a los edificios) ----
	local function flagpole(x, z, height, nasa)
		cyl(folder, height, 0.4, at(x, height / 2, z), C.WHITE, METAL).CastShadow = false
		ball(folder, 0.8, at(x, height + 0.3, z), C.GOLD, METAL)
		-- la bandera mira hacia el norte y el sur (se ve desde la avenida y desde el complejo)
		local flag = part(Vector3.new(7.4, 3.9, 0.08), at(x + 3.9, height - 2.2, z), C.WHITE, Enum.Material.Fabric)
		if nasa then
			local gui = make("SurfaceGui", { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0.4 }, flag)
			make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.BLUE, BorderSizePixel = 0 }, gui)
			local logo = part(Vector3.new(3.4, 3.4, 0.05), flag.CFrame * CFrame.new(0, 0, -0.07), C.WHITE, Enum.Material.SmoothPlastic)
			logo.Transparency = 1
			env.drawNasaLogo(logo, Enum.NormalId.Front)
		else
			env.drawFlag(flag, Enum.NormalId.Front)
			env.drawFlag(flag, Enum.NormalId.Back)
		end
	end
	for i = -3, 3 do
		if i ~= 0 then
			flagpole(i * 9 + (i > 0 and 6 or -6), F.z2 + 30, 20, i == 1 or i == -1)
		end
	end
	for _, spot in ipairs({ { -200, 180 }, { 200, 180 }, { -200, -240 }, { 200, -240 }, { 160, -110 }, { 40, -110 } }) do
		flagpole(spot[1], spot[2], 18, false)
	end

	-- 5. EDIFICIOS DE LA NASA ---------------------------------------------------------------
	-- Ventanas en bandas de vidrio que brillan al atardecer
	local function windows(cf, width, height, depth, rows)
		for r = 1, rows do
			local y = -height / 2 + r * height / (rows + 1)
			local band = part(Vector3.new(width * 0.92, height / (rows + 1) * 0.42, depth + 0.2), cf * CFrame.new(0, y, 0), GLASS, NEON)
			band.Transparency = 0.25
		end
	end

	-- 5a. Edificio de Ensamblaje de Vehículos (enorme, al oeste: se ve desde el ventanal del hangar 1)
	local vab = at(-430, 95, -40)
	part(Vector3.new(150, 190, 170), vab, BUILDING, Enum.Material.Concrete, true).Name = "EdificioEnsamblaje"
	for i = -6, 6 do                                                                  -- paneles verticales
		part(Vector3.new(151, 186, 1.2), vab * CFrame.new(0, 0, i * 12.5), Color3.fromRGB(205, 207, 210), Enum.Material.Concrete)
	end
	for _, z in ipairs({ -45, 45 }) do                                                -- puertas altísimas (cara este)
		part(Vector3.new(1, 160, 26), vab * CFrame.new(75.2, -15, z), Color3.fromRGB(90, 96, 104), METAL)
		for y = -90, 60, 10 do
			part(Vector3.new(1.2, 0.5, 26), vab * CFrame.new(75.4, y, z), C.DARK, METAL)
		end
	end
	local vabFlag = part(Vector3.new(0.3, 34, 62), vab * CFrame.new(75.6, 50, 0), C.WHITE, Enum.Material.SmoothPlastic)
	env.drawFlag(vabFlag, Enum.NormalId.Right)                                        -- bandera gigante hacia el complejo
	local vabLogo = part(Vector3.new(0.3, 40, 40), vab * CFrame.new(75.6, -10, 0), C.WHITE, Enum.Material.SmoothPlastic)
	vabLogo.Transparency = 1
	env.drawNasaLogo(vabLogo, Enum.NormalId.Right)
	local vabName = part(Vector3.new(0.3, 8, 120), vab * CFrame.new(75.6, 86, 0), C.WHITE, Enum.Material.SmoothPlastic)
	surfaceText(vabName, Enum.NormalId.Right, "EDIFICIO DE ENSAMBLAJE DE VEHÍCULOS", C.NAVY, C.WHITE, 100)
	part(Vector3.new(156, 3, 176), vab * CFrame.new(0, 96.5, 0), Color3.fromRGB(150, 152, 156), METAL)
	ball(folder, 2, vab * CFrame.new(70, 99, 80), C.RED, NEON)                        -- balizas para aviones
	ball(folder, 2, vab * CFrame.new(70, 99, -80), C.RED, NEON)

	-- 5b. Centro de Control de Lanzamiento (bajo, con ventanales)
	local lcc = at(-330, 11, 300)
	part(Vector3.new(90, 22, 40), lcc, BUILDING, Enum.Material.SmoothPlastic, true)
	windows(lcc, 90, 22, 40, 2)
	local lccSign = part(Vector3.new(50, 4, 0.4), lcc * CFrame.new(0, 13, -20.3), C.WHITE, Enum.Material.SmoothPlastic)
	surfaceText(lccSign, Enum.NormalId.Front, "CENTRO DE CONTROL DE LANZAMIENTO", C.NAVY, C.WHITE, 80)

	-- 5c. Oficinas con el nombre en el techo
	for _, info in ipairs({ { -150, 340, 70, 34, 44, "NASA" }, { 140, 360, 60, 52, 40, "NASA" }, { 360, 380, 50, 24, 50, "JPL · LABORATORIOS" } }) do
		local cf = at(info[1], info[4] / 2, info[2])
		part(Vector3.new(info[3], info[4], info[5]), cf, BUILDING, Enum.Material.SmoothPlastic, true)
		windows(cf, info[3], info[4], info[5], math.max(2, math.floor(info[4] / 9)))
		part(Vector3.new(info[3] + 1, 1.2, info[5] + 1), cf * CFrame.new(0, info[4] / 2 + 0.6, 0), C.BLUE, METAL)
		local sign = part(Vector3.new(info[3] * 0.6, 8, 0.6), cf * CFrame.new(0, info[4] / 2 + 5.2, -info[5] / 2 + 2), C.BLUE, Enum.Material.SmoothPlastic)
		surfaceText(sign, Enum.NormalId.Front, info[6], C.WHITE, C.BLUE, 120)
		surfaceText(sign, Enum.NormalId.Back, info[6], C.WHITE, C.BLUE, 120)
	end

	-- 5d. Tanque de agua con el logo
	local tank = at(300, 0, 250)
	for i = 0, 3 do
		local a = math.rad(45 + 90 * i)
		part(Vector3.new(1, 40, 1), tank * CFrame.new(math.cos(a) * 7, 20, math.sin(a) * 7), C.STEEL, METAL)
	end
	cyl(folder, 2, 8, tank * CFrame.new(0, 54, 0), C.STEEL, METAL)
	local tankBody = cyl(folder, 14, 20, tank * CFrame.new(0, 47, 0), C.WHITE, Enum.Material.SmoothPlastic)
	tankBody.CastShadow = false
	local tankLogo = part(Vector3.new(10, 10, 0.1), tank * CFrame.new(0, 47, -10.2), C.WHITE, Enum.Material.SmoothPlastic)
	tankLogo.Transparency = 1
	env.drawNasaLogo(tankLogo, Enum.NormalId.Front)

	-- 5e. Plataformas de lanzamiento lejanas sobre la costa (pararrayos, torre y tanque esférico)
	local function farPad(x, z)
		local cf = at(x, 0, z)
		part(Vector3.new(60, 4, 60), cf * CFrame.new(0, 2, 0), CONCRETE, Enum.Material.Concrete, true)
		for _, p in ipairs({ { -24, -24 }, { 24, -24 }, { -24, 24 }, { 24, 24 } }) do      -- pararrayos
			part(Vector3.new(1.2, 90, 1.2), cf * CFrame.new(p[1], 49, p[2]), C.STEEL, METAL)
		end
		for _, h in ipairs({ 30, 60 }) do
			part(Vector3.new(10, 2, 10), cf * CFrame.new(10, h, 0), C.RED, METAL)
		end
		part(Vector3.new(10, 70, 10), cf * CFrame.new(10, 39, 0), C.RED, METAL).Transparency = 0.55
		ball(folder, 16, cf * CFrame.new(-40, 12, 20), C.WHITE, Enum.Material.SmoothPlastic)
		ball(folder, 1.6, cf * CFrame.new(24, 95, 24), C.RED, NEON)
	end
	farPad(480, -520)
	farPad(470, 320)
	farPad(500, -900)

	-- 6. ÁRBOLES: palmeras junto a las calles y monte bajo en el horizonte --------------------
	local TRUNK = Color3.fromRGB(122, 96, 66)
	local LEAF = Color3.fromRGB(58, 112, 52)
	local function palm(x, z)
		local h = random:NextNumber(14, 22)
		local lean = CFrame.Angles(math.rad(random:NextNumber(-6, 6)), 0, math.rad(random:NextNumber(-6, 6)))
		local base = at(x, 0, z) * lean
		part(Vector3.new(1.2, h, 1.2), base * CFrame.new(0, h / 2, 0), TRUNK, Enum.Material.Wood)
		local top = base * CFrame.new(0, h, 0)
		for i = 0, 6 do
			local leaf = top * CFrame.Angles(0, math.rad(i * 51 + random:NextNumber(0, 20)), 0) * CFrame.new(0, 0, -3.4) * CFrame.Angles(math.rad(-28), 0, 0)
			part(Vector3.new(1.6, 0.3, 7.5), leaf, LEAF, Enum.Material.Grass)
		end
	end
	for z = 250, 880, 45 do
		palm(-18, z)
		palm(18, z + 20)
	end
	for x = -200, 200, 50 do
		palm(x + 12, 246)
	end
	for z = -300, 180, 60 do
		palm(-262, z)
		palm(262, z + 25)
	end
	for _ = 1, 40 do                                                                  -- palmeras sueltas afuera de la reja
		local x, z = random:NextNumber(-700, 540), random:NextNumber(-900, 900)
		if x < -230 or x > 300 or z < -300 or z > 260 then
			if not (x < -340 and x > -520 and z > -140 and z < 60) then              -- no adentro del edificio de ensamblaje
				palm(x, z)
			end
		end
	end
	for i = 0, 47 do                                                                  -- monte en el horizonte (no tapa el mar)
		local a = i / 48 * math.pi * 2
		local x, z = math.cos(a) * 1100, math.sin(a) * 1100
		if x < 520 then
			local h = random:NextNumber(14, 30)
			part(Vector3.new(random:NextNumber(90, 160), h, 50), at(x, h / 2, z) * CFrame.Angles(0, -a, 0), Color3.fromRGB(46, 82, 46), Enum.Material.Grass)
		end
	end

	-- 7. ESTACIONAMIENTO CON AUTOS Y FAROLES ----------------------------------------------
	part(Vector3.new(120, 0.2, 60), at(110, 0.1, 300), ASPHALT, Enum.Material.Asphalt, true)
	local carColors = { C.WHITE, C.RED, C.BLUE, C.STEEL, Color3.fromRGB(30, 30, 34), Color3.fromRGB(200, 170, 60) }
	for row = 0, 1 do
		for i = 0, 7 do
			if random:NextNumber() < 0.75 then
				local car = at(61 + i * 14, 0, 286 + row * 28)
				local color = carColors[random:NextInteger(1, #carColors)]
				part(Vector3.new(4.4, 1.6, 9), car * CFrame.new(0, 1.4, 0), color, Enum.Material.SmoothPlastic)
				part(Vector3.new(4, 1.4, 4.6), car * CFrame.new(0, 2.9, 0.4), GLASS, Enum.Material.Glass).Transparency = 0.2
				for _, w in ipairs({ { -2.1, -3 }, { 2.1, -3 }, { -2.1, 3 }, { 2.1, 3 } }) do
					local wheel = cyl(folder, 0.8, 1.6, car * CFrame.new(w[1], 0.8, w[2]) * CFrame.Angles(0, 0, math.rad(90)), C.DARK, Enum.Material.SmoothPlastic)
					wheel.CastShadow = false
				end
			end
		end
	end
	for z = 240, 900, 80 do                                                           -- faroles de la avenida
		for _, x in ipairs({ -14, 14 }) do
			part(Vector3.new(0.6, 16, 0.6), at(x, 8, z), C.STEEL, METAL)
			local lamp = part(Vector3.new(2.4, 0.6, 1.2), at(x - math.sign(x) * 1.2, 16, z), Color3.fromRGB(255, 226, 170), NEON)
			if z < 600 then
				make("PointLight", { Range = 34, Brightness = 1.2 * Campus.LUZ.focos, Color = Color3.fromRGB(255, 214, 160), Shadows = false }, lamp)
			end
		end
	end

	return folder
end

return Campus
