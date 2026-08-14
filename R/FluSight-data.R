#' Forecasts from the 2025--26 FluSight backtest
#'
#' Precomputed forecasts from every successfully fitted `incast` candidate.
#' For each state and forecast round, the candidate selected by real-time
#' cross-validation is duplicated with `model_id = "incast"`.
#'
#' @format A data frame with 52,500 rows and 9 columns:
#' \describe{
#'   \item{model_id}{Model identifier.}
#'   \item{reference_date}{Date defining the forecast round.}
#'   \item{target}{Forecast target.}
#'   \item{horizon}{Forecast horizon in weeks, from 0 through 3.}
#'   \item{location}{Two-digit US location code.}
#'   \item{target_end_date}{End date of the predicted week.}
#'   \item{output_type}{Forecast output type; always `"quantile"`.}
#'   \item{output_type_id}{Quantile probability.}
#'   \item{value}{Forecast value.}
#' }
#'
#' @source Generated with `incast` from CDC NHSN influenza hospitalization
#'   data for the 2025--26 FluSight season.
"flusight_forecasts"

#' Scores from the 2025--26 FluSight backtest
#'
#' Precomputed score summaries comparing forecasts from `incast` and selected
#' FluSight models. These data let the FluSight vignette display its results
#' without refitting the forecasting models or downloading Hub data.
#'
#' `flusight_scores` contains scores pooled across locations.
#' `flusight_scores_by_location` contains scores stratified by location.
#'
#' @format `flusight_scores` is a data frame with one row per model and these
#'   columns:
#' \describe{
#'   \item{model_id}{Model identifier.}
#'   \item{wis}{Mean weighted interval score.}
#'   \item{interval_coverage_50}{Empirical coverage of the 50 percent interval.}
#'   \item{interval_coverage_95}{Empirical coverage of the 95 percent interval.}
#'   \item{wis_relative_skill}{Pairwise relative WIS.}
#'   \item{wis_scaled_relative_skill}{Relative WIS scaled to the
#'     `FluSight-ensemble`; values below one are better.}
#'   \item{count}{Number of forecast tasks scored.}
#'   \item{model_group}{One of `"FluSight ensemble"`, `"FluSight model"`,
#'     or `"incast model"`.}
#' }
#'
#' @source Forecasts and target data from the
#'   \href{https://github.com/cdcepi/FluSight-forecast-hub/tree/v1.2.0}{
#'   FluSight Forecast Hub, version 1.2.0}.
#' @seealso [flusight_scores_by_location]
"flusight_scores"

#' Scores from the 2025--26 FluSight backtest by location
#'
#' @format A data frame with one row per model and location and these columns:
#' \describe{
#'   \item{model_id}{Model identifier.}
#'   \item{location}{Two-digit US location code.}
#'   \item{wis}{Mean weighted interval score.}
#'   \item{interval_coverage_50}{Empirical coverage of the 50 percent interval.}
#'   \item{interval_coverage_95}{Empirical coverage of the 95 percent interval.}
#'   \item{wis_relative_skill}{Pairwise relative WIS.}
#'   \item{wis_scaled_relative_skill}{Relative WIS scaled to the
#'     `FluSight-ensemble`; values below one are better.}
#'   \item{count}{Number of forecast tasks scored.}
#'   \item{model_group}{One of `"FluSight ensemble"`, `"FluSight model"`,
#'     or `"incast model"`.}
#'   \item{state}{Two-letter state abbreviation.}
#' }
#' @source Forecasts and target data from the
#'   \href{https://github.com/cdcepi/FluSight-forecast-hub/tree/v1.2.0}{
#'   FluSight Forecast Hub, version 1.2.0}.
#' @seealso [flusight_scores]
"flusight_scores_by_location"
