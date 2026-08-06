install.packages(c("sf","terra","spatstat","gstat","tmap","dplyr","units",
                   "exactextractr","tidyterra"))

library(sf)        # vectores
library(terra)     # rasters
library(spatstat)  # análisis de patrones de puntos
library(gstat)     # interpolación (IDW / kriging)
library(tmap)      # mapas temáticos
library(dplyr)
library(units)

# Área de estudio (ajusta la ruta a tu archivo)
area <- st_read("muestreo_distribucion/Shapefile/Microcuenca_cumbaza.shp")

# Reproyectar a UTM 18S para trabajar en metros
area <- st_transform(area, 32718)
tm_shape(area) + tm_borders(lwd = 2) + tm_layout(frame = F)


set.seed(2026)   # reproducibilidad

# --- Muestreo sistemático (malla regular ~25 m) ---
n_puntos <- as.numeric(st_area(area) / set_units(3000^2, m^2))
malla <- st_sample(area, size = round(n_puntos), type = "regular") |> st_sf()

# --- Muestreo aleatorio (40 puntos) ---
aleatorio <- st_sample(area, size = 40, type = "random") |> st_sf()

tm_shape(area) + tm_borders() +
  tm_shape(aleatorio) + tm_dots(size = 0.2) + tm_borders(lwd = 2) + tm_layout(frame = F)

tm_shape(area) + tm_borders() +
  tm_shape(malla) + tm_dots(size = 0.2) + tm_borders(lwd = 2) + tm_layout(frame = F)

