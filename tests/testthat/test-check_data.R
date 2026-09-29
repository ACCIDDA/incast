test_that("check_data validates a single-location frame", {
  x <- check_data(make_weekly_df(n = 3))

  expect_s3_class(x, "insightcast_data")
  expect_equal(x$key, "location")
  expect_equal(x$target, "wk inc covid hosp")
  expect_equal(x$interval, 7L)
  expect_false(x$history)
  expect_equal(x$window[["from"]], as.Date("2023-01-01"))
  expect_equal(x$window[["to"]], as.Date("2023-01-15"))
})

test_that("check_data accepts composite keys", {
  df <- make_weekly_df(
    locations = c("NY", "CA"),
    age_groups = c("0-17", "18+"),
    n = 3
  )
  x <- check_data(df, key = c("location", "age_group"))

  expect_equal(x$key, c("location", "age_group"))
  expect_equal(x$interval, 7L)
})

test_that("check_data validates the key argument", {
  expect_error(check_data(make_weekly_df(n = 3), key = 1), "`key` must be")
  expect_error(check_data(make_weekly_df(n = 3), key = character()), "`key` must be")
  expect_error(check_data(make_weekly_df(n = 3), key = c("location", "location")), "unique")
  expect_error(
    check_data(make_weekly_df(n = 3), key = "age_group"),
    "Missing required columns: age_group"
  )
})

test_that("check_data returns an insightcast_data unchanged", {
  x <- check_data(make_weekly_df(n = 3))

  expect_identical(check_data(x), x)
  expect_error(check_data(x, key = "age_group"), "already validated")
})

test_that("check_data rejects non-data-frame input", {
  expect_error(check_data(123), "must be a data frame")
})

test_that("check_data reports missing columns", {
  expect_error(check_data(data.frame(a = 1:3)), "Missing required columns")
})

test_that("check_data coerces column types", {
  df <- make_weekly_df(n = 3)
  df$target_end_date <- as.character(df$target_end_date)
  df$observation <- factor(df$observation)
  df$location <- factor(df$location)

  x <- check_data(df)

  expect_s3_class(x$data$target_end_date, "Date")
  expect_type(x$data$observation, "double")
  expect_type(x$data$location, "character")
  expect_type(x$data$target, "character")
  expect_equal(x$data$observation, as.numeric(as.character(df$observation)))
})

test_that("check_data rejects invalid values", {
  df <- make_weekly_df(n = 3)
  df$observation[1] <- Inf
  expect_error(check_data(df), "finite values")

  df <- make_weekly_df(n = 3)
  df$location[1] <- NA
  expect_error(check_data(df), "Key columns")

  df <- make_weekly_df(n = 3)
  df$target[1] <- ""
  expect_error(check_data(df), "`target` must not")
})

test_that("check_data rejects dates that cannot be coerced", {
  df <- make_weekly_df(n = 3)
  df$target_end_date[1] <- NA

  expect_error(check_data(df), "cannot be coerced to Date")
})

test_that("check_data requires exactly one target", {
  df <- make_weekly_df(n = 3)
  df$target[2] <- "deaths"

  expect_error(check_data(df), "exactly one target")
})

test_that("check_data rejects irregular spacing within a series", {
  df <- make_weekly_df(n = 6)
  df$target_end_date[3] <- df$target_end_date[3] + 1

  expect_error(check_data(df), "Irregular reporting dates")
})

test_that("check_data allows gaps that are multiples of the interval", {
  df <- make_weekly_df(n = 6)
  df <- df[-3, ] # one missing week is a 14-day gap, still weekly

  expect_equal(check_data(df)$interval, 7L)
})

test_that("check_data detects revision history", {
  x <- check_data(make_weekly_df(n = 6, revisions = TRUE))

  expect_true(x$history)
  expect_s3_class(x$data$as_of, "Date")
})

test_that("history is FALSE when as_of is constant", {
  df <- make_weekly_df(n = 3)
  df$as_of <- "2023-01-15"

  expect_false(check_data(df)$history)
})

test_that("history requires revisions of the same observation", {
  df <- make_weekly_df(locations = c("NY", "CA"), n = 3)
  df$as_of <- rep(as.Date(c("2023-02-01", "2023-02-02")), each = 3)

  expect_false(check_data(df)$history)

  df$as_of[1] <- NA
  expect_error(check_data(df), "`as_of` contains")
})

test_that("check_data requires one row per series and date", {
  df <- make_weekly_df(locations = "NY", age_groups = c("young", "old"), n = 6)

  # age_group splits the series but is not in the key
  expect_error(check_data(df), "more than one row")
  expect_s3_class(
    check_data(df, key = c("location", "age_group")),
    "insightcast_data"
  )
})

test_that("check_data requires all series to report on the same dates", {
  saturdays <- make_weekly_df(locations = "NY", n = 6)
  sundays <- make_weekly_df(locations = "CA", n = 6, start = as.Date("2023-01-02"))

  expect_error(check_data(rbind(saturdays, sundays)), "different dates")
})

test_that("check_data requires all series to end on the same date", {
  df <- make_weekly_df(locations = c("NY", "CA"), n = 8)
  df <- df[!(df$location == "CA" & df$target_end_date > as.Date("2023-01-29")), ]

  expect_error(check_data(df), "CA ends 2023-01-29")
})

test_that("check_data allows series that start on different dates", {
  df <- make_weekly_df(locations = c("NY", "CA"), n = 8)
  df <- df[!(df$location == "CA" & df$target_end_date < as.Date("2023-02-01")), ]

  expect_equal(check_data(df)$interval, 7L)
})

test_that("check_data rejects and names a series at a different interval", {
  weekly <- make_weekly_df(
    locations = c("AK", "AL", "AR", "AZ", "CO", "CT", "NY"),
    n = 6
  )
  biweekly <- make_weekly_df(locations = "WY", n = 6)[c(TRUE, FALSE), ]

  expect_error(
    check_data(rbind(weekly, biweekly)),
    "different intervals.*WY = 14"
  )
})

test_that("check_data rejects and names a series with too few dates", {
  long <- make_weekly_df(locations = "NY", n = 6)
  single <- make_weekly_df(locations = "ZZ", n = 1)

  expect_error(
    check_data(rbind(long, single)),
    "Series ZZ.*at least two distinct"
  )
})
