shader_type spatial;

// AÑADIDO: blend_mix para que el ALPHA funcione perfectamente
render_mode cull_back, unshaded, blend_mix;

uniform sampler2D textura_caras_traseras;
uniform sampler3D textura_volumen; 
uniform int MAX_STEPS = 64; 

varying vec3 posicion_local;

void vertex() {
    posicion_local = VERTEX;
}

void fragment() {
    vec3 pos_frontal = posicion_local;
    
    // Leemos el fondo desde el SubViewport
    vec3 pos_trasera = texture(textura_caras_traseras, SCREEN_UV).rgb - vec3(0.5);
    
    vec3 rayo_total = pos_trasera - pos_frontal;
    float distancia_total = length(rayo_total);
    vec3 direccion_rayo = normalize(rayo_total);
    
    float tamano_paso = distancia_total / float(MAX_STEPS);
    vec3 posicion_actual = pos_frontal;
    float densidad_acumulada = 0.0;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        // Avanzamos el rayo
        posicion_actual += direccion_rayo * tamano_paso;
        
        // Convertimos la posición local (-0.5 a 0.5) a coordenadas de textura (0.0 a 1.0)
        vec3 coordenadas_uvw = posicion_actual + vec3(0.5);
        
        // Leemos el dato binario del Compute Shader (0.0 o 1.0)
        float densidad_en_este_punto = texture(textura_volumen, coordenadas_uvw).r;
        
        // MEJORA: Multiplicamos por 15.0 para que el humo sea muy espeso rápidamente
        densidad_acumulada += (densidad_en_este_punto * 15.0) * tamano_paso;
		
		
        
        if (densidad_acumulada >= 1.0) {
            break;
        }
    }
    
    
    // Bordes (baja densidad) = Naranja/Rojo. Núcleo (alta densidad) = Amarillo puro.
    vec3 color_fuego = mix(vec3(1.0, 0.2, 0.0), vec3(1.0, 0.9, 0.0), densidad_acumulada);
    
    ALBEDO = color_fuego; 
    ALPHA = clamp(densidad_acumulada, 0.0, 1.0); 
}