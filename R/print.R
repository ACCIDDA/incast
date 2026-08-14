#' Shared print helpers
#'
#' @keywords internal
#' @noRd
cat_field <- function(label, ...) {
  cat(sprintf("%-9s %s\n", paste0(label, ":"), paste0(...)))
}


#' Format series information
#'
#' @keywords internal
#' @noRd
fmt_series <- function(df, key) {
  sprintf("%d (%s)", nrow(unique(df[key])), paste(key, collapse = " x "))
}


#' Format a date range and reporting interval
#'
#' @keywords internal
#' @noRd
fmt_window <- function(from, to, interval) {
  paste0(from, " to ", to, " (", interval, "-day interval)")
}


#' Print an \code{incast_data} object
#'
#' @param x An \code{incast_data} object.
#' @param ... Ignored.
#'
#' @export
print.incast_data <- function(x, ...) {
  m <- incast_meta(x)
  cat("<incast_data>\n")
  cat_field("Target", m$target)
  cat_field("Series", fmt_series(x$data, m$key))
  cat_field("Window", fmt_window(m$window[["from"]], m$window[["to"]], m$interval))
  if (m$history) {
    cat_field("History", min(x$data$as_of), " to ", max(x$data$as_of))
  }
  invisible(x)
}


#' Print an \code{incast_ncast} object
#'
#' @param x An \code{incast_ncast} object.
#' @param ... Ignored.
#'
#' @export
print.incast_ncast <- function(x, ...) {
  m <- incast_meta(x)
  cat("<incast_ncast>\n")
  cat_field("Target", m$target)
  cat_field("Series", fmt_series(x$data, m$key))
  cat_field("Window", fmt_window(m$window[["from"]], m$window[["to"]], m$interval))
  corrected <- x$data$target_end_date[!is.na(x$data$ncast_lower)]
  if (length(corrected) > 0) {
    cat_field("Nowcast", min(corrected), " to ", max(corrected))
  }
  invisible(x)
}


#' Print an \code{incast_cv} object
#'
#' @param x An \code{incast_cv} object.
#' @param ... Ignored.
#'
#' @export
print.incast_cv <- function(x, ...) {
  m <- incast_meta(x)
  cat("<incast_cv>\n")
  cat_field("Target", m$target)
  cat_field("Series", fmt_series(x$data, m$key))
  cat_field(
    "Window",
    fmt_window(min(x$data$target_end_date), max(x$data$target_end_date), m$interval)
  )
  cat_field(
    "CV",
    length(x$models), " models x ",
    dplyr::n_distinct(x$forecasts$reference_date), " origins (h = ", x$meta$h, ")"
  )
  invisible(x)
}


#' Print an \code{incast_fcast} object
#'
#' @param x An \code{incast_fcast} object.
#' @param ... Ignored.
#'
#' @export
print.incast_fcast <- function(x, ...) {
  m <- incast_meta(x)
  rng <- range(x$hub$model_out_tbl$target_end_date)
  cat("<incast_fcast>\n")
  cat_field("Target", m$target)
  cat_field("Series", fmt_series(x$hub$model_out_tbl, m$key))
  cat_field("Forecast", rng[1], " to ", rng[2], " (h = ", x$meta$h, ")")
  n_models <- dplyr::n_distinct(x$hub$model_out_tbl$model_id) - 1L
  cat_field("Models", n_models, " + ENSEMBLE")
  invisible(x)
}
