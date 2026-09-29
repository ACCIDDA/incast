#' @importFrom dplyr as_tibble
#' @export
dplyr::as_tibble


#' Plot-ready tibbles from pipeline objects
#'
#' The data behind each object's \code{autoplot()}, for building custom plots:
#' \describe{
#'   \item{\code{insightcast_data}}{Observed counts, one row per series and
#'     \code{target_end_date} (latest reported value per date when revisions
#'     are present).}
#'   \item{\code{insightcast_ncast}}{Weekly nowcast summary, one row per series and
#'     reporting week (\code{reference_date}): \code{median}, 50% (\code{q25},
#'     \code{q75}) and 95% (\code{lower}, \code{upper}) credible intervals,
#'     and the reported-so-far \code{observed} count.}
#'   \item{\code{insightcast_fcast}}{Forecast quantiles per model, one row per
#'     \code{model_id}, series and \code{target_end_date}: \code{median}, 50%
#'     (\code{q25}, \code{q75}) and 95% (\code{lower}, \code{upper})
#'     prediction intervals. Observed counts for context are in
#'     \code{x$hub$oracle_output}.}
#' }
#'
#' @author Cyril Geismar
#'
#' @param x An \code{insightcast_data}, \code{insightcast_ncast} or
#'   \code{insightcast_fcast} object.
#' @param ... Ignored.
#' @return A tibble.
#' @seealso \code{\link{autoplot.insightcast_data}},
#'   \code{\link{autoplot.insightcast_ncast}}, \code{\link{autoplot.insightcast_fcast}}
#' @examples
#' example_data |>
#'   check_data() |>
#'   as_tibble()
#' @export
as_tibble.insightcast_data <- function(x, ...) {
  dplyr::as_tibble(extract_series(x))
}


#' @rdname as_tibble.insightcast_data
#' @export
as_tibble.insightcast_ncast <- function(x, ...) {
  dplyr::as_tibble(x$meta$ncast_summary)
}


#' @rdname as_tibble.insightcast_data
#' @export
as_tibble.insightcast_fcast <- function(x, ...) {
  x$hub$model_out_tbl |>
    tidyr::pivot_wider(names_from = output_type_id, values_from = value) |>
    dplyr::rename(
      lower = "0.025",
      q25 = "0.25",
      median = "0.5",
      q75 = "0.75",
      upper = "0.975"
    )
}
