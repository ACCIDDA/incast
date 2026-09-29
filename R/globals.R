#' Global variables used in non-standard evaluation
#'
#' `fable::ARIMA()` needs the `urca` import for unit-root order selection.
#' @importFrom urca ur.kpss
#' @keywords internal
#' @noRd

utils::globalVariables(c(
  "observation",
  "output_type_id",
  "value",
  ".model",
  ".mean",
  ".id",
  "target_end_date",
  "issue",
  "geo_value",
  "time_value",
  "wis",
  "wis_relative_skill",
  "model_id",
  # fable_to_hub
  "reference_date",
  "horizon",
  "output_type",
  # fable_to_hub / autoplot.insight.cast_fcast
  "oracle_value",
  # package data transformations
  "target",
  # get_ncast
  "as_of",
  "confirm",
  "count",
  "ncast_median",
  "ncast_lower",
  "ncast_upper",
  "corrected",
  "pred_count",
  "report_date",
  "location",
  "lower",
  "upper",
  "q25",
  "q75",
  "median",
  "observed"
))
