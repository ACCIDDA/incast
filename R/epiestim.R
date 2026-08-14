specials_epiestim <- fabletools::new_specials(
  xreg = function(...) {
    stop("`EPIESTIM()` does not support exogenous regressors.")
  }
)


#' EpiEstim model for fable
#'
#' Estimate the effective reproduction number (Rt) with
#' [EpiEstim::estimate_R()] and forecast with [projections::project()].
#'
#' @author Cyril Geismar
#'
#' @param formula Response variable to model, for example
#'   \code{observation}. External predictors are not supported.
#' @param mean_si Mean serial interval in days.
#' @param std_si Standard deviation of the serial interval in days.
#' @param rt_window Length of the sliding window (in days) used to estimate Rt.
#'   Smaller values respond more quickly to recent changes, while larger values
#'   provide smoother estimates. Defaults to \code{14}.
#' @param n_sim Number of simulated forecast trajectories. Defaults to
#'   \code{100}.
#' @param R_fix_within Logical indicating whether Rt is held constant within
#'   each simulated trajectory. Recommended for short forecast horizons.
#'
#' @return A \code{fable} model specification for use with
#'   \code{\link[fabletools]{model}}.
#'
#' @examples
#' \dontrun{
#' example_data |>
#'   get_fcast(models = EPIESTIM(
#'     observation,
#'     mean_si = 4.7,
#'     std_si = 2.9,
#'     rt_window = 7
#'   ))
#' }
#'
#' @export
EPIESTIM <- function(
  formula,
  mean_si,
  std_si,
  rt_window = 14L,
  n_sim = 100L,
  R_fix_within = TRUE
) {
  validate_positive_number(mean_si, "mean_si")
  validate_positive_number(std_si, "std_si")
  validate_integer(rt_window, "rt_window")
  validate_integer(n_sim, "n_sim", minimum = 2L)
  if (!is.logical(R_fix_within) || length(R_fix_within) != 1L || is.na(R_fix_within)) {
    stop("`R_fix_within` must be `TRUE` or `FALSE`.", call. = FALSE)
  }

  for (pkg in c("EpiEstim", "projections")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(
        "Package '", pkg, "' is required for EPIESTIM().\n",
        "Install it with install.packages(\"", pkg, "\").",
        call. = FALSE
      )
    }
  }

  fabletools::new_model_definition(
    model_epiestim,
    {{ formula }},
    mean_si = mean_si,
    std_si = std_si,
    rt_window = as.integer(rt_window),
    n_sim = as.integer(n_sim),
    R_fix_within = R_fix_within
  )
}


train_epiestim <- function(
  .data,
  specials,
  mean_si,
  std_si,
  rt_window,
  n_sim,
  R_fix_within,
  ...
) {
  mv <- tsibble::measured_vars(.data)
  if (length(mv) != 1L) {
    stop("`EPIESTIM()` is a univariate model.")
  }

  counts <- .data[[mv]]
  n_obs_all <- length(counts)
  if (n_obs_all < 3L) {
    stop("Need at least 3 observations to estimate Rt.")
  }

  # Aggregation period (days) from the tsibble index.
  dates <- sort(as.Date(.data[[tsibble::index_var(.data)]]))
  dt_days <- as.integer(dates[2] - dates[1])

  # Estimate Rt on recent data only (the current transmission regime): enough
  # periods to cover rt_window plus an SI tail buffer (mean + 4 * SD). The last
  # period is kept, so projections start one period after it (horizon 1 = next
  # period); feed nowcast-corrected data if the tail is right-truncated.
  si_buffer <- as.integer(ceiling(mean_si + 4 * std_si))
  n_keep <- max(4L, ceiling((rt_window + si_buffer) / dt_days) + 2L)
  counts_recent <- utils::tail(counts, min(n_keep, n_obs_all))

  # EpiEstim EM algorithm: reconstruct daily incidence from the aggregated
  # counts, then estimate Rt on trailing rt_window-day sliding windows.
  # iter = 100L ensures convergence on the short window; capture.output keeps
  # its per-iteration logging out of the pipeline.
  invisible(utils::capture.output(
    Rt <- suppressMessages(EpiEstim::estimate_R(
      incid = counts_recent,
      dt = dt_days,
      dt_out = rt_window,
      recon_opt = "match",
      iter = 100L,
      method = "parametric_si",
      config = EpiEstim::make_config(list(mean_si = mean_si, std_si = std_si))
    ))
  ))

  # Seed projections with the EM-reconstructed daily incidence.
  daily_incid <- incidence::as.incidence(
    Rt$I,
    dates = as.Date(Rt$dates),
    interval = 1
  )

  structure(
    list(
      Rt = Rt,
      daily_incid = daily_incid,
      # Most recent window with a finite Rt (the current transmission level).
      cur_window = max(which(is.finite(Rt$R[["Mean(R)"]]))),
      mean_si = mean_si,
      std_si = std_si,
      dt_days = dt_days,
      rt_window = rt_window,
      n_sim = n_sim,
      R_fix_within = R_fix_within,
      y_name = mv,
      n_obs = n_obs_all,
      last_date = max(dates)
    ),
    class = "model_epiestim"
  )
}

