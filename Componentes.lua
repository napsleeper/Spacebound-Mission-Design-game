--[[
	COMPONENTES · ModuleScript compartido · v8
	DÓNDE VA: ReplicatedStorage > ControlDeMisionCompartido > Componentes

	Ficha técnica de cada pieza. Masa y costo siguen en MISSIONS (script principal); acá van los
	datos de ingeniería que usan el comparador, el laboratorio, el panel de recursos y las maniobras.

	v8: las misiones son NEW HORIZONS y PERSEVERANCE. En cada subsistema una opción es la que
	eligió la NASA (real = true, se marca con ★) y la otra es una alternativa para comparar.
	Cada ficha dice de dónde sale cada número:
	  fuente   = dato publicado (NASA, JPL, JHUAPL)
	  estimado = lo que no está publicado por pieza y el juego necesita (ver DATOS_REALES.md)

	Campos:
	  funcion        qué hace la pieza
	  consumoW       potencia que consume en operación (W)
	  produccionW    potencia eléctrica que produce (W). Sonda: en Plutón. Rover: a pleno Sol / siempre.
	  almacenamientoWh  energía almacenada (Wh)
	  capacidad      texto corto con la capacidad principal
	  rendimiento    texto corto con el rendimiento
	  ventajas / desventajas  listas cortas
	  + campos numéricos propios (isp, tasaMBmin, maxMB, kbps, mbPorUnidad, pendienteMax, traccion...)
]]

local C = {}

-- Plataforma: lo que tiene la nave aunque no sea una pieza elegible (estructura, computadoras,
-- control térmico, cableado...). Su masa es la masa real menos las piezas:
--   New Horizons: 401 kg secos − (57 + 25 + 15 + 30) = 274 kg
--   Perseverance: 1.025 kg − (150 + 72 + 59) = 744 kg (incluye el brazo de 2 m con su torreta de 45 kg)
-- El consumo de la plataforma es ESTIMADO (la NASA no publica el reparto por equipo).
C.BASE = {
	probe = { consumoW = 120, masa = 274, nombre = "Plataforma de New Horizons (estructura, aviónica, control térmico)" },
	rover = { consumoW = 50, masa = 744, nombre = "Plataforma de Perseverance (chasis, brazo, computadoras, muestras)" },
}

-- El rover no elige antena: usa una radio UHF fija hacia los orbitadores de relevo (escala del juego)
C.RADIO_ROVER = { consumoW = 20, tasaMBmin = 6, ventanaMin = 8.5 }
-- Pase de la Red del Espacio Profundo para la sonda (escala del juego)
C.VENTANA_SONDA = 14.2

