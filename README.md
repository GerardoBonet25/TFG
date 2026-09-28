<h1 align="center">🔥 Simulador Volumétrico 3D de Incendios Forestales</h1>
<h3 align="center">Trabajo de Fin de Grado - Ingeniería Informática (UGR)</h3>

<div align="center">
  <img src="https://img.shields.io/badge/Godot_4-%23FFFFFF.svg?style=for-the-badge&logo=godot-engine" alt="Godot 4">
  <img src="https://img.shields.io/badge/GLSL_Shaders-%23555555.svg?style=for-the-badge&logo=opengl" alt="Shaders">
  <img src="https://img.shields.io/badge/QGIS-%23589632.svg?style=for-the-badge&logo=qgis&logoColor=white" alt="QGIS">
</div>

---

## 📖 Acerca del Proyecto

Este repositorio contiene el código fuente de mi Trabajo de Fin de Grado (TFG) para la obtención del título en Ingeniería Informática (Especialidad de Ingeniería del Software) por la Universidad de Granada.

El proyecto consiste en un simulador de propagación de incendios forestales en **3D y en tiempo real**. El objetivo principal es aunar la precisión del modelado matemático de propagación del fuego con técnicas de renderizado gráfico avanzado para lograr una representación visual volumétrica de alta fidelidad, aprovechando al máximo la aceleración por hardware (GPU).

## ✨ Características Principales y Arquitectura Técnica

El simulador integra un motor de lógica matemática con un *pipeline* de renderizado personalizado:

*   **Motor Gráfico:** Desarrollado íntegramente utilizando **Godot Engine (Godot 4)**.
*   **Modelado de Propagación:** Implementación del comportamiento del fuego mediante **autómatas celulares** y simulaciones estocásticas permitiendo predecir el avance de las llamas en función del entorno.
*   **Renderizado Volumétrico en Tiempo Real:** Uso intensivo de programación gráfica (GPU) mediante **Compute Shaders** y **Raymarching Shaders** para calcular la densidad, iluminación y dispersión del fuego y el humo.
*   **Optimización de Memoria Gráfica:** Implementación y gestión de **Frame Buffer Objects (FBO)** para manejar el renderizado fuera de la pantalla (*off-screen rendering*) y mejorar el rendimiento del trazado de rayos.
*   **Generación de Terreno Geográfico (LiDAR):** Procesamiento de datos de elevación geográficos mediante **QGIS**. Se utilizaron mapas de altura (*heightmaps*) en formato GeoTIFF (modelos MDT02 y MDT05) obtenidos del Centro Nacional de Información Geográfica (CNIG) para generar la orografía tridimensional exacta del terreno en el simulador.

## ⚙️ Uso e Instalación

### Opción 1: Ejecución directa (Recomendada)
No es necesario instalar ningún motor gráfico para probar el simulador. El repositorio incluye una versión precompilada lista para usar.
1. Clona o descarga este repositorio:
   `git clone https://github.com/GerardoBonet25/TFG.git`
2. Navega hasta la carpeta `simulación incendios`.
3. Ejecuta el archivo binario de la aplicación incluido en el directorio.

### Opción 2: Explorar el código fuente
Si deseas inspeccionar el código, editar los *shaders* o ver el proyecto desde dentro del motor:
1. Descarga e instala [Godot Engine 4.x](https://godotengine.org/download).
2. Abre Godot, selecciona el botón de **Importar** y navega hasta el archivo `project.godot` incluido en la raíz de este repositorio.
3. Ejecuta el proyecto pulsando `F5` o el botón de *Play* en el editor.

## 👨‍💻 Autor

**Gerardo Bonet Pérez**
* [LinkedIn](www.linkedin.com/in/gerardobonet25)
* Email: [gerardobonet25@gmail.com](mailto:gerardobonet25@gmail.com
