# Taller: IA generativa para visualización de datos con R
# WiDS 2026
# Datos: Centro de Datos OCUC (CC BY-NC 4.0)
# Inspiración: Taller IA generativa de Riva Quiroga
# https://github.com/rivaquiroga/ia-generativa-analisis-de-datos
# Idea clave: no vamos a usar la IA en una página web, sino desde nuestro
# propio código. Así queda registrado qué le preguntamos y qué nos respondió,
# y eso hace el trabajo reproducible.

# 0. Paquetes -------------------------------------------------------------

library(ellmer)
library(tidyverse)
library(jsonlite)

# 1. Acá elegimos el modelo -----------------------------------------------

# Ver modelos disponibles
models_google_gemini()

modelo <- "gemini-3.5-flash-lite"

# 2. Acá le damos un rol a la IA (prompt de sistema) ----------------------

# El prompt de sistema define el rol y las reglas de toda la conversación
chat <- chat_google_gemini(
  model = modelo,
  system_prompt = "Eres experta en R, tidyverse y ggplot2.
  Responde con un solo bloque de código R comentado en español.
  Usa solo las columnas que te indico"
)

# Aquí creamos una conversación con la IA y la guardamos con el nombre chat

# 3. Acá conversamos con la IA --------------------------------------------

chat$chat("¿Qué geom de ggplot2 conviene para comparar una cantidad entre 30 categorías?")

# El objeto `chat` guarda el historial: la siguiente pregunta "recuerda" la anterior
chat$chat("¿Y cómo ordeno las barras de mayor a menor?")

# chat$chat(...) significa “en esta conversación, envía este mensaje”.

# 4. Acá cargamos los datos reales ----------------------------------------

# Función auxiliar para leer capas del Centro de Datos OCUC (sin geometría)
leer_ocuc <- function(servicio, campos = "*") {
  url <- paste0(
    "https://services9.arcgis.com/kKJR3Qt68ohAWuet/arcgis/rest/services/",
    servicio,
    "/FeatureServer/0/query?where=1%3D1&outFields=", campos,
    "&returnGeometry=false&f=json"
  )
  fromJSON(url)$features$attributes |> as_tibble()
}

ciclovias <- leer_ocuc(
  "Evaluaci%C3%B3n_de_la_Red_de_Ciclov%C3%ADas_del_Gran_Santiago_seg%C3%BAn_el_Decreto_102",
  "COMUNA,Recomendad,Shape_Leng"
) |>
  rename(comuna = COMUNA, decreto_102 = Recomendad, largo_m = Shape_Leng)

glimpse(ciclovias) # en el taller ciclovias desde leer ocuc es el "real"

# 5. Acá creamos datos sintéticos -----------------------------------------
# Estos datos son públicos, pero practicamos el hábito que usaríamos
# con datos privados: compartir solo la ESTRUCTURA, nunca los datos.

set.seed(2026)
ciclovias_sinteticas <- tibble(
  comuna      = sample(c("SANTIAGO", "MAIPÚ", "ÑUÑOA", "LA FLORIDA"), 20, replace = TRUE),
  decreto_102 = sample(c("Aprobado", "Reprobado"), 20, replace = TRUE),
  largo_m     = round(runif(20, min = 50, max = 5000))
)

# 6. Acá le pedimos el gráfico a la IA ------------------------------------

# Guardamos la estructura como texto para incluirla en el prompt
estructura <- capture.output(glimpse(ciclovias_sinteticas)) |>
  paste(collapse = "\n")

respuesta <- chat$chat(paste0(
  "Tengo un data frame llamado `ciclovias` con esta estructura:\n",
  estructura,
  "\n\nEscribe código ggplot2 para un gráfico de barras horizontales ",
  "con los kilómetros de ciclovía por comuna, coloreado según `decreto_102`, ",
  "ordenado de mayor a menor. Usa la paleta viridis y theme_minimal()."
))

# 7. Acá verificamos con el dato real -------------------------------------

# 1) Copia el código de la respuesta, pruébalo con `ciclovias_sinteticas`
# 2) Si funciona, ejecútalo con los datos reales (`ciclovias`)
# 3) Verifica: ¿la suma total da cerca de 418 km?
sum(ciclovias$largo_m) / 1000

# 8. Acá está la versión de referencia ------------------------------------
# Para comparar con lo que generó la IA

km_comuna <- ciclovias |>
  group_by(comuna, decreto_102) |>
  summarise(km = sum(largo_m) / 1000, .groups = "drop")

grafico <- ggplot(km_comuna,
                  aes(x = km, y = fct_reorder(comuna, km, .fun = sum), fill = decreto_102)) +
  geom_col() +
  scale_fill_viridis_d(end = 0.8) +
  labs(x = "Kilómetros de ciclovía", y = NULL, fill = "Decreto 102",
       title = "La mayoría de la red de ciclovías no cumple el Decreto 102",
       caption = "Fuente: Centro de Datos OCUC") +
  theme_minimal()

grafico

# 9. Acá la IA extrae información de textos -------------------------------

red <- leer_ocuc("Red_ciclovias_RM", "name,popupinfo,longitud") |>
  filter(!is.na(popupinfo), popupinfo != "")

red |> select(popupinfo) |> head()

# del objeto red, la columna estrella a usar popupinfo
# Es texto escrito por personas dice cosas como “Calzada / Ambos sentidos / Desde Av. X hasta calle Y”

