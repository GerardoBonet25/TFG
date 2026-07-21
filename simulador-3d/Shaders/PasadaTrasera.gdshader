shader_type spatial;

// Ocultamos la cara delantera y quitamos las sombras
render_mode cull_front, unshaded;

varying vec3 posicion_local;

void vertex() {
    // Solo pasamos la posición
    posicion_local = VERTEX;
}

void fragment() {
    // Encriptamos la posición 3D convirtiéndola en un color RGB válido (de 0.0 a 1.0)
    ALBEDO = (posicion_local ) + vec3(0.5);
}