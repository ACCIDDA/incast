test_that("get_fcast rejects plain data frames", {
  expect_error(
    get_fcast(data.frame(wrong_column = 1)),
    "insightcast_cv, insightcast_data or insightcast_ncast"
  )
})

test_that("get_fcast validates h", {
  x <- check_data(make_weekly_df(n = 10))

  expect_error(get_fcast(x, h = -1), "`h` must be")
  expect_error(get_fcast(x, h = c(1, 2)), "`h` must be")
  expect_error(get_fcast(x, h = 1.5), "positive integer")
})

test_that("get_fcast builds one flat hub with an ensemble, without cross-validation", {
  x <- check_data(make_weekly_df(locations = c("NY", "CA"), n = 20))

  fcast <- get_fcast(
    x,
    models = list(
      NAIVE = fable::NAIVE(observation),
      DRIFT = fable::RW(observation ~ drift())
    ),
    h = 2
  )

  expect_s3_class(fcast, "insightcast_fcast")
  expect_null(fcast$score)
  expect_equal(fcast$meta$models, c("NAIVE", "DRIFT"))
  expect_false(fcast$meta$nowcast)

  out <- fcast$hub$model_out_tbl
  expect_s3_class(out, "data.frame")
  expect_setequal(unique(out$location), c("NY", "CA"))
  expect_setequal(unique(out$model_id), c("NAIVE", "DRIFT", "ENSEMBLE"))
  expect_true(all(is.finite(out$value)))
  # 2 locations x 3 models x 2 horizons x 5 quantiles
  expect_equal(nrow(out), 60)
})

test_that("get_fcast quantile_average takes the median of the models' quantiles", {
  x <- check_data(make_weekly_df(locations = c("NY", "CA"), n = 20))

  fcast <- get_fcast(
    x,
    models = list(
      NAIVE = fable::NAIVE(observation),
      DRIFT = fable::RW(observation ~ drift())
    ),
    h = 2,
    ensemble = "quantile_average"
  )

  expect_equal(fcast$meta$ensemble, "quantile_average")
  out <- fcast$hub$model_out_tbl
  expect_setequal(unique(out$model_id), c("NAIVE", "DRIFT", "ENSEMBLE"))
  # Same shape as the linear pool: 2 locations x 3 models x 2 horizons x 5 quantiles
  expect_equal(nrow(out), 60)
  expect_false(anyNA(out))

  # The ENSEMBLE value at each quantile level is the median across models.
  by_cols <- c("location", "target_end_date", "output_type_id")
  expected <- out |>
    dplyr::filter(model_id != "ENSEMBLE") |>
    dplyr::summarise(value = stats::median(value), .by = dplyr::all_of(by_cols)) |>
    dplyr::arrange(dplyr::pick(dplyr::all_of(by_cols)))
  ens <- out |>
    dplyr::filter(model_id == "ENSEMBLE") |>
    dplyr::arrange(dplyr::pick(dplyr::all_of(by_cols)))
  expect_equal(ens$value, expected$value)
})

test_that("get_fcast rejects unknown ensemble methods", {
  x <- check_data(make_weekly_df(n = 10))
  expect_error(get_fcast(x, ensemble = "stacking"), "should be one of")
})

test_that("get_fcast retains all models and ensembles each series' top_n", {
  dates <- seq(as.Date("2023-01-01"), by = "week", length.out = 30)
  df <- rbind(
    # strong trend: NAIVE clearly beats MEAN
    data.frame(
      target_end_date = dates,
      observation = seq(100, by = 10, length.out = 30),
      location = "TREND",
      target = "cases"
    ),
    # flat alternation around 100: MEAN clearly beats NAIVE
    data.frame(
      target_end_date = dates,
      observation = rep(c(99, 101), 15),
      location = "FLAT",
      target = "cases"
    )
  )
  cv <- get_cv(
    check_data(df),
    eval_start_date = "2023-05-21",
    h = 1,
    step = 1,
    models = list(NAIVE = fable::NAIVE(observation), MEAN = fable::MEAN(observation))
  )
  top1 <- cv$score |>
    dplyr::slice_min(wis, n = 1, by = location, with_ties = FALSE)
  expect_setequal(top1$model_id, c("NAIVE", "MEAN")) # the series disagree

  fcast <- get_fcast(cv, top_n = 1)

  out <- fcast$hub$model_out_tbl
  for (loc in c("TREND", "FLAT")) {
    expect_setequal(
      setdiff(unique(out$model_id[out$location == loc]), "ENSEMBLE"),
      c("NAIVE", "MEAN")
    )

    selected <- out |>
      dplyr::filter(
        location == loc,
        model_id == top1$model_id[top1$location == loc]
      ) |>
      dplyr::arrange(target_end_date, output_type_id)
    ensemble <- out |>
      dplyr::filter(location == loc, model_id == "ENSEMBLE") |>
      dplyr::arrange(target_end_date, output_type_id)
    expect_equal(
      ensemble$value,
      selected$value,
      tolerance = 1e-6
    )
  }
  expect_equal(fcast$meta$top_n, 1)
  # meta$selection records which model each series uses
  expect_equal(
    fcast$meta$selection,
    dplyr::select(top1, location, model_id)
  )
})

