# HHH4 depends on the Suggests-only surveillance package.
skip_if_no_hhh4 <- function() skip_if_not_installed("surveillance")

# Weekly counts simulated from a genuine endemic-epidemic process, in insight.cast's
# long input shape. `make_weekly_df()` is a noiseless sinusoid, which drives the
# negative-binomial overdispersion to zero and prevents hhh4 converging; these
# series carry both real overdispersion and real coupling between locations.
hhh4_df <- function(locations = c("CA", "NY"),
                    n = 150,
                    lambda = 0.5,
                    phi = 0.35,
                    seed = 1,
                    revisions = FALSE) {
  set.seed(seed)
  u <- length(locations)
  W <- hhh4_W(locations)
  y <- matrix(0L, n, u, dimnames = list(NULL, locations))
  y[1L, ] <- stats::rpois(u, 40)
  for (t in 2:n) {
    nu <- 40 * exp(0.8 * sin(2 * pi * t / 52))
    mu <- lambda * y[t - 1L, ] + phi * as.vector(y[t - 1L, ] %*% W) + nu
    y[t, ] <- stats::rnbinom(u, mu = pmax(mu, 0.1), size = 12)
  }
  df <- data.frame(
    target_end_date = rep(
      as.Date("2023-01-07") + 7L * (seq_len(n) - 1L),
      times = u
    ),
    location = rep(locations, each = n),
    observation = as.numeric(y),
    target = "wk inc flu hosp",
    stringsAsFactors = FALSE
  )
  if (!revisions) {
    return(df)
  }
  # Right-truncated reporting triangle, the shape get_ncast() expects.
  reported <- do.call(rbind, lapply(0:2, function(delay) {
    out <- df
    out$as_of <- out$target_end_date + 7L * delay
    out$observation <- round(out$observation * (0.7 + 0.15 * delay))
    out
  }))
  reported[reported$as_of <= max(df$target_end_date), ]
}

hhh4_W <- function(locations = c("CA", "NY")) {
  u <- length(locations)
  W <- matrix(1, u, u)
  diag(W) <- 0
  dimnames(W) <- list(locations, locations)
  W / pmax(rowSums(W), 1)
}

hhh4_spec <- function(locations = c("CA", "NY"), ne = TRUE, ...) {
  control <- list(
    ar = list(f = ~1),
    end = list(f = surveillance::addSeason2formula(~1, S = 1, period = 52)),
    family = "NegBin1"
  )
  if (ne) control$ne <- list(f = ~1)
  HHH4(
    observation,
    control = control,
    neighbourhood = hhh4_W(locations),
    population = stats::setNames(
      rep(1 / length(locations), length(locations)), locations
    ),
    ...
  )
}


hhh4_mable <- function(ts, spec, horizon = 2L) {
  key <- setdiff(tsibble::key_vars(ts), ".id")
  units <- sort(unique(dplyr::as_tibble(ts)[[key]]))
  wide <- ts |>
    dplyr::as_tibble() |>
    tidyr::pivot_wider(names_from = dplyr::all_of(key), values_from = observation) |>
    tsibble::as_tsibble(index = target_end_date)
  lhs <- rlang::expr(fabletools::vars(!!!rlang::syms(units)))
  args <- spec$args
  args$horizon <- horizon
  definition <- rlang::inject(fabletools::new_model_definition(
    spec$model, !!lhs, !!!args
  ))
  fabletools::model(wide, M = definition)
}


fit_hhh4 <- function(ts, spec, horizon = 2L) {
  hhh4_mable(ts, spec, horizon)$M[[1]]$fit
}


test_that("HHH4() returns a joint spec without touching the data", {
  skip_if_no_hhh4()
  spec <- hhh4_spec()

  expect_s3_class(spec, "insightcast_joint")
  expect_named(
    spec$args,
    c("control", "neighbourhood", "population", "n_sim")
  )
})


test_that("HHH4() rejects a user-supplied control$subset", {
  skip_if_no_hhh4()
  expect_error(
    HHH4(observation, control = list(ar = list(f = ~1), subset = 2:10)),
    "managed by insight.cast"
  )
})


test_that("HHH4() validates control and its own arguments", {
  skip_if_no_hhh4()
  expect_error(HHH4(control = list()), "formula.*required")
  expect_error(HHH4(observation ~ location, control = list()), "bare response")
  expect_error(HHH4(cases, control = list()), "bare response.*observation")
  expect_error(HHH4(observation, control = "not a list"), "must be a list")
  expect_error(hhh4_spec(n_sim = 0), "n_sim")
  expect_error(hhh4_spec(n_sim = 1), "integer >= 2")
  expect_error(hhh4_spec(n_sim = 2.5), "integer >= 2")
})


