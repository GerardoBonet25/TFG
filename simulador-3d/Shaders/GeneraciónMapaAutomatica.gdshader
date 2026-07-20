shader_type spatial;

// ==========================================
// PARÁMETROS DEL SANDBOX (PRUEBAS PROCEDURALES)
// ==========================================

// RELIEVE 
uniform sampler2D mapa_elevacion : hint_default_black;
uniform float escala_altura = 20.0; // Altura máxima en metros de tus colinas de prueba

// COMBUSTIBLES
uniform sampler2D mapa_vegetacion : source_color;

// Variable para pasar datos del vértice al fragmento si lo necesitas para depurar
varying float altura_actual;

void vertex() {
    // Leemos el valor del ruido matemático (va de 0.0 a 1.0)
    float relieve = textureLod(mapa_elevacion, UV, 0.0).r;
    
    // Calculamos la altura final
    altura_actual = relieve * escala_altura;
    
    // Desplazamos los vértices hacia arriba para formar las montañas
    VERTEX.y += altura_actual;
}

void fragment() {
    // Leemos el color asignado por tu gradiente en esa coordenada
    vec3 color_combustible = texture(mapa_vegetacion, UV).rgb;
    
    // Pintamos el terreno
    ALBEDO = color_combustible;
    
    // Un toque mate para que parezca tierra/vegetación bajo la luz
    ROUGHNESS = 0.9;
    SPECULAR = 0.1;
}