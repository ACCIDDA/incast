#' Internal shared helpers
#' Internal utility functions used across incast.
#' @name incast-utils
#' @keywords internal
#' @noRd
NULL


#' Detect the reporting interval
#'
#' Determine the regular reporting interval in days from observation dates.
#' Missing periods that are multiples of the detected interval are allowed,
#' but irregular date spacing is not.
#'
#' @param dates A \code{Date} vector. Duplicate dates are allowed.
#' @return A positive integer giving the reporting interval in days.
#' @keywords internal
#' @noRd
detect_interval <- function(dates) {
  u <- sort(unique(dates))
  if (length(u) < 2L) {
    stop(
      "Need at least two distinct `target_end_date` values to determine ",
      "the reporting interval."
    )
  }
  diffs <- as.integer(diff(u))
  tab <- table(diffs)
  interval <- as.integer(names(tab)[which.max(tab)])
  if (interval <= 0L) {
    stop("Could not determine a positive reporting interval from the dates.")
  }
  irregular <- unique(diffs[diffs %% interval != 0L])
  if (length(irregular) > 0L) {
    stop(
      "Irregular reporting dates: gaps of ",
      paste(irregular, collapse = ", "),
      " days do not fit the dominant ", interval, "-day interval."
    )
  }
  interval
}


#' Extract forecast-ready series data
#'
#' Extract the data used for modelling, keeping the latest revision when'
#' revision history is available.
#' @param x An \code{incast_data} or \code{incast_ncast} object.
#' @return A data frame with one row per series per target_end_date.
#' @keywords internal
#' @noRd
extract_series <- function(x) {
  if (inherits(x, "incast_ncast") || inherits(x, "incast_data")) {
    df <- x$data
  } else {
    stop(
      "`x` must be an incast_data or incast_ncast object.\n",
      "Run check_data() on your data frame first."
    )
  }

  if ("as_of" %in% names(df)) {
    df <- df |>
      dplyr::group_by(dplyr::across(dplyr::all_of(c(x$key, "target_end_date")))) |>
      dplyr::filter(as_of == max(as_of)) |>
      dplyr::ungroup() |>
      dplyr::select(-as_of)
  }
  df
}


#' Create a modelling tsibble
#'
#' Convert forecast-ready data into a regular keyed \code{tsibble} suitable
#' for fitting \code{fable} models.
#'
#' @param df A data frame containing an \code{observation} column.
#' @param key Character vector of key column names.
#' @return A keyed \code{tsibble} indexed by \code{target_end_date}.
#' @keywords internal
#' @noRd
#' @importFrom dplyr filter select
#' @importFrom tsibble as_tsibble fill_gaps
as_model_ts <- function(df, key) {
  df |>
    dplyr::filter(!is.na(observation)) |>
    dplyr::select(dplyr::all_of(key), target_end_date, observation) |>
    tsibble::as_tsibble(index = target_end_date, key = dplyr::all_of(key)) |>
    tsibble::fill_gaps()
}


#' Truncate count distributions
#'
#' Restrict a distribution to non-negative values.
#'
#' @param dist A \code{distributional} distribution.
#' @return A truncated distribution.
#' @keywords internal
#' @noRd
#' @importFrom distributional dist_truncated
truncate_counts <- function(dist) {
  distributional::dist_truncated(dist, lower = 0, upper = Inf)
}


#' Create an equal-weight mixture distribution
#'
#' Combine multiple distributions into a single mixture with equal weights.
#'
#' @param dists A vector or list of \code{distributional} distributions.
#' @return A mixture distribution.
#' @keywords internal
#' @noRd
#' @importFrom distributional dist_mixture
mix_equally <- function(dists) {
  dists <- as.list(dists)
  n <- length(dists)
  do.call(
    distributional::dist_mixture,
    c(dists, list(weights = rep(1 / n, n)))
  )
}


#' Validate a positive numeric value
#'
#' Check that an input is a single positive number.
#'
#' @param x Value to check.
#' @param name Argument name shown in the error.
#' @param what Description of the expected value.
#' @return \code{x}, invisibly.
#' @keywords internal
#' @noRd
validate_positive_scalar <- function(x, name, what) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || x <= 0) {
    stop("`", name, "` must be a single positive number (", what, ").")
  }
  invisible(x)
}


#' Validate forecasting models
#'
#' Check that model specifications form a non-empty named list.
#'
#' @param models A named list of model specifications.
#' @return \code{models}, invisibly.
#' @keywords internal
#' @noRd
validate_models <- function(models) {
  if (!is.list(models) || length(models) == 0L) {
    stop("`models` must be a non-empty list of model definitions.")
  }
  nms <- names(models)
  if (is.null(nms) || any(!nzchar(nms)) || anyDuplicated(nms) > 0L) {
    stop(
      "`models` must be a uniquely named list; each name labels a model.\n",
      "e.g. list(ETS = fable::ETS(observation), ARIMA = fable::ARIMA(observation))"
    )
  }
  invisible(models)
}
