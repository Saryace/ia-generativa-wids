
# Taller: IA generativa para visualización de datos con R
# WiDS 2026
# Datos: Centro de Datos OCUC (CC BY-NC 4.0)
# Inspiración: Taller IA generativa de Riva Quiroga
# https://github.com/rivaquiroga/ia-generativa-analisis-de-datos

library(ellmer)
library(tidyverse)
library(jsonlite)

# Prompt Sistema ----------------------------------------------------------

# Ver modelos disponibles
models_google_gemini()

modelo <- "gemini-3.5-flash-lite"

# El prompt de sistema define el rol y las reglas de toda la conversación
chat <- chat_google_gemini(
  model = modelo,
  system_prompt = "Eres experta en R, tidyverse y ggplot2.
  Responde con un solo bloque de código R comentado en español.
  Usa solo las columnas que te indico"
)

chat$chat("¿Qué geom de ggplot2 conviene para comparar una cantidad entre 30 categorías?")

# El objeto `chat` guarda el historial: la siguiente pregunta "recuerda" la anterior
chat$chat("¿Y cómo ordeno las barras de mayor a menor?")

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

glimpse(ciclovias)

# Datos sintéticos --------------------------------------------------------
# Estos datos son públicos, pero practicamos el hábito que usaríamos
# con datos privados: compartir solo la ESTRUCTURA, nunca los datos.

set.seed(2026)
ciclovias_sinteticas <- tibble(
  comuna      = sample(c("SANTIAGO", "MAIPÚ", "ÑUÑOA", "LA FLORIDA"), 20, replace = TRUE),
  decreto_102 = sample(c("Aprobado", "Reprobado"), 20, replace = TRUE),
  largo_m     = round(runif(20, min = 50, max = 5000))
)

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

# 1) Copia el código de la respuesta, pruébalo con `ciclovias_sinteticas`
# 2) Si funciona, ejecútalo con los datos reales (`ciclovias`)
# 3) Verifica: ¿la suma total da cerca de 418 km?
sum(ciclovias$largo_m) / 1000

# Versión de referencia (para comparar con lo que generó la IA)
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

# Usar elmer
red <- leer_ocuc("Red_ciclovias_RM", "name,popupinfo,longitud") |>
  filter(!is.na(popupinfo), popupinfo != "")

red |> select(popupinfo) |> head()

# Definimos la estructura que queremos obtener
tipo_ciclovia <- type_object(
  ubicacion = type_string("Dónde va la ciclovía: vereda, calle, bandejón u otra combinación"),
  sentido   = type_string("Sentido de circulación, por ejemplo 'Ambos sentidos' o 'Un sentido'"),
  desde     = type_string("Calle donde comienza el tramo"),
  hasta     = type_string("Calle donde termina el tramo")
)

extractor <- chat_google_gemini(
  model = modelo,
  system_prompt = "Extraes información de descripciones de ciclovías de Santiago."
)

# Primero con una sola descripción
extractor$chat_structured(red$popupinfo[1], type = tipo_ciclovia)

# Luego con varias (usamos pocas para no superar el límite gratuito de Gemini)
extraido <- parallel_chat_structured(
  extractor,
  as.list(red$popupinfo[1:10]),
  type = tipo_ciclovia
)

bind_cols(red[1:10, "popupinfo"], extraido)

# ¿Necesitábamos IA para esto? Las descripciones siguen un patrón con "/"
sin_ia <- red |>
  separate_wider_delim(popupinfo, delim = " / ",
                       names = c("ubicacion", "sentido", "tramo"),
                       too_few = "align_start", too_many = "merge")

sin_ia |> count(ubicacion, sort = TRUE)

# Que la IA revise el grâfico

ggsave("ciclovias_comuna.png", grafico, width = 8, height = 7, dpi = 150)

# Un chat nuevo con otro rol: así no "defiende" el código que escribió antes
critica <- chat_google_gemini(
  model = modelo,
  system_prompt = "Eres experta en visualización de datos y accesibilidad."
)

# Tokens usados ----------------------------------------------------------

# Resumen de toda la sesión: todos los chats, por proveedor y modelo
token_usage()

# Detalle por turno de un chat (entrada y salida de cada pregunta)
chat$get_tokens()
extractor$get_tokens()

# Costo estimado en USD (precio de la capa pagada)
chat$get_cost()
