#' Fetch hospitalisation data
#'
#' Fetch confirmed US hospital admissions for COVID-19, influenza or RSV from
#' NHSN through [epidatr::pub_covidcast()].
#'
#' @author Cyril Geismar
#'
#' @param pathogen One of `"covid"`, `"flu"` or `"rsv"`.
#' @param geo_value Geographic values accepted by [epidatr::pub_covidcast()].
#' @param revisions Fetch revision history for [get_ncast()]. Defaults to
#'   `FALSE`.
#'
#' @return An \code{incast_data} object (see \code{\link{check_data}}).
#'
#' @export
#' @examples
#' \dontrun{
#' get_data(pathogen = "covid", geo_value = "ny")
#'
#' get_data(pathogen = "covid", geo_value = "ca", revisions = TRUE)
#' }
get_data <- function(pathogen, geo_value, revisions = FALSE) {
  pathogen <- match.arg(pathogen, choices = c("covid", "flu", "rsv"))
  if (!is.logical(revisions) || length(revisions) != 1L || is.na(revisions)) {
    stop("`revisions` must be `TRUE` or `FALSE`.")
  }

  signal_map <- c(
    covid = "confirmed_admissions_covid_ew",
    flu = "confirmed_admissions_flu_ew",
    rsv = "confirmed_admissions_rsv_ew"
  )

  raw <- epidatr::pub_covidcast(
    source = "nhsn",
    signals = signal_map[pathogen],
    geo_type = "state",
    time_type = "week",
    geo_values = geo_value,
    issues = if (revisions) "*" else NULL
  ) |>
    dplyr::transmute(
      as_of = issue,
      location = toupper(geo_value),
      target = paste0("wk inc ", pathogen, " hosp"),
      target_end_date = time_value + 6,
      observation = value
    )

  check_data(raw)
}
