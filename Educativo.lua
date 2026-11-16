--[[
	EDUCATIVO · ModuleScript compartido · v8
	DÓNDE VA: ReplicatedStorage > ControlDeMisionCompartido > Educativo
	Lo usan el servidor (que decide el resultado real) y el cliente (que muestra la predicción).
	Como los dos usan las MISMAS fórmulas, la predicción de la consola coincide con lo que pasa.

	v8: las dos misiones son reales. La sonda es NEW HORIZONS (Plutón, 2006-2015) y el rover es
	PERSEVERANCE (Marte, 2020-2021). Los datos reales están en Educativo.REAL, cada uno con su
	fuente. Lo que no está publicado y el juego necesita se marca como ESTIMACIÓN (ver DATOS_REALES.md).

	UNIDADES (siempre las mismas en todo el juego)
	  masa: kg · velocidad: m/s · distancia orbital: km · μ: km³/s² · tiempo: s · Isp: s

	IMPORTANTE: el Δv DISPONIBLE de una nave (lo que puede cambiar su velocidad con el
	propelente que lleva) NO es la velocidad de lanzamiento. New Horizons salió de la Tierra a
	unos 16,2 km/s gracias al cohete Atlas V y a su tercera etapa; con su propia hidracina
	solo puede cambiar su velocidad unos cientos de m/s.
]]

local Educativo = {}

Educativo.G0 = 9.80665                 -- m/s², gravedad estándar (convención internacional)
Educativo.MU_TIERRA = 398600.4418      -- km³/s²
Educativo.R_TIERRA = 6378.137          -- km, radio ecuatorial
Educativo.MU_LUNA = 4902.8             -- km³/s²
Educativo.R_LUNA = 1737.4              -- km
Educativo.MU_SOL = 1.32712440018e11    -- km³/s²
Educativo.UA = 149597870.7             -- km, unidad astronómica
Educativo.GRAVEDAD_LUNAR = 1.62        -- m/s², cerca de 1/6 de la terrestre
Educativo.GRAVEDAD_MARTE = 3.71        -- m/s², cerca de 3/8 de la terrestre
Educativo.SOLAR_1UA = 1361             -- W/m², constante solar a 1 UA

-- Semieje mayor de las órbitas (UA). Plutón tiene una órbita muy excéntrica: en 2015 estaba a ~33 UA.
Educativo.PLANETAS = {
	{ clave = "tierra", nombre = "Tierra", a = 1.000 },
	{ clave = "marte", nombre = "Marte", a = 1.524 },
	{ clave = "jupiter", nombre = "Júpiter", a = 5.203 },
	{ clave = "pluton", nombre = "Plutón", a = 39.48 },
}

-- Impulso específico típico (s): hidracina monopropelente ~220 s · bipropelente MMH/N2O4 ~310 s
Educativo.ISP = { A = 220, B = 310 }

