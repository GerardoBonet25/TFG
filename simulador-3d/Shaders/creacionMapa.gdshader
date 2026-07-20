shader_type spatial;

// ==========================================
// PARÁMETROS DEL INSPECTOR
// ==========================================

// 1. EL MAPA FÍSICO (Topografía - Archivo .EXR)
uniform sampler2D mapa_vegetacion: source_color;
uniform sampler2D mapa_elevacion;
uniform float escala_altura = 1.0;
uniform float altura_base = 1300.0; // Altitud a la que cortamos la montaña




// ==========================================
// PROCESAMIENTO GEOMÉTRICO (LEVANTAR LA MALLA)
// ==========================================
void vertex() {
    // Leemos la altitud exacta del píxel (usamos Lod 0.0 para evitar interpolaciones rotas)
    float altura_leida = textureLod(mapa_elevacion, UV, 0.0).r;

    float altura_segura = altura_leida;
    //if (isnan(altura_leida) || isinf(altura_leida) || altura_leida < -100.0 || altura_leida > 5000.0) {
       // altura_segura = altura_base;
    //}

    // DESPLAZAMIENTO 3D:
    // Restamos la altura base para que el valle empiece en la coordenada Y=0 de Godot.
    VERTEX.y += (altura_segura - altura_base) * escala_altura;
}


// ==========================================
// PROCESAMIENTO VISUAL (PINTAR LOS COLORES)
// ==========================================
void fragment() {
    // Leemos el color exacto de tu mapa de GIMP en estas coordenadas UV
    vec3 color_combustible = texture(mapa_vegetacion, UV).rgb;

    // Aplicamos el color (rojo, azul, verde, rosa...) a la superficie de la montaña 3D
    ALBEDO = color_combustible;

    // Opcional: Reducimos un poco el brillo para que los colores no sean tan fosforitos
    // y la luz del sol en Godot genere mejores sombras sobre el relieve.
    ROUGHNESS = 0.9;
    SPECULAR = 0.1;
}