C.FICHAS = {
	-------------------------------------------------------------------------
	-- NEW HORIZONS
	-------------------------------------------------------------------------
	["probe-power-A"] = {
		funcion = "Paneles solares dimensionados para dar 180 W en Plutón.",
		consumoW = 0, produccionW = 180, almacenamientoWh = 0, solar = true, areaM2 = 515, eficiencia = 0.28,
		capacidad = "180 W en Plutón con ~515 m² de paneles", rendimiento = "1.361 W/m² a 1 UA, 1,25 W/m² a 33 UA",
		compatibilidad = "Ninguna: es demasiado grande y pesado para el Atlas V.",
		ventajas = { "No usa material radiactivo" },
		desventajas = { "≈ 1.030 kg: 2,5 veces la nave entera", "En Plutón casi no hay luz" },
		estimado = "Área = 180 W / (1,25 W/m² × 28 %). Masa ≈ 2 kg/m² (estimación).",
	},
	["probe-power-B"] = {
		funcion = "Generador termoeléctrico de radioisótopos (RTG): el calor del plutonio-238 se vuelve electricidad.",
		consumoW = 0, produccionW = 200, almacenamientoWh = 0, produccionLanzamientoW = 240, real = true,
		capacidad = "240 W al despegar · 200 W en Plutón", rendimiento = "Funciona lejos del Sol durante décadas",
		compatibilidad = "Alcanza para los 180 W que pedía la NASA en Plutón.",
		ventajas = { "57 kg", "No depende del Sol", "Su calor abriga la nave" },
		desventajas = { "Pierde unos 4 W por año", "Caro y con controles de seguridad" },
		fuente = "RTG de 57 kg, ~240 W al despegar y ~200 W en Plutón (NASA, Spaceflight Now, INL).",
	},
	["probe-propulsion-A"] = {
		funcion = "Hidracina monopropelente: se descompone en un catalizador y genera empuje.",
		consumoW = 5, produccionW = 0, almacenamientoWh = 0, isp = 220, real = true,
		capacidad = "16 propulsores: 4 × 4,4 N y 12 × 0,8 N", rendimiento = "Isp ≈ 220 s · ve ≈ 2.157 m/s",
		compatibilidad = "Con 77 kg de hidracina: Δv ideal ≈ 379 m/s.",
		ventajas = { "Simple y confiable", "Un solo tanque" },
		desventajas = { "Menos Δv por kilo que el bipropelente" },
		fuente = "77 kg de hidracina, 4 × 4,4 N + 12 × 0,8 N (NASA). Isp: valor típico de la hidracina.",
		estimado = "Masa del sistema (tanque, válvulas, propulsores): 25 kg estimados.",
	},
	["probe-propulsion-B"] = {
		funcion = "Bipropelente: combustible y oxidante se encienden al mezclarse (hipergólicos).",
		consumoW = 8, produccionW = 0, almacenamientoWh = 0, isp = 310,
		capacidad = "Isp ≈ 310 s", rendimiento = "ve ≈ 3.040 m/s",
		compatibilidad = "Solo entra en 480 kg si la nave ahorra masa en otro lado.",
		ventajas = { "41 % más de Δv con el mismo propelente" },
		desventajas = { "Dos tanques: ≈ 45 kg", "Más caro" },
		estimado = "Isp típico de MMH/N₂O₄. Masa del sistema: 45 kg estimados.",
	},
	["probe-comms-A"] = {
		funcion = "Solo la antena de ganancia media (0,3 m).",
		consumoW = 20, produccionW = 0, almacenamientoWh = 0, tasaMBmin = 0.3, maxMB = 4, kbps = 0.02,
		capacidad = "≈ 0,02 kbps desde Plutón", rendimiento = "(0,3 / 2,1)² = 1/49 de la antena grande",
		compatibilidad = "No alcanza para mandar las fotos de Plutón.",
		ventajas = { "Liviana", "No hace falta apuntar tan exacto" },
		desventajas = { "49 veces menos datos" },
		fuente = "New Horizons tiene una antena de ganancia media de 0,3 m (NASA).",
		estimado = "La tasa sale de escalar la de la antena grande por el área. Masa: 3 kg estimados.",
	},
	["probe-comms-B"] = {
		funcion = "Antena de alta ganancia de 2,1 m: concentra la señal en un haz angosto.",
		consumoW = 25, produccionW = 0, almacenamientoWh = 0, tasaMBmin = 15, maxMB = 213, kbps = 1, real = true,
		capacidad = "≈ 1 kbps desde Plutón", rendimiento = "La señal tarda 4 h 25 min",
		compatibilidad = "La que usó New Horizons para bajar todos los datos de Plutón.",
		ventajas = { "49 veces más datos que la antena chica" },
		desventajas = { "Hay que apuntarla con precisión a la Tierra" },
		fuente = "Antena de 2,1 m (Weaver et al., 2008). ~1 kbps desde Plutón (NASA).",
		estimado = "Masa (plato, amplificadores): 15 kg estimados. MB por ventana: escala del juego.",
	},
	["probe-science-A"] = {
		funcion = "Solo LORRI, la cámara telescópica.",
		consumoW = 6, produccionW = 0, almacenamientoWh = 0, mbPorUnidad = 30,
		capacidad = "Fotos en blanco y negro de alta resolución", rendimiento = "Sin color ni composición química",
		compatibilidad = "Ahorra masa para otra pieza más pesada.",
		ventajas = { "≈ 9 kg", "Bajo consumo" },
		desventajas = { "Pierde 6 de los 7 instrumentos" },
		estimado = "Masa y consumo de LORRI: ≈ 9 kg y ≈ 6 W (estimados).",
	},
	["probe-science-B"] = {
		funcion = "Los 7 instrumentos de New Horizons: Ralph, Alice, LORRI, REX, SWAP, PEPSSI y SDC.",
		consumoW = 30, produccionW = 0, almacenamientoWh = 0, mbPorUnidad = 75, real = true,
		capacidad = "Color, infrarrojo, ultravioleta, radio y polvo", rendimiento = "Menos de 12 W a la vez en Plutón",
		compatibilidad = "La que voló: menos de 30 kg y 30 W en total.",
		ventajas = { "Dos veces y media más datos", "Composición de Plutón y su atmósfera" },
		desventajas = { "30 kg", "No se pueden prender todos juntos" },
		fuente = "Menos de 30 kg y 30 W; menos de 12 W a la vez en Plutón (Weaver et al., 2008).",
	},
	-------------------------------------------------------------------------
	-- PERSEVERANCE
	-------------------------------------------------------------------------
	["rover-mobility-A"] = {
		funcion = "Suspensión rocker-bogie con seis ruedas de aluminio.",
		consumoW = 150, produccionW = 0, almacenamientoWh = 0, pendienteMax = 30, vuelco = 45, real = true,
		traccion = { regolito = 0.50, roca = 0.62, mixto = 0.56 },
		capacidad = "Aguanta 45° sin volcar · evita más de 30°", rendimiento = "Máximo 4,2 cm/s (152 m/h)",
		compatibilidad = "La de Curiosity y Perseverance.",
		ventajas = { "Muy estable", "Supera rocas del tamaño de una rueda" },
		desventajas = { "Pesada (≈ 150 kg)" },
		fuente = "Rocker-bogie, ruedas de aluminio, 152 m/h (NASA). 45°/30°: diseño de Curiosity y Perseverance.",
		estimado = "Masa, consumo y tracción por terreno: estimados.",
	},
	["rover-mobility-B"] = {
		funcion = "Ruedas de malla de alambre, como las del Rover Lunar del Apolo.",
		consumoW = 90, produccionW = 0, almacenamientoWh = 0, pendienteMax = 20, vuelco = 38,
		traccion = { regolito = 0.55, roca = 0.40, mixto = 0.48 },
		capacidad = "Pendientes de hasta 20°", rendimiento = "Buena en regolito suelto",
		compatibilidad = "Pensada para la Luna y para un vehículo mucho más liviano.",
		ventajas = { "Ahorra 70 kg", "Menos consumo" },
		desventajas = { "Sufre en pendientes fuertes y sobre roca" },
		estimado = "Todos sus números son estimados para comparar.",
	},
	["rover-power-A"] = {
		-- produccionW es a pleno Sol: de noche o con tormenta de polvo baja (ver Ingenieria, prueba de energía)
		funcion = "Paneles solares con las mismas dos baterías.",
		consumoW = 0, produccionW = 330, almacenamientoWh = 2408, solar = true,
		capacidad = "≈ 330 W a pleno Sol + ≈ 2.400 Wh", rendimiento = "Depende de la luz y del polvo",
		compatibilidad = "Bien con rutas cortas y el instrumento de bajo consumo.",
		ventajas = { "Más liviana y barata", "Sin plutonio" },
		desventajas = { "De noche no produce", "El polvo tapa los paneles" },
		calefaccionSombraW = 150,
		estimado = "4 m² × 586 W/m² (Sol en Marte) × 28 % × ½ por ángulo y polvo ≈ 330 W. Masa ≈ 52 kg.",
	},
	["rover-power-B"] = {
		funcion = "Generador de radioisótopos MMRTG y dos baterías de ion-litio.",
		consumoW = 0, produccionW = 110, almacenamientoWh = 2408, real = true,
		capacidad = "110 W siempre + 2 baterías de 43 Ah", rendimiento = "Funciona de día, de noche y con polvo",
		compatibilidad = "La de Perseverance: las baterías cubren los picos de hasta 900 W.",
		ventajas = { "No depende del Sol", "Su calor protege los circuitos del frío" },
		desventajas = { "Pesado (72 kg)", "Caro" },
		calefaccionSombraW = 30,
		fuente = "MMRTG de 45 kg con 4,8 kg de PuO₂, ~110 W; baterías 2 × 43 Ah, 26,5 kg (JPL).",
		estimado = "Energía de las baterías: 2 × 43 Ah × 28 V ≈ 2.408 Wh (28 V estimado).",
	},
	["rover-science-A"] = {
		funcion = "Solo dos instrumentos del mástil: Mastcam-Z y SuperCam.",
		consumoW = 60, produccionW = 0, almacenamientoWh = 0, mbPorUnidad = 30,
		capacidad = "Fotos con zoom y láser a distancia", rendimiento = "Composición de la superficie",
		compatibilidad = "Combina con cualquier fuente de energía.",
		ventajas = { "Liviana (≈ 15 kg)", "Bajo consumo" },
		desventajas = { "Sin taladro: no guarda muestras" },
		estimado = "Masa y consumo estimados.",
	},
	["rover-science-B"] = {
		funcion = "Los 7 instrumentos de Perseverance y el taladro con 43 tubos de muestras.",
		consumoW = 250, produccionW = 0, almacenamientoWh = 0, mbPorUnidad = 75, real = true,
		capacidad = "59 kg de instrumentos · 43 tubos", rendimiento = "Busca rastros de vida antigua",
		compatibilidad = "Pide MMRTG para trabajar de noche.",
		ventajas = { "Dos veces y media más datos", "Guarda muestras para traer a la Tierra" },
		desventajas = { "Alto consumo", "Pesado" },
		fuente = "Mastcam-Z, MEDA, MOXIE, PIXL, RIMFAX, SHERLOC y SuperCam: 59 kg; 43 tubos (JPL).",
		estimado = "Consumo medio estimado (el pico del rover llega a 900 W).",
	},
}

