#[compute]
#version 450

// Agrupa los hilos en voxels de 8*8*8
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(r8, binding = 0) restrict uniform readonly image3D estado_anterior;
layout(r8, binding = 1) restrict uniform writeonly image3D estado_nuevo;
layout(r8, binding = 2) restrict uniform readonly image3D mapa_combustibles;

// Aqui recibimos los bytes
layout(push_constant, std430) uniform Params {
	vec4 datos_tiempo;   // x: SEMILLA_ALEATORIA_CPU
	vec4 datos_ambiente; // x: velocidad_viento, y: direccion_rad, z: %humedad
} params;

// Generador Hash: Combina la semilla de la CPU con la coordenada 3D exacta
float hash(vec3 p, float semilla) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(sin(dot(p, vec3(12.9898, 78.233, 54.53)) + semilla) * 43758.5453);
}

void main() {
	ivec3 coord = ivec3(gl_GlobalInvocationID.xyz);
	ivec3 tamano_mapa = imageSize(estado_anterior);
	
	if (coord.x >= tamano_mapa.x || coord.y >= tamano_mapa.y || coord.z >= tamano_mapa.z) {
		return;
	}

	float estado_actual = imageLoad(estado_anterior, coord).r;
	
	if (estado_actual > 0.5) {
		imageStore(estado_nuevo, coord, vec4(1.0, 0.0, 0.0, 0.0));
		return;
	}
	
	float es_combustible = imageLoad(mapa_combustibles, coord).r;
	
	if (es_combustible < 0.1) {
		imageStore(estado_nuevo, coord, vec4(0.0, 0.0, 0.0, 0.0));
		return;
	}

	// --- EVALUACION DEL TIPO DE COMBUSTIBLE ---
	// Asignamos distintos pesos segun el valor de la textura.
	float propension_combustible = 1.0;
	
	// Si el valor tiende a blanco puro (ej: Arbol), es mas grueso y le cuesta mas prender.
	if (es_combustible > 0.7) { 
		propension_combustible = 0.4; 
	} 
	// Si el valor es intermedio (ej: Matorral), arde de forma extremadamente volatil.
	else if (es_combustible > 0.2) { 
		propension_combustible = 1.5; 
	}

	float vel_viento = params.datos_ambiente.x;
	float dir_viento = params.datos_ambiente.y;
	float humedad = params.datos_ambiente.z;

	vec2 vector_viento = vec2(sin(dir_viento), -cos(dir_viento));
	float factor_humedad = exp(-2.5 * humedad); 

	float riesgo_ignicion = 0.0;

	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				
				if (x == 0 && y == 0 && z == 0) continue;
				
				ivec3 coord_vecino = coord + ivec3(x, y, z);
				
				if (coord_vecino.x >= 0 && coord_vecino.x < tamano_mapa.x &&
					coord_vecino.y >= 0 && coord_vecino.y < tamano_mapa.y &&
					coord_vecino.z >= 0 && coord_vecino.z < tamano_mapa.z) {
					
					float estado_vecino = imageLoad(estado_anterior, coord_vecino).r;
					if (estado_vecino > 0.5) {

						// --- FISICAS DE VIENTO ESTRICTAS ---
						vec2 dir_bruto = vec2(float(-x), float(-z));
						float cos_theta = 0.0;

						if (length(dir_bruto) > 0.01) {
							vec2 dir_vecino = normalize(dir_bruto); 
							cos_theta = dot(dir_vecino, vector_viento);
						} 
						
						// Hacemos la curva exponencial mas agresiva a favor del viento
						float factor_viento = exp(vel_viento * 0.8 * cos_theta);
						
						// Si el viento sopla en contra (cos_theta negativo), aplastamos la probabilidad
						if (cos_theta < 0.0) {
							factor_viento *= 0.15; // El fuego a contraviento casi no avanza
						}


						// --- FISICAS DE PENDIENTE (TOPOGRAFIA) ---
						float factor_pendiente = 1.0;
						// Si y == -1, el fuego viene del vecino de ABAJO. El calor sube, asi que avanza muy rapido.
						if (y == -1) {
							factor_pendiente = 3.5; 
						} 
						// Si y == 1, el fuego viene del vecino de ARRIBA. Al fuego le cuesta mucho bajar laderas.
						else if (y == 1) {
							factor_pendiente = 0.2; 
						}

						// --- 4. CALCULO FINAL  ---
						float riesgo_base = 0.003; 
						
						float riesgo_vecino = riesgo_base * factor_viento * factor_pendiente * factor_humedad * propension_combustible;
						riesgo_ignicion += riesgo_vecino;
					}
				}
			}
		}
	}

	float nuevo_estado = 0.0;
	
	if (riesgo_ignicion > 0.0) {
		// Inyectamos la semilla de la CPU en el hash posicional
		float tirada = hash(vec3(coord), params.datos_tiempo.x);
		
		if (tirada < riesgo_ignicion) {
			nuevo_estado = 1.0;
		}
	}

	imageStore(estado_nuevo, coord, vec4(nuevo_estado, 0.0, 0.0, 0.0));
}
