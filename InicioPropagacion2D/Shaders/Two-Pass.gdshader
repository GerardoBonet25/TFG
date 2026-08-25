shader_type spatial;

render_mode cull_back, unshaded, blend_mix;

uniform sampler2D textura_caras_traseras;
uniform int MAX_STEPS = 50;
uniform float Densidad = 0.3;
uniform float RadioEsfera=0;

varying vec3 posicion_local;

void vertex() {
    posicion_local = VERTEX;
}

void fragment() {
    vec3 pos_frontal = posicion_local;
    vec3 pos_trasera = (texture(textura_caras_traseras, SCREEN_UV).rgb - vec3(0.5));

    vec3 rayo_total = pos_trasera - pos_frontal;
    float distancia_total = length(rayo_total);
    vec3 direccion_rayo = normalize(rayo_total);

    float tamano_paso = distancia_total / float(MAX_STEPS);
    
	vec3 posicion_actual = pos_frontal;
    float densidad_acumulada = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        posicion_actual += direccion_rayo * tamano_paso;

		float distancia_al_centro = length(posicion_actual);

        float dentro_de_esfera = 1.0 - step(RadioEsfera, distancia_al_centro);
        densidad_acumulada += Densidad * tamano_paso * dentro_de_esfera;
		

        if (densidad_acumulada >= 1.0) {
            break;
        }
    }

    ALBEDO = vec3(1.0, 0.4, 0.4);
    ALPHA = clamp(densidad_acumulada, 0.0, 1.0);
	
}