test_that("get_data validates pathogen argument", {
  expect_error(
    get_data(pathogen = "invalid"),
    "'arg' should be one of"
  )
})

test_that("get_data validates revisions", {
  expect_error(
    get_data(pathogen = "flu", geo_value = "ny", revisions = NA),
    "`revisions` must be"
  )
})
