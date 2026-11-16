--[[
	CINEMÁTICA · ModuleScript (hijo del LocalScript "ControlDeMisionCliente") · v7

	Todo ocurre en el cliente, con copias locales: el jugador nunca sale de la Tierra.
	La cámara muestra la nave; el personaje queda en el centro espacial.

	SONDA (la sonda ya está dentro de la cofia del Atlas V, en el hangar)
	  cuenta regresiva · se abre el techo y se ve el cielo estrellado · ignición · el Atlas V
	  sale por el techo → corte al espacio: se separan la etapa y la cofia, y la sonda queda en órbita.
	ROVER A MARTE (el rover ya está dentro del Atlas V, en la plataforma exterior)
	  cuenta regresiva · despegue → crucero hacia Marte en la cápsula → entrada atmosférica
	  (el escudo térmico se pone al rojo) → paracaídas → grúa celeste: retrocohetes y cables
	  bajan el rover hasta el suelo del cráter Jezero, como Curiosity (2012) y Perseverance (2021).

	COHERENCIA: en Marte sí hay aire (muy poco, 1 % de la presión de la Tierra). Por eso el
	paracaídas frena, pero no alcanza: los retrocohetes hacen el último tramo.

	Flujo con el servidor:
	  "cinematic" → Cinematica.play(info) … pantalla en negro → FireServer("cinematicBlack")
	  "arrive" → Cinematica.arrive(...): travelling en la sala de control.

	SONIDO: Roblox no permite fabricar audio por script. Pegá ids de la Creator Store en
	Cinematica.SONIDOS. Si un id está vacío, simplemente no suena.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Cinematica = {}

Cinematica.SONIDOS = {
	cuenta = "",        -- bip corto en cada segundo de la cuenta regresiva
	ignicion = "",      -- encendido de motores (una vez)
	motor = "",         -- rugido de motor (en bucle durante el ascenso)
	puerta = "",        -- techo del hangar
	ambiente = "",      -- murmullo de sala de control
}

Cinematica.onHud = function(_visible) end
Cinematica.remote = nil

local RED = Color3.fromRGB(252, 61, 33)
local WHITE = Color3.fromRGB(245, 247, 250)
local GREEN = Color3.fromRGB(61, 255, 122)
local NAVY = Color3.fromRGB(10, 22, 52)
local FLAME = Color3.fromRGB(255, 150, 50)
local MARS_SAND = Color3.fromRGB(184, 98, 58)
local MARS_ROCK = Color3.fromRGB(122, 64, 42)

local CFG = {
	probe = { count = 8, lift = 9, orbit = 19, cuts = { 19 }, blackStart = 28, blackEnd = 29.5 },
	rover = {
		count = 6, rocket = 0, rocketLift = 7, space = 15, entry = 20, chute = 25, crane = 29, touchdown = 33.5,
		cuts = { 15, 20 }, blackStart = 39.5, blackEnd = 41,
	},
}

local SPACE = Vector3.new(0, 900, 6000)        -- escenas locales, lejos del centro espacial
local MARS = Vector3.new(0, 600, 9000)

local player = Players.LocalPlayer
local overlay, black, barTop, barBottom, subtitle, countLabel, infoLabel, skipButton
local session = nil
local RENDER_NAME = "CinematicaCamara"

---------------------------------------------------------------------------
-- Interfaz de la cinemática
---------------------------------------------------------------------------
local function make(className, props, parent)
	local obj = Instance.new(className)
	for key, value in pairs(props) do
		obj[key] = value
	end
	obj.Parent = parent
	return obj
end

local function build()
	if overlay then
		return
	end
	overlay = make("ScreenGui", { Name = "CinematicaGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50 }, player:WaitForChild("PlayerGui"))
	black = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1 }, overlay)
	barTop = make("Frame", { Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5 }, overlay)
	barBottom = make("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5, ClipsDescendants = true,
	}, overlay)
	subtitle = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.7),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextScaled = true, TextWrapped = true, TextColor3 = WHITE, Text = "", ZIndex = 6,
	}, barBottom)
	make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 10 }, subtitle)
	countLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.14), Size = UDim2.fromOffset(340, 80),
		BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 44, TextColor3 = WHITE, Text = "",
		TextStrokeTransparency = 0.4, ZIndex = 6, Visible = false,
	}, overlay)
	infoLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.14, 84), Size = UDim2.fromOffset(560, 22),
		BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 16, TextColor3 = GREEN, Text = "", ZIndex = 6, Visible = false,
	}, overlay)
	skipButton = make("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(120, 30),
		BackgroundColor3 = NAVY, BackgroundTransparency = 0.2, BorderSizePixel = 0, Font = Enum.Font.GothamBold,
		TextSize = 14, TextColor3 = WHITE, Text = "SALTAR ▶▶", ZIndex = 7, Visible = false,
	}, overlay)
	make("UIStroke", { Color = RED, Thickness = 1 }, skipButton)
	skipButton.Activated:Connect(function()
		if Cinematica.isTouring and Cinematica.isTouring() then
			Cinematica.stopTour()
			return
		end
		local s = session
		if s and s.phase == "main" then
			local target = s.cfg.blackStart - 0.3
			if os.clock() - s.t0 < target then
				s.t0 = os.clock() - target
				s.eventIndex = #s.events + 1
			end
		end
	end)
end

local function tween(obj, time, goal, style)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), goal)
	t:Play()
	return t
end

local function setBars(on)
	tween(barTop, 0.8, { Size = UDim2.fromScale(1, on and 0.11 or 0) })
	tween(barBottom, 0.8, { Size = UDim2.fromScale(1, on and 0.13 or 0) })
end

local function say(text)
	subtitle.Text = text
	subtitle.TextTransparency = 1
	tween(subtitle, 0.25, { TextTransparency = 0 })
end

local function playSound(name, looped, volume)
	local id = Cinematica.SONIDOS[name]
	if not id or id == "" then
		return nil
	end
	local sound = make("Sound", { SoundId = id, Looped = looped == true, Volume = volume or 0.8 }, SoundService)
	sound:Play()
	if not looped then
		Debris:AddItem(sound, 30)
	end
	if session then
		table.insert(session.sounds, sound)
	end
	return sound
end

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function shake(t, amp)
	if amp <= 0.001 then
		return CFrame.new()
	end
	return CFrame.new(math.noise(t * 23, 1.7) * amp, math.noise(t * 27, 8.3) * amp, 0)
		* CFrame.Angles(0, 0, math.noise(t * 19, 4.1) * amp * 0.02)
end

local function newEmitter(parent, props)
	local emitter = Instance.new("ParticleEmitter")
	for key, value in pairs(props) do
		emitter[key] = value
	end
	emitter.Parent = parent
	return emitter
end

