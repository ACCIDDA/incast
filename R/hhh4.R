#' Joint endemic-epidemic model
#'
#' `HHH4()` fits [surveillance::hhh4()] jointly to all series and returns
#' simulated forecasts for [get_cv()] and [get_fcast()].
#'
#' Model components and `control` options are documented in
#' [surveillance::hhh4()]. `incast` manages `control$subset`, so do not supply
#' it. Data must have one series key, and all unit-indexed inputs must be named
#' with its values. Fractional observations are rounded to counts before
#' fitting.
#'
#' @author Cyril Geismar
#'
#' @param formula Use `observation`. Units come from the single key supplied to
#'   [check_data()].
#' @param control A [surveillance::hhh4()] control list.
#' @param neighbourhood Optional named adjacency or neighbourhood-order matrix.
#' @param population Optional named population vector or time-by-unit matrix.
#' @param n_sim Number of joint forecast simulations. Defaults to `500`.
#'
#' @return A joint model specification for [get_cv()] or [get_fcast()].
#'
#' @examples
#' \dontrun{
#' states <- c("CT", "NY")
#' W <- matrix(
#'   c(0, 1, 1, 0),
#'   2, 2,
#'   byrow = TRUE,
#'   dimnames = list(states, states)
#' )
#' population <- c(CT = 3.6, NY = 20)
#' population <- population / sum(population)
#'
#' get_data("flu", tolower(states)) |>
#'   get_cv(
#'     h = 4,
#'     n_origins = 8,
#'     models = list(
#'       HHH4 = HHH4(
#'         observation,
#'         control = list(
#'           ar = list(f = ~1),
#'           ne = list(f = ~1, normalize = TRUE),
#'           end = list(
#'             f = surveillance::addSeason2formula(~1, S = 1, period = 52)
#'           ),
#'           family = "NegBin1"
#'         ),
#'         neighbourhood = W,
#'         population = population
#'       )
#'     )
#'   )
#' }
#'
#' @seealso `vignette("hhh4")`, [surveillance::hhh4()]
#' @export
#' @importFrom fabletools new_model_class
#' @importFrom tsibble is_regular measured_vars index_var
#' @importFrom distributional dist_sample
HHH4 <- function(
  formula,
  control,
  neighbourhood = NULL,
  population = NULL,
  n_sim = 500L
) {
  if (!requireNamespace("surveillance", quietly = TRUE)) {
    stop(
      "Package 'surveillance' is required for HHH4().\n",
      "Install it with install.packages(\"surveillance\").",
      call. = FALSE
    )
  }
  if (missing(formula)) {
    stop(
      "`formula` is required; use `HHH4(observation, ...)`.",
      call. = FALSE
    )
  }
  response <- substitute(formula)
  if (
    !is.symbol(response) || !identical(as.character(response), "observation")
  ) {
    stop(
      "`formula` must be the bare response `observation`; ",
      "the coupled units come from `check_data(key = ...)`.",
      call. = FALSE
    )
  }
  if (missing(control) || !is.list(control)) {
    stop(
      "`control` must be a list; see ?surveillance::hhh4 for its contents.",
      call. = FALSE
    )
  }
  if (!is.null(control$subset)) {
    stop(
      "`control$subset` is managed by incast and must not be supplied.",
      call. = FALSE
    )
  }
  validate_hhh4_integer(n_sim, "n_sim", minimum = 2L)

  new_joint_model(
    model_hhh4,
    control = control,
    neighbourhood = neighbourhood,
    population = population,
    n_sim = as.integer(n_sim)
  )
}


#' Validate a scalar integer used by HHH4
#' @keywords internal
#' @noRd
validate_hhh4_integer <- function(x, name, minimum = 1L) {
  if (
    !is.numeric(x) ||
      length(x) != 1L ||
      is.na(x) ||
      !is.finite(x) ||
      x != round(x) ||
      x < minimum
  ) {
    stop(
      "`",
      name,
      "` must be a single integer >= ",
      minimum,
      ".",
      call. = FALSE
    )
  }
  invisible(x)
}


#' Check names on a unit-indexed object
#' @keywords internal
#' @noRd
check_hhh4_unit_names <- function(nms, units, what) {
  if (is.null(nms) || anyNA(nms) || any(!nzchar(nms))) {
    stop(
      "`",
      what,
      "` must be named by the series key values.",
      call. = FALSE
    )
  }
  if (anyDuplicated(nms)) {
    stop("`", what, "` contains duplicated unit names.", call. = FALSE)
  }
  missing_units <- setdiff(units, nms)
  if (length(missing_units)) {
    stop(
      "`",
      what,
      "` is missing series: ",
      paste(utils::head(missing_units, 6L), collapse = ", "),
      if (length(missing_units) > 6L) ", ..." else "",
      ".",
      call. = FALSE
    )
  }
  invisible(nms)
}


