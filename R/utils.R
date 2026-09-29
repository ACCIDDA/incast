#' Internal helpers
#' @name insight.cast-utils
#' @keywords internal
#' @noRd
NULL


#' Detect the reporting interval in days
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


#' Extract series data, keeping the latest revision
#' @param x An \code{insightcast_data} or \code{insightcast_ncast} object.
#' @return A data frame with one row per series per target_end_date.
#' @keywords internal
#' @noRd
extract_series <- function(x) {
  if (inherits(x, "insightcast_ncast") || inherits(x, "insightcast_data")) {
    df <- x$data
  } else {
    stop(
      "`x` must be an insightcast_data or insightcast_ncast object.\n",
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


#' Create a regular modelling tsibble
#'
#' @param df A data frame containing an \code{observation} column.
#' @param key Character vector of key column names.
#' @return A keyed \code{tsibble} indexed by \code{target_end_date}.
#' @keywords internal
#' @noRd
as_model_ts <- function(df, key) {
  df |>
    dplyr::filter(!is.na(observation)) |>
    dplyr::select(dplyr::all_of(key), target_end_date, observation) |>
    tsibble::as_tsibble(index = target_end_date, key = dplyr::all_of(key)) |>
    tsibble::fill_gaps()
}


#' Restrict a distribution to non-negative values
#'
#' @param dist A \code{distributional} distribution.
#' @return A truncated distribution.
#' @keywords internal
#' @noRd
truncate_counts <- function(dist) {
  elements <- unclass(dist)
  is_sample <- vapply(elements, inherits, logical(1L), "dist_sample")

  out <- distributional::dist_truncated(dist, lower = 0, upper = Inf)
  if (any(is_sample)) {
    out[is_sample] <- distributional::dist_sample(
      lapply(elements[is_sample], function(x) pmax(x$x, 0))
    )
  }
  out
}


#' Create an equal-weight mixture distribution
#'
#' @param dists A vector or list of \code{distributional} distributions.
#' @return A mixture distribution.
#' @keywords internal
#' @noRd
mix_equally <- function(dists) {
  dists <- as.list(dists)
  n <- length(dists)
  do.call(
    distributional::dist_mixture,
    c(dists, list(weights = rep(1 / n, n)))
  )
}


#' Validate a scalar integer
#'
#' @param x Value to check.
#' @param name Argument name shown in the error.
#' @param minimum Smallest allowed value.
#' @return \code{x}, invisibly.
#' @keywords internal
#' @noRd
validate_integer <- function(x, name, minimum = 1L) {
  if (
    !is.numeric(x) ||
      length(x) != 1L ||
      is.na(x) ||
      !is.finite(x) ||
      x != round(x) ||
      x < minimum
  ) {
    expected <- if (minimum == 1L) {
      "a single positive integer"
    } else {
      paste0("a single integer >= ", minimum)
    }
    stop("`", name, "` must be ", expected, ".", call. = FALSE)
  }
  invisible(x)
}


#' Validate a positive scalar
#'
#' @inheritParams validate_integer
#' @return \code{x}, invisibly.
#' @keywords internal
#' @noRd
validate_positive_number <- function(x, name) {
  if (
    !is.numeric(x) ||
      length(x) != 1L ||
      is.na(x) ||
      !is.finite(x) ||
      x <= 0
  ) {
    stop("`", name, "` must be a single positive number.", call. = FALSE)
  }
  invisible(x)
}


#' Validate forecasting models
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