model_epiestim <- fabletools::new_model_class(
  "epiestim",
  train = train_epiestim,
  specials = specials_epiestim,
  check = function(.data) {
    if (!tsibble::is_regular(.data)) {
      stop("Data must be a regular tsibble (no implicit gaps).")
    }
  }
)


epiestim_R_now <- function(x) x$Rt$R[x$cur_window, ]

#' @importFrom fabletools model_sum
#' @export
model_sum.model_epiestim <- function(x) {
  sprintf(
    "EpiEstim[si=%.2f\u00b1%.2f, w=%d, n=%d]",
    x$mean_si,
    x$std_si,
    x$rt_window,
    x$n_sim
  )
}

#' @importFrom fabletools report
#' @export
report.model_epiestim <- function(object, ...) {
  R_row <- epiestim_R_now(object)
  cat("\n--- EpiEstim + Projections Model ---\n\n")
  cat(sprintf(
    "  Serial interval : mean = %.2f days, SD = %.2f days\n",
    object$mean_si,
    object$std_si
  ))
  cat(sprintf("  Rt window       : last %d days\n", object$rt_window))
  cat(sprintf("  Simulations     : %d\n", object$n_sim))
  cat(sprintf("  R fix within    : %s\n\n", object$R_fix_within))
  cat("  Current Rt estimate:\n")
  cat(sprintf("    Median Rt : %.3f\n", R_row[["Median(R)"]]))
  cat(sprintf(
    "    95%% CrI   : [%.3f, %.3f]\n",
    R_row[["Quantile.0.025(R)"]],
    R_row[["Quantile.0.975(R)"]]
  ))
  cat(sprintf(
    "\n  Training data   : %d observations (%d-day period), last date = %s\n",
    object$n_obs,
    object$dt_days,
    format(object$last_date)
  ))
}

#' @importFrom fabletools tidy
#' @export
tidy.model_epiestim <- function(x, ...) {
  R_row <- epiestim_R_now(x)
  data.frame(
    term = c("Rt_median", "Rt_lower_95", "Rt_upper_95"),
    estimate = c(
      R_row[["Median(R)"]],
      R_row[["Quantile.0.025(R)"]],
      R_row[["Quantile.0.975(R)"]]
    )
  )
}

#' @importFrom fabletools glance
#' @export
glance.model_epiestim <- function(x, ...) {
  R_row <- epiestim_R_now(x)
  data.frame(
    mean_si = x$mean_si,
    std_si = x$std_si,
    rt_window = x$rt_window,
    n_sim = x$n_sim,
    Rt_median = R_row[["Median(R)"]],
    Rt_lower_95 = R_row[["Quantile.0.025(R)"]],
    Rt_upper_95 = R_row[["Quantile.0.975(R)"]]
  )
}

#' @importFrom stats fitted
#' @export
fitted.model_epiestim <- function(object, ...) rep(NA_real_, object$n_obs)

#' @importFrom stats residuals
#' @export
residuals.model_epiestim <- function(object, ...) rep(NA_real_, object$n_obs)

#' @importFrom fabletools forecast
#' @export
forecast.model_epiestim <- function(object, new_data, specials = NULL, ...) {
  h <- NROW(new_data)

  # Draw n_sim reproduction numbers from the posterior of the current window,
  # so the forecast carries Rt estimation uncertainty, not just simulation noise.
  R_draws <- EpiEstim::sample_posterior_R(
    object$Rt,
    n = object$n_sim,
    window = object$cur_window
  )

  proj <- projections::project(
    x = object$daily_incid,
    R = R_draws,
    si = object$Rt$si_distr[-1],
    n_sim = object$n_sim,
    R_fix_within = object$R_fix_within,
    n_days = object$dt_days * h
  )

  # Sum daily simulations into per-period totals (h periods x n_sim paths).
  proj_matrix <- as.matrix(proj)
  period_labels <- rep(seq_len(h), each = object$dt_days)
  period_proj <- t(vapply(
    seq_len(h),
    \(p) colSums(proj_matrix[period_labels == p, , drop = FALSE]),
    numeric(object$n_sim)
  ))

  distributional::dist_sample(lapply(seq_len(h), \(p) period_proj[p, ]))
}
