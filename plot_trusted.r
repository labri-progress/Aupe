#!/usr/bin/env Rscript
# Usage: Rscript plot_merge.r <faulty_pct> <budget> <p>
# Example: Rscript plot_merge.r 30 10 1
#   faulty_pct: Byzantine percentage (30)
#   budget:     budget memory in KB (10 or 20), used for BM filenames
#   p:          number of merges per trusted node per round (1 or 10)
#
# Outputs one figure with BM and Array, 3 lines per strategy (t=1%,5%,10%).

# Rscript plot_mergeandNomergeFloat.r 30 0.5 10

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(scales)

# --- Parameters ---
faulty_pct   <- as.integer(args[1])  # e.g. 30
budget       <- as.numeric(args[2])  # e.g. 0.5, 1 or 2 (KB)
strategy     <- args[3]
p_merge <- 10 # e.g. 1 or 10
nodes        <- 1000
view         <- 20
nruns        <- 1
force        <- 20
faulty_count <- as.integer(nodes * faulty_pct / 100)
strat_labels <- c("bm" = "BM", "decay" = "BMDecay", "array" = "Array")
trusted_pcts <- c(0, 5, 10, 20) #1, 5, 10, 20, 30) #c(1, 5, 10)
trusted_counts <- as.integer(nodes * trusted_pcts / 100)
trusted_counts
results_dir  <- "results_merge"

# --- Theme ---
line_size  <- 0.5
point_size <- 1.5
ratio      <- 2
width      <- 7
height     <- width / ratio

custom_colors <- c("0" = "#000000", "1" = "#e60096", "5" = "#E69F00", "10" = "#56B4E9", "20" = "#009E73", "30" = "#D55E00")
custom_linetypes <- c("BM" = "solid", "BMDecay" = "solid", "Array" = "dashed")
custom_shapes <- c("BM" = 16, "BMDecay" = 16,"Array" = 17)

mytheme <- theme(
  panel.grid.major   = element_blank(),
  panel.grid.minor   = element_blank(),
  panel.background   = element_rect(fill = "white"),
  plot.background    = element_rect(fill = "white"),
  panel.border       = element_rect(colour = "black", linewidth = 1, fill = NA),
  legend.spacing.y   = unit(0.005, "cm"),
  text               = element_text(size = 12, color = "black"),
  axis.title.x       = element_text(size = 14, face = "bold"),
  axis.title.y       = element_text(size = 12, face = "bold"),
  axis.text.x        = element_text(size = 14, face = "bold"),
  axis.text.y        = element_text(size = 14, face = "bold"),
  plot.title          = element_text(size = 14, face = "bold"),
  legend.text        = element_text(size = 12, face = "bold"),
  legend.title       = element_blank(),
  legend.background  = element_rect(fill = "transparent", colour = NA),
  legend.box.background = element_rect(fill = "transparent", colour = NA),
  axis.ticks         = element_line(color = "black", linewidth = 1)
)

# --- Read and aggregate data ---
common_cols <- c("time", "n_sent", "n_recv", "avgRecv", "avgByzRecv", "pByzRecv",
                 "avgByzN", "pushByzN", "pullByzN", "sampByzN", "avgByzSamp")

all_data <- data.frame()

for (ti in seq_along(trusted_pcts)) {
  t_pct   <- trusted_pcts[ti]
  t_count <- trusted_counts[ti]

  for (run in 1:nruns) {
    if (strategy == "array") {
      fname <- file.path(results_dir,
                          sprintf("%s-%d-%d-%d-%d-%d-run%d",
                                  strategy, nodes, view, faulty_count, t_count, p_merge, run))
    } else {
      fname <- file.path(results_dir,
                          sprintf("%s-%d-%d-%d-%d-%d-%.1g-run%d",
                                  strategy, nodes, view, faulty_count, t_count, p_merge, budget, run))
    }
    if (!file.exists(fname)) {
      cat("Warning: file not found:", fname, "\n")
      next
    }
    d <- read.table(fname, header = TRUE)
    # Keep only common columns to allow rbind across different file types
    d <- d[, intersect(names(d), common_cols), drop = FALSE]
    
    d$time      <- as.integer(d$time)
    d$strategy  <- strat_labels[[strategy]]
    d$t_pct     <- t_pct
    d$run       <- run
    all_data    <- rbind(all_data, d)
  }
}


# Compute proportion of Byzantine
all_data$propByz <- all_data$avgByzN / view

# Average over runs
avg_data <- all_data %>%
  group_by(strategy, t_pct, time) %>%
  summarise(propByz = mean(propByz), .groups = "drop")

avg_data$t_pct_f <- factor(avg_data$t_pct)
unique(avg_data$t_pct_f)
unique(avg_data$t_pct)
# --- Plot ---
optimal <- faulty_pct / 100

max_time <- max(avg_data$time)
if (max_time > 200) {
  x_breaks <- seq(0, max_time, by = 200)
} else if (max_time > 50) {
  x_breaks <- seq(0, max_time, by = 50)
} else {
  x_breaks <- sort(unique(avg_data$time))
}
if (strategy == "bm") {
  avg_data$label <- ifelse(avg_data$t_pct == 0, "BM noMerge", paste0("BM t=", avg_data$t_pct, "%"))
} else if (strategy == "decay") {
  avg_data$label <- ifelse(avg_data$t_pct == 0, "BMDecay noMerge", paste0("BMDecay t=", avg_data$t_pct, "%"))
}
avg_data$label_f <- factor(avg_data$label, levels = unique(avg_data$label))

# Build color mapping: reuse custom_colors keyed by t_pct
label_color_map <- avg_data %>%
  distinct(label_f, t_pct) %>%
  mutate(color = custom_colors[as.character(t_pct)])
label_colors <- setNames(label_color_map$color, label_color_map$label_f)

p <- ggplot(avg_data, aes(x = time, y = propByz,
                           color = label_f,
                           group = label_f)) +
  geom_hline(yintercept = optimal, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = line_size) +
  #geom_point(data = subset(avg_data, time %% 25 == 0), size = point_size) +
  scale_color_manual(values = label_colors) +
  labs(
    x = expression(bold("Rounds")),
    y = expression(bold("Proportion of Byz. samp."))
  ) +
  coord_cartesian(ylim = c(0, 1)) +
  scale_x_continuous(breaks = x_breaks) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
  mytheme +
  theme(
    legend.position = c(0.35, 0.85),
    legend.title = element_blank(),
    legend.box = "horizontal"
  ) +
  guides(color = guide_legend(ncol = 3)) 

# --- Save PDF ---
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/merge_byz_f%d_b%.1g_p%d_strat%s.pdf", faulty_pct, budget, p_merge, strategy)
pdf(outfile, width = width, height = height)
print(p)
dev.off()
cat("Saved to:", outfile, "\n")