test_that("HHH4 fits jointly and forecasts through get_cv()", {
  skip_if_no_hhh4()
  cv <- hhh4_df() |>
    check_data() |>
    get_cv(h = 2, n_origins = 3, models = list(HHH4 = hhh4_spec(n_sim = 100L)))

  expect_s3_class(cv, "insightcast_cv")
  expect_setequal(cv$score$model_id, "HHH4")
  expect_setequal(cv$score$location, c("CA", "NY"))
  expect_true(all(is.finite(cv$score$wis)))
  expect_false(anyNA(cv$forecasts$value))
})


test_that("HHH4 couples any single series key, including age groups", {
  skip_if_no_hhh4()
  age_groups <- c("0-17", "18+")
  data <- hhh4_df(age_groups)
  names(data)[names(data) == "location"] <- "age_group"

  cv <- data |>
    check_data(key = "age_group") |>
    get_cv(
      h = 2,
      n_origins = 2,
      models = list(HHH4 = hhh4_spec(age_groups, n_sim = 50L))
    )

  expect_setequal(cv$score$age_group, age_groups)
  expect_false(anyNA(cv$forecasts$value))
})


test_that("joint and fable models combine in one model list", {
  skip_if_no_hhh4()
  cv <- hhh4_df() |>
    check_data() |>
    get_cv(
      h = 2,
      n_origins = 3,
      models = list(
        NAIVE = fable::NAIVE(log(observation + 1)),
        HHH4 = hhh4_spec(n_sim = 100L)
      )
    )

  expect_setequal(cv$score$model_id, c("NAIVE", "HHH4"))

  # Both routes must yield the same per-series forecast rows.
  n_rows <- table(cv$forecasts$model_id)
  expect_equal(unname(n_rows[["HHH4"]]), unname(n_rows[["NAIVE"]]))

  fc <- get_fcast(cv, top_n = 2)
  expect_s3_class(fc, "insightcast_fcast")
  expect_true("ENSEMBLE" %in% fc$hub$model_out_tbl$model_id)
  expect_false(anyNA(fc$hub$model_out_tbl$value))
})


test_that("neighbour component propagates incidence between series", {
  skip_if_no_hhh4()
  ts <- insight.cast:::as_model_ts(hhh4_df(), "location")

  fit_one <- function(ne) {
    spec <- hhh4_spec(ne = ne, n_sim = 4000L)
    fit_hhh4(ts, spec, horizon = 1L)
  }

  # Hold the fitted coefficients fixed and change only the incidence that the
  # neighbour contributes, so any movement is structural rather than refit drift.
  mean_CA <- function(m, mult) {
    m$fit$stsObj@observed[m$n, "NY"] <-
      m$fit$stsObj@observed[m$n, "NY"] * mult
    set.seed(42)
    d <- fabletools::forecast(m, new_data = data.frame(x = 1))
    mean(distributional::parameters(d)$x[[1]][, 1])
  }

  with_ne <- fit_one(TRUE)
  without_ne <- fit_one(FALSE)

  expect_gt(mean_CA(with_ne, 5) / mean_CA(with_ne, 1), 1.15)
  expect_equal(mean_CA(without_ne, 5) / mean_CA(without_ne, 1), 1, tolerance = 0.05)
})


test_that("asymmetric per-series inputs are matched by name, not position", {
  skip_if_no_hhh4()
  locations <- c("A", "M", "Z")
  ts <- insight.cast:::as_model_ts(hhh4_df(locations), "location")
  adjacency <- matrix(
    c(0, 1, 0, 0, 0, 1, 1, 0, 0),
    3,
    3,
    byrow = TRUE,
    dimnames = list(locations, locations)
  )
  population <- c(A = 0.15, M = 0.30, Z = 0.55)

  run <- function(order) {
    spec <- HHH4(
      observation,
      control = list(
        ar = list(f = ~1),
        ne = list(f = ~1),
        end = list(f = ~1),
        family = "Poisson"
      ),
      neighbourhood = adjacency[order, order],
      population = population[order],
      n_sim = 50L
    )
    set.seed(1)
    insight.cast:::forecast_joint(ts, list(HHH4 = spec), h = 2)
  }

  a <- run(locations)
  b <- run(rev(locations))
  expect_equal(a$.mean, b$.mean, tolerance = 1e-8)
})


