

`%||%` <- function (x, y) {
  if (is.null(x)) y else x
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Convert a devices colour back into an RGB colour
#'
#' @param col 4 element RGBA colour with values in range [0-255]
#'
#' @importFrom grDevices rgb
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
col2hex <- function(col) {
  rgb(col[1], col[2], col[3], col[4], maxColorValue = 255)
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# When the device is opened
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi_open <- function(args, state) {

  width <- state$rdata$width
  if (is.null(width)) {
    width  <- getOption('width', default = 80)
  }

  height <- state$rdata$height
  if (is.null(height)) {
    # Set height to visually be half the width
    height <- as.integer(width * 0.5 * state$rdata$font_aspect)
  }

  state$rdata$width    <- width
  state$rdata$height   <- height
  state$dd$right       <- width   * 72
  state$dd$bottom      <- height  * 72
  state$dd$clipRight   <- width   * 72
  state$dd$clipBottom  <- height  * 72


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # ANSI device
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  bg <- col2hex(state$dd$startfill)
  state$rdata$ansi <- miniansi::ANSI$new(width = width, height = height, background = bg, ansi_bits = state$rdata$colour_depth)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # ASCII has different "inches per pixel" in the x and y direction.
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  font_aspect <- state$rdata$font_aspect %||% 0.45
  state$dd$ipr <- c(1/72, 1/72/font_aspect)
  state$dd$hasTextUTF8    <- TRUE  # The macOS terminal will let us use utf8
  state$dd$wantSymbolUTF8 <- TRUE



  state
}



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# When the device is closed
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi_close <- function(args, state) {

  filename          <- state$rdata$filename
  ansi              <- state$rdata$ansi
  plain_ascii       <- isTRUE(state$rdata$plain_ascii)
  char_lookup_table <- state$rdata$char_lookup_table %||% 1
  pow               <- state$rdata$pow %||% 1

  if (!is.null(filename)) {
    ansi$save(filename, plain_ascii = plain_ascii, char_lookup_table = char_lookup_table, pow = pow)
  } else {
    ansi$print(plain_ascii = plain_ascii, char_lookup_table = char_lookup_table, pow = pow)
  }

  state
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Draw a line
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi_line <- function(args, state) {

  x1 <- args$x1 / 72
  x2 <- args$x2 / 72
  y1 <- args$y1 / 72
  y2 <- args$y2 / 72

  state$rdata$ansi$line(x1, y1,  x2,  y2, col2hex(state$gc$col))

  state
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Draw a rectangle
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi_rect <- function(args, state) {

  xmin <- round(min(c(args$x0, args$x1))/72)
  xmax <- round(max(c(args$x0, args$x1))/72)
  ymin <- round(min(c(args$y0, args$y1))/72)
  ymax <- round(max(c(args$y0, args$y1))/72)
  state$rdata$ansi$rect(
    xmin, ymin, xmax, ymax,
    colour = col2hex(state$gc$col),
    fill   = col2hex(state$gc$fill)
  )

  state
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Simply polyline
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi_polyline <- function(args, state) {

  xs  <- as.integer(round(args$x / 72))
  ys  <- as.integer(round(args$y / 72))
  col <- col2hex(state$gc$col)

  state$rdata$ansi$polyline(xs, ys, colour = col)

  state
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# No filled polygons (yet!)
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi_polygon <- function(args, state) {

  xs   <- as.integer(round(args$x / 72))
  ys   <- as.integer(round(args$y / 72))
  col  <- col2hex(state$gc$col)
  fill <- col2hex(state$gc$fill)

  state$rdata$ansi$polygon(xs, ys, colour = col, fill = fill)

  state
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Draw multiple paths
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi_path <- function(args, state) {

  extents <- c(0, cumsum(args$nper))
  col     <- col2hex(state$gc$col)
  fill    <- col2hex(state$gc$fill)
  alpha   <- state$gc$fill[4]/255

  xs <- as.integer(round(args$x / 72))
  ys <- as.integer(round(args$y / 72))

  for (poly in seq_len(args$npoly)) {
    subargs   <- args
    lower     <- extents[poly     ] + 1L
    upper     <- extents[poly + 1L]
    x         <- xs[lower:upper]
    y         <- ys[lower:upper]
    state$rdata$ansi$polygon(
      xs          = x,
      ys          = y,
      colour      = col,
      fill        = fill
    )

  }


  state
}



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Calculate and return the string width in the current state
#
# device_StrWidth should return the width of the given
# string in DEVICE units.
#
# graphics parameters that should be honoured (if possible):
#   font, cex, ps
#
# @param str string
#
# @return Optionally return 'width' the display width of the string in device units (numeric).
#         If not returned then a default value is used i.e. (strlen(str) + 2) * 72
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi_strWidth <- function(args, state) {

  str <- args$str

  state$width <- (nchar(str) - 0.5) * 72

  state
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# For a text device, these numbers are pure fudge.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi_metricInfo <- function(args, state) {

  state$ascent  <- 0.5 * 72
  state$descent <- 0.7 * 72

  state
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ref: http://members.chello.at/~easyfilter/bresenham.html
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi_circle <- function(args, state) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Scales sizes and coords
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  r  <- ceiling(args$r/2)
  xc <- args$x / 72
  yc <- args$y / 72

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Draw a circle
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  state$rdata$ansi$circle(
    xc, yc, r = r,
    colour = col2hex(state$gc$col),
    fill   = col2hex(state$gc$fill)
  )

  state
}





#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Text
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi_text <- function(args, state) {
  x <- round(args$x/72)
  y <- round(args$y/72)


  str <- args$str

  # For text at 90degrees, y coord needs to be offset
  if (args$rot == 90) {
    n   <- nchar(str)
    n2  <- floor(n/2)
    y   <- y - n2
  }

  colour <- col2hex(state$gc$col)
  state$rdata$ansi$text(x, y, text = str, angle = args$rot, colour = colour)

  state
}






#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' ASCII callback for the rdevice
#'
#' @param device_call name of device function call
#' @param args arguments to device function call
#' @param state list of rdata, dd and gc. Some or all of which may be NULL
#'
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi_callback <- function(device_call, args, state) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Anything we're not handling, just return() straight away
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # print(state$name)
  state <- switch(
    device_call,
    "open"         = ansi_open      (args, state),
    "close"        = ansi_close     (args, state),
    "line"         = ansi_line      (args, state),
    "polyline"     = ansi_polyline  (args, state),
    "circle"       = ansi_circle    (args, state),
    "rect"         = ansi_rect      (args, state),
    "text"         = ansi_text      (args, state),
    'strWidth'     = ansi_strWidth  (args, state),
    "textUTF8"     = ansi_text      (args, state),
    'strWidthUTF8' = ansi_strWidth  (args, state),
    'polygon'      = ansi_polygon   (args, state),
    'metricInfo'   = ansi_metricInfo(args, state),
    'path'         = ansi_path      (args, state),
    'circle'       = ansi_circle    (args, state),
    {
      # if (!device_call %in% c('strWidth', 'size', 'clip', 'mode', 'metricInfo')) {
      #   print(device_call);
      # }
      state
    }
  )

  state
}


