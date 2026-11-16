--[[
	PANEL DE RECURSOS · ModuleScript (hijo del LocalScript "ControlDeMisionCliente") · v5

	Amplía el panel v4 sin cambiar su forma de uso (Panel.new, panel:update, panel:toast).

	EN EL HANGAR
	  MASA y PRESUPUESTO: actual, máximo, % usado, lo que queda y, con una pieza en las manos,
	  el valor proyectado (barra blanca) y el costo de esa pieza.
	  Verde → amarillo (85 %) → rojo (más del 100 %).
	  Debajo, desplegable: ENERGÍA (producción, consumo, almacenamiento, autonomía),
	  PROPULSIÓN (propelente, Δv disponible y Δv requerido) y ENLACE (capacidad y datos).
	  Botón BRAZO: velocidad de la animación del brazo robótico (normal, rápida u omitir).

	EN VUELO
	  Energía, integridad, propelente y Δv (sonda) o margen térmico (vehículo), y enlace
	  (datos pendientes frente a la capacidad de la ventana). Todo viene del servidor.

	"Dato NASA": tarjeta corta que aparece al agarrar una pieza y se va sola.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Panel = {}
Panel.__index = Panel

local SPACE = Color3.fromRGB(5, 11, 31)
local NAVY = Color3.fromRGB(10, 22, 52)
local RED = Color3.fromRGB(252, 61, 33)
local WHITE = Color3.fromRGB(245, 247, 250)
local MUTED = Color3.fromRGB(157, 179, 222)
local GREEN = Color3.fromRGB(61, 255, 122)
local YELLOW = Color3.fromRGB(255, 200, 40)
local CYAN = Color3.fromRGB(56, 189, 248)

local WARN_RATIO = 0.85
local ANIM_ORDER = { "normal", "rapida", "omitir" }
local ANIM_NAMES = { normal = "NORMAL", rapida = "RÁPIDA", omitir = "OMITIR" }

local function make(className, props, parent)
	local obj = Instance.new(className)
	for key, value in pairs(props) do
		obj[key] = value
	end
	obj.Parent = parent
	return obj
end

local function text(parent, props)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextTruncate = props.TextTruncate or Enum.TextTruncate.AtEnd
	return make("TextLabel", props, parent)
end

local function colorOf(ratio)
	if ratio > 1 then
		return RED
	elseif ratio >= WARN_RATIO then
		return YELLOW
	end
	return GREEN
end

local function tween(obj, time, goal)
	local t = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function thousands(n)
	local s = tostring(math.floor(n + 0.5))
	return (s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^(-?)%.", "%1"))
end

-- Barra con título, valor y una línea de detalle debajo
local function newGauge(parent, order, title, tall)
	local box = make("Frame", {
		LayoutOrder = order, Size = UDim2.new(1, 0, 0, tall and 50 or 38), BackgroundColor3 = NAVY, BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, box)
	local stroke = make("UIStroke", { Color = GREEN, Thickness = 1, Transparency = 0.6 }, box)
	local titleLabel = text(box, {
		Position = UDim2.fromOffset(8, 3), Size = UDim2.new(0.4, -8, 0, 16), Text = title, TextSize = 11,
		TextColor3 = MUTED, Font = Enum.Font.GothamBold,
	})
	local value = text(box, {
		Position = UDim2.new(0.3, 0, 0, 3), Size = UDim2.new(0.7, -8, 0, 16), Text = "", TextSize = 13,
		Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Right,
	})
	local track = make("Frame", {
		Position = UDim2.fromOffset(8, 22), Size = UDim2.new(1, -16, 0, 8), BackgroundColor3 = SPACE,
		BorderSizePixel = 0, ClipsDescendants = true,
	}, box)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, track)
	local ghost = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.5, BorderSizePixel = 0 }, track)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0 }, track)
	make("Frame", {
		Position = UDim2.fromScale(WARN_RATIO, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 3,
	}, track)
	local detail = text(box, {
		Position = UDim2.fromOffset(8, 33), Size = UDim2.new(1, -16, 0, 14), Text = "", TextSize = 11, TextColor3 = MUTED,
		Visible = tall == true,
	})
	return { box = box, stroke = stroke, fill = fill, ghost = ghost, value = value, detail = detail, title = titleLabel }
end

local function setBar(gauge, ratio, color)
	tween(gauge.fill, 0.4, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1), BackgroundColor3 = color })
	gauge.stroke.Color = color
	gauge.stroke.Transparency = color == GREEN and 0.6 or 0.2
end

local function updateLimitGauge(gauge, current, limit, projected, prefix, suffix, detailText)
	local ratio = current / limit
	setBar(gauge, ratio, colorOf(ratio))
	local valueText = prefix .. thousands(current)
	local valueColor = ratio > 1 and RED or WHITE
	if projected and projected ~= current then
		local projRatio = projected / limit
		valueText = prefix .. thousands(current) .. " → " .. thousands(projected)
		valueColor = projRatio > 1 and RED or (projRatio >= WARN_RATIO and YELLOW or WHITE)
		gauge.ghost.BackgroundColor3 = valueColor
		tween(gauge.ghost, 0.3, { Size = UDim2.fromScale(math.clamp(math.max(projRatio, ratio), 0, 1), 1) })
	else
		tween(gauge.ghost, 0.3, { Size = UDim2.fromScale(0, 1) })
	end
	gauge.value.Text = valueText .. " / " .. prefix .. thousands(limit) .. suffix .. (ratio > 1 and "  ⚠" or "")
	gauge.value.TextColor3 = valueColor
	gauge.detail.Text = detailText or ""
