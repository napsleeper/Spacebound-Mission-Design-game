--[[
	CONSOLAS · ModuleScript (hijo del LocalScript "ControlDeMisionCliente") · v5

	Dibuja las pantallas interactivas sobre partes del mundo (SurfaceGui con Adornee en el
	PlayerGui, así los botones responden al mouse o al toque):
	  · Consola del escritorio de la sala de control: decisiones, corrección orbital y ruta.
	  · Consola del Laboratorio de Ingeniería: elegir prueba, ajustar parámetros, ejecutar.
	  · Consola y pantalla del Centro de Planificación: Hohmann, corrección TCM y Tierra-Luna.
	  · Cámara remota (ViewportFrame) y luz de alerta de la sala de control.
	  · Vista sentado: al ocupar el asiento, la cámara se ubica frente al escritorio.
	    V alterna entre el escritorio y las pantallas grandes.

	Las predicciones usan el mismo módulo Educativo que el servidor: lo que se predice es
	exactamente lo que pasa cuando el comando llega.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Consolas = {}

local player = Players.LocalPlayer
local deps = nil            -- { remote, Educativo, Ingenieria, DatosGMAT, Cinematica }
local mission = nil
local design = nil          -- último resumen del diseño (hangar)
local guis = {}

local BG = Color3.fromRGB(4, 12, 32)
local PANEL = Color3.fromRGB(12, 26, 58)
local BLUE = Color3.fromRGB(11, 61, 145)
local BLUE_HI = Color3.fromRGB(59, 123, 240)
local RED = Color3.fromRGB(252, 61, 33)
local WHITE = Color3.fromRGB(245, 247, 250)
local MUTED = Color3.fromRGB(150, 172, 215)
local GREEN = Color3.fromRGB(61, 255, 122)
local YELLOW = Color3.fromRGB(255, 200, 40)
local CYAN = Color3.fromRGB(56, 189, 248)
local SELECTED = Color3.fromRGB(30, 130, 90)

local function make(className, props, parent)
	local obj = Instance.new(className)
	for key, value in pairs(props) do
		obj[key] = value
	end
	obj.Parent = parent
	return obj
end

local function worldFolder(name)
	local root = workspace:FindFirstChild("ControlDeMision")
	return root and root:FindFirstChild(name)
end

local function findPart(folderName, name)
	local folder = worldFolder(folderName)
	return folder and folder:FindFirstChild(name)
end

-- SurfaceGui interactiva sobre una parte de la carpeta Consolas
local function surface(partName, ppu)
	local entry = guis[partName]
	if entry and entry.gui.Parent and entry.part.Parent then
		return entry
	end
	local part = findPart("Consolas", partName)
	if not part then
		return nil
	end
	if entry then
		entry.gui:Destroy()
	end
	local gui = make("SurfaceGui", {
		Name = "Consola_" .. partName, Adornee = part, Face = Enum.NormalId.Front, Active = true,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = ppu or 100, LightInfluence = 0,
		ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ClipsDescendants = true,
	}, player:WaitForChild("PlayerGui"))
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BG, BorderSizePixel = 0 }, gui)
	entry = { gui = gui, root = root, part = part }
	guis[partName] = entry
	return entry
end

local function clear(entry)
	for _, child in ipairs(entry.root:GetChildren()) do
		child:Destroy()
	end
end

local function label(parent, x, y, w, h, text, color, font, align, maxSize)
	local item = make("TextLabel", {
		Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundTransparency = 1,
		Text = text, TextColor3 = color or WHITE, Font = font or Enum.Font.GothamMedium, TextScaled = true,
		TextWrapped = true, TextXAlignment = align or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
	make("UITextSizeConstraint", { MaxTextSize = maxSize or 34, MinTextSize = 6 }, item)
	return item
end

local function button(parent, x, y, w, h, text, color, onClick)
	local item = make("TextButton", {
		Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundColor3 = color or BLUE,
		BorderSizePixel = 0, AutoButtonColor = true, Text = text, TextColor3 = WHITE, Font = Enum.Font.GothamBold,
		TextScaled = true, TextWrapped = true,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, item)
	make("UITextSizeConstraint", { MaxTextSize = 28, MinTextSize = 6 }, item)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3),
	}, item)
	item.Activated:Connect(onClick)
	return item
end

local function header(root, text, color)
	local bar = make("Frame", { Size = UDim2.fromScale(1, 0.11), BackgroundColor3 = color or BLUE, BorderSizePixel = 0 }, root)
	make("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = RED, BorderSizePixel = 0 }, bar)
	label(bar, 0.03, 0.1, 0.94, 0.8, text, WHITE, Enum.Font.GothamBlack, nil, 30)
	return bar
end

local function panel(root, x, y, w, h)
	local frame = make("Frame", {
		Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundColor3 = PANEL, BorderSizePixel = 0,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, frame)
	return frame
end

---------------------------------------------------------------------------
-- TARJETA: ícono gigante en un círculo de color, título, una frase y fichas.
-- La usan la consola del escritorio y los monitores grandes (ver ControlDeMisionCliente).
-- c = { icono, color = "verde"|"rojo"|"amarillo"|"azul", titulo, linea, chips = { { texto, ok } } }
---------------------------------------------------------------------------
local CARD_COLORS = { verde = GREEN, rojo = RED, amarillo = YELLOW, azul = BLUE_HI }

function Consolas.tarjeta(parent, c)
	local color = CARD_COLORS[c.color] or WHITE
	local root = make("Frame", { Name = "Tarjeta", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BG, BorderSizePixel = 0 }, parent)
	make("Frame", { Size = UDim2.fromScale(1, 0.035), BackgroundColor3 = color, BorderSizePixel = 0 }, root)
	-- círculo del ícono: su tamaño depende del alto, así queda redondo en cualquier pantalla
	local circle = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.04, 0.42), Size = UDim2.fromScale(0.58, 0.58),
		SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundColor3 = color, BorderSizePixel = 0,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, circle)
	label(circle, 0.12, 0.12, 0.76, 0.76, c.icono or "", BG, Enum.Font.GothamBlack, Enum.TextXAlignment.Center, 400)
	label(root, 0.42, 0.12, 0.54, 0.3, c.titulo or "", color, Enum.Font.GothamBlack, nil, 120)
	label(root, 0.42, 0.44, 0.54, 0.28, c.linea or "", WHITE, Enum.Font.GothamMedium, nil, 56)
	local chips = c.chips or {}
	local count = #chips
	if count > 0 then
		local gap = 0.015
		local width = (0.92 - gap * (count - 1)) / count
		for i, chip in ipairs(chips) do
			local tone = chip.ok == true and GREEN or (chip.ok == false and RED or MUTED)
			local box = make("Frame", {
				Position = UDim2.fromScale(0.04 + (i - 1) * (width + gap), 0.78), Size = UDim2.fromScale(width, 0.16),
				BackgroundColor3 = PANEL, BorderSizePixel = 0,
			}, root)
			make("UICorner", { CornerRadius = UDim.new(0.25, 0) }, box)
			make("UIStroke", { Color = tone, Thickness = 3 }, box)
			-- las fichas de cambios (+/−) ya dicen si es bueno o malo con el color; el ✓/✗ va en los objetivos
			local prefix = ""
			if not chip.cambio then
				prefix = chip.ok == true and "✓ " or (chip.ok == false and "✗ " or "")
			end
			label(box, 0.05, 0.1, 0.9, 0.8, prefix .. (chip.texto or ""), WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Center, 48)
		end
	end
	return root
