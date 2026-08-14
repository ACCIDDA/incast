#' Convert a fable forecast to hubverse output tables
#'
#' Convert a \code{fable} forecast object into the two tables required by the
#' hubverse format: \code{model_out_tbl} and \code{oracle_output}.
#'
#' Series identifiers are preserved from the original tsibble and added as
#' task ID columns in the output tables alongside \code{target}.
#'
#' @author Cyril Geismar
#'
#' @param fcast A \code{fable} forecast object containing an \code{.id} origin
#' column.
#' @param ts The keyed \code{tsibble} containing observed values, used to
#' generate the oracle output.
#' @param key Character vector of key column names present in both \code{fcast}
#' and \code{ts}.
#' @param target Character string identifying the forecast target.
#' @param interval Reporting interval in days, used to define forecast origins
#' and horizons.
#' @param quantiles Numeric vector of quantiles to extract. Defaults to
#' \code{c(0.025, 0.25, 0.5, 0.75, 0.975)}.
#'
#' @return A list containing \code{model_out_tbl} and \code{oracle_output}.
#'
#' @keywords internal
#' @noRd
fable_to_hub <- function(
  fcast,
  ts,
  key,
  target,
  interval = 7L,
  quantiles = c(0.025, 0.25, 0.5, 0.75, 0.975)
) {
  model_out_tbl <- fcast |>
    dplyr::as_tibble() |>
    dplyr::mutate(
      reference_date = min(target_end_date) - interval,
      .by = c(.id, dplyr::all_of(key))
    ) |>
    dplyr::mutate(
      output_type_id = list(as.character(quantiles)),
      value = stats::quantile(observation, quantiles)
    ) |>
    tidyr::unnest(c(output_type_id, value)) |>
    dplyr::reframe(
      model_id = .model,
      reference_date,
      target = target,
      horizon = as.integer(round(
        as.numeric(difftime(target_end_date, reference_date, units = "days")) /
          interval
      )),
      dplyr::pick(dplyr::all_of(key)),
      target_end_date,
      output_type = "quantile",
      output_type_id,
      value
    )

  oracle_output <- ts |>
    dplyr::as_tibble() |>
    dplyr::filter(!is.na(observation)) |>
    dplyr::reframe(
      dplyr::pick(dplyr::all_of(key)),
      target_end_date,
      target = target,
      output_type = "quantile",
      output_type_id = NA,
      oracle_value = observation
    )

  list(model_out_tbl = model_out_tbl, oracle_output = oracle_output)
}