local function fxPart(s, position)
	local part = make("Part", {
		Name = "FxCinematica", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		Transparency = 1, Size = Vector3.new(1, 1, 1), Position = position,
	}, workspace)
	table.insert(s.fx, part)
	return part
end

local function scenery(s, props, parent)
	props.Anchored = true
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	local part = make("Part", props, parent or workspace)
	if not parent then
		table.insert(s.fx, part)
	end
	return part
end

local function seq(...)
	local keys = {}
	for _, pair in ipairs({ ... }) do
		table.insert(keys, NumberSequenceKeypoint.new(pair[1], pair[2]))
	end
	return NumberSequence.new(keys)
end

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- Fuego, humo de estela y luz de un motor, sobre una parte que sigue al cohete
local function rocketFx(s, position, size)
	local k = size or 1
	local part = fxPart(s, position)
	local fx = { part = part }
	fx.flame = newEmitter(part, {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 210)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 160, 50)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 50, 20)),
		}),
		Size = seq({ 0, 6 * k }, { 1, 1 * k }), Transparency = seq({ 0, 0 }, { 0.7, 0.3 }, { 1, 1 }),
		Lifetime = NumberRange.new(0.35, 0.7), Speed = NumberRange.new(35 * k, 55 * k), Rate = 0,
		SpreadAngle = Vector2.new(7, 7), LightEmission = 1, EmissionDirection = Enum.NormalId.Bottom,
	})
	fx.trail = newEmitter(part, {
		Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(225, 225, 230)),
		Size = seq({ 0, 6 * k }, { 1, 30 * k }), Transparency = seq({ 0, 0.35 }, { 1, 1 }),
		Lifetime = NumberRange.new(2.5, 4.2), Speed = NumberRange.new(6, 16), Rate = 0,
		SpreadAngle = Vector2.new(18, 18), EmissionDirection = Enum.NormalId.Bottom, Drag = 1.2,
	})
	fx.ground = fxPart(s, position + Vector3.new(0, 0.5, 0))
	fx.smoke = newEmitter(fx.ground, {
		Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(200, 205, 215)),
		Size = seq({ 0, 8 * k }, { 1, 34 * k }), Transparency = seq({ 0, 0.3 }, { 1, 1 }),
		Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(10, 26), Rate = 0,
		SpreadAngle = Vector2.new(180, 180), EmissionDirection = Enum.NormalId.Top, Drag = 2,
	})
	fx.light = make("PointLight", { Color = Color3.fromRGB(255, 160, 70), Range = 60, Brightness = 0, Shadows = false }, part)
	for _, e in ipairs({ fx.flame, fx.trail, fx.smoke }) do
		table.insert(s.emitters, e)
	end
	return fx
end

local function dustBurst(s, position, color)
	local part = fxPart(s, position)
	local e = newEmitter(part, {
		Texture = SMOKE, Color = ColorSequence.new(color or Color3.fromRGB(160, 160, 165)),
		Size = seq({ 0, 2 }, { 1, 10 }), Transparency = seq({ 0, 0.4 }, { 1, 1 }),
		Lifetime = NumberRange.new(1.2, 2.4), Speed = NumberRange.new(4, 14), Rate = 0,
		SpreadAngle = Vector2.new(80, 80), EmissionDirection = Enum.NormalId.Top, Drag = 2,
	})
	table.insert(s.emitters, e)
	return part, e
end

local function cloneModel(s, model, name)
	local clone = model:Clone()
	clone.Name = name
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.LocalTransparencyModifier = 0
		elseif part:IsA("ProximityPrompt") then
			part:Destroy()
		end
	end
	clone.Parent = workspace
	table.insert(s.fx, clone)
	return clone
end