end

local function fmt(n, decimals)
	local s = string.format("%." .. (decimals or 0) .. "f", n)
	local int, dec = s:match("^(-?%d+)%.?(%d*)$")
	int = int or s
	local formatted = int:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^(-?)%.", "%1")
	if dec and dec ~= "" then
		return formatted .. "," .. dec
	end
	return formatted
end

---------------------------------------------------------------------------
-- GRÁFICO DE VUELO: trayectoria resultante de la maniobra (sobre la pantalla del servidor)
---------------------------------------------------------------------------
local function graphResult()
	local part = findPart("Graficos", "probe")
	local gui = part and part:FindFirstChild("Grafico")
	local canvas = gui and gui:FindFirstChild("Lienzo")
	return canvas and canvas:FindFirstChild("Resultado")
end

-- v8: dibuja la trayectoria hacia Júpiter que resultaría con el error de velocidad que quedó
-- (err en m/s; con error 0 coincide con la trayectoria real). Exagerado para que se vea.
local function drawOrbit(err, transparency, textLine)
	local holder = graphResult()
	if not holder then
		return
	end
	holder:ClearAllChildren()
	if not err then
		return
	end
	local E = deps.Educativo
	local miss = math.clamp(err / E.MANIOBRA.requerido, -3, 3) * 0.06
	for i = 0, 44 do
		local n = i / 44 * 0.35
		local x, y = E.trayectoriaGrafico(n, miss * (n / 0.35))
		local dot = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(7, 7), BackgroundColor3 = YELLOW, BackgroundTransparency = transparency, BorderSizePixel = 0,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
	end
	if textLine then
		label(holder, 0.02, 0.84, 0.6, 0.06, textLine, YELLOW, Enum.Font.Code, nil, 40)
	end
end

---------------------------------------------------------------------------
-- 1. CONSOLA DEL ESCRITORIO (sala de control)
---------------------------------------------------------------------------
local desk = { data = nil, dv = 0, dir = "retro", momento = 1, angulo = 16, vel = 1 }
local renderDesk

local function sendManeuver()
	if desk.data and desk.data.mode == "maneuver" then
		deps.remote:FireServer("maneuver", { dv = desk.dv, dir = desk.dir, momento = desk.momento })
	elseif desk.data and desk.data.mode == "route" then
		deps.remote:FireServer("route", { angulo = desk.angulo, vel = desk.vel })
	end
end

