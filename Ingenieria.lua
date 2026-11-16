--[[
	INGENIERÍA · ModuleScript compartido · v5
	DÓNDE VA: ReplicatedStorage > ControlDeMisionCompartido > Ingenieria

	Pruebas configurables del Laboratorio de Ingeniería. Cada prueba recibe el diseño del
	jugador y los parámetros que eligió en la consola, y devuelve un informe técnico.
	Los resultados son deterministas: mismo diseño + mismos parámetros = mismo resultado.

	El cliente usa PRUEBAS para dibujar los controles; el servidor valida los parámetros
	(ajustar) y ejecuta (ejecutar). Modelos simplificados con fines educativos.
]]

local Ingenieria = {}

-- Definición de pruebas y parámetros por misión
Ingenieria.PRUEBAS = {
	probe = {
		{ clave = "energia", nombre = "ENERGÍA", params = {
			{ clave = "fase", nombre = "Etapa del viaje", opciones = { "DESPEGUE (1 UA)", "JÚPITER (5,2 UA)", "PLUTÓN (33 UA)" }, def = 3 },
			{ clave = "instrumentos", nombre = "Instrumentos", opciones = { "TODOS", "DE A UNO (12 W)", "APAGADOS" }, def = 1 },
			{ clave = "antena", nombre = "Transmisor", opciones = { "TRANSMITIENDO", "APAGADO" }, def = 1 },
		} },
		{ clave = "propulsion", nombre = "PROPULSIÓN", params = {
			{ clave = "maniobras", nombre = "Correcciones planificadas", min = 1, max = 8, paso = 1, def = 2, unidad = "" },
			{ clave = "dv", nombre = "Δv por corrección", min = 5, max = 150, paso = 5, def = 20, unidad = "m/s" },
		} },
		{ clave = "comunicaciones", nombre = "COMUNICACIONES", params = {
			{ clave = "distancia", nombre = "Distancia a la Tierra", min = 1, max = 50, paso = 1, def = 33, unidad = "UA" },
			{ clave = "ventana", nombre = "Pase de la antena DSN", min = 2, max = 12, paso = 1, def = 8, unidad = "h" },
		} },
	},
	rover = {
		{ clave = "movilidad", nombre = "MOVILIDAD", params = {
			{ clave = "pendiente", nombre = "Pendiente del escenario", min = 0, max = 35, paso = 5, def = 25, unidad = "°" },
			{ clave = "terreno", nombre = "Terreno", opciones = { "REGOLITO SUELTO", "ROCA", "MIXTO" }, def = 1 },
		} },
		{ clave = "energia", nombre = "ENERGÍA", params = {
			{ clave = "luz", nombre = "Iluminación solar", min = 0, max = 100, paso = 10, def = 0, unidad = "%" },
			{ clave = "horas", nombre = "Duración", min = 1, max = 24, paso = 1, def = 4, unidad = "h" },
			{ clave = "traccion", nombre = "Tracción", opciones = { "EN MARCHA", "DETENIDO" }, def = 1 },
		} },
		{ clave = "comunicaciones", nombre = "COMUNICACIONES", params = {
			{ clave = "ventana", nombre = "Ventana del relevo", min = 4, max = 12, paso = 1, def = 8, unidad = "min" },
			{ clave = "obstruccion", nombre = "Pared del cráter", opciones = { "SIN OBSTRUCCIÓN", "TAPA EL 40 %" }, def = 1 },
		} },
	},
}

function Ingenieria.buscar(missionKey, clave)
	for _, prueba in ipairs(Ingenieria.PRUEBAS[missionKey] or {}) do
		if prueba.clave == clave then
			return prueba
		end
	end
end

-- Valores por defecto de una prueba
function Ingenieria.defaults(prueba)
	local v = {}
	for _, p in ipairs(prueba.params) do
		v[p.clave] = p.def
	end
	return v
end

