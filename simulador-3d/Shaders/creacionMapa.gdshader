shader_type spatial;

uniform sampler2D mapa_vegetacion : source_color;
uniform sampler2D mapa_elevacion : hint_default_black, repeat_disable; 

uniform float escala_altura = 140.648;
uniform float altura_base = 0; // Altitud a la que cortamos la montaña

// Distancia entre píxeles (1.0 / resolución de tu imagen EXR). 
// Por defecto 0.005 asume una imagen de 200x200 aprox.
uniform float tamano_pixel = 0.005; 


void vertex() {
    float altura_leida = textureLod(mapa_elevacion, UV, 0.0).r;

    // Si la imagen EXR tiene píxeles corruptos (Infinito o Not-a-Number), forzamos la altura base.
    float altura_segura = (isinf(altura_leida) || isnan(altura_leida)) ? altura_base : altura_leida;

    VERTEX.y += (altura_segura - altura_base) * escala_altura;

    // D. RECONSTRUCCIÓN DE NORMALES
    // Leemos la altura de los 4 píxeles vecinos (arriba, abajo, izquierda, derecha)
    vec2 offset_x = vec2(tamano_pixel, 0.0);
    vec2 offset_y = vec2(0.0, tamano_pixel);
    
    float h_izq = textureLod(mapa_elevacion, UV - offset_x, 0.0).r * escala_altura;
    float h_der = textureLod(mapa_elevacion, UV + offset_x, 0.0).r * escala_altura;
    float h_aba = textureLod(mapa_elevacion, UV - offset_y, 0.0).r * escala_altura;
    float h_arr = textureLod(mapa_elevacion, UV + offset_y, 0.0).r * escala_altura;
    
    // Calculamos la inclinación en los ejes X y Z
    vec3 vector_tangente = normalize(vec3(tamano_pixel * 2.0, h_der - h_izq, 0.0));
    vec3 vector_binormal = normalize(vec3(0.0, h_arr - h_aba, tamano_pixel * 2.0));
    
    // El producto cruzado (cross) nos da el vector perpendicular exacto de la ladera
    NORMAL = normalize(cross(vector_binormal, vector_tangente));
}



void fragment() {
    // Leemos el color del mapa de vegetación (rojo, verde, etc.)
    vec3 color_combustible = texture(mapa_vegetacion, UV).rgb;

    ALBEDO = color_combustible;

    // Terreno mate y rugoso: evita que las montañas parezcan de plástico bajo el sol
    ROUGHNESS = 0.95;
    SPECULAR = 0.05;
}