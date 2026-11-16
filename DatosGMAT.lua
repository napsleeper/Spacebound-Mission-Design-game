--[[
	DATOS GMAT · ModuleScript compartido · v5
	DÓNDE VA: ReplicatedStorage > ControlDeMisionCompartido > DatosGMAT

	Puente entre NASA GMAT y Roblox. GMAT no corre dentro de Roblox: se ejecuta en una PC,
	se exporta la trayectoria a texto, se convierte a JSON con gmat_a_json.py y el JSON se
	pega en JSON_GMAT (abajo). Ver gmat/LEEME_GMAT.md.

	DOS FUENTES QUE NUNCA SE MEZCLAN
	  · "GMAT (precalculado)": lo que viene en este JSON. Se muestra con esa etiqueta.
	  · "Cálculo Luau": lo que calcula Educativo en el momento (Tsiolkovsky, vis-viva,
	    Hohmann). También se muestra con su etiqueta.

	UNIDADES Y MARCO
	  El JSON trae distancias en km, velocidades y Δv en km/s, tiempos en s, en el marco
	  EarthMJ2000Eq (inercial, centrado en la Tierra). Al cargar se convierte a las
	  unidades del juego: km, m/s y s. Si el JSON declara otras unidades o marco, se rechaza.

	EL JSON ACTUAL ES UN EJEMPLO SINTÉTICO generado con las ecuaciones de Kepler, NO por GMAT.
]]

local HttpService = game:GetService("HttpService")

local DatosGMAT = {}

DatosGMAT.JSON_GMAT = [==[{"formato":"ControlDeMision-GMAT/1","fuente":"EJEMPLO SINTÉTICO generado con las ecuaciones de Kepler (NO es una salida de GMAT). Reemplazar con la exportación real.","unidades":{"distancia":"km","velocidad":"km/s","tiempo":"s","dv":"km/s"},"marco":"EarthMJ2000Eq","cuerpoCentral":"Earth","mu":398600.4418,"escenarios":[{"id":"sonda_tcm","nombre":"Órbita de la sonda y corrección TCM","elementos":{"SMA":6790.0,"ECC":0.014,"INC":28.5,"RAAN":0,"AOP":0},"periodo_s":5568.2,"maniobras":[{"nombre":"TCM","t_s":1800,"ejes":"VNB","dv":[-0.045,0,0]}],"puntos":[[0.0,6694.94,0.0,0.0,-0.0,6.82831,3.70747],[154.7,6588.86,1050.57,570.41,-1.36791,6.72014,3.64874],[309.3,6274.11,2067.87,1122.76,-2.69075,6.39947,3.47463],[464.0,5761.05,3019.83,1639.63,-3.92524,5.87767,3.19131],[618.7,5066.47,3876.66,2104.86,-5.03168,5.17303,2.80873],[773.4,4212.93,4611.9,2504.06,-5.97535,4.30992,2.3401],[928.0,3227.9,5203.25,2825.13,-6.72773,3.31765,1.80134],[1082.7,2142.72,5633.24,3058.6,-7.26733,2.22918,1.21035],[1237.4,991.49,5889.69,3197.84,-7.5801,1.0798,0.58629],[1392.1,-190.11,5966.0,3239.27,-7.6596,-0.09423,-0.05116],[1546.7,-1365.98,5861.13,3182.34,-7.50677,-1.2569,-0.68244],[1701.4,-2500.71,5579.56,3029.45,-7.1295,-2.37358,-1.28875],[1856.1,-3560.61,5130.92,2785.86,-6.54202,-3.41193,-1.85253],[2010.7,-4514.62,4529.65,2459.4,-5.76412,-4.3427,-2.35789],[2165.4,-5335.15,3794.4,2060.19,-4.82041,-5.14034,-2.79098],[2320.1,-5998.71,2947.48,1600.35,-3.73943,-5.78344,-3.14015],[2474.8,-6486.48,2014.17,1093.61,-2.55281,-6.25506,-3.39622],[2629.4,-6784.71,1021.99,554.9,-1.29451,-6.54296,-3.55254],[2784.1,-6885.06,0.0,0.0,-0.0,-6.63975,-3.60509],[2938.8,-6784.71,-1021.99,-554.9,1.29451,-6.54296,-3.55254],[3093.5,-6486.48,-2014.17,-1093.61,2.55281,-6.25506,-3.39622],[3248.1,-5998.71,-2947.48,-1600.35,3.73943,-5.78344,-3.14015],[3402.8,-5335.15,-3794.4,-2060.19,4.82041,-5.14034,-2.79098],[3557.5,-4514.62,-4529.65,-2459.4,5.76412,-4.3427,-2.35789],[3712.1,-3560.61,-5130.92,-2785.86,6.54202,-3.41193,-1.85253],[3866.8,-2500.71,-5579.56,-3029.45,7.1295,-2.37358,-1.28875],[4021.5,-1365.98,-5861.13,-3182.34,7.50677,-1.2569,-0.68244],[4176.2,-190.11,-5966.0,-3239.27,7.6596,-0.09423,-0.05116],[4330.8,991.49,-5889.69,-3197.84,7.5801,1.0798,0.58629],[4485.5,2142.72,-5633.24,-3058.6,7.26733,2.22918,1.21035],[4640.2,3227.9,-5203.25,-2825.13,6.72773,3.31765,1.80134],[4794.8,4212.93,-4611.9,-2504.06,5.97535,4.30992,2.3401],[4949.5,5066.47,-3876.66,-2104.86,5.03168,5.17303,2.80873],[5104.2,5761.05,-3019.83,-1639.63,3.92524,5.87767,3.19131],[5258.9,6274.11,-2067.87,-1122.76,2.69075,6.39947,3.47463],[5413.5,6588.86,-1050.57,-570.41,1.36791,6.72014,3.64874],[5568.2,6694.94,-0.0,-0.0,0.0,6.82831,3.70747]]},{"id":"tierra_luna","nombre":"Tierra → órbita lunar (valores de referencia)","tramos":[{"nombre":"Inyección translunar (TLI) desde 185 km","dv":3.15},{"nombre":"Inserción en órbita lunar (LOI) a 100 km","dv":0.85},{"nombre":"Descenso a la superficie","dv":1.9}],"duracion_s":259200}]}]==]

