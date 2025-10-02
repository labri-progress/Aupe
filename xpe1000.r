library(ggplot2)
library(dplyr)
library(stringr)

v <- 16       # view size
round <- 200  # target round

# Function to read one result file
read_result <- function(f) {
  if (file.info(f)$size == 0) return(NULL)  # skip empty files
  
  df <- tryCatch(read.table(f, header = TRUE), error = function(e) NULL)
  if (is.null(df)) return(NULL)
  
  df <- df %>% filter(time == round)
  if (nrow(df) == 0) return(NULL)
  
  fname <- basename(f)
  
  if (str_detect(fname, "^bm-")) {
    parts <- str_split(fname, "-")[[1]]
    faulty <- as.numeric(parts[2])
    space <- as.numeric(parts[3])
    strat <- "bm"
  } 
  else if (str_detect(fname, "^mergebm-")) {
    parts <- str_split(fname, "-")[[1]]
    faulty <- as.numeric(parts[2])
    trusty <- as.numeric(parts[3])
    space <- as.numeric(parts[4])
    strat <- paste("mergebm", trusty, sep="-")
  } 
  else if (str_detect(fname, "^mergekvs-")) {
    parts <- str_split(fname, "-")[[1]]
    faulty <- as.numeric(parts[2])
    trusty <- as.numeric(parts[3])
    space <- NA
    strat <- paste("mergekvs", trusty, sep="-")
  } 
  else if (str_detect(fname, "^kvs-")) {
    parts <- str_split(fname, "-")[[1]]
    faulty <- as.numeric(parts[2])
    space <- 4
    strat <- "kvs"
  } 
  else if (str_detect(fname, "^bs-")) {
    parts <- str_split(fname, "-")[[1]]
    faulty <- as.numeric(parts[2])
    space <- 4
    strat <- "basalt"
  } else if (str_detect(fname, "^br-")) {
    parts <- str_split(fname, "-")[[1]]
    faulty <- as.numeric(parts[2])
    space <- 4
    strat <- "brahms"
  } else {
    return(NULL)
  }
  
  df <- df %>%
    mutate(
      strategy = strat,
      faulty = faulty,
      space = space,
      avgByzN_norm = avgByzN / v
    )
  
  return(df)
}


x_breaks_faulty <- c(0.1, 0.2, 0.3)
y_breaks <- c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)

# Load all files
files <- list.files("analysis", full.names = TRUE)
all_data <- do.call(rbind, lapply(files, read_result))
all_data <- all_data %>% filter(!is.na(space))
all_data$strat
# Plot: one plot per space value
ggplot(all_data %>% filter(!is.na(space)), 
       aes(x = faulty, y = avgByzN_norm, color = strategy, group = strategy)) + #shape = strategy, 
  geom_line(linewidth = 0.25) +
  geom_point(size = 1) +
  facet_wrap(~ space, scales = "free_y") +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray40") +  # Add y = x line
  coord_cartesian(ylim = c(0, 1)) +
  scale_x_continuous(breaks = x_breaks_faulty) +
  scale_y_continuous(breaks = y_breaks) +
  theme_minimal(base_size = 14) +
  labs(
    title = "Normalized avgByzN at round 200 per space value",
    x = "Prop. of Byz. nodes",
    y = "Prop. of Byz. samples",
    color = "Strategy"
  )
