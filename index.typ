// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a4",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Manual de Prácticas de SIG],
  subtitle: [Muestreo espacial e índices satelitales con QGIS 4.2 y R],
  author: "Fernando Michel Tuesta Chichipe",
  date: "2026-08-06",
  lang: "es",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
  supplement-chapter: "Capítulo",
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Presentación]
<presentación>
Este libro reúne dos prácticas del curso #strong[Sistema de Información Geográfica] (0101140064) de la Escuela Profesional de Agronomía de la UNSM-T, correspondientes a la Unidad III del sílabo:

- #strong[Práctica 1 --- Muestreo y su distribución espacial] (Semana 13): diseño de redes de muestreo, captura de datos en campo y análisis de su patrón espacial.
- #strong[Práctica 2 --- Índices satelitales aplicados a la agricultura] (Semanas 14--15): descarga de imágenes, cálculo de índices de vegetación y evaluación del cultivo.

Cada práctica documenta el flujo de trabajo en #strong[QGIS 4.2] como método principal y, en paralelo, su #strong[equivalente en R], de modo que las prácticas puedan reproducirse tanto con la interfaz gráfica como por código.

#heading(level: 2, numbering: none)[Cómo usar este manual]
<cómo-usar-este-manual>
#block[
#callout(
body: 
[
- Los bloques desplegables #strong[🔵 Equivalente en R] contienen el código para reproducir el paso. Vienen con #NormalTok("eval: false");\; cámbialo a #NormalTok("eval: true"); cuando trabajes con tus datos reales (colócalos en #NormalTok("data/"); y ajusta las rutas).
- Las capturas se muestran a ancho ampliado y, en la versión HTML, puedes #strong[hacer clic sobre cualquiera para verla a pantalla completa].

]
, 
title: 
[
Convenciones
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
#heading(level: 2, numbering: none)[Software y entorno]
<software-y-entorno>
Los pasos se documentan sobre #strong[QGIS 4.2 "Belém do Pará"] (Qt6, marzo 2026) y son igualmente válidos en #strong[QGIS 3.44 LTR], ya que los cambios de interfaz para el usuario son mínimos. Si utilizas la LTR, ten presente que algunos plugins Qt5 aún no son compatibles con Qt6.

Para la versión en R se requiere R ≥ 4.3 con los paquetes:

- #strong[Práctica 1:] #NormalTok("sf");, #NormalTok("terra");, #NormalTok("spatstat");, #NormalTok("gstat");, #NormalTok("tmap");, #NormalTok("dplyr");, #NormalTok("units");.
- #strong[Práctica 2:] #NormalTok("terra");, #NormalTok("sf");, #NormalTok("tmap");, #NormalTok("exactextractr");, #NormalTok("tidyterra"); (y, opcional, #NormalTok("rstac"); / #NormalTok("rsi"); para descarga automatizada de imágenes).

#Skylighting(([#FunctionTok("install.packages");#NormalTok("(");#FunctionTok("c");#NormalTok("(");#StringTok("\"sf\"");#NormalTok(",");#StringTok("\"terra\"");#NormalTok(",");#StringTok("\"spatstat\"");#NormalTok(",");#StringTok("\"gstat\"");#NormalTok(",");#StringTok("\"tmap\"");#NormalTok(",");#StringTok("\"dplyr\"");#NormalTok(",");#StringTok("\"units\"");#NormalTok(",");],
[#NormalTok("                   ");#StringTok("\"exactextractr\"");#NormalTok(",");#StringTok("\"tidyterra\"");#NormalTok("))");],));
= Muestreo y su distribución espacial
<sec-practica1>
#block[
#callout(
body: 
[
#strong[Curso:] Sistema de Información Geográfica (0101140064) · Escuela Profesional de Agronomía · UNSM-T #strong[Unidad III · Semana 13] --- Diseño de mapas con puntos de muestreo con fines de investigación. #strong[Software:] QGIS 4.2 "Belém do Pará" (Qt6). Los pasos son válidos también en QGIS 3.44 LTR; las rutas de menú son prácticamente idénticas.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Introducción
<introducción>
El muestreo es la base de toda investigación agronómica de campo: define #emph[dónde] medimos y determina qué tan bien nuestras observaciones representan al conjunto de la parcela. Cuando a cada muestra le asociamos una coordenada, dejamos de tener una simple tabla y pasamos a tener un #strong[patrón espacial] que podemos analizar: ¿las plantas afectadas se agrupan en un foco?, ¿la fertilidad se distribuye al azar?, ¿existe un gradiente?

En esta práctica diseñaremos una red de muestreo sobre una parcela, capturaremos los datos en campo, y analizaremos su distribución espacial en QGIS. En cada paso se incluye además el #strong[equivalente en R], para que la misma práctica pueda reproducirse por código.

=== Objetivos
<objetivos>
- Diseñar redes de muestreo (sistemática y aleatoria) sobre un área de estudio.
- Analizar el patrón espacial mediante mapas de calor, vecino más cercano e interpolación.
- Elaborar un mapa temático final con los puntos de muestreo.

=== Materiales y requisitos
<materiales-y-requisitos>
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Recurso], [Detalle],),
  table.hline(),
  [Software], [QGIS 4.2 (o 3.44 LTR)],
  [Datos base], [Límite del área de estudio (#NormalTok(".gpkg"); / #NormalTok(".shp");)],
  [SRC de trabajo], [WGS 84 / UTM zona 18S (EPSG:32718)],
  [Opcional (versión R)], [R ≥ 4.3 con #NormalTok("sf");, #NormalTok("terra");, #NormalTok("spatstat");, #NormalTok("gstat");, #NormalTok("tmap");, #NormalTok("dplyr");],
)

#horizontalrule

== Preparación del proyecto
<sec-preparacion>
+ Abre QGIS 4.0 y crea un proyecto nuevo: #strong[Proyecto ▸ Nuevo ▸ Guardar].
+ Define el SRC del proyecto: barra inferior derecha (icono del globo) ▸ escribe #strong[32718] ▸ selecciona #emph[WGS 84 / UTM zone 18S].
+ Carga el límite del área de estudio: #strong[Panel Navegador ▸ Inicio del proyecto] y doble click en el archivo.
+ Verifica que la capa cae sobre la ubicación correcta añadiendo un mapa base (plugin #strong[NextGIS QuickMapServices] o el conector XYZ de OpenStreetMap).

#figure([
#box(image("images/m1-01-proyecto.gif", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Proyecto inicial con el límite del área de estudio sobre el mapa base.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m1-proyecto>


#block[
#callout(
body: 
[
#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(sf)        ");#CommentTok("# vectores");],
[#FunctionTok("library");#NormalTok("(terra)     ");#CommentTok("# rasters");],
[#FunctionTok("library");#NormalTok("(spatstat)  ");#CommentTok("# análisis de patrones de puntos");],
[#FunctionTok("library");#NormalTok("(gstat)     ");#CommentTok("# interpolación (IDW / kriging)");],
[#FunctionTok("library");#NormalTok("(tmap)      ");#CommentTok("# mapas temáticos");],
[#FunctionTok("library");#NormalTok("(dplyr)");],
[],
[#CommentTok("# Área de estudio (ajusta la ruta a tu archivo)");],
[#NormalTok("area ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("st_read");#NormalTok("(");#StringTok("\"data/area_estudio.gpkg\"");#NormalTok(")");],
[],
[#CommentTok("# Reproyectar a UTM 18S para trabajar en metros");],
[#NormalTok("area ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("st_transform");#NormalTok("(area, ");#DecValTok("32718");#NormalTok(")");],
[],
[#FunctionTok("tm_shape");#NormalTok("(area) ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("tm_borders");#NormalTok("(");#AttributeTok("lwd =");#NormalTok(" ");#DecValTok("2");#NormalTok(") ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("tm_layout");#NormalTok("(");#AttributeTok("frame =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],));
]
]
, 
title: 
[
🔵 Equivalente en R
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]

#horizontalrule

== Diseño de la red de muestreo
<sec-diseno>
QGIS ofrece varios algoritmos según el tipo de muestreo. Los encuentras en #strong[Procesos ▸ Caja de herramientas] (o #NormalTok("Ctrl+Alt+T");).

=== Muestreo sistemático (malla regular)
<muestreo-sistemático-malla-regular>
Útil para caracterizar variabilidad continua (fertilidad, humedad, vigor).

+ Caja de herramientas ▸ #strong[Creación de vectores ▸ Puntos regulares].
+ En #emph[Extensión de entrada] selecciona el área de estudio (icono ▸ #emph[Usar extensión de capa]).
+ Define el #emph[Espaciado de puntos] (ej. 3000 m) según la resolución que necesites.
+ Ejecuta y recorta al polígono con #strong[Superposición vectorial ▸ Cortar] si la malla excede el borde.

#figure([
#box(image("images/m1-02-malla.gif", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Malla sistemática de puntos generada dentro del área.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m1-malla>


=== Muestreo aleatorio
<muestreo-aleatorio>
Requerido cuando el diseño estadístico exige independencia entre muestras.

+ Caja de herramientas ▸ #strong[Creación de vectores ▸ Puntos aleatorios dentro de polígonos].
+ Capa de entrada: el área de estudio.
+ Estrategia: #emph[Número de puntos] (ej. 40) y una #emph[distancia mínima] (ej. 2500 m) entre puntos para evitar agrupamientos.
+ Ejecuta.

#figure([
#box(image("images/m1-03-aleatorio.gif", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Puntos aleatorios generados dentro del área con distancia mínima.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m1-aleatorio>


#block[
#callout(
body: 
[
Para #strong[muestreo estratificado] (por unidades de manejo, tipos de suelo o campañas), primero divide el área en estratos y genera puntos por polígono usando el mismo algoritmo con la capa de estratos como entrada.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#block[
#Skylighting(([#FunctionTok("set.seed");#NormalTok("(");#DecValTok("2026");#NormalTok(")   ");#CommentTok("# reproducibilidad");],
[],
[#CommentTok("# --- Muestreo sistemático (malla regular ~25 m) ---");],
[#NormalTok("malla ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("st_sample");#NormalTok("(area, ");#AttributeTok("size =");#NormalTok(" ");#FunctionTok("st_area");#NormalTok("(area) ");#SpecialCharTok("/");#NormalTok(" units");#SpecialCharTok("::");#FunctionTok("set_units");#NormalTok("(");#DecValTok("25");#SpecialCharTok("^");#DecValTok("2");#NormalTok(", m");#SpecialCharTok("^");#DecValTok("2");#NormalTok("),");],
[#NormalTok("                    ");#AttributeTok("type =");#NormalTok(" ");#StringTok("\"regular\"");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("st_sf");#NormalTok("()");],
[],
[#CommentTok("# --- Muestreo aleatorio (40 puntos) ---");],
[#NormalTok("aleatorio ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("st_sample");#NormalTok("(area, ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("40");#NormalTok(", ");#AttributeTok("type =");#NormalTok(" ");#StringTok("\"random\"");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("st_sf");#NormalTok("()");],
[],
[#FunctionTok("tm_shape");#NormalTok("(area) ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("tm_borders");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("tm_shape");#NormalTok("(aleatorio) ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("tm_dots");#NormalTok("(");#AttributeTok("size =");#NormalTok(" ");#FloatTok("0.2");#NormalTok(")");],));
]
]
, 
title: 
[
🔵 Equivalente en R
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]

#horizontalrule

== Análisis de la distribución espacial
<sec-analisis>
=== Simbología graduada (magnitud por punto)
<simbología-graduada-magnitud-por-punto>
+ Añadir la capa #strong[Puntos\_suelos] desde el panel navegador.
+ Doble clic en la capa ▸ #strong[Simbología].
+ Cambia de #emph[Símbolo único] a #strong[Graduado].
+ Valor: #NormalTok("variable");\; método: #emph[Rupturas naturales (Jenks)]\; 5 clases; rampa de color a elección.
+ Clasifica y aplica.

#figure([
#box(image("images/m1-06-graduado.gif", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Puntos de muestreo simbolizados por magnitud de la variable.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m1-graduado>


=== Mapa de calor (densidad kernel)
<mapa-de-calor-densidad-kernel>
Muestra dónde se concentran las observaciones (o la magnitud, si se pondera).

+ Caja de herramientas ▸ #strong[Análisis de mapa de calor ▸ Mapa de calor (estimación de densidad kernel)].
+ Capa de puntos: tu capa de campo.
+ #emph[Radio] según la escala del fenómeno (ej. 50 m); opcionalmente pondera con el campo #NormalTok("variable");.
+ Ejecuta y aplica una rampa de color pseudocolor al ráster resultante.

#figure([
#box(image("images/m1-07-heatmap.gif", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Mapa de calor de densidad de muestreo.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m1-heatmap>


=== Análisis del vecino más cercano
<análisis-del-vecino-más-cercano>
Cuantifica si el patrón es #strong[agrupado, aleatorio o disperso] mediante el índice R de Clark y Evans @clark1954.

+ Caja de herramientas ▸ #strong[Análisis vectorial ▸ Análisis del vecino más cercano].
+ Capa de entrada: los puntos de muestreo.
+ Ejecuta: el resultado (HTML) reporta el #strong[índice del vecino más cercano]:
  - R \< 1 → patrón #strong[agrupado]
  - R ≈ 1 → patrón #strong[aleatorio]
  - R \> 1 → patrón #strong[disperso/regular]

El valor de R = 1.67 por lo tanto el patron es #strong[disperso/regular].

#figure([
#box(image("images/m1-08-vecino.gif", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Resultado del análisis del vecino más cercano.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m1-vecino>


#block[
#callout(
body: 
[
#block[
#Skylighting(([#CommentTok("# Convertir a patrón de puntos planar (ppp) dentro de la ventana del área");],
[#NormalTok("win ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as.owin");#NormalTok("(");#FunctionTok("st_geometry");#NormalTok("(area))");],
[#NormalTok("xy  ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("st_coordinates");#NormalTok("(pts)");],
[#NormalTok("P   ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("ppp");#NormalTok("(xy[,");#DecValTok("1");#NormalTok("], xy[,");#DecValTok("2");#NormalTok("], ");#AttributeTok("window =");#NormalTok(" win)");],
[],
[#CommentTok("# Test de Clark-Evans (patrón agrupado / aleatorio / disperso)");],
[#FunctionTok("clarkevans.test");#NormalTok("(P, ");#AttributeTok("correction =");#NormalTok(" ");#StringTok("\"Donnelly\"");#NormalTok(", ");#AttributeTok("alternative =");#NormalTok(" ");#StringTok("\"two.sided\"");#NormalTok(")");],
[],
[#CommentTok("# Densidad kernel");],
[#FunctionTok("plot");#NormalTok("(");#FunctionTok("density");#NormalTok("(P, ");#AttributeTok("sigma =");#NormalTok(" ");#DecValTok("50");#NormalTok("), ");#AttributeTok("main =");#NormalTok(" ");#StringTok("\"Densidad kernel\"");#NormalTok(")");],
[],
[#CommentTok("# Función K de Ripley (dependencia de escala)");],
[#FunctionTok("plot");#NormalTok("(");#FunctionTok("Kest");#NormalTok("(P), ");#AttributeTok("main =");#NormalTok(" ");#StringTok("\"Función K de Ripley\"");#NormalTok(")");],));
]
]
, 
title: 
[
🔵 Equivalente en R
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Interpolación de la variable (IDW) y polígonos de Voronoi
<interpolación-de-la-variable-idw-y-polígonos-de-voronoi>
Para pasar de puntos a una #strong[superficie continua] estimada.

+ #strong[IDW:] Caja de herramientas ▸ #strong[Interpolación ▸ Interpolación IDW]. Selecciona la capa, el campo #NormalTok("variable");, el coeficiente de distancia (P=2) y la extensión del área. Ejecuta.
+ #strong[Voronoi (alternativa por vecindad):] Caja de herramientas ▸ #strong[Geometría vectorial ▸ Polígonos de Voronoi]\; luego colorea cada polígono por el valor de su punto.

#figure([
#box(image("images/m1-09-idw.gif", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Superficie interpolada IDW de la variable y polígonos de Voronoi.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m1-idw>


#block[
#callout(
body: 
[
#block[
#Skylighting(([#CommentTok("# Malla de predicción sobre el área");],
[#NormalTok("grid ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("st_make_grid");#NormalTok("(area, ");#AttributeTok("cellsize =");#NormalTok(" ");#DecValTok("10");#NormalTok(", ");#AttributeTok("what =");#NormalTok(" ");#StringTok("\"centers\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("st_sf");#NormalTok("() ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("st_filter");#NormalTok("(area)");],
[],
[#CommentTok("# Interpolación IDW (potencia = 2)");],
[#NormalTok("idw_res ");#OtherTok("<-");#NormalTok(" gstat");#SpecialCharTok("::");#FunctionTok("idw");#NormalTok("(variable ");#SpecialCharTok("~");#NormalTok(" ");#DecValTok("1");#NormalTok(", pts, ");#AttributeTok("newdata =");#NormalTok(" grid, ");#AttributeTok("idp =");#NormalTok(" ");#DecValTok("2");#NormalTok(")");],
[],
[#FunctionTok("tm_shape");#NormalTok("(idw_res) ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("tm_dots");#NormalTok("(");#AttributeTok("col =");#NormalTok(" ");#StringTok("\"var1.pred\"");#NormalTok(", ");#AttributeTok("palette =");#NormalTok(" ");#StringTok("\"-RdYlGn\"");#NormalTok(", ");#AttributeTok("size =");#NormalTok(" ");#FloatTok("0.1");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("tm_shape");#NormalTok("(pts) ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("tm_dots");#NormalTok("(");#AttributeTok("size =");#NormalTok(" ");#FloatTok("0.15");#NormalTok(")");],
[],
[#CommentTok("# Polígonos de Voronoi");],
[#NormalTok("voro ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("st_voronoi");#NormalTok("(");#FunctionTok("st_union");#NormalTok("(pts)) ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("st_collection_extract");#NormalTok("() ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("st_intersection");#NormalTok("(area)");],));
]
]
, 
title: 
[
🔵 Equivalente en R
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]

#horizontalrule

== Producto de la práctica
<producto-de-la-práctica>
Entrega un mapa temático (PDF/JPEG) con:

- La red de muestreo y la variable simbolizada por magnitud.
- Al menos un análisis de patrón (mapa de calor #strong[o] vecino más cercano) con su interpretación.
- Todos los elementos cartográficos (título, leyenda, escala, norte, grilla, membrete).

Y una breve interpretación (½ página): ¿el patrón es agrupado, aleatorio o disperso? ¿Qué implica para tu objeto de estudio?

= Índices satelitales aplicados a la agricultura
<sec-practica2>
#block[
#callout(
body: 
[
#strong[Curso:] Sistema de Información Geográfica (0101140064) · Escuela Profesional de Agronomía · UNSM-T #strong[Unidad III · Semanas 14--15] --- Teledetección, descarga de imágenes satelitales y cálculo del NDVI. #strong[Software:] QGIS 4.0 "Norrköping" (Qt6). Válido también en QGIS 3.44 LTR.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Introducción
<introducción-1>
Los sensores satelitales miden la energía que la superficie refleja en distintas longitudes de onda (#strong[bandas espectrales]). La vegetación sana refleja mucho en el #strong[infrarrojo cercano (NIR)] y absorbe en el #strong[rojo] (por la clorofila): esa diferencia es la base de los #strong[índices de vegetación], que resumen el vigor del cultivo en un solo número por píxel.

En esta práctica descargaremos una imagen satelital, calcularemos varios índices y evaluaremos el estado del cultivo por lote. En cada paso se incluye el #strong[equivalente en R] con el paquete #NormalTok("terra");, para migrar la práctica a código.

=== Objetivos
<objetivos-1>
- Descargar imágenes Sentinel-2 / Landsat de portales gratuitos.
- Componer bandas (color natural y falso color) y recortar al área de estudio.
- Calcular NDVI y otros índices con la Calculadora ráster.
- Clasificar el vigor y obtener estadísticas por parcela.

=== Materiales y requisitos
<materiales-y-requisitos-1>
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Recurso], [Detalle],),
  table.hline(),
  [Software], [QGIS 4.0 (o 3.44 LTR)],
  [Imagen], [Sentinel-2 (10 m) o Landsat 8/9 (30 m)],
  [Portales], [Copernicus Browser, USGS EarthExplorer, LandViewer],
  [Límite de parcelas], [Capa vectorial (#NormalTok(".gpkg"); / #NormalTok(".shp");)],
  [Opcional (versión R)], [R ≥ 4.3 con #NormalTok("terra");, #NormalTok("sf");, #NormalTok("tmap");, #NormalTok("exactextractr");, #NormalTok("tidyterra");],
)
=== Correspondencia de bandas
<sec-bandas>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Uso], [Sentinel-2], [Landsat 8/9],),
  table.hline(),
  [Azul], [B2], [B2],
  [Verde], [B3], [B3],
  [#strong[Rojo]], [#strong[B4]], [#strong[B4]],
  [Borde rojo (Red-edge)], [B5], [---],
  [#strong[NIR]], [#strong[B8]], [#strong[B5]],
  [SWIR-1], [B11], [B6],
)

#horizontalrule

== Descarga de la imagen satelital
<sec-descarga>
Este paso se hace en el #strong[navegador web] (fuera de QGIS). Usaremos el Copernicus Browser (Sentinel-2), pero EarthExplorer o LandViewer son equivalentes.

+ Ingresa a Copernicus Browser y crea una cuenta gratuita.
+ Ubica tu zona de estudio en el mapa.
+ Filtra por #strong[fecha] y por #strong[cobertura de nubes] (busca \< 10 %).
+ Selecciona un producto #strong[Sentinel-2 L2A] (reflectancia de superficie, ya corregida atmosféricamente).
+ Descarga las bandas necesarias (mínimo B4 y B8; añade B3, B5, B11 para más índices).

#figure([
#box(image("images/m2-01-descarga.png", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Selección de la escena Sentinel-2 en el portal de descarga. #strong[📸 Capturar:] el navegador web con la escena seleccionada, el filtro de fecha y el porcentaje de nubes visible.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m2-descarga>


#block[
#callout(
body: 
[
#strong[L2A vs.~L1C:] usa siempre #strong[L2A] (reflectancia de superficie) para calcular índices; L1C es reflectancia en el tope de la atmósfera y requiere corrección previa.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]

#horizontalrule

== Carga de bandas y composiciones
<sec-carga>
+ #strong[Capa ▸ Añadir capa ▸ Añadir capa ráster] y carga cada banda (o el producto completo).
+ #strong[Color natural (RGB):] doble clic en la capa ▸ Simbología ▸ #emph[Multibanda color] ▸ R=B4, G=B3, B=B2.
+ #strong[Falso color (vegetación en rojo):] R=B8, G=B4, B=B3. La vegetación vigorosa aparece en tonos rojos intensos.

#figure([
#box(image("images/m2-02-falsocolor.png", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Composición en falso color de la zona de estudio. #strong[📸 Capturar:] el lienzo con la composición falso color (NIR-Rojo-Verde), donde la vegetación resalta en rojo.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m2-falsocolor>


#block[
#callout(
body: 
[
#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(terra)");],
[#FunctionTok("library");#NormalTok("(sf)");],
[#FunctionTok("library");#NormalTok("(tmap)");],
[#FunctionTok("library");#NormalTok("(exactextractr)");],
[],
[#CommentTok("# Cargar bandas (ajusta rutas/nombres a tu descarga)");],
[#NormalTok("b3 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("rast");#NormalTok("(");#StringTok("\"data/S2_B03.tif\"");#NormalTok(")  ");#CommentTok("# Verde");],
[#NormalTok("b4 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("rast");#NormalTok("(");#StringTok("\"data/S2_B04.tif\"");#NormalTok(")  ");#CommentTok("# Rojo");],
[#NormalTok("b5 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("rast");#NormalTok("(");#StringTok("\"data/S2_B05.tif\"");#NormalTok(")  ");#CommentTok("# Borde rojo");],
[#NormalTok("b8 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("rast");#NormalTok("(");#StringTok("\"data/S2_B08.tif\"");#NormalTok(")  ");#CommentTok("# NIR");],
[],
[#CommentTok("# Composición falso color (NIR-Rojo-Verde)");],
[#NormalTok("falso ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(b8, b4, b3)");],
[#FunctionTok("plotRGB");#NormalTok("(falso, ");#AttributeTok("r =");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("g =");#NormalTok(" ");#DecValTok("2");#NormalTok(", ");#AttributeTok("b =");#NormalTok(" ");#DecValTok("3");#NormalTok(", ");#AttributeTok("stretch =");#NormalTok(" ");#StringTok("\"lin\"");#NormalTok(")");],));
]
]
, 
title: 
[
🔵 Equivalente en R
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]

#horizontalrule

== Recorte al área de estudio
<sec-recorte>
Trabajar sobre toda la escena es lento; recortamos a nuestras parcelas.

+ Carga la capa de parcelas (asegura mismo SRC que el ráster).
+ Caja de herramientas ▸ #strong[Extracción de ráster ▸ Cortar ráster por capa de máscara].
+ Capa de entrada: la banda (o cada banda); capa de máscara: las parcelas. Ejecuta.

#figure([
#box(image("images/m2-03-recorte.png", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Bandas recortadas al límite de las parcelas. #strong[📸 Capturar:] el diálogo "Cortar ráster por capa de máscara" y el resultado recortado sobre el área de trabajo.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m2-recorte>


#block[
#callout(
body: 
[
#block[
#Skylighting(([#NormalTok("parcelas ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("st_read");#NormalTok("(");#StringTok("\"data/parcelas.gpkg\"");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("st_transform");#NormalTok("(");#FunctionTok("crs");#NormalTok("(b8))");],
[],
[#NormalTok("recortar ");#OtherTok("<-");#NormalTok(" ");#ControlFlowTok("function");#NormalTok("(r) ");#FunctionTok("crop");#NormalTok("(");#FunctionTok("mask");#NormalTok("(r, ");#FunctionTok("vect");#NormalTok("(parcelas)), ");#FunctionTok("vect");#NormalTok("(parcelas))");],
[#NormalTok("b3 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("recortar");#NormalTok("(b3); b4 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("recortar");#NormalTok("(b4); b5 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("recortar");#NormalTok("(b5); b8 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("recortar");#NormalTok("(b8)");],));
]
]
, 
title: 
[
🔵 Equivalente en R
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]

#horizontalrule

== Cálculo de índices con la Calculadora ráster
<sec-indices>
Abre #strong[Ráster ▸ Calculadora ráster] (o desde la Caja de herramientas: #emph[Análisis ráster ▸ Calculadora ráster]).

#block[
#callout(
body: 
[
Si tus bandas están en enteros escalados (DN), primero conviértelas a reflectancia (típicamente dividir entre 10000 en Sentinel-2 L2A). Trabaja con #strong[decimales].

]
, 
title: 
[
Importante
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
=== NDVI --- Índice de Vegetación de Diferencia Normalizada @rouse1974
<ndvi-índice-de-vegetación-de-diferencia-normalizada-rouse1974>
$ N D V I = frac(N I R - R o j o, N I R + R o j o) $

En la Calculadora ráster escribe (Sentinel-2):

#Skylighting(([#NormalTok("(\"B8@1\" - \"B4@1\") / (\"B8@1\" + \"B4@1\")");],));
Para #strong[Landsat 8/9] usa #NormalTok("(\"B5@1\" - \"B4@1\") / (\"B5@1\" + \"B4@1\")");. El NDVI varía de −1 a 1: valores altos (0.6--0.9) indican vegetación densa y vigorosa; cercanos a 0, suelo desnudo; negativos, agua.

#figure([
#box(image("images/m2-04-ndvi.png", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Cálculo del NDVI en la Calculadora ráster. #strong[📸 Capturar:] el diálogo de la Calculadora con la expresión del NDVI escrita, y el ráster NDVI resultante.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m2-ndvi>


=== Otros índices útiles
<otros-índices-útiles>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Índice], [Fórmula (Sentinel-2)], [Uso],),
  table.hline(),
  [#strong[SAVI] @huete1988], [#NormalTok("1.5*(B8-B4)/(B8+B4+0.5)");], [Corrige el efecto del suelo en cobertura baja],
  [#strong[GNDVI]], [#NormalTok("(B8-B3)/(B8+B3)");], [Sensible al contenido de clorofila],
  [#strong[NDRE]], [#NormalTok("(B8-B5)/(B8+B5)");], [Estrés en cultivos densos (usa borde rojo)],
  [#strong[NDWI]], [#NormalTok("(B3-B8)/(B3+B8)");], [Contenido de agua / detección de cuerpos de agua],
)
#figure([
#box(image("images/m2-05-indices.png", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Comparación de índices (NDVI vs.~otro índice). #strong[📸 Capturar:] dos rásters de índices lado a lado con su rampa de color.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m2-indices>


#block[
#callout(
body: 
[
#block[
#Skylighting(([#CommentTok("# (si vienen escalados, primero: b4 <- b4/10000, etc.)");],
[#NormalTok("ndvi  ");#OtherTok("<-");#NormalTok(" (b8 ");#SpecialCharTok("-");#NormalTok(" b4) ");#SpecialCharTok("/");#NormalTok(" (b8 ");#SpecialCharTok("+");#NormalTok(" b4)");],
[#NormalTok("savi  ");#OtherTok("<-");#NormalTok(" ");#FloatTok("1.5");#NormalTok(" ");#SpecialCharTok("*");#NormalTok(" (b8 ");#SpecialCharTok("-");#NormalTok(" b4) ");#SpecialCharTok("/");#NormalTok(" (b8 ");#SpecialCharTok("+");#NormalTok(" b4 ");#SpecialCharTok("+");#NormalTok(" ");#FloatTok("0.5");#NormalTok(")");],
[#NormalTok("gndvi ");#OtherTok("<-");#NormalTok(" (b8 ");#SpecialCharTok("-");#NormalTok(" b3) ");#SpecialCharTok("/");#NormalTok(" (b8 ");#SpecialCharTok("+");#NormalTok(" b3)");],
[#NormalTok("ndre  ");#OtherTok("<-");#NormalTok(" (b8 ");#SpecialCharTok("-");#NormalTok(" b5) ");#SpecialCharTok("/");#NormalTok(" (b8 ");#SpecialCharTok("+");#NormalTok(" b5)");],
[],
[#FunctionTok("plot");#NormalTok("(ndvi, ");#AttributeTok("main =");#NormalTok(" ");#StringTok("\"NDVI\"");#NormalTok(")");],
[#FunctionTok("global");#NormalTok("(ndvi, ");#AttributeTok("fun =");#NormalTok(" ");#StringTok("\"mean\"");#NormalTok(", ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")   ");#CommentTok("# NDVI medio de la escena");],));
]
]
, 
title: 
[
🔵 Equivalente en R
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]

#horizontalrule

== Simbología y clases de vigor
<sec-simbologia>
+ Doble clic en el ráster NDVI ▸ #strong[Simbología].
+ Tipo de renderizado: #strong[Pseudocolor de banda simple].
+ Rampa de color #strong[RdYlGn] (rojo = bajo vigor, verde = alto vigor).
+ Modo #emph[Clasificar] con cortes interpretables, p.~ej.:

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Clase], [Rango NDVI], [Interpretación],),
  table.hline(),
  [Muy bajo], [\< 0.2], [Suelo desnudo / sin cultivo],
  [Bajo], [0.2 -- 0.4], [Vegetación escasa / estrés],
  [Medio], [0.4 -- 0.6], [Vigor moderado],
  [Alto], [0.6 -- 0.8], [Vigor bueno],
  [Muy alto], [\> 0.8], [Cobertura densa],
)
#figure([
#box(image("images/m2-06-clases.png", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
NDVI clasificado en niveles de vigor. #strong[📸 Capturar:] el panel de Simbología en modo Pseudocolor con los cortes definidos, y el mapa NDVI clasificado.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m2-clases>


#block[
#callout(
body: 
[
#block[
#Skylighting(([#NormalTok("rcl ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("matrix");#NormalTok("(");#FunctionTok("c");#NormalTok("(");#SpecialCharTok("-");#DecValTok("1");#NormalTok(", ");#FloatTok("0.2");#NormalTok(", ");#DecValTok("1");#NormalTok(",");],
[#NormalTok("                ");#FloatTok("0.2");#NormalTok(", ");#FloatTok("0.4");#NormalTok(", ");#DecValTok("2");#NormalTok(",");],
[#NormalTok("                ");#FloatTok("0.4");#NormalTok(", ");#FloatTok("0.6");#NormalTok(", ");#DecValTok("3");#NormalTok(",");],
[#NormalTok("                ");#FloatTok("0.6");#NormalTok(", ");#FloatTok("0.8");#NormalTok(", ");#DecValTok("4");#NormalTok(",");],
[#NormalTok("                ");#FloatTok("0.8");#NormalTok(",   ");#DecValTok("1");#NormalTok(", ");#DecValTok("5");#NormalTok("), ");#AttributeTok("ncol =");#NormalTok(" ");#DecValTok("3");#NormalTok(", ");#AttributeTok("byrow =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],
[#NormalTok("ndvi_clases ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("classify");#NormalTok("(ndvi, rcl)");],
[],
[#FunctionTok("tm_shape");#NormalTok("(ndvi) ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("tm_raster");#NormalTok("(");#AttributeTok("palette =");#NormalTok(" ");#StringTok("\"RdYlGn\"");#NormalTok(", ");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"NDVI\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("tm_layout");#NormalTok("(");#AttributeTok("legend.outside =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("frame =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],));
]
]
, 
title: 
[
🔵 Equivalente en R
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]

#horizontalrule

== Estadísticas por parcela
<sec-zonal>
Para llevar el NDVI a una tabla de decisión (media por lote).

+ Caja de herramientas ▸ #strong[Análisis ráster ▸ Estadísticas zonales].
+ Capa de polígonos: parcelas; capa ráster: NDVI; estadísticas: media, mínimo, máximo, desviación.
+ Ejecuta: se añaden columnas a la tabla de atributos de las parcelas.

#figure([
#box(image("images/m2-07-zonal.png", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Estadísticas zonales de NDVI por parcela. #strong[📸 Capturar:] la tabla de atributos de las parcelas con la columna de NDVI medio, y el mapa coloreado por ese valor.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m2-zonal>


#block[
#callout(
body: 
[
#block[
#Skylighting(([#NormalTok("parcelas");#SpecialCharTok("$");#NormalTok("ndvi_medio ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("exact_extract");#NormalTok("(ndvi, parcelas, ");#StringTok("\"mean\"");#NormalTok(")");],
[#NormalTok("parcelas");#SpecialCharTok("$");#NormalTok("ndvi_min   ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("exact_extract");#NormalTok("(ndvi, parcelas, ");#StringTok("\"min\"");#NormalTok(")");],
[#NormalTok("parcelas");#SpecialCharTok("$");#NormalTok("ndvi_max   ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("exact_extract");#NormalTok("(ndvi, parcelas, ");#StringTok("\"max\"");#NormalTok(")");],
[],
[#NormalTok("parcelas[");#FunctionTok("order");#NormalTok("(parcelas");#SpecialCharTok("$");#NormalTok("ndvi_medio), ");#FunctionTok("c");#NormalTok("(");#StringTok("\"id\"");#NormalTok(", ");#StringTok("\"ndvi_medio\"");#NormalTok(")]");],));
]
]
, 
title: 
[
🔵 Equivalente en R
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]

#horizontalrule

== Composición del mapa final
<sec-layout2>
+ #strong[Proyecto ▸ Nueva composición de impresión].
+ Inserta el mapa NDVI (o una lámina comparando índices) con #strong[título, leyenda, escala, norte, grilla y membrete] (logo UNSM, autor, fecha, satélite y fecha de la imagen).
+ #strong[Exportar como PDF / imagen].

#figure([
#box(image("images/m2-08-layout.png", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Composición final con el mapa de NDVI. #strong[📸 Capturar:] el diseñador de impresión con el mapa de índice, leyenda de vigor, escala, norte, grilla y membrete.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-m2-layout>


#block[
#callout(
body: 
[
#block[
#Skylighting(([#NormalTok("mapa_ndvi ");#OtherTok("<-");],
[#NormalTok("  ");#FunctionTok("tm_shape");#NormalTok("(ndvi) ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("tm_raster");#NormalTok("(");#AttributeTok("palette =");#NormalTok(" ");#StringTok("\"RdYlGn\"");#NormalTok(", ");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"NDVI\"");#NormalTok(", ");#AttributeTok("style =");#NormalTok(" ");#StringTok("\"cont\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("tm_shape");#NormalTok("(parcelas) ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("tm_borders");#NormalTok("(");#AttributeTok("col =");#NormalTok(" ");#StringTok("\"black\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("tm_compass");#NormalTok("(");#AttributeTok("position =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"right\"");#NormalTok(", ");#StringTok("\"top\"");#NormalTok(")) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("tm_scale_bar");#NormalTok("(");#AttributeTok("position =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"left\"");#NormalTok(", ");#StringTok("\"bottom\"");#NormalTok(")) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("tm_layout");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"NDVI por parcela\"");#NormalTok(", ");#AttributeTok("legend.outside =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("frame =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],
[],
[#FunctionTok("tmap_save");#NormalTok("(mapa_ndvi, ");#StringTok("\"images/mapa_ndvi_R.png\"");#NormalTok(", ");#AttributeTok("dpi =");#NormalTok(" ");#DecValTok("300");#NormalTok(")");],));
]
]
, 
title: 
[
🔵 Equivalente en R
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Para automatizar la descarga sin el portal web puedes usar #NormalTok("rstac"); (Planetary Computer / AWS) o el paquete #NormalTok("rsi");, que trae #NormalTok("get_sentinel2_imagery()"); y helpers para calcular índices directamente sobre el cubo descargado.

]
, 
title: 
[
Descarga por código (opcional, para tu versión 100 % R)
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]

#horizontalrule

== Producto de la práctica
<producto-de-la-práctica-1>
Entrega un mapa temático (PDF/JPEG) con:

- El NDVI clasificado en niveles de vigor sobre tus parcelas.
- La tabla de NDVI medio por parcela (estadísticas zonales).
- Todos los elementos cartográficos, indicando #strong[satélite, fecha de la imagen y % de nubes].

Y una breve interpretación (½ página): ¿qué parcelas muestran menor vigor y qué manejo agronómico sugerirías?

#heading(level: 1, numbering: none)[Referencias]
<referencias>
#block[
] <refs>



#bibliography(("references.bib"))

