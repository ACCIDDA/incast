#' Internal joint models
#'
#' @name incast-joint
#' @keywords internal
#' @noRd
NULL


#' Create a joint model specification
#'
#' @param model A model class from \code{\link[fabletools]{new_model_class}}.
#' @param ... Arguments passed to the model's \code{train} function.
#' @return An \code{incast_joint} object.
#' @keywords internal
#' @noRd
new_joint_model <- function(model, ...) {
  structure(
    list(model = model, args = list(...)),
    class = "incast_joint"
  )
}


#' Fit and forecast joint models
#'
#' @param ts A keyed model \code{tsibble} from \code{as_model_ts}.
#' @param models A named list of \code{incast_joint} specifications.
#' @param h Forecast horizon in reporting intervals.
#' @return Forecasts in the standard long format used by \code{incast}.
#'
#' @keywords internal
#' @noRd
forecast_joint <- function(ts, models, h) {
  key <- setdiff(tsibble::key_vars(ts), ".id")

  if (length(key) != 1L) {
    stop(
      "Joint models (", paste(names(models), collapse = ", "),
      ") need a single key column, but `key` is ",
      paste(key, collapse = " + "),
      ".\nRe-run check_data() with one key column, or drop the joint model.",
      call. = FALSE
    )
  }

  df <- dplyr::as_tibble(ts)
  units <- sort(unique(df[[key]]))

  wide <- df |>
    tidyr::pivot_wider(
      names_from = dplyr::all_of(key),
      values_from = observation
    ) |>
    tsibble::as_tsibble(
      index = target_end_date,
      key = dplyr::any_of(".id")
    )

  lhs <- rlang::expr(fabletools::vars(!!!rlang::syms(units)))

  dplyr::bind_rows(lapply(names(models), function(nm) {
    spec <- models[[nm]]
    args <- spec$args
    args$horizon <- h
    defn <- rlang::inject(
      fabletools::new_model_definition(spec$model, !!lhs, !!!args)
    )
    fit_warning <- NULL
    fit <- withCallingHandlers(
      rlang::inject(
        fabletools::model(wide, !!!rlang::set_names(list(defn), nm))
      ),
      warning = function(w) {
        fit_warning <<- conditionMessage(w)
      }
    )

    # Failed fable fits become null models rather than errors.
    if (any(vapply(fit[[nm]], function(x) inherits(x$fit, "null_mdl"), logical(1L)))) {
      stop(
        "Model ", nm, " failed to fit.\n",
        if (!is.null(fit_warning)) {
          fit_warning
        } else {
          "Fix its arguments or drop the model."
        },
        call. = FALSE
      )
    }

    fc <- fabletools::forecast(fit, h = h)
    joint_to_long(fc, nm, key, units)
  }))
}


#' Convert joint draws to long format
#'
#' @param fc A \code{fable} whose distribution column holds joint draws, one
#'   matrix (draws x series) per forecast row.
#' @param nm Model name to record in \code{.model}.
#' @param key Name of the key column to rebuild.
#' @param units Series identifiers, in wide-column order.
#' @return A long tibble, one row per series and forecast date.
#' @keywords internal
#' @noRd
joint_to_long <- function(fc, nm, key, units) {
  params <- distributional::parameters(
    fc[[fabletools::distribution_var(fc)]]
  )
  if (!"x" %in% names(params)) {
    stop(
      "Joint model ", nm, " must return sample distributions containing ",
      "one draws-by-series matrix per forecast period.",
      call. = FALSE
    )
  }
  draws <- params$x

  out <- dplyr::bind_rows(lapply(seq_along(units), function(j) {
    d <- distributional::dist_sample(
      lapply(draws, function(x) as.numeric(if (is.matrix(x)) x[, j] else x))
    )
    # Match fable's response name before binding marginal distributions.
    dimnames(d) <- "observation"

    res <- dplyr::tibble(
      .model = nm,
      target_end_date = fc$target_end_date,
      observation = d
    )
    res[[key]] <- units[[j]]
    if (".id" %in% names(fc)) {
      res$.id <- fc$.id
    }
    res
  }))

  out$.mean <- mean(out$observation)
  out
}