function C.ficha(missionKey, subKey, code)
	return C.FICHAS[missionKey .. "-" .. subKey .. "-" .. code]
end

-- Masa fija de la plataforma (kg)
function C.masaBase(missionKey)
	return C.BASE[missionKey] and C.BASE[missionKey].masa or 0
end

-- Número con coma decimal (máximo un decimal) para los textos
local function num(n)
	if n ~= 0 and math.abs(n) < 0.95 then
		return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.", ","))
	end
	if math.abs(n - math.round(n)) < 0.05 then
		return tostring(math.round(n))
	end
	return (string.format("%.1f", n):gsub("%.", ","))
end
C.num = num

-- Resumen de rendimiento de un diseño (sirve con piezas faltantes: las ignora)
--   mods = { power = "A", ... } · masaSeca = plataforma + piezas (kg) · propelente (kg, solo sonda)
function C.resumen(missionKey, mods, masaSeca, propelente, Educativo)
	local r = { consumoW = C.BASE[missionKey].consumoW, produccionW = 0, almacenamientoWh = 0, produccionSolarW = 0 }
	for key, code in pairs(mods) do
		local f = C.ficha(missionKey, key, code)
		if f then
			r.consumoW += f.consumoW or 0
			r.produccionW += f.produccionW or 0
			r.almacenamientoWh += f.almacenamientoWh or 0
			if f.solar then
				r.produccionSolarW += f.produccionW or 0
			end
		end
	end
	if missionKey == "rover" then
		r.consumoW += C.RADIO_ROVER.consumoW
		r.tasaMBmin = C.RADIO_ROVER.tasaMBmin
		r.maxMB = math.floor(C.RADIO_ROVER.tasaMBmin * C.RADIO_ROVER.ventanaMin)
	else
		local f = mods.comms and C.ficha(missionKey, "comms", mods.comms)
		r.tasaMBmin = f and f.tasaMBmin or 0
		r.maxMB = f and f.maxMB or 0
		r.kbps = f and f.kbps or 0
	end
	-- Autonomía para el peor caso. Rover: de noche los paneles no producen.
	-- Sonda: no tiene baterías (como New Horizons): o la producción cubre el consumo, o no.
	local neto
	if missionKey == "rover" then
		neto = r.consumoW - (r.produccionW - r.produccionSolarW)
	else
		neto = r.consumoW - r.produccionW
	end
	r.netoW = neto
	if neto <= 0 then
		r.autonomiaH = math.huge
	elseif r.almacenamientoWh > 0 then
		r.autonomiaH = r.almacenamientoWh / neto
	else
		r.autonomiaH = 0
	end
	local sci = mods.science and C.ficha(missionKey, "science", mods.science)
	r.mbPorUnidad = sci and sci.mbPorUnidad or 0
	if missionKey == "probe" and mods.propulsion and Educativo then
		local f = C.ficha(missionKey, "propulsion", mods.propulsion)
		r.propulsion = Educativo.presupuesto(f.isp, masaSeca, propelente or 0)
	end
	return r
