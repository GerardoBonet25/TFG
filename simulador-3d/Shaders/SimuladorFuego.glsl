#[compute]
#version 450

// Agrupa los hilos en voxels de 8*8*8
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(r8, binding = 0) restrict uniform readonly image3D estado_anterior;
layout(r8, binding = 1) restrict uniform writeonly image3D estado_nuevo;

// Aquí recibimos los 16 bytes exactos que nos manda el script Controlador
layout(push_constant, std430) uniform Params {
	vec4 datos_tiempo;
} params;

// Generador pseudoaleatorio 
float rand(vec3 co){
	return fract(sin(dot(co, vec3(12.9898, 78.233, 54.53))) * 43758.5453);
}

void main() {
	ivec3 coord = ivec3(gl_GlobalInvocationID.xyz);
	ivec3 tamano_mapa = imageSize(estado_anterior);
	
	//Si tiene una coortdenada que se sale del mapa aborta la ejecución de ese voxel
	if (coord.x >= tamano_mapa.x || coord.y >= tamano_mapa.y || coord.z >= tamano_mapa.z) {
		return;
	}

	float estado_actual = imageLoad(estado_anterior, coord).r;
	
	// Si antes ya estaba ardiendo se deja
	if (estado_actual > 0.5) {
		imageStore(estado_nuevo, coord, vec4(1.0, 0.0, 0.0, 0.0));
		return;
	}

	float riesgo_ignicion = 0.0;
	// Si esta apagado
	// Vecindad de Moore 3D
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				//Si es el voxel central (en el que me encuentro) lo salto
				if (x == 0 && y == 0 && z == 0) continue;
				
				//Se calcula la coordenada del vecino
				ivec3 coord_vecino = coord + ivec3(x, y, z);
				
				//Si está dentro del mapa
				if (coord_vecino.x >= 0 && coord_vecino.x < tamano_mapa.x &&
					coord_vecino.y >= 0 && coord_vecino.y < tamano_mapa.y &&
					coord_vecino.z >= 0 && coord_vecino.z < tamano_mapa.z) {
					//Por cada vecino ardiendo se le suma la probabilidad de encenderse
					float estado_vecino = imageLoad(estado_anterior, coord_vecino).r;
					if (estado_vecino > 0.5) {
						riesgo_ignicion += 0.02;
					}
				}
			}
		}
	}

	float nuevo_estado = 0.0;
	
	if (riesgo_ignicion > 0.0) {
		// Sumamos el valor lógico .x a la semilla espacial.
		vec3 semilla = vec3(coord) + vec3(params.datos_tiempo.x);
		float tirada = rand(semilla);
		
		if (tirada < riesgo_ignicion) {
			nuevo_estado = 1.0;
		}
	}

	imageStore(estado_nuevo, coord, vec4(nuevo_estado, 0.0, 0.0, 0.0));
}
