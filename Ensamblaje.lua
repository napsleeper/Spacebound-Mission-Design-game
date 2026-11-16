--[[
	ENSAMBLAJE · ModuleScript (hijo del LocalScript "ControlDeMisionCliente") · v5

	Anima los brazos robóticos del hangar. El servidor ya decidió todo (qué pieza, en qué
	lugar, cuánto dura); acá solo se mueve el brazo y una copia local de la pieza:
	  1. la pieza aparece resaltada en la mesa de transferencia
	  2. el brazo baja, la toma y la levanta
	  3. la lleva hasta su lugar en la nave y la suelta
	  4. destello verde de confirmación (la pieza real la coloca el servidor)
	En reposo, los brazos se balancean despacio. Cinemática inversa de dos tramos.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Ensamblaje = {}

local player = Players.LocalPlayer
local arms = {}             -- nombre → datos del brazo
local busy = {}             -- nombre → true mientras anima

local YELLOW = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(61, 255, 122)
local RED = Color3.fromRGB(252, 61, 33)

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function worldFolder(name)
	local root = workspace:FindFirstChild("ControlDeMision")
	return root and root:FindFirstChild(name)
end

-- Registra los brazos que ya llegaron del servidor
local function scan()
	local folder = worldFolder("Brazos")
	if not folder then
		return
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("Base") and not arms[model.Name] then
			local parts = {}
			for _, name in ipairs({ "Torreta", "Brazo", "Codo", "Antebrazo", "Muneca", "Pinza", "DedoA", "DedoB" }) do
				parts[name] = model:FindFirstChild(name)
			end
			if parts.Brazo and parts.Antebrazo and parts.Pinza then
				arms[model.Name] = {
					model = model, parts = parts, base = model:GetAttribute("Base"),
					L1 = model:GetAttribute("L1") or 11, L2 = model:GetAttribute("L2") or 11,
					hombro = model:GetAttribute("Hombro") or 6.4, mission = model.Name:match("^(%a+)%-"),
					center = model:GetAttribute("Centro"),          -- el brazo de la torre mira al cohete
				}
			end
		end
	end
	-- centro del hangar de cada misión = punto medio entre sus dos brazos del piso
	for name, arm in pairs(arms) do
		if not arm.center and not name:match("BrazoC$") then
			local a = arms[arm.mission .. "-BrazoA"]
			local b = arms[arm.mission .. "-BrazoB"]
			if a and b then
				a.center = (a.base + b.base) / 2
				b.center = a.center
			end
		end
	end
end

-- Posiciona el brazo para que la muñeca quede en "wrist" (Vector3). open = separación de los dedos
local function pose(arm, wrist, open)
	local p = arm.parts
	local S = arm.base + Vector3.new(0, arm.hombro, 0)
	local d = wrist - S
	local horizontal = Vector3.new(d.X, 0, d.Z)
	local r = horizontal.Magnitude
	local forward = r > 0.01 and horizontal.Unit or Vector3.new(0, 0, -1)
	local reach = arm.L1 + arm.L2 - 0.05
	local D = math.clamp(d.Magnitude, 0.6, reach)
	local W = d.Magnitude > 0.01 and (S + d.Unit * D) or (S + Vector3.new(0, D, 0))
	local elevation = math.atan2(d.Y, math.max(r, 0.001))
	local cosA = math.clamp((arm.L1 ^ 2 + D ^ 2 - arm.L2 ^ 2) / (2 * arm.L1 * D), -1, 1)
	local a = elevation + math.acos(cosA)                          -- codo hacia arriba
	local E = S + forward * (arm.L1 * math.cos(a)) + Vector3.new(0, arm.L1 * math.sin(a), 0)

	local side = forward:Cross(Vector3.new(0, 1, 0))           -- perpendicular al plano del brazo
	local turretPos = arm.base + Vector3.new(0, 5.8, 0)
	if p.Torreta then
		p.Torreta.CFrame = CFrame.lookAt(turretPos, turretPos + forward)
	end
	p.Brazo.CFrame = CFrame.lookAt((S + E) / 2, E, side)
	if p.Codo then
		p.Codo.CFrame = CFrame.new(E)
	end
	p.Antebrazo.CFrame = CFrame.lookAt((E + W) / 2, W, side)
	if p.Muneca then
		p.Muneca.CFrame = CFrame.new(W)
	end
	local grip = CFrame.lookAt(W, W + forward)
	p.Pinza.CFrame = grip * CFrame.new(0, -1.1, 0)
	if p.DedoA and p.DedoB then
		p.DedoA.CFrame = grip * CFrame.new(-open, -2.1, 0)
		p.DedoB.CFrame = grip * CFrame.new(open, -2.1, 0)
	end
	return W
end

local function idleWrist(arm, t)
	local toCenter = arm.center and Vector3.new(arm.center.X - arm.base.X, 0, arm.center.Z - arm.base.Z) or Vector3.new(0, 0, -1)
	toCenter = toCenter.Magnitude > 0.01 and toCenter.Unit or Vector3.new(0, 0, -1)
	local sway = Vector3.new(math.sin(t * 0.5) * 0.8, math.sin(t * 0.8) * 0.5, math.cos(t * 0.5) * 0.8)
	return arm.base + Vector3.new(0, 13.5, 0) + toCenter * 6 + sway
end

local function lerpPath(points, k)
	-- recorre una lista de { t, pos } con suavizado entre cada par
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		if k <= b.t then
			local f = smooth((k - a.t) / math.max(b.t - a.t, 1e-3))
			return a.pos:Lerp(b.pos, f)
		end
	end
	return points[#points].pos
end

local function highlight(target, color, seconds)
	if not target or not target.Parent then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.65
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = target
	task.delay(seconds, function()
		h:Destroy()
	end)
end

local function vehicleOf()
	local root = workspace:FindFirstChild("ControlDeMision")
	local folder = root and root:FindFirstChild("Jugador_" .. player.UserId)
	return folder and folder:FindFirstChild("Nave")
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
function Ensamblaje.install(info)
	scan()
	local arm = arms[info.arm]
	local folder = worldFolder("Brazos")
	local tablePart = folder and folder:FindFirstChild(info.table)
	local pieces = worldFolder("Piezas")
	local template = pieces and pieces:FindFirstChild(info.template)
	if not arm or not tablePart or not template or typeof(info.to) ~= "CFrame" then
		return
	end
	busy[info.arm] = true
	local ghost = template:Clone()
	for _, part in ipairs(ghost:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	ghost.Name = "PiezaAnimada"
	ghost.Parent = workspace
	if type(info.scale) == "number" and info.scale > 0 and info.scale ~= 1 then
		ghost:ScaleTo(info.scale)           -- la nave se arma a escala reducida (entra en la cofia del Atlas V)
	end
	local rotation = info.to - info.to.Position
	local pick = CFrame.new(tablePart.Position + Vector3.new(0, 0.2, 0)) * rotation
	ghost:PivotTo(pick)
	local height = ghost:GetExtentsSize().Y
	highlight(ghost, YELLOW, info.duration * 0.6)

	local center = arm.center or arm.base
	local outward = Vector3.new(info.to.Position.X - center.X, 0, info.to.Position.Z - center.Z)
	outward = outward.Magnitude > 0.01 and outward.Unit or Vector3.new(0, 0, 1)
	local hold = Vector3.new(0, height + 2.4, 0)
	local start = idleWrist(arm, os.clock())
	local abovePick = pick.Position + Vector3.new(0, height + 7, 0)
	local atPick = pick.Position + hold
	local aboveSlot = info.to.Position + hold + Vector3.new(0, 4, 0) + outward * 3
	local atSlot = info.to.Position + hold
	local path = {
		{ t = 0, pos = start }, { t = 0.14, pos = abovePick }, { t = 0.24, pos = atPick }, { t = 0.34, pos = abovePick },
		{ t = 0.62, pos = aboveSlot }, { t = 0.74, pos = atSlot }, { t = 0.80, pos = atSlot }, { t = 0.92, pos = aboveSlot },
		{ t = 1.0, pos = aboveSlot },
	}
	local t0 = os.clock()
	local connection
	local flashed = false
	connection = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / info.duration
		if not arm.model.Parent or k > 1.25 then
			connection:Disconnect()
			if ghost.Parent then
				ghost:Destroy()
			end
			busy[info.arm] = nil
			return
		end
		local wrist = lerpPath(path, math.min(k, 1))
		local closed = k >= 0.22 and k < 0.77
		pose(arm, wrist, closed and 0.25 or 0.5)
		if k >= 0.24 and k < 0.77 then
			ghost:PivotTo(CFrame.new(wrist - hold) * rotation)
		elseif k >= 0.77 then
			ghost:PivotTo(info.to)
			if not flashed then
				flashed = true
				highlight(ghost, GREEN, 0.5)
			end
		end
		if k >= 1 and ghost.Parent then
			ghost:Destroy()
		end
	end)
end

-- Oculta (o vuelve a mostrar) la nave real solo en este cliente, mientras se anima la copia
local function setHidden(model, hidden)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = hidden and 1 or 0
		elseif part:IsA("SurfaceGui") then
			part.Enabled = not hidden
		end
	end
end

-- Un brazo toma la nave ENTERA y la lleva a otro lugar: del banco a la cofia del Atlas V,
-- o del banco al transportador. Si hay cohete, sus dos mitades de cofia se abren y se cierran.
-- info = { arm, model, from (CFrame), to (CFrame), duration, rocket (opcional) }
function Ensamblaje.insert(info)
	scan()
	local arm = arms[info.arm]
	local model = info.model
	if not arm or typeof(model) ~= "Instance" or typeof(info.from) ~= "CFrame" or typeof(info.to) ~= "CFrame" then
		return
	end
	local duration = math.max(tonumber(info.duration) or 4, 0.5)
	busy[info.arm] = true

	-- copia que viaja con la pinza; la nave real se esconde hasta que el servidor la ubique
	local ghost = model:Clone()
	for _, part in ipairs(ghost:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	ghost.Name = "NaveAnimada"
	ghost.Parent = workspace
	ghost:PivotTo(info.from)
	setHidden(model, true)
	local boxCF, boxSize = ghost:GetBoundingBox()
	local top = boxCF.Position.Y + boxSize.Y / 2 - info.from.Position.Y      -- altura de la nave sobre su pivote
	local hold = Vector3.new(0, top + 2.4, 0)

	-- mitades de la cofia (se mueven solo en este cliente)
	local halves = {}
	local rocket = info.rocket
	if typeof(rocket) == "Instance" then
		for _, entry in ipairs({ { "CofiaA", -1 }, { "CofiaB", 1 } }) do
			local half = rocket:FindFirstChild(entry[1])
			if half then
				table.insert(halves, { model = half, home = half:GetPivot(), dir = entry[2] })
			end
		end
	end
	local function openFairing(amount)
		for _, h in ipairs(halves) do
			if h.model.Parent then
				h.model:PivotTo(h.home * CFrame.new(0, 0, h.dir * 5.5 * amount))
			end
		end
	end

	-- recorrido: baja a la nave, la levanta, se acerca de costado al destino, la apoya y vuelve
	local toArm = Vector3.new(arm.base.X - info.to.Position.X, 0, arm.base.Z - info.to.Position.Z)
	toArm = toArm.Magnitude > 0.01 and toArm.Unit or Vector3.new(1, 0, 0)
	local start = idleWrist(arm, os.clock())
	local atPick = info.from.Position + hold
	local abovePick = atPick + Vector3.new(0, 4, 0)
	local atSlot = info.to.Position + hold
	local beside = atSlot + toArm * (halves[1] and 4 or 2) + Vector3.new(0, 1.5, 0)
	local path = {
		{ t = 0, pos = start }, { t = 0.14, pos = abovePick }, { t = 0.22, pos = atPick }, { t = 0.32, pos = abovePick },
		{ t = 0.58, pos = beside }, { t = 0.72, pos = atSlot }, { t = 0.78, pos = atSlot }, { t = 0.9, pos = beside },
		{ t = 1.0, pos = beside },
	}
	local rotFrom = info.from - info.from.Position
	local rotTo = info.to - info.to.Position
	highlight(ghost, YELLOW, duration * 0.3)

	local t0 = os.clock()
	local connection
	local flashed = false
	connection = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / duration
		if not arm.model.Parent or k > 1.15 then
			connection:Disconnect()
			if ghost.Parent then
				ghost:Destroy()
			end
			openFairing(0)
			if model.Parent then
				setHidden(model, false)
			end
			busy[info.arm] = nil
			return
		end
		-- la cofia se abre al principio y se cierra después de soltar la nave
		openFairing(smooth(k / 0.2) * (1 - smooth((k - 0.82) / 0.16)))
		local wrist = lerpPath(path, math.min(k, 1))
		local holding = k >= 0.2 and k < 0.76
		pose(arm, wrist, holding and 0.25 or 0.5)
		if k < 0.22 then
			ghost:PivotTo(info.from)
		elseif k < 0.76 then
			local turn = smooth((k - 0.32) / 0.4)
			ghost:PivotTo(CFrame.new(wrist - hold) * rotFrom:Lerp(rotTo, turn))
		else
			ghost:PivotTo(info.to)
			if not flashed then
				flashed = true
				highlight(ghost, GREEN, 0.6)
			end
		end
	end)
end

function Ensamblaje.installed(info)
	local vehicle = vehicleOf()
	if not vehicle then
		return
	end
	local piece = vehicle:FindFirstChild("Pieza" .. tostring(info.index))
	highlight(piece or vehicle, GREEN, 1.2)
end

function Ensamblaje.removing(info)
	local vehicle = vehicleOf()
	if not vehicle then
		return
	end
	local piece = vehicle:FindFirstChild("Pieza" .. tostring(info.index))
	highlight(piece or vehicle, RED, 0.7)
end

function Ensamblaje.init()
	scan()
	local lastScan = os.clock()
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if t - lastScan > 2 then
			lastScan = t
			scan()
		end
		for name, arm in pairs(arms) do
			if not busy[name] then
				if arm.model.Parent then
					pose(arm, idleWrist(arm, t + #name), 0.5)
				else
					arms[name] = nil
				end
			end
		end
	end)
end

return Ensamblaje
