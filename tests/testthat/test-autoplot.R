test_that("autoplot.insightcast_data draws one panel per series", {
  x <- check_data(make_weekly_df(locations = c("NY", "CA"), n = 10))

  p <- autoplot(x)

  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("autoplot.insightcast_cv compares models by relative WIS", {
  x <- check_data(make_weekly_df(locations = c("NY", "CA"), n = 30))
  cv <- get_cv(
    x,
    eval_start_date = "2023-05-21",
    h = 1,
    step = 4,
    models = list(
      NAIVE = fable::NAIVE(observation),
      MEAN = fable::MEAN(observation)
    )
  )

  p <- autoplot(cv)

  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
  # the relative branch marks the reference line at 1
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_contains(geoms, "GeomVline")
})

test_that("autoplot.insightcast_cv falls back to raw WIS for a single model", {
  x <- check_data(make_weekly_df(n = 30))
  cv <- get_cv(
    x,
    eval_start_date = "2023-05-21",
    h = 1,
    step = 4,
    models = list(NAIVE = fable::NAIVE(observation))
  )

  p <- autoplot(cv)

  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_false("GeomVline" %in% geoms)
})

test_that("autoplot.insightcast_fcast plots the ensemble by default", {
  x <- check_data(make_weekly_df(n = 12))
  fcast <- get_fcast(x, models = list(NAIVE = fable::NAIVE(observation)), h = 2)

  p <- autoplot(fcast)

  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
  expect_error(autoplot(fcast, model = "NOPE"), "must be one of")
})
