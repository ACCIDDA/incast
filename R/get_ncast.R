#' Nowcast right-truncated surveillance data
#'
#' Estimate final counts for recent, incomplete weeks using
#' [baselinenowcast](https://baselinenowcast.epinowcast.org/). The last
#' `max_delay` weeks are replaced; earlier observations are unchanged.
#' Downward revisions are redistributed with
#' [baselinenowcast::preprocess_negative_values()].
#'
#' Weekly data only; other cadences are rejected (the rest of the pipeline is
#' cadence-agnostic).
#'
#' @author Cyril Geismar
#'
#' @param x An `insight.cast_data` object with revision history.
#' @param max_delay Number of recent weeks to nowcast. Defaults to `2`.
#' @param draws Number of posterior samples. Defaults to `1000`.
#' @param prop_delay Proportion of reference times used to estimate delays.
#'   Must be between 0 and 1. Defaults to `0.5`.
#' @param scale_factor Multiplier applied to `max_delay` to set the estimation
#'   window. Defaults to `3`.
#'
#' @return An \code{insight.cast_ncast} object with the shared backbone
#'   (\code{key}, \code{target}, \code{window}, \code{interval},
#'   \code{history}) plus:
#'   \describe{
#'     \item{data}{Corrected series with `ncast_lower` and `ncast_upper` 95%
#'       credible interval bounds.}
#'     \item{meta}{Nowcast settings and a per-series `ncast_summary`.}
#'   }
#'
#' @examples
#' \dontrun{
#' x <- get_data(pathogen = "covid", geo_value = "ca", revisions = TRUE)
#' ncast <- get_ncast(x)
#' autoplot(ncast)
#' }
#'
#' @export
get_ncast <- function(
  x,
  max_delay = 2,
  draws = 1000,
  prop_delay = 0.5,
  scale_factor = 3
) {
  x <- check_data(x)
  validate_integer(max_delay, "max_delay")
  validate_integer(draws, "draws", minimum = 2L)
  validate_positive_number(scale_factor, "scale_factor")
  if (
    !is.numeric(prop_delay) ||
      length(prop_delay) != 1L ||
      is.na(prop_delay) ||
      !is.finite(prop_delay) ||
      prop_delay <= 0 ||
      prop_delay >= 1
  ) {
    stop("`prop_delay` must be a single number between 0 and 1.")
  }

  if (!x$history) {
    stop(
      "Nowcasting requires revision history (multiple `as_of` dates).\n",
      "Use get_data(revisions = TRUE) or include an `as_of` column."
    )
  }
  if (x$interval != 7L) {
    stop(
      "get_ncast() currently supports weekly data only ",
      "(detected reporting interval = ",
      x$interval,
      " days).\n",
      "Aggregate the series to weekly before nowcasting, or skip the nowcast ",
      "and pass the data straight to get_cv() / get_fcast()."
    )
  }

  best_obs <- extract_series(x) |>
    dplyr::mutate(reference_date = week_floor(target_end_date))

  ncast_summary <- x$data |>
    dplyr::reframe(
      run_ncast(
        dplyr::pick(dplyr::everything()),
        max_delay, draws, prop_delay, scale_factor
      ),
      .by = dplyr::all_of(x$key)
    ) |>
    dplyr::left_join(
      dplyr::select(
        best_obs,
        dplyr::all_of(x$key),
        reference_date,
        observed = observation
      ),
      by = c(x$key, "reference_date")
    )

  data <- best_obs |>
    dplyr::left_join(
      dplyr::select(
        ncast_summary,
        dplyr::all_of(x$key),
        reference_date,
        ncast_median = median,
        ncast_lower = lower,
        ncast_upper = upper
      ),
      by = c(x$key, "reference_date")
    ) |>
    dplyr::mutate(
      corrected = !is.na(ncast_median) &
        target_end_date > max(target_end_date) - max_delay * x$interval,
      .by = dplyr::all_of(x$key)
    ) |>
    dplyr::mutate(
      observation = dplyr::if_else(corrected, ncast_median, observation),
      ncast_lower = dplyr::if_else(corrected, ncast_lower, NA_real_),
      ncast_upper = dplyr::if_else(corrected, ncast_upper, NA_real_)
    ) |>
    dplyr::select(-reference_date, -ncast_median, -corrected) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(c(x$key, "target_end_date"))))

  new_insight.cast_ncast(
    data = data,
    key = x$key,
    target = x$target,
    window = x$window,
    interval = x$interval,
    history = TRUE,
    meta = list(
      max_delay = max_delay,
      draws = draws,
      prop_delay = prop_delay,
      scale_factor = scale_factor,
      ncast_summary = ncast_summary
    )
  )
}


#' Round dates to ISO weeks
#' @keywords internal
#' @noRd
week_floor <- function(dates) {
  as.Date(cut(dates, "week"))
}


#' Nowcast one series
#'
#' @param df Revision history (`target_end_date`, `as_of`, `observation`) for
#'   a single series.
#' @inheritParams get_ncast
#' @return A tibble with one row per reference week: `median`, `lower` /
#'   `upper` (95% CrI) and `q25` / `q75`.
#' @keywords internal
#' @noRd
run_ncast <- function(df, max_delay, draws, prop_delay, scale_factor) {
  # Only a recent window is used for delay estimation.
  estimation_window <- scale_factor * max_delay * 7L # days

  rep_tri <- df |>
    build_reporting_triangle(estimation_window) |>
    baselinenowcast::as_reporting_triangle(delays_unit = "weeks") |>
    baselinenowcast::preprocess_negative_values() |>
    baselinenowcast::truncate_to_delay(max_delay = max_delay)

  baselinenowcast::baselinenowcast(
    rep_tri,
    scale_factor = scale_factor,
    prop_delay = prop_delay,
    draws = draws
  ) |>
    dplyr::summarise(
      median = stats::median(pred_count),
      lower = stats::quantile(pred_count, 0.025),
      upper = stats::quantile(pred_count, 0.975),
      q25 = stats::quantile(pred_count, 0.25),
      q75 = stats::quantile(pred_count, 0.75),
      .by = reference_date
    )
}


#' Build an incremental reporting triangle
#'
#' Convert successive revisions into new reports by week. Negative increments
#' are kept;
#' \code{baselinenowcast::preprocess_negative_values()} redistributes them.
#' @param df Revision history (`as_of`) for a single series.
#' @param estimation_window Width in days of the delay-estimation window.
#' @return A data frame of `reference_date`, `report_date`, `count`.
#' @keywords internal
#' @noRd
build_reporting_triangle <- function(df, estimation_window) {
  df |>
    dplyr::filter(target_end_date >= max(target_end_date) - estimation_window) |>
    dplyr::transmute(
      reference_date = week_floor(target_end_date),
      report_date = week_floor(as_of),
      confirm = as.integer(round(observation))
    ) |>
    dplyr::summarise(
      confirm = max(confirm, na.rm = TRUE),
      .by = c(reference_date, report_date)
    ) |>
    dplyr::arrange(reference_date, report_date) |>
    dplyr::mutate(
      count = confirm - dplyr::lag(confirm, default = 0L),
      .by = reference_date,
      .keep = "unused"
    )
}
