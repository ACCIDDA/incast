# print.insightcast_data shows the shared grid

    Code
      print(x)
    Output
      <insightcast_data>
      Target:   wk inc covid hosp
      Series:   2 (location)
      Window:   2023-01-01 to 2023-05-14 (7-day interval)

---

    Code
      print(rev)
    Output
      <insightcast_data>
      Target:   wk inc covid hosp
      Series:   1 (location)
      Window:   2023-01-01 to 2023-02-05 (7-day interval)
      History:  2023-01-01 to 2023-02-05

# print.insightcast_ncast and a pooled forecast print consistently

    Code
      print(ncast)
    Output
      <insightcast_ncast>
      Target:   wk inc covid hosp
      Series:   2 (location)
      Window:   2023-01-01 to 2023-02-19 (7-day interval)
      Nowcast:  2023-02-12 to 2023-02-19

---

    Code
      print(fcast)
    Output
      <insightcast_fcast>
      Target:   wk inc covid hosp
      Series:   2 (location)
      Forecast: 2023-02-26 to 2023-03-05 (h = 2)
      Models:   1 + ENSEMBLE

# print.insightcast_cv and print.insightcast_fcast print consistently

    Code
      print(cv)
    Output
      <insightcast_cv>
      Target:   wk inc covid hosp
      Series:   2 (location)
      Window:   2023-01-01 to 2023-05-14 (7-day interval)
      CV:       2 models x 2 origins (h = 1)

---

    Code
      print(fcast)
    Output
      <insightcast_fcast>
      Target:   wk inc covid hosp
      Series:   2 (location)
      Forecast: 2023-05-21 to 2023-05-21 (h = 1)
      Models:   2 + ENSEMBLE

