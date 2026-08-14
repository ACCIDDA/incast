#' Cross-validate forecasting models
#'
#' Evaluate models using expanding-window time-series cross-validation.
#'
#' Forecast performance is measured using weighted interval score (WIS) and
#' interval coverage. Models are ranked separately for each series, and the
#' resulting rankings are used by \code{\link{get_fcast}}.
#'
#' @author Cyril Geismar
#'
#' @param x An `incast_data` or `incast_ncast` object.
#'
#' @param eval_start_date Date (or character string coercible to a date) giving
#'   the first forecast origin to evaluate. Must fall within the data window.
#'   All earlier observations are used as the initial training period.
#'   This argument is exclusive with \code{n_origins} and \code{origins}.
#'
#' @param h Forecast horizon in reporting intervals. Defaults to `4`.
#'
#' @param models Named list of \code{fable} or joint incast model
#'   specifications, such as \code{\link{HHH4}}. Defaults to
#'   \code{\link{default_models}}.
#'
#' @param step Reporting intervals between forecast origins. Defaults to `h`.
#'
#' @param n_origins Integer giving the number of forecast origins to evaluate,
#'   as an alternative to \code{eval_start_date}. Origins are placed so that
#'   the last forecast ends at the last observation:
#'   \code{eval_start_date = t - ((h - 1) + (n_origins - 1) * step) * interval},
#'   where \code{t} is the last observation date.
#'   This argument is exclusive with \code{eval_start_date} and \code{origins}.
#'
#' @param origins Explicit forecast origin dates. Use non-contiguous dates to
#'   evaluate corresponding weeks in previous seasons.
#'   This argument is exclusive with \code{eval_start_date} and
#'   \code{n_origins}; \code{step} is ignored.
#'
#' @return An \code{incast_cv} object containing:
#' \describe{
#'   \item{forecasts}{Forecasts for each model, series, and cross-validation origin.}
#'   \item{oracle}{Observed values used for scoring.}
#'   \item{score}{Model performance metrics, including WIS and interval coverage,
#'   for each model and series.}
#'   \item{models}{The evaluated model specifications.}
#'   \item{meta}{Cross-validation settings including dates, horizon, step,
#'   number of origins, series keys, target, and reporting interval.}
#'   \item{data}{Input data with revisions collapsed, used by
#'   \code{\link{get_fcast}}.}
#' }
#'
#' @examples
#' \dontrun{
#' cv <- get_data("covid", "ny", revisions = TRUE) |>
#'   get_ncast() |>
#'   get_cv(h = 4, n_origins = 16)
#'
#' # or give the first forecast origin directly:
#' cv <- get_data("covid", "ny", revisions = TRUE) |>
#'   get_ncast() |>
#'   get_cv(eval_start_date = "2025-01-01", h = 4)
#'
#' cv$score
#' }
#'
#' @export
#'
get_cv <- function(
  x,
  eval_start_date = NULL,
  h = 4,
  models = default_models(),
  step = h,
  n_origins = NULL,
  origins = NULL
) {
  df <- extract_series(x)
  meta <- incast_meta(x)

  explicit_origins <- !is.null(origins)
  if (sum(!vapply(
    list(eval_start_date, n_origins, origins),
    is.null,
    logical(1L)
  )) != 1L) {
    stop("Supply exactly one of `eval_start_date`, `n_origins`, or `origins`.")
  }
  validate_integer(h, "h")
  if (!explicit_origins) {
    validate_integer(step, "step")
  }
  validate_models(models)

  from <- meta$window[["from"]]
  to <- meta$window[["to"]]

  if (explicit_origins) {
    origins <- sort(unique(as.Date(origins)))
    if (length(origins) == 0L || anyNA(origins)) {
      stop("`origins` must contain valid dates.")
    }
    eval_start_date <- min(origins)
  } else if (!is.null(n_origins)) {
    validate_integer(n_origins, "n_origins")
    eval_start_date <- to - ((h - 1) + (n_origins - 1) * step) * meta$interval
    if (eval_start_date <= from) {
      stop(
        "`n_origins` = ", n_origins, " (with h = ", h, ", step = ", step,
        ") puts the first forecast origin at ", as.character(eval_start_date),
        ", on or before the start of the series (", as.character(from),
        "). Reduce `n_origins`."
      )
    }
  } else {
    eval_start_date <- as.Date(eval_start_date)
    if (length(eval_start_date) != 1L || is.na(eval_start_date)) {
      stop("`eval_start_date` must be a single date.")
    }
  }

  if (eval_start_date <= from || eval_start_date > to) {
    stop(
      "`eval_start_date` (",
      as.character(eval_start_date),
      ") must fall within the data window (",
      as.character(from),
      " to ",
      as.character(to),
      ")."
    )
  }

  ts <- as_model_ts(df, meta$key)
  last_origin <- max(ts$target_end_date) - (h - 1) * meta$interval
  if (!explicit_origins) {
    if (eval_start_date > last_origin) {
      stop(sprintf(
        "`eval_start_date` leaves too little to score: %s is the last origin with a full %d-step window.",
        last_origin,
        h
      ))
    }
    origins <- seq(
      eval_start_date,
      last_origin,
      by = step * meta$interval
    )
  } else if (any(!origins %in% unique(ts$target_end_date))) {
    stop("Every `origins` date must match a reporting date in the data.")
  }
  cv_ts <- make_cv_origins(ts, origins, h, meta$interval)

  {
    progressr::with_progress({
      fcast <- forecast_final(cv_ts, models, h)
      successful_models <- unique(as.character(fcast$.model))
      models <- models[intersect(names(models), successful_models)]

      hub <- fable_to_hub(
        fcast,
        ts,
        key = meta$key,
        target = meta$target,
        interval = meta$interval
      )

      p <- progressr::progressor(steps = 1)
      p(message = "Scoring forecasts")
      score <- hubEvals::score_model_out(
        model_out_tbl = hub$model_out_tbl,
        oracle_output = hub$oracle_output,
        metrics = c("wis", "interval_coverage_50", "interval_coverage_95"),
        relative_metrics = if (length(models) > 1) "wis",
        by = c("model_id", meta$key)
      ) |>
        dplyr::as_tibble() |>
        dplyr::arrange(dplyr::across(dplyr::all_of(meta$key)), wis)
    })

    new_incast_cv(
      forecasts = hub$model_out_tbl,
      oracle = hub$oracle_output,
      score = score,
      models = models,
      meta = list(
        eval_start_date = eval_start_date,
        h = h,
        step = if (explicit_origins) NULL else step,
        n_origins = dplyr::n_distinct(cv_ts$.id),
        key = meta$key,
        target = meta$target,
        interval = meta$interval
      ),
      data = df
    )
  } |>
    pipetime::time_pipe("get_cv")
}