-- Cuerda (o cable) entre dos puntos
local function stretch(part, from, to, thickness)
	local length = math.max((to - from).Magnitude, 0.05)
	part.Size = Vector3.new(thickness or 0.12, thickness or 0.12, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
end

---------------------------------------------------------------------------
-- Cielo local: estrellas para el despegue nocturno y cielo marciano para el aterrizaje.
-- Solo cambia en este cliente y se restaura al terminar.
---------------------------------------------------------------------------
local function overrideSky(s, mode)
	if not s.skySaved then
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
		s.skySaved = {
			clock = Lighting.ClockTime, brightness = Lighting.Brightness, exposure = Lighting.ExposureCompensation, atm = atm,
			outdoor = Lighting.OutdoorAmbient, clouds = clouds, cloudsOn = clouds and clouds.Enabled,
			atmProps = atm and { Density = atm.Density, Haze = atm.Haze, Color = atm.Color, Decay = atm.Decay, Glare = atm.Glare, Offset = atm.Offset } or nil,
		}
	end
	local atm = s.skySaved.atm
	local clouds = s.skySaved.clouds
	if mode == "estrellas" then
		-- v8: anochecer, no medianoche: el cielo queda azul oscuro con estrellas y el centro espacial
		-- (suelo, edificios, mar) se sigue viendo. Antes era todo negro.
		Lighting.ClockTime = 19.1
		Lighting.OutdoorAmbient = Color3.fromRGB(92, 96, 124)
		if atm then
			atm.Density, atm.Haze, atm.Glare, atm.Offset = 0.22, 0.6, 0, 0.1
		end
		if clouds then
			clouds.Enabled = false
		end
	elseif mode == "espacio" then
		-- en el espacio no hay aire: cielo negro con estrellas
		Lighting.ClockTime = 0
		if atm then
			atm.Density, atm.Haze, atm.Glare = 0, 0, 0
		end
		if clouds then
			clouds.Enabled = false
		end
	elseif mode == "marte" then
		if clouds then
			clouds.Enabled = false
		end
		Lighting.ClockTime = 15
		Lighting.Brightness = 2
		Lighting.ExposureCompensation = 0
		if atm then
			atm.Density, atm.Offset, atm.Haze, atm.Glare = 0.42, 0.1, 2.2, 0.3
			atm.Color = Color3.fromRGB(226, 160, 116)
			atm.Decay = Color3.fromRGB(170, 96, 62)
		end
	end
end

local function restoreSky(s)
	local saved = s.skySaved
	if not saved then
		return
	end
	Lighting.ClockTime = saved.clock
	Lighting.Brightness = saved.brightness
	Lighting.ExposureCompensation = saved.exposure
	Lighting.OutdoorAmbient = saved.outdoor
	if saved.clouds and saved.clouds.Parent then
		saved.clouds.Enabled = saved.cloudsOn
	end
	if saved.atm and saved.atm.Parent and saved.atmProps then
		for key, value in pairs(saved.atmProps) do
			saved.atm[key] = value
		end
	end
	s.skySaved = nil
end

---------------------------------------------------------------------------
-- Restaurar el mundo (el servidor nunca movió nada: todo fue local)
---------------------------------------------------------------------------
local function restoreScenery(s)
	if s.roof then
		for _, item in ipairs(s.roof) do
			if item.part and item.part.Parent then
				item.part.CFrame = item.home
			end
		end
	end
	if s.rocket and s.rocket.Parent and s.rocketHome then
		s.rocket:PivotTo(s.rocketHome)
	end
	if s.vehicle and s.vehicle.Parent and s.vehiclePivot then
		s.vehicle:PivotTo(s.vehiclePivot)
	end
	restoreSky(s)
end

local function cleanup(s)
	restoreScenery(s)
	for _, item in ipairs(s.fx) do
		if item and item.Parent then
			item:Destroy()
		end
	end
	for _, sound in ipairs(s.sounds) do
		if sound and sound.Parent then
			sound:Destroy()
		end
	end
end

local function release(s, quick)
	pcall(function()
		RunService:UnbindFromRenderStep(RENDER_NAME)
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
	countLabel.Visible = false
	infoLabel.Visible = false
	skipButton.Visible = false
	subtitle.Text = ""
	setBars(false)
	tween(black, quick and 0.1 or 0.6, { BackgroundTransparency = 1 })
	Cinematica.onHud(true)
	if session == s then
		session = nil
	end
end

function Cinematica.isActive()
	return session ~= nil
end

function Cinematica.cancel()
	local s = session
	if not s then
		return
	end
	s.cancelled = true
	cleanup(s)
	release(s, true)
end

---------------------------------------------------------------------------
-- Subtítulos (cortos: el juego es para chicos)
---------------------------------------------------------------------------
local function buildEvents(s)
	local cfg = s.cfg
	local events = {}
	local function add(t, text)
		table.insert(events, { t = t, text = text })
	end
	-- v8: datos reales de New Horizons (2006) y de Perseverance (2020-2021), con fuente en Educativo.REAL
	if s.kind == "probe" then
		add(0.8, "T-8 · Atlas V 551 con New Horizons. Cada puesto responde GO o NO-GO.")
		add(2.0, "Se abre el techo: anochece en Cabo Cañaveral y aparecen las estrellas.")
		for i, call in ipairs(s.info.calls or {}) do
			add(2.6 + i * 0.85, "PUESTO " .. i .. " · " .. call)
		end
		add(6.2, "T-3 · Ignición: el empuje tiene que ganarle al peso del cohete.")
		add(cfg.lift, "¡DESPEGUE! 19 de enero de 2006.")
		add(cfg.lift + 3, "Cinco propulsores sólidos dan el empujón inicial.")
		add(cfg.lift + 6.5, "MAX-Q · Máxima presión del aire sobre el cohete.")
		add(cfg.orbit + 0.4, "La tercera etapa Star 48B la deja a 16,2 km/s respecto de la Tierra.")
		add(cfg.orbit + 3.2, "Más que la velocidad de escape: no queda en órbita, va directo a Júpiter.")
		add(cfg.orbit + 6, "9 horas después cruza la órbita de la Luna. Desde ahora la operás desde la Tierra.")
	else
		add(0.6, "T-6 · Atlas V 541. El rover viaja plegado adentro de la cápsula y la cofia.")
		for i, call in ipairs(s.info.calls or {}) do
			add(1.4 + i * 0.9, "PUESTO " .. i .. " · " .. call)
		end
		add(cfg.rocketLift, "¡DESPEGUE! 30 de julio de 2020, rumbo a Marte.")
		add(cfg.rocketLift + 3.5, "(El viaje real: 203 días y 471 millones de km. Acá lo aceleramos.)")
		add(cfg.space + 0.3, "Crucero: 539 kg de etapa de crucero con paneles solares llevan la cápsula.")
		add(cfg.entry + 0.3, "18/2/2021 · Entrada a 19.500 km/h. El escudo térmico se pone al rojo.")
		add(cfg.chute + 0.2, "A 11 km de altura y 1.512 km/h se abre el paracaídas de 21,5 m.")
		add(cfg.chute + 2.2, "El aire de Marte es muy fino: el paracaídas solo no alcanza para frenar.")
		add(cfg.crane + 0.2, "Retrocohetes y grúa celeste: a 20 m del suelo y 2,7 km/h, cables de 7,6 m.")
		add(cfg.touchdown, "¡ATERRIZAJE CONFIRMADO en el cráter Jezero! (La señal tarda 11 min 22 s.)")
		add(cfg.touchdown + 2.5, "Traspasando el control a la sala de misión…")
	end
	table.sort(events, function(a, b)
		return a.t < b.t
	end)
	return events
end

---------------------------------------------------------------------------
-- Escenas locales: órbita de la Tierra, crucero y Marte
---------------------------------------------------------------------------
local function buildOrbitScene(s)
	if s.orbitBuilt or not s.rocket or not s.rocket.Parent then
		return
	end
	s.orbitBuilt = true
	scenery(s, { Shape = Enum.PartType.Ball, Size = Vector3.new(520, 520, 520), Position = SPACE + Vector3.new(0, -330, -40), Color = Color3.fromRGB(30, 90, 190), Material = Enum.Material.Neon, Transparency = 0.1 })
	scenery(s, { Shape = Enum.PartType.Ball, Size = Vector3.new(530, 530, 530), Position = SPACE + Vector3.new(0, -330, -40), Color = Color3.fromRGB(120, 190, 255), Material = Enum.Material.ForceField })
	-- copia del Atlas V con la sonda adentro
	local container = make("Model", { Name = "AtlasEnOrbita" }, workspace)
	table.insert(s.fx, container)
	local rocketCopy = s.rocket:Clone()
	rocketCopy.Parent = container
	rocketCopy:PivotTo(s.rocketHome)
	if s.vehicle and s.vehicle.Parent and s.vehOffset then
		local probeCopy = s.vehicle:Clone()
		probeCopy.Parent = container
		probeCopy:PivotTo(s.rocketHome * s.vehOffset)
	end
	for _, part in ipairs(container:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.LocalTransparencyModifier = 0
		end
	end
	container.WorldPivot = s.rocketHome
	local base = CFrame.new(SPACE) * CFrame.Angles(0, 0, math.rad(80))
	container:PivotTo(base)
	s.orbit = { model = container, base = base, parts = {} }
	for _, part in ipairs(container:GetDescendants()) do
		if part:IsA("BasePart") and (part.Name == "Etapa" or part.Name == "Cofia") then
			local dir = Vector3.zero
			if part.Name == "Cofia" then                 -- las dos mitades se abren como una almeja
				dir = Vector3.new(0, 0, part.Parent and part.Parent.Name == "CofiaB" and 1 or -1)
			end
			table.insert(s.orbit.parts, { part = part, home = part.CFrame, kind = part.Name, dir = dir, spin = math.random() * 2 - 1 })
		end
	end
	local light = scenery(s, { Transparency = 1, Size = Vector3.new(1, 1, 1), Position = SPACE + Vector3.new(40, 30, 40) })
	make("PointLight", { Range = 80, Brightness = 3, Color = Color3.fromRGB(255, 248, 235), Shadows = false }, light)
end

-- Cápsula de entrada a Marte: escudo térmico abajo, coraza trasera arriba, etapa de crucero con paneles.
-- Se arma en el origen y después se mueve con PivotTo. Devuelve sus partes por grupo.
local function buildCapsule(s)
	local m = make("Model", { Name = "CapsulaMarte" }, workspace)
	table.insert(s.fx, m)
	local up = CFrame.Angles(0, 0, math.rad(90))
	local c = { model = m, back = {}, cruise = {} }
	c.shield = scenery(s, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 9, 9), CFrame = up, Color = Color3.fromRGB(110, 70, 45), Material = Enum.Material.Slate }, m)
	for i, ring in ipairs({ { 1.4, 8.6, 1.1 }, { 1.4, 6.8, 2.5 }, { 1.4, 4.8, 3.9 }, { 1, 2.6, 5.1 } }) do
		local part = scenery(s, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(ring[1], ring[2], ring[2]), CFrame = CFrame.new(0, ring[3], 0) * up, Color = i % 2 == 0 and Color3.fromRGB(225, 225, 230) or WHITE, Material = Enum.Material.SmoothPlastic }, m)
		table.insert(c.back, part)
	end
	table.insert(c.cruise, scenery(s, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 9.6, 9.6), CFrame = CFrame.new(0, 6, 0) * up, Color = Color3.fromRGB(150, 155, 165), Material = Enum.Material.Metal }, m))
	for i = 0, 7 do
		local a = math.rad(i * 45)
		table.insert(c.cruise, scenery(s, { Size = Vector3.new(2.6, 0.15, 1.4), CFrame = CFrame.new(0, 6.5, 0) * CFrame.Angles(0, a, 0) * CFrame.new(3.6, 0, 0), Color = Color3.fromRGB(30, 60, 140), Material = Enum.Material.Glass }, m))
	end
	-- plasma de la entrada (se ve solo en la atmósfera)
	c.plasma = scenery(s, { Shape = Enum.PartType.Ball, Size = Vector3.new(11, 4, 11), CFrame = CFrame.new(0, -1.2, 0), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, Transparency = 1 }, m)
	m.WorldPivot = CFrame.new()
	return c
