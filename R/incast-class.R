#' Internal S3 constructors
#'
#' @name incast-class
#' @keywords internal
#' @noRd
NULL


#' @keywords internal
#' @noRd
new_incast_data <- function(data, key, target, window, interval, history) {
  stopifnot(
    is.data.frame(data),
    is.character(key), length(key) > 0L, all(key %in% names(data)),
    is.character(target), length(target) == 1L,
    inherits(window, "Date"), length(window) == 2L,
    is.numeric(interval), length(interval) == 1L,
    is.logical(history), length(history) == 1L
  )
  structure(
    list(
      data = data,
      key = key,
      target = target,
      window = window,
      interval = as.integer(interval),
      history = history
    ),
    class = "incast_data"
  )
}


#' @keywords internal
#' @noRd
new_incast_ncast <- function(
  data,
  key,
  target,
  window,
  interval,
  history,
  meta
) {
  stopifnot(is.list(meta))
  out <- new_incast_data(data, key, target, window, interval, history)
  out$meta <- meta
  class(out) <- "incast_ncast"
  out
}


#' @keywords internal
#' @noRd
new_incast_cv <- function(forecasts, oracle, score, models, meta, data) {
  stopifnot(is.list(models), is.list(meta), is.data.frame(data))
  structure(
    list(
      forecasts = forecasts,
      oracle = oracle,
      score = score,
      models = models,
      meta = meta,
      data = data
    ),
    class = "incast_cv"
  )
}


#' @keywords internal
#' @noRd
new_incast_fcast <- function(hub, score, meta) {
  stopifnot(is.list(hub), is.list(meta))
  structure(
    list(hub = hub, score = score, meta = meta),
    class = "incast_fcast"
  )
}


#' Read shared metadata from a pipeline object
#' @param x An \code{incast_data}, \code{incast_ncast}, \code{incast_cv} or
#'   \code{incast_fcast}.
#' @return A named list.
#' @keywords internal
#' @noRd
incast_meta <- function(x) {
  if (inherits(x, c("incast_data", "incast_ncast"))) {
    x[c("key", "target", "window", "interval", "history")]
  } else if (inherits(x, c("incast_cv", "incast_fcast"))) {
    x$meta[c("key", "target", "interval")]
  } else {
    stop(
      "`x` must be an incast_data, incast_ncast, incast_cv or ",
      "incast_fcast object.\n",
      "Run check_data() on your data frame first."
    )
  }
}
