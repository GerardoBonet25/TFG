shader_type spatial;

render_mode cull_back, unshaded, blend_mix;

uniform sampler2D textura_caras_traseras;
uniform int MAX_STEPS = 50;

varying vec3 posicion_local;

void vertex() {
    posicion_local = VERTEX;
}

void fragment() {
    vec3 pos_frontal = posicion_local;
    vec3 pos_trasera = texture(textura_caras_traseras, SCREEN_UV).rgb - vec3(0.5);
    
    vec3 rayo_total = pos_trasera - pos_frontal;
    float distancia_total = length(rayo_total);
    vec3 direccion_rayo = normalize(rayo_total);
    
    float tamano_paso = distancia_total / float(MAX_STEPS);
    vec3 posicion_actual = pos_frontal;
    float densidad_acumulada = 0.0;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        posicion_actual += direccion_rayo * tamano_paso;
        
        float densidad_en_este_punto = 0.3; 
        densidad_acumulada += densidad_en_este_punto * tamano_paso;
        
        if (densidad_acumulada >= 1.0) {
            break;
        }
    }
    
    ALBEDO = vec3(1.0, 0.4, 0.4); 
    ALPHA = clamp(densidad_acumulada, 0.0, 1.0); 
}