test_that("explicit transmission weights are aligned by both dimensions", {
  skip_if_no_hhh4()
  locations <- c("Z", "A", "M")
  ts <- insight.cast:::as_model_ts(hhh4_df(locations), "location")
  neighbourhood <- hhh4_W(locations)
  weights <- matrix(
    c(0, 0.11, 0.12, 0.21, 0, 0.23, 0.31, 0.32, 0),
    3,
    3,
    byrow = TRUE,
    dimnames = list(locations, locations)
  )
  spec <- HHH4(
    observation,
    control = list(
      ar = list(f = ~1),
      ne = list(f = ~1, weights = weights),
      end = list(f = ~1),
      family = "Poisson"
    ),
    neighbourhood = neighbourhood,
    n_sim = 20L
  )

  model <- suppressWarnings(fit_hhh4(ts, spec))
  expect_identical(model$units, c("A", "M", "Z"))
  expect_equal(
    model$fit$control$ne$weights,
    weights[model$units, model$units]
  )
})


test_that("all nested unit-indexed control inputs are aligned", {
  units <- c("A", "M", "Z")
  supplied <- c("Z", "A", "M")
  base <- matrix(
    seq_len(9), 3, 3,
    dimnames = list(supplied, supplied)
  )
  weights <- array(
    rep(base, 4),
    dim = c(3, 3, 4),
    dimnames = list(supplied, supplied, NULL)
  )
  family <- factor(c("z", "a", "m"))
  names(family) <- supplied
  time_covariate <- matrix(
    seq_len(18), 6, 3,
    dimnames = list(NULL, supplied)
  )

  control <- insight.cast:::prepare_hhh4_control(
    list(
      ne = list(weights = weights, scale = c(Z = 3, A = 1, M = 2)),
      family = family,
      data = list(time_covariate = time_covariate)
    ),
    units = units,
    n = 4,
    horizon = 2
  )

  expect_equal(control$ne$weights[, , 1], base[units, units])
  expect_equal(control$ne$weights[, , 6], base[units, units])
  expect_equal(control$ne$scale, c(A = 1, M = 2, Z = 3))
  expect_identical(names(control$family), units)
  expect_equal(control$data$time_covariate, time_covariate[, units])
})


test_that("misaligned per-series inputs are rejected with a clear message", {
  skip_if_no_hhh4()

  expect_error(
    insight.cast:::align_units(c(CA = 0.5, XX = 0.5), c("CA", "NY"), "population"),
    "missing series: NY"
  )
  expect_error(
    insight.cast:::align_units(
      unname(hhh4_W()), c("CA", "NY"), "neighbourhood",
      square = TRUE
    ),
    "columns.*must be named"
  )
  bad_rows <- hhh4_W()
  rownames(bad_rows) <- NULL
  expect_error(
    insight.cast:::align_units(
      bad_rows, c("CA", "NY"), "neighbourhood",
      square = TRUE
    ),
    "rows.*must be named"
  )
  expect_equal(
    insight.cast:::align_units(c(NY = 2, CA = 1), c("CA", "NY"), "population"),
    c(CA = 1, NY = 2)
  )
  expect_null(insight.cast:::align_units(NULL, c("CA", "NY"), "population"))
})


test_that("a joint model that fails to fit stops the run", {
  skip_if_no_hhh4()
  ts <- insight.cast:::as_model_ts(hhh4_df(), "location")

  spec <- hhh4_spec()
  spec$args$population <- c(CA = 0.5, XX = 0.5)

  expect_error(
    suppressWarnings(insight.cast:::forecast_joint(ts, list(HHH4 = spec), h = 2)),
    "failed to fit"
  )
})


test_that("fractional counts are rounded, not refused", {
  skip_if_no_hhh4()
  df <- hhh4_df()
  df$observation <- df$observation + 0.65
  ts <- insight.cast:::as_model_ts(df, "location")

  # Nowcast estimates are fractional, so this must fit quietly rather than
  # error or emit a warning per observation per iteration.
  expect_no_warning(
    fc <- insight.cast:::forecast_joint(ts, list(HHH4 = hhh4_spec(n_sim = 50L)), h = 2)
  )
  expect_equal(nrow(fc), 4L)
  expect_false(anyNA(fc$.mean))
})


test_that("time-varying populations and offsets align to CV origins", {
  skip_if_no_hhh4()
  locations <- c("CA", "NY")
  n <- 100L
  data <- hhh4_df(locations, n = n)
  population <- cbind(
    NY = seq(0.65, 0.60, length.out = n),
    CA = seq(0.35, 0.40, length.out = n)
  )
  offset <- cbind(
    NY = seq(1.2, 1.1, length.out = n),
    CA = seq(0.8, 0.9, length.out = n)
  )
  spec <- HHH4(
    observation,
    control = list(
      ar = list(f = ~1),
      end = list(f = ~1, offset = offset),
      family = "Poisson"
    ),
    population = population,
    n_sim = 30L
  )

  expect_no_error(
    cv <- get_cv(
      check_data(data),
      h = 2, n_origins = 2, models = list(HHH4 = spec)
    )
  )
  expect_false(anyNA(cv$forecasts$value))
})