test_that("quantile_average retains all models but uses the cv selection", {
  x <- check_data(make_weekly_df(n = 30))
  cv <- get_cv(
    x,
    eval_start_date = "2023-05-21",
    h = 1,
    models = list(
      NAIVE = fable::NAIVE(observation),
      MEAN = fable::MEAN(observation)
    )
  )
  selected_model <- cv$score |>
    dplyr::slice_min(wis, n = 1, with_ties = FALSE) |>
    dplyr::pull(model_id)

  out <- get_fcast(
    cv,
    top_n = 1,
    ensemble = "quantile_average"
  )$hub$model_out_tbl

  expect_setequal(unique(out$model_id), c("NAIVE", "MEAN", "ENSEMBLE"))
  selected <- out |>
    dplyr::filter(model_id == selected_model) |>
    dplyr::arrange(target_end_date, output_type_id)
  ensemble <- out |>
    dplyr::filter(model_id == "ENSEMBLE") |>
    dplyr::arrange(target_end_date, output_type_id)
  expect_equal(ensemble$value, selected$value)
})

test_that("get_fcast uses explicit models over the cv ranking when supplied", {
  x <- check_data(make_weekly_df(locations = c("NY", "CA"), n = 30))
  cv <- get_cv(
    x,
    eval_start_date = "2023-05-21",
    h = 1,
    step = 2,
    models = list(NAIVE = fable::NAIVE(observation), MEAN = fable::MEAN(observation))
  )

  # The CV evaluated NAIVE/MEAN; forecast with a different set that includes a
  # model (DRIFT) the CV never saw.
  fcast <- get_fcast(
    cv,
    h = 2,
    models = list(
      MEAN = fable::MEAN(observation),
      DRIFT = fable::RW(observation ~ drift())
    )
  )

  expect_setequal(
    unique(fcast$hub$model_out_tbl$model_id),
    c("MEAN", "DRIFT", "ENSEMBLE")
  )
  expect_equal(fcast$meta$models, c("MEAN", "DRIFT"))
  expect_null(fcast$meta$top_n) # no ranking was applied
  expect_null(fcast$meta$selection) # every series uses every model
  expect_false(is.null(fcast$score)) # the cross-validation ranking is retained
})

test_that("get_fcast reuses the cv horizon when h is unset", {
  x <- check_data(make_weekly_df(n = 30))
  cv <- get_cv(
    x,
    eval_start_date = "2023-05-21",
    h = 2,
    step = 2,
    models = list(NAIVE = fable::NAIVE(observation), MEAN = fable::MEAN(observation))
  )

  fcast <- get_fcast(cv, top_n = 1)

  expect_equal(fcast$meta$h, 2)
  expect_setequal(unique(fcast$hub$model_out_tbl$horizon), 1:2)
})

test_that("get_fcast pools nowcast uncertainty from an insightcast_ncast", {
  x <- check_data(make_weekly_df(n = 12, revisions = TRUE))
  ncast <- get_ncast(x, draws = 50)

  fcast <- get_fcast(ncast, models = list(NAIVE = fable::NAIVE(observation)), h = 2)

  expect_true(fcast$meta$nowcast)
  out <- fcast$hub$model_out_tbl
  expect_setequal(unique(out$model_id), c("NAIVE", "ENSEMBLE"))
  expect_true(all(is.finite(out$value)))
})

test_that("get_fcast names a model that fails to fit", {
  x <- check_data(make_weekly_df(n = 10))

  expect_error(
    suppressWarnings(
      get_fcast(
        x,
        models = list(BAD = fable::ARIMA(observation ~ pdq(8, 0, 0))),
        h = 1
      )
    ),
    "Model BAD failed to fit"
  )
})

test_that("get_fcast warns and continues when one model fails", {
  x <- check_data(make_weekly_df(n = 20))

  expect_warning(
    fcast <- get_fcast(
      x,
      models = list(
        GOOD = fable::NAIVE(observation),
        BAD = fable::ARIMA(observation ~ pdq(30, 0, 0))
      ),
      h = 1
    ),
    "Model BAD failed and was dropped"
  )

  expect_setequal(
    unique(fcast$hub$model_out_tbl$model_id),
    c("GOOD", "ENSEMBLE")
  )
  expect_equal(fcast$meta$models, "GOOD")
})

test_that("get_fcast runs the default models end-to-end", {
  x <- check_data(make_weekly_df(n = 30))

  fcast <- get_fcast(x, h = 1)

  expect_setequal(
    unique(fcast$hub$model_out_tbl$model_id),
    c(names(default_models()), "ENSEMBLE")
  )
})

test_that("get_fcast supports composite keys", {
  df <- make_weekly_df(
    locations = c("NY", "CA"),
    age_groups = c("young", "old"),
    n = 10
  )
  x <- check_data(df, key = c("location", "age_group"))

  fcast <- get_fcast(x, models = list(NAIVE = fable::NAIVE(observation)), h = 1)

  out <- fcast$hub$model_out_tbl
  expect_contains(names(out), c("location", "age_group"))
  expect_equal(nrow(unique(out[c("location", "age_group")])), 4L)
  expect_equal(fcast$meta$key, c("location", "age_group"))
})