#' Align a vector or matrix to the model's unit order
#' @keywords internal
#' @noRd
align_units <- function(x, units, what, square = FALSE) {
  if (is.null(x)) {
    return(NULL)
  }
  if (square && !is.matrix(x)) {
    stop("`", what, "` must be a square matrix.", call. = FALSE)
  }
  if (is.matrix(x)) {
    check_hhh4_unit_names(colnames(x), units, paste0(what, " columns"))
    if (square) {
      check_hhh4_unit_names(rownames(x), units, paste0(what, " rows"))
      return(x[units, units, drop = FALSE])
    }
    return(x[, units, drop = FALSE])
  }
  check_hhh4_unit_names(names(x), units, what)
  x[units]
}


#' Align the first two dimensions of a unit-by-unit array
#' @keywords internal
#' @noRd
align_hhh4_array <- function(x, units, what) {
  if (length(dim(x)) != 3L) {
    stop(
      "`",
      what,
      "` must be a matrix or three-dimensional array.",
      call. = FALSE
    )
  }
  dn <- dimnames(x)
  check_hhh4_unit_names(dn[[1L]], units, paste0(what, " rows"))
  check_hhh4_unit_names(dn[[2L]], units, paste0(what, " columns"))
  x[units, units, , drop = FALSE]
}


#' Select rows for an origin and carry the final row into missing future rows
#' @keywords internal
#' @noRd
hhh4_time_rows <- function(x, n, horizon, what, require_future = FALSE) {
  need <- n + horizon
  if (nrow(x) < n || (require_future && nrow(x) < need)) {
    stop(
      "`",
      what,
      "` needs at least ",
      if (require_future) need else n,
      " rows for this fit; got ",
      nrow(x),
      ".",
      call. = FALSE
    )
  }
  out <- x[seq_len(min(nrow(x), need)), , drop = FALSE]
  if (nrow(out) < need) {
    out <- rbind(
      out,
      out[rep.int(nrow(out), need - nrow(out)), , drop = FALSE]
    )
  }
  out
}


#' Select time slices for an origin and carry the final future slice
#' @keywords internal
#' @noRd
hhh4_time_slices <- function(x, n, horizon, what) {
  need <- n + horizon
  if (dim(x)[3L] < n) {
    stop(
      "`",
      what,
      "` needs at least ",
      n,
      " slices for this fit; got ",
      dim(x)[3L],
      ".",
      call. = FALSE
    )
  }
  out <- x[, , seq_len(min(dim(x)[3L], need)), drop = FALSE]
  if (dim(out)[3L] < need) {
    last <- out[, , dim(out)[3L], drop = FALSE]
    out <- array(
      c(out, rep(last, need - dim(out)[3L])),
      dim = c(dim(out)[1:2], need),
      dimnames = list(dimnames(out)[[1L]], dimnames(out)[[2L]], NULL)
    )
  }
  out
}


