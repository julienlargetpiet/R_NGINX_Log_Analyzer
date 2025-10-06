library(dplyr)
library(lubridate)
library(ggplot2)
library(optparse)
library(readr)

option_list <- list(
  make_option(c("-f", "--file"), type="character", default="access.log",
              help="input log file", metavar="FILE"),
  make_option(c("-s", "--start"), 
              type="character", default="01/Sep/1970:00",
              help="starting analysis time", metavar="STRT"),
  make_option(c("-e", "--ending"), type="character", 
              default="01/Sep/2970:00",
              help="ending analysis time", metavar="END"),
  make_option(c("-l", "--last"), type="numeric", 
              default=0,
              help="last days analysis time", metavar="END"),
  make_option(c("-p", "--pages"), type="character", default=".",
              help="pages", metavar="PAGES"),
  make_option(c("-o", "--outfile"), type="character", default="out.pdf",
              help="outfile", metavar="OUTFILE"),
  make_option(c("-m", "--most"), type="logical", default=FALSE,
              help="most visited webpages", metavar="MOST"),
  make_option(c("-i", "--interval"), type="character", default="h",
              help="interval time: h (hour), d (day), w (week), m (month), y (year)", metavar="INTERVAL")
)

opt <- parse_args(OptionParser(option_list=option_list))


pdf(opt$outfile)
Sys.setlocale("LC_TIME", "C")

excluded_ips = c("86.242.190.96")

df <- read_delim(
  opt$file,
  delim = " ",
  quote = '"',
  col_names = FALSE,
  trim_ws = TRUE,
  col_types = cols(
    .default = col_character(),
    X7 = col_double(),
    X8 = col_double()
  )
)

# We filter bots here

bot_keywords <- c(
  "bot","spider","crawler","curl","wget","python","scrapy",
  "ahrefs","ahrefsbot","semrush","mj12","dotbot",
  "googlebot","bingbot","yandex","uptime","pingdom","monitor",
  "facebookexternalhit","slurp","baiduspider"
)

bot_pat <- paste(bot_keywords, collapse = "|")

df <- df %>%
  filter(!grepl(bot_pat, .[[10]]))

########

df <- df[, c(1, 4, 6)]
names(df) <- c("ip",
                  "date",
                  "target")

df <- df[!df$ip %in% excluded_ips, ]
df$date <- as.POSIXct(substring(df$date, 2), format="%d/%b/%Y:%H:%M:%S")

mult_map <- c(h = 3600, 
              d = 24 * 3600, 
              w = 7 * 24 * 3600, 
              m = 30 * 24 * 3600, 
              y = 365 * 24 * 3600)
last <- opt$last * mult_map[[opt$interval]]
start <- as.POSIXct(opt$start, format="%d/%b/%Y:%H")
end <- as.POSIXct(opt$ending, format="%d/%b/%Y:%H")

if (opt$last == 0) {
    df <- df[df$date >= start & df$date <= end, ]
} else {
    df <- df[df$date >= (max(df$date) - last) & df$date <= end, ]
}

df$target <- mapply(function(x) { 
                            posvec <- gregexpr(" ", x)[[1]][1:2]
                            substring(x, posvec[1] + 1, posvec[2] - 1)}, 
                            df$target)

if (opt$most) {
  
  agg <- df %>%
    group_by(target) %>%
    summarise(hits = n(), .groups = "drop") %>%
    arrange(desc(hits)) %>%
    head(5)

  ggplot(agg, aes(x = "", y = hits, fill = target)) +
  geom_bar(stat = "identity", width = 1) +
  coord_polar(theta = "y") +
  theme_void() +
  labs(
    title = "Most visited targets",
    fill = "Target Group"
  ) +
  geom_text(
    aes(label = paste0(round(100 * hits / sum(hits), 1), "%")),
    position = position_stack(vjust = 0.5)
  )
}

patterns <- strsplit(opt$pages, "--")[[1]]
df <- df[Reduce(`|`, lapply(patterns, function(p) grepl(p, df$target))), ]

interval_map <- c(h = "hour", d = "day", w = "week", m = "month", y = "year")
interval <- interval_map[[opt$interval]]
df$date <- floor_date(df$date, unit = interval)

df$target_group <- df$target
for (ptrn in patterns) { 
    df$target_group <- ifelse(grepl(ptrn, df$target_group),
                          ptrn,
                          df$target_group)
}

agg <- df %>%
  group_by(target_group, date) %>%
  summarise(hits = n(), .groups = "drop")

ggplot(agg, aes(x = date, y = hits, color = target_group)) +
  geom_line() +
  geom_point() +
  labs(x = "Date",
       y = "Number of requests",
       title = "Traffic by URL") +
  theme_minimal() 