end

local function buildMarsScene(s)
	if s.marsBuilt then
		return
	end
	s.marsBuilt = true
	scenery(s, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 700, 700), CFrame = CFrame.new(MARS - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = MARS_SAND, Material = Enum.Material.Sand })
	local random = Random.new(9)                      -- semilla fija: siempre el mismo paisaje
	for _ = 1, 60 do                                   -- rocas
		local size = random:NextNumber(0.8, 4.5)
		local pos = MARS + Vector3.new(random:NextNumber(-170, 170), size * 0.25, random:NextNumber(-170, 170))
		if (pos - MARS).Magnitude > 16 then
			scenery(s, { Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.6, size * 1.1), Position = pos, Color = MARS_ROCK, Material = Enum.Material.Basalt })
		end
	end
	for _ = 1, 8 do                                    -- cráteres chicos
		local r = random:NextNumber(5, 18)
		local pos = MARS + Vector3.new(random:NextNumber(-150, 150), 0.1, random:NextNumber(-150, 150))
		if (pos - MARS).Magnitude > 40 then
			scenery(s, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, r * 2.2, r * 2.2), CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(196, 110, 66), Material = Enum.Material.Sand })
			scenery(s, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, r * 1.8, r * 1.8), CFrame = CFrame.new(pos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 76, 46), Material = Enum.Material.Sand })
		end
	end
	for i = 0, 9 do                                    -- borde del cráter Jezero a lo lejos
		local a = math.rad(i * 36 + 8)
		scenery(s, { Size = Vector3.new(140, random:NextNumber(22, 46), 50), CFrame = CFrame.new(MARS + Vector3.new(math.cos(a) * 260, 10, math.sin(a) * 260)) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = Color3.fromRGB(160, 84, 52), Material = Enum.Material.Sandstone })
	end
	local holder = scenery(s, { Transparency = 1, Size = Vector3.new(1, 1, 1), Position = MARS + Vector3.new(30, 40, 30) })
	make("PointLight", { Range = 70, Brightness = 1.5, Color = Color3.fromRGB(255, 230, 210), Shadows = false }, holder)
end

