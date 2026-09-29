test_that("get_cv rejects plain data frames", {
  expect_error(
    get_cv(data.frame(wrong_column = 1), eval_start_date = Sys.Date()),
    "insightcast_data or insightcast_ncast"
  )
})

test_that("default_models() returns the built-in fable model set", {
  m <- default_models()
  expect_type(m, "list")
  expect_named(m, c("NAIVE", "ETS", "THETA", "ARIMA"))
})

test_that("get_cv validates its parameters", {
  x <- check_data(make_weekly_df(n = 20))

  expect_error(get_cv(x, eval_start_date = "2023-03-01", h = -1), "`h`")
  expect_error(get_cv(x, eval_start_date = "2023-03-01", h = c(1, 2)), "`h`")
  expect_error(get_cv(x, eval_start_date = "2023-03-01", h = 1.5), "integer")
  expect_error(get_cv(x, eval_start_date = "2023-03-01", step = 0), "`step`")
  expect_error(get_cv(x, eval_start_date = c("2023-03-01", "2023-04-01")), "single date")
  expect_error(get_cv(x, eval_start_date = "2019-01-01"), "data window")
  expect_error(get_cv(x, eval_start_date = "2023-03-01", models = list()), "models")
})

test_that("get_cv requires exactly one origin specification", {
  x <- check_data(make_weekly_df(n = 20))

  expect_error(get_cv(x), "exactly one")
  expect_error(
    get_cv(x, eval_start_date = "2023-03-01", n_origins = 4),
    "exactly one"
  )
  expect_error(
    get_cv(
      x,
      n_origins = 4,
      origins = as.Date(c("2023-03-05", "2023-04-02"))
    ),
    "exactly one"
  )
})

test_that("get_cv supports explicit non-contiguous origins", {
  x <- check_data(make_weekly_df(n = 40))
  origins <- as.Date(c("2023-03-26", "2023-06-18"))

  cv <- get_cv(
    x,
    origins = origins,
    h = 2,
    models = list(NAIVE = fable::NAIVE(observation))
  )

  expect_equal(cv$meta$eval_start_date, min(origins))
  expect_null(cv$meta$step)
  expect_equal(cv$meta$n_origins, 2)
  expect_equal(
    sort(unique(cv$forecasts$reference_date)),
    origins - x$interval
  )
})

test_that("get_cv derives the first origin from n_origins", {
  x <- check_data(make_weekly_df(n = 30))
  models <- list(NAIVE = fable::NAIVE(observation))

  cv <- get_cv(x, h = 2, n_origins = 3, models = models)
  expect_equal(dplyr::n_distinct(cv$forecasts$reference_date), 3)
  expect_equal(cv$meta$n_origins, 3)

  # matches the equivalent explicit eval_start_date
  t <- max(x$data$target_end_date)
  start <- t - ((2 - 1) + (3 - 1) * 2) * x$interval
  expect_equal(cv$meta$eval_start_date, start)
  cv2 <- get_cv(x, eval_start_date = start, h = 2, models = models)
  expect_equal(
    unique(cv$forecasts$reference_date),
    unique(cv2$forecasts$reference_date)
  )
  # both paths record identical settings
  expect_equal(cv$meta, cv2$meta)
  expect_equal(cv2$meta$n_origins, 3)
})

test_that("get_cv validates n_origins", {
  x <- check_data(make_weekly_df(n = 20))

  expect_error(get_cv(x, n_origins = 0), "`n_origins`")
  expect_error(get_cv(x, n_origins = 50, h = 1), "Reduce `n_origins`")
})

test_that("get_cv works with a single model", {
  x <- check_data(make_weekly_df(n = 30))

  cv <- get_cv(
    x,
    eval_start_date = "2023-05-21",
    h = 1,
    step = 4,
    models = list(NAIVE = fable::NAIVE(observation))
  )

  expect_s3_class(cv, "insightcast_cv")
  expect_contains(names(cv$score), "wis")
})

