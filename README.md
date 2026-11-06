# IA generativa para visualización de datos con R

Taller realizado en el marco de **WiDS 2026 (Women in Data Science)**.

Presentación acá: [saryace.github.io/seminario_sacevedo/ia-generativa-wids](https://saryace.github.io/seminario_sacevedo/ia-generativa-wids/)

## Descripción

Este taller muestra cómo usar modelos de lenguaje desde R con el paquete [{ellmer}](https://ellmer.tidyverse.org/) para apoyar la visualización de datos. Trabajaremos con datos abiertos de ciclovías de Santiago y practicaremos tres hábitos: compartir con la IA solo la **estructura** de los datos, pedir código **verificable** y **revisar** todo lo que la IA genera antes de usarlo.

## Preparación

### R y RStudio

Para realizar las actividades es necesario tener instalada una versión reciente de [R](https://cran.r-project.org/) y de [RStudio](https://posit.co/download/rstudio-desktop/). 

Instalaremos los siguientes paquetes:

```r
install.packages("ellmer")
install.packages("usethis")
install.packages("tidyverse")
install.packages("jsonlite")
```

### Gemini

Usaremos la capa gratuita de Google Gemini. Sigue las instrucciones de configuración de la API key en [la guía del taller de Riva Quiroga](https://github.com/rivaquiroga/ia-generativa-analisis-de-datos/blob/main/gemini-api-key.md). En resumen:

1. Crea una API key en [Google AI Studio](https://aistudio.google.com/api-keys).
2. Ejecuta `usethis::edit_r_environ()` y agrega la línea `GEMINI_API_KEY=TU_API_KEY`.
3. Guarda el archivo y reinicia R.

> **⚠️ Importante:** la API key funciona como una contraseña. Nunca la escribas dentro de un script ni la subas a GitHub.

Para comprobar que todo funciona:

```r
library(ellmer)
chat <- chat_google_gemini()
chat$chat("Responde solo: estamos ready!!")
```

## Extra: por tu cuenta, modelos locales

## Modelos locales con Ollama (opcional)
 
En la última parte del taller usamos un modelo de IA **instalado en tu propio computador** con [Ollama](https://ollama.com). Así los datos **nunca salen de tu máquina** y no hay costo por token.
 
> ⚠️ Esta parte es **opcional**. Cómo instalarlo y qué modelo usar **depende de tu sistema operativo y de la memoria RAM de tu computador**. Si tu equipo es más modesto, puedes seguir el taller igual: el resto funciona con Gemini en la nube.
 
### 1. Instalar Ollama
 
Descarga el instalador para tu sistema desde **https://ollama.com/download**.
 
| Sistema | Cómo instalar |
|---|---|
| **macOS** | Descarga la app, muévela a *Aplicaciones* y ábrela. Queda un ícono en la barra de menú. |
| **Windows** | Descarga y ejecuta el instalador `.exe`. |
| **Linux** | Sigue el comando de instalación indicado en la página de descarga. |
 
Las instrucciones pueden cambiar con nuevas versiones: revisa siempre la página oficial.
 
### 2. Verificar la instalación
 
Abre una **terminal** (en Windows, *PowerShell*; en Mac/Linux, *Terminal*) y escribe:
 
```bash
ollama --version
```
 
Si aparece un número de versión, quedó instalado. Si dice `command not found`, cierra y vuelve a abrir la terminal, o asegúrate de que la app de Ollama esté abierta.
 
### 3. Elegir y descargar un modelo según tu RAM
 
El modelo debe **caber en la memoria** de tu computador. Si es demasiado grande, funcionará extremadamente lento. Para ver tu RAM:
 
- **macOS:**  → *Acerca de esta Mac*
- **Windows:** *Configuración → Sistema → Información*
- **Linux:** `free -h` en la terminal
| RAM de tu computador | Tamaño de modelo recomendado | Ejemplo |
|---|---|---|
| 8 GB | Pequeño (1–4 mil millones de parámetros, ~2–3 GB) | `ollama pull llama3.2` |
| 16 GB | Mediano (7–12 mil millones de parámetros, ~5–8 GB) | `ollama pull gemma4` |
| 32 GB o más | Grande (14–30 mil millones de parámetros) | Explora el [catálogo de Ollama](https://ollama.com/library) |
 
Los nombres de modelos cambian seguido: revisa el [catálogo de Ollama](https://ollama.com/library) para ver las opciones actuales. **Para el taller, un modelo pequeño es suficiente.**

## Datos

Usaremos datos del [Centro de Datos OCUC](https://centrodedatos-ocuc.hub.arcgis.com/) (Observatorio de Ciudades UC)

- [Evaluación de la Red de Ciclovías del Gran Santiago según el Decreto 102](https://centrodedatos-ocuc.hub.arcgis.com/datasets/844180d7d2ab4986a4f2d315707127f2): 392 tramos con su comuna, largo y si aprueban o reprueban las recomendaciones del Decreto 102.
- Red Regional de Ciclovías en el Área Metropolitana de Santiago: 169 ciclovías con una descripción en texto, por ejemplo *"Vereda / Ambos sentidos / Los Milagros a Los Pozos"*.

Los datos se leen directamente desde internet en el script `taller.R`; no es necesario descargarlos.

## Partes del taller

Todo el código está en [`taller.R`](taller.R).

### Parte 1: Datos sintéticos para generación de código

Creamos una base falsa con la misma estructura que los datos de ciclovías, le pedimos a Gemini el código del gráfico y luego lo ejecutamos con los datos reales.

### Parte 2: Uso de {ellmer} para extraer datos

Le pedimos a Gemini que convierta descripciones en texto de las ciclovías en columnas (ubicación, sentido, desde, hasta). Después comparamos el resultado con una solución sin IA: ¿siempre necesitamos un modelo de lenguaje?

### Parte 3: La IA revisa nuestro gráfico

Enviamos la imagen de nuestro gráfico a Gemini y le pedimos mejoras de legibilidad y un texto alternativo. Decidimos qué sugerencias aceptar.

### Parte 4: Modelo local

Usando ollama, replicaremos las partes 1, 2 y 3 del taller

## Créditos

La estructura base de este taller está inspirada en [IA generativa para análisis de datos](https://github.com/rivaquiroga/ia-generativa-analisis-de-datos) de Riva Quiroga.
