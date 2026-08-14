#' Default forecasting models
#'
#' Return the models used by [get_cv()] and [get_fcast()] by default.
#'
#' The set contains naive, ETS, Theta and ARIMA models fitted to
#' `log(observation + 1)`. `fable` transforms forecasts back to the count scale.
#'
#' Extend the list to add models:
#' `c(default_models(), list(CUSTOM = fable::ARIMA(observation)))`.
#'
#' @author Cyril Geismar
#'
#' @return A named list of \code{fable} model specifications.
#'
#' @examples
#' default_models()
#'
#' @export
#' @importFrom feasts unitroot_ndiffs
default_models <- function() {
  list(
    NAIVE = fable::NAIVE(log(observation + 1)),
    ETS = fable::ETS(log(observation + 1)),
    THETA = fable::THETA(log(observation + 1)),
    ARIMA = fable::ARIMA(log(observation + 1))
  )
}
