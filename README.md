# Manual de Prácticas de SIG — Quarto book (QGIS 4.0 + R)

Libro Quarto con dos prácticas para el curso **Sistema de Información Geográfica**
(Escuela Profesional de Agronomía, UNSM-T).

Cada práctica documenta el flujo de trabajo en **QGIS 4.0** (método principal, con
marcadores 📸 para insertar tus capturas) y, en paralelo, el **equivalente en R**
en bloques desplegables, para reproducir las prácticas por código.

## Estructura

```
manuales-qgis/
├── _quarto.yml                        # configuración del libro (chapters, formatos)
├── index.qmd                          # presentación / cómo usar el manual
├── manual1-muestreo-distribucion.qmd  # Capítulo 1
├── manual2-indices-satelitales.qmd    # Capítulo 2
├── references.qmd                     # referencias consolidadas
├── references.bib                     # bibliografía
├── images/                            # ← pega aquí tus capturas de pantalla
└── data/                              # ← coloca aquí tus datos (gpkg, tif, csv)
```

## Cómo renderizar

Requiere [Quarto](https://quarto.org). Para el HTML basta con Quarto; para ejecutar
el código R necesitas R con los paquetes indicados en la presentación.

```bash
quarto render          # genera todo el libro (HTML y PDF)
quarto preview         # vista previa con recarga automática
```

Salidas en la carpeta `_output/`: un sitio HTML navegable (index.html) y un PDF
del libro (vía Typst, sin necesidad de LaTeX).

## Capturas de pantalla

Cada figura apunta a un archivo concreto en `images/`. Guarda tus capturas con esos
nombres exactos (p. ej. m1-01-proyecto.png, m2-04-ndvi.png) y aparecerán al
renderizar. La leyenda de cada figura indica **qué** debe mostrar la captura.

## Ejecutar el código R

Los chunks vienen con `eval: false` (definido en _quarto.yml) para que el libro
renderice sin datos. Para que el código corra con tus datos:

1. Coloca tus archivos en `data/` y ajusta las rutas dentro de los chunks.
2. Cambia `eval: false` a `eval: true` en _quarto.yml (global) o chunk por chunk
   con `#| eval: true`.

## Nota sobre versiones de QGIS

El libro documenta **QGIS 4.0 "Norrköping"** (Qt6, marzo 2026). Los pasos son válidos
también en **QGIS 3.44 LTR**: los cambios de interfaz para el usuario son mínimos.
Si algún alumno usa la LTR, ten presente que ciertos plugins Qt5 aún no son
compatibles con Qt6.
