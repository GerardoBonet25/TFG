shader_type canvas_item;

uniform sampler2D mapa_anterior;

// --- PARÁMETROS DEL VIENTO
uniform float velocidad_viento = 15.0; // km/h
uniform float direccion_viento = 0.0;  // 0.0 es Norte, 90.0 es Este
uniform float c1 = 2.0;                // Escala máxima del viento
uniform float c2 = 0.1;                // Sensibilidad al viento
uniform float probabilidad_base = 0.02;


// Los Shaders no tienen función random() nativa, usamos esta fórmula clásica
float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    vec4 estado_actual = texture(mapa_anterior, UV);

    // Si ya es fuego, sigue siendo fuego
    if (estado_actual.r > 0.5) {
        COLOR = vec4(1.0, 0.0, 0.0, 1.0);
    }
    else {
        vec2 tamano_pixel = vec2(1.0 / 64.0, 1.0 / 64.0);
        bool me_enciendo = false;

        // Convertimos la dirección del viento de grados a radianes
        float dir_viento_rad = radians(direccion_viento);
        // Creamos un vector unitario de hacia dónde sopla el viento
        vec2 vector_viento = vec2(sin(dir_viento_rad), -cos(dir_viento_rad));

        // Revisamos los 8 vecinos
        for(int x = -1; x <= 1; x++) {
			if (me_enciendo) break;
            for(int y = -1; y <= 1; y++) {
                if(x == 0 && y == 0) continue;

                vec2 offset = vec2(float(x), float(y)) * tamano_pixel;
                vec4 color_vecino = texture(mapa_anterior, UV + offset);

                if(color_vecino.r > 0.5) {

                    vec2 direccion_vecino = normalize(vec2(float(-x), float(-y)));

                    float cos_theta = dot(direccion_vecino, vector_viento);

                    float factor_viento = c1 * exp(c2 * velocidad_viento * (cos_theta - 1.0));

                    float prob_total = probabilidad_base * factor_viento;
                    // Usamos UV y TIME como semilla para que sea diferente cada vez
                    float dado = rand(UV + vec2(TIME));

                    if (dado < prob_total) {
                        me_enciendo = true;
						break;
                    }
                }
            }
        }

        if (me_enciendo) {
            COLOR = vec4(1.0, 0.0, 0.0, 1.0);
        } else {
            COLOR = vec4(0.0, 0.0, 0.0, 1.0);
        }
    }
}