---------------------------------------------------------------------------
-- Secuencia principal
---------------------------------------------------------------------------
local function beginSequence(s)
	local info = s.info
	local camera = workspace.CurrentCamera
	local cfg = s.cfg
	s.vehicle = info.vehicle
	s.vehiclePivot = typeof(s.vehicle) == "Instance" and s.vehicle.Parent and s.vehicle:GetPivot() or nil
	if typeof(info.rocket) == "Instance" and info.rocket.Parent then
		s.rocket = info.rocket
		s.rocketHome = info.rocket:GetPivot()
		if s.vehiclePivot then
			s.vehOffset = s.rocketHome:ToObjectSpace(s.vehiclePivot)        -- la nave viaja adentro de la cofia
		end
	end
	s.origin = (s.rocketHome or info.stand).Position

	if info.roof then
		s.roof = {}
		for _, part in ipairs(info.roof) do
			if typeof(part) == "Instance" and part:IsA("BasePart") then
				table.insert(s.roof, { part = part, home = part.CFrame, dir = part.Position.Z > s.origin.Z and 1 or -1 })
			end
		end
	end
	s.engine = rocketFx(s, s.origin + Vector3.new(0, 1, 0), 1.3)
	overrideSky(s, "estrellas")

	s.events = buildEvents(s)
	s.eventIndex = 1
	s.look = s.origin + Vector3.new(0, 26, 0)

	camera.CameraType = Enum.CameraType.Scriptable
	setBars(true)
	countLabel.Visible = true
	infoLabel.Visible = true
	skipButton.Visible = true
	s.t0 = os.clock()
	s.phase = "main"
	playSound("ambiente", false, 0.3)

	local lastCount = nil
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt)
		if s.cancelled then
			return
		end
		local t = os.clock() - s.t0
		local cam = workspace.CurrentCamera
		if s.phase == "main" then
			-- fundidos: entrada, cortes entre escenas y salida
			local alpha
			if t < cfg.blackStart then
				alpha = 1 - smooth(t / 0.9)
				for _, cut in ipairs(cfg.cuts) do
					alpha = math.max(alpha, 1 - smooth(math.abs(t - cut) / 0.45))
				end
			else
				alpha = smooth((t - cfg.blackStart) / (cfg.blackEnd - cfg.blackStart))
			end
			black.BackgroundTransparency = 1 - alpha

			while s.events[s.eventIndex] and s.events[s.eventIndex].t <= t do
				say(s.events[s.eventIndex].text)
				s.eventIndex += 1
			end

			local launchAt = s.kind == "probe" and cfg.lift or cfg.rocketLift
			local tl = t - launchAt
			local showCount = s.kind == "probe" or t < cfg.space
			if showCount then
				if tl < 0 then
					local n = math.ceil(-tl)
					if t >= 1 and n <= cfg.count then
						countLabel.Text = "T-" .. n
						countLabel.TextColor3 = n <= 3 and RED or WHITE
						if lastCount ~= n then
							lastCount = n
							playSound("cuenta", false, 0.6)
						end
					else
						countLabel.Text = ""
					end
				elseif s.kind == "probe" and t >= cfg.orbit then
					countLabel.Text = ""
				else
					countLabel.Text = "T+" .. math.floor(tl)
					countLabel.TextColor3 = GREEN
				end
			else
				countLabel.Text = ""
			end

			if s.kind == "probe" then
				Cinematica._stepProbe(s, cam, t, dt)
			else
				Cinematica._stepRover(s, cam, t, dt)
			end

			if t >= cfg.blackEnd and not s.blackSent then
				s.blackSent = true
				s.phase = "waiting"
				s.waitStart = os.clock()
				restoreScenery(s)
				for _, emitter in ipairs(s.emitters) do
					emitter.Enabled = false
				end
				for _, sound in ipairs(s.sounds) do
					if sound.Looped then
						sound:Stop()
					end
				end
				countLabel.Text = ""
				infoLabel.Text = ""
				subtitle.Text = ""
				skipButton.Visible = false
				if Cinematica.remote then
					Cinematica.remote:FireServer("cinematicBlack")
				end
			end
		elseif s.phase == "waiting" then
			if os.clock() - s.waitStart > 25 then
				cleanup(s)
				release(s, false)
			end
		elseif s.phase == "arrive" then
			Cinematica._stepArrive(s, cam, os.clock() - s.arriveStart)
		end
	end)
end

-- Mueve el Atlas V (y la nave que va adentro) a una altura h sobre su base
local function placeRocket(s, h, tilt, vib)
	local rocketCF = CFrame.new(Vector3.new(0, h, 0) + (vib or Vector3.zero)) * s.rocketHome * CFrame.Angles(0, 0, tilt or 0)
	if s.rocket and s.rocket.Parent then
		s.rocket:PivotTo(rocketCF)
	end
	if s.vehicle and s.vehicle.Parent and s.vehOffset then
		s.vehicle:PivotTo(rocketCF * s.vehOffset)
	end
	return rocketCF
end

local function engineOn(s, t, ign, tl, rocketCF)
	local fx = s.engine
	fx.part.Position = rocketCF.Position + Vector3.new(0, 0.5, 0)
	fx.flame.Rate = 160 * ign
	fx.smoke.Rate = (ign > 0 and tl < 4) and 80 * ign or 0
	fx.trail.Rate = tl > 0 and 80 or 0
	fx.light.Brightness = ign * 7 + math.abs(math.noise(t * 30, 3)) * 3 * ign
	if ign > 0 and not s.ignSound then
		s.ignSound = true
		playSound("ignicion", false, 0.9)
		playSound("motor", true, 0.9)
	end
end

local function engineOff(s)
	if s.engine then
		s.engine.flame.Rate, s.engine.trail.Rate, s.engine.smoke.Rate, s.engine.light.Brightness = 0, 0, 0, 0
	end
end

---------------------------------------------------------------------------
-- SONDA: el Atlas V sale por el techo abierto del hangar
---------------------------------------------------------------------------
function Cinematica._stepProbe(s, cam, t, dt)
	local cfg = s.cfg
	local S = s.origin
	local tl = t - cfg.lift
	local ign = smooth((t - 6) / 3)

	if t >= cfg.orbit then
		buildOrbitScene(s)
		if not s.spaceSky then
			s.spaceSky = true
			overrideSky(s, "espacio")
		end
	end
	if t >= cfg.orbit and s.orbit then
		-- ÓRBITA: la etapa cae, la cofia se abre en dos y la sonda queda sola sobre la Tierra
		engineOff(s)
		local k = t - cfg.orbit
		local base = s.orbit.base
		for _, item in ipairs(s.orbit.parts) do
			if item.part.Parent then
				if item.kind == "Etapa" then
					local f = math.max(0, k - 0.3)
					item.part.CFrame = item.home + base:VectorToWorldSpace(Vector3.new(0, -f * f * 2.2 - f * 3, 0))
				else
					local f = math.max(0, k - 2.8)
					item.part.CFrame = (item.home + base:VectorToWorldSpace(item.dir * f * 6 + Vector3.new(0, f * 2, 0)))
						* CFrame.Angles(item.dir.Z * f * 0.25, 0, item.spin * f * 0.1)
				end
			end
		end
		local drift = base * CFrame.Angles(0, k * 0.05, 0)
		local center = (drift * CFrame.new(0, 36, 0)).Position
		local angle = k * 0.22
		cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(angle) * 40, 12 - k * 0.6, math.cos(angle) * 40), center)
		cam.FieldOfView = 55
		infoLabel.Text = "VISTA SIMULADA · SALIDA DE LA TIERRA A 16,2 KM/S"
		return
	end

	-- el techo se abre y aparece el cielo estrellado
	if s.roof then
		local open = smooth((t - 1.5) / 4) * 50
		for _, item in ipairs(s.roof) do
			if item.part.Parent then
				item.part.CFrame = item.home + Vector3.new(0, 0, item.dir * open)
			end
		end
		if not s.roofSound and t > 1.5 then
			s.roofSound = true
			playSound("puerta", false, 0.7)
		end
	end

	local h = tl > 0 and (1.2 * tl * tl + 0.35 * tl * tl * tl) or 0
	local tilt = tl > 5 and math.rad((tl - 5) * 1.1) or 0
	local vib = (tl <= 0 and ign > 0) and Vector3.new(0, math.noise(t * 40, 2) * 0.12 * ign, 0) or Vector3.zero
	local rocketCF = placeRocket(s, h, tilt, vib)
	engineOn(s, t, ign, tl, rocketCF)

	local amp = ign * 0.08
	if tl > 0 then
		amp = 0.14 * math.max(0, 1 - tl / 7)
	end
	local pos, target, fov
	if t < 5.5 then
		-- mirando para arriba: el techo se abre y se ven las estrellas sobre la punta del cohete
		local k = t / 5.5
		pos = S + Vector3.new(16, 5, -26)
		target = S + Vector3.new(0, 34 + 30 * k, 0)
		fov = 70
	elseif tl < 0 then
		local k = (t - 5.5) / (cfg.lift - 5.5)
		local angle = math.rad(205 - 45 * k)
		local radius = 40 - 4 * k
		pos = S + Vector3.new(math.sin(angle) * radius, 4 + 2 * k, math.cos(angle) * radius)
		target = S + Vector3.new(0, 26, 0)
		fov = 66 - 8 * k
	else
		local follow = math.max(0, h - 30) * 0.82
		pos = S + Vector3.new(28 + tl * 2.6, 6 + follow, -34 - follow * 0.12)
		target = rocketCF.Position + Vector3.new(0, 26, 0)
		fov = 58 + math.min(tl, 10) * 1.4
	end
	s.look = s.look:Lerp(target, math.clamp(dt * (tl < 0 and 3 or 5), 0, 1))
	cam.CFrame = CFrame.lookAt(pos, s.look) * shake(t, amp)
	cam.FieldOfView = fov
	infoLabel.Text = ""