---------------------------------------------------------------------------
-- DATOS REALES (con fuente). Lo que dice "≈" o "estimado" no está publicado así: es cálculo
-- o estimación del juego y se explica en DATOS_REALES.md.
---------------------------------------------------------------------------
Educativo.REAL = {
	newHorizons = {
		masaLanzamiento = 478,            -- kg, con propelente (NASA; Spaceflight Now)
		hidracina = 77,                   -- kg (NASA; JHUAPL)
		masaSeca = 401,                   -- kg = 478 − 77
		limiteMasa = 480,                 -- kg: "the entire spacecraft mass had to be kept below 480 kg" (Weaver et al., 2008)
		propulsores = { { n = 4, empuje = 4.4 }, { n = 12, empuje = 0.8 } },   -- N (NASA)
		dvNasa = 290,                     -- m/s disponibles después del lanzamiento (Planetary Society)
		velocidadSalida = 16.26,          -- km/s respecto de la Tierra (NASA; otra fuente: 16,21)
		lanzador = "Atlas V 551 + Star 48B",
		lanzamiento = "19/1/2006",
		tcm1 = { { nombre = "TCM-1A", dv = 5, fecha = "28/1/2006" }, { nombre = "TCM-1B", dv = 13.3, fecha = "30/1/2006" } },
		tcmPresupuesto = 92,              -- m/s reservados para correcciones (Planetary Society)
		jupiter = { fecha = "28/2/2007", distanciaKm = 2300000, ganancia = 4, diasDesdeLanzamiento = 405 },
		pluton = { fecha = "14/7/2015", distanciaKm = 12500, velocidad = 13.78, distanciaUA = 33, luz = "4 h 25 min", anios = 9.5 },
		rtg = { masa = 57, wLanzamiento = 240, wPluton = 200, requeridoPluton = 180 },   -- RTG GPHS
		cargaUtil = { masa = 30, potencia = 30, alaVez = 12, instrumentos = 7 },          -- "menos de 30 kg y 30 W"
		antena = 2.1,                     -- m, antena de alta ganancia
		mga = 0.3,                        -- m, antena de ganancia media
	},
	perseverance = {
		masaRover = 1025,                 -- kg, con el brazo y su torreta de 45 kg (JPL)
		medidas = { largo = 3, ancho = 2.7, alto = 2.2 },   -- m (JPL)
		velocidadMax = 0.042,             -- m/s = 152 m/h en terreno plano y firme (NASA)
		mmrtg = { w = 110, masa = 45, plutonioKg = 4.8 },    -- W al empezar la misión (JPL)
		baterias = { n = 2, ah = 43, masa = 26.5 },          -- (JPL)
		picoW = 900,                      -- W de demanda máxima en actividades científicas (JPL)
		instrumentos = { n = 7, masa = 59 },                 -- Mastcam-Z, MEDA, MOXIE, PIXL, RIMFAX, SHERLOC, SuperCam
		tubos = 43,
		lanzador = "Atlas V 541",
		lanzamiento = "30/7/2020",
		aterrizaje = "18/2/2021",
		viajeDias = 203, viajeKm = 471e6,
		masas = { crucero = 539, coraza = 575, escudo = 440, descenso = 1070 },   -- kg; con el rover suman 3.649 kg
		edl = {
			entradaKmh = 19500, paracaidasM = 21.5, paracaidasKmh = 1512, paracaidasKm = 11, paracaidasSeg = 240,
			escudoSeg = 20, corazaKm = 2.1, propulsadaKmh = 306, gruaM = 20, gruaKmh = 2.7, cablesM = 7.6,
		},
		senal = "11 min 22 s",            -- retraso de la señal el día del aterrizaje (JPL)
		costoMillones = 2700,             -- US$ 2.400 M construir y lanzar + 300 M operar (JPL)
	},
}

---------------------------------------------------------------------------
-- ECUACIÓN DE TSIOLKOVSKY
---------------------------------------------------------------------------
-- Velocidad de escape de los gases: ve = Isp · g0
function Educativo.ve(isp)
	return isp * Educativo.G0
end

-- Presupuesto completo de propulsión. Devuelve todas las magnitudes por separado.
--   masaSeca:  todo lo que NO es propelente (kg)
--   propelente: masa de propelente cargada (kg)
function Educativo.presupuesto(isp, masaSeca, propelente)
	local m0 = masaSeca + propelente          -- masa inicial
	local mf = masaSeca                       -- masa final (sin propelente)
	local ve = Educativo.ve(isp)
	local dv = 0
	if masaSeca > 0 and propelente > 0 then
		dv = ve * math.log(m0 / mf)
	end
	return { seca = masaSeca, propelente = propelente, m0 = m0, mf = mf, isp = isp, ve = ve, dv = dv }
end

-- Compatibilidad con v4: Δv disponible a partir del código de propulsión
function Educativo.deltaV(codigoPropulsion, masaSeca, propelente)
	local isp = Educativo.ISP[codigoPropulsion] or Educativo.ISP.A
	return Educativo.presupuesto(isp, masaSeca, propelente).dv
end

-- Propelente que consume una maniobra de Δv partiendo de una masa actual m0 (kg)
--   mp = m0 · (1 − e^(−Δv / ve))
function Educativo.propelenteParaDv(isp, m0, dv)
	if dv <= 0 or m0 <= 0 then
		return 0
	end
	return m0 * (1 - math.exp(-dv / Educativo.ve(isp)))
end

-- Segunda ley de Newton: cuánto dura una quema de Δv con un empuje F (N) sobre una masa m (kg).
-- Aproximación de masa constante (en una corrección chica la masa casi no cambia): t = m · Δv / F
function Educativo.duracionQuema(masa, dv, empujeN)
	if empujeN <= 0 then
		return math.huge
	end
	return masa * dv / empujeN
end

