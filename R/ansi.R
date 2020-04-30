


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Graphics device for ANSI output
#'
#' Graphics primitives will be rendered using ANSI characters.
#'
#' Uses \code{devout::rdevice()}.
#'
#' @param filename If given, write ANSII to this file, otherwise write to console.
#' @param width,height dimensions of text output (in characters). Default: NULL
#'                     (auto-detect)
#' @param colour_depth ANSI colour depth. Default: 8.  8 is best for most terminals
#'        (including the Rstudio console).   24-bit depth is not supported by
#'        all terminals - use with caution.
#' @param plain_ascii Print ASCII representation only. default: FALSE
#' @param pow only valid when \code{plain_ascii = TRUE}. raise intensity to this
#'        power before conversion to an ASCII character.  Default: 1
#' @param char_lookup_table only valid when \code{plain_ascii = TRUE}. Choose from
#'        the available character mappings. Default: 1. Possible values 1, 2 or 3
#' @param font_aspect Character spacing horizontally and vertically are almost
#'        never the same. On many terminals character resolution vertically is
#'        half the resolution horizontally.  Adjust this value if circles don't
#'        look right. Default: 0.45
#' @param ... other parameters passed to the rdevice
#'
#' @import devout
#' @import miniansi
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ansi <- function(filename = NULL, width = NULL, height = NULL, colour_depth = 8,
                 plain_ascii = FALSE, pow = 1, char_lookup_table = 1, font_aspect = 0.45, ...) {
  devout::rdevice(ansi_callback, filename = filename, width = width, height = height,
                  colour_depth = colour_depth, plain_ascii = plain_ascii,
                  char_lookup_table = char_lookup_table, pow = pow,
                  font_aspect = font_aspect,
                  ..., device_name = 'ansi')
}