end

---------------------------------------------------------------------------
-- ROVER A MARTE
---------------------------------------------------------------------------
local ROVER_TOP = 5.4        -- alto del rover (escala 0,68: un poco más que el jugador), para colgarlo de los cables

function Cinematica._stepRover(s, cam, t, dt)
	local cfg = s.cfg

	-- 1. DESPEGUE desde la plataforma exterior
	if t < cfg.space then
		if not s.rocket then
			return
		end
		local tl = t - cfg.rocketLift
		local ign = smooth((t - (cfg.rocketLift - 1.5)) / 1.5)
		local h = tl > 0 and (1.4 * tl * tl + 0.4 * tl * tl * tl) or 0
		local vib = (tl <= 0 and ign > 0) and Vector3.new(0, math.noise(t * 40, 2) * 0.15 * ign, 0) or Vector3.zero
		local rocketCF = placeRocket(s, h, 0, vib)
		engineOn(s, t, ign, tl, rocketCF)
		local P = s.rocketHome.Position
		local follow = math.max(0, h - 20) * 0.85
		local pos = P + Vector3.new(60, 10 + follow, 58 - follow * 0.1)          -- el Atlas V del rover es 1,3 veces más grande
		local target = rocketCF.Position + Vector3.new(0, 34, 0)
		s.look = s.look:Lerp(target, math.clamp(dt * 4, 0, 1))
		cam.CFrame = CFrame.lookAt(pos, s.look) * shake(t, ign * (tl > 0 and math.max(0, 0.15 - tl * 0.02) or 0.08))
		cam.FieldOfView = 58 + math.min(math.max(tl, 0), 6)
		infoLabel.Text = ""
		return
	end
	engineOff(s)

	if not s.capsule then
		overrideSky(s, "espacio")
		s.capsule = buildCapsule(s)
		-- crucero: la Tierra queda atrás y Marte se agranda adelante
		scenery(s, { Shape = Enum.PartType.Ball, Size = Vector3.new(60, 60, 60), Position = SPACE + Vector3.new(-120, 40, 260), Color = Color3.fromRGB(30, 90, 190), Material = Enum.Material.Neon })
		s.marsBall = scenery(s, { Shape = Enum.PartType.Ball, Size = Vector3.new(160, 160, 160), Position = SPACE + Vector3.new(120, -30, -420), Color = Color3.fromRGB(190, 92, 52), Material = Enum.Material.SmoothPlastic })
		local holder = scenery(s, { Transparency = 1, Size = Vector3.new(1, 1, 1), Position = SPACE + Vector3.new(30, 30, 30) })
		make("PointLight", { Range = 80, Brightness = 3, Shadows = false }, holder)
	end
	local c = s.capsule

	-- 2. CRUCERO hacia Marte
	if t < cfg.entry then
		local k = t - cfg.space
		local cf = CFrame.new(SPACE + Vector3.new(k * 2, 0, -k * 6)) * CFrame.Angles(math.rad(-70), k * 0.1, 0)
		c.model:PivotTo(cf)
		if s.marsBall then
			s.marsBall.Size = Vector3.new(160, 160, 160) * (1 + k * 0.12)
		end
		local center = cf.Position
		cam.CFrame = CFrame.lookAt(center + Vector3.new(22 - k, 8, 26), center)
		cam.FieldOfView = 55
		infoLabel.Text = "VISTA SIMULADA · CRUCERO A MARTE"
		return
	end

	-- 3 a 6. MARTE: entrada, paracaídas, grúa celeste y aterrizaje
	if not s.marsReady then
		s.marsReady = true
		buildMarsScene(s)
		overrideSky(s, "marte")
		for _, part in ipairs(c.cruise) do                  -- la etapa de crucero se descarta antes de entrar
			part.Transparency = 1
		end
		-- etapa de descenso con cuatro retrocohetes (va adentro de la coraza hasta la grúa celeste)
		s.stage = scenery(s, { Size = Vector3.new(9.5, 1.6, 9.5), Color = Color3.fromRGB(205, 165, 70), Material = Enum.Material.Foil, Transparency = 1 })
		s.retro = {}
		for i = 1, 4 do
			s.retro[i] = scenery(s, { Size = Vector3.new(0.7, 2.4, 0.7), Color = FLAME, Material = Enum.Material.Neon, Transparency = 1 })
		end
		s.cords = {}
		for i = 1, 3 do
			s.cords[i] = scenery(s, { Size = Vector3.new(0.12, 0.12, 1), Color = WHITE, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
		end
		s.chuteCords = {}
		for i = 1, 4 do
			s.chuteCords[i] = scenery(s, { Size = Vector3.new(0.12, 0.12, 1), Color = WHITE, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
		end
		s.canopy = scenery(s, { Shape = Enum.PartType.Ball, Size = Vector3.new(24, 9, 24), Color = Color3.fromRGB(240, 120, 40), Material = Enum.Material.Fabric, Transparency = 1 })
		if s.vehicle and s.vehicle.Parent then
			s.roverClone = cloneModel(s, s.vehicle, "RoverEnMarte")
			for _, part in ipairs(s.roverClone:GetDescendants()) do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 1
				end
			end
		end
		s.touchPart, s.touchDust = dustBurst(s, MARS + Vector3.new(0, 0.5, 0), Color3.fromRGB(200, 120, 80))
		s.fire = newEmitter(c.shield, {
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 80, 20)),
			Size = seq({ 0, 4 }, { 1, 0.5 }), Transparency = seq({ 0, 0.1 }, { 1, 1 }), LightEmission = 1,
			Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(20, 30), Rate = 0,
			SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Right,       -- hacia atrás (arriba de la cápsula)
		})
		table.insert(s.emitters, s.fire)
	end

	local ground = MARS
	local yaw = CFrame.Angles(0, math.rad(25), 0)
	local capsuleCF, look, camPos, fov

	-- altura de la cápsula sobre el suelo
	if t < cfg.chute then
		local k = smooth((t - cfg.entry) / (cfg.chute - cfg.entry))
		capsuleCF = CFrame.new(ground + Vector3.new(-160 + 130 * k, 240 - 170 * k, -80 + 70 * k)) * yaw * CFrame.Angles(0, 0, math.rad(-18 * (1 - k)))
		c.plasma.Transparency = 0.25 + 0.75 * k
		s.fire.Rate = 120 * (1 - k)
		camPos = capsuleCF.Position + Vector3.new(30, 6, 24)
		look = capsuleCF.Position
		fov = 50
	elseif t < cfg.crane then
		local k = smooth((t - cfg.chute) / (cfg.crane - cfg.chute))
		capsuleCF = CFrame.new(ground + Vector3.new(-30 + 30 * k, 70 - 25 * k, -10 + 10 * k)) * yaw
		c.plasma.Transparency = 1
		s.fire.Rate = 0
		camPos = ground + Vector3.new(36, 30 - 10 * k, 40)
		look = capsuleCF.Position + Vector3.new(0, 8, 0)
		fov = 52
	else
		-- la coraza y el paracaídas se alejan; la etapa de descenso sigue sola
		local k = t - cfg.crane
		capsuleCF = CFrame.new(ground + Vector3.new(k * 6, 45 + k * 3, 0)) * yaw
		camPos = ground + Vector3.new(24, 7, 30)
		look = ground + Vector3.new(0, 6, 0)
		fov = 55
	end
	c.model:PivotTo(capsuleCF)

	-- escudo térmico: se suelta y cae un poco después de abrir el paracaídas
	if t >= cfg.chute + 1.5 then
		local f = t - (cfg.chute + 1.5)
		c.shield.CFrame = capsuleCF * CFrame.new(0, -f * f * 6 - f * 2, f * 2) * CFrame.Angles(0, 0, math.rad(90 + f * 20))
		c.shield.Transparency = f > 3 and 1 or 0
	end

	-- paracaídas
	local chuteOn = t >= cfg.chute and t < cfg.touchdown
	s.canopy.Transparency = chuteOn and 0 or 1
	local top = capsuleCF.Position + Vector3.new(0, 26, 0)
	s.canopy.CFrame = CFrame.new(top)
	for i, cord in ipairs(s.chuteCords) do
		local a = math.rad(i * 90 + 45)
		stretch(cord, capsuleCF.Position + Vector3.new(math.cos(a) * 2.5, 5.5, math.sin(a) * 2.5), top + Vector3.new(math.cos(a) * 10, -3, math.sin(a) * 10))
		cord.Transparency = chuteOn and 0 or 1
	end

	-- etapa de descenso y rover (grúa celeste)
	local stageH, cable
	if t < cfg.crane then
		stageH, cable = nil, nil
	elseif t < cfg.crane + 2 then
		local k = smooth((t - cfg.crane) / 2)
		stageH, cable = 44 - 26 * k, 0.4
	elseif t < cfg.touchdown then
		local k = smooth((t - cfg.crane - 2) / (cfg.touchdown - cfg.crane - 2))
		stageH, cable = 18 - 7 * k, 0.4 + 6.5 * k
	else
		local k = t - cfg.touchdown
		stageH, cable = 11 + k * k * 4 + k * 3, nil       -- corta los cables y se va volando
	end

	if stageH then
		local away = t >= cfg.touchdown and (t - cfg.touchdown) * 14 or 0
		local stageCF = CFrame.new(ground + Vector3.new(-away, stageH, away * 0.4)) * yaw
		s.stage.CFrame = stageCF
		s.stage.Transparency = 0
		local burning = true
		for i, flame in ipairs(s.retro) do
			local a = math.rad(i * 90 + 45)
			flame.CFrame = stageCF * CFrame.new(math.cos(a) * 3.9, -1.9, math.sin(a) * 3.9) * CFrame.Angles(0, 0, math.rad(math.cos(a) * 20))
			flame.Transparency = burning and (0.15 + math.abs(math.noise(t * 25, i)) * 0.4) or 1
		end
		-- rover: colgado de los cables hasta tocar el suelo; después rueda un poco
		if s.roverClone then
			if not s.roverShown then
				s.roverShown = true
				for _, part in ipairs(s.roverClone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.LocalTransparencyModifier = 0
					end
				end
			end
			local roverCF
			if cable then
				roverCF = CFrame.new(ground + Vector3.new(0, math.max(0, stageH - 0.6 - cable - ROVER_TOP), 0)) * yaw
			else
				local roll = smooth((t - cfg.touchdown - 1.5) / 4) * 6
				roverCF = CFrame.new(ground) * yaw * CFrame.new(0, 0, -roll)
			end
			s.roverClone:PivotTo(roverCF)
			for i, cord in ipairs(s.cords) do
				local a = math.rad(i * 120)
				stretch(cord, stageCF.Position + Vector3.new(math.cos(a) * 2.6, -0.8, math.sin(a) * 2.6), roverCF.Position + Vector3.new(math.cos(a) * 2.2, ROVER_TOP, math.sin(a) * 2.2), 0.1)
				cord.Transparency = cable and 0 or 1
			end
		end
	end
	s.touchDust.Rate = (stageH and stageH < 20 and t < cfg.touchdown + 1.5) and 110 or 0

	s.look = s.look:Lerp(look, math.clamp(dt * 4, 0, 1))
	if t - dt < cfg.entry + 0.05 then
		s.look = look
	end
	cam.CFrame = CFrame.lookAt(camPos, s.look) * shake(t, (t > cfg.entry and t < cfg.chute) and 0.08 or 0)
	cam.FieldOfView = fov
	infoLabel.Text = "VISTA SIMULADA · MARTE · CRÁTER JEZERO"
end

---------------------------------------------------------------------------
-- Llegada a la sala de control: plano general + travelling hasta el puesto del jugador
---------------------------------------------------------------------------
local ARRIVE_TIME = 6.5

function Cinematica._stepArrive(s, cam, t)
	local focus = s.arriveCF
	local fwd = focus.LookVector
	local startPos = (focus * CFrame.new(-16, 16, 16)).Position
	local endPos = (focus * CFrame.new(0, 3.2, 4)).Position
	local startLook = focus.Position + fwd * 24 + Vector3.new(0, 6, 0)
	local endLook = focus.Position + fwd * 14 + Vector3.new(0, 4, 0)
	local a = smooth(t / (ARRIVE_TIME - 0.8))
	cam.CFrame = CFrame.lookAt(startPos:Lerp(endPos, a), startLook:Lerp(endLook, a))
	cam.FieldOfView = 78 - 10 * a
	black.BackgroundTransparency = smooth(t / 1.4)
	if t > 0.6 and not s.arriveSay1 then
		s.arriveSay1 = true
		say("SALA DE CONTROL · Tu puesto es el escritorio del centro.")
	end
	if t > 3.2 and not s.arriveSay2 then
		s.arriveSay2 = true
		say("La señal tarda " .. string.lower(s.arriveDelay or "") .. " en llegar: hay que decidir con anticipación.")
	end
	if t >= ARRIVE_TIME then
		cleanup(s)
		release(s, false)
	end
end

function Cinematica.arrive(focusCF, delayText)
	local s = session
	if not s or s.phase ~= "waiting" then
		return
	end
	s.phase = "arrive"
	s.arriveCF = focusCF
	s.arriveDelay = delayText
	s.arriveStart = os.clock()
	playSound("ambiente", false, 0.4)
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
function Cinematica.play(info)
	build()
	Cinematica.cancel()
	local cfg = CFG[info.kind]
	if not cfg or typeof(info.stand) ~= "CFrame" then
		return
	end
	local s = { info = info, kind = info.kind, cfg = cfg, fx = {}, sounds = {}, emitters = {}, cancelled = false, phase = "intro" }
	session = s
	Cinematica.onHud(false)
	black.BackgroundTransparency = 1
	tween(black, 0.5, { BackgroundTransparency = 0 })
	task.delay(0.55, function()
		if session == s and not s.cancelled then
			beginSequence(s)
		end
	end)
end

function Cinematica.init(remote, onHud)
	Cinematica.remote = remote
	Cinematica.onHud = onHud or Cinematica.onHud
	build()
end

---------------------------------------------------------------------------
-- TOUR DEL MAPA (tecla T o botón 🎬): planos de dron por el centro espacial, para mostrar el mapa
-- o grabar un video. Solo mueve la cámara de este jugador; no cambia nada del juego.
-- Cada plano: dur (s), texto, y cam(k) → posición y punto al que mira (k va de 0 a 1).
---------------------------------------------------------------------------
local FLOOR = 201
local TOUR = {
	{ dur = 8, text = "CENTRO ESPACIAL · Cabo Cañaveral, Florida", fov = 60, cam = function(k)
		local a = math.rad(200 + 80 * k)
		return Vector3.new(math.cos(a) * 430, FLOOR + 230 - 70 * k, -20 + math.sin(a) * 430), Vector3.new(0, FLOOR, -20)
	end },
	{ dur = 6, text = "La entrada: avenida de banderas y palmeras", fov = 58, cam = function(k)
		return Vector3.new(6, FLOOR + 22 - 8 * k, 720 - 440 * k), Vector3.new(0, FLOOR + 14, 150)
	end },
	{ dur = 7, text = "Atlas V 541 · el cohete que llevó a Perseverance a Marte", fov = 55, cam = function(k)
		local a = math.rad(110 + 110 * k)
		local base = Vector3.new(100, FLOOR + 1, -180)
		return base + Vector3.new(math.cos(a) * 75, 8 + 45 * k, math.sin(a) * 75), base + Vector3.new(0, 28 + 14 * k, 0)
	end },
	{ dur = 6, text = "Hangar 1 · Atlas V 551 de New Horizons, listo para ir a Plutón", fov = 62, cam = function(k)
		return Vector3.new(-92, FLOOR + 4 + 40 * k, -34 + 6 * k), Vector3.new(-129, FLOOR + 8 + 42 * k, 0)
	end },
	{ dur = 7, text = "Edificio de Ensamblaje de Vehículos", fov = 60, cam = function(k)
		local z = 140 - 330 * k
		return Vector3.new(-280, FLOOR + 40 + 20 * k, z), Vector3.new(-380, FLOOR + 70, z * 0.6 - 40)
	end },
	{ dur = 7, text = "Plataformas de lanzamiento junto al mar", fov = 55, cam = function(k)
		return Vector3.new(360 + 40 * k, FLOOR + 55, -120 - 220 * k), Vector3.new(490, FLOOR + 35, -560)
	end },
	{ dur = 7, text = "Elegí tu misión: New Horizons o Perseverance", fov = 60, cam = function(k)
		return Vector3.new(160 - 60 * k, FLOOR + 30 + 220 * k, -60 + 340 * k), Vector3.new(0, FLOOR + 10, -40)
	end },
}

local tour = nil

function Cinematica.isTouring()
	return tour ~= nil
end

function Cinematica.stopTour()
	local t = tour
	if not t then
		return
	end
	tour = nil
	pcall(function()
		RunService:UnbindFromRenderStep("TourDelMapa")
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
	subtitle.Text = ""
	skipButton.Visible = false
	skipButton.Text = "SALTAR ▶▶"
	setBars(false)
	tween(black, 0.4, { BackgroundTransparency = 1 })
	if t.onDone then
		t.onDone()
	end
end

-- onDone: lo que hay que restaurar al terminar (el menú, el HUD)
function Cinematica.tour(onDone)
	if session or tour then
		return false
	end
	build()
	tour = { start = os.clock(), index = 0, onDone = onDone }
	local total = 0
	for _, shot in ipairs(TOUR) do
		shot.from = total
		total += shot.dur
	end
	setBars(true)
	skipButton.Text = "SALIR ✕"
	skipButton.Visible = true
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("TourDelMapa", Enum.RenderPriority.Camera.Value + 2, function()
		local t = tour
		if not t then
			return
		end
		local elapsed = os.clock() - t.start
		if elapsed >= total then
			Cinematica.stopTour()
			return
		end
		local index = 1
		for i, shot in ipairs(TOUR) do
			if elapsed >= shot.from then
				index = i
			end
		end
		local shot = TOUR[index]
		local local_t = elapsed - shot.from
		if index ~= t.index then
			t.index = index
			say(shot.text)
			pcall(function()                         -- que la zona del plano esté cargada (StreamingEnabled)
				player:RequestStreamAroundAsync(shot.cam(0.5), 2)
			end)
		end
		-- fundido corto entre planos
		local fade = math.max(1 - smooth(local_t / 0.5), smooth((local_t - shot.dur + 0.5) / 0.5))
		if index == #TOUR then
			fade = 1 - smooth(local_t / 0.5)
		end
		black.BackgroundTransparency = 1 - fade
		local pos, target = shot.cam(smooth(local_t / shot.dur))
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(pos, target)
		cam.FieldOfView = shot.fov
	end)
	return true
end

return Cinematica