# Definimos la estructura que queremos obtener
# Aquí no hablamos todavía con la IA: solo diseñamos el formulario y lo guardamos con el nombre tipo_ciclovia.
tipo_ciclovia <- type_object(
  ubicacion = type_string("Dónde va la ciclovía: vereda, calle, bandejón u otra combinación"),
  sentido   = type_string("Sentido de circulación, por ejemplo 'Ambos sentidos' o 'Un sentido'"),
  desde     = type_string("Calle donde comienza el tramo"),
  hasta     = type_string("Calle donde termina el tramo")
)

# Creamos una conversación nueva, separada de chat, con un rol distinto
# ya no es experta en programación en ggplot2, sino que extrae información.

extractor <- chat_google_gemini(
  model = modelo,
  system_prompt = "Extraes información de descripciones de ciclovías de Santiago."
)

# Primero con una sola descripción
# Se lee: “asistente extractora, lee esta descripción y llena este formulario”.
extractor$chat_structured(red$popupinfo[1], type = tipo_ciclovia)

# Luego con varias (usamos pocas para no superar el límite gratuito de Gemini)
extraido <- parallel_chat_structured(
  extractor,
  as.list(red$popupinfo[1:10]),
  type = tipo_ciclovia
)

# bind_cols pegar columnas pone lado a lado la descripción original y lo que extrajo la IA.

bind_cols(red[1:10, "popupinfo"], extraido) |> View()

# 10. Acá lo resolvemos sin IA --------------------------------------------

# ¿Necesitábamos IA para esto? Las descripciones siguen un patrón con "/"
sin_ia <- red |>
  separate_wider_delim(popupinfo, delim = " / ",
                       names = c("ubicacion", "sentido", "tramo"),
                       too_few = "align_start", too_many = "merge")

# 11. Acá la IA revisa el gráfico -----------------------------------------
# Ahora le pedimos al a IA que nos de feedback del grafico

ggsave("ciclovias_comuna.png", grafico, width = 8, height = 7, dpi = 150)

# Un chat nuevo con otro rol: así no "defiende" el código que escribió antes
# mantener separado los chat
critica <- chat_google_gemini(
  model = modelo,
  system_prompt = "Eres experta en visualización de datos y accesibilidad."
)

critica$chat(
  "Revisa este gráfico: legibilidad, orden, colores y título.
   Propón 3 mejoras concretas en código ggplot2 y un texto alternativo de 2 frases.",
  content_image_file("ciclovias_comuna.png")
)

# 12. Acá vemos cuántos tokens usamos y cuánto costó ----------------------

# Resumen de toda la sesión: todos los chats, por proveedor y modelo
token_usage()

# Detalle por turno de un chat (entrada y salida de cada pregunta)
chat$get_tokens()
extractor$get_tokens()

# Costo estimado en USD (precio de la capa pagada)
chat$get_cost()

# 13. Acá usamos un modelo local con Ollama -------------------------------
# Todo lo anterior envía los prompts a los servidores de Google.
# Con un modelo local, los datos NUNCA salen de tu computador:
# no hay costo por token y puedes usar datos privados (ej. entrevistas).
# Inspiración: https://www.mjandrews.org/notes/text_analysis_with_llms/part1.html

# 1) Instala Ollama desde https://ollama.com (Windows, macOS, Linux)
# 2) Depende de tu sistema operativo
# 3) Acá la capacidad de tu computador toma peso

# 13.1 Acá elegimos el modelo local ----

# Ver los modelos que tienes descargados
models_ollama()

modelo_local <- "llama3.2"

# 13.2 Acá conversamos con el modelo local ----

# Mismo prompt de sistema que antes, solo cambia la función
chat_local <- chat_ollama(
  model = modelo_local,
  system_prompt = "Eres experta en R, tidyverse y ggplot2.
  Responde con un solo bloque de código R comentado en español.
  Usa solo las columnas que te indico"
)

chat_local$chat("¿Qué geom de ggplot2 conviene para comparar una cantidad entre 30 categorías?")

# 13.3 Acá le mostramos datos reales (no salen del computador) ----

# Como el modelo es local, podemos mostrarle una muestra de los datos REALES
# La IA solo entiende texto, no tablas de R. Tenemos que convertir la tabla en texto,
# como hacer una captura de pantalla, pero en palabras.
muestra <- capture.output(print(head(ciclovias, 10))) |>
  paste(collapse = "\n")

# No le paso todos los datos, sino una muestra real

chat_local$chat(paste0(
  "Estas son las primeras filas del data frame `ciclovias`:\n", muestra,
  "\n\nEscribe código ggplot2 para un gráfico de barras horizontales ",
  "con los kilómetros de ciclovía por comuna, ordenado de mayor a menor."
))

# 13.4 Acá extraemos información de textos en local ----

# Extracción estructurada local: el mismo tipo_ciclovia de antes
extractor_local <- chat_ollama(
  model = modelo_local,
  system_prompt = "Extraes información de descripciones de ciclovías de Santiago."
)

extractor_local$chat_structured(red$popupinfo[1], type = tipo_ciclovia)

# Sin límite gratuito que cuidar: el límite ahora es tu computador.
# max_active bajo para no saturar la memoria
extraido_local <- parallel_chat_structured(
  extractor_local,
  as.list(red$popupinfo[1:10]),
  type = tipo_ciclovia,
  max_active = 2
)

# Comparemos: ¿el modelo local extrae lo mismo que Gemini?
bind_cols(red[1:10, "popupinfo"], extraido_local) |> View()

# 13.5 Acá vemos los tokens del modelo local ----

# Tokens y costo: se cuentan igual, pero el costo es solo la electricidad
chat_local$get_tokens()