end

-- Texto del comparador A vs B (monitor de cada sala de piezas). ★ = la que eligió la NASA.
function C.comparar(missionKey, sub, cost, mass, budget, massMax, current)
	local A = C.ficha(missionKey, sub.key, "A")
	local B = C.ficha(missionKey, sub.key, "B")
	local oa, ob = sub.A, sub.B
	local function signo(n)
		return (n > 0 and "+" or "") .. tostring(n)
	end
	local function star(f)
		return f.real and " ★" or ""
	end
	local function proj(option)
		local old = current and sub[current] or nil
		local c = cost - (old and old.cost or 0) + option.cost
		local m = mass - (old and old.mass or 0) + option.mass
		local ok = c <= budget and m <= massMax
		return string.format("$%d M · %d kg %s", c, m, ok and "✓" or "✗ excede")
	end
	local lines = {
		"COMPARADOR · " .. sub.title .. "   (★ = elección de la NASA)",
		"",
		string.format("[A] %s%s  vs  [B] %s%s", oa.name, star(A), ob.name, star(B)),
		string.format("Masa: %d vs %d kg (B %s kg)", oa.mass, ob.mass, signo(ob.mass - oa.mass)),
		string.format("Costo ≈ $%d vs $%d M (estimado del juego)", oa.cost, ob.cost),
		string.format("Capacidad: %s  |  %s", A.capacidad, B.capacidad),
		string.format("Consumo: %s W  |  %s W", num(A.consumoW or 0), num(B.consumoW or 0)),
	}
	if (A.produccionW or 0) + (B.produccionW or 0) > 0 then
		table.insert(lines, string.format("Producción: %d W  |  %d W", A.produccionW or 0, B.produccionW or 0))
	end
	table.insert(lines, "A ✓ " .. table.concat(A.ventajas, " · ") .. "   ✗ " .. table.concat(A.desventajas, " · "))
	table.insert(lines, "B ✓ " .. table.concat(B.ventajas, " · ") .. "   ✗ " .. table.concat(B.desventajas, " · "))
	table.insert(lines, "")
	table.insert(lines, "Total si elegís A: " .. proj(oa))
	table.insert(lines, "Total si elegís B: " .. proj(ob))
	return table.concat(lines, "\n")
end

return C
