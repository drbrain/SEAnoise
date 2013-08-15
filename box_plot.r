require(graphics)
library("DBI")
library("RPostgreSQL")

drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname="noise", user="drbrain", host="localhost")

query <- function(con, query) {
  rs <- dbSendQuery(con, query)

  data <- fetch(rs, n = -1)

  dbClearResult(rs)

  data
}

select_dates <- query(con, "
SELECT date_trunc('day', recorded_at)::date as \"date\", dBs
FROM noise_entries
WHERE station_id = 9
ORDER BY recorded_at")

png(filename="station_9.png",
    height=1000, width=2000, bg="white")

boxplot(select_dates[,2] ~ select_dates[,1], select_dates, notch=TRUE, horizontal=TRUE, xlab="dB", main="Station 9")

dev.off()