---------------------------------------------------------------------------
-- MECÁNICA ORBITAL (órbitas de dos cuerpos, cálculo directo en Luau)
---------------------------------------------------------------------------
-- Vis-viva: v² = μ (2/r − 1/a). r y a en km; devuelve m/s.
function Educativo.visViva(mu, r, a)
	return math.sqrt(mu * (2 / r - 1 / a)) * 1000
end

function Educativo.velocidadCircular(mu, r)
	return math.sqrt(mu / r) * 1000
end

function Educativo.velocidadEscape(mu, r)        -- m/s
	return math.sqrt(2 * mu / r) * 1000
end

function Educativo.periodo(mu, a)          -- s
	return 2 * math.pi * math.sqrt(a ^ 3 / mu)
end

-- Transferencia de Hohmann entre dos órbitas circulares coplanares (radios en km)
function Educativo.hohmann(mu, r1, r2)
	local at = (r1 + r2) / 2
	local v1 = Educativo.velocidadCircular(mu, r1)
	local v2 = Educativo.velocidadCircular(mu, r2)
	local vp = Educativo.visViva(mu, r1, at)
	local va = Educativo.visViva(mu, r2, at)
	local dv1 = math.abs(vp - v1)
	local dv2 = math.abs(v2 - va)
	return {
		v1 = v1, v2 = v2, vPeri = vp, vApo = va, dv1 = dv1, dv2 = dv2, total = dv1 + dv2,
		tiempo = Educativo.periodo(mu, at) / 2, aTransfer = at,
	}
end

-- Hohmann alrededor del Sol, de la Tierra a otro planeta (órbitas circulares y coplanares).
-- dv1 = velocidad de salida que hay que sumarle a la de la Tierra (m/s); tiempo en s.
function Educativo.hohmannPlaneta(aUA)
	return Educativo.hohmann(Educativo.MU_SOL, Educativo.UA, aUA * Educativo.UA)
end

-- Potencia de un panel solar a d UA (ley de la inversa del cuadrado): W
function Educativo.potenciaSolar(areaM2, eficiencia, dUA)
	return Educativo.SOLAR_1UA / (dUA * dUA) * areaM2 * eficiencia
end

---------------------------------------------------------------------------
-- CORRECCIÓN DE TRAYECTORIA TCM (evento 1 de New Horizons)
-- Datos reales: después del lanzamiento, New Horizons hizo la TCM-1 en dos partes, los días 9 y
-- 11 (5 + 13,3 m/s; la NASA la planificó como una corrección de 18 m/s).
-- Regla física simplificada: un error de velocidad Δv produce, al llegar, un desvío de posición
-- que crece con el tiempo que falta (desvío ≈ error × tiempo). Para cancelar el MISMO desvío más
-- tarde hace falta más Δv: rendimiento = (días que faltan) / (días que faltaban el día 9).
-- En el juego el error es solo de velocidad a lo largo de la trayectoria: hay que FRENAR
-- (retrógrada). La dirección real de la TCM-1 fue un vector en 3D.
---------------------------------------------------------------------------
local LLEGADA_JUPITER = 405            -- días entre el lanzamiento (19/1/2006) y Júpiter (28/2/2007)
local function rendimientoDia(dia)
	return (LLEGADA_JUPITER - dia) / (LLEGADA_JUPITER - 9)
end

Educativo.MANIOBRA = {
	requerido = 18,
	momentos = {
		{ clave = "dia9", nombre = "DÍA 9", rendimiento = rendimientoDia(9), espera = "como la NASA" },
		{ clave = "dia100", nombre = "DÍA 100", rendimiento = rendimientoDia(100), espera = "3 meses después" },
		{ clave = "dia300", nombre = "DÍA 300", rendimiento = rendimientoDia(300), espera = "cerca de Júpiter" },
	},
	tolerancia = 2,         -- m/s de error aceptables
	maxDv = 120,
	paso = 2,
}