#' Align the unit- and time-indexed parts of an hhh4 control list
#' @keywords internal
#' @noRd
prepare_hhh4_control <- function(control, units, n, horizon) {
  for (component in c("ar", "ne", "end")) {
    item <- control[[component]]
    if (!is.null(item) && !is.list(item)) {
      stop("`control$", component, "` must be a list.", call. = FALSE)
    }
    offset <- item$offset
    if (is.matrix(offset)) {
      offset <- align_units(
        offset,
        units,
        paste0("control$", component, "$offset")
      )
      control[[component]]$offset <- hhh4_time_rows(
        offset,
        n,
        horizon,
        paste0("control$", component, "$offset")
      )
    }
  }

  ne_weights <- control$ne$weights
  if (is.matrix(ne_weights)) {
    control$ne$weights <- align_units(
      ne_weights,
      units,
      "control$ne$weights",
      square = TRUE
    )
  } else if (is.array(ne_weights) && length(dim(ne_weights)) == 3L) {
    control$ne$weights <- ne_weights |>
      align_hhh4_array(units, "control$ne$weights") |>
      hhh4_time_slices(n, horizon, "control$ne$weights")
  }

  ne_scale <- control$ne$scale
  if (is.matrix(ne_scale)) {
    control$ne$scale <- align_units(
      ne_scale,
      units,
      "control$ne$scale",
      square = TRUE
    )
  } else if (is.array(ne_scale) && length(dim(ne_scale)) == 3L) {
    control$ne$scale <- ne_scale |>
      align_hhh4_array(units, "control$ne$scale") |>
      hhh4_time_slices(n, horizon, "control$ne$scale")
  } else if (is.atomic(ne_scale) && length(ne_scale) == length(units)) {
    control$ne$scale <- align_units(ne_scale, units, "control$ne$scale")
  }

  if (is.factor(control$family) && length(control$family) > 1L) {
    control$family <- align_units(control$family, units, "control$family")
  }

  if (!is.null(control$data) && !is.list(control$data)) {
    stop("`control$data` must be a named list.", call. = FALSE)
  }
  if (length(control$data)) {
    need <- n + horizon
    data_names <- names(control$data)
    if (is.null(data_names) || any(!nzchar(data_names))) {
      stop("`control$data` must be a named list.", call. = FALSE)
    }
    control$data <- lapply(data_names, function(name) {
      value <- control$data[[name]]
      what <- paste0("control$data$", name)

      if (is.matrix(value) && nrow(value) >= n) {
        if (ncol(value) == length(units)) {
          value <- align_units(value, units, what)
        }
        return(hhh4_time_rows(
          value,
          n,
          horizon,
          what,
          require_future = TRUE
        ))
      }
      if (is.atomic(value) && is.null(dim(value)) && length(value) >= n) {
        if (length(value) < need) {
          stop(
            "`",
            what,
            "` needs ",
            need,
            " values (training history plus forecast horizon); got ",
            length(value),
            ".",
            call. = FALSE
          )
        }
        return(value[seq_len(need)])
      }
      value
    })
    names(control$data) <- data_names
  }

  control
}


#' Read and validate the epidemic component lags
#' @keywords internal
#' @noRd
hhh4_lags <- function(control) {
  get_lag <- function(component, minimum) {
    item <- control[[component]]
    if (!is.null(item) && !is.list(item)) {
      stop("`control$", component, "` must be a list.", call. = FALSE)
    }
    lag <- item$lag
    if (is.null(lag)) {
      lag <- 1L
    }
    validate_hhh4_integer(lag, paste0("control$", component, "$lag"), minimum)
    as.integer(lag)
  }
  c(ar = get_lag("ar", 1L), ne = get_lag("ne", 0L))
}


train_hhh4 <- function(
  .data,
  specials,
  control,
  neighbourhood,
  population,
  n_sim,
  horizon,
  ...
) {
  validate_hhh4_integer(horizon, "horizon")

  idx <- as.Date(.data[[tsibble::index_var(.data)]])
  units <- tsibble::measured_vars(.data)
  y <- as.matrix(.data[, units, drop = FALSE])
  colnames(y) <- units
  n <- nrow(y)
  u <- ncol(y)

  if (n < 3L) {
    stop("Need at least 3 reporting periods to fit `HHH4()`.", call. = FALSE)
  }
  if (any(!is.finite(y) & !is.na(y))) {
    stop("`HHH4()` observations must be finite or missing.", call. = FALSE)
  }
  if (any(y < 0, na.rm = TRUE)) {
    stop("`HHH4()` observations must be non-negative counts.", call. = FALSE)
  }
  y[] <- round(y)

  interval <- as.integer(idx[2L] - idx[1L])
  frequency <- max(1L, round(365.25 / interval))
  year <- as.integer(format(idx[1L], "%Y"))
  period <- floor(
    as.numeric(idx[1L] - as.Date(paste0(year, "-01-01"))) / interval
  ) +
    1L

  neighbourhood <- align_units(
    neighbourhood,
    units,
    "neighbourhood",
    square = TRUE
  )
  population <- align_units(population, units, "population")
  if (is.matrix(population)) {
    population <- hhh4_time_rows(
      population,
      n,
      horizon,
      "population"
    )
  }
  control <- prepare_hhh4_control(control, units, n, horizon)

  padded_y <- rbind(
    y,
    matrix(0, horizon, u, dimnames = list(NULL, units))
  )
  sts_obj <- surveillance::sts(
    observed = padded_y,
    start = c(year, period),
    frequency = frequency,
    neighbourhood = neighbourhood,
    population = population
  )

  if (!is.null(population) && is.null(control$end$offset)) {
    control$end$offset <- surveillance::population(sts_obj)
  }

  lags <- hhh4_lags(control)
  max_lag <- max(lags)
  if (n <= max_lag + 1L) {
    stop(
      "Need at least ",
      max_lag + 2L,
      " reporting periods for lag ",
      max_lag,
      "; got ",
      n,
      ".",
      call. = FALSE
    )
  }
  control$subset <- seq.int(max_lag + 1L, n)

  fit <- surveillance::hhh4(sts_obj, control)

  structure(
    list(
      fit = fit,
      n = n,
      units = units,
      n_sim = n_sim,
      horizon = horizon,
      max_lag = max_lag
    ),
    class = "model_hhh4"
  )
}