-- Valida lo que manda el cliente: números dentro de rango y alineados al paso
function Ingenieria.ajustar(prueba, valores)
	local v = {}
	valores = type(valores) == "table" and valores or {}
	for _, p in ipairs(prueba.params) do
		local x = tonumber(valores[p.clave]) or p.def
		if p.opciones then
			x = math.clamp(math.floor(x + 0.5), 1, #p.opciones)
		else
			x = math.clamp(x, p.min, p.max)
			x = p.min + math.floor((x - p.min) / p.paso + 0.5) * p.paso
		end
		v[p.clave] = x
	end
	return v
end

local function barra(pct)
	local n = math.clamp(math.floor(pct / 10 + 0.5), 0, 10)
	return string.rep("■", n) .. string.rep("□", 10 - n)
end

local function horasTexto(h)
	if h == math.huge then
		return "sin límite (el generador cubre el consumo)"
	end
	return string.format("%.1f h", h)
end

---------------------------------------------------------------------------
-- Ejecutar una prueba
--   d = { mission, mods, masa, propelente, resumen (Componentes.resumen), ficha(fn) }
--   devuelve { titulo, lineas, veredicto ("ok"|"riesgo"|"falla"), visual = {...} }
---------------------------------------------------------------------------
function Ingenieria.ejecutar(missionKey, clave, v, d, Educativo, Componentes)
	local L = {}
	local function add(s)
		table.insert(L, s)
	end
	local veredicto, visual = "ok", { tipo = clave }
	local r = d.resumen

	if clave == "energia" and missionKey == "probe" then
		-- New Horizons no tiene baterías: en cada etapa el consumo tiene que entrar en lo que se produce
		local power = Componentes.ficha("probe", "power", d.mods.power)
		local distancias = { 1, 5.2, 33 }
		local dUA = distancias[v.fase]
		local produccion
		if power.solar then
			produccion = Educativo.potenciaSolar(power.areaM2, power.eficiencia, dUA)
		else
			-- el RTG pierde potencia de a poco: 240 W al despegar, 200 W en Plutón (9,5 años después)
			local anios = ({ 0, 1.1, 9.5 })[v.fase]
			produccion = power.produccionLanzamientoW - (power.produccionLanzamientoW - power.produccionW) * anios / 9.5
		end
		local sci = d.mods.science and Componentes.ficha("probe", "science", d.mods.science)
		local comms = d.mods.comms and Componentes.ficha("probe", "comms", d.mods.comms)
		local instrumentos = 0
		if sci then
			instrumentos = ({ sci.consumoW, math.min(sci.consumoW, 12), 0 })[v.instrumentos]
		end
		local consumo = Componentes.BASE.probe.consumoW + instrumentos
			+ ((v.antena == 1 and comms) and comms.consumoW or 0)
			+ (d.mods.propulsion and Componentes.ficha("probe", "propulsion", d.mods.propulsion).consumoW or 0)
		local margen = produccion - consumo
		local pct = produccion > 0 and margen / produccion * 100 or -100
		add(string.format("Distancia al Sol: %s UA", Componentes.num(dUA)))
		if power.solar then
			add(string.format("Luz del Sol: 1.361 / %s² = %s W/m²", Componentes.num(dUA), Componentes.num(Educativo.SOLAR_1UA / dUA ^ 2)))
		end
		add(string.format("Producción: %s W · consumo: %s W", Componentes.num(produccion), Componentes.num(consumo)))
		add(string.format("Instrumentos: %s W · plataforma: %d W", Componentes.num(instrumentos), Componentes.BASE.probe.consumoW))
		add(string.format("Margen: %+.0f W  %s", margen, barra(math.clamp(pct, 0, 100))))
		add("Sin baterías: lo que se consume tiene que producirse en el momento.")
		if margen < 0 then
			veredicto = "falla"
			add("✗ No alcanza. Prendé los instrumentos de a uno (como hizo la NASA) o apagá el transmisor.")
		elseif pct < 8 then
			veredicto = "riesgo"
			add("~ Alcanza con muy poco margen.")
		else
			add("✓ La energía alcanza en esta etapa.")
		end
		visual.carga = math.clamp(50 + pct, 0, 100)

	elseif clave == "energia" and missionKey == "rover" then
		local power = Componentes.ficha("rover", "power", d.mods.power)
		local mob = d.mods.mobility and Componentes.ficha("rover", "mobility", d.mods.mobility)
		local sci = d.mods.science and Componentes.ficha("rover", "science", d.mods.science)
		local consumo = Componentes.BASE.rover.consumoW + Componentes.RADIO_ROVER.consumoW + (sci and sci.consumoW or 0)
			+ ((v.traccion == 1 and mob) and mob.consumoW or 0)
		local calef = (power.calefaccionSombraW or 0) * (1 - v.luz / 100)
		-- los paneles solares producen según la luz; el generador nuclear, siempre igual
		local produccion = power.solar and r.produccionW * v.luz / 100 or r.produccionW
		local neto = consumo + calef - produccion
		local usado = math.max(0, neto) * v.horas
		local carga = math.clamp(100 - usado / r.almacenamientoWh * 100, 0, 100)
		local autonomia = neto <= 0 and math.huge or (r.almacenamientoWh / neto)
		add(string.format("Iluminación: %d %% · tracción: %s", v.luz, v.traccion == 1 and "en marcha" or "detenida"))
		add(string.format("Producción: %d W%s", math.floor(produccion + 0.5), power.solar and " (paneles solares)" or " (MMRTG)"))
		add("Real: el MMRTG da ~110 W y las baterías cubren picos de hasta 900 W.")
		add(string.format("Consumo: %d W + calefacción %d W", consumo, math.floor(calef + 0.5)))
		add(string.format("Almacenamiento: %d Wh", r.almacenamientoWh))
		add(string.format("Carga al final de %d h: %s %d %%", v.horas, barra(carga), math.floor(carga + 0.5)))
		add("Autonomía: " .. horasTexto(autonomia))
		if carga < 20 then
			veredicto = "falla"
			add("✗ Se queda sin energía. De noche o con tormenta de polvo conviene el generador nuclear.")
		elseif carga < 50 then
			veredicto = "riesgo"
			add("~ Llega con poco margen. Reducí el uso del instrumento o la tracción.")
		else
			add("✓ Energía suficiente.")
		end
		visual.carga = carga

	elseif clave == "propulsion" then
		local f = Componentes.ficha("probe", "propulsion", d.mods.propulsion)
		local b = Educativo.presupuesto(f.isp, d.masa, d.propelente)
		local requerido = v.maniobras * v.dv
		local m = b.m0
		local gastado = 0
		local hechas = 0
		for _ = 1, v.maniobras do
			local mp = Educativo.propelenteParaDv(f.isp, m, v.dv)
			if gastado + mp > d.propelente then
				break
			end
			gastado += mp
			m -= mp
			hechas += 1
		end
		add(string.format("Masa seca: %d kg · propelente: %.1f kg", b.seca, b.propelente))
		add(string.format("Masa inicial m0: %.1f kg · masa final mf: %.1f kg", b.m0, b.mf))
		add(string.format("Isp: %d s · ve = Isp·g0 = %d m/s", b.isp, math.floor(b.ve + 0.5)))
		add(string.format("Δv disponible = ve·ln(m0/mf) = %d m/s", math.floor(b.dv + 0.5)))
		add(string.format("Δv requerido: %d × %d = %d m/s", v.maniobras, v.dv, requerido))
		add(string.format("Propelente usado: %.1f kg en %d de %d maniobras", gastado, hechas, v.maniobras))
		local margen = b.dv - requerido
		add(string.format("Margen: %s%d m/s  %s", margen >= 0 and "+" or "", math.floor(margen + 0.5), barra(math.clamp(margen / math.max(1, b.dv) * 100, 0, 100))))
		add(string.format("Cada corrección con 4 × 4,4 N dura %.0f s (Newton: t = m·Δv/F)", Educativo.duracionQuema(b.m0, v.dv, 17.6)))
		add("Real: la TCM-1 de 2006 fue de 18 m/s y la NASA reservó 92 m/s para correcciones.")
		if hechas < v.maniobras then
			veredicto = "falla"
			add("✗ No alcanza para todas las correcciones. Bajá la masa o planificá menos Δv.")
		elseif margen < b.dv * 0.2 then
			veredicto = "riesgo"
			add("~ Alcanza, con menos de 20 % de margen.")
		else
			add("✓ Δv suficiente con margen.")
		end
		visual.margen = margen

	elseif clave == "comunicaciones" and missionKey == "probe" then
		-- Unidades reales: kbps. La señal cae con la distancia al cuadrado (referencia: ~1 kbps a 33 UA con la antena de 2,1 m)
		local comms = Componentes.ficha("probe", "comms", d.mods.comms)
		local kbps = comms.kbps * (33 / v.distancia) ^ 2
		local mbPase = kbps * 1000 * v.ventana * 3600 / 8 / 1e6
		local sci = d.mods.science and Componentes.ficha("probe", "science", d.mods.science)
		local generado = (sci and sci.mbPorUnidad == 75) and 6250 or 1500       -- MB del sobrevuelo (≈ 6,25 GB reales con los 7 instrumentos)
		local pases = mbPase > 0 and generado / mbPase or math.huge
		local margenDb = 10 * math.log10(math.max(kbps, 1e-6) / 0.5)              -- modelo simplificado: 0 dB a 0,5 kbps
		add(string.format("Antena: %s · %d W", d.mods.comms == "B" and "alta ganancia (2,1 m)" or "ganancia media (0,3 m)", comms.consumoW))
		add(string.format("Tasa a %d UA: %s kbps (cae con la distancia al cuadrado)", v.distancia, kbps >= 10 and string.format("%.0f", kbps) or string.format("%.2f", kbps)))
		add(string.format("Datos por pase de %d h: %.1f MB", v.ventana, mbPase))
		add(string.format("Datos del sobrevuelo: ≈ %d MB", generado))
		add(string.format("Pases de %d h para bajarlos todos: %s", v.ventana, pases == math.huge and "∞" or string.format("%.0f", pases)))
		add(string.format("Margen de enlace (modelo simplificado): %.1f dB", margenDb))
		add("Real: New Horizons tardó unos 16 meses en bajar todo desde Plutón.")
		if margenDb < -6 then
			veredicto = "falla"
			add("✗ La señal casi no se distingue del ruido: hace falta la antena grande.")
		elseif margenDb < 0 or pases > 3000 then
			veredicto = "riesgo"
			add("~ Llegan datos, pero muy despacio.")
		else
			add("✓ Enlace posible: los datos llegan de a poco, pase tras pase.")
		end
		visual.porVentana = mbPase

	elseif clave == "comunicaciones" and missionKey == "rover" then
		local tasa = Componentes.RADIO_ROVER.tasaMBmin * (v.obstruccion == 2 and 0.6 or 1)
		local porVentana = tasa * v.ventana
		local generado = r.mbPorUnidad * 2
		add(string.format("Radio UHF al relevo: %d MB/min%s", Componentes.RADIO_ROVER.tasaMBmin, v.obstruccion == 2 and " × 0,6 (obstrucción)" or ""))
		add(string.format("Datos por ventana de %d min: %.0f MB", v.ventana, porVentana))
		add(string.format("Datos que genera la misión: ~%d MB", generado))
		if porVentana < generado * 0.5 then
			veredicto = "falla"
			add("✗ No llegaría ni la mitad. Esperá una ventana más larga o salí del cráter.")
		elseif porVentana < generado then
			veredicto = "riesgo"
			add("~ Habrá que comprimir o elegir qué datos enviar.")
		else
			add("✓ Sube todos los datos en una ventana.")
		end
		visual.porVentana = porVentana

	elseif clave == "movilidad" then
		local mob = Componentes.ficha("rover", "mobility", d.mods.mobility)
		local terrenos = { "regolito", "roca", "mixto" }
		local mu = mob.traccion[terrenos[v.terreno]]
		local requerida = math.tan(math.rad(v.pendiente))
		local estabilidad = math.clamp((mob.vuelco - v.pendiente) / mob.vuelco * 100, 0, 100)
		local maxTraccion = math.deg(math.atan(mu))
		local maxSuperable = math.min(mob.pendienteMax, maxTraccion)
		local riesgo = math.clamp((v.pendiente / math.max(1, maxSuperable)) ^ 3 * 100, 0, 100)
		if requerida > mu or v.pendiente > mob.pendienteMax then
			riesgo = 100
		end
		local consumo = math.floor(mob.consumoW * (1 + v.pendiente / 30) + 0.5)
		add(string.format("Escenario: %d° sobre %s", v.pendiente, ({ "regolito suelto", "roca", "terreno mixto" })[v.terreno]))
		add(string.format("Estabilidad (margen al vuelco de %d°): %s %d %%", mob.vuelco, barra(estabilidad), math.floor(estabilidad + 0.5)))
		add(string.format("Tracción disponible μ = %.2f · requerida tan θ = %.2f", mu, requerida))
		add(string.format("Consumo de tracción: %d W", consumo))
		add(string.format("Pendiente máxima superable: %d°", math.floor(maxSuperable + 0.5)))
		add(string.format("Riesgo de quedar inmovilizado: %s %d %%", barra(riesgo), math.floor(riesgo + 0.5)))
		if riesgo >= 100 then
			veredicto = "falla"
			add("✗ No supera este escenario. Elegí otra ruta o la suspensión articulada.")
		elseif riesgo > 60 then
			veredicto = "riesgo"
			add("~ Lo supera con riesgo de patinar. Bajá la velocidad.")
		else
			add("✓ Supera el escenario con margen.")
		end
		visual.pendiente = v.pendiente
		visual.avance = 1 - riesgo / 100
	end

	return { titulo = "LABORATORIO DE INGENIERÍA · " .. (Ingenieria.buscar(missionKey, clave) or {}).nombre, lineas = L, veredicto = veredicto, visual = visual }
end

return Ingenieria
