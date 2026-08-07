install.packages(c("sf","terra","spatstat","gstat","dplyr", "mapsf"))

library(sf)         # datos vectoriales: leer shapefiles, reproyectar, muestreo
library(terra)      # datos ráster: crear, recortar, rasterizar superficies
library(spatstat)   # análisis de patrones de puntos: densidad, Smooth, vecino más cercano
library(gstat)      # interpolación espacial (IDW / kriging)
library(dplyr)      # manipulación de tablas: unir datos, clasificar, crear campos
library(mapsf)      # diseño de mapas temáticos (contorno, escala, norte, leyenda)


# Área de estudio (ajusta la ruta a tu archivo)
area <- st_read("muestreo_distribucion/Shapefile/Microcuenca_cumbaza.shp")

# Reproyectar a UTM 18S para trabajar en metros
area <- st_transform(area, 32718)

# Mapa del contorno con mapsf
mf_map(st_geometry(area), col = "grey90", border = "grey20", lwd = 2)
mf_title("Microcuenca del Cumbaza")
mf_scale(pos = "bottomright")
mf_arrow(pos = "topleft")
mf_credits("WGS 84 / UTM 18S · Elaboración propia")

library(spatstat.random)

## --- Generar ambos muestreos ---
malla <- st_make_grid(area, cellsize = 3000, what = "centers") |>
  st_as_sf() |>
  st_filter(area)

win <- as.owin(st_geometry(area))
set.seed(2026)
ssi <- rSSI(r = 2500, n = 40, win = win)
aleatorio <- st_as_sf(data.frame(x = ssi$x, y = ssi$y),
                      coords = c("x", "y"), crs = st_crs(area))

## --- Dos paneles lado a lado ---
par(mfrow = c(1, 2))

# Panel 1: sistemático
mf_map(st_geometry(area), col = "grey95", border = "grey40", lwd = 1.5)
mf_map(malla, pch = 2, col = "#2166ac", cex = 1, lwd = 2, add = TRUE)
mf_title("Sistemático (malla 3000 m)")
mf_scale(pos = "bottomleft")
mf_arrow(pos = "topleft")

# Panel 2: aleatorio inhibido
mf_map(st_geometry(area), col = "grey95", border = "grey40", lwd = 1.5)
mf_map(aleatorio, pch = 21, col = "grey20", bg = "#d6604d", cex = 0.9, add = TRUE)
mf_title("Aleatorio inhibido (2500 m)")
mf_scale(pos = "bottomleft")
mf_arrow(pos = "topleft")

par(mfrow = c(1, 1))   # restaurar el dispositivo


pts <- st_read("muestreo_distribucion/Shapefile/Puntos_suelos.shp")

## 1. Patrón de puntos MARCADO con la MO ----
win <- as.owin(st_union(st_geometry(area)))
xy  <- st_coordinates(pts)
P   <- ppp(xy[, 1], xy[, 2], window = win, marks = pts$MO)
stopifnot(npoints(P) == nrow(pts))

## 2. Suavizado kernel de la MO -> valores en %, no densidad ----
sigma_opt <- bw.smoothppp(P)              # ancho de banda propio de Smooth (no bw.diggle)
mo_s <- Smooth(P, sigma = sigma_opt)      # media local ponderada de MO

## 3. Convertir 'im' a SpatRaster ----
mo_r <- rast(as.data.frame(mo_s), type = "xyz")   # columnas x, y, value (= MO %)
crs(mo_r) <- st_crs(area)$wkt
mo_r <- mask(mo_r, vect(area))
names(mo_r) <- "MO (%)"

## 4. Mapa con mapsf ----
mf_raster(mo_r, type = "continuous", pal = "Inferno", rev = F,
          leg_pos = "topright", leg_title = "MO (%)")
mf_map(st_geometry(area), col = NA, border = "grey20", lwd = 1.2, add = TRUE)
mf_map(pts, pch = 21, col = "grey20", bg = "white", cex = 0.6, add = TRUE)
mf_scale(pos = "bottomright")
mf_arrow(pos = "topleft")
mf_title("Superficie suavizada de MO del suelo (%)")
mf_credits("Datos simulados · WGS 84 / UTM 18S")