model_hhh4 <- fabletools::new_model_class(
  "hhh4",
  train = train_hhh4,
  specials = fabletools::new_specials(
    xreg = function(...) {
      stop(
        "`HHH4()` takes future covariates through `control$data`; ",
        "see ?HHH4.",
        call. = FALSE
      )
    }
  ),
  check = function(.data) {
    if (!tsibble::is_regular(.data)) {
      stop("Data must be a regular tsibble with no implicit gaps.")
    }
  }
)


#' Compact family label for hhh4 summaries
#' @keywords internal
#' @noRd
hhh4_family_label <- function(x) {
  family <- x$fit$control$family
  if (is.factor(family)) {
    sprintf("NegBin[%d groups]", nlevels(family))
  } else {
    as.character(family)
  }
}


#' @importFrom fabletools model_sum
#' @export
model_sum.model_hhh4 <- function(x) {
  sprintf(
    "HHH4[%d series, %s]",
    length(x$units),
    hhh4_family_label(x)
  )
}


#' @importFrom fabletools report
#' @export
report.model_hhh4 <- function(object, ...) {
  cat("\n--- Endemic-epidemic model (hhh4) ---\n\n")
  cat(sprintf("  Series      : %d\n", length(object$units)))
  cat(sprintf("  Family      : %s\n", hhh4_family_label(object)))
  cat(sprintf("  Simulations : %d\n", object$n_sim))
  cat(sprintf("  Converged   : %s\n\n", object$fit$convergence))
  cat("  Coefficients:\n")
  print(round(stats::coef(object$fit), 4L))
  invisible(object)
}


#' @importFrom fabletools tidy
#' @export
tidy.model_hhh4 <- function(x, ...) {
  coefficients <- stats::coef(x$fit)
  data.frame(
    term = names(coefficients),
    estimate = as.numeric(coefficients)
  )
}


#' @importFrom fabletools glance
#' @export
glance.model_hhh4 <- function(x, ...) {
  data.frame(
    n_series = length(x$units),
    family = hhh4_family_label(x),
    AIC = as.numeric(stats::AIC(x$fit)),
    loglik = as.numeric(stats::logLik(x$fit)),
    converged = isTRUE(x$fit$convergence)
  )
}


#' Fitted means in the original wide response shape
#' @keywords internal
#' @noRd
hhh4_fitted_matrix <- function(object) {
  fitted <- matrix(
    NA_real_,
    nrow = object$n,
    ncol = length(object$units),
    dimnames = list(NULL, object$units)
  )
  rows <- object$fit$control$subset
  fitted[rows, ] <- object$fit$fitted.values
  fitted
}


#' @importFrom stats fitted
#' @export
fitted.model_hhh4 <- function(object, ...) {
  hhh4_fitted_matrix(object)
}


#' @importFrom stats residuals
#' @export
residuals.model_hhh4 <- function(object, ...) {
  observed <- surveillance::observed(object$fit$stsObj)[
    seq_len(object$n),
    object$units,
    drop = FALSE
  ]
  observed - hhh4_fitted_matrix(object)
}


#' @importFrom fabletools forecast
#' @export
forecast.model_hhh4 <- function(object, new_data, specials = NULL, ...) {
  horizon <- NROW(new_data)
  if (horizon > object$horizon) {
    stop(
      "This HHH4 fit was prepared for at most ",
      object$horizon,
      " forecast periods; got ",
      horizon,
      ".",
      call. = FALSE
    )
  }

  observed <- surveillance::observed(object$fit$stsObj)[
    seq_len(object$n),
    object$units,
    drop = FALSE
  ]
  simulations <- stats::simulate(
    object$fit,
    nsim = object$n_sim,
    subset = seq.int(object$n + 1L, object$n + horizon),
    y.start = observed[
      seq.int(object$n - object$max_lag + 1L, object$n), ,
      drop = FALSE
    ],
    simplify = TRUE
  )
  simulations <- unclass(simulations)

  distributional::dist_sample(lapply(
    seq_len(horizon),
    function(i) {
      t(matrix(
        simulations[i, , ],
        nrow = length(object$units)
      ))
    }
  ))
}