local cache = nil

function DatosGMAT.cargar()
	if cache then
		return cache
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(DatosGMAT.JSON_GMAT)
	end)
	if not ok or type(data) ~= "table" then
		warn("[DatosGMAT] No se pudo leer el JSON: " .. tostring(data))
		cache = { ok = false, escenarios = {} }
		return cache
	end
	local u = data.unidades or {}
	if u.distancia ~= "km" or u.velocidad ~= "km/s" or data.marco ~= "EarthMJ2000Eq" then
		warn("[DatosGMAT] Unidades o marco no soportados: se esperan km, km/s y EarthMJ2000Eq.")
		cache = { ok = false, escenarios = {} }
		return cache
	end
	local out = { ok = true, fuente = data.fuente, marco = data.marco, mu = data.mu, escenarios = {} }
	for _, esc in ipairs(data.escenarios or {}) do
		local e = { id = esc.id, nombre = esc.nombre, periodo = esc.periodo_s, duracion = esc.duracion_s, elementos = esc.elementos }
		if esc.puntos then
			e.puntos = {}
			for _, p in ipairs(esc.puntos) do
				-- t (s), posición (km) y velocidad (de km/s a m/s)
				table.insert(e.puntos, { t = p[1], x = p[2], y = p[3], z = p[4], vx = p[5] * 1000, vy = p[6] * 1000, vz = p[7] * 1000 })
			end
		end
		if esc.maniobras then
			e.maniobras = {}
			for _, m in ipairs(esc.maniobras) do
				local dv = m.dv or { 0, 0, 0 }
				table.insert(e.maniobras, {
					nombre = m.nombre, t = m.t_s, ejes = m.ejes,
					dv = math.sqrt(dv[1] ^ 2 + dv[2] ^ 2 + dv[3] ^ 2) * 1000,
				})
			end
		end
		if esc.tramos then
			e.tramos = {}
			for _, t in ipairs(esc.tramos) do
				table.insert(e.tramos, { nombre = t.nombre, dv = t.dv * 1000 })
			end
		end
		out.escenarios[esc.id] = e
	end
	cache = out
	return out
end

function DatosGMAT.escenario(id)
	return DatosGMAT.cargar().escenarios[id]
end

return DatosGMAT