end

-- Fila compacta: nombre, valor y barrita
local function newRow(parent, order, title)
	local row = make("Frame", {
		LayoutOrder = order, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = NAVY, BackgroundTransparency = 0.35, BorderSizePixel = 0,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, row)
	text(row, { Position = UDim2.fromOffset(7, 2), Size = UDim2.new(0, 80, 0, 14), Text = title, TextSize = 10, TextColor3 = MUTED, Font = Enum.Font.GothamBold })
	local value = text(row, { Position = UDim2.new(0, 70, 0, 2), Size = UDim2.new(1, -77, 0, 14), Text = "", TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right })
	local track = make("Frame", { Position = UDim2.fromOffset(7, 19), Size = UDim2.new(1, -14, 0, 5), BackgroundColor3 = SPACE, BorderSizePixel = 0, ClipsDescendants = true }, row)
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, track)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = CYAN, BorderSizePixel = 0 }, track)
	return { row = row, value = value, fill = fill }
end

local function setRow(row, valueText, ratio, color)
	row.value.Text = valueText
	tween(row.fill, 0.4, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1), BackgroundColor3 = color or CYAN })
end

function Panel.new(parentGui, remote)
	local self = setmetatable({}, Panel)
	self.remote = remote
	self.expanded = false
	self.anim = "normal"

	local root = make("Frame", {
		Name = "PanelRecursos", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false,
	}, parentGui)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, root)
	if UserInputService.TouchEnabled then
		make("UIScale", { Scale = 0.78 }, root)
	end
	self.root = root

	self.mass = newGauge(root, 1, "MASA", true)
	self.budget = newGauge(root, 2, "PRESUPUESTO", true)

	local tools = make("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 }, root)
	self.toggle = make("TextButton", {
		Size = UDim2.new(0.6, -2, 1, 0), BackgroundColor3 = NAVY, BackgroundTransparency = 0.25, BorderSizePixel = 0,
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = WHITE, Text = "▸ ENERGÍA · PROPULSIÓN · ENLACE",
	}, tools)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, self.toggle)
	self.toggle.Activated:Connect(function()
		self.expanded = not self.expanded
		self:refreshExpanded()
	end)
	self.animButton = make("TextButton", {
		Position = UDim2.new(0.6, 2, 0, 0), Size = UDim2.new(0.4, -2, 1, 0), BackgroundColor3 = NAVY, BackgroundTransparency = 0.25,
		BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = YELLOW, Text = "BRAZO: NORMAL",
	}, tools)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, self.animButton)
	self.animButton.Activated:Connect(function()
		local index = table.find(ANIM_ORDER, self.anim) or 1
		self.anim = ANIM_ORDER[index % #ANIM_ORDER + 1]
		self.animButton.Text = "BRAZO: " .. ANIM_NAMES[self.anim]
		if self.remote then
			self.remote:FireServer("anim", self.anim)
		end
	end)
	self.tools = tools

	self.energy = newRow(root, 4, "ENERGÍA")
	self.prop = newRow(root, 5, "PROPULSIÓN")
	self.link = newRow(root, 6, "ENLACE")
	self.extra = newRow(root, 7, "INTEGRIDAD")

	-- Tarjeta educativa: corta y discreta
	self.toastGui = make("Frame", {
		Name = "DatoNASA", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 40), Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = NAVY, BackgroundTransparency = 0.12, BorderSizePixel = 0, Visible = false,
	}, parentGui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, self.toastGui)
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, self.toastGui)
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, self.toastGui)
	local tag = text(self.toastGui, { Size = UDim2.new(1, 0, 0, 14), Text = "DATO NASA", TextSize = 11, TextColor3 = RED, Font = Enum.Font.GothamBlack })
	tag.LayoutOrder = 1
	self.toastText = text(self.toastGui, {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "", TextSize = 14, TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None, TextColor3 = WHITE, Font = Enum.Font.GothamMedium,
	})
	self.toastText.LayoutOrder = 2
	self.toastToken = 0
	if UserInputService.TouchEnabled then
		make("UIScale", { Scale = 0.8 }, self.toastGui)
	end
	self.mode = "hangar"
	self:refreshExpanded()
	return self
end

function Panel:refreshExpanded()
	local show = self.mode == "flight" or self.expanded
	self.energy.row.Visible = show
	self.prop.row.Visible = show and self.hasProp ~= false
	self.link.row.Visible = show
	self.extra.row.Visible = self.mode == "flight"
	self.toggle.Text = (self.expanded and "▾ " or "▸ ") .. "ENERGÍA · PROPULSIÓN · ENLACE"
