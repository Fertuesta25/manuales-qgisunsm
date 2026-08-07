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


set.seed(2026)
library(spatstat.random)

# --- Muestreo sistemático (malla regular de 3000 m) ---
malla <- st_make_grid(area, cellsize = 3000, what = "centers") |>
  st_as_sf() |>
  st_filter(area)

tm_shape(area) + tm_borders() +
  tm_shape(malla) + tm_dots(size = 0.2) + tm_layout(frame = F)

# --- Muestreo aleatorio con distancia mínima (2500 m) ---
win <- as.owin(st_geometry(area))
ssi <- rSSI(r = 2500, n = 40, win = win)
aleatorio <- st_as_sf(data.frame(x = ssi$x, y = ssi$y),
                      coords = c("x", "y"), crs = st_crs(area))

tm_shape(area) + tm_borders() +
  tm_shape(aleatorio) + tm_dots(size = 0.2) + tm_layout(frame = F)

