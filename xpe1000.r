library(ggplot2)
library(dplyr)
library(tidyr)
library(stringr)

# Parametersy
n <- 1000
v <- 16
round <- 200

# List all result files
files <- list.files("analysis", full.names = TRUE, recursive = FALSE)
#files
# Function to read one file and extract data
read_result <- function(f) {
  # read table (assuming space- or tab-delimited)
  df <- read.table(f, header = TRUE)
  
  #print(f)
  # keep only round = 200
  df <- df %>% filter(time == round)
  
  if (nrow(df) == 0) return(NULL)
  
  # Extract metadata from filename
  fname <- basename(f)
  
  # For bm: bm-FAULTY-SPACE
  if (str_detect(fname, "^bm-")) {
    parts <- str_split(fname, "-")[[1]]
    faulty <- as.numeric(parts[2])
    space <- as.numeric(parts[3])
    strat <- "bm"
  } else if (str_detect(fname, "^mergebm-")) {
    parts <- str_split(fname, "-")[[1]]
    faulty <- as.numeric(parts[2])
    trusty <- as.numeric(parts[3])
    space <- as.numeric(parts[4])
    strat <- paste("mergebm", trusty, sep="-")
  } else if (str_detect(fname, "^mergekvs-")) {
    parts <- str_split(fname, "-")[[1]]
    faulty <- as.numeric(parts[2])
    trusty <- as.numeric(parts[3])
    space <- 4
    strat <- paste("mergekvs", trusty, sep="-")
  } else if (str_detect(fname, "^kvs-")) {
    parts <- str_split(fname, "-")[[1]]
    faulty <- as.numeric(parts[2])
    space <- 4
    strat <- "kvs"
  } else if (str_detect(fname, "^bs-")) {
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
  
  # Add metadata and normalize
  df <- df %>%
    mutate(
      strategy = strat,
      faulty = faulty / n,
      space = space,
      avgByzN_norm = avgByzN / v
    )
  
  return(df)
}

# Read all files and combine
data <- do.call(rbind, lapply(files, read_result))

x_breaks_faulty <- c(0.1, 0.2, 0.3)
y_breaks <- c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)
# Plot
ggplot(data, aes(x = faulty, y = avgByzN_norm, color = factor(space), linetype = strategy, shape = strategy)) +
  geom_line(linewidth = 0.5) +
  geom_point() +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray40") +  # Add y = x line
  coord_cartesian(ylim = c(0, 1)) +
  scale_x_continuous(breaks = x_breaks_faulty) +
  scale_y_continuous(breaks = y_breaks) +
  labs(
    title = "Prop. of Byz. samples",
    x = "Prop. of Byz. nodes",
    y = "avgByzN / view size",
    color = "Space",
    linetype = "Strategy"
  ) +
  theme_minimal(base_size = 14)
