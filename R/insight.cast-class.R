#' Internal S3 constructors
#'
#' @name insight.cast-class
#' @keywords internal
#' @noRd
NULL


#' @keywords internal
#' @noRd
new_insightcast_data <- function(data, key, target, window, interval, history) {
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
    class = "insightcast_data"
  )
}


#' @keywords internal
#' @noRd
new_insightcast_ncast <- function(
  data,
  key,
  target,
  window,
  interval,
  history,
  meta
) {
  stopifnot(is.list(meta))
  out <- new_insightcast_data(data, key, target, window, interval, history)
  out$meta <- meta
  class(out) <- "insightcast_ncast"
  out
}


#' @keywords internal
#' @noRd
new_insightcast_cv <- function(forecasts, oracle, score, models, meta, data) {
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
    class = "insightcast_cv"
  )
}


#' @keywords internal
#' @noRd
new_insightcast_fcast <- function(hub, score, meta) {
  stopifnot(is.list(hub), is.list(meta))
  structure(
    list(hub = hub, score = score, meta = meta),
    class = "insightcast_fcast"
  )
}


#' Read shared metadata from a pipeline object
#' @param x An \code{insightcast_data}, \code{insightcast_ncast}, \code{insightcast_cv} or
#'   \code{insightcast_fcast}.
#' @return A named list.
#' @keywords internal
#' @noRd
insightcast_meta <- function(x) {
  if (inherits(x, c("insightcast_data", "insightcast_ncast"))) {
    x[c("key", "target", "window", "interval", "history")]
  } else if (inherits(x, c("insightcast_cv", "insightcast_fcast"))) {
    x$meta[c("key", "target", "interval")]
  } else {
    stop(
      "`x` must be an insightcast_data, insightcast_ncast, insightcast_cv or ",
      "insightcast_fcast object.\n",
      "Run check_data() on your data frame first."
    )
  }
}
