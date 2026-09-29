test_that("print.insightcast_data shows the shared grid", {
  x <- check_data(make_weekly_df(locations = c("NY", "CA"), n = 20))
  expect_snapshot(print(x))

  rev <- check_data(make_weekly_df(n = 6, revisions = TRUE))
  expect_snapshot(print(rev))
})

test_that("print.insightcast_ncast and a pooled forecast print consistently", {
  ncast <- get_ncast(
    check_data(make_weekly_df(locations = c("NY", "CA"), n = 8, revisions = TRUE)),
    draws = 50
  )
  expect_snapshot(print(ncast))

  fcast <- get_fcast(ncast, models = list(NAIVE = fable::NAIVE(observation)), h = 2)
  expect_snapshot(print(fcast))
})

test_that("print.insightcast_cv and print.insightcast_fcast print consistently", {
  x <- check_data(make_weekly_df(locations = c("NY", "CA"), n = 20))
  cv <- get_cv(
    x,
    eval_start_date = "2023-04-16",
    h = 1,
    step = 4,
    models = list(NAIVE = fable::NAIVE(observation), MEAN = fable::MEAN(observation))
  )
  expect_snapshot(print(cv))

  fcast <- get_fcast(cv, top_n = 1)
  expect_snapshot(print(fcast))
})
