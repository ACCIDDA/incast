specials_foundation <- fabletools::new_specials(
  xreg = function(...) {
    stop("`FOUNDATION()` does not support exogenous regressors.")
  }
)


#' Forecast with a pretrained time-series model
#'
#' \code{FOUNDATION()} provides access to large pretrained forecasting models
#' within \code{fable}. Unlike traditional statistical models, these models do
#' not require training on the supplied data. The fitting step stores the
#' observed history, and forecasts are generated directly from the pretrained
#' model.
#'
#' Forecasts are returned in the same format as other \code{fable} models,
#' allowing them to be used with functions such as \code{\link{get_cv}} and
#' \code{\link{get_fcast}}.
#'
#' The models run through Python using \code{reticulate}. On the first forecast
#' in a session, required Python dependencies and model weights are installed
#' and downloaded automatically. These are cached for subsequent forecasts.
#'
#' Available models (\code{backend}):
#' \describe{
#'   \item{\code{"chronos"}}{Amazon Chronos. Default:
#'     \code{amazon/chronos-t5-small}.}
#'   \item{\code{"timesfm"}}{Google TimesFM. Default:
#'     \code{google/timesfm-2.5-200m-pytorch}.}
#'   \item{\code{"sundial"}}{Tsinghua Sundial. Default:
#'     \code{thuml/sundial-base-128m}.}
#'   \item{\code{"moirai"}}{Salesforce Moirai. Default:
#'     \code{Salesforce/moirai-1.1-R-small}.}
#' }
#'
#' Some models provide only a limited number of quantiles, so extreme prediction
#' intervals may be approximate.
#'
#' @author Cyril Geismar
#'
#' @param formula The series to forecast, for example \code{observation}.
#'   For count data, use \code{log(observation)} if variance stabilisation is
#'   required. \code{fable} automatically back-transforms forecasts.
#'   Additional predictors are not supported.
#' @param backend Pretrained model backend to use:
#'   \code{"chronos"}, \code{"timesfm"}, \code{"sundial"}, or \code{"moirai"}.
#' @param model_id Optional Hugging Face model identifier. If \code{NULL},
#'   the default model for the selected backend is used.
#' @param device Computation device: \code{"cpu"} (default) or \code{"cuda"}.
#' @param n_samples Number of forecast samples to generate. Defaults to
#'   \code{200}.
#'
#' @return A \code{fable} model specification for use with
#'   \code{\link[fabletools]{model}}, \code{\link{get_cv}}, or
#'   \code{\link{get_fcast}}.
#'
#' @examples
#' \dontrun{
#' ncast <- get_data("covid", "ny", revisions = TRUE) |> get_ncast()
#' get_fcast(ncast, models = c(
#'   default_models(),
#'   list(
#'     CHRONOS = FOUNDATION(log(observation), "chronos"),
#'     MOIRAI  = FOUNDATION(log(observation), "moirai")
#'   )
#' ))
#' }
#'
#' @seealso \code{\link{default_models}}
#' @export
FOUNDATION <- function(
  formula,
  backend = c("chronos", "timesfm", "sundial", "moirai"),
  model_id = NULL,
  device = c("cpu", "cuda"),
  n_samples = 200L
) {
  backend <- match.arg(backend)
  device <- match.arg(device)
  spec <- foundation_backend(backend)
  if (is.null(model_id)) {
    model_id <- spec$default_model
  }
  validate_integer(n_samples, "n_samples", minimum = 2L)

  # Declare this backend's Python deps now, before any forecast starts the Python
  # session, so a run mixing backends resolves one environment that satisfies all
  # of them (e.g. sundial's transformers pin is set before chronos imports it).
  ensure_reticulate()
  reticulate::py_require(spec$deps)

  model_foundation <- fabletools::new_model_class(
    "foundation",
    train = train_foundation,
    specials = specials_foundation,
    check = function(.data) {
      if (!tsibble::is_regular(.data)) {
        stop("Data must be a regular tsibble (no implicit gaps).")
      }
    }
  )

  fabletools::new_model_definition(
    model_foundation,
    {{ formula }},
    backend = backend,
    model_id = model_id,
    device = device,
    n_samples = as.integer(n_samples)
  )
}


train_foundation <- function(
  .data,
  specials,
  backend,
  model_id,
  device,
  n_samples,
  ...
) {
  mv <- tsibble::measured_vars(.data)
  if (length(mv) != 1L) {
    stop("`FOUNDATION()` is a univariate model.")
  }

  # Zero-shot: keep the history as context; the pretrained model is only called
  # at forecast time (see forecast.model_foundation).
  y <- as.numeric(.data[[mv]])
  if (sum(!is.na(y)) < 2L) {
    stop(
      "Need at least 2 non-missing observations to forecast with FOUNDATION()."
    )
  }

  structure(
    list(
      context = y,
      backend = backend,
      model_id = model_id,
      device = device,
      n_samples = n_samples,
      n_obs = length(y)
    ),
    class = "model_foundation"
  )
}


#' @importFrom fabletools model_sum
#' @export
model_sum.model_foundation <- function(x) {
  sprintf("%s[%s]", toupper(x$backend), basename(x$model_id))
}

#' @importFrom fabletools report
#' @export
report.model_foundation <- function(object, ...) {
  cat("\n--- Foundation model (zero-shot) ---\n\n")
  cat(sprintf("  Backend      : %s\n", object$backend))
  cat(sprintf("  Model id     : %s\n", object$model_id))
  cat(sprintf("  Device       : %s\n", object$device))
  cat(sprintf("  Draws        : %d\n", object$n_samples))
  cat(sprintf("  Context      : %d observations\n\n", object$n_obs))
  invisible(object)
}

#' @importFrom fabletools glance
#' @export
glance.model_foundation <- function(x, ...) {
  data.frame(
    backend = x$backend,
    model_id = x$model_id,
    device = x$device,
    n_samples = x$n_samples,
    n_obs = x$n_obs
  )
}

#' @importFrom stats fitted
#' @export
fitted.model_foundation <- function(object, ...) rep(NA_real_, object$n_obs)

#' @importFrom stats residuals
#' @export
residuals.model_foundation <- function(object, ...) rep(NA_real_, object$n_obs)

#' @importFrom fabletools forecast
#' @export
forecast.model_foundation <- function(object, new_data, specials = NULL, ...) {
  h <- NROW(new_data)

  paths <- foundation_sample_paths(
    backend = object$backend,
    context = object$context,
    h = h,
    model_id = object$model_id,
    device = object$device,
    n_samples = object$n_samples
  )

  # Draws as a sample distribution: flows through the package's truncation,
  # mixture and WIS scoring, and fable back-transforms them (e.g. inverts log()).
  distributional::dist_sample(lapply(seq_len(h), function(i) paths[i, ]))
}
