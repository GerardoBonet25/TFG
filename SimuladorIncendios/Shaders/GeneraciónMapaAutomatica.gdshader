shader_type spatial;


// RELIEVE
uniform sampler2D mapa_elevacion : hint_default_black;
uniform float escala_altura = 20.0; // Altura máxima en metros de tus colinas de prueba

// COMBUSTIBLES
uniform sampler2D mapa_vegetacion : source_color;

// Variable para pasar datos del vértice al fragmento si lo necesitas para depurar
varying float altura_actual;
uniform float tamano_pixel = 0.005; 
void vertex() {
    // Leemos el valor del ruido matemático (va de 0.0 a 1.0)
    float relieve = textureLod(mapa_elevacion, UV, 0.0).r;

    // Calculamos la altura final
    altura_actual = relieve * escala_altura;

    // Desplazamos los vértices hacia arriba para formar las montañas
    VERTEX.y += altura_actual;
	// RECONSTRUCCIÓN DE NORMALES
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
    // Leemos el color asignado por tu gradiente en esa coordenada
    vec3 color_combustible = texture(mapa_vegetacion, UV).rgb;

    // Pintamos el terreno
    ALBEDO = color_combustible;

    // Un toque mate para que parezca tierra/vegetación bajo la luz
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}