test_that("control$data covariates are sliced for CV and include future values", {
  skip_if_no_hhh4()
  n <- 100L
  horizon <- 2L
  data <- hhh4_df(n = n)
  holiday <- rep(c(0, 1, 0, 0), length.out = n + horizon)
  spec <- HHH4(
    observation,
    control = list(
      ar = list(f = ~1),
      end = list(f = ~ 1 + holiday),
      family = "Poisson",
      data = list(holiday = holiday)
    ),
    n_sim = 30L
  )

  expect_no_error(
    cv <- get_cv(
      check_data(data),
      h = horizon, n_origins = 2,
      models = list(HHH4 = spec)
    )
  )
  expect_no_error(fc <- get_fcast(check_data(data), models = list(HHH4 = spec), h = horizon))
  expect_false(anyNA(c(cv$forecasts$value, fc$hub$model_out_tbl$value)))

  short <- spec
  short$args$control$data$holiday <- holiday[seq_len(n)]
  expect_error(
    suppressWarnings(insight.cast:::forecast_joint(
      insight.cast:::as_model_ts(data, "location"), list(HHH4 = short),
      h = horizon
    )),
    "training history plus forecast horizon"
  )
})


test_that("HHH4 forecasts from nowcast output, whose values are fractional", {
  skip_if_no_hhh4()

  ncast <- hhh4_df(n = 120, revisions = TRUE) |>
    check_data() |>
    get_ncast()

  # get_fcast() refits from the nowcast lower/median/upper scenarios, which is
  # where fractional observations reach the model.
  cv <- get_cv(
    ncast,
    h = 2,
    n_origins = 3,
    models = list(HHH4 = hhh4_spec(n_sim = 100L))
  )
  fc <- get_fcast(cv, top_n = 1)

  expect_s3_class(fc, "insightcast_fcast")
  expect_true(fc$meta$nowcast)
  expect_false(anyNA(fc$hub$model_out_tbl$value))
})


test_that("joint models require a single key column", {
  skip_if_no_hhh4()
  df <- make_weekly_df(locations = c("CA", "NY"), age_groups = c("0-4", "5+"))
  ts <- insight.cast:::as_model_ts(df, c("location", "age_group"))

  expect_error(
    insight.cast:::forecast_joint(ts, list(HHH4 = hhh4_spec()), h = 2),
    "single key column"
  )
})


test_that("lagged epidemic components fit and forecast", {
  skip_if_no_hhh4()
  ts <- insight.cast:::as_model_ts(hhh4_df(), "location")

  # lag > 1 needs `subset` to skip more leading periods and `y.start` to carry
  # one row per lag; both were hardcoded to lag 1 at first.
  spec <- HHH4(
    observation,
    control = list(
      ar = list(f = ~1, lag = 2),
      ne = list(f = ~1, lag = 2),
      end = list(f = surveillance::addSeason2formula(~1, S = 1, period = 52)),
      family = "NegBin1"
    ),
    neighbourhood = hhh4_W(),
    n_sim = 50L
  )

  expect_no_warning(fc <- insight.cast:::forecast_joint(ts, list(HHH4 = spec), h = 3))
  expect_equal(nrow(fc), 6L)
  expect_false(anyNA(fc$.mean))
})


test_that("fitted values, residuals, and augment retain every response", {
  skip_if_no_hhh4()
  ts <- insight.cast:::as_model_ts(hhh4_df(n = 80), "location")
  mable <- hhh4_mable(ts, hhh4_spec(n_sim = 20L))
  model <- mable$M[[1]]$fit

  expect_equal(dim(stats::fitted(model)), c(80L, 2L))
  expect_equal(dim(stats::residuals(model)), c(80L, 2L))
  augmented <- fabletools::augment(mable)
  expect_true(all(c(".response", "value", ".fitted", ".resid") %in% names(augmented)))
  expect_setequal(as.character(augmented$.response), c("CA", "NY"))
})


test_that("too little history for the requested lag is refused", {
  skip_if_no_hhh4()
  spec <- HHH4(observation, control = list(ar = list(f = ~1, lag = 5)))
  ts <- insight.cast:::as_model_ts(hhh4_df(n = 6), "location")

  expect_error(
    suppressWarnings(insight.cast:::forecast_joint(ts, list(HHH4 = spec), h = 2)),
    "failed to fit"
  )
})


test_that("a fitted joint model cannot exceed its prepared horizon", {
  skip_if_no_hhh4()
  ts <- insight.cast:::as_model_ts(hhh4_df(), "location")
  model <- fit_hhh4(ts, hhh4_spec(n_sim = 20L), horizon = 2L)
  expect_error(
    fabletools::forecast(model, new_data = data.frame(x = 1:3)),
    "prepared for at most 2"
  )
})