-- p = { m0, isp, combustible, bateriasLitio (bool) }
function Educativo.prediccionManiobra(p, dv, direccion, momentoIndex)
	local M = Educativo.MANIOBRA
	local momento = M.momentos[momentoIndex] or M.momentos[1]
	dv = math.clamp(dv, 0, M.maxDv)
	local signo = direccion == "retro" and 1 or -1
	local efectivo = dv * momento.rendimiento * signo
	local error = M.requerido - efectivo
	local consumo = Educativo.propelenteParaDv(p.isp, p.m0, dv)
	local alcanza = consumo <= p.combustible + 1e-6
	if not alcanza then
		-- sin propelente suficiente la quema se corta cuando se agota
		local dvReal = p.combustible > 0 and Educativo.ve(p.isp) * math.log(p.m0 / (p.m0 - p.combustible)) or 0
		efectivo = dvReal * momento.rendimiento * signo
		error = M.requerido - efectivo
		consumo = p.combustible
	end
	local estado
	if math.abs(error) <= M.tolerancia then
		estado = "nominal"
	elseif error > 0 then
		estado = "insuficiente"
	else
		estado = "excesiva"
	end
	-- "daño": en el juego representa el riesgo de no apuntar bien a Júpiter (no es daño físico real)
	local danio = 0
	if estado == "insuficiente" then
		danio = math.clamp(math.floor(error * 1.6 + 0.5), 0, 35)
	elseif estado == "excesiva" then
		danio = math.clamp(math.floor(-error * 0.8 + 0.5), 0, 25)
	end
	local energia = p.bateriasLitio and math.floor(12 * dv / M.requerido + 0.5) or 0
	-- duración con los 4 propulsores de 4,4 N (Newton: t = m·Δv/F)
	local empuje = 4 * 4.4
	return {
		dv = dv, efectivo = efectivo, error = error, consumo = consumo, alcanza = alcanza,
		estado = estado, danio = danio, energia = energia, momento = momento,
		duracion = Educativo.duracionQuema(p.m0, dv, empuje),
		-- compatibilidad: escala de la trayectoria para el gráfico (1 = sin error)
		escala = 0.86 + 0.14 * (error / M.requerido),
	}
end

---------------------------------------------------------------------------
-- GRÁFICO DE LA TRAYECTORIA DE NEW HORIZONS (pantalla de la sala de control)
-- Lo usan el servidor (dibuja), el cliente (mueve el marcador) y la consola (dibuja la
-- trayectoria corregida). Escala NO lineal: el radio crece con la raíz de la distancia al Sol.
--   n = 0 Tierra · 0,35 Júpiter · 1 Plutón. Devuelve x, y en fracciones del lienzo.
---------------------------------------------------------------------------
Educativo.GRAFICO = { solU = 0.30, solV = 0.56, aspecto = 14.8 / 9.2, escalaR = 0.2 }

function Educativo.radioGrafico(aUA)
	return Educativo.GRAFICO.escalaR * math.sqrt(aUA)
end

function Educativo.trayectoriaGrafico(n, desvio)
	local G = Educativo.GRAFICO
	local rT, rJ, rP = Educativo.radioGrafico(1), Educativo.radioGrafico(5.203), Educativo.radioGrafico(33)
	local r
	if n <= 0.35 then
		r = rT + (rJ - rT) * (n / 0.35)
	else
		r = rJ + (rP - rJ) * ((n - 0.35) / 0.65)
	end
	r += (desvio or 0)
	local angulo = 1.2 - 1.4 * n
	local u = G.solU + r * math.cos(angulo)
	local v = G.solV - r * math.sin(angulo)
	return u / G.aspecto, v
end

---------------------------------------------------------------------------
-- PLANIFICACIÓN DE RUTA (evento 1 de Perseverance en el cráter Jezero, Marte)
-- Escenario del juego: bajar un desnivel de 420 m (ESTIMADO, no es un dato de la NASA).
-- Datos reales: velocidad máxima 4,2 cm/s (152 m/h); el MMRTG da 110 W y las baterías guardan
-- la energía para los picos (hasta 900 W).
-- Bajar con un ángulo menor alarga el camino (d = 420 / sen θ). Se maneja unas horas por sol y el
-- MMRTG recarga las baterías el resto del día: energiaPct es la descarga en UNA sesión de manejo.
-- Un ángulo mayor que el que soporta la locomoción inmoviliza al vehículo. Es determinista.
---------------------------------------------------------------------------
Educativo.RUTA = {
	desnivel = 420, minAngulo = 8, maxAngulo = 28, paso = 2, horasPorSol = 4,
	velocidades = {
		{ clave = "lenta", nombre = "PRUDENTE", v = 0.021, factor = 1.0 },     -- mitad de la máxima (elección del juego)
		{ clave = "rapida", nombre = "MÁXIMA", v = 0.042, factor = 1.3 },      -- 152 m/h (NASA)
	},
}

