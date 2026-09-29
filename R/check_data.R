#' Validate surveillance data
#'
#' Validate and standardise surveillance data for nowcasting and forecasting.
#'
#' Data must contain one row per time series and reporting date (and
#' \code{as_of}, if present). All series must have the same reporting interval,
#' share the same reporting dates, and end on the same date. Series may begin
#' at different times and may contain missing reporting periods.
#'
#' @author Cyril Geismar
#'
#' @param data A data frame with `target_end_date` (`Date`), `observation`
#'   (numeric), `target` (character) and the key columns. Add `as_of` (`Date`)
#'   for revision history. An `insight.cast_data` object is returned unchanged.
#'
#' @param key Character vector naming the columns that identify a series.
#'   Defaults to `"location"`.
#'
#' @return An \code{insight.cast_data} object containing:
#' \describe{
#' \item{data}{Validated data with standardised column types.}
#' \item{key}{Names of the key columns.}
#' \item{target}{Target variable name.}
#' \item{window}{Start and end dates of the data.}
#' \item{interval}{Reporting interval in days.}
#' \item{history}{Logical indicating whether multiple revisions are available.}
#' }
#'
#' @examples
#' \dontrun{
#' x <- get_data("covid", c("ny", "ca")) |> check_data()
#' my_x <- read.csv("my_data.csv") |>
#'   check_data(key = c("location", "age_group"))
#' }
#'
#' @export
check_data <- function(data, key = "location") {
  if (
    !is.character(key) ||
      length(key) == 0L ||
      anyNA(key) ||
      any(!nzchar(key)) ||
      anyDuplicated(key)
  ) {
    stop("`key` must be a vector of unique column names.")
  }

  if (inherits(data, "insight.cast_data")) {
    if (!missing(key) && !identical(key, data$key)) {
      stop(
        "`data` is already validated with key: ",
        paste(data$key, collapse = ", ")
      )
    }
    return(data)
  }

  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.")
  }

  required <- c("target_end_date", "observation", "target", key)
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  data$target_end_date <- as.Date(data$target_end_date)
  observation <- data$observation
  data$observation <- suppressWarnings(as.numeric(as.character(observation)))
  data$target <- as.character(data$target)
  data[key] <- lapply(data[key], as.character)

  if (any(is.na(data$target_end_date))) {
    stop("`target_end_date` contains values that cannot be coerced to Date.")
  }
  if (any(!is.na(observation) & is.na(data$observation))) {
    stop("`observation` contains values that cannot be coerced to numeric.")
  }
  if (any(!is.finite(data$observation) & !is.na(data$observation))) {
    stop("`observation` must contain finite values or `NA`.")
  }
  if (anyNA(data[key]) || any(!vapply(data[key], nzchar, logical(nrow(data))))) {
    stop("Key columns must not contain missing or empty values.")
  }
  if (anyNA(data$target) || any(!nzchar(data$target))) {
    stop("`target` must not contain missing or empty values.")
  }

  target <- unique(data$target)
  if (length(target) != 1) {
    stop(
      "Data must contain exactly one target (found ",
      length(target),
      ": ",
      paste(utils::head(target, 5), collapse = ", "),
      if (length(target) > 5) ", ..." else "",
      "). Filter before calling check_data()."
    )
  }

  history <- FALSE
  if ("as_of" %in% names(data)) {
    data$as_of <- as.Date(data$as_of)
    if (anyNA(data$as_of)) {
      stop("`as_of` contains values that cannot be coerced to Date.")
    }
    history <- any(duplicated(data[c(key, "target_end_date")]))
  }

  # Prevent unkeyed groups from being aggregated downstream.
  id_cols <- c(key, "target_end_date", intersect("as_of", names(data)))
  dup <- data[duplicated(data[id_cols]), id_cols, drop = FALSE]
  if (nrow(dup) > 0) {
    stop(
      "Data has more than one row per ", paste(id_cols, collapse = " + "),
      " (e.g. ",
      paste0(id_cols, " = ", vapply(dup[1L, ], as.character, ""), collapse = ", "),
      ").\nIf a column splits the series further (e.g. age_group), add it to ",
      "`key`; otherwise aggregate before calling check_data()."
    )
  }

  by_series <- split(data$target_end_date, data[key], drop = TRUE)
  intervals <- vapply(
    names(by_series),
    function(s) {
      tryCatch(
        detect_interval(by_series[[s]]),
        error = function(e) {
          stop("Series ", s, ": ", conditionMessage(e), call. = FALSE)
        }
      )
    },
    integer(1L)
  )
  if (length(unique(intervals)) > 1) {
    usual <- as.integer(names(which.max(table(intervals))))
    odd <- intervals[intervals != usual]
    stop(
      "Series report at different intervals (days): most report every ",
      usual, " days, but ",
      paste0(
        utils::head(names(odd), 6L),
        " = ",
        utils::head(odd, 6L),
        collapse = ", "
      ),
      if (length(odd) > 6L) ", ..." else "",
      ". Resample or filter before calling check_data()."
    )
  }
  interval <- intervals[[1L]]

  # Series must use the same calendar, such as the same week-ending day.
  pooled_gaps <- as.integer(diff(sort(unique(data$target_end_date))))
  if (any(pooled_gaps %% interval != 0L)) {
    stop(
      "Series report on different dates: every series reports every ",
      interval, " days, but not on the same days ",
      "(e.g. one series on Saturdays, another on Sundays).\n",
      "Align the reporting dates before calling check_data()."
    )
  }

  # Different start dates are allowed, but forecast origins must align.
  ends <- do.call(c, lapply(by_series, max))
  if (length(unique(ends)) > 1) {
    short <- ends[ends < max(ends)]
    stop(
      "All series must end on the same date (", max(ends), "), but ",
      paste0(
        utils::head(names(short), 6L),
        " ends ",
        utils::head(short, 6L),
        collapse = ", "
      ),
      if (length(short) > 6L) ", ..." else "",
      ".\nTrim every series to a common end date before calling check_data()."
    )
  }

  window <- c(
    from = min(data$target_end_date),
    to = max(data$target_end_date)
  )

  new_insight.cast_data(
    data = data,
    key = key,
    target = target,
    window = window,
    interval = interval,
    history = history
  )
}
