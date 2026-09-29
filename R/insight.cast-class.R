#' Internal S3 constructors
#'
#' @name insight.cast-class
#' @keywords internal
#' @noRd
NULL


#' @keywords internal
#' @noRd
new_insight.cast_data <- function(data, key, target, window, interval, history) {
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
    class = "insight.cast_data"
  )
}


#' @keywords internal
#' @noRd
new_insight.cast_ncast <- function(
  data,
  key,
  target,
  window,
  interval,
  history,
  meta
) {
  stopifnot(is.list(meta))
  out <- new_insight.cast_data(data, key, target, window, interval, history)
  out$meta <- meta
  class(out) <- "insight.cast_ncast"
  out
}


#' @keywords internal
#' @noRd
new_insight.cast_cv <- function(forecasts, oracle, score, models, meta, data) {
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
    class = "insight.cast_cv"
  )
}


#' @keywords internal
#' @noRd
new_insight.cast_fcast <- function(hub, score, meta) {
  stopifnot(is.list(hub), is.list(meta))
  structure(
    list(hub = hub, score = score, meta = meta),
    class = "insight.cast_fcast"
  )
}


#' Read shared metadata from a pipeline object
#' @param x An \code{insight.cast_data}, \code{insight.cast_ncast}, \code{insight.cast_cv} or
#'   \code{insight.cast_fcast}.
#' @return A named list.
#' @keywords internal
#' @noRd
insight.cast_meta <- function(x) {
  if (inherits(x, c("insight.cast_data", "insight.cast_ncast"))) {
    x[c("key", "target", "window", "interval", "history")]
  } else if (inherits(x, c("insight.cast_cv", "insight.cast_fcast"))) {
    x$meta[c("key", "target", "interval")]
  } else {
    stop(
      "`x` must be an insight.cast_data, insight.cast_ncast, insight.cast_cv or ",
      "insight.cast_fcast object.\n",
      "Run check_data() on your data frame first."
    )
  }
}
