#' Weekly influenza hospital admissions for New York and California
#'
#' Weekly confirmed influenza hospital admissions for New York and California,
#' with revision history, fetched from CDC NHSN through [get_data()].
#'
#' The archive is pinned to 14 December 2025 so the latest weeks remain
#' incomplete. Pass it to [check_data()] before use. Regenerate it with
#' `data-raw/example_data.R`.
#'
#' @format A data frame with 5 columns:
#' \describe{
#'   \item{as_of}{Date the observation was reported.}
#'   \item{location}{State abbreviation (\code{"NY"} or \code{"CA"}).}

#'   \item{target}{Forecast target (\code{"wk inc flu hosp"}).}
#'   \item{target_end_date}{End date of the epidemiological week.}
#'   \item{observation}{Confirmed hospital admissions count.}
#' }
#'
#' @source CDC NHSN via \code{\link[epidatr]{pub_covidcast}}.
#'
#' @examples
#' example_data |> check_data()
"example_data"
