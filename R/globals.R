#' Global variables used in NSE functions
#' To avoid R CMD check notes about "no visible binding for global variable"
#' we declare these variables as global here.
#'
#' The urca import is not called directly: fable::ARIMA() needs it for its
#' unit-root order selection, but only suggests it. Without it every ARIMA
#' fit in default_models() silently fails.
#' @importFrom utils head
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
  # fable_to_hub / autoplot.incast_fcast
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