#Analisis de vecino mas cercano

## 1. Patrón de puntos dentro del área (solo posiciones) ----
area_union <- st_union(st_geometry(area))
win <- as.owin(area_union)
xy  <- st_coordinates(pts)
P   <- ppp(xy[, 1], xy[, 2], window = win)
P   <- unmark(P)                 # el vecino más cercano analiza UBICACIONES, no la MO
stopifnot(npoints(P) > 0)

area_km2 <- as.numeric(st_area(area_union)) / 1e6   # (evita usar area() de spatstat: 'area' es tu capa)

## 2. Distancias al vecino más cercano ----
nn      <- nndist(P)                     # distancia de cada punto a su vecino más próximo
lambda  <- intensity(P)                  # densidad = nº puntos / área
r_esper <- 1 / (2 * sqrt(lambda))        # distancia media esperada bajo aleatoriedad (CSR)

## 3. Índice de Clark-Evans (R) + prueba de Monte Carlo ----
R_cdf <- clarkevans(P, correction = "cdf")     # estimador con corrección de borde (ventana irregular)
set.seed(2026)
ce <- clarkevans.test(P, correction = "none",  # prueba por simulación: el borde se cancela solo
                      alternative = "two.sided", nsim = 999)

## 4. Interpretación automática ----
patron <- if (ce$p.value >= 0.05) "ALEATORIO (no se rechaza CSR)" else
          if (R_cdf < 1)          "AGRUPADO (clustered)"          else
                                  "DISPERSO / REGULAR"

cat("=========== Vecino más cercano ===========\n")
cat("Puntos analizados      :", npoints(P), "en", round(area_km2, 2), "km²\n")
cat("Dist. media observada  :", round(mean(nn), 1), "m\n")
cat("Dist. media esperada   :", round(r_esper, 1), "m (bajo aleatoriedad CSR)\n")
cat("Índice R (Clark-Evans) :", round(R_cdf, 3), "\n")
cat("p-valor (999 sim.)     :", format.pval(ce$p.value, digits = 3), "\n")
cat("Patrón espacial        :", patron, "\n")
cat("==========================================\n")

## 5. Función G: distribución acumulada de distancias al vecino, con envolvente CSR ----
set.seed(2026)
G <- envelope(P, fun = Gest, nsim = 99, correction = "km")
plot(G, main = "Función G del vecino más cercano (envolvente CSR)",
     xlab = "Distancia r (m)", ylab = "G(r)", legend = FALSE)


#Interpolación IDW

## 1. Rejilla de predicción: ráster vacío sobre el área (celda 200 m) ----
grid_r <- rast(vect(area), resolution = 200)
values(grid_r) <- 1                       # valores dummy para extraer los centros
grid_pts <- as.points(grid_r) |> st_as_sf()   # centros de celda como locations

## 2. Interpolación IDW (potencia p = 2) ----
idw_res <- gstat::idw(MO ~ 1, locations = pts, newdata = grid_pts,
                      idp = 2, nmax = 12)   # nmax limita vecinos: más rápido y estable

## 3. Rasterizar la predicción y recortar al área ----
idw_r <- rasterize(vect(idw_res), grid_r, field = "var1.pred")
idw_r <- mask(idw_r, vect(area))
names(idw_r) <- "MO (%)"

range(values(idw_r), na.rm = TRUE)        # verifica que estén en % (~1.2–5.5)

## 4. Mapa con mapsf ----
mf_raster(idw_r, type = "continuous", pal = "YlGn",
          leg_pos = "topright", leg_title = "MO (%)")
mf_map(st_geometry(area), col = NA, border = "grey20", lwd = 1.2, add = TRUE)
mf_map(pts, pch = 21, col = "grey20", bg = "white", cex = 0.6, add = TRUE)
mf_scale(pos = "bottomright")
mf_arrow(pos = "topleft")
mf_title("Interpolación IDW de MO del suelo (%)")
mf_credits("Datos simulados · WGS 84 / UTM 18S")