test_that("get_cv warns, drops a failed model, and scores the others", {
  x <- check_data(make_weekly_df(n = 30))

  expect_warning(
    cv <- get_cv(
      x,
      eval_start_date = "2023-05-21",
      h = 1,
      step = 4,
      models = list(
        GOOD = fable::NAIVE(observation),
        BAD = fable::ARIMA(observation ~ pdq(30, 0, 0))
      )
    ),
    "Model BAD failed and was dropped"
  )

  expect_named(cv$models, "GOOD")
  expect_equal(unique(cv$forecasts$model_id), "GOOD")
  expect_equal(unique(cv$score$model_id), "GOOD")
})

test_that("get_cv errors when a series starts after eval_start_date", {
  df <- make_weekly_df(locations = c("NY", "CA"), n = 30)
  df <- df[!(df$location == "CA" & df$target_end_date < as.Date("2023-06-01")), ]

  expect_error(
    get_cv(
      check_data(df),
      eval_start_date = "2023-04-01",
      h = 1,
      models = list(NAIVE = fable::NAIVE(observation))
    ),
    "too little training data: series CA"
  )
})

test_that("get_cv errors when eval_start_date leaves nothing to score", {
  x <- check_data(make_weekly_df(n = 30))

  expect_error(
    get_cv(
      x,
      eval_start_date = max(x$data$target_end_date),
      h = 4,
      models = list(NAIVE = fable::NAIVE(observation))
    ),
    "too little to score"
  )
})

test_that("get_cv returns an insightcast_cv with the expected structure", {
  x <- check_data(make_weekly_df(n = 40))

  cv <- get_cv(
    x,
    eval_start_date = as.Date("2023-01-01") + 7 * 30,
    h = 4,
    models = list(NAIVE = fable::NAIVE(observation), MEAN = fable::MEAN(observation))
  )

  expect_s3_class(cv, "insightcast_cv")
  expect_named(cv, c("forecasts", "oracle", "score", "models", "meta", "data"))
  expect_named(cv$models, c("NAIVE", "MEAN"))
  expect_contains(names(cv$score), c("model_id", "location", "wis"))
  expect_equal(cv$meta$h, 4)
  expect_equal(cv$meta$step, 4)
  expect_equal(cv$meta$key, "location")
})

test_that("get_cv honors step when spacing origins", {
  x <- check_data(make_weekly_df(n = 30))
  models <- list(NAIVE = fable::NAIVE(observation), MEAN = fable::MEAN(observation))
  n_folds <- function(step) {
    cv <- get_cv(x, eval_start_date = "2023-05-21", h = 1, step = step, models = models)
    dplyr::n_distinct(cv$forecasts$reference_date)
  }

  # weekly data, origins from 2023-05-21 (week 21) through week 30
  expect_equal(n_folds(1), 10)
  expect_equal(n_folds(4), 3)
})

test_that("get_cv ranks models within each series", {
  x <- check_data(make_weekly_df(locations = c("NY", "CA"), n = 30))

  cv <- get_cv(
    x,
    eval_start_date = "2023-05-21",
    h = 2,
    step = 2,
    models = list(NAIVE = fable::NAIVE(observation), MEAN = fable::MEAN(observation))
  )

  # one score row per model and location, sorted by wis within location
  expect_equal(as.integer(table(cv$score$location)), c(2L, 2L))
  expect_false(is.unsorted(cv$score$wis[cv$score$location == "CA"]))
  expect_false(is.unsorted(cv$score$wis[cv$score$location == "NY"]))
})

test_that("get_cv supports composite keys", {
  df <- make_weekly_df(
    locations = c("NY", "CA"),
    age_groups = c("young", "old"),
    n = 20
  )
  x <- check_data(df, key = c("location", "age_group"))

  cv <- get_cv(
    x,
    eval_start_date = "2023-04-16",
    h = 1,
    step = 2,
    models = list(NAIVE = fable::NAIVE(observation), MEAN = fable::MEAN(observation))
  )

  expect_contains(names(cv$score), c("model_id", "location", "age_group", "wis"))
  expect_equal(nrow(cv$score), 8) # 2 models x 4 series
  expect_contains(names(cv$forecasts), c("location", "age_group"))
})