local function renderManeuver(root, d)
	local E = deps.Educativo
	local M = E.MANIOBRA
	local p = d.params
	header(root, d.title or "CORRECCIÓN ORBITAL")
	local left = panel(root, 0.02, 0.13, 0.47, 0.84)
	label(left, 0.04, 0.02, 0.92, 0.1, "Δv", MUTED, Enum.Font.GothamBold)
	button(left, 0.04, 0.13, 0.2, 0.15, "−", BLUE, function()
		desk.dv = math.max(0, desk.dv - M.paso)
		renderDesk()
	end)
	label(left, 0.26, 0.13, 0.48, 0.15, desk.dv .. " m/s", WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	button(left, 0.76, 0.13, 0.2, 0.15, "+", BLUE, function()
		desk.dv = math.min(M.maxDv, desk.dv + M.paso)
		renderDesk()
	end)
	label(left, 0.04, 0.31, 0.92, 0.09, "DIRECCIÓN", MUTED, Enum.Font.GothamBold)
	button(left, 0.04, 0.41, 0.45, 0.14, "◀ FRENAR\nretrógrada", desk.dir == "retro" and SELECTED or BLUE, function()
		desk.dir = "retro"
		renderDesk()
	end)
	button(left, 0.51, 0.41, 0.45, 0.14, "ACELERAR ▶\nprograda", desk.dir == "pro" and SELECTED or BLUE, function()
		desk.dir = "pro"
		renderDesk()
	end)
	label(left, 0.04, 0.58, 0.92, 0.09, "⏱ CUÁNDO", MUTED, Enum.Font.GothamBold)
	for i, m in ipairs(M.momentos) do
		button(left, 0.04 + (i - 1) * 0.31, 0.68, 0.29, 0.16, m.nombre .. "\n" .. m.espera, desk.momento == i and SELECTED or BLUE, function()
			desk.momento = i
			renderDesk()
		end)
	end
	label(left, 0.04, 0.87, 0.92, 0.11, "🎯 NASA 2006: 5 + 13,3 m/s · día 9", CYAN, Enum.Font.Code)

	-- Predicción: los mismos números de siempre, con íconos en vez de frases
	local pred = E.prediccionManiobra(p, desk.dv, desk.dir, desk.momento)
	local right = panel(root, 0.51, 0.13, 0.47, 0.68)
	label(right, 0.04, 0.02, 0.92, 0.11, "PREDICCIÓN", YELLOW, Enum.Font.GothamBold)
	local colors = { nominal = GREEN, insuficiente = YELLOW, excesiva = YELLOW }
	local names = { nominal = "✓ RUMBO A JÚPITER", insuficiente = "! TE QUEDÁS CORTO", excesiva = "! TE PASÁS" }
	local lines = {
		string.format("⛽ %s / %s kg", fmt(pred.consumo, 1), fmt(p.combustible, 1)),
		string.format("🚀 Δv real %+d m/s (%d %%)", math.floor(pred.efectivo + 0.5), math.floor(pred.momento.rendimiento * 100)),
		string.format("🎯 Error %+d m/s", math.floor(pred.error + 0.5)),
		string.format("⏱ Quema %s s (4 × 4,4 N)", fmt(pred.duracion)),
		string.format("🛡️ −%d %%", pred.danio),
	}
	label(right, 0.04, 0.15, 0.92, 0.6, table.concat(lines, "\n"), WHITE, Enum.Font.Code, nil, 26)
	label(right, 0.04, 0.78, 0.92, 0.18, (pred.alcanza and "" or "✗ SIN PROPELENTE · ") .. names[pred.estado],
		pred.alcanza and colors[pred.estado] or RED, Enum.Font.GothamBlack)
	button(root, 0.51, 0.83, 0.47, 0.14, "ENVIAR COMANDO ▶", RED, sendManeuver)
	drawOrbit(pred.error, 0.6, "PREVISTA: error " .. string.format("%+d", math.floor(pred.error + 0.5)) .. " m/s")
end

local function renderRoute(root, d)
	local E = deps.Educativo
	local R = E.RUTA
	local p = d.params
	header(root, d.title or "RUTA DE DESCENSO")
	local left = panel(root, 0.02, 0.13, 0.47, 0.84)
	label(left, 0.04, 0.02, 0.92, 0.1, "📐 ÁNGULO", MUTED, Enum.Font.GothamBold)
	button(left, 0.04, 0.13, 0.2, 0.16, "−", BLUE, function()
		desk.angulo = math.max(R.minAngulo, desk.angulo - R.paso)
		renderDesk()
	end)
	label(left, 0.26, 0.13, 0.48, 0.16, desk.angulo .. "°", WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	button(left, 0.76, 0.13, 0.2, 0.16, "+", BLUE, function()
		desk.angulo = math.min(R.maxAngulo, desk.angulo + R.paso)
		renderDesk()
	end)
	label(left, 0.04, 0.33, 0.92, 0.1, "🏁 VELOCIDAD", MUTED, Enum.Font.GothamBold)
	for i, v in ipairs(R.velocidades) do
		button(left, 0.04 + (i - 1) * 0.47, 0.44, 0.45, 0.16, v.nombre .. "\n" .. fmt(v.v * 100, 1) .. " cm/s", desk.vel == i and SELECTED or BLUE, function()
			desk.vel = i
			renderDesk()
		end)
	end
	label(left, 0.04, 0.66, 0.92, 0.3, string.format("⛰️ Bajada %d m\n🛞 Aguanta hasta %d°", R.desnivel, p.pendienteMax), CYAN, Enum.Font.Code)

	-- Predicción: los mismos números de siempre, con íconos en vez de frases
	local pred = E.prediccionRuta(p, desk.angulo, desk.vel)
	local right = panel(root, 0.51, 0.13, 0.47, 0.68)
	label(right, 0.04, 0.02, 0.92, 0.11, "PREDICCIÓN", YELLOW, Enum.Font.GothamBold)
	local lines = {
		string.format("📏 %s km · ⏱ %s h", fmt(pred.distancia / 1000, 2), fmt(pred.horas, 1)),
		string.format("☀ %d soles de manejo", pred.soles),
		string.format("⚡ −%d %% por sol (%d W)", pred.energiaPct, math.floor(pred.potencia + 0.5)),
		string.format("⚠ Riesgo %d %%", math.floor(pred.riesgo * 100 + 0.5)),
	}
	label(right, 0.04, 0.15, 0.92, 0.6, table.concat(lines, "\n"), WHITE, Enum.Font.Code, nil, 26)
	local names = { ok = "✓ BAJADA SEGURA", patinaje = "! PUEDE PATINAR", atasco = "✗ SE ATASCA" }
	local colors = { ok = GREEN, patinaje = YELLOW, atasco = RED }
	label(right, 0.04, 0.78, 0.92, 0.18, names[pred.estado], colors[pred.estado], Enum.Font.GothamBlack)
	button(root, 0.51, 0.83, 0.47, 0.14, "ENVIAR COMANDO ▶", RED, sendManeuver)
end

local function renderDecision(root, d)
	header(root, d.title or "DECISIÓN")
	label(root, 0.03, 0.13, 0.94, 0.17, d.situation or "", MUTED, Enum.Font.GothamMedium, nil, 24)
	local colors = { BLUE_HI, RED, Color3.fromRGB(30, 150, 120) }
	for i, option in ipairs(d.options or {}) do
		local x = 0.02 + (i - 1) * 0.327
		local b = button(root, x, 0.32, 0.31, 0.64, "", colors[i], function()
			deps.remote:FireServer("decide", i)
		end)
		b.Text = ""
		label(b, 0.04, 0.02, 0.92, 0.2, option.label .. "  [" .. i .. "]", WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
		label(b, 0.04, 0.24, 0.92, 0.72, option.text, WHITE, Enum.Font.GothamMedium, Enum.TextXAlignment.Center, 26)
	end
end

renderDesk = function()
	if not mission then
		return
	end
	local entry = surface(mission .. "-consola", 100)
	if not entry then
		return
	end
	clear(entry)
	local root = entry.root
	local d = desk.data or { mode = "idle", text = "SALA DE CONTROL · EN ESPERA" }
	if d.mission and d.mission ~= mission then
		return
	end
	if d.mode == "maneuver" then
		renderManeuver(root, d)
	elseif d.mode == "route" then
		renderRoute(root, d)
	elseif d.mode == "decision" then
		renderDecision(root, d)
	else
		local titles = { idle = "CONSOLA DE OPERACIONES", wait = "TRANSMITIENDO", result = "RESULTADO", report = "INFORME FINAL" }
		header(root, titles[d.mode] or "CONSOLA", d.mode == "wait" and Color3.fromRGB(120, 80, 10) or BLUE)
		if type(d.card) == "table" then
			local holder = make("Frame", { Position = UDim2.fromScale(0, 0.11), Size = UDim2.fromScale(1, 0.89), BackgroundTransparency = 1 }, root)
			Consolas.tarjeta(holder, d.card)
		else
			if d.mark then
				label(root, 0.03, 0.13, 0.94, 0.12, d.mark, d.mark:find("✓") and GREEN or (d.mark:find("✗") and RED or YELLOW), Enum.Font.GothamBlack)
			end
			label(root, 0.03, d.mark and 0.27 or 0.15, 0.94, d.mark and 0.7 or 0.82, d.text or "", WHITE, Enum.Font.GothamMedium, nil, 28)
		end
	end
end

---------------------------------------------------------------------------
-- 2. CÁMARA REMOTA Y LUZ DE ALERTA
---------------------------------------------------------------------------
local cam = { built = false, camera = nil, vehicle = nil, flame = nil, flameUntil = 0 }

local function buildCamera()
	if not mission then
		return
	end
	local entry = surface(mission .. "-camara", 40)
	if not entry then
		return
	end
	clear(entry)
	local root = entry.root
	local viewport = make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
		Ambient = Color3.fromRGB(110, 115, 130), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-1, -0.6, -0.4),
	}, root)
	local camera = make("Camera", { FieldOfView = 50 }, viewport)
	viewport.CurrentCamera = camera
	cam.camera = camera
	local folder = workspace:FindFirstChild("ControlDeMision")
	local own = folder and folder:FindFirstChild("Jugador_" .. player.UserId)
	local source = own and own:FindFirstChild("Nave")
	if source then
		local clone = source:Clone()
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 0
			end
		end
		-- la nave está armada a escala reducida: se centra la sonda y el rover se apoya en el suelo
		clone:PivotTo(CFrame.new(0, mission == "probe" and -3 or 0, 0))
		clone.Parent = viewport
		cam.vehicle = clone
	end
	if mission == "probe" then
		-- v8: el fondo cambia con la etapa del viaje (Tierra que se aleja, Júpiter, Plutón y Caronte)
		local stages = {
			{ color = Color3.fromRGB(40, 90, 170), size = 160, pos = Vector3.new(30, -110, 60), name = "TIERRA (SE ALEJA)" },
			{ color = Color3.fromRGB(200, 150, 100), size = 260, pos = Vector3.new(60, -40, 190), name = "JÚPITER · 2,3 MILLONES DE KM", bands = true },
			{ color = Color3.fromRGB(196, 160, 128), size = 120, pos = Vector3.new(40, -70, 80), name = "PLUTÓN · 12.500 KM", heart = true },
		}
		local st = stages[math.clamp((cam.stage or 0) + 1, 1, 3)]
		local planet = make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(st.size, st.size, st.size), Position = st.pos, Color = st.color, Material = Enum.Material.SmoothPlastic, Anchored = true }, viewport)
		planet.Name = "Planeta"
		local R = st.size / 2
		if st.bands then
			for i, h in ipairs({ -0.55, -0.3, -0.05, 0.22, 0.48 }) do
				local d = 2 * math.sqrt(math.max(0, R * R - (h * R) ^ 2)) + 0.6
				make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 0.09, d, d), CFrame = CFrame.new(st.pos + Vector3.new(0, h * R, 0)) * CFrame.Angles(0, 0, math.rad(90)),
					Color = i % 2 == 0 and Color3.fromRGB(150, 96, 60) or Color3.fromRGB(230, 200, 160), Material = Enum.Material.SmoothPlastic, Anchored = true }, viewport)
			end
		end
		if st.heart then                                     -- la región clara con forma de corazón (Tombaugh Regio)
			local toCam = (Vector3.new(0, 0, 0) - st.pos).Unit
			make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.9, R * 0.8, R * 0.9), Position = st.pos + toCam * R * 0.78, Color = Color3.fromRGB(240, 226, 210), Material = Enum.Material.SmoothPlastic, Anchored = true }, viewport)
			make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(R, R, R), Position = st.pos + Vector3.new(-R * 2.6, R * 0.8, R * 1.5), Color = Color3.fromRGB(150, 150, 155), Material = Enum.Material.SmoothPlastic, Anchored = true }, viewport)
		end
		cam.stageName = st.name
		local flame = make("Part", { Size = Vector3.new(1.4, 1.4, 6), CFrame = CFrame.new(0, 0, 6), Color = Color3.fromRGB(255, 150, 50), Material = Enum.Material.Neon, Anchored = true, Transparency = 1 }, viewport)
		cam.flame = flame
	else
		-- suelo y rocas de Marte, con cielo color caramelo
		viewport.BackgroundColor3 = Color3.fromRGB(196, 140, 104)
		viewport.Ambient = Color3.fromRGB(150, 110, 90)
		make("Part", { Size = Vector3.new(220, 2, 220), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(184, 98, 58), Material = Enum.Material.Sand, Anchored = true }, viewport)
		local random = Random.new(11)
		for _ = 1, 30 do
			local s = random:NextNumber(0.5, 2.5)
			make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(s, s * 0.7, s), Position = Vector3.new(random:NextNumber(-60, 60), 0, random:NextNumber(-60, 60)), Color = Color3.fromRGB(122, 64, 42), Material = Enum.Material.Basalt, Anchored = true }, viewport)
		end
		make("Part", { Size = Vector3.new(220, 40, 2), Position = Vector3.new(0, 10, 80), Color = Color3.fromRGB(160, 84, 52), Material = Enum.Material.Sandstone, Anchored = true }, viewport)
	end
	local bar = make("Frame", { Size = UDim2.fromScale(1, 0.1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0 }, root)
	label(bar, 0.02, 0.1, 0.7, 0.8, "CÁMARA REMOTA (SIMULADA) · " .. (mission == "probe" and ("NEW HORIZONS · " .. (cam.stageName or "")) or "PERSEVERANCE · JEZERO"), WHITE, Enum.Font.Code, nil, 40)
	cam.rec = label(bar, 0.75, 0.1, 0.23, 0.8, "● REC", RED, Enum.Font.Code, Enum.TextXAlignment.Right, 40)
	cam.delay = label(root, 0.02, 0.9, 0.96, 0.08, "", YELLOW, Enum.Font.Code, nil, 32)
	cam.built = true
end

function Consolas.burn()
	cam.flameUntil = os.clock() + 2.5
end

-- Etapa del viaje de New Horizons para el fondo de la cámara remota (0 Tierra, 1 Júpiter, 2+ Plutón)
function Consolas.setStage(index)
	index = math.clamp(tonumber(index) or 0, 0, 2)
	if cam.stage ~= index then
		cam.stage = index
		cam.built = false
		if mission == "probe" then
			buildCamera()
		end
	end
end

local alertOn = false

---------------------------------------------------------------------------
-- 3. CONSOLA DEL LABORATORIO DE INGENIERÍA
---------------------------------------------------------------------------
local lab = { index = 1, values = {}, status = "Elegí una prueba y ejecutala.", statusColor = MUTED }
local renderLab

local function labTests()
	return mission and deps.Ingenieria.PRUEBAS[mission] or {}
end

local function labValues(test)
	if not lab.values[test.clave] then
		lab.values[test.clave] = deps.Ingenieria.defaults(test)
	end
	return lab.values[test.clave]
end

renderLab = function()
	local entry = surface("lab-consola", 100)
	if not entry then
		return
	end
	clear(entry)
	local root = entry.root
	header(root, "LABORATORIO DE INGENIERÍA" .. (mission and (" · " .. (mission == "probe" and "NEW HORIZONS" or "PERSEVERANCE")) or ""), Color3.fromRGB(120, 20, 10))
	local tests = labTests()
	if #tests == 0 then
		label(root, 0.05, 0.3, 0.9, 0.4, "Elegí una misión para usar el laboratorio.", MUTED, nil, Enum.TextXAlignment.Center)
		return
	end
	lab.index = math.clamp(lab.index, 1, #tests)
	for i, test in ipairs(tests) do
		button(root, 0.02 + (i - 1) * 0.327, 0.13, 0.31, 0.12, test.nombre, lab.index == i and SELECTED or BLUE, function()
			lab.index = i
			renderLab()
		end)
	end
	local test = tests[lab.index]
	local values = labValues(test)
	for row, p in ipairs(test.params) do
		local y = 0.28 + (row - 1) * 0.165
		label(root, 0.03, y, 0.38, 0.14, p.nombre, WHITE, Enum.Font.GothamBold, nil, 24)
		if p.opciones then
			local w = 0.55 / #p.opciones
			for k, option in ipairs(p.opciones) do
				button(root, 0.43 + (k - 1) * w, y, w - 0.01, 0.14, option, values[p.clave] == k and SELECTED or BLUE, function()
					values[p.clave] = k
					renderLab()
				end)
			end
		else
			button(root, 0.43, y, 0.1, 0.14, "−", BLUE, function()
				values[p.clave] = math.max(p.min, values[p.clave] - p.paso)
				renderLab()
			end)
			local shown = p.paso < 1 and fmt(values[p.clave], 1) or fmt(values[p.clave])
			label(root, 0.54, y, 0.32, 0.14, shown .. " " .. p.unidad, YELLOW, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
			button(root, 0.87, y, 0.1, 0.14, "+", BLUE, function()
				values[p.clave] = math.min(p.max, values[p.clave] + p.paso)
				renderLab()
			end)
		end
	end
	label(root, 0.03, 0.8, 0.55, 0.17, lab.status, lab.statusColor, Enum.Font.GothamMedium, nil, 22)
	button(root, 0.6, 0.82, 0.38, 0.15, "EJECUTAR PRUEBA ▶", RED, function()
		lab.status = "Ejecutando " .. test.nombre:lower() .. "…"
		lab.statusColor = YELLOW
		renderLab()
		deps.remote:FireServer("labRun", { test = test.clave, values = values })
	end)
end

-- Animación de la rampa de movilidad
local function animateRamp(slope, advance)
	local rig = findPart("Consolas", "lab-rampa")
	local ramp = rig and rig:FindFirstChild("Rampa")
	local mini = rig and rig:FindFirstChild("MiniRover")
	local hinge = rig and rig:GetAttribute("Bisagra")
	if not ramp or not mini or not hinge then
		return
	end
	local length = ramp:GetAttribute("Largo") or 8
	local t0 = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local angle = math.rad(slope) * math.clamp(t / 1.2, 0, 1)
		local tilt = CFrame.new(hinge) * CFrame.Angles(0, 0, angle)
		ramp.CFrame = tilt * CFrame.new(length / 2, 0, 0)
		local climb = math.clamp((t - 1.2) / 3, 0, 1)
		local s = 1.2 + advance * (length - 2.4) * climb
		if advance < 0.4 and t > 4.2 then                -- no puede: patina y vuelve
			s = 1.2 + advance * (length - 2.4) * math.clamp(1 - (t - 4.2) / 1.5, 0, 1)
		end
		mini:PivotTo(tilt * CFrame.new(s, 0.5, 0))
		if t > 6 then
			connection:Disconnect()
		end
	end)
end

---------------------------------------------------------------------------
-- 4. CENTRO DE PLANIFICACIÓN
---------------------------------------------------------------------------
-- v8: tres pestañas con datos reales y cálculos Luau (no se ejecutó GMAT):
--   1. HOHMANN: transferencia ideal de la Tierra a Marte, Júpiter o Plutón vs. el viaje real
--   2. TCM-1: la corrección real de New Horizons (2006) contra el Δv de tu diseño
--   3. JÚPITER: la asistencia gravitatoria, comparada con lo que puede hacer la hidracina
local DESTINOS = {
	{ indice = 2, real = "Perseverance: 203 días (2020-2021)", realDias = 203 },
	{ indice = 3, real = "New Horizons: 405 días (2006-2007)", realDias = 405 },
	{ indice = 4, real = "New Horizons: 9,5 años con Júpiter", realDias = 3463 },
}
local plan = { tab = 1, dest = 3, saved = {} }
local renderPlan

local function designDv()
	if design and design.propulsion and design.propulsion.isp > 0 then
		return design.propulsion
	end
	return nil
end

local function planHohmann()
	local E = deps.Educativo
	local planeta = E.PLANETAS[DESTINOS[plan.dest].indice]
	return E.hohmannPlaneta(planeta.a), planeta
end

local function daysText(dias)
	if dias >= 730 then
		return fmt(dias / 365.25, 1) .. " años"
	end
	return fmt(dias) .. " días"
end

local function drawPlanScreen()
	local entry = surface("plan-pantalla", 40)
	if not entry then
		return
	end
	clear(entry)
	local root = entry.root
	local E = deps.Educativo
	local NH = E.REAL.newHorizons
	local bar = make("Frame", { Size = UDim2.fromScale(1, 0.09), BackgroundColor3 = BLUE, BorderSizePixel = 0 }, root)
	make("Frame", { Size = UDim2.new(0, 10, 1, 0), BackgroundColor3 = RED, BorderSizePixel = 0 }, bar)
	local titles = { "TRANSFERENCIA DE HOHMANN", "CORRECCIÓN TCM-1 DE NEW HORIZONS", "JÚPITER: ASISTENCIA GRAVITATORIA" }
	label(bar, 0.02, 0.1, 0.6, 0.8, "PLANIFICACIÓN · " .. titles[plan.tab], WHITE, Enum.Font.GothamBlack, nil, 40)
	local source = plan.tab == 1 and "FUENTE: CÁLCULO LUAU (vis-viva) + NASA/JPL" or "FUENTE: DATOS NASA/JHUAPL + CÁLCULO LUAU"
	label(bar, 0.62, 0.15, 0.36, 0.7, source, YELLOW, Enum.Font.Code, Enum.TextXAlignment.Right, 30)

	-- área de dibujo: cuadrada a la izquierda
	local area = make("Frame", { Position = UDim2.fromScale(0.01, 0.11), Size = UDim2.fromScale(0.5, 0.87), BackgroundTransparency = 1 }, root)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, area)
	local function dot(x, y, size, color, transparency)
		local d = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + x, 0.5 + y), Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = color, BackgroundTransparency = transparency or 0, BorderSizePixel = 0,
		}, area)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, d)
		return d
	end
	local function circle(radius, color, n)
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2
			dot(math.cos(a) * radius, math.sin(a) * radius, 4, color)
		end
	end
	-- radio en pantalla: raíz de la distancia (escala no lineal, para que entren Marte y Plutón)
	local function rad(aUA)
		return 0.075 * math.sqrt(aUA)
	end
	local info = {}
	if plan.tab == 1 then
		local h, planeta = planHohmann()
		local destino = DESTINOS[plan.dest]
		dot(0, 0, 22, YELLOW).ZIndex = 2
		circle(rad(1), CYAN, 50)
		circle(rad(planeta.a), GREEN, 110)
		for i = 0, 60 do                                       -- media elipse de transferencia
			local t = math.pi * i / 60
			local r = rad(1) + (rad(planeta.a) - rad(1)) * (1 - math.cos(t)) / 2
			dot(math.cos(t) * r, -math.sin(t) * r, 6, YELLOW)
		end
		dot(rad(1), 0, 14, BLUE_HI)
		dot(-rad(planeta.a), 0, 14, RED)
		local dias = h.tiempo / 86400
		table.insert(info, string.format("Tierra (1 UA) → %s (%s UA)", planeta.nombre, fmt(planeta.a, 2)))
		table.insert(info, string.format("Salida: +%s km/s sobre los 29,8 km/s de la Tierra", fmt(h.dv1 / 1000, 2)))
		table.insert(info, string.format("Llegada: %s km/s", fmt(h.dv2 / 1000, 2)))
		table.insert(info, string.format("Viaje de Hohmann: %s", daysText(dias)))
		table.insert(info, "")
		table.insert(info, "REAL · " .. destino.real)
		if destino.realDias < dias then
			table.insert(info, string.format("La misión real tardó %d %% menos: más velocidad de salida%s.",
				math.floor((1 - destino.realDias / dias) * 100 + 0.5), plan.dest == 3 and " y Júpiter" or ""))
		end
		local p = designDv()
		if p then
			table.insert(info, string.format("Tu sonda: %s m/s propios. La salida la pone el cohete.", fmt(p.dv)))
		end
	elseif plan.tab == 2 then
		-- Sol, órbita de la Tierra y el comienzo de la trayectoria con la TCM-1
		dot(-0.3, 0.1, 26, YELLOW).ZIndex = 2
		for i = 0, 70 do
			local a = i / 70 * math.pi * 2
			dot(-0.3 + math.cos(a) * 0.2, 0.1 + math.sin(a) * 0.2, 4, CYAN)
		end
		for i = 0, 40 do
			local t = i / 40
			dot(-0.1 + t * 0.55, 0.1 - t * 0.45 + t * t * 0.1, 6, GREEN)
		end
		dot(-0.1, 0.1, 14, BLUE_HI)
		dot(-0.06, 0.06, 16, RED)
		local total = 0
		for _, tcm in ipairs(NH.tcm1) do
			total += tcm.dv
			table.insert(info, string.format("%s · %s: %s m/s", tcm.nombre, tcm.fecha, fmt(tcm.dv, 1)))
		end
		table.insert(info, string.format("TOTAL: %s m/s · reservado para correcciones: %d m/s", fmt(total, 1), NH.tcmPresupuesto))
		local p = designDv()
		if p then
			local fuel = E.propelenteParaDv(p.isp, p.m0, total)
			table.insert(info, "")
			table.insert(info, string.format("LUAU · con tu sonda: %s kg de propelente", fmt(fuel, 2)))
			table.insert(info, string.format("Quema con 4 × 4,4 N: %s s (t = m·Δv/F)", fmt(E.duracionQuema(p.m0, total, 17.6))))
			table.insert(info, string.format("Δv disponible: %s m/s (margen %s m/s)", fmt(p.dv), fmt(p.dv - total)))
		else
			table.insert(info, "Armá la propulsión para comparar con tu diseño.")
		end
	else
		-- Júpiter dobla la trayectoria y le suma velocidad
		dot(-0.38, 0.32, 20, YELLOW)
		dot(0.12, -0.05, 70, Color3.fromRGB(200, 150, 100)).ZIndex = 2
		for i = 0, 50 do
			local t = i / 50
			local x = -0.4 + t * 0.85
			local y = 0.3 - t * 0.35 - math.sin(t * math.pi) * 0.08
			dot(x, y, 6, GREEN)
		end
		local p = designDv()
		local veces = p and p.dv > 0 and (NH.jupiter.ganancia * 1000 / p.dv) or nil
		table.insert(info, string.format("%s · a %s millones de km de Júpiter", NH.jupiter.fecha, fmt(NH.jupiter.distanciaKm / 1e6, 1)))
		table.insert(info, string.format("Ganancia: casi %d km/s sin gastar propelente", NH.jupiter.ganancia))
		table.insert(info, "El viaje a Plutón se acortó unos 3 años.")
		table.insert(info, "")
		if veces then
			table.insert(info, string.format("Tu sonda tiene %s m/s propios:", fmt(p.dv)))
			table.insert(info, string.format("Júpiter le dio %s veces más.", fmt(veces, 1)))
		end
		local hp = E.hohmannPlaneta(E.PLANETAS[4].a)
		table.insert(info, string.format("Sin asistencias, Hohmann a Plutón: %s", daysText(hp.tiempo / 86400)))
	end
	local side = make("Frame", { Position = UDim2.fromScale(0.52, 0.11), Size = UDim2.fromScale(0.47, 0.87), BackgroundColor3 = PANEL, BorderSizePixel = 0 }, root)
	label(side, 0.03, 0.02, 0.94, 0.62, table.concat(info, "\n"), WHITE, Enum.Font.Code, nil, 30)
	label(side, 0.03, 0.66, 0.94, 0.07, "ESCENARIOS GUARDADOS (comparación)", MUTED, Enum.Font.GothamBold, nil, 26)
	local rows = {}
	for i, s in ipairs(plan.saved) do
		table.insert(rows, string.format("%d. %s", i, s.nombre))
	end
	label(side, 0.03, 0.74, 0.94, 0.24, #rows > 0 and table.concat(rows, "\n") or "Todavía no guardaste escenarios.", CYAN, Enum.Font.Code, nil, 26)
end

renderPlan = function()
	local entry = surface("plan-consola", 100)
	if not entry then
		return
	end
	clear(entry)
	local root = entry.root
	header(root, "CENTRO DE PLANIFICACIÓN DE MISIONES", Color3.fromRGB(10, 90, 60))
	local tabs = { "HOHMANN", "TCM-1 REAL", "JÚPITER" }
	for i, name in ipairs(tabs) do
		button(root, 0.02 + (i - 1) * 0.327, 0.13, 0.31, 0.13, name, plan.tab == i and SELECTED or BLUE, function()
			plan.tab = i
			renderPlan()
		end)
	end
	local E = deps.Educativo
	if plan.tab == 1 then
		label(root, 0.03, 0.31, 0.36, 0.13, "Destino", WHITE, Enum.Font.GothamBold)
		for i, destino in ipairs(DESTINOS) do
			local planeta = E.PLANETAS[destino.indice]
			button(root, 0.3 + (i - 1) * 0.23, 0.31, 0.21, 0.13, planeta.nombre, plan.dest == i and SELECTED or BLUE, function()
				plan.dest = i
				renderPlan()
			end)
		end
		local h = planHohmann()
		label(root, 0.03, 0.5, 0.94, 0.25, string.format("Hohmann: %s\nReal: %s", daysText(h.tiempo / 86400), DESTINOS[plan.dest].real), GREEN, Enum.Font.Code)
	else
		label(root, 0.03, 0.31, 0.94, 0.45, plan.tab == 2
			and "La corrección real de New Horizons en 2006.\nComparala con el Δv de tu sonda (cálculo Luau).\nEn la sala de control vas a hacer esta corrección."
			or "Júpiter le regaló casi 4 km/s a New Horizons.\nCompará eso con lo que puede hacer su hidracina:\nel gran cambio de velocidad lo dan el cohete y Júpiter.", MUTED, Enum.Font.GothamMedium, nil, 24)
	end
	button(root, 0.03, 0.82, 0.45, 0.15, "GUARDAR ESCENARIO", BLUE_HI, function()
		local nombre
		if plan.tab == 1 then
			local h, planeta = planHohmann()
			nombre = string.format("Hohmann a %s: %s", planeta.nombre, daysText(h.tiempo / 86400))
		elseif plan.tab == 2 then
			nombre = "TCM-1 real: 18,3 m/s (NASA)"
		else
			nombre = "Júpiter: +4 km/s gratis"
		end
		table.insert(plan.saved, 1, { nombre = nombre })
		while #plan.saved > 3 do
			table.remove(plan.saved)
		end
		renderPlan()
	end)
	button(root, 0.52, 0.82, 0.45, 0.15, "BORRAR COMPARACIÓN", Color3.fromRGB(80, 30, 30), function()
		plan.saved = {}
		renderPlan()
	end)
	drawPlanScreen()
end

---------------------------------------------------------------------------
-- 5. VISTA SENTADO EN EL PUESTO
---------------------------------------------------------------------------
local seatView = { active = false, mode = "desk", cf = nil }
local hintGui, viewButton

local function seatedSeat()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat.Name:match("%-Asiento$") then
		return seat, character
	end
	return nil
end

local function setCharacterHidden(character, hidden)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function toggleView()
	if seatView.active then
		seatView.mode = seatView.mode == "desk" and "screens" or "desk"
		if viewButton then
			viewButton.Text = seatView.mode == "desk" and "VER PANTALLAS (V)" or "VER ESCRITORIO (V)"
		end
	end
end

local function buildHint()
	hintGui = make("ScreenGui", { Name = "VistaPuesto", ResetOnSpawn = false, Enabled = false, DisplayOrder = 6 }, player:WaitForChild("PlayerGui"))
	local frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(470, 30),
		BackgroundColor3 = BG, BackgroundTransparency = 0.25, BorderSizePixel = 0,
	}, hintGui)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, frame)
	viewButton = make("TextButton", {
		Position = UDim2.fromOffset(4, 3), Size = UDim2.fromOffset(170, 24), BackgroundColor3 = BLUE, BorderSizePixel = 0,
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = WHITE, Text = "VER PANTALLAS (V)",
	}, frame)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, viewButton)
	viewButton.Activated:Connect(toggleView)
	make("TextLabel", {
		Position = UDim2.fromOffset(182, 0), Size = UDim2.new(1, -186, 1, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Tocá los botones de la consola · 1/2/3 · Espacio: levantarse",
	}, frame)
end

local function stepSeat(dt)
	local cinematic = deps.Cinematica and deps.Cinematica.isActive()
	local seat, character = seatedSeat()
	local camera = workspace.CurrentCamera
	if seat and not cinematic and camera then
		local head = character:FindFirstChild("Head")
		local m = seat.Name:match("^(%a+)%-")
		local consolePart = findPart("Consolas", (m or "") .. "-consola")
		local bigScreen = findPart("Pantallas", (m or "") .. "-main")
		if head and consolePart then
			if not seatView.active then
				seatView.active = true
				seatView.cf = camera.CFrame
				hintGui.Enabled = true
			end
			local look = seat.CFrame.LookVector
			local target
			if seatView.mode == "desk" or not bigScreen then
				target = CFrame.lookAt(head.Position + look * 1.4 + Vector3.new(0, 0.6, 0), consolePart.Position + Vector3.new(0, 0.3, 0))
				camera.FieldOfView = camera.FieldOfView + (62 - camera.FieldOfView) * math.min(1, dt * 6)
			else
				target = CFrame.lookAt(head.Position + Vector3.new(0, 1.6, 0) - look * 1.5, bigScreen.Position)
				camera.FieldOfView = camera.FieldOfView + (72 - camera.FieldOfView) * math.min(1, dt * 6)
			end
			camera.CameraType = Enum.CameraType.Scriptable
			seatView.cf = seatView.cf:Lerp(target, math.min(1, dt * 5))
			camera.CFrame = seatView.cf
			setCharacterHidden(character, true)
			return
		end
	end
	if seatView.active then
		seatView.active = false
		seatView.mode = "desk"
		hintGui.Enabled = false
		if viewButton then
			viewButton.Text = "VER PANTALLAS (V)"
		end
		if character then
			setCharacterHidden(character, false)
		end
		if camera and not cinematic then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
		end
	end
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
function Consolas.setMission(m)
	mission = m
	lab.values = {}
	lab.index = 1
	lab.status, lab.statusColor = "Elegí una prueba y ejecutala.", MUTED
	cam.built = false
	desk.data = nil
	drawOrbit(nil)
	renderLab()
	renderPlan()
	renderDesk()
end

function Consolas.onConsole(data)
	if type(data) ~= "table" then
		return
	end
	local previous = desk.data and desk.data.mode
	desk.data = data
	if data.mode ~= previous then
		if data.mode == "maneuver" then
			desk.dv, desk.dir, desk.momento = 0, "retro", 1
		elseif data.mode == "route" then
			desk.angulo, desk.vel = 16, 1
		end
	end
	if data.mode ~= "idle" and not cam.built then
		buildCamera()
	end
	if data.mode == "idle" then
		drawOrbit(nil)
	end
	renderDesk()
end

function Consolas.onResources(data)
	if type(data) == "table" and data.mode == "hangar" then
		design = data
		if plan.tab ~= 3 then
			renderPlan()
		end
	end
end

function Consolas.onLabResult(data)
	if type(data) ~= "table" then
		return
	end
	if data.error then
		lab.status, lab.statusColor = data.error, RED
	else
		local names = { ok = "✓ APROBADA", riesgo = "~ CON RIESGO", falla = "✗ NO APROBADA" }
		local colors = { ok = GREEN, riesgo = YELLOW, falla = RED }
		lab.status = string.format("%s · informe en la pantalla · %d de 3 pruebas", names[data.veredicto] or "", data.count or 0)
		lab.statusColor = colors[data.veredicto] or WHITE
		if data.visual and data.visual.tipo == "movilidad" then
			animateRamp(data.visual.pendiente or 0, data.visual.avance or 0)
		end
	end
	renderLab()
end

function Consolas.onManeuverResult(data)
	if type(data) ~= "table" then
		return
	end
	drawOrbit(data.error or 0, 0, string.format("RESULTANTE: error %+d m/s · %s kg de propelente", math.floor((data.error or 0) + 0.5), fmt(data.consumo or 0, 1)))
	Consolas.burn()
end

function Consolas.onAlert(on)
	alertOn = on == true
end

function Consolas.init(dependencies)
	deps = dependencies
	buildHint()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.V then
			toggleView()
		elseif seatView.active and desk.data then
			local keys = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }
			if desk.data.mode == "decision" and keys[input.KeyCode] then
				deps.remote:FireServer("decide", keys[input.KeyCode])
			elseif (desk.data.mode == "maneuver" or desk.data.mode == "route") and input.KeyCode == Enum.KeyCode.Return then
				sendManeuver()
			end
		end
	end)
	-- Las consolas pueden tardar en llegar del servidor: se reintenta hasta encontrarlas
	task.spawn(function()
		while true do
			if not guis["lab-consola"] or not guis["lab-consola"].part.Parent then
				renderLab()
			end
			if not guis["plan-consola"] or not guis["plan-consola"].part.Parent then
				renderPlan()
			end
			if mission and (not guis[mission .. "-consola"] or not guis[mission .. "-consola"].part.Parent) then
				renderDesk()
			end
			task.wait(2)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		stepSeat(dt)
		local t = os.clock()
		-- cámara remota: órbita lenta alrededor de la nave
		if cam.built and cam.camera and cam.camera.Parent then
			local radius = mission == "probe" and 13 or 11
			local height = mission == "probe" and 3 or 4
			local a = t * 0.15
			cam.camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(a) * radius, height + math.sin(t * 0.3) * 1, math.cos(a) * radius), Vector3.new(0, mission == "probe" and 0 or 1.3, 0))
			if cam.rec then
				cam.rec.TextTransparency = (math.floor(t * 2) % 2 == 0) and 0 or 0.7
			end
			if cam.delay then
				local s = math.floor(t) % 60
				cam.delay.Text = string.format("SEÑAL DIFERIDA · %s · %02d:%02d UTC", mission == "probe" and "14 MIN 20 SEG" or "12 MIN", math.floor(t / 60) % 60, s)
			end
			if cam.flame then
				cam.flame.Transparency = t < cam.flameUntil and (0.1 + math.abs(math.sin(t * 20)) * 0.3) or 1
			end
		end
		-- luz de alerta
		if mission then
			local lamp = findPart("Consolas", mission .. "-alerta")
			if lamp then
				local pulse = alertOn and (0.5 + 0.5 * math.sin(t * 6)) or 0
				lamp.Transparency = alertOn and (0.6 - pulse * 0.5) or 0.85
				local glow = lamp:FindFirstChildOfClass("PointLight")
				if glow then
					glow.Brightness = pulse * 3
				end
			end
		end
	end)
end

return Consolas