-- p = { pendienteMax, potenciaTraccion (W), produccion (W), almacenamiento (Wh), consumoBase (W) }
function Educativo.prediccionRuta(p, angulo, velIndex)
	local R = Educativo.RUTA
	angulo = math.clamp(angulo, R.minAngulo, R.maxAngulo)
	local vel = R.velocidades[velIndex] or R.velocidades[1]
	local distancia = R.desnivel / math.sin(math.rad(angulo))
	local horas = distancia / vel.v / 3600
	local soles = math.max(1, math.ceil(horas / R.horasPorSol - 1e-9))
	local sesion = math.min(horas, R.horasPorSol)
	local potencia = p.potenciaTraccion * vel.factor * (1 + angulo / 60) + p.consumoBase
	local neto = math.max(0, potencia - p.produccion)
	local energiaWh = neto * sesion
	local energiaPct = p.almacenamiento > 0 and math.floor(energiaWh / p.almacenamiento * 100 + 0.5) or 100
	local riesgo = math.clamp((angulo / p.pendienteMax) ^ 3 * (vel.clave == "rapida" and 1.4 or 1), 0, 1)
	local estado, danio
	if angulo > p.pendienteMax then
		estado, danio = "atasco", 32
	elseif riesgo > 0.6 then
		estado, danio = "patinaje", 14
	else
		estado, danio = "ok", 0
	end
	return {
		angulo = angulo, vel = vel, distancia = distancia, horas = horas, soles = soles, potencia = potencia,
		energiaPct = energiaPct, riesgo = riesgo, estado = estado, danio = danio,
	}
end

---------------------------------------------------------------------------
-- "Dato NASA" que aparece al agarrar cada pieza
---------------------------------------------------------------------------
Educativo.TIPS = {
	["probe-power-A"] = "En Plutón (33 UA) el Sol da 1.000 veces menos luz que en la Tierra: 1.361 / 33² ≈ 1,25 W por m². Para tener 180 W harían falta unos 515 m² de paneles.",
	["probe-power-B"] = "El RTG de New Horizons convierte en electricidad el calor del plutonio-238: daba unos 240 W al despegar y unos 200 W al llegar a Plutón, nueve años después.",
	["probe-propulsion-A"] = "New Horizons lleva 77 kg de hidracina y 16 propulsores: cuatro de 4,4 N para corregir el rumbo y doce de 0,8 N para orientarse.",
	["probe-propulsion-B"] = "Un motor bipropelente quema combustible y oxidante: su impulso específico ronda los 310 s, pero necesita dos tanques y es más pesado.",
	["probe-comms-A"] = "La antena de ganancia media de New Horizons mide 0,3 m. La señal que junta crece con el área: (0,3 / 2,1)² ≈ 1/49 de la antena grande.",
	["probe-comms-B"] = "La antena grande de New Horizons mide 2,1 m. Desde Plutón la señal tarda 4 h 25 min y llega muy débil: unos pocos miles de bits por segundo.",
	["probe-science-A"] = "LORRI es la cámara telescópica de New Horizons: sacó las fotos en blanco y negro más detalladas de Plutón.",
	["probe-science-B"] = "New Horizons lleva 7 instrumentos que juntos pesan menos de 30 kg y gastan menos de 30 W, ¡menos que una lamparita!",
	["rover-mobility-A"] = "Perseverance usa la suspensión rocker-bogie de seis ruedas de aluminio. Aguanta inclinaciones de 45° sin volcar, pero se evitan las de más de 30°.",
	["rover-mobility-B"] = "El Rover Lunar de las misiones Apolo (1971-1972) usó ruedas de malla de alambre: livianas y flexibles, pensadas para la Luna y no para un rover de una tonelada.",
	["rover-power-A"] = "Spirit y Opportunity (2004) usaban paneles solares. Opportunity anduvo casi 15 años, hasta que una tormenta de polvo en 2018 tapó el Sol.",
	["rover-power-B"] = "El MMRTG de Perseverance pesa 45 kg, tiene 4,8 kg de dióxido de plutonio y da unos 110 W. Dos baterías de 43 Ah cubren los picos de hasta 900 W.",
	["rover-science-A"] = "Mastcam-Z es el par de cámaras con zoom del mástil de Perseverance; SuperCam dispara un láser a las rocas para saber de qué están hechas.",
	["rover-science-B"] = "Perseverance lleva 7 instrumentos (59 kg) y un taladro que guarda núcleos de roca en 43 tubos, para traerlos algún día a la Tierra.",
}

return Educativo