#' Create expanding-window cross-validation origins
#'
#' Origins are dates spaced by \code{step * interval} days starting from
#' \code{eval_start_date}. For each origin, observations before that date are
#' used as the training data. Only origins with a complete \code{h}-step
#' evaluation period are retained.
#'
#' @param ts A keyed \code{tsibble} containing the observation series.
#' @param origins Dates of the forecast origins.
#' @param h Forecast horizon in reporting intervals.
#' @param interval Reporting interval in days.
#'
#' @return A \code{tsibble} containing the input data repeated for each origin
#' and keyed by \code{.id}.
#'
#' @keywords internal
#' @noRd
make_cv_origins <- function(ts, origins, h, interval) {
  last_origin <- max(ts$target_end_date) - (h - 1) * interval
  if (any(origins > last_origin)) {
    stop(sprintf(
      "An origin leaves too little to score: %s is the last origin with a full %d-step window.",
      last_origin,
      h
    ))
  }

  key_cols <- tsibble::key_vars(ts)
  first_origin <- min(origins)
  n_before <- dplyr::as_tibble(ts) |>
    dplyr::summarise(
      n = sum(target_end_date < first_origin & !is.na(observation)),
      .by = dplyr::all_of(key_cols)
    )
  too_new <- n_before[n_before$n < 2L, ]
  if (nrow(too_new) > 0L) {
    series <- do.call(paste, c(too_new[key_cols], sep = "/"))
    stop(
      "`eval_start_date` leaves too little training data: series ",
      paste(utils::head(series, 6L), collapse = ", "),
      if (length(series) > 6L) ", ..." else "",
      if (length(series) > 1L) " have" else " has",
      " fewer than 2 observations before ",
      first_origin,
      "."
    )
  }

  tidyr::expand_grid(.id = seq_along(origins), dplyr::as_tibble(ts)) |>
    dplyr::filter(target_end_date < origins[.id]) |>
    tsibble::as_tsibble(
      index = target_end_date,
      key = dplyr::all_of(c(tsibble::key_vars(ts), ".id"))
    )
}