end

function Panel:setVisible(visible)
	self.root.Visible = visible
	if not visible then
		self.toastGui.Visible = false
	end
end

function Panel:toast(message)
	self.toastToken += 1
	local token = self.toastToken
	self.toastText.Text = message
	self.toastGui.Position = UDim2.new(0.5, 0, 1, 40)
	self.toastGui.Visible = true
	tween(self.toastGui, 0.4, { Position = UDim2.new(0.5, 0, 1, -12) })
	task.delay(7, function()
		if token == self.toastToken then
			tween(self.toastGui, 0.4, { Position = UDim2.new(0.5, 0, 1, 40) })
			task.delay(0.45, function()
				if token == self.toastToken then
					self.toastGui.Visible = false
				end
			end)
		end
	end)
end

function Panel:update(data)
	if not data or data.visible == false then
		self:setVisible(false)
		return
	end
	self:setVisible(true)
	self.mode = data.mode or "hangar"

	if self.mode == "flight" then
		self.mass.box.Visible = false
		self.budget.box.Visible = false
		self.tools.Visible = false
		self.hasProp = true
		setRow(self.energy, string.format("%d %%", data.power), data.power / 100, colorOf(1 - data.power / 100 + 0.15))
		setRow(self.extra, string.format("%d %%", data.integrity), data.integrity / 100, colorOf(1 - data.integrity / 100 + 0.15))
		if data.mission == "probe" then
			self.prop.row:FindFirstChildOfClass("TextLabel").Text = "PROPELENTE"
			setRow(self.prop, string.format("%.1f kg · Δv %s m/s", data.fuel, thousands(data.dv)), data.maxFuel > 0 and data.fuel / data.maxFuel or 0, CYAN)
		else
			self.prop.row:FindFirstChildOfClass("TextLabel").Text = "TÉRMICO"
			setRow(self.prop, string.format("%d %%", data.thermal), data.thermal / 100, colorOf(1 - data.thermal / 100 + 0.15))
		end
		local linkRatio = data.capacity > 0 and data.pending / data.capacity or 0
		setRow(self.link, string.format("%d MB pendientes / %d MB · enviados %d", data.pending, data.capacity, data.sent),
			linkRatio, colorOf(linkRatio))
		self:refreshExpanded()
		return
	end

	self.mass.box.Visible = true
	self.budget.box.Visible = true
	self.tools.Visible = true
	if data.anim and data.anim ~= self.anim then
		self.anim = data.anim
		self.animButton.Text = "BRAZO: " .. ANIM_NAMES[self.anim]
	end
	local massLeft = data.massMax - (data.carry and data.projMass or data.mass)
	local budgetLeft = data.budget - (data.carry and data.projCost or data.cost)
	updateLimitGauge(self.mass, data.mass, data.massMax, data.carry and data.projMass or nil, "", " kg",
		string.format("%d %% usado · quedan %s kg%s", math.floor(data.mass / data.massMax * 100 + 0.5), thousands(massLeft),
			data.carry and string.format(" · pieza %d kg", data.carry.mass) or ""))
	updateLimitGauge(self.budget, data.cost, data.budget, data.carry and data.projCost or nil, "$", " M",
		string.format("%d %% gastado · quedan $%s M%s", math.floor(data.cost / data.budget * 100 + 0.5), thousands(budgetLeft),
			data.carry and string.format(" · pieza $%d M", data.carry.cost) or ""))

	local e = data.energia
	if e then
		local autonomy = e.autonomia < 0 and "∞" or string.format("%.0f h", e.autonomia)
		local ratio = e.prod > 0 and math.min(e.cons / e.prod, 1.5) / 1.5 or (e.autonomia < 0 and 0 or math.clamp(1 - e.autonomia / 48, 0, 1))
		setRow(self.energy, string.format("+%d W / −%d W · %s Wh · %s", e.prod, e.cons, thousands(e.wh), autonomy), ratio,
			(e.prod >= e.cons or e.autonomia >= 24 or e.autonomia < 0) and GREEN or YELLOW)
	end
	local p = data.propulsion
	self.hasProp = p ~= nil
	if p then
		self.prop.row:FindFirstChildOfClass("TextLabel").Text = "PROPULSIÓN"
		local ratio = p.dv > 0 and p.req / p.dv or 1
		setRow(self.prop, p.isp > 0 and string.format("Δv %s m/s · req. %d (TCM) · %.0f kg", thousands(p.dv), p.req, p.prop) or "falta el motor",
			ratio, p.dv >= p.req * 1.2 and GREEN or (p.dv >= p.req and YELLOW or RED))
	end
	local l = data.enlace
	if l then
		local ratio = l.max > 0 and l.generado / l.max or 1
		setRow(self.link, string.format("%s MB/min · %d MB/ventana · ciencia ~%d MB", l.tasa < 1 and string.format("%.1f", l.tasa) or tostring(math.floor(l.tasa + 0.5)),
			math.floor(l.max + 0.5), math.floor(l.generado + 0.5)), ratio, colorOf(ratio))
	end
	self:refreshExpanded()
end

return